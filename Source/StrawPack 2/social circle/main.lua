--[[
)?]]
-- ################################################## SOCIAL CIRCLE TRINKET ##################################################
-- While held, familiars that would normally follow Isaac will now orbit him instead.
-- This only applies to followers in the familiar chain that follows Isaac. One exception to this is Isaac's Heart, which would always follow Isaac.
-- Might not have any effect on modded familiars.

local mod = RegisterMod("social circle", 1)

local game = Game()

local SocialCircle = {
	TRINKET_SOCIAL_CIRCLE = Isaac.GetTrinketIdByName("Social Circle"), -- trinket ID
	ORBIT_SPEED = 0.01, -- orbiting speed for both rings (should be less than 0.1)
	ORBIT_1_NUM = 22, -- max number of followers in the inner orbital ring (closest to Isaac)
	-- since there are only two rings of familiars, >22 always goes to the outer ring
	ORBIT_LAYER_1 = 1268, -- layer ID for the inner ring
	ORBIT_LAYER_2 = 1269, -- layer ID for the outer ring
	ORBIT_DISTANCE_1 = Vector(87.0, 87.0), -- circular orbit of radius 87 for the inner ring
	ORBIT_DISTANCE_2 = Vector(130.0, 130.0), -- circular orbit of radius 130 for the outer ring

	ORBIT_VELOCITY_DIVISOR = 6.0 -- how much an orbiting familiar's velocity is divided by; used to ease their movement speed
	-- so it doesn't just snap into place; increase the value for slower movement; must be >0
}

-- Sets the SocialCircleIndex field of every familiar that can be affected by Social Circle. Returns the number of indexes assigned.
local function assign_social_circle_indexes()

	local index = 1

	for _, familiar in pairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, -1, -1, false, false)) do

		familiar = familiar:ToFamiliar()
		-- check if they follow Isaac in a familiar train (hidden attribute) or a familiar we want to add but is not a follower
		if (familiar.IsFollower or familiar.Variant == FamiliarVariant.ISAACS_HEART) then 
			familiar:GetData().SocialCircleIndex = index
			index = index + 1
		end
	end

	return index-1

end

local follower_num = assign_social_circle_indexes()
local should_recheck_familiars = false -- whether or not we should call assign_social_circle_indexes()

-- Called after every game update to check if it's necessary to recount the number of followers.
local function on_update(_)
	if should_recheck_familiars then
		should_recheck_familiars = false
		follower_num = assign_social_circle_indexes()
	end
end
mod:AddCallback(ModCallbacks.MC_POST_UPDATE, on_update)

-- Called every cache update to set flag for on_update function (assign_social_circle_indexes() can't be called here)
local function cache_update(_, player, cache_flag)
	if player:HasTrinket(SocialCircle.TRINKET_SOCIAL_CIRCLE) and cache_flag == CacheFlag.CACHE_FAMILIARS then
		should_recheck_familiars = true
		-- it's only updated when we need to
	end
end
mod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, cache_update)

-- Called every frame for every familiar
local function on_familiar_update(_, familiar) -- EntityFamiliar

	local data = familiar:GetData()
	-- Since we are calling this for every familiar, we need to be careful with what we do
	if familiar.Player:HasTrinket(SocialCircle.TRINKET_SOCIAL_CIRCLE)
		and (familiar.IsFollower or familiar.Variant == FamiliarVariant.ISAACS_HEART)
		and familiar.Variant ~= FamiliarVariant.KEY_FULL then -- Skip full key so it can unlock Mega Satan's door

		if data.SocialCircleIndex == nil then data.SocialCircleIndex = 0 end

		-- assign orbit layers (and be careful not to end up flipping between them)
		if familiar.OrbitLayer ~= SocialCircle.ORBIT_LAYER_1 and data.SocialCircleIndex <= SocialCircle.ORBIT_1_NUM then
			data.SocialCircleWasOrbital = true
			data.SocialCircleOriginalLayer = familiar.OrbitLayer
			familiar:AddToOrbit(SocialCircle.ORBIT_LAYER_1)
		elseif  familiar.OrbitLayer ~= SocialCircle.ORBIT_LAYER_2 and data.SocialCircleIndex > SocialCircle.ORBIT_1_NUM then
			data.SocialCircleWasOrbital = true
			data.SocialCircleOriginalLayer = familiar.OrbitLayer
			familiar:AddToOrbit(SocialCircle.ORBIT_LAYER_2)
		end
		-- Beyond here, OrbitLayer is set to a value different than -1 (would crash orbit functions otherwise)
		-- and data.SocialCircleIndex is a number

		----> Make it orbit the player:

		-- pick which ring we are on
		local next_orbit = SocialCircle.ORBIT_DISTANCE_1
		if data.SocialCircleIndex > SocialCircle.ORBIT_1_NUM then
			next_orbit = SocialCircle.ORBIT_DISTANCE_2
		end

		local mult = 1.0 -- orbit radius multiplier
		if familiar.Player:HasCollectible(CollectibleType.COLLECTIBLE_MOMS_BOX) then -- Mom's Box synergy
			mult = 0.4 * math.sin(0.05 * game:GetFrameCount()) + 1 -- pulsating orbit (mult goes from 0.6 to 1.4)
		end

		familiar.OrbitDistance = next_orbit * mult
		familiar.OrbitSpeed = SocialCircle.ORBIT_SPEED -- ^these two MUST be here (tested)
		local orbit_pos = familiar:GetOrbitPosition(familiar.Player.Position + familiar.Player.Velocity) -- get orbit position from center_pos based on some attributes (OrbitDistance, OrbitSpeed, OrbitAngleOffset)

		-- Familiars that charge/dash, i.e., that can detach from their train/orbit
		local is_charging_familiar = familiar.Variant == FamiliarVariant.LITTLE_CHUBBY or familiar.Variant == FamiliarVariant.BOBS_BRAIN
										or familiar.Variant == FamiliarVariant.BIG_CHUBBY

		if not is_charging_familiar or (is_charging_familiar and familiar.FireCooldown >= 0) then -- make them orbit!
			familiar.Velocity = (orbit_pos - familiar.Position) / SocialCircle.ORBIT_VELOCITY_DIVISOR -- to_pos - from_pos
		end

		-- Quick reminder about charging familiars' FireCooldown attribute:
		-- >0 = starts cooldown after it stops charging and will now go back to following; will decrease by 1 with each game frame (update)
		-- 0 = can be fired
		-- -1 = mid dash/flight (e.g: Little Chubby chomping or when Bob's Brain can explode)
		-- <-1 = stopped dashing/flying (e.g: hit wall) but won't follow the player again just yet; will decrease by 1 with each
		-- game frame (update); used so it stays in place for a bit (and doesn't just snap back)

		-- E.g: Little Chubby -> 0 -> is fired -> -1 for as long as it is dashing -> hits wall -> <-1 (decrease til a set amount is
		-- reached) -> FireCooldown is set to MAX (how many game frames til it can be fired again) -> decreased by 1 til it reaches 0 ->
		-- -> 0 (back to initial state)
	elseif data.SocialCircleWasOrbital then -- dropped the trinket
		data.SocialCircleWasOrbital = nil -- so we only do this once
		--data.SocialCircleIndex = nil -> not cleared for smoother transitions after dropping it and picking it up again
		-- The indexes will be reassigned as soon as the "Holding up the trinket" animation is finished

		if data.SocialCircleOriginalLayer == -1 then -- if we were a normal follower
			familiar:RemoveFromOrbit() -- back to -1 (no layer)
		else -- if we were some sort of hybrid follower that was also an orbital (possible because of mods)
			familiar:AddToOrbit(data.SocialCircleOriginalLayer) -- put it back in it's original orbit (for compatibility)
		end
		data.SocialCircleOriginalLayer = nil

		-- It's worth noting that these layer changing shenanigans work because, for a brief period, familiars will be assigned
		-- their original OrbitLayer in their INIT functions. This means the original layer is never lost, even after exiting
		-- and continuing.

	end
end
mod:AddCallback(ModCallbacks.MC_FAMILIAR_UPDATE, on_familiar_update) -- variant at nil (converted to -1) calls it for every one