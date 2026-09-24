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

should_process_entity = function(entity, player, order_type)
    if not (entity and entity.valid and player and player.valid) then return false end
    if player.force.name ~= entity.force.name and entity.force.name ~= "neutral" then return false end
    local player_surface = player.physical_surface
    if player_surface ~= entity.surface then return false end -- Ensure entity is on player's physical surface

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
        local player = drone_data.player
        if player and player.valid then
            counts[player.index] = (counts[player.index] or 0) + 1
        end
    end

    for player_index, requested in pairs(data.request_count) do
        counts[player_index] = (counts[player_index] or 0) + requested
    end

    return counts
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


-- How many more drones this player may command right now
get_drone_budget = function(player)
    -- Without a controller nobody takes orders, garages or not
    local capacity = get_controller_capacity(player)
    if capacity <= 0 then
        return 0
    end

    return capacity + get_garage_bonus(player) - (active_drone_counts[player.index] or 0)
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
