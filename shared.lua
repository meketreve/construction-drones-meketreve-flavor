-- Shared data interface between data and script, notably prototype names.
local data = {}
data.drones = {}

data.drone_quality = {
    ["normal"] = {
        max_health = 45,
        movement_speed = 0.2,
        inventory_size = 4
    },
    ["uncommon"] = {
        max_health = 60,
        movement_speed = 0.3,
        inventory_size = 6
    },
    ["rare"] = {
        max_health = 75,
        movement_speed = 0.6,
        inventory_size = 8
    },
    ["epic"] = {
        max_health = 120,
        movement_speed = 0.8,
        inventory_size = 12
    },
    ["legendary"] = {
        max_health = 240,
        movement_speed = 1.2,
        inventory_size = 16
    }
}
data.units = { construction_drone = "Construction_Drone" }
data.bounding_box = { { -0.01, -0.01 }, { 0.01, 0.01 } }
data.default_collision_mask = { not_colliding_with_itself = true, consider_tile_transitions = true, layers = {
    construction_drone = true
}}
data.spectral_collision_mask = { not_colliding_with_itself = true, colliding_with_tiles_only = true, layers = {
    water_tile = true,
    lava_tile = true
}}

data.entities = {
    construction_drone_proxy_chest = "Construction_Drone_Proxy_Chest",
    drone_garage = "drone-garage",
}

data.technologies = { drone_garage = "drone-garage" }

data.garage = {
    -- How far from a garage its help reaches
    radius = 32,
    -- How many more drones you command while inside a garage area
    drone_bonus = 5,
    -- Garages join up the way roboports do: when the areas they cover touch. Nothing else to configure.
}

data.items = { drone_controller = "drone-controller" }

data.ammo_categories = { drone_control = "drone-control" }

-- How many drones one controller commands at the same time, per quality of the controller
data.controller_capacity = {
    ["normal"] = 5,
    ["uncommon"] = 7,
    ["rare"] = 9,
    ["epic"] = 12,
    ["legendary"] = 16,
}

data.beams = {
    build = "Build_beam",
    deconstruction = "Deconstruct_Beam",
    pickup = "Pickup_Beam",
    dropoff = "Dropoff_Beam",
    attack = "Attack_Beam",
}

return data
