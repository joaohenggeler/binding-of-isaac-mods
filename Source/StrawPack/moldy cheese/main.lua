--[[
?)]]
-- ################################################## MOLDY CHEESE PASSIVE ##################################################
-- One half filled heart container + 1-2 blue flies
-- Isaac spawns green creep under him until he gets hit once.
-- Creep spawning flag resets every floor.

local mod = RegisterMod("moldy cheese", 1)

local game = Game() -- reference to current run (works across restarts and continues)
local ZERO_VECTOR = Vector(0, 0)

local MoldyCheese = {
	COLLECTIBLE_MOLDY_CHEESE = Isaac.GetItemIdByName("Moldy Cheese"), -- item ID
	CREEP_TYPE = EffectVariant.PLAYER_CREEP_GREEN, -- type that doesn't hurt the player
	CREEP_FRAMES = 3, -- frequency of puddle spawn
	CREEP_TIMEOUT = 24, -- how long it stays for (effectively the max trail length); 24 ~ 1 sec
	MIN_FLIES = 2,
	MAX_FLIES = 3 -- Moldy Cheese spawns MIN_FLIES to MAX_FLIES (inclusive) blue flies when picked up
}

local moldy_cheese_flag = nil -- whether or not we should be spawning creep (loaded from mod data)
-- On mod load by luamod, the flag is set to whatever is on the current save.dat. This can be used to test specific scenarios. 

local function str2boolean(str)
	return str == "true"
end

local function update_moldy_cheese(_, player)

	if player:HasCollectible(MoldyCheese.COLLECTIBLE_MOLDY_CHEESE) then

		if moldy_cheese_flag == nil then -- flag reset because of mod reloads (luamod or from toggling mod support in the menu)
			if mod:HasData() then
				moldy_cheese_flag = str2boolean(mod:LoadData())
			else
				moldy_cheese_flag = true
				mod:SaveData(tostring(moldy_cheese_flag))
			end
		end

		if not mod:HasData() then  -- if save.dat doesn't exist for some reason
			mod:SaveData(tostring(moldy_cheese_flag)) -- moldy_cheese_flag is guaranteed to have a meaningful value here
		end
		
		----> Passive effects:
		-- Handle creep after pick up (and no damage has been taken yet):
		-- If we haven't been hit yet (CreepFlag is true), every CREEP_FRAMES frames we spawn a creep puddle
		if moldy_cheese_flag and Isaac.GetFrameCount() % MoldyCheese.CREEP_FRAMES == 0 then
			-- Spawn and cast to EntityEffect
			local creep = Isaac.Spawn(EntityType.ENTITY_EFFECT, MoldyCheese.CREEP_TYPE, 0, player.Position, ZERO_VECTOR, player):ToEffect()
			creep:SetTimeout(MoldyCheese.CREEP_TIMEOUT)
		end

	end
end

mod:AddCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, update_moldy_cheese)

local function hit_moldy_cheese(_, dmg_target, dmg_amount, dmg_flags, dmg_source, dmg_countdown_frames)
	if Isaac.GetPlayer(0):HasCollectible(MoldyCheese.COLLECTIBLE_MOLDY_CHEESE) and moldy_cheese_flag then
		moldy_cheese_flag = false -- stop creep from spawning
	end
end

mod:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, hit_moldy_cheese, EntityType.ENTITY_PLAYER)

local function on_new_level(_) -- Forget Me Not counts as a level change!
	if Isaac.GetPlayer(0):HasCollectible(MoldyCheese.COLLECTIBLE_MOLDY_CHEESE) then
		moldy_cheese_flag = true
	end
end

mod:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, on_new_level)

-- For reference (callback order in ONE game frame):
-- ... -> POST_PEFFECT_UPDATE -> POST_PlAYER_UPDATE -> POST_UPDATE -> POST_PlAYER_UPDATE -> MC_EVALUATE_CACHE -> POST_PlAYER_UPDATE -> ...
local previous_moldy_cheese_item_num = nil -- how many Moldy Cheese items we had; used to spawn drops on pick up
if Isaac.GetPlayer(0) ~= nil then previous_moldy_cheese_item_num = Isaac.GetPlayer(0):GetCollectibleNum(MoldyCheese.COLLECTIBLE_MOLDY_CHEESE) end
-- if the mod is reloaded in the game, previous_moldy_cheese_item_num will hold the correct value (its only nil if its loaded from the menu)

local function update_cache(_, player, cache_flag)

	if player:HasCollectible(MoldyCheese.COLLECTIBLE_MOLDY_CHEESE) then

		----> Spawn some blue flies per Moldy Cheese item pick up (we take advantage of the dummy CACHE_RANGE flag)
		-- Works on mod reloads, between runs/exits/continues, given by the console or if it's there from the start of the run (Eden's Blessing, etc)
		local current_moldy_cheese_item_num = player:GetCollectibleNum(MoldyCheese.COLLECTIBLE_MOLDY_CHEESE)

		if previous_moldy_cheese_item_num == nil then
			if game:GetFrameCount() == 0 then -- cache is evaluated for ALL on game frame 0, before MC_POST_GAME_STARTED
				previous_moldy_cheese_item_num = 0 -- spawn pills if we have it at the beginning of a new run (Eden's Blessing, etc)
			else
				previous_moldy_cheese_item_num = current_moldy_cheese_item_num -- spawn nothing if we are continuing after reloading mods
			end
		end -- guarantee that previous_moldy_cheese_item_num is a number

		local roll
		for _ = 1, current_moldy_cheese_item_num - previous_moldy_cheese_item_num do -- stuff to do when we pick up the item itself
				
			roll = math.random(MoldyCheese.MIN_FLIES, MoldyCheese.MAX_FLIES)
			for _ = 1, roll do
				Isaac.Spawn(EntityType.ENTITY_FAMILIAR, FamiliarVariant.BLUE_FLY, 0, player.Position, Vector(0, 0), player)
			end

			moldy_cheese_flag = true -- whether or not creep should spawn under the player

		end

		previous_moldy_cheese_item_num = current_moldy_cheese_item_num

	else -- lost the item (removed or rerolled) or resetting the value on a new run start (cache is evaluated for ALL on start)
		previous_moldy_cheese_item_num = 0
		moldy_cheese_flag = true -- the next time we pick one we want to spawn creep
	end

end

mod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, update_cache)

-- Called every time a new run is started/continued
local function post_game_started(_, from_save)
	if from_save then -- run continue

		if mod:HasData() then -- load existing data
			moldy_cheese_flag = str2boolean(mod:LoadData())
		else -- create save.dat if it's been deleted
			if moldy_cheese_flag == nil then moldy_cheese_flag = true end
			mod:SaveData(tostring(moldy_cheese_flag))
		end

	else -- run start - reset creep spawning flag
		moldy_cheese_flag = true
	end
end

mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, post_game_started)

local function pre_game_exit(_, should_save)
	if should_save then
		mod:SaveData(tostring(moldy_cheese_flag))
	end
end

mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, pre_game_exit)