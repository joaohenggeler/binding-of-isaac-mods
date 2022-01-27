--[[
?)]]
-- ################################################## MOM'S RING PASSIVE ##################################################
-- When an enemy dies, there is a % chance for them to shoot four player tears (+synergies) in an X pattern.
-- +1.00 luck up.
-- Spawns two non-specific coins on pickup.

local mod = RegisterMod("moms ring", 1)

local game = Game() -- reference to current run (works across restarts and continues)
-- current room reference must be gotten in the moment (avoids crashes)

local ZERO_VECTOR = Vector(0, 0)

local MomsRing = {
	COLLECTIBLE_MOMS_RING = Isaac.GetItemIdByName("Mom's Ring"), -- item ID
	LUCK = 1.00, -- luck up on pickup
	MAX_LUCK = 29, -- increase for slower chance growth; with each +1 luck increase, chance increases by (1-BASE_CHANCE)/MAX_LUCK ~ 2.18% (in this case)
	BASE_CHANCE = 0.08, -- chance at 0 luck (0 to 1)
	MAX_CHANCE = 0.5, -- maximum chance (cap, 0 to 1)
	START_DEGREES = 45.0, -- for X pattern
	VELOCITY_LENGTH = 8.0, -- how fast the tears that spawn after an enemy dies are going (8.0 seemed good during testing)
	BRIM_TIMEOUT = 5, -- how many frames the brimstone laser stays on screen (synergy)
	TECHX_RADIUS = 25.0 -- radius of the tech x ring laser (synergy)
}

-- Called when an EntityNPC dies
local function post_npc_death(_, npc)

	local player = Isaac.GetPlayer(0)

	if player:HasCollectible(MomsRing.COLLECTIBLE_MOMS_RING) and npc.Type ~= EntityType.ENTITY_SHOPKEEPER then -- exclude dead shopkeepers

		-- Linear probability: Isaac's base luck + Mom's Ring bonus (1 luck) ~ 10.84% -> 10%
		-- At >14.22 luck, effect triggers 50% of the time.
		local chance = (1 - MomsRing.BASE_CHANCE) * player.Luck/MomsRing.MAX_LUCK + MomsRing.BASE_CHANCE
		chance = math.min(MomsRing.MAX_CHANCE, chance) -- capped at MAX_CHANCE (50%)

		if chance >= math.random() then
			
			local vel = Vector.FromAngle(MomsRing.START_DEGREES):Resized(MomsRing.VELOCITY_LENGTH)
			local pos = npc.Position -- enemy's position

			for i = 0, 270, 90 do -- Create X pattern and shoot the respective shot
				
				local rot_vel = vel:Rotated(i)

				-- Check for synergy potential
				-- Precedence: Brimstone > Dr Fetus > Tech X > Tech 1 and 2 > Tears

				-- Brimstone
				if player:HasWeaponType(WeaponType.WEAPON_BRIMSTONE) then

					-- Starting position offset (default would lead to a + pattern)
					--local brim_laser = EntityLaser.ShootAngle(1, pos, i+45, MomsRing.BRIM_TIMEOUT, ZERO_VECTOR, player)
					--brim_laser.DisableFollowParent = true -- Otherwise it would follow our every move

					local brim_swirl = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.BRIMSTONE_SWIRL, 0, pos, ZERO_VECTOR, player):ToEffect()
					brim_swirl.Rotation = rot_vel:GetAngleDegrees()

				-- Dr Fetus
				elseif player:HasWeaponType(WeaponType.WEAPON_BOMBS) then

					local bomb = player:FireBomb(pos, rot_vel)

				-- Tech X
				elseif player:HasWeaponType(WeaponType.WEAPON_TECH_X) then

					local ring_laser = player:FireTechXLaser(pos, rot_vel, MomsRing.TECHX_RADIUS)

				-- Tech 1 and 2
				elseif player:HasWeaponType(WeaponType.WEAPON_LASER) then

					local laser = player:FireTechLaser(pos, LaserOffset.LASER_TECH5_OFFSET, rot_vel, false, false)

				else -- Other (tears, knives, ludo, monstro's lung, Epic Fetus rockets)
					local tear = player:FireTear(pos, rot_vel, true, true, false) -- Has same effects as Isaac's tears
				end

			end -- X pattern for

		end -- chance

	end -- HasCollectible

end

mod:AddCallback(ModCallbacks.MC_POST_NPC_DEATH, post_npc_death)

-- For reference (callback order in ONE game frame):
-- ... -> POST_PEFFECT_UPDATE -> POST_PlAYER_UPDATE -> POST_UPDATE -> POST_PlAYER_UPDATE -> MC_EVALUATE_CACHE -> POST_PlAYER_UPDATE -> ...
local previous_moms_ring_item_num = nil -- how many Mom's Ring items we had; used to spawn drops on pick up
if Isaac.GetPlayer(0) ~= nil then previous_moms_ring_item_num = Isaac.GetPlayer(0):GetCollectibleNum(MomsRing.COLLECTIBLE_MOMS_RING) end
-- if the mod is reloaded in the game, previous_moms_ring_item_num will hold the correct value (its only nil if its loaded from the menu)

-- Handles cache updates (recalculating stats)
local function update_cache(_, player, cache_flag)

	if player:HasCollectible(MomsRing.COLLECTIBLE_MOMS_RING) then

		if cache_flag == CacheFlag.CACHE_LUCK then -- Luck change
			player.Luck = player.Luck + MomsRing.LUCK * player:GetCollectibleNum(MomsRing.COLLECTIBLE_MOMS_RING)
		end

		----> Spawn two coins per Mom's Ring item pick up
		-- Works on mod reloads, between runs/exits/continues, given by the console or if it's there from the start of the run (Eden's Blessing, etc)
		local current_moms_ring_item_num = player:GetCollectibleNum(MomsRing.COLLECTIBLE_MOMS_RING)

		if previous_moms_ring_item_num == nil then
			if game:GetFrameCount() == 0 then -- cache is evaluated for ALL on game frame 0, before MC_POST_GAME_STARTED
				previous_moms_ring_item_num = 0 -- spawn pills if we have it at the beginning of a new run (Eden's Blessing, etc)
			else
				previous_moms_ring_item_num = current_moms_ring_item_num -- spawn nothing if we are continuing after reloading mods
			end
		end -- guarantee that previous_moms_ring_item_num is a number

		local free_spawn_position

		for _ = 1, current_moms_ring_item_num - previous_moms_ring_item_num do -- stuff to do when we pick up the item itself
				
			for _ = 1, 2 do
				free_spawn_position = game:GetRoom():FindFreePickupSpawnPosition(player.Position, 40.0, true)
				Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COIN, 0, free_spawn_position, ZERO_VECTOR, nil)
				-- SubType = 0 for non-specific coin drop
			end

		end

		previous_moms_ring_item_num = current_moms_ring_item_num

	else -- lost the item (removed or rerolled) or resetting the value on a new run start (cache is evaluated for ALL on start)
		previous_moms_ring_item_num = 0
	end

end

mod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, update_cache)