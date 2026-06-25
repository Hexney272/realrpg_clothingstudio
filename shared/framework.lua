RRFW = RRFW or {}
RRFW.Name = 'standalone'

local function resourceStarted(name)
    return GetResourceState(name) == 'started'
end

function RRFW.Detect()
    if Config.Framework ~= 'auto' then
        RRFW.Name = Config.Framework
        return RRFW.Name
    end
    if resourceStarted('es_extended') then RRFW.Name = 'esx'
    elseif resourceStarted('qbx_core') then RRFW.Name = 'qbox'
    elseif resourceStarted('qb-core') then RRFW.Name = 'qb'
    else RRFW.Name = 'standalone' end
    return RRFW.Name
end

RRFW.Detect()
