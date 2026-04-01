--[[
    Debug menu controls for auto pickup.
]]

DebugMenu:AddCategory('auto_pickup', 'Auto Pickup')
DebugMenu:AddToggle('auto_pickup', 'los', 'Require line of sight', 'auto_pickup_require_los')
DebugMenu:AddToggle('auto_pickup', 'held', 'Ignore held items', 'auto_pickup_ignore_held_items')
DebugMenu:AddToggle('auto_pickup', 'grav', 'Ignore grav pulled items', 'auto_pickup_ignore_grav_pulled')