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


-- The area a garage works in: a square of tiles around it, the way a roboport covers a square, not a circle.
garage_area = function(position)
    local reach = shared.garage.radius
    local x = position.x or position[1]
    local y = position.y or position[2]
    return {
        { x - reach, y - reach },
        { x + reach, y + reach },
    }
end


-- Two garages are on the same network when the areas they cover touch, which is how roboports join up
garages_touch = function(one, other)
    local reach = shared.garage.radius * 2
    return math.abs(one.position.x - other.position.x) <= reach
        and math.abs(one.position.y - other.position.y) <= reach
end


-- Garages whose area covers this position. The square is symmetric, so asking which garages sit inside the square
-- around the position gives the same answer.
get_garages_in_range = function(surface, position, force)
    return surface.find_entities_filtered {
        name = shared.entities.drone_garage,
        area = garage_area(position),
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
            area = garage_area(garage.position),
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


-- Garages whose areas touch join into one network, and a garage in the middle chains two that do not touch each
-- other, exactly like roboports. What one of them knows, all of them know.
get_garage_network = function(garage)
    local network = { garage }
    local seen = { [garage.unit_number] = true }
    local index = 1

    while index <= #network do
        local current = network[index]
        index = index + 1

        for _, other in pairs(get_all_garages()) do
            if other.valid and not seen[other.unit_number] and other.surface == garage.surface
                and other.force == garage.force and garages_touch(current, other) then
                seen[other.unit_number] = true
                network[#network + 1] = other
            end
        end
    end

    return network
end


-- A chest holds what it holds, but a drone only knows about the ones wired to a garage. Any garage on the same
-- network will do, the way any chest on a logistic network serves the whole network.
-- Returns the closest usable chest, or nil, which means the player carries it or nobody does.
find_wired_chest = function(force, surface, position, item_name, quality, count)
    local quality_name = quality and (type(quality) == "string" and quality or quality.name) or "normal"
    local wanted = { name = item_name, quality = quality_name }

    local candidates = {}
    local asked = {}
    for _, garage in pairs(get_garages_in_range(surface, position, force)) do
        for _, networked in pairs(get_garage_network(garage)) do
            if not asked[networked.unit_number] then
                asked[networked.unit_number] = true

                for _, chest in pairs(get_wired_chests(networked, force)) do
                    if chest.valid and chest.get_item_count(wanted) >= count then
                        candidates[chest.unit_number] = chest
                    end
                end
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


-- The closest garage of this force on this surface that the test accepts
find_nearest_garage = function(surface, position, force, accept)
    local best, best_distance

    for _, garage in pairs(get_all_garages()) do
        if garage.valid and garage.surface == surface and garage.force == force
            and (not accept or accept(garage)) then
            local dx = garage.position.x - position.x
            local dy = garage.position.y - position.y
            local squared = dx * dx + dy * dy
            if not best_distance or squared < best_distance then
                best, best_distance = garage, squared
            end
        end
    end

    return best, best_distance and best_distance ^ 0.5
end


-- Garages work as one: a drone reports to whichever one is closest to where it finished, not to the one it left
-- from, so over time the drones end up where the work is.
find_home_garage = function(drone, fallback)
    if not (drone and drone.valid) then
        return fallback
    end

    local home = find_nearest_garage(drone.surface, drone.position, drone.force, function(garage)
        local inventory = garage.get_inventory(defines.inventory.chest)
        return inventory and not inventory.is_full()
    end)

    return home or fallback
end


-- Which garage actually hands out the drone: its own if it has any, otherwise the closest one in the network
find_drone_source_garage = function(garage)
    if get_available_drones(garage) > 0 then
        return garage
    end

    local on_the_network = {}
    for _, other in pairs(get_garage_network(garage)) do
        on_the_network[other.unit_number] = true
    end

    return (find_nearest_garage(garage.surface, garage.position, garage.force, function(other)
        return on_the_network[other.unit_number] and other ~= garage and get_available_drones(other) > 0
    end))
end


-- How many drones this owner can still send out of an inventory it can reach
get_spawnable_drones = function(owner)
    if not is_garage(owner) then
        return get_available_drones(owner)
    end

    local source = find_drone_source_garage(owner)
    return source and get_available_drones(source) or 0
end


-- While a garage is on the cursor, the ones already built show their area too, so there is something to line the
-- new one up against. The game only draws the radius of the thing being held.
-- the green the game paints a construction area with, __core__/graphics/visualization-construction-radius.png
local preview_colour = { r = 0.51, g = 0.85, b = 0.22, a = 0.08 }
local preview_border = { r = 0.51, g = 0.85, b = 0.22, a = 0.45 }

clear_garage_previews = function(player_index)
    data.garage_previews = data.garage_previews or {}

    for _, object in pairs(data.garage_previews[player_index] or {}) do
        if object and object.valid then
            object.destroy()
        end
    end
    data.garage_previews[player_index] = nil
end


local holding_a_garage = function(player)
    local stack = player.cursor_stack
    if stack and stack.valid_for_read and stack.name == shared.entities.drone_garage then
        return true
    end

    -- picking one from a blueprint or the ghost cursor counts too
    local ghost = player.cursor_ghost
    return ghost ~= nil and ghost.name and ghost.name.name == shared.entities.drone_garage
end


update_garage_previews = function(player)
    if not (player and player.valid) then
        return
    end

    clear_garage_previews(player.index)

    if not holding_a_garage(player) then
        return
    end

    -- the surface being looked at, so it also helps while planning from the map view
    local surface = player.surface
    local objects = {}

    for _, garage in pairs(get_all_garages()) do
        if garage.valid and garage.surface == surface and garage.force == player.force then
            local area = garage_area(garage.position)

            objects[#objects + 1] = rendering.draw_rectangle {
                color = preview_colour,
                filled = true,
                left_top = area[1],
                right_bottom = area[2],
                surface = surface,
                players = { player },
                draw_on_ground = true,
            }
            objects[#objects + 1] = rendering.draw_rectangle {
                color = preview_border,
                width = 3,
                left_top = area[1],
                right_bottom = area[2],
                surface = surface,
                players = { player },
            }
        end
    end

    data.garage_previews = data.garage_previews or {}
    data.garage_previews[player.index] = objects
end
