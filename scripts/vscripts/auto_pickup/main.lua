
local collector = require('auto_pickup.collector')

---@param event PlayerEventPlayerActivate
ListenToPlayerEvent('player_activate', function(event)
    -- kill any existing trigger to avoid duplicates and make life easier
    local trigger = collector:GetTrigger()
    if IsValidEntity(trigger) then
        ---@cast trigger -nil
        devprint('Killing existing auto pickup trigger')
        trigger:Kill()
    end

    collector:Init(event.player)
end)