--[[
    Auto Pickup Convars
]]

EasyConvars:RegisterConvar('auto_pickup_require_los', '1', 'Require line of sight to item to pick it up')
EasyConvars:SetPersistent('auto_pickup_require_los', true)

EasyConvars:RegisterConvar('auto_pickup_ignore_held_items', '1', 'Ignore items currently held in hand')
EasyConvars:SetPersistent('auto_pickup_ignore_held_items', true)

EasyConvars:RegisterConvar('auto_pickup_ignore_grav_pulled', '1', 'Ignore items currently being pulled by the grabbity glove')
EasyConvars:SetPersistent('auto_pickup_ignore_grav_pulled', true)