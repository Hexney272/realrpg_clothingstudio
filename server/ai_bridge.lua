AIBridge = AIBridge or {}

local cooldowns = {}

local function notify(src, msg, typ)
    TriggerClientEvent('realrpg_clothingstudio:client:notify', src, msg, typ or 'info')
end

local function isEnabled()
    return Config.AI and Config.AI.enabled and Config.AI.provider == 'gemini'
end

local function hasPermission(src)
    local allowed = Config.AI and Config.AI.allowedJobs
    if not allowed then return true end

    local job, grade = ServerFW.GetJob(src)
    if not job then return false end

    local required = allowed[job]
    return required ~= nil and tonumber(grade or 0) >= tonumber(required or 0)
end

local function sanitizePrompt(prompt)
    prompt = tostring(prompt or ''):gsub('[\r\n]+', ' '):gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    local maxLen = tonumber(Config.AI.maxPromptLength) or 420
    if #prompt > maxLen then prompt = prompt:sub(1, maxLen) end
    return prompt
end

local function sanitizeNegativePrompt(prompt)
    prompt = tostring(prompt or ''):gsub('[\r\n]+', ' '):gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    local maxLen = tonumber(Config.AI.maxNegativePromptLength) or 240
    if #prompt > maxLen then prompt = prompt:sub(1, maxLen) end
    return prompt
end

local function blocked(prompt)
    local lower = prompt:lower()
    for _, word in ipairs(Config.AI.blockedWords or {}) do
        if word ~= '' and lower:find(tostring(word):lower(), 1, true) then
            return true, word
        end
    end
    return false, nil
end

local function canUseCooldown(src)
    local cooldown = tonumber(Config.AI.cooldownSeconds) or 60
    if cooldown <= 0 then return true, 0 end

    local now = os.time()
    local last = cooldowns[src] or 0
    local remaining = cooldown - (now - last)
    if remaining > 0 then return false, remaining end

    cooldowns[src] = now
    return true, 0
end

local b64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local function base64Encode(data)
    return ((data:gsub('.', function(x)
        local r, byte = '', x:byte()
        for i = 8, 1, -1 do
            r = r .. (byte % 2 ^ i - byte % 2 ^ (i - 1) > 0 and '1' or '0')
        end
        return r
    end) .. '0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if #x < 6 then return '' end
        local c = 0
        for i = 1, 6 do
            c = c + (x:sub(i, i) == '1' and 2 ^ (6 - i) or 0)
        end
        return b64:sub(c + 1, c + 1)
    end) .. ({ '', '==', '=' })[#data % 3 + 1])
end

local function extractGeminiImage(decoded)
    -- New Interactions API response format
    local steps = decoded and decoded.steps
    if type(steps) ~= 'table' then return nil, nil, nil end

    local textParts = {}

    for _, step in ipairs(steps) do
        if type(step) == 'table' and step.type == 'model_output' then
            local content = step.content
            if type(content) == 'table' then
                for _, block in ipairs(content) do
                    if type(block) == 'table' then
                        if block.type == 'text' and block.text then
                            textParts[#textParts + 1] = tostring(block.text)
                        end
                        if block.type == 'image' and block.data then
                            return block.data, block.mime_type or 'image/png', table.concat(textParts, '\n')
                        end
                    end
                end
            end
        end
    end

    -- Fallback: check output_image at top level
    if decoded.output_image and decoded.output_image.data then
        return decoded.output_image.data, decoded.output_image.mime_type or 'image/png', table.concat(textParts, '\n')
    end

    return nil, nil, table.concat(textParts, '\n')
end

local function buildPayload(prompt, negativePrompt)
    local finalPrompt = (Config.AI.systemPrefix or '') .. prompt
    if negativePrompt and negativePrompt ~= '' then
        finalPrompt = finalPrompt .. '\nAvoid: ' .. negativePrompt
    end

    -- Interactions API: minimal format that works
    return json.encode({
        model = Config.AI.model or 'gemini-2.5-flash-image',
        input = finalPrompt
    })
end

local function saveHistory(src, prompt, negativePrompt, resultUrl, error)
    if not (Config.AI and Config.AI.storePromptHistory) then return end
    if not DB or not DB.SaveAIHistory then return end

    local identifier = ServerFW.GetIdentifier(src)
    local ok = pcall(DB.SaveAIHistory, identifier, ServerFW.GetName(src), prompt, negativePrompt, resultUrl, error)
    if not ok and Config.Debug then
        print('[realrpg_clothingstudio] failed to save AI history')
    end
end

function AIBridge.IsEnabled()
    return isEnabled()
end

function AIBridge.Generate(src, payload)
    if not isEnabled() then
        notify(src, 'Az AI mód jelenleg ki van kapcsolva a configban.', 'error')
        TriggerClientEvent('realrpg_clothingstudio:client:aiResult', src, { ok = false, error = 'ai_disabled' })
        return
    end

    if not hasPermission(src) then
        notify(src, 'Nincs jogosultságod az AI designer használatához.', 'error')
        TriggerClientEvent('realrpg_clothingstudio:client:aiResult', src, { ok = false, error = 'permission_denied' })
        return
    end

    local allowed, remaining = canUseCooldown(src)
    if not allowed then
        notify(src, ('AI cooldown aktív: %s mp.'):format(remaining), 'error')
        TriggerClientEvent('realrpg_clothingstudio:client:aiResult', src, { ok = false, error = 'cooldown', remaining = remaining })
        return
    end

    local prompt = sanitizePrompt(payload and payload.prompt)
    local negativePrompt = sanitizeNegativePrompt(payload and payload.negativePrompt)

    if prompt == '' then
        TriggerClientEvent('realrpg_clothingstudio:client:aiResult', src, { ok = false, error = 'empty_prompt' })
        return
    end

    local isBlocked, blockedWord = blocked(prompt .. ' ' .. negativePrompt)
    if isBlocked then
        notify(src, ('Tiltott AI prompt elem: %s'):format(blockedWord), 'error')
        saveHistory(src, prompt, negativePrompt, nil, 'blocked_prompt')
        TriggerClientEvent('realrpg_clothingstudio:client:aiResult', src, { ok = false, error = 'blocked_prompt' })
        return
    end

    local apiKey = Config.AI.apiKey or ''
    if apiKey == '' then
        notify(src, 'Nincs megadva Gemini API kulcs a configban.', 'error')
        TriggerClientEvent('realrpg_clothingstudio:client:aiResult', src, { ok = false, error = 'missing_api_key' })
        return
    end

    -- New Interactions API endpoint (key in URL as fallback for FiveM PerformHttpRequest)
    local endpoint = ('https://generativelanguage.googleapis.com/v1beta/interactions?key=%s'):format(apiKey)
    local body = buildPayload(prompt, negativePrompt)

    notify(src, 'AI design generálása folyamatban...', 'info')
    print(('[^3RealRPG AI^0] Player %d generating: "%s" | Model: %s'):format(src, prompt:sub(1, 60), Config.AI.model or '?'))
    print(('[^3RealRPG AI^0] Body: %s'):format(body:sub(1, 300)))

    PerformHttpRequest(endpoint, function(status, response)
        print(('[^3RealRPG AI^0] Response status: %s | Body length: %s'):format(tostring(status), response and #response or 0))

        if status < 200 or status >= 300 then
            local err = ('http_%s'):format(status)
            notify(src, ('AI generálás sikertelen: HTTP %s'):format(status), 'error')
            if Config.Debug and response then
                print(('[^1RealRPG AI^0] Error response: %s'):format(tostring(response):sub(1, 500)))
            end
            saveHistory(src, prompt, negativePrompt, nil, err)
            TriggerClientEvent('realrpg_clothingstudio:client:aiResult', src, { ok = false, error = err })
            return
        end

        local ok, decoded = pcall(json.decode, response or '{}')
        if not ok or type(decoded) ~= 'table' then
            notify(src, 'AI válasz nem értelmezhető.', 'error')
            saveHistory(src, prompt, negativePrompt, nil, 'bad_response')
            TriggerClientEvent('realrpg_clothingstudio:client:aiResult', src, { ok = false, error = 'bad_response' })
            return
        end

        local imageBase64, mime, aiText = extractGeminiImage(decoded)
        if not imageBase64 then
            local err = 'no_image_returned'
            notify(src, 'Az AI nem adott vissza képet.', 'error')
            saveHistory(src, prompt, negativePrompt, nil, err)
            TriggerClientEvent('realrpg_clothingstudio:client:aiResult', src, { ok = false, error = err, text = aiText })
            return
        end

        local dataUrl = ('data:%s;base64,%s'):format(mime or 'image/png', imageBase64)

        local function finish(resultUrl, uploadError)
            local result = {
                ok = true,
                prompt = prompt,
                negativePrompt = negativePrompt,
                mime = mime or 'image/png',
                url = resultUrl,
                dataUrl = resultUrl and nil or dataUrl,
                text = aiText,
                uploadError = uploadError
            }

            saveHistory(src, prompt, negativePrompt, resultUrl, uploadError)
            TriggerClientEvent('realrpg_clothingstudio:client:aiResult', src, result)
            notify(src, 'AI design elkészült.', 'success')
        end

        if Config.AI.uploadResultToCdn and UploadBridge and UploadBridge.IsEnabled and UploadBridge.IsEnabled() then
            UploadBridge.UploadDataUrl(src, dataUrl, 'ai_design', function(uploadOk, url, uploadErr)
                if uploadOk and url then
                    finish(url, nil)
                else
                    if Config.AI.failIfUploadFails then
                        notify(src, ('AI kép upload sikertelen: %s'):format(uploadErr or 'unknown'), 'error')
                        saveHistory(src, prompt, negativePrompt, nil, uploadErr or 'upload_failed')
                        TriggerClientEvent('realrpg_clothingstudio:client:aiResult', src, { ok = false, error = uploadErr or 'upload_failed' })
                    else
                        finish(nil, uploadErr or 'upload_failed')
                    end
                end
            end)
        else
            finish(nil, nil)
        end
    end, 'POST', body, {
        ['Content-Type'] = 'application/json',
        ['x-goog-api-key'] = apiKey
    })
end

AddEventHandler('playerDropped', function()
    cooldowns[source] = nil
end)
