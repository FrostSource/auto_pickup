--[[
    Detects when an item is near to the player for collection.
]]

local util = require('auto_pickup.util')
local partialClipStorageEnabled = util.IsPartialClipStorageEnabled()

GlobalPrecache:Add('model', 'models/auto_pickup/collector_trigger.vmdl')

-- Minimum time between playing pickup sound, to avoid spamming when picking up multiple items at once.
local SND_MIN_TIME = 0.05

-- Trigger update interval in seconds. This is how often the trigger checks for touching entities.
local TRIGGER_UPDATE_INTERVAL = 1.0

local collector = {}

local lastSoundTime = 0

local itemClasses = {
    item_hlvr_clip_energygun = {
        cmd = 'hlvr_addresources 10 0 0 0',
        snd = 'Inventory.DepositItem'
    },
    item_hlvr_clip_energygun_multiple = {
        cmd = 'hlvr_addresources 40 0 0 0',
        snd = 'Inventory.DepositItem'
    },
    item_hlvr_clip_shotgun_single = {
        cmd = 'hlvr_addresources 0 0 1 0',
        snd = 'Inventory.DepositItem'
    },
    item_hlvr_clip_shotgun_multiple = {
        cmd = 'hlvr_addresources 0 0 4 0',
        snd = 'Inventory.DepositItem'
    },
    item_hlvr_clip_rapidfire = {
        cmd = 'hlvr_addresources 0 30 0 0',
        snd = 'Inventory.DepositItem'
    },
    item_hlvr_crafting_currency_small = {
        cmd = 'hlvr_addresources 0 0 0 1',
        snd = 'Inventory.BackpackGrabItemResin' -- does it actually use this?
    },
    item_hlvr_crafting_currency_large = {
        cmd = 'hlvr_addresources 0 0 0 5',
        snd = 'Inventory.BackpackGrabItemResin' -- does it actually use this?
    },
}

local function checkItem(_, ioparams)
    print('in checker')
    local activator = ioparams.activator

    if not IsValidEntity(activator) then return end
    ---@cast activator -nil

    local class = activator:GetClassname()
    local itemInfo = itemClasses[class]

    if not itemInfo then
        devprint2('Did not collect ' .. class .. ' because it is not in the item list')
        return
    end

    if Convars:GetBool('auto_pickup_ignore_held_items') then
        if Player:IsHolding(activator) then
            devprint2('Did not collect ' .. class .. ' because the player is holding it')
            return
        end
    end

    if not collector:IsCollectableItem(activator) then
        devprint2('Did not collect ' .. class .. ' because it is not collectable')
        return
    end

    if Convars:GetBool('auto_pickup_require_los') and not util.LosWithPlayer(activator) then
        devprint2('Did not collect ' .. class .. ' because player does not have line of sight')
        return
    end

    -- All checks passed, collect the item!

    local time = Time()
    if time - lastSoundTime > SND_MIN_TIME then
        -- EmitSoundOnClient(itemInfo.snd, Player)
        EmitSoundOn(itemInfo.snd, Player)
        lastSoundTime = time
    end

    if class == 'item_hlvr_clip_energygun' and partialClipStorageEnabled then
        ---@diagnostic disable-next-line: undefined-global
        local bulletCount = GetBulletCountFromPistolClip(activator)
        SendToServerConsole('hlvr_addresources ' .. bulletCount .. ' 0 0 0')
    else
        -- add the ammo/resin
        SendToConsole(itemInfo.cmd)
    end

    devprint2('Auto pickup collected ' .. class)

    -- remove the item from the world
    UTIL_Remove(activator)
end

local function onEndTouch(_, ioparams)
    local ent = ioparams.activator

    if not IsValidEntity(ent) then return end
    ---@cast ent -nil

    -- clear the IgnoreCollector flag so the item can be collected again
    -- if the player drops it and picks it up again
    if ent:GetIntAttr('IgnoreCollector') == 1 and not Player:IsHolding(ent) then
        ent:SetIntAttr('IgnoreCollector', 0)
    end
end

function collector:Init(parent)

    local filter = util.CreateFilterMultiClass(unpack(TableKeys(itemClasses)))
    filter:SetEntityName('_auto_pickup_collector_filter')

    local trigger = SpawnEntityFromTableSynchronous('trigger_multiple',
        {
            targetname='_auto_pickup_collector_trigger',
            spawnflags='4104', -- only physics objects
            model='models/auto_pickup/collector_trigger.vmdl',
            origin=Player:GetOrigin(),
	        filtername = filter:GetName(),
	        wait = tostring(TRIGGER_UPDATE_INTERVAL),
        })
    trigger:SetParent(parent, nil)
    trigger:ResetLocal()

    -- Player z stands on top of physics ents even if it's not visually shown
    -- moving the trigger down helps mitigate misses when an item is next to a prop
    trigger:SetLocalOrigin(Vector(0, 0, -16))

    trigger:RedirectOutputFunc('OnStartTouch', checkItem)
    trigger:RedirectOutputFunc('OnEndTouch', onEndTouch)

    -- constant triggering helps position into LOS while still touching
    trigger:RedirectOutputFunc('OnTrigger', checkItem)
end

---Checks if an entity is collectable by `collector`.
---@param ent EntityHandle
---@return boolean
function collector:IsCollectableItem(ent)
    if not IsValidEntity(ent) then return false end
    if ent:GetIntAttr('IgnoreCollector') == 1 then return false end

    local class = ent:GetClassname()
    if itemClasses[class] == nil then return false end

    local parent = ent:GetMoveParent()
    if parent then
        if parent:IsNPC() then return false end
        if parent:GetClassname() == 'prop_hlvr_crafting_station_console' then return false end
    end

    if class == 'item_hlvr_clip_energygun' then
        if not partialClipStorageEnabled and ent:GetIntAttr('ClipHasBeenChambered') == 1 then
            -- don't collect clips that have been chambered, because they're now partly empty
            return false
        end
    end

    if class == 'item_hlvr_clip_rapidfire' then
        -- don't collect empty rapidfire clips
        if not ent:GetFirstChildWithClassname('hlvr_weapon_rapidfire_ammo_capsule') then
            return false
        end
    end

    return true
end

---Gets the collection trigger entity if it exists.
---@return EntityHandle?
function collector:GetTrigger()
    return Entities:FindByName(nil, '_auto_pickup_collector_trigger')
end

---If an item is grav pulled we don't want to collect it,
---because the player is intentionally trying to pick it up.
---@param event GameEventGrabbityGlovePull
ListenToGameEvent('grabbity_glove_pull', function (event)
    if not Convars:GetBool('auto_pickup_ignore_grav_pulled') then return end

    local ent = EntIndexToHScript(event.entindex)

    if not IsValidEntity(ent) then return end
    ---@cast ent -nil

    if collector:IsCollectableItem(ent) then
        ent:SetIntAttr('IgnoreCollector', 1)
    end

end, nil)

if not util.IsPartialClipStorageEnabled() then
    ---If the player chambers a round from a clip, we shouldn't collect that clip because it's now partly empty.
    ---Don't know of a better way to detect partly empty clips.
    ---@param event GameEventPlayerPistolChamberedRound
    ListenToGameEvent('player_pistol_chambered_round', function (event)

        local pistol = Player.Items.weapons.energygun
        if not IsValidEntity(pistol) then
            warn('Could not find player pistol to check for chambered round')
            return
        end
        ---@cast pistol -nil

        local clip = pistol:GetFirstChildWithClassname('item_hlvr_clip_energygun')
        if IsValidEntity(clip) then
            ---@cast clip -nil
            clip:SetIntAttr('ClipHasBeenChambered', 1)
        end
    end, nil)
end

return collector