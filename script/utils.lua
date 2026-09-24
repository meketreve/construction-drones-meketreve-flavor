local sin, cos = math.sin, math.cos
local angle = util.angle
local floor = math.floor
local random = math.random

unique_index = function(entity)
    if entity.unit_number then
        return entity.unit_number
    end
    return entity.surface.index .. entity.name .. entity.position.x .. entity.position.y
end

is_commandable = function(string)
    return drone_prototypes[string] ~= nil
end

get_prototype = function(name)
    if prototype_cache[name] then
        return prototype_cache[name]
    end
    logs.trace("searching for prototype by name:" .. name)
    local prototype = prototypes.entity[name]
    prototype_cache[name] = prototype
    return prototype
end

getPlayerSurface = function(player)
    if player.controller_type == defines.controllers.remote then -- remote map view
        return player.physical_surface
    else
        return player.surface
    end
end


getPlayerPosition = function(player)
    if not settings.global["remote-view-spawn"].value and (player.controller_type == defines.controllers.remote) then -- remote map view
        logs.debug("returning physical location")
        return player.physical_position
    else
        return player.position
    end
end

get_beam_orientation = function(source_position, target_position)
    -- Angle in rads
    local beam_angle = angle(target_position, source_position)

    -- Convert to orientation
    local orientation = (beam_angle / (2 * math.pi)) - 0.25
    if orientation < 0 then
        orientation = orientation + 1
    end

    local x, y = 0, 0.5

    --[[x = x cos θ − y sin θ
    y = x sin θ + y cos θ]]
    beam_angle = beam_angle + (math.pi / 2)
    local x1 = (x * cos(beam_angle)) - (y * sin(beam_angle))
    local y1 = (x * sin(beam_angle)) + (y * cos(beam_angle))

    return orientation, { x1, y1 - 0.5 }
end

-- The drones answer either to a player or to a garage. These few helpers are everything the job pipeline needs
-- to know about which one it is dealing with.
is_garage = function(owner)
    return owner.object_name == "LuaEntity"
end


owner_key = function(owner)
    if is_garage(owner) then
        return "g" .. owner.unit_number
    end
    return "p" .. owner.index
end


owner_force = function(owner)
    return owner.force
end


owner_surface = function(owner)
    if is_garage(owner) then
        return owner.surface
    end
    return owner.physical_surface
end


owner_position = function(owner)
    if is_garage(owner) then
        return owner.position
    end
    return getPlayerPosition(owner)
end


-- Where a drone leaves from. A garage is a building, so its own tile is solid: paths that start inside it fail,
-- and so does spawning there.
owner_spawn_position = function(owner)
    if not is_garage(owner) then
        return owner_position(owner)
    end

    local free = owner.surface.find_non_colliding_position(
        "normal-" .. shared.units.construction_drone,
        owner.position,
        8,
        0.5,
        false
    )
    return free or owner.position
end


-- The entity the drones take items from and bring them back to
owner_container = function(owner)
    if is_garage(owner) then
        return owner
    end
    return owner.character
end


owner_cheat_mode = function(owner)
    if is_garage(owner) then
        return false
    end
    return owner.cheat_mode
end


-- Per user settings have no meaning for a garage, it falls back to what the setting ships with
owner_setting = function(owner, name)
    if is_garage(owner) then
        return prototypes.mod_setting[name].default_value
    end
    return settings.get_player_settings(owner)[name].value
end


owner_item_count = function(owner, item)
    local container = owner_container(owner)
    if not (container and container.valid) then
        return 0
    end
    return container.get_item_count(item)
end


should_process_entity = function(entity, owner, order_type)
    if not (entity and entity.valid and owner and owner.valid) then return false end
    if owner_force(owner).name ~= entity.force.name and entity.force.name ~= "neutral" then return false end
    if owner_surface(owner) ~= entity.surface then return false end

    -- A garage answers to nobody, it works on anything of its own force in its area
    if is_garage(owner) then return true end

    local player = owner

    -- Map drone order type to the corresponding setting
    local setting_name
    if order_type == drone_orders.construct then
        setting_name = "drone_process_other_player_construction"
    elseif order_type == drone_orders.deconstruct then
        setting_name = "drone_process_other_player_deconstruction"
    elseif order_type == drone_orders.upgrade then
        setting_name = "drone_process_other_player_upgrade"
    elseif order_type == drone_orders.request_proxy then
        setting_name = "drone_process_other_player_proxies"
    else
        return true  -- For unsupported types (repair, cliff_deconstruct), process as original
    end

    -- Check the player's runtime setting
    local process_others = settings.get_player_settings(player)[setting_name].value
    if process_others then
        return true  -- Setting enabled: process any valid entity, including other players'
    else
        -- Setting disabled: only process if last_user matches the player or is nil (for neutral entities)
        return entity.last_user == nil or entity.last_user == player
    end
end

get_radius_map = function()
    -- Caching radius map, deliberately not local or data
    if radius_map then
        return radius_map
    end
    radius_map = {}
    for k, entity in pairs(prototypes.entity) do
        radius_map[k] = entity.radius
    end
    return radius_map
end

get_radius = function(entity, range, goto_entity)
    -- Handle non-entity targets (e.g., plain positions) by returning 0 to avoid errors in radius lookups
    if not entity.name then
        return 0
    end
    local radius
    local type = entity.type
    if type == ghost_type then
        radius = get_radius_map()[entity.ghost_name]
    elseif type == cliff_type then
        radius = entity.get_radius() * 2
    elseif is_commandable(entity.name) then
        if range == ranges.interact then
            radius = get_radius_map()[entity.name] + 5
        elseif range == ranges.return_to_character then
            radius = get_radius_map()[entity.name] - 1
        else
            radius = get_radius_map()[entity.name]
        end
    elseif goto_entity then
        return 0
    else
        radius = get_radius_map()[entity.name]
    end

    if radius < min_radius then
        return min_radius
    end
    return radius
end

distance = function(position_1, position_2)
    local x1 = position_1[1] or position_1.x
    local y1 = position_1[2] or position_1.y
    local x2 = position_2[1] or position_2.x
    local y2 = position_2[2] or position_2.y
    return (((x2 - x1) * (x2 - x1)) + ((y2 - y1) * (y2 - y1))) ^ 0.5
end

in_construction_range = function(drone, target)
    local distance = distance(drone.position, target.position) - 2
    return distance <= ((get_radius(drone, ranges.interact) + (get_radius(target))))
end

validate = function(entities)
    for k, entity in pairs(entities) do
        if not entity.valid then
            entities[k] = nil
        end
    end
    return entities
end

get_build_time = function()
    return random(15, 25)
end

unit_clear_target = function(unit, target)
    local r = get_radius(unit) + get_radius(target) + 1
    local position = { x = true, y = true }
    if unit.position.x > target.position.x then
        position.x = unit.position.x + r
    else
        position.x = unit.position.x - r
    end
    if unit.position.y > target.position.y then
        position.y = unit.position.y + r
    else
        position.y = unit.position.y - r
    end
    unit.speed = unit.prototype.speed
    unit.commandable.set_command { type = defines.command.go_to_location, destination = position, radius = 1 }
end

get_extra_target = function(drone_data)
    if not drone_data.extra_targets then
        return
    end
    drone_data.extra_targets = validate(drone_data.extra_targets)

    local any = next(drone_data.extra_targets)
    if not any then
        drone_data.extra_targets = nil
        return
    end

    local next_target = drone_data.entity.surface.get_closest(drone_data.entity.position, drone_data.extra_targets)
    if next_target then
        drone_data.target = next_target
        drone_data.extra_targets[unique_index(next_target)] = nil
        return next_target
    end
end

has_flag = function(entity, tag_name)
    -- Validate the entity
    if not (entity and entity.valid) then
        return false -- Entity is invalid or nil, so no tags exist
    end

    -- Get the tags table from the entity
    -- LuaEntity.tags returns a table of key-value pairs or nil if no tags are set
    local flags = entity.flags
    if not flags then
        return false -- No tags table exists, so the tag doesn't exist
    end

    -- Check if the tag exists in the tags table
    -- tags[tag_name] will be nil if the tag doesn't exist, or its value if it does
    return flags[tag_name] ~= nil
end

get_entity_flag = function(entity, tag_name)
    if has_flag(entity, tag_name) then
        return entity.flags[tag_name]
        else return nil
    end
end

use_spectral_drones = function(player)
    if player.force.technologies["spectral-drones"] and player.force.technologies["spectral-drones"].researched then
        return true
    end
    return false
end

get_collision_mask = function(player)
    local collision_mask_to_use = shared.default_collision_mask
    if player.force.technologies["spectral-drones"] and player.force.technologies["spectral-drones"].researched then
        collision_mask_to_use = shared.spectral_collision_mask 
    end
    return collision_mask_to_use
end

inspect_item_properties = function(inspection, item)
    if inspection then game.print(inspection) end
    if not item then return end
    for key, value in pairs(item) do
        if type(value) == "table" then
            game.print(key .. ": (table)")
            for sub_key, sub_value in pairs(value) do
                game.print("  " .. sub_key .. ": " .. tostring(sub_value))
            end
        else
            game.print(key .. ": " .. tostring(value))
        end
    end
end

console = function(string)
    game.print(string)
    log(string)
end

-- The controller is a gun, and the character has weapon slots from the start, unlike the armor grid. Every
-- controller in a weapon slot adds its own capacity, so you can trade weapon slots for drones.
get_controller_capacity = function(player)
    local character = player.character
    if not (character and character.valid) then
        return 0
    end

    local guns = character.get_inventory(defines.inventory.character_guns)
    if not guns then
        return 0
    end

    local controller_name = shared.items.drone_controller
    local capacity = 0
    for index = 1, #guns do
        local stack = guns[index]
        if stack and stack.valid_for_read and stack.name == controller_name then
            local quality = stack.quality and stack.quality.name or "normal"
            capacity = capacity + (shared.controller_capacity[quality] or shared.controller_capacity.normal)
        end
    end

    return capacity
end


-- Drones already out, plus the ones whose path is still being calculated, per player index
count_active_drones = function()
    local counts = {}

    for _, drone_data in pairs(data.drone_commands) do
        local owner = drone_data.owner
        if owner and owner.valid then
            local key = owner_key(owner)
            counts[key] = (counts[key] or 0) + 1
        end
    end

    for key, requested in pairs(data.request_count) do
        counts[key] = (counts[key] or 0) + requested
    end

    return counts
end


-- Every garage on every surface, cached and refreshed on a slow beat, plus whenever one is built or mined
local all_garages_cache
local all_garages_tick = -1000
local all_garages_interval = 300

invalidate_garage_cache = function()
    all_garages_tick = -1000
end


get_all_garages = function()
    if all_garages_cache and all_garages_tick + all_garages_interval > game.tick then
        -- One of them may have been mined since the list was built
        local still_there = {}
        for _, garage in pairs(all_garages_cache) do
            if garage.valid then
                still_there[#still_there + 1] = garage
            end
        end
        all_garages_cache = still_there
        return all_garages_cache
    end

    local garages = {}
    for _, surface in pairs(game.surfaces) do
        for _, garage in pairs(surface.find_entities_filtered { name = shared.entities.drone_garage }) do
            garages[#garages + 1] = garage
        end
    end

    all_garages_cache = garages
    all_garages_tick = game.tick
    return garages
end


-- Garages whose area covers this position. Looked up rarely, the answer only changes when one is built or mined.
get_garages_in_range = function(surface, position, force)
    return surface.find_entities_filtered {
        name = shared.entities.drone_garage,
        position = position,
        radius = shared.garage.radius,
        force = force,
    }
end


-- Each garage covering the player lends its own processing to the controller
local garage_bonus_cache = {}
local garage_bonus_interval = 120

get_garage_bonus = function(player)
    local index = player.index
    local cached = garage_bonus_cache[index]
    if cached and cached.tick + garage_bonus_interval > game.tick then
        return cached.bonus
    end

    local bonus = 0
    local character = player.character
    if character and character.valid then
        bonus = #get_garages_in_range(player.physical_surface, getPlayerPosition(player), player.force)
            * shared.garage.drone_bonus
    end

    garage_bonus_cache[index] = { tick = game.tick, bonus = bonus }
    return bonus
end


-- How many more drones this owner may command right now
get_drone_budget = function(owner)
    if is_garage(owner) then
        return shared.garage.drone_bonus - (active_drone_counts[owner_key(owner)] or 0)
    end

    -- Without a controller nobody takes orders
    local capacity = get_controller_capacity(owner)
    if capacity <= 0 then
        return 0
    end

    return capacity + get_garage_bonus(owner) - (active_drone_counts[owner_key(owner)] or 0)
end


-- The closest garage that still has room, for a drone that wants to get rid of its cargo
find_garage_for_dropoff = function(drone)
    local garages = get_garages_in_range(drone.surface, drone.position, drone.force)
    if #garages == 0 then
        return
    end

    local closest = drone.surface.get_closest(drone.position, garages)
    if not (closest and closest.valid) then
        return
    end

    local inventory = closest.get_inventory(defines.inventory.chest)
    if inventory and not inventory.is_full() then
        return closest
    end
end


local wire_connector_ids = { defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green }
local chest_types = { "container", "logistic-container" }

-- Chests wired to this garage, on either colour. Rebuilt every couple of seconds, since it only changes when
-- somebody lays a wire or builds a chest.
local wired_chest_cache = {}
local wired_chest_interval = 120

local get_wired_chests = function(garage, force)
    local cached = wired_chest_cache[garage.unit_number]
    if cached and cached.tick + wired_chest_interval > game.tick then
        return cached.chests
    end

    local networks = {}
    for _, connector_id in pairs(wire_connector_ids) do
        local network = garage.get_circuit_network(connector_id)
        if network then
            networks[connector_id] = network.network_id
        end
    end

    local chests = {}
    if next(networks) then
        for _, chest in pairs(garage.surface.find_entities_filtered {
            type = chest_types,
            position = garage.position,
            radius = shared.garage.radius,
            force = force,
        }) do
            for connector_id, network_id in pairs(networks) do
                local chest_network = chest.get_circuit_network(connector_id)
                if chest_network and chest_network.network_id == network_id then
                    chests[#chests + 1] = chest
                    break
                end
            end
        end
    end

    wired_chest_cache[garage.unit_number] = { tick = game.tick, chests = chests }
    return chests
end


-- A chest holds what it holds, but a drone only knows about the ones wired to a garage that covers the job.
-- Returns the closest such chest holding the item, or nil, which means the player carries it or nobody does.
find_wired_chest = function(force, surface, position, item_name, quality, count)
    local quality_name = quality and (type(quality) == "string" and quality or quality.name) or "normal"
    local wanted = { name = item_name, quality = quality_name }

    local candidates = {}
    for _, garage in pairs(get_garages_in_range(surface, position, force)) do
        for _, chest in pairs(get_wired_chests(garage, force)) do
            if chest.valid and chest.get_item_count(wanted) >= count then
                candidates[chest.unit_number] = chest
            end
        end
    end

    if not next(candidates) then
        return
    end

    return surface.get_closest(position, candidates)
end


-- Where the drone should pick the item up: nil means the player carries it, an entity means go there
find_item_source = function(owner, entity, item_name, quality, count)
    if owner_cheat_mode(owner) then
        return
    end

    if owner_item_count(owner, { name = item_name, quality = quality }) >= count then
        return
    end

    return find_wired_chest(owner_force(owner), entity.surface, entity.position, item_name, quality, count)
end


-- The antenna on top of a garage is a rendered animation, since a container prototype can only hold a still
-- picture. One per garage, kept in storage so it survives a save.
local antenna_name = shared.entities.drone_garage .. "-antenna"

add_garage_antenna = function(garage)
    if not (garage and garage.valid and garage.name == shared.entities.drone_garage) then
        return
    end

    data.garage_antennas = data.garage_antennas or {}
    local existing = data.garage_antennas[garage.unit_number]
    if existing and existing.valid then
        return
    end

    data.garage_antennas[garage.unit_number] = rendering.draw_animation {
        animation = antenna_name,
        target = garage,
        surface = garage.surface,
        render_layer = "higher-object-above",
    }
end


remove_garage_antenna = function(unit_number)
    if not (unit_number and data.garage_antennas) then
        return
    end

    local antenna = data.garage_antennas[unit_number]
    if antenna and antenna.valid then
        antenna.destroy()
    end
    data.garage_antennas[unit_number] = nil
end


refresh_garage_antennas = function()
    data.garage_antennas = data.garage_antennas or {}

    for unit_number, antenna in pairs(data.garage_antennas) do
        if not (antenna and antenna.valid) then
            data.garage_antennas[unit_number] = nil
        end
    end

    invalidate_garage_cache()
    for _, garage in pairs(get_all_garages()) do
        add_garage_antenna(garage)
    end
end
