local runtimeHandles = {}
local appliedTextures = {}

local function debugPrint(msg)
    if Config.Debug then print(('^2[RealRPG Clothing Studio]^7 %s'):format(msg)) end
end

local function safeRuntimeName(value)
    value = tostring(value or 'unknown')
    value = value:gsub('[^%w_]', '_')
    return value:sub(1, 48)
end

local function getDuiUrl()
    return ('nui://%s/web/dui_texture.html'):format(GetCurrentResourceName())
end

local function now()
    return GetGameTimer()
end

local function cacheConfig()
    return Config.Cache or {}
end

local function handleCount()
    local count = 0
    for _ in pairs(runtimeHandles) do count = count + 1 end
    return count
end

local function removeAppliedForHandle(handle)
    if handle and handle.sourceTxd and handle.sourceTxn then
        RemoveReplaceTexture(handle.sourceTxd, handle.sourceTxn)
        appliedTextures[('%s:%s'):format(handle.sourceTxd, handle.sourceTxn)] = nil
    end
end

local function destroyRuntime(designId)
    local key = safeRuntimeName(designId)
    local handle = runtimeHandles[key]
    if handle then
        removeAppliedForHandle(handle)
        if handle.dui then DestroyDui(handle.dui) end
        runtimeHandles[key] = nil
    end
end

local function destroyByKey(key)
    local handle = runtimeHandles[key]
    if not handle then return false end
    removeAppliedForHandle(handle)
    if handle.dui then DestroyDui(handle.dui) end
    runtimeHandles[key] = nil
    return true
end

local function cleanupRuntimeCache(force)
    if not Config.Cache or Config.Cache.enabled == false then return 0 end

    local cfg = cacheConfig()
    local maxHandles = tonumber(cfg.maxRuntimeHandles) or 32
    local maxIdleMs = (tonumber(cfg.maxIdleSeconds) or 900) * 1000
    local current = now()
    local removed = 0

    for key, handle in pairs(runtimeHandles) do
        if force or (handle.lastUsed and (current - handle.lastUsed) > maxIdleMs) then
            if destroyByKey(key) then removed = removed + 1 end
        end
    end

    while not force and handleCount() > maxHandles do
        local oldestKey, oldestTime = nil, nil
        for key, handle in pairs(runtimeHandles) do
            local t = handle.lastUsed or handle.createdAt or 0
            if not oldestTime or t < oldestTime then
                oldestKey, oldestTime = key, t
            end
        end
        if not oldestKey then break end
        if destroyByKey(oldestKey) then removed = removed + 1 else break end
    end

    return removed
end

local function buildRuntimeTexture(metadata)
    if not Config.RuntimeTextures or not Config.RuntimeTextures.enabled then return nil end
    if type(metadata) ~= 'table' or type(metadata.runtime) ~= 'table' then return nil end

    local image = metadata.image or metadata.preview
    if type(image) ~= 'string' or image == '' then return nil end

    cleanupRuntimeCache(false)

    local designKey = safeRuntimeName(metadata.designId)
    if runtimeHandles[designKey] then
        runtimeHandles[designKey].lastUsed = now()
        return runtimeHandles[designKey]
    end

    local width = tonumber(metadata.runtime.width or Config.RuntimeTextures.width) or 1024
    local height = tonumber(metadata.runtime.height or Config.RuntimeTextures.height) or 1024

    local dui = CreateDui(getDuiUrl(), width, height)
    if not dui then return nil end

    local duiHandle = GetDuiHandle(dui)
    local txdName = ('rrcs_%s'):format(designKey)
    local txnName = 'print'
    local txd = CreateRuntimeTxd(txdName)
    CreateRuntimeTextureFromDuiHandle(txd, txnName, duiHandle)

    runtimeHandles[designKey] = {
        dui = dui,
        txd = txdName,
        txn = txnName,
        sourceTxd = metadata.runtime.txd,
        sourceTxn = metadata.runtime.txn,
        designId = metadata.designId,
        category = metadata.category,
        slot = metadata.runtime.slot,
        createdAt = now(),
        lastUsed = now(),
        width = width,
        height = height
    }

    CreateThread(function()
        Wait(250)
        SendDuiMessage(dui, json.encode({
            action = 'setImage',
            image = image,
            width = width,
            height = height
        }))
    end)

    debugPrint(('DUI runtime prepared design=%s slot=%s source=%s/%s'):format(metadata.designId, metadata.runtime.slot, metadata.runtime.txd, metadata.runtime.txn))
    return runtimeHandles[designKey]
end

function ApplyRealRPGRuntimeTexture(metadata)
    local rt = buildRuntimeTexture(metadata)
    if not rt or not rt.sourceTxd or not rt.sourceTxn then return false end

    rt.lastUsed = now()
    local replaceKey = ('%s:%s'):format(rt.sourceTxd, rt.sourceTxn)
    if appliedTextures[replaceKey] ~= rt.designId then
        RemoveReplaceTexture(rt.sourceTxd, rt.sourceTxn)
        AddReplaceTexture(rt.sourceTxd, rt.sourceTxn, rt.txd, rt.txn)
        appliedTextures[replaceKey] = rt.designId
        debugPrint(('Texture replaced %s/%s -> %s/%s'):format(rt.sourceTxd, rt.sourceTxn, rt.txd, rt.txn))
    end

    return true
end

function RemoveRealRPGRuntimeTexture(metadata)
    if type(metadata) ~= 'table' then return end
    if metadata.runtime and metadata.runtime.txd and metadata.runtime.txn then
        RemoveReplaceTexture(metadata.runtime.txd, metadata.runtime.txn)
        appliedTextures[('%s:%s'):format(metadata.runtime.txd, metadata.runtime.txn)] = nil
    end
    if metadata.designId then destroyRuntime(metadata.designId) end
end

function ClearRealRPGRuntimeTextureCache()
    return cleanupRuntimeCache(true)
end

RegisterCommand((Config.Admin and Config.Admin.textureDebugCommand) or 'rrcs_texdebug', function()
    print('^2[RealRPG Clothing Studio]^7 Runtime handles:')
    for key, handle in pairs(runtimeHandles) do
        print(('%s -> source=%s/%s runtime=%s/%s slot=%s lastUsed=%s'):format(key, handle.sourceTxd, handle.sourceTxn, handle.txd, handle.txn, handle.slot, handle.lastUsed or 0))
    end
end)

RegisterCommand((Config.Admin and Config.Admin.textureCacheCommand) or (Config.Cache and Config.Cache.textureCacheCommand) or 'rrcs_texcache', function()
    print('^2[RealRPG Clothing Studio]^7 Runtime texture cache:')
    print(('Handles: %s / Max: %s'):format(handleCount(), (Config.Cache and Config.Cache.maxRuntimeHandles) or 'nil'))
    print(('Applied replacements:'))
    for key, designId in pairs(appliedTextures) do
        print(('  %s -> %s'):format(key, designId))
    end
end)

RegisterCommand((Config.Admin and Config.Admin.clearTextureCacheCommand) or (Config.Cache and Config.Cache.clearTextureCacheCommand) or 'rrcs_cleartexcache', function()
    local removed = cleanupRuntimeCache(true)
    print(('^2[RealRPG Clothing Studio]^7 Texture cache cleared. Removed handles: %s'):format(removed))
end)

CreateThread(function()
    while true do
        local interval = ((Config.Cache and Config.Cache.autoCleanupIntervalSeconds) or 120) * 1000
        Wait(interval)
        local removed = cleanupRuntimeCache(false)
        if removed > 0 then debugPrint(('Runtime texture cache cleanup removed %s handle(s)'):format(removed)) end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    cleanupRuntimeCache(true)
    runtimeHandles = {}
    appliedTextures = {}
end)
