--[[
    RealRPG Clothing Studio - Discord CDN Upload Bridge
    
    Preview képek feltöltése Discord webhook-ra.
    A Discord attachment URL-ek CDN-ként szolgálnak a design preview képeknek.
    
    Flow:
    1. Kliens elküldi a base64 preview-t a saveDesign-nal
    2. Server dekódolja a base64-et bináris adattá
    3. Multipart/form-data POST a Discord webhookra (fájl mellékletként)
    4. Discord válaszból kinyerjük az attachment URL-t
    5. Az URL-t mentjük az image_url mezőbe
    
    FONTOS:
    - A Discord CDN URL-ek NEM permanensek (lejárhatnak)
    - Éles használathoz saját CDN/S3 ajánlott, de Discord jó MVP-hez
    - A base64 preview_data mindig mentődik fallback-ként
]]

Upload = {}

-- ═══════════════════════════════════════════════════════════════
-- BASE64 DECODE
-- ═══════════════════════════════════════════════════════════════

--- Base64 dekódolás (pure Lua implementation)
local b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local b64lookup = {}
for i = 1, #b64chars do
    b64lookup[b64chars:sub(i, i)] = i - 1
end

local function base64Decode(data)
    -- Remove data URL prefix if present
    data = data:gsub('^data:[^;]+;base64,', '')
    -- Remove whitespace
    data = data:gsub('%s', '')

    local result = {}
    local padding = 0

    -- Count padding
    if data:sub(-2) == '==' then
        padding = 2
    elseif data:sub(-1) == '=' then
        padding = 1
    end

    for i = 1, #data - padding, 4 do
        local a = b64lookup[data:sub(i, i)] or 0
        local b = b64lookup[data:sub(i+1, i+1)] or 0
        local c = b64lookup[data:sub(i+2, i+2)] or 0
        local d = b64lookup[data:sub(i+3, i+3)] or 0

        local n = (a << 18) + (b << 12) + (c << 6) + d

        result[#result + 1] = string.char((n >> 16) & 0xFF)
        if data:sub(i+2, i+2) ~= '=' then
            result[#result + 1] = string.char((n >> 8) & 0xFF)
        end
        if data:sub(i+3, i+3) ~= '=' then
            result[#result + 1] = string.char(n & 0xFF)
        end
    end

    return table.concat(result)
end


-- ═══════════════════════════════════════════════════════════════
-- MULTIPART FORM-DATA BUILDER
-- ═══════════════════════════════════════════════════════════════

--- Multipart boundary generálás
local function generateBoundary()
    return '----RealRPGBoundary' .. os.time() .. math.random(100000, 999999)
end

--- Multipart form-data body összeállítás fájl melléklettel
---@param boundary string
---@param filename string
---@param fileData string Binary file data
---@param contentType string MIME type
---@param extraFields table|nil { key = value } extra form mezők
---@return string body
local function buildMultipartBody(boundary, filename, fileData, contentType, extraFields)
    local parts = {}

    -- Extra mezők (pl. payload_json)
    if extraFields then
        for key, value in pairs(extraFields) do
            parts[#parts + 1] = ('--' .. boundary .. '\r\n')
            parts[#parts + 1] = ('Content-Disposition: form-data; name="%s"\r\n\r\n'):format(key)
            parts[#parts + 1] = value .. '\r\n'
        end
    end

    -- Fájl melléklet
    parts[#parts + 1] = ('--' .. boundary .. '\r\n')
    parts[#parts + 1] = ('Content-Disposition: form-data; name="file"; filename="%s"\r\n'):format(filename)
    parts[#parts + 1] = ('Content-Type: %s\r\n\r\n'):format(contentType)
    parts[#parts + 1] = fileData
    parts[#parts + 1] = '\r\n'

    -- Záró boundary
    parts[#parts + 1] = ('--' .. boundary .. '--\r\n')

    return table.concat(parts)
end


-- ═══════════════════════════════════════════════════════════════
-- DISCORD WEBHOOK UPLOAD
-- ═══════════════════════════════════════════════════════════════

--- Preview kép feltöltése Discord webhook-ra
---@param base64Data string Base64 encoded image (data:image/png;base64,... vagy nyers base64)
---@param filename string A fájl neve (pl. "rr_design_12345.png")
---@param label string|nil Opcionális embed title
---@return string|nil imageUrl A feltöltött kép CDN URL-je, vagy nil ha sikertelen
function Upload.ToDiscord(base64Data, filename, label)
    if not Config.UploadBridge.enabled then return nil end
    if not Config.UploadBridge.discordWebhook or Config.UploadBridge.discordWebhook == '' then
        print('[^1RealRPG Upload^0] Discord webhook URL nincs konfigurálva!')
        return nil
    end

    -- Base64 dekódolás
    local binaryData = base64Decode(base64Data)
    if not binaryData or #binaryData == 0 then
        print('[^1RealRPG Upload^0] Base64 dekódolás sikertelen.')
        return nil
    end

    -- Méret ellenőrzés
    if #binaryData > Config.UploadBridge.maxFileSize then
        print(('[^1RealRPG Upload^0] Fájl túl nagy: %d bytes (max: %d)'):format(
            #binaryData, Config.UploadBridge.maxFileSize
        ))
        return nil
    end

    -- Content type meghatározás
    local contentType = 'image/png'
    if Config.UploadBridge.format == 'jpeg' or filename:find('%.jpe?g$') then
        contentType = 'image/jpeg'
    end

    -- Multipart body összeállítás
    local boundary = generateBoundary()

    -- Payload JSON (opcionális embed az üzenethez)
    local payloadJson = json.encode({
        username = Config.UploadBridge.botName or 'RealRPG Studio',
        avatar_url = Config.UploadBridge.botAvatar ~= '' and Config.UploadBridge.botAvatar or nil,
        content = label and ('Design: **%s**'):format(label) or nil
    })

    local body = buildMultipartBody(boundary, filename, binaryData, contentType, {
        payload_json = payloadJson
    })

    -- HTTP POST a Discord webhook-ra
    local webhookUrl = Config.UploadBridge.discordWebhook .. '?wait=true'

    local statusCode, responseText, headers = nil, nil, nil

    PerformHttpRequest(webhookUrl, function(code, text, hdrs)
        statusCode = code
        responseText = text
        headers = hdrs
    end, 'POST', body, {
        ['Content-Type'] = 'multipart/form-data; boundary=' .. boundary
    })

    -- Várunk a válaszra (max 15 sec)
    local timeout = 150
    while statusCode == nil and timeout > 0 do
        Wait(100)
        timeout = timeout - 1
    end

    if not statusCode then
        print('[^1RealRPG Upload^0] Discord webhook timeout!')
        return nil
    end

    if statusCode < 200 or statusCode >= 300 then
        print(('[^1RealRPG Upload^0] Discord webhook hiba: HTTP %d'):format(statusCode))
        if Config.Debug and responseText then
            print(('[^1RealRPG Upload^0] Response: %s'):format(responseText:sub(1, 500)))
        end
        return nil
    end

    -- Válasz feldolgozás - attachment URL kinyerése
    local response = json.decode(responseText or '')
    if not response then
        print('[^1RealRPG Upload^0] Discord válasz parse hiba.')
        return nil
    end

    local attachments = response.attachments
    if not attachments or #attachments == 0 then
        print('[^1RealRPG Upload^0] Discord válaszban nincs attachment.')
        return nil
    end

    local imageUrl = attachments[1].url or attachments[1].proxy_url
    if not imageUrl then
        print('[^1RealRPG Upload^0] Attachment URL nem található.')
        return nil
    end

    if Config.Debug then
        print(('[^2RealRPG Upload^0] Feltöltve: %s (%d bytes) -> %s'):format(
            filename, #binaryData, imageUrl:sub(1, 80) .. '...'
        ))
    end

    return imageUrl
end


-- ═══════════════════════════════════════════════════════════════
-- DESIGN PREVIEW UPLOAD (MAIN ENTRY POINT)
-- ═══════════════════════════════════════════════════════════════

--- Design preview feltöltése - ezt hívja a server/main.lua saveDesign-ból
---@param designId string A design egyedi azonosítója
---@param base64Preview string A canvas base64 export
---@param label string|nil Design neve (Discord embed-hez)
---@return string|nil imageUrl
function Upload.UploadDesignPreview(designId, base64Preview, label)
    if not Config.UploadBridge.enabled then return nil end
    if not base64Preview or base64Preview == '' then return nil end
    -- Nagyon rövid base64 = üres canvas, nem töltjük fel
    if #base64Preview < 100 then return nil end

    local ext = Config.UploadBridge.format or 'png'
    local filename = ('%s.%s'):format(designId, ext)

    local url = Upload.ToDiscord(base64Preview, filename, label)

    -- Ha sikeres, frissítjük a DB-ben az image_url-t
    if url then
        MySQL.update.await(
            'UPDATE realrpg_clothing_designs SET image_url = ? WHERE design_id = ?',
            { url, designId }
        )
    end

    return url
end

--- Batch: meglévő designek feltöltése (admin parancshoz)
---@param limit number Maximum hány designt töltsünk fel
function Upload.BatchUploadMissing(limit)
    if not Config.UploadBridge.enabled then
        print('[^3RealRPG Upload^0] Upload bridge disabled.')
        return
    end

    local designs = MySQL.query.await([[
        SELECT design_id, label, preview_data FROM realrpg_clothing_designs
        WHERE (image_url IS NULL OR image_url = '') AND preview_data IS NOT NULL AND preview_data != ''
        ORDER BY id DESC LIMIT ?
    ]], { limit or 10 })

    if not designs or #designs == 0 then
        print('[^3RealRPG Upload^0] Nincs feltöltendő design.')
        return
    end

    local uploaded = 0
    for _, design in ipairs(designs) do
        local url = Upload.UploadDesignPreview(design.design_id, design.preview_data, design.label)
        if url then
            uploaded = uploaded + 1
        end
        Wait(1500) -- Rate limit: Discord webhook max 30 req/min
    end

    print(('[^2RealRPG Upload^0] Batch upload kész: %d/%d feltöltve.'):format(uploaded, #designs))
end

-- ═══════════════════════════════════════════════════════════════
-- ADMIN COMMAND
-- ═══════════════════════════════════════════════════════════════

RegisterCommand('rr_upload_missing', function(source, args)
    -- Csak konzolból vagy admin
    if source ~= 0 then
        -- Opcionális: admin ellenőrzés (IsPlayerAceAllowed)
        if not IsPlayerAceAllowed(source, 'realrpg.admin') then
            TriggerClientEvent('realrpg_clothingstudio:client:notify', source, 'Nincs jogosultságod.', 'error')
            return
        end
    end

    local limit = tonumber(args[1]) or 10
    print(('[^3RealRPG Upload^0] Batch upload indítása (limit: %d)...'):format(limit))
    Upload.BatchUploadMissing(limit)
end, true)
