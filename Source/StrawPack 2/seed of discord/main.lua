--[[
?)]]
-- ################################################## SEED OF DISCORD TRINKET ##################################################
-- While held, every time Isaac goes down a floor, 3 new special seed effects are added to the run.
-- When a full batch of 3 seed effects can't be added, a random Challenge effect will be added instead.

-- Compatible with challenges and seed effects:
-- Challenges: vanilla + custom ones should always work if you are using the trinket. Since trophies spawn at on or after the
-- target floor, we'll need to correct the exits (see correct_challenge_exits()). This function's effect is only applied on runs whose
-- current challenge is different than the original one and whose ID is one that is able to be applied by the trinket.

-- Special seeds and eggs: because the trinket can add several seed effects that can be turned on manually by the player in the Eggs menu,
-- we'll clear every seed effects and readd the original ones after a run ends (win, lose or restart).

-- Both the current run's original challenge and seed effects are saved in the save.dat file.

local mod = RegisterMod("seed of discord", 1)
local json = require("json.lua") -- for saving and loading data

local ZERO_VECTOR = Vector(0, 0)

local game = Game() -- reference to current run (works across restarts and continues)
local level = game:GetLevel() -- reference to current stage (works across restarts and continues)
local seeds = game:GetSeeds() -- reference to Seeds Class (works across restarts and continues)

local SeedOfDiscord = {
	TRINKET_SEED_OF_DISCORD = Isaac.GetTrinketIdByName("Seed of Discord"), -- item ID
	NUM = 3, -- how many new special seeds do we add every floor transition?
	SEEDS = { -- seeds that don't break the game (Infinite Basement) and aren't overpowered (remove every curse)
		SeedEffect.SEED_MOVEMENT_PITCH, SeedEffect.SEED_HEALTH_PITCH, SeedEffect.SEED_CAMO_ISAAC, SeedEffect.SEED_CAMO_PICKUPS,
		SeedEffect.SEED_FART_SOUNDS, SeedEffect.SEED_DYSLEXIA, SeedEffect.SEED_PICKUPS_SLIDE, SeedEffect.SEED_ALL_CHAMPIONS,
		SeedEffect.SEED_ALWAYS_ALTERNATING_FEAR, SeedEffect.SEED_EXTRA_BLOOD, SeedEffect.SEED_POOP_TRAIL, SeedEffect.SEED_PILLS_NEVER_IDENTIFY,
		SeedEffect.SEED_MYSTERY_TAROT_CARDS, SeedEffect.SEED_ENEMIES_RESPAWN, SeedEffect.SEED_ITEMS_COST_MONEY, SeedEffect.SEED_BLACK_ISAAC,
		SeedEffect.SEED_GLOWING_TEARS, SeedEffect.SEED_SLOW_MUSIC, SeedEffect.SEED_ULTRA_SLOW_MUSIC, SeedEffect.SEED_FAST_MUSIC,
		SeedEffect.SEED_ULTRA_FAST_MUSIC, SeedEffect.SEED_KAPPA, SeedEffect.SEED_PERMANENT_CURSE_DARKNESS, SeedEffect.SEED_PREVENT_CURSE_DARKNESS,
		SeedEffect.SEED_PICKUPS_TIMEOUT, SeedEffect.SEED_SHOOT_IN_MOVEMENT_DIRECTION, SeedEffect.SEED_SHOOT_OPPOSITE_MOVEMENT_DIRECTION,
		SeedEffect.SEED_AXIS_ALIGNED_CONTROLS, SeedEffect.SEED_OLD_TV
	},
	-- challenge effects to add after we run out of seed effects (Onan's Streak, Aprils Fool and Ultra Hard should be here)
	CHALLENGES = {Challenge.CHALLENGE_ONANS_STREAK, Challenge.CHALLENGE_APRILS_FOOL, Challenge.CHALLENGE_SPEED, Challenge.CHALLENGE_ULTRA_HARD}, 
	CHEST_CHALLENGE = Challenge.CHALLENGE_NULL, -- for Cathedral/Sheol only (because of Mega Satan door/boss room being generated on the next floor)
	CHEST_SEED_EFFECT =  SeedEffect.SEED_PERMANENT_CURSE_CURSED -- little bonus since no challenge effect would be applied on the Cathedral/Sheol
}

local ChallengeEndStage = { -- table with Challenge IDs mapped to their corresponding end LevelStage values
	[Challenge.CHALLENGE_ONANS_STREAK] = LevelStage.STAGE5, -- Cathedral/Sheol (treated as alts in the game)
	[Challenge.CHALLENGE_APRILS_FOOL] = LevelStage.STAGE4_2, -- Womb/Utero/Scared Womb 2
	[Challenge.CHALLENGE_SPEED] = LevelStage.STAGE4_2,
	[Challenge.CHALLENGE_ULTRA_HARD] = LevelStage.STAGE6 -- Chest/Dark Room (alts)
}

-- Returns a table with every SeedEffect present in the run. Can be called in the menus successfully.
local function get_seed_effects()
	local res = {}
	for _, seed in pairs(SeedEffect) do
		if seeds:HasSeedEffect(seed) then
			table.insert(res, seed)
		end
	end
	return res
end

-- Adds every seed effect from a given table.
local function add_seed_effects(seeds_to_add)
	for _, seed in pairs(seeds_to_add) do
		seeds:AddSeedEffect(seed)
	end
end

-- Get which seeds from a given table are still unused.
local function get_available_seeds(allowed_seeds)
	local res = {}
	for _, seed in pairs(allowed_seeds) do
		if not seeds:HasSeedEffect(seed) then
			table.insert(res, seed)
		end
	end
	return res
end

----> Saving and loading data:
local ModData = {}
local decode_status, decode_retval = pcall(json.decode, mod:LoadData()) -- prevent an error while reading data from stopping the mod completely
-- LoadData() returns an empty string if no save.dat file exists (decode would throw an error in this case)

if decode_status then -- successfully decoded the data into a table
	ModData = decode_retval
else -- error while trying to decode the data
	Isaac.DebugString(string.format("[%s] Couldn't load the mod's data. OriginalChallenge and OriginalSeedEffects will now have the values of the current ones and a new file will be created when the run is exited.", mod.Name))
end

-- Two cases:
-- Successfully loaded but one or more variables could have been removed by some dingus.
-- Failed to load but ModData is already a table which means that all variables below will be nil.
if ModData.OriginalChallenge == nil then ModData.OriginalChallenge = game.Challenge end
if ModData.OriginalSeedEffects == nil then ModData.OriginalSeedEffects = get_seed_effects() end
-- ModData has two useful variables beyond here. It will only be saved again when we exit to the menu.
----> /End of saving and loading data (see on_game_start)

local held_restart_action_for = 0 -- how many game updates the restart action has been pressed for
local function on_update(_)

	local player = Isaac.GetPlayer(0)

	if Input.IsActionPressed(ButtonAction.ACTION_RESTART, 0) or Input.IsActionPressed(ButtonAction.ACTION_RESTART, player.ControllerIndex) then
		held_restart_action_for = held_restart_action_for + 1 -- used in on_game_start()
	else -- reset when we let go
		held_restart_action_for = 0
	end

end

mod:AddCallback(ModCallbacks.MC_POST_UPDATE, on_update)

-- Called when a new run is started to save the original Challenge and SeedEffects selected by the user.
local function on_game_start(_, from_save)
	
	if not from_save then -- run start (Seeds from the eggs menu can only be manually picked before a new run starts)

		if held_restart_action_for > 0 then -- catch restarts (held_restart_action_for keeps its value for one game frame as a new run starts)
			game.Challenge = ModData.OriginalChallenge -- back to original challenge
			seeds:ClearSeedEffects() -- back to normal run (we need to clear seed effects used by Seed of Discord so they don't show up in the next run)
			add_seed_effects(ModData.OriginalSeedEffects) -- readd original ones
		end -- the counter can only be changed after all this has been applied, so you can't clear the seeds by holding restart as the run starts

		-- if this is a restart (manual or after the player lost the run) then get_seed_effects() will return the original seeds from the
		-- previous run (we cleared every seed effect and added only those ones) which is consistent with how the game does it.
		
		ModData.OriginalChallenge = game.Challenge
		ModData.OriginalSeedEffects = get_seed_effects()
		mod:SaveData(json.encode(ModData)) -- save them because the trinket can mess with seeds and the run's challenge
	end
end

-- Called when Isaac wins or loses a run (set seed effects back to original ones -> consistent with how the vanilla game does it)
local function on_game_end(_, was_gameover)
	seeds:ClearSeedEffects() -- back to normal run (we need to clear seed effects used by Seed of Discord so they don't show up in the next run)
	add_seed_effects(ModData.OriginalSeedEffects) -- readd original ones
end

mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, on_game_start)
mod:AddCallback(ModCallbacks.MC_POST_GAME_END, on_game_end)


-- Add special seed or challenge effects every floor, if Seed of Discord is held.
local function on_new_level(_) -- Forget Me Not counts as a level change!

	local player = Isaac.GetPlayer(0)

	if player:HasTrinket(SeedOfDiscord.TRINKET_SEED_OF_DISCORD) then

		local available_seeds = get_available_seeds(SeedOfDiscord.SEEDS)

		-- Add special seed effects
		local seeds_to_add = math.min(SeedOfDiscord.NUM, #available_seeds) -- 3 or fewer

		for i = 1, seeds_to_add do -- add whatever seeds we still can

			local rand_index = math.random(#available_seeds)
			seeds:AddSeedEffect(available_seeds[rand_index])
			--Isaac.DebugString(string.format("###########[%s mod]: Added special seed effect %d.", mod.Name, available_seeds[rand_index]))
			table.remove(available_seeds, rand_index) -- so it can't pick the same one again in another iteration
		
		end

		if #available_seeds == 0 then -- Add a random challenge effect if we can't add a full batch of special seeds
		
			local challenge_table = SeedOfDiscord.CHALLENGES -- we pick from here
			local my_challenge = nil -- challenge to add
			-- Our post_trophy_init() takes care of changing the trophies to the respective level exits depending on the level type.
			-- However, we still need to do one thing: if the end stage of the challenge has an alternative floor (Cathedral/Sheol or 
			-- Chest/Dark Room), the game won't let you spawn an exit to the other one in the previous floor (e.g. because Onan's Streak
			-- ends at Isaac, we can't spawn a trapdoor to Sheol after It Lives or Hush - the game automatically removes them).
			local end_stage = nil -- the challenge normally ends here
			local current_stage = level:GetStage() -- we are here

			repeat -- pick proper challenge effect

				my_challenge = challenge_table[math.random(#challenge_table)]
				end_stage = ChallengeEndStage[my_challenge]

			until not ( end_stage == LevelStage.STAGE5 and (current_stage == LevelStage.STAGE4_2 or current_stage == LevelStage.STAGE4_3) )
			-- The only cases are after Mom's Heart/It lives and Hush (Womb/Utero/Scared Womb 2 (4_2) + Blue Womb (4_3) floors) and
			-- if the challenge would end in the Cathedral or Sheol (5)

			-- One last thing: Mega Satan's door won't spawn unless we have no challenge or are on one which ends at Mega Satan.
			-- This one MUST be added in the Cathedral/Sheol since adding while on the Chest/Dark Room won't change it (checked when it generates the floor I guess)
			if end_stage ~= LevelStage.STAGE6 and current_stage == LevelStage.STAGE5 then -- next challenge to add doesn't end at Chest/Dark Room and we are in Cathedral/Sheol:
				my_challenge = SeedOfDiscord.CHEST_CHALLENGE
				seeds:AddSeedEffect(SeedOfDiscord.CHEST_SEED_EFFECT)
			end

			game.Challenge = my_challenge -- replaces current challenge (0 = no challenge)

			--Isaac.DebugString(string.format("###########[%s mod]: Ran out of special seeds to add. Adding challenge %d effect...", mod.Name, my_challenge))
		end
	end
end

-- Called every time Isaac goes down a floor (or a new floor of the same type due to Forget Me Not) - AFTER the level is generated (pretty sure?).
mod:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, on_new_level)

-- If the current run's challenge ID differs from the original one, instead of spawning a Trophy at or past the target boss, the normal
-- exits will spawn instead (trapdoor, heaven light or big chest).
-- NOTE: it is currently impossible to spawn exits to floors which deviate from the target boss. E.g. if your challenge ends at Isaac,
-- the game won't let you spawn a trapdoor to go to Sheol.

-- Called after a Challenge Trophy is initialized to remove it if the conditions above are met. 
local function post_trophy_init(_, trophy) -- EntityPickup

	-- Boss room in a challenge (which can be applied by the trinket) different from the one picked at the start of a run and Seed of Discord
	-- is now allowed to add challenge effects (no more special seeds left)
	if ModData.OriginalChallenge ~= game.Challenge and (game.Challenge == Challenge.CHALLENGE_ONANS_STREAK or game.Challenge == Challenge.CHALLENGE_APRILS_FOOL
		or game.Challenge == Challenge.CHALLENGE_SPEED or game.Challenge == Challenge.CHALLENGE_ULTRA_HARD)
		and game:GetRoom():GetType() == RoomType.ROOM_BOSS and #get_available_seeds(SeedOfDiscord.SEEDS) == 0 then

		trophy:Remove()

		-- Spawn exits in absolute positions
		local stage = level:GetStage()
		--local is_alt = level:IsAltStage() -- relevant: Cathedral(10a)/Sheol(10), Chest(11a)/Dark Room (11a)

		-- Does not apply to Greed Mode runs (they are treated as different stages)
		if stage == LevelStage.STAGE3_2 or stage == LevelStage.STAGE4_1 then -- Depths 2 or equivalent and Womb 1 (for Mom - this is the first time a win condition is possible)
			
			Isaac.GridSpawn(GridEntityType.GRID_TRAPDOOR, 0, Vector(320, 200), true)
		
		elseif stage == LevelStage.STAGE4_2 then -- Womb 2 or equivalent (for Mom's Heart / It Lives)
			
			Isaac.GridSpawn(GridEntityType.GRID_TRAPDOOR, 0, Vector(280, 280), true) -- to Sheol
			Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.HEAVEN_LIGHT_DOOR, 0, Vector(360, 280), ZERO_VECTOR, nil) -- to Cathedral

		elseif stage == LevelStage.STAGE4_3 then -- ??? (for Hush)

			Isaac.GridSpawn(GridEntityType.GRID_TRAPDOOR, 0, Vector(560, 280), true) -- to Sheol
			Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.HEAVEN_LIGHT_DOOR, 0, Vector(640, 280), ZERO_VECTOR, nil) -- to Cathedral

		elseif stage == LevelStage.STAGE5 or stage == LevelStage.STAGE6 then -- Cathedral/Sheol (for Satan and Isaac) or The Chest/Dark Room (for The Lamb, ??? and maybe Mega Satan)

			Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_BIGCHEST, 0, Vector(320, 280), ZERO_VECTOR, nil) -- to The Chest/Dark Room or game win

		elseif stage == LevelStage.STAGE7 then -- The Void (for Delirium)

			Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_BIGCHEST, 0, Vector(600, 440), ZERO_VECTOR, nil) -- game win

		end

	end
end

mod:AddCallback(ModCallbacks.MC_POST_PICKUP_INIT, post_trophy_init, PickupVariant.PICKUP_TROPHY)