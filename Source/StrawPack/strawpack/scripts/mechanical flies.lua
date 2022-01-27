--[[
?)]]
-- ################################################## MECHANICAL FLIES FAMILIAR ##################################################
-- Gives Isaac two orbiting flies:
----> Tear colored fly: orbits closest to Isaac and only moves when Isaac is shooting; contact damage scales with Isaac's damage
-- (less than the other fly's but can possibly overtake it with enough tear damage).
----> Body colored fly: orbits furthest away from Isaac and only moves when Isaac moves; contact damage is constant and greater
-- than the other fly's base damage.

-- NOTE: GetOrbitPosition() isn't used here (even though it works fine) because the flies' movement isn't constant (and must be smooth)
-- If you want a more conventional example for orbitals, check out "Planetoids" (3 orbitals in one item)

local MechanicalFlies = {
	COLLECTIBLE_MECHANICAL_FLIES = Isaac.GetItemIdByName("Mechanical Flies") -- item ID
}

-- Given the OrbitDistance attribute from an orbital familiar, its x and y position (Vector) in the orbit at a certain angle is returned.
local function get_orbit_position_from_angle(orbit_distance, center_pos, angle)

	angle = angle % 360 -- in degrees (but passed as radians to math.tan() - see Lua 5.3 manual)

	-- ellipse equation -> x^2 / a^2 + y^2 / b^2 = 1
	local a = orbit_distance.X -- (x) semi-major/minor axis
	local b = orbit_distance.Y -- (y) semi-major/minor axis

	-- handle particular case (angle = 270º)
	if math.abs(angle - 270) < 0.00001 then -- normal method works angle = 90º and 0º <= angle < 360º
		return Vector(0.0, -b) + center_pos
	end

	local x = (a*b) / math.sqrt(b^2 + a^2 * math.tan( math.rad(angle) )^2)

	if 90 < angle and angle < 270 then -- 90º < angle < 270º
		x = -x
	end

	local y = x*math.tan(math.rad(angle))

	return Vector(x, y) + center_pos
end

local MechflyTear = {
	VARIANT = Isaac.GetEntityVariantByName("Mechfly Tear"), -- familiar variant
	ORBIT_DISTANCE = Vector(40.0, 40.0), -- circular orbit with a radius of 40.0
	ORBIT_SPEED = 0.03, -- usually below 0.1 (too much more and it's too damn fast)
	ORBIT_STARTING_ANGLE = 0.0,
	BASE_DAMAGE = 1.0
}

local function init_mechfly_tear(_, fam)
	-- set initial orbit conditions
	fam.OrbitDistance = MechflyTear.ORBIT_DISTANCE
	-- not a usual orbital
end

local function update_mechfly_tear(_, fam)

	fam.OrbitDistance = MechflyTear.ORBIT_DISTANCE -- needs to be constantly updated
	
	-- Center of the orbit (we need to account for player movement, hence adding the velocity)
	local center_pos = fam.Player.Position + fam.Player.Velocity

	local mechfly_tear_data = fam:GetData()
	if mechfly_tear_data.CurrentAngle == nil then -- initialize CurrentAngle
		mechfly_tear_data.CurrentAngle = MechflyTear.ORBIT_STARTING_ANGLE
	end
	-- Where it should be in the orbit around the player
	local orbit_pos = get_orbit_position_from_angle(fam.OrbitDistance, center_pos, mechfly_tear_data.CurrentAngle)

	if fam.Player:GetFireDirection() ~= Direction.NO_DIRECTION then -- player shooting/charging
		mechfly_tear_data.CurrentAngle = mechfly_tear_data.CurrentAngle + 100*MechflyTear.ORBIT_SPEED
		-- *100 so the ORBIT_SPEED is has the same magnitude as the speed of an orbital that uses GetOrbitPosition()

		if math.abs(mechfly_tear_data.CurrentAngle) >= 360 then mechfly_tear_data.CurrentAngle =  mechfly_tear_data.CurrentAngle % 360 end
		--Isaac.DebugString(string.format("XXXXXX Tear angle = %.2f", mechfly_tear_data.CurrentAngle))
	end

	-- Velocity vector that points from the familiar's original position to the one where it should go to next in the orbit
	fam.Velocity = orbit_pos - fam.Position
	
	fam.CollisionDamage = MechflyTear.BASE_DAMAGE + 1.25 * math.sqrt(fam.Player.Damage) -- scales with player damage

end

-- ####################################################
-- Check update_mechfly_tear()'s comments for explanation (ver similar to the next one)
-- Base damage is constant (from XML)

local MechflyBody = {
	VARIANT = Isaac.GetEntityVariantByName("Mechfly Body"), -- familiar variant
	ORBIT_DISTANCE = Vector(80.0, 80.0),
	ORBIT_SPEED = -0.02,
	ORBIT_STARTING_ANGLE = 180.0
}

local function init_mechfly_body(_, fam)
	fam.OrbitDistance = MechflyBody.ORBIT_DISTANCE
	-- not a usual orbital
end

local function update_mechfly_body(_, fam)

	fam.OrbitDistance = MechflyBody.ORBIT_DISTANCE
	
	local center_pos = fam.Player.Position + fam.Player.Velocity

	local mechfly_body_data = fam:GetData()
	if mechfly_body_data.CurrentAngle == nil then
		mechfly_body_data.CurrentAngle = MechflyBody.ORBIT_STARTING_ANGLE
	end

	local orbit_pos = get_orbit_position_from_angle(fam.OrbitDistance, center_pos, mechfly_body_data.CurrentAngle)

	if fam.Player:GetMovementDirection() ~= Direction.NO_DIRECTION then -- moving
		mechfly_body_data.CurrentAngle = mechfly_body_data.CurrentAngle + 100*MechflyBody.ORBIT_SPEED

		if math.abs(mechfly_body_data.CurrentAngle) >= 360 then mechfly_body_data.CurrentAngle =  mechfly_body_data.CurrentAngle % 360 end
		--Isaac.DebugString(string.format("XXXXXX Body angle = %.2f", mechfly_body_data.CurrentAngle))
	end

	fam.Velocity = orbit_pos - fam.Position

end

-- Handles cache updates
local function update_cache(_, player, cache_flag)

	-- Handle the addition/removal and reallignments of Isaac's familiars/orbitals
	if cache_flag == CacheFlag.CACHE_FAMILIARS then

		local mech_fly_pickups =  player:GetCollectibleNum(MechanicalFlies.COLLECTIBLE_MECHANICAL_FLIES) -- number of 'Mechanical Flies' items
		local mech_fly_rng = player:GetCollectibleRNG(MechanicalFlies.COLLECTIBLE_MECHANICAL_FLIES) -- respective RNG reference
		player:CheckFamiliar(MechflyTear.VARIANT, mech_fly_pickups, mech_fly_rng)
		player:CheckFamiliar(MechflyBody.VARIANT, mech_fly_pickups, mech_fly_rng)

	end
end

return {
	ID = MechanicalFlies.COLLECTIBLE_MECHANICAL_FLIES,
	MECHFLY_TEAR_VARIANT = MechflyTear.VARIANT,
	MECHFLY_BODY_VARIANT = MechflyBody.VARIANT,
	init_mechfly_tear = init_mechfly_tear,
	update_mechfly_tear = update_mechfly_tear,
	init_mechfly_body = init_mechfly_body,
	update_mechfly_body = update_mechfly_body,
	update_cache = update_cache
}