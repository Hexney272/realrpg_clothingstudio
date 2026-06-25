UploadBridge = UploadBridge or {}

local uploadBuffers = {}

local function enabled()
    return Config.UploadBridge and Config.UploadBridge.enabled and Config.UploadBridge.provider == 'discord'
end

local function notify(src, msg, typ)
    TriggerClientEvent('realrpg_clothingstudio:client:notify', src, msg, typ or 'info')
end

local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

local function base64Decode(data)
    data = tostring(data or ''):gsub('[^' .. b .. '=]', '')
    return (data:gsub('.', function(x)
        if x == '=' then return '' end
        local r, f = '', (b:find(x, 1, true) or 1) - 1
        for i = 6, 1, -1 do
            r = r .. (f % 2 ^ i - f % 2 ^ (i - 1) > 0 and '1' or '0')
        end
        return r
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if #x ~= 8 then return '' end
        local c = 0
        for i = 1, 8 do
            c = c + (x:sub(i, i) == '1' and 2 ^ (8 - i) or 0)
        end
        return string.char(c)
    end))
end

local function parseDataUrl(dataUrl)
    if type(dataUrl) ~= 'string' then return nil, 'invalid_data' end
    local mime, base64 = dataUrl:match('^data:([^;]+);base64,(.+)$')
    if not mime or not base64 then return nil, 'not_data_url' end
    if mime ~= 'image/png' and mime ~= 'image/jpeg' and mime ~= 'image/webp' then
        return nil, 'bad_mime'
    end
    return {
        mime = mime,
        extension = mime == 'image/png' and 'png' or mime == 'image/jpeg' and 'jpg' or 'webp',
        data = base64Decode(base64)
    }
end

local function discordUpload(binary, filename, mime, cb)
    local webhook = Config.UploadBridge.discordWebhook or ''
    if webhook == '' then
        cb(false, nil, 'missing_webhook')
        return
    end

    local boundary = '----RealRPGClothingStudio' .. tostring(os.time()) .. tostring(math.random(1000, 9999))
    local payload = json.encode({
        username = 'RealRPG Clothing Studio',
        content = ('New clothing design upload: `%s`'):format(filename)
    })

    local body = table.concat({
        '--' .. boundary .. '\r\n',
        'Content-Disposition: form-data; name="payload_json"\r\n',
        'Content-Type: application/json\r\n\r\n',
        payload .. '\r\n',
        '--' .. boundary .. '\r\n',
        ('Content-Disposition: form-data; name="files[0]"; filename="%s"\r\n'):format(filename),
        ('Content-Type: %s\r\n\r\n'):format(mime),
        binary .. '\r\n',
        '--' .. boundary .. '--\r\n'
    })

    PerformHttpRequest(webhook, function(status, response)
        if status < 200 or status >= 300 then
            cb(false, nil, ('http_%s'):format(status))
            return
        end

        local ok, decoded = pcall(json.decode, response or '{}')
        if not ok or type(decoded) ~= 'table' then
            cb(false, nil, 'bad_response')
            return
        end

        local attachment = decoded.attachments and decoded.attachments[1]
        local url = attachment and (attachment.url or attachment.proxy_url)
        if not url then
            cb(false, nil, 'no_attachment_url')
            return
        end

        cb(true, url, nil)
    end, 'POST', body, {
        ['Content-Type'] = 'multipart/form-data; boundary=' .. boundary,
        ['Content-Length'] = tostring(#body)
    })
end

function UploadBridge.IsEnabled()
    return enabled()
end

function UploadBridge.UploadDataUrl(src, dataUrl, filenamePrefix, cb)
    if not enabled() then
        cb(false, nil, 'upload_disabled')
        return
    end

    local maxBytes = tonumber(Config.UploadBridge.maxDataUrlBytes) or (6 * 1024 * 1024)
    if #dataUrl > maxBytes then
        cb(false, nil, 'too_large')
        return
    end

    local parsed, err = parseDataUrl(dataUrl)
    if not parsed then
        cb(false, nil, err)
        return
    end

    local filename = ('%s_%s_%s.%s'):format(filenamePrefix or 'design', src, os.time(), parsed.extension)
    discordUpload(parsed.data, filename, parsed.mime, cb)
end

RegisterNetEvent('realrpg_clothingstudio:server:uploadBegin', function(data)
    local src = source
    if not enabled() then
        TriggerClientEvent('realrpg_clothingstudio:client:uploadResult', src, { ok = false, uploadId = data and data.uploadId, error = 'upload_disabled' })
        return
    end

    if type(data) ~= 'table' or not data.uploadId then return end

    uploadBuffers[src] = uploadBuffers[src] or {}
    uploadBuffers[src][data.uploadId] = {
        chunks = {},
        total = tonumber(data.total) or 0,
        received = 0,
        created = os.time(),
        kind = tostring(data.kind or 'design')
    }
end)

RegisterNetEvent('realrpg_clothingstudio:server:uploadChunk', function(data)
    local src = source
    if type(data) ~= 'table' or not data.uploadId or not data.chunk then return end
    local bucket = uploadBuffers[src] and uploadBuffers[src][data.uploadId]
    if not bucket then return end

    local index = tonumber(data.index) or (#bucket.chunks + 1)
    local chunk = tostring(data.chunk)
    bucket.chunks[index] = chunk
    bucket.received = bucket.received + #chunk

    local maxBytes = tonumber(Config.UploadBridge.maxDataUrlBytes) or (6 * 1024 * 1024)
    if bucket.received > maxBytes then
        uploadBuffers[src][data.uploadId] = nil
        TriggerClientEvent('realrpg_clothingstudio:client:uploadResult', src, { ok = false, uploadId = data.uploadId, error = 'too_large' })
    end
end)

RegisterNetEvent('realrpg_clothingstudio:server:uploadFinish', function(data)
    local src = source
    if type(data) ~= 'table' or not data.uploadId then return end
    local bucket = uploadBuffers[src] and uploadBuffers[src][data.uploadId]
    if not bucket then
        TriggerClientEvent('realrpg_clothingstudio:client:uploadResult', src, { ok = false, uploadId = data.uploadId, error = 'missing_upload_buffer' })
        return
    end

    local timeout = tonumber(Config.UploadBridge.timeoutSeconds) or 60
    if os.time() - bucket.created > timeout then
        uploadBuffers[src][data.uploadId] = nil
        TriggerClientEvent('realrpg_clothingstudio:client:uploadResult', src, { ok = false, uploadId = data.uploadId, error = 'upload_timeout' })
        return
    end

    local dataUrl = table.concat(bucket.chunks)
    uploadBuffers[src][data.uploadId] = nil

    UploadBridge.UploadDataUrl(src, dataUrl, bucket.kind, function(ok, url, err)
        TriggerClientEvent('realrpg_clothingstudio:client:uploadResult', src, {
            ok = ok,
            uploadId = data.uploadId,
            url = url,
            error = err
        })

        if not ok then
            notify(src, ('Upload sikertelen: %s'):format(err or 'unknown'), 'error')
        end
    end)
end)

AddEventHandler('playerDropped', function()
    uploadBuffers[source] = nil
end)
