--[[
?]]
-- ################################################## MOM'S MOLE PASSIVE ##################################################
-- Shot speed up + slight range down.
-- Gives Isaac tears that burrow underground at the end of their range. After enough have been burrowed, they'll all reemerge at once 
-- with combined tear effects.

local mod = RegisterMod("moms mole", 1)
local json = require("json.lua") -- for saving and loading data

local ZERO_VECTOR = Vector(0, 0)

local game = Game()

local MomsMole = {
	COLLECTIBLE_MOMS_MOLE = Isaac.GetItemIdByName("Mom's Mole"), -- item ID
	COSTUME_ID = Isaac.GetCostumeIdByPath("gfx/characters/c001_momsmole.anm2"),
	SHOT_SPEED = 0.20, -- stat up (increase for larger shot speed)
	TEAR_HEIGHT = 5.00, -- stat down (increase for smaller range)
	MOLE_NUM = 8, -- how many are shot/how many have to be underground until a shot is taken
	INTERVAL_FRAMES = 120, -- how many games updates/frames until we check the number of underground tears
	MAX_MOLE_NUM = 104, -- max number that can be held underground
	MOLE_VELOCITY = 12.0, -- vector length for a Mole tear's velocity
	VISUAL_SHOCKWAVE_NUM = 6, -- how many extra shockwaves are spawned (visual effect only)
	MAX_SHOCKWAVE_DISTANCE = 20, -- increase for more (visual) shockwave sparsity in relation to its distance to the main shockwave (where tears are shot)
	MAX_NPC_DISTANCE = 80, -- increase for greater distance in relation to the picked NPCs position (effect when there are enemies in the room)
	MAX_PLAYER_DISTANCE = 40, -- -- increase for greater distance in relation to where Isaac is (effect when there are no enemies in the room)
	BANNED_TEAR_FLAGS = TearFlags.TEAR_SPLIT | TearFlags.TEAR_QUADSPLIT | TearFlags.TEAR_BONE -- for tears that split into more
}

-- For reference (height axis points down!):
--[[
	TEAR HEIGHT:
	-10.0	-> a travelling tear usually starts abruptly falling around this height (aprox. height for max range)

	-5.0	-> below this point they might as well have hit the ground

	 0.0	-> they never get here (ground?)
]]

----> Saving and loading data:
local ModData = {}
local decode_status, decode_retval = pcall(json.decode, mod:LoadData()) -- prevent an error while reading data from stopping the mod completely
-- LoadData() returns an empty string if no save.dat file exists (decode would throw an error in this case)

if decode_status then -- successfully decoded the data into a table
	ModData = decode_retval
else -- error while trying to decode the data
	Isaac.DebugString(string.format("[%s] Couldn't load the mod's data. Both saved variables will be set to 0 and a new file will be created when the run is exited.", mod.Name))
end

-- Two cases:
-- Successfully loaded but one or more variables could have been removed by some dingus.
-- Failed to load but ModData is already a table which means that all variables below will be nil.
if ModData.UndergroundTearNum == nil then ModData.UndergroundTearNum = 0 end
if ModData.UndergroundTearFlags == nil then ModData.UndergroundTearFlags = 0 end
-- ModData has two useful variables beyond here. It will only be saved again when we exit to the menu.

local function pre_game_exit(_, should_save)
	if should_save then -- we always come through here before it's possible to reload mods in the Mods menu
		mod:SaveData(json.encode(ModData))
	end -- even if we choose to continue, ModData still holds the correct values, regardless of whether the mod has been reloaded
	-- (not should_save) is when you win/lose a run. It's not really necessary to save then in this particular mod.
end

mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, pre_game_exit)
----> /End of saving and loading data.

local function on_game_start(_, from_save) -- from_save = is_continue
	if not from_save then -- run start
		ModData.UndergroundTearNum = 0
		ModData.UndergroundTearFlags = 0
	end
end

-- Called when the run starts/continues to reset the two variables
mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, on_game_start)

local had_moms_mole = false -- helper variable for applying/removing the costume (were we previously holding the item?)

local function update_moms_mole(_)

	local player = Isaac.GetPlayer(0)
	
	if player:HasCollectible(MomsMole.COLLECTIBLE_MOMS_MOLE) then

		if not had_moms_mole then -- for applying the costume (so it still removes it on mod reload)
			had_moms_mole = true
		end

		-- Item effect:

		-- Pop out and shoot them:
		if game:GetFrameCount() % MomsMole.INTERVAL_FRAMES == 0 and ModData.UndergroundTearNum >= MomsMole.MOLE_NUM then -- check if we have enough every 120 frames

			local room = game:GetRoom()
			local center_position = nil

			if Isaac.CountEnemies() > 0 then

				local entities = Isaac.GetRoomEntities()
				for i = #entities, 1, -1 do -- cycle backwards to prioritize newly spawned entities

					if entities[i]:IsVulnerableEnemy() then -- shuffle it a bunch so it's not exactly on them
						center_position = entities[i].Position + Vector(math.random(-1, 1)*MomsMole.MAX_NPC_DISTANCE, math.random(-1, 1)*MomsMole.MAX_NPC_DISTANCE)
					end

				end
			end

			-- No enemies in the room or on the very slim chance that there were enemies but they died before we found one in the cycle above
			if center_position == nil then -- shuffle it a bit but not too much
				center_position = player.Position + Vector(math.random(-1, 1)*MomsMole.MAX_PLAYER_DISTANCE, math.random(-1, 1)*MomsMole.MAX_PLAYER_DISTANCE)
			end

			-- shuffle position a bit and find the nearest position with no grid entities (doesn't collide with any rocks when popping out)
			local out_position = room:FindFreeTilePosition(center_position, 40.0)

			-- Main shockwave (should be on the exact position because it looks nicer)
			Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.ROCK_EXPLOSION, 0, out_position, ZERO_VECTOR, player)

			for i = 1, MomsMole.VISUAL_SHOCKWAVE_NUM do -- add a few more for visual effect
				local pos = out_position + Vector(math.random(-MomsMole.MAX_SHOCKWAVE_DISTANCE, MomsMole.MAX_SHOCKWAVE_DISTANCE), math.random(-MomsMole.MAX_SHOCKWAVE_DISTANCE, MomsMole.MAX_SHOCKWAVE_DISTANCE))
				Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.ROCK_EXPLOSION, 0, pos, ZERO_VECTOR, player)
			end

			ModData.UndergroundTearNum = math.max(0, ModData.UndergroundTearNum - MomsMole.MOLE_NUM) -- remove tears fired by shockwave (0 is the minimum possible)
			local step = 360 / MomsMole.MOLE_NUM

			for angle = 0, 360-step, step do -- fire MomsMole.MOLE_NUM evenly spaced tears

				local vel = Vector.FromAngle(angle):Resized(MomsMole.MOLE_VELOCITY)
				local mole_tear = player:FireTear(out_position, vel, false, true, false) -- booleans: can't be Eye, not affected by Tractor Beam, can't trigger streak end
				mole_tear.TearFlags = ModData.UndergroundTearFlags
				mole_tear:GetData().CheckedMomsMole = true -- so they don't count as tears that can trigger the effect
				
			end

			ModData.UndergroundTearFlags = player.TearFlags & ~(MomsMole.BANNED_TEAR_FLAGS) -- reset flags back to Isaac's current ones (minus banned ones)

		end

		-- Catch tears that hit the ground
		for _, tear in pairs(Isaac.FindByType(EntityType.ENTITY_TEAR, -1, -1, true, false)) do -- get every tear in the current room (cached)

			if tear.SpawnerType == EntityType.ENTITY_PLAYER then

				tear = tear:ToTear()
				local tear_data = tear:GetData()

				-- check if it hit the ground (see reference above)
				if tear:IsDead() and tear_data.CheckedMomsMole == nil and tear.Height >= -5.0 and not tear:CollidesWithGrid() then

					tear_data.CheckedMomsMole = true -- avoid checking the same tear twice

					-- visual effect only
					Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.ROCK_EXPLOSION, 0, tear.Position, ZERO_VECTOR, player)
				
					ModData.UndergroundTearNum = math.min(MomsMole.MAX_MOLE_NUM, ModData.UndergroundTearNum + 1) -- one more to shoot out
					ModData.UndergroundTearFlags = ModData.UndergroundTearFlags | player.TearFlags | tear.TearFlags -- keep stacking tear flags
					ModData.UndergroundTearFlags = ModData.UndergroundTearFlags & ~(MomsMole.BANNED_TEAR_FLAGS) -- remove banned tear flags

				end
			end
		end
	end
end

mod:AddCallback(ModCallbacks.MC_POST_UPDATE, update_moms_mole)

-- Handles cache updates
local function update_cache(_, player, cache_flag)

	if player:HasCollectible(MomsMole.COLLECTIBLE_MOMS_MOLE) then

		if cache_flag == CacheFlag.CACHE_SHOTSPEED then -- Increase shot speed
			player.ShotSpeed = player.ShotSpeed + MomsMole.SHOT_SPEED * player:GetCollectibleNum(MomsMole.COLLECTIBLE_MOMS_MOLE)
		elseif cache_flag == CacheFlag.CACHE_RANGE then -- tears are fired from lower (range down)
			player.TearHeight = player.TearHeight + MomsMole.TEAR_HEIGHT * player:GetCollectibleNum(MomsMole.COLLECTIBLE_MOMS_MOLE)
		end

		if not had_moms_mole then

			player:AddNullCostume(MomsMole.COSTUME_ID)
			had_moms_mole = true -- so if we have the item and we pick up something else with a cache flag,
			-- our costume isn't added again and potentially overlayed on top of the other item's costume
		end

	elseif had_moms_mole then -- not strictly necessary (TryRemove with no costume does nothing?) but you never know
		player:TryRemoveNullCostume(MomsMole.COSTUME_ID)
		had_moms_mole = false
	end

end

mod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, update_cache)