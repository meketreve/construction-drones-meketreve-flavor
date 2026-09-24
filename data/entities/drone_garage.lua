local path = util.path("data/units/construction_drone/")
local name = shared.entities.drone_garage
local technology_name = shared.technologies.drone_garage

-- The steel chest already carries a circuit connector and the wire reach, which is the whole point of the garage:
-- the chests you wire to it are what the drones may take from.
local garage = util.copy(data.raw.container["steel-chest"])
garage.name = name
garage.icon = path .. "logistic_beacon_icon.png"
garage.icon_size = 150
garage.inventory_size = 20
garage.minable = { mining_time = 0.5, result = name }
garage.next_upgrade = nil
garage.fast_replaceable_group = nil
util.recursive_hack_tint(garage, { r = 0.45, g = 0.8, b = 1 })

local item = util.copy(data.raw.item["steel-chest"])
item.name = name
item.icon = garage.icon
item.icon_size = garage.icon_size
item.place_result = name
item.order = "b[storage]-d[" .. name .. "]"
item.stack_size = 10

local recipe = {
    type = "recipe",
    name = name,
    enabled = false,
    energy_required = 2,
    ingredients = {
        { type = "item", name = "radar", amount = 1 },
        { type = "item", name = "electronic-circuit", amount = 10 },
        { type = "item", name = "iron-plate", amount = 20 },
    },
    results = { { type = "item", name = name, amount = 1 } },
}

local technology = {
    type = "technology",
    name = technology_name,
    icon = path .. "construction_drone_technology.png",
    icon_size = 150,
    effects = { { type = "unlock-recipe", recipe = name } },
    prerequisites = { "radar" },
    unit = {
        count = 75,
        ingredients = { { "automation-science-pack", 1 } },
        time = 20,
    },
    order = "c-k-a",
}

data:extend { garage, item, recipe, technology }
