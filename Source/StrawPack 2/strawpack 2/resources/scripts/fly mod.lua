--[[
?)]]
-- ################################################## FLY MOD ACTIVE ##################################################
-- Charge: 1 room.
-- While held, a robotic fly will orbit Isaac, dealing light contact damage and blocking enemy shots.
-- After activating the item, Fly Mod will leave the orbit and dash for a few seconds, dealing a high amount of damage.
-- After the fly slows down, it will bounce off the walls for the remainder of the room, dealing a medium amount of damage.
-- Fly Mod confuses fly enemies that get close to it. It also turns Blue Flies into Locusts if they stay close to it for a few seconds.
-- Every time Fly Mod kills an enemy, there is 50% for a Blue Fly to spawn.
-- Synergizes with BFFS: increased area of effect for enemies and Blue Flies + the number of Blue Flies spawned after killing an enemy is increased by the amount of BFFS! items.

-- 2S4Y 96HY -> stage 3 -> room on the right

local mod = RegisterMod("strawpack 2 - fly mod", 1)

local game = Game()

local ZERO_VECTOR = Vector(0, 0)

local FlyModStates = {
	STATE_ORBIT = 0, -- orbiting the player (default state)
	STATE_DASH = 1, -- initial speed boost after activating the item
	STATE_LAUNCHED = 2 -- after slowing down from the boost above; goes back to ORBIT on a new room or if the active item charges again (batteries, 9 Volt, etc)
}

local FlyMod = {

	COLLECTIBLE_FLY_MOD = Isaac.GetItemIdByName("Fly Mod"), -- item ID
	VARIANT_FLY_MOD = Isaac.GetEntityVariantByName("Fly Mod"), -- familiar variant

	ORBIT_LAYER = 763, -- hopefully unique to this orbital (the number of familiars in a layer adjusts the orbiting speed and placement); 853 no longer works for some reason?
	ORBIT_SPEED = 0.03, -- how fast it orbits (should be less than 0.1)
	ORBIT_DISTANCE = Vector(120.0, 120.0), -- circular orbit of radius 120

	LAUNCH_VELOCITY = 10.0, -- how fast Fly Mod moves while bouncing around the room (locked at this speed because of friction)
	DASH_VELOCITY = 25.0, -- initial boost when the active item is used (slows down to the speed above)
	DASH_FRICTION = 0.97, -- increase to decrease how quickly the boost above goes does to LAUNCH_VELOCITY (slow Fly Mod down)
	-- ^ percentage of the speed that is kept every frame (new = old * DASH_FRICTION) while in the DASH state
	DASH_FLASH_COLOR = Color(2.5, 2.5, 2.5, 1.0, 0, 0, 0), -- color to be set for dash visual (fades out); see below for *CONT.
	DASH_FLASH_DURATION = 5, -- how long each flash last for while dashing (in frames)

	ORBIT_DAMAGE = 1.00, -- how much collision damage Fly Mod deals when in the orbit state (original damage from the XMLs)
	LAUNCHED_DAMAGE = 5.00, -- how much collision damage Fly Mod deals when it is flying across the room
	DASH_DAMAGE_MULTIPLIER = 2.0, -- how much damage is dealt while first dashing (this * LAUNCHED_DAMAGE)

	MAX_CONFUSION_DISTANCE = 80.0, -- confusion range for fly monsters
	BFFS_CONFUSION_DISTANCE_MULTIPLIER = 1.2, -- (BFFS synergy) above is multiplied by this
	CONFUSION_DURATION = 2, -- how long each confusion effect added last for (should be low since they will stack every frame)
	
	-- Both of the following two values are squared (distance = 90.0, mult = 1.05)
	MAX_BLUE_FLY_DISTANCE = 8100.0, -- a blue fly would have to be a <= of this distance to a Fly Mod for it to turn into a random Locust
	BFFS_BLUE_FLY_DISTANCE_MULTIPLIER = 1.1025, -- (BFFS synergy) above is multiplied by this
	FRAMES_IN_RANGE = 40.0 -- how many frames does a blue fly have to be in range (above) of a Fly Mod for it to turn into a random Locust
}

-- *CONT. (color was based on the Pony's dash color)
FlyMod.DASH_FLASH_COLOR:SetOffset(0.7, 0.7, 0.7) -- now this is just silly: color constructor expects integers for offsets (while the attributes are floats)

if not __eidItemDescriptions then __eidItemDescriptions = {}; end -- External Item Descriptions compatibility
__eidItemDescriptions[FlyMod.COLLECTIBLE_FLY_MOD] = "While held, gives Isaac an orbiting fly#When used, the fly is launched, dealing contact damage#Converts blue flies into locusts and confuses enemy flies";

-- Returns true if the entity is a fly or related to flies. Otherwise, false. Based on if it feels right.
local function is_fly_entity(entity)
	return entity.Type == EntityType.ENTITY_FLY or entity.Type == EntityType.ENTITY_POOTER or entity.Type == EntityType.ENTITY_POOTER
	or entity.Type == EntityType.ENTITY_ATTACKFLY or entity.Type == EntityType.ENTITY_BOOMFLY or entity.Type == EntityType.ENTITY_SUCKER
	or entity.Type == EntityType.ENTITY_MOTER or entity.Type == EntityType.ENTITY_ETERNALFLY or entity.Type == EntityType.ENTITY_FLY_L2
	or entity.Type == EntityType.ENTITY_RING_OF_FLIES or entity.Type == EntityType.ENTITY_FULL_FLY or entity.Type == EntityType.ENTITY_DART_FLY
	or entity.Type == EntityType.ENTITY_SWARM or entity.Type == EntityType.ENTITY_DUKIE or entity.Type == EntityType.ENTITY_HUSH_FLY
	or entity.Type == EntityType.ENTITY_SWARMER or entity.Type == EntityType.ENTITY_DUKE
end

-- Called every time an entity takes damage
local function entity_take_damage(_, dmg_target, dmg_amount, dmg_flags, dmg_source, dmg_countdown_frames)

	-- if something was killed by Fly Mod, there is a 50% chance to spawn a blue fly
	if dmg_source.Type == EntityType.ENTITY_FAMILIAR and dmg_source.Variant == FlyMod.VARIANT_FLY_MOD
		and dmg_target.HitPoints - dmg_amount <= 0 and math.random(2) == 1 and dmg_target:GetData().CheckedFlyModDeath == nil then

		dmg_target:GetData().CheckedFlyModDeath = true
		local player = Isaac.GetPlayer(0)
		player:AddBlueFlies(player:GetCollectibleNum(CollectibleType.COLLECTIBLE_BFFS) + 1, player.Position, nil)
	end
end

mod:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, entity_take_damage)

-- Called when the orbital first spawns or when we come back after an exit/continue
local function init_fly_mod(_, fly_mod) -- EntityFamiliar

	fly_mod:AddToOrbit(FlyMod.ORBIT_LAYER) -- sets OrbitLayer attribute + initial states
	fly_mod.OrbitDistance = FlyMod.ORBIT_DISTANCE
	fly_mod.OrbitSpeed = FlyMod.ORBIT_SPEED
	fly_mod.State = FlyModStates.STATE_ORBIT
	fly_mod.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE

end

mod:AddCallback(ModCallbacks.MC_FAMILIAR_INIT, init_fly_mod, FlyMod.VARIANT_FLY_MOD)

-- Called every frame for each Fly Mod orbital
local function update_fly_mod(_, fly_mod) -- EntityFamiliar

	local fly_mod_data = fly_mod:GetData()

	-- Things to change depending on state: Damage, Grid collision type, Velocity vector

	if fly_mod.State == FlyModStates.STATE_ORBIT then -- in orbit

		fly_mod.CollisionDamage = FlyMod.ORBIT_DAMAGE
		fly_mod.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE -- fly over everything like an orbital should

		fly_mod.OrbitDistance = FlyMod.ORBIT_DISTANCE -- these two MUST be here (tested)
		fly_mod.OrbitSpeed = FlyMod.ORBIT_SPEED

		local orbit_pos = fly_mod:GetOrbitPosition(fly_mod.Player.Position + fly_mod.Player.Velocity) -- get orbit position from center_pos based on some attributes (OrbitDistance, OrbitSpeed, OrbitAngleOffset)
		fly_mod.Velocity = orbit_pos - fly_mod.Position -- to_pos - from_pos

	elseif fly_mod.State == FlyModStates.STATE_DASH then -- initial dash after being launched

		fly_mod.CollisionDamage = FlyMod.LAUNCHED_DAMAGE * FlyMod.DASH_DAMAGE_MULTIPLIER
		fly_mod.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_WALLS -- to bounce off walls

		-- the lower bound here is the normal speed at which it moves (Fly Mod slows down after the initial boost)
		local vel_length = math.max(FlyMod.LAUNCH_VELOCITY, fly_mod.Velocity:Length() * FlyMod.DASH_FRICTION)
		if vel_length <= FlyMod.LAUNCH_VELOCITY then -- if it slows down (dash finished)
			fly_mod.State = FlyModStates.STATE_LAUNCHED
		end
		fly_mod.Velocity = fly_mod.Velocity:Resized(vel_length)

		-- dash visual flash
		if fly_mod:IsFrame(FlyMod.DASH_FLASH_DURATION, 0) then			
			fly_mod:SetColor(FlyMod.DASH_FLASH_COLOR, FlyMod.DASH_FLASH_DURATION, 0, true, false) -- true = fades out
		end

	elseif fly_mod.State == FlyModStates.STATE_LAUNCHED then -- bouncing across the room (after dash)

		fly_mod.CollisionDamage = FlyMod.LAUNCHED_DAMAGE
		fly_mod.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_WALLS -- to bounce off walls
		fly_mod.Velocity = fly_mod.Velocity:Resized(FlyMod.LAUNCH_VELOCITY)

	end

	-- Things to do when not orbiting
	if fly_mod.State ~= FlyModStates.STATE_ORBIT then

		if not game:GetRoom():IsPositionInRoom(fly_mod.Position, 0.0) then -- in case it somehow ends up outside the room
			fly_mod.Position = fly_mod.Player.Position -- prevents those annoying log messages
		end

		-- if the one charge item becomes filled again (Lil' Batteries, 9 Volt or Sharp Plug)
		if fly_mod.Player:HasCollectible(FlyMod.COLLECTIBLE_FLY_MOD) and not fly_mod.Player:NeedsCharge() then
			Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF01, 0, fly_mod.Position, ZERO_VECTOR, nil) -- visual poof
			fly_mod.State = FlyModStates.STATE_ORBIT -- back to orbiting
		end

	end

	-- Apply certain effects to some Entity Types (Blue Flies and Enemies)

	local confusion_range_multiplier = 1.0
	if fly_mod.Player ~= nil and fly_mod.Player:HasCollectible(CollectibleType.COLLECTIBLE_BFFS) then
		confusion_range_multiplier = FlyMod.BFFS_CONFUSION_DISTANCE_MULTIPLIER
	end
	local blue_fly_range_multiplier = 1.0
	if fly_mod.Player ~= nil and fly_mod.Player:HasCollectible(CollectibleType.COLLECTIBLE_BFFS) then
		blue_fly_range_multiplier = FlyMod.BFFS_BLUE_FLY_DISTANCE_MULTIPLIER
	end

	-- Blue Flies (SubType 0) in the room (looks at how long they've been in blue-fly range and converts them into locusts)
	for _, blue_fly in pairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, FamiliarVariant.BLUE_FLY, 0, false, false)) do -- SubType = 0 (Blue Flies only)

		blue_fly = blue_fly:ToFamiliar()
		local fly_data = blue_fly:GetData()
		if fly_data.InRangeDuration == nil then fly_data.InRangeDuration = 0 end -- how many frames has it been in range? (resets when outside)

		if blue_fly.Position:DistanceSquared(fly_mod.Position) <= FlyMod.MAX_BLUE_FLY_DISTANCE * blue_fly_range_multiplier then -- in range
			fly_data.InRangeDuration = fly_data.InRangeDuration + 1
		elseif fly_data.InRangeDuration ~= 0 then -- drifted out of range
			fly_data.InRangeDuration = 0
		end

		if fly_data.InRangeDuration >= FlyMod.FRAMES_IN_RANGE then -- exceded time in range
			fly_data.InRangeDuration = 0
			-- spawn random locust
			Isaac.Spawn(EntityType.ENTITY_FAMILIAR, FamiliarVariant.BLUE_FLY, math.random(LocustSubtypes.LOCUST_OF_CONQUEST), blue_fly.Position, blue_fly.Velocity, nil)
			blue_fly:Remove() -- Morph() doesn't exist for familiars
		end

	end

	-- Enemies in Fly Mod's confusion radius
	for _, npc in pairs(Isaac.FindInRadius(fly_mod.Position, FlyMod.MAX_CONFUSION_DISTANCE * confusion_range_multiplier, EntityPartition.ENEMY)) do

		if is_fly_entity(npc) then
			npc:AddConfusion(EntityRef(fly_mod), FlyMod.CONFUSION_DURATION, true) -- true = include bosses
		end

	end

end

mod:AddCallback(ModCallbacks.MC_FAMILIAR_UPDATE, update_fly_mod, FlyMod.VARIANT_FLY_MOD)

local function pre_fly_mod_collision(_, fly_mod, collider, low)
	if collider.Type == EntityType.ENTITY_PROJECTILE then -- stop enemy bullets
		collider:Die()
	end
end

mod:AddCallback(ModCallbacks.MC_PRE_FAMILIAR_COLLISION, pre_fly_mod_collision, FlyMod.VARIANT_FLY_MOD)

-- Called when the player uses the active item to launch a Fly Mod
local function use_fly_mod_item(_, collectible_type, rng)

	for _, fly_mod in pairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, FlyMod.VARIANT_FLY_MOD, -1, false, false)) do

		fly_mod = fly_mod:ToFamiliar()

		-- 1. orbiting + inside the room + not inside a wall
		-- 2. launched (for The Battery synergy)
		if (fly_mod.State == FlyModStates.STATE_ORBIT and game:GetRoom():IsPositionInRoom(fly_mod.Position, 0.0)
			and game:GetRoom():GetGridCollisionAtPos(fly_mod.Position) ~= GridCollisionClass.COLLISION_WALL)
			or fly_mod.State == FlyModStates.STATE_LAUNCHED then

			fly_mod.Velocity = fly_mod.Velocity:Resized(FlyMod.DASH_VELOCITY)
			fly_mod.State = FlyModStates.STATE_DASH

		end			

	end

	return true -- show holding active item animation
end

mod:AddCallback(ModCallbacks.MC_USE_ITEM, use_fly_mod_item, FlyMod.COLLECTIBLE_FLY_MOD)

local has_fly_mod_item = false -- are/were we holding the active item? (used to check for swaps)

-- Called every player frame to check for active item swaps
local function post_player_update(_, player)
	-- Active item swaps:
	-- Reevaluate cache for familiars if we now have it (and we previously didn't) or we lost it (don't have it now but had it just before)
	if (player:HasCollectible(FlyMod.COLLECTIBLE_FLY_MOD) and not has_fly_mod_item)
		or (not player:HasCollectible(FlyMod.COLLECTIBLE_FLY_MOD) and has_fly_mod_item) then
		
		has_fly_mod_item = not has_fly_mod_item
		player:AddCacheFlags(CacheFlag.CACHE_FAMILIARS) -- reevaluate cache for familiars only
		player:EvaluateItems()
	end
end

mod:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, post_player_update, 0) -- Variant = 0 (Isaac and not coop babies)

-- Called every new room to set any Fly Mod back to the initial orbiting state
local function post_new_room(_)
	if Isaac.GetPlayer(0):HasCollectible(FlyMod.COLLECTIBLE_FLY_MOD) then
		for _, fly_mod in pairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, FlyMod.VARIANT_FLY_MOD, -1, false, false)) do
			-- send any existing ones back to orbiting
			fly_mod:ToFamiliar().State = FlyModStates.STATE_ORBIT
		end
	end
end

mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, post_new_room)

-- Called every time the cache is reevaluated to add/remove a Fly Mod
local function update_cache(_, player, cache_flag)

	--Isaac.DebugString(string.format("############################# CACHE EVALUATED WITH FLAG: %d", cache_flag))
	if cache_flag == CacheFlag.CACHE_FAMILIARS then
		player:CheckFamiliar(FlyMod.VARIANT_FLY_MOD, player:GetCollectibleNum(FlyMod.COLLECTIBLE_FLY_MOD), player:GetCollectibleRNG(FlyMod.COLLECTIBLE_FLY_MOD))
	end

end

mod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, update_cache)

return {
	ITEM_ID = FlyMod.COLLECTIBLE_FLY_MOD
}