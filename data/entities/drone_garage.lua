local path = util.path("data/units/construction_drone/")
local name = shared.entities.drone_garage
local technology_name = shared.technologies.drone_garage

local graphics = util.path("data/entities/graphics/")

-- The sprites are drawn at 64 pixels per tile, so they are placed at half scale. The footprint centre of the
-- building sits 32 pixels below the middle of its canvas, hence the shift on the picture.

-- A steel chest to start from, because it already carries a circuit connector and the wire reach, which is the
-- whole point of the garage: the chests you wire to it are what the drones may take from.
local garage = util.copy(data.raw.container["steel-chest"])
garage.name = name
garage.icon = graphics .. "drone_garage_icon.png"
garage.icon_size = 64
garage.inventory_size = 20
garage.minable = { mining_time = 0.5, result = name }
garage.next_upgrade = nil
garage.fast_replaceable_group = nil
garage.max_health = 350
garage.corpse = "big-remnants"
garage.dying_explosion = "medium-explosion"
garage.collision_box = { { -1.35, -1.35 }, { 1.35, 1.35 } }
garage.selection_box = { { -1.5, -1.5 }, { 1.5, 1.5 } }
-- The wires keep the chest connector, which lands them near the middle of the platform
garage.circuit_wire_max_distance = 12
-- Shows the area the garage works in, while its item is on the cursor or the garage itself is selected, the same
-- way a roboport shows its construction area.
garage.radius_visualisation_specification = {
    sprite = {
        filename = "__core__/graphics/visualization-construction-radius.png",
        priority = "extra-high-no-scale",
        width = 12,
        height = 12,
    },
    distance = shared.garage.radius,
    draw_in_cursor = true,
    draw_on_selection = true,
}
garage.picture = {
    layers = {
        {
            filename = graphics .. "drone_garage_base.png",
            width = 256,
            height = 256,
            scale = 0.5,
            shift = { 0, -0.5 },
        },
    },
}

-- The antenna turning on the roof is the roboport one, drawn over the garage by the control stage, since a
-- container prototype can only hold a still picture.
local antenna = {
    type = "animation",
    name = name .. "-antenna",
    filename = "__base__/graphics/entity/roboport/roboport-base-animation.png",
    priority = "medium",
    width = 83,
    height = 59,
    frame_count = 8,
    animation_speed = 0.5,
    scale = 0.5,
    shift = { 0, -0.48 },
}

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
    icon = graphics .. "drone_garage_icon.png",
    icon_size = 64,
    effects = { { type = "unlock-recipe", recipe = name } },
    prerequisites = { "radar" },
    unit = {
        count = 75,
        ingredients = { { "automation-science-pack", 1 } },
        time = 20,
    },
    order = "c-k-a",
}

data:extend { garage, antenna, item, recipe, technology }
