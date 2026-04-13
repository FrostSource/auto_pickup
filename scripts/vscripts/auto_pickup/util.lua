
local function isPartialClipStorageEnabled()
    return IsAddonEnabled('3329684800')
end

---Checks if an entity has line of sight with the player.
---@param ent EntityHandle
local function losWithPlayer(ent)
    local trace

    -- check feet
    trace = TraceLineSimple(ent:GetCenter(), Player:GetOrigin() + Vector(0, 0, 8), ent)
    if trace.enthit == Player then return true end

    -- check head
    trace = TraceLineSimple(ent:GetCenter(), Player:EyePosition(), ent)
    if trace.enthit == Player then return true end

    return false
end

---Creates a class filter.
---@param class string
---@param name? string
---@return EntityHandle
local function createFilterClass(class, name)
    return SpawnEntityFromTableSynchronous('filter_activator_class', {
	    filterclass = class,
	    Negated = '0',
        targetname = name or '',
    })
end

local function createFilterMultiClass(...)
    local keys = {
        filtertype = "1",
        Negated = "0",
    }

    for i = 1, 10 do
        local class = select(i, ...)
        if not class then break end

        local fName = '_auto_pickup_filter_' .. class
        local existingFilter = Entities:FindByName(nil, fName)
        if not existingFilter or existingFilter:GetClassname() ~= 'filter_activator_class' then
            createFilterClass(class, fName)
        end

        if i == 10 then
            keys['Filter10'] = fName
        else
            keys['Filter0' .. i] = fName
        end
    end

    return SpawnEntityFromTableSynchronous('filter_multi', keys)
end

return {
    IsPartialClipStorageEnabled = isPartialClipStorageEnabled,
    LosWithPlayer = losWithPlayer,
    CreateFilterClass = createFilterClass,
    CreateFilterMultiClass = createFilterMultiClass,
}
