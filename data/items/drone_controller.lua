local path = util.path("data/units/construction_drone/")
local name = shared.items.drone_controller
local ammo_category = shared.ammo_categories.drone_control

-- The controller sits in a weapon slot, which the character has from the start, unlike the armor grid. It is a gun
-- that can never fire: nothing in the game uses its ammo category.
local gun = {
    type = "gun",
    name = name,
    icon = path .. "logistic_beacon_icon.png",
    icon_size = 150,
    subgroup = "gun",
    order = "a[basic-clips]-a[" .. name .. "]",
    stack_size = 1,
    attack_parameters = {
        type = "projectile",
        ammo_category = ammo_category,
        cooldown = 60,
        range = 0,
        projectile_creation_distance = 0,
    },
}

local recipe = {
    type = "recipe",
    name = name,
    -- unlocked by electronics, see data-final-fixes
    enabled = false,
    energy_required = 2,
    ingredients = {
        { type = "item", name = "electronic-circuit", amount = 10 },
        { type = "item", name = "iron-gear-wheel", amount = 5 },
        { type = "item", name = "iron-plate", amount = 5 },
    },
    results = { { type = "item", name = name, amount = 1 } },
}

data:extend { { type = "ammo-category", name = ammo_category }, gun, recipe }
