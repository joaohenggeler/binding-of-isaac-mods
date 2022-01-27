--[[
?)]]
-- ################################################## PLANETOIDS FAMILIARS ##################################################
-- Gives Isaac 3 orbitals:
-- Sun: orbits Isaac; deals light contact damage + 1/5 to apply burn to the enemy
-- 			transforms tears that touch it into Fire Mind tears (adds burn flag)
-- Earth: orbits the Earth; deals very light contact damage + 1/5 to spawn small puddle of blue creep
-- 			transforms Fire Mind tears that touch it into regular ones (removes burn flag)
-- Moon: orbits the Earth; deals extremely light contact damage + 1/5 to apply confusion to the enemy

local ZERO_VECTOR = Vector(0, 0)

local Planetoids = {
	COLLECTIBLE_PLANETOIDS = Isaac.GetItemIdByName("Planetoids") -- item ID	
}

local PlanetoidsSun = {
	VARIANT = Isaac.GetEntityVariantByName("Planetoid Sun"), -- familiar variant
	ORBIT_DISTANCE = Vector(120.0, 120.0), -- circular orbit with a radius of 120.0
	ORBIT_CENTER_OFFSET = Vector(0.0, 0.0), -- move orbit center away from the player
	ORBIT_LAYER = 122, -- orbitals in the same layer are separated accordingly when spawned
	ORBIT_SPEED = 0.005, -- usually below 0.1 (too much more and it's too damn fast)
	BURN_CHANCE = 5, -- 1 in CHANCE to apply burn to enemies on contact
	BURN_DURATION = 30, -- how long the above lasts for in 
	BURN_DAMAGE = 0.3, -- 
	TEAR_FLAGS = TearFlags.TEAR_BURN -- flags applied if a tear hits the Sun
}

local PlanetoidsEarth = {
	VARIANT = Isaac.GetEntityVariantByName("Planetoid Earth"), -- familiar variant
	ORBIT_DISTANCE = Vector(60.0, 60.0), -- circular orbit with a radius of 60.0
	ORBIT_CENTER_OFFSET = Vector(0.0, 0.0), -- move orbit center away from the player
	ORBIT_LAYER = 123, -- orbitals in the same layer are separated accordingly when spawned
	ORBIT_SPEED = 0.04, -- usually below 0.1 (too much more and it's too damn fast)
	CREEP_CHANCE = 5 -- 1 in CHANCE to spawn blue creep on contact with an enemy
}

local PlanetoidsMoon = {
	VARIANT = Isaac.GetEntityVariantByName("Planetoid Moon"), -- familiar variant
	ORBIT_DISTANCE = Vector(20.0, 20.0), -- circular orbit with a radius of 20.0
	ORBIT_CENTER_OFFSET = Vector(0.0, 0.0), -- move orbit center away from the player
	ORBIT_LAYER = 124, -- orbitals in the same layer are separated accordingly when spawned
	ORBIT_SPEED = 0.12, -- usually below 0.1 (too much more and it's too damn fast)
	CONFUSION_CHANCE = 5, -- 1 in CHANCE to apply confusion to enemies on contact
	CONFUSION_DURATION = 30 -- how long the above lasts for in 
}

-- Returns true if entity_1 and entity_2 (Entity) are touching each other. Otherwise false.
-- Simple collisions (not useful for lasers). Doesn't take into account sprite offset.
local function are_entities_colliding(entity_1, entity_2)
	return entity_1.Position:Distance(entity_2.Position) <= entity_1.Size + entity_2.Size
end

-- Assign parent-child relationship of Sun, Earth and Moon orbitals for the Planetoids item.
-- Necessary for save/exit and continue with multiple Planetoid items.
local function assign_planetoids()

	local sun, earth, moon
	local sun_flag, earth_flag, moon_flag = false, false, false

	local entities = Isaac.GetRoomEntities() -- spawn order
	for i = #entities, 1, -1 do -- cycle from the most to least recently spawned familiars

		-- This is kinda messy and probably somewhat unnecessary, sorry
		if sun_flag and earth_flag and moon_flag then

			-- assign parent-child relationships to last planetoids familiars
			earth.Parent = sun
			earth.Child = moon
			moon.Parent = earth

			sun_flag, earth_flag, moon_flag = false, false, false
			sun, earth, moon = nil, nil, nil
		end

		if entities[i].Type == EntityType.ENTITY_FAMILIAR then

			local familiar = entities[i]:ToFamiliar()

			if familiar.Variant == PlanetoidsSun.VARIANT and not sun_flag then
				sun = familiar
				sun_flag = true
			elseif familiar.Variant == PlanetoidsEarth.VARIANT and not earth_flag then
				earth = familiar
				earth_flag = true
			elseif familiar.Variant == PlanetoidsMoon.VARIANT and not moon_flag then
				moon = familiar
				moon_flag = true
			end

		end

	end

end

-- ######################################## SUN

local function init_planetoid_sun(_, sun)
	-- set initial orbit conditions
	sun.OrbitDistance = PlanetoidsSun.ORBIT_DISTANCE
	sun.OrbitSpeed = PlanetoidsSun.ORBIT_SPEED
	sun:AddToOrbit(PlanetoidsSun.ORBIT_LAYER)
end

local function update_planetoid_sun(_, sun)

	sun.OrbitDistance = PlanetoidsSun.ORBIT_DISTANCE -- these need to be constantly updated
	sun.OrbitSpeed = PlanetoidsSun.ORBIT_SPEED
	
	local center_pos = (sun.Player.Position + sun.Player.Velocity) + PlanetoidsSun.ORBIT_CENTER_OFFSET
	local orbit_pos = sun:GetOrbitPosition(center_pos)
	sun.Velocity = orbit_pos - sun.Position

	for _, tear in pairs(Isaac.FindByType(EntityType.ENTITY_TEAR, -1, -1, true, false)) do -- get cached table with every tear

		if are_entities_colliding(sun, tear) then
			-- NOTE: changing variant to the same on can make the tear sprite invisible
			if tear.Variant ~= TearVariant.FIRE_MIND then
				tear = tear:ToTear() -- cast to EntityTear
				tear:ChangeVariant(TearVariant.FIRE_MIND) -- visual effect to a Fire Mind tear
				tear.TearFlags = tear.TearFlags | PlanetoidsSun.TEAR_FLAGS -- add burn flag
			end
		end
	end
end

-- Called when an entities collides with the Sun orbital (doesn't include tears, familiars, pickups, slots, lasers, knives or effects)
-- even with ENTCOLL_ALL.
local function pre_sun_collision(_, sun, collider, low)

	if collider:IsVulnerableEnemy() and math.random(PlanetoidsSun.BURN_CHANCE) == 1 then
		collider:AddBurn(EntityRef(sun), PlanetoidsSun.BURN_DURATION, PlanetoidsSun.BURN_DAMAGE)
	elseif collider.Type == EntityType.ENTITY_BOMBDROP and collider.Variant ~= BombVariant.BOMB_HOT then
		local bomb = collider:ToBomb()
		bomb.Flags = bomb.Flags | PlanetoidsSun.TEAR_FLAGS -- add burn flag
	end

end

-- ######################################## EARTH

local function init_planetoid_earth(_, earth)
	-- set initial orbit conditions
	earth.OrbitDistance = PlanetoidsEarth.ORBIT_DISTANCE
	earth.OrbitSpeed = PlanetoidsEarth.ORBIT_SPEED
	earth:AddToOrbit(PlanetoidsEarth.ORBIT_LAYER)
end

local function update_planetoid_earth(_, earth)

	earth.OrbitDistance = PlanetoidsEarth.ORBIT_DISTANCE -- these need to be constantly updated
	earth.OrbitSpeed = PlanetoidsEarth.ORBIT_SPEED
	
	local center_pos = (earth.Parent.Position + earth.Parent.Velocity) + PlanetoidsEarth.ORBIT_CENTER_OFFSET
	local orbit_pos = earth:GetOrbitPosition(center_pos)
	earth.Velocity = orbit_pos - earth.Position

	for _, tear in pairs(Isaac.FindByType(EntityType.ENTITY_TEAR, -1, -1, true, false)) do -- get cached table with every tear

		if are_entities_colliding(earth, tear) then
			-- NOTE: changing variant to the same on can make the tear sprite invisible
			if tear.Variant == TearVariant.FIRE_MIND then
				tear = tear:ToTear() -- cast to EntityTear
				tear:ChangeVariant(TearVariant.BLUE) --- change visual effect back to a regular tear
				tear.TearFlags = tear.TearFlags & ~PlanetoidsSun.TEAR_FLAGS -- remove burn flag
			end
		end
	end
end

-- Called when an entities collides with the Earth orbital (doesn't include tears, familiars, pickups, slots, lasers, knives or effects)
-- even with ENTCOLL_ALL.
local function pre_earth_collision(_, earth, collider, low)

	if collider:IsVulnerableEnemy() and math.random(PlanetoidsEarth.CREEP_CHANCE) == 1 then
		Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.PLAYER_CREEP_HOLYWATER_TRAIL, 0, earth.Position, ZERO_VECTOR, earth)
	elseif collider.Type == EntityType.ENTITY_BOMBDROP and collider.Variant == BombVariant.BOMB_HOT then
		local bomb = collider:ToBomb()
		bomb.Flags = bomb.Flags & ~PlanetoidsSun.TEAR_FLAGS -- remove burn flag
	end

end

-- ######################################## MOON

local function init_planetoid_moon(_, moon)
	-- set initial orbit conditions
	moon.OrbitDistance = PlanetoidsMoon.ORBIT_DISTANCE
	moon.OrbitSpeed = PlanetoidsMoon.ORBIT_SPEED
	moon:AddToOrbit(PlanetoidsMoon.ORBIT_LAYER)
end

local function update_planetoid_moon(_, moon)

	moon.OrbitDistance = PlanetoidsMoon.ORBIT_DISTANCE -- these need to be constantly updated
	moon.OrbitSpeed = PlanetoidsMoon.ORBIT_SPEED
	
	local center_pos = (moon.Parent.Position + moon.Parent.Velocity) + PlanetoidsMoon.ORBIT_CENTER_OFFSET
	local orbit_pos = moon:GetOrbitPosition(center_pos)
	moon.Velocity = orbit_pos - moon.Position
end

-- Called when an entities collides with the Moon orbital (doesn't include tears, familiars, pickups, slots, lasers, knives or effects)
-- even with ENTCOLL_ALL.
local function pre_moon_collision(_, moon, collider, low)
	if collider:IsVulnerableEnemy() and math.random(PlanetoidsMoon.CONFUSION_CHANCE) == 1 then
		collider:AddConfusion(EntityRef(moon), PlanetoidsMoon.CONFUSION_DURATION, true)
	end
end

-- Handles cache updates
local function update_cache(_, player, cache_flag)

	-- Handle the addition/removal and reallignments of Isaac's familiars/orbitals
	if cache_flag == CacheFlag.CACHE_FAMILIARS then

		-- 1 'Planetoids' item = 1 Sun + 1 Earth + 1 Moon
		local planetoids_pickups = player:GetCollectibleNum(Planetoids.COLLECTIBLE_PLANETOIDS) -- number of 'Planetoids' items
		local planetoids_rng = player:GetCollectibleRNG(Planetoids.COLLECTIBLE_PLANETOIDS) -- respective RNG reference
		player:CheckFamiliar(PlanetoidsSun.VARIANT, planetoids_pickups, planetoids_rng)
		player:CheckFamiliar(PlanetoidsEarth.VARIANT, planetoids_pickups, planetoids_rng)
		player:CheckFamiliar(PlanetoidsMoon.VARIANT, planetoids_pickups, planetoids_rng)
		-- Assign parent-child relationships of Planetoids (we need go through this every time because of exits and continues)
		if planetoids_pickups > 0 then assign_planetoids() end

	end
end

return {
	ID = Planetoids.COLLECTIBLE_PLANETOIDS,
	SUN_VARIANT = PlanetoidsSun.VARIANT,
	EARTH_VARIANT = PlanetoidsEarth.VARIANT,
	MOON_VARIANT = PlanetoidsMoon.VARIANT,

	init_planetoid_sun = init_planetoid_sun,
	update_planetoid_sun = update_planetoid_sun,
	pre_sun_collision = pre_sun_collision,

	init_planetoid_earth = init_planetoid_earth,
	update_planetoid_earth = update_planetoid_earth,
	pre_earth_collision = pre_earth_collision,

	init_planetoid_moon = init_planetoid_moon,
	update_planetoid_moon = update_planetoid_moon,
	pre_moon_collision = pre_moon_collision,

	update_cache = update_cache
}