--[[
?]]
-- ################################################## PENNY PINCHER CHALLENGE ##################################################
-- Character: The Keeper
-- Starting items: Sack of Pennies, Money = Power, Deep Pockets, Head of the Keeper, Eye of Greed, Dad's Lost Coin, Crooked Penny,
-- Greed's Gullet, Store Key, Ace of Diamonds and The Fool card (spawned in the first floor's starting room).
-- Goal:  buy a Trophy that costs 99 cents and is located on every Starting Room of every floor
-- Conditions: Infinite Basement seed effect, the Keeper dies after 7 floors, no Sacrifice or Dice Rooms, no curses

local mod = RegisterMod("penny pincher", 1)

local json = require("json") -- for saving and loading data

local ZERO_VECTOR = Vector(0, 0)

local game = Game()
local game_seeds = game:GetSeeds()
local level = game:GetLevel()
local itempool = game:GetItemPool()
local sfx = SFXManager()

local PennyPincher = {
	CHALLENGE_PENNY_PINCHER = Isaac.GetChallengeIdByName("Penny Pincher"),
	TROPHY_PRICE = 99, -- how much the Challenge Trophy costs (in cents)
	MAX_LEVEL_NUM = 8, -- the player is killed if they reach this floor (or go beyond); CurrentLevelNum starts at 1 (Basement I)
	MAX_PROGRESS_DIGIT = 8, -- the Progress Keeper's sign/head digits goes from 0 to this; used to clamp the value passed to SetFrame()

	TROPHY_KEEPER_VARIANT = Isaac.GetEntityVariantByName("Penny Pincher Trophy Keeper"),
	PROGRESS_KEEPER_VARIANT = Isaac.GetEntityVariantByName("Penny Pincher Progress Keeper"),
	PROGRESS_KEEPER_ANIMATIONS = {"Guy1", "Guy2", "Guy3", "Guy4", "Guy5"}, -- possible Progress Keeper visuals (needed since GetCurrentAnimation()
	-- isn't a thing yet and we need to know it to set the sign/head number)

	TROPHY_KEEPER_POSITION_OFFSET = Vector(-80, 0), -- where it spawns relative to the Trophy (center of the starting room)
	PROGRESS_KEEPER_POSITION_OFFSET = Vector(80, 0),
	PENALTY_HANGER_ENEMIES_POSITION_OFFSETS = {Vector(240, 120), Vector(-240, -120)}, -- same as above for Hanger enemies when the max floor is reached
	PENALTY_DEATH_FREQUENCY = 150 -- when the player reaches/passes the max floor, they'll be killed every *this* game frames (sorry for the weird name)
}

----> Saving and loading data:
local ModData = {}
local decode_status, decode_retval = pcall(json.decode, mod:LoadData()) -- prevent an error while reading data from stopping the mod completely
-- LoadData() returns an empty string if no save.dat file exists (decode would throw an error in this case)

if decode_status then -- successfully decoded the data into a table
	ModData = decode_retval
else -- error while trying to decode the data
	Isaac.DebugString(string.format("[%s] Couldn't load the mod's data. CurrentLevelNum will be set to 1 and a new file will be created when the run is exited.", mod.Name))
end

-- Two cases:
-- Successfully loaded but one or more variables could have been removed by some dingus.
-- Failed to load but ModData is already a table which means that all variables below will be nil.
if ModData.CurrentLevelNum == nil then ModData.CurrentLevelNum = 1 end
-- ModData has one useful variable beyond here. It will only be saved again when we exit to the menu.

local function pre_game_exit(_, should_save)
	if should_save then -- we always come through here before it's possible to reload mods in the Mods menu
		mod:SaveData(json.encode(ModData))
	end -- even if we choose to continue, ModData still holds the correct values, regardless of whether the mod has been reloaded
	-- (not should_save) is when you win/lose a run. It's not really necessary to save then in this particular mod.
end

mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, pre_game_exit)
----> /End of saving and loading data.

-- CurrentLevelNum = which Basement floor we are on (Infinite Basements Seed Effect); starts at 1 (Basement I).
-- We don't need to worry about Curse of the Labyrinth since all curses are disabled for this Challenge.

local function post_new_level(_) -- always called before the Keepers' init and update functions
	if game.Challenge == PennyPincher.CHALLENGE_PENNY_PINCHER then

		--Isaac.DebugString(string.format("-------------- [PENNY PINCHER] New Room; GameFrameCount=%d", game:GetFrameCount()))
		if game:GetFrameCount() == 0 then -- run start
			ModData.CurrentLevelNum = 1 -- Basement I (never XL since curses are filtered)
		else -- floor transition
			ModData.CurrentLevelNum = ModData.CurrentLevelNum + 1
		end
		
		local center_pos = game:GetRoom():GetCenterPos()
		local trophy = Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TROPHY, 0, center_pos, ZERO_VECTOR, nil):ToPickup()
		trophy.AutoUpdatePrice = false
		trophy.Price = PennyPincher.TROPHY_PRICE

		local trophy_keeper = Isaac.Spawn(EntityType.ENTITY_SHOPKEEPER, PennyPincher.TROPHY_KEEPER_VARIANT, 0,
											center_pos + PennyPincher.TROPHY_KEEPER_POSITION_OFFSET, ZERO_VECTOR, nil)
		

		if ModData.CurrentLevelNum == 1 then -- spawn a Fool card on the first floor
			Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TAROTCARD, Card.CARD_FOOL,
						center_pos + PennyPincher.PROGRESS_KEEPER_POSITION_OFFSET, ZERO_VECTOR, nil)
		else -- on any other floor, spawn the Keeper that keeps track of how many floors we have left
			local progress_keeper = Isaac.Spawn(EntityType.ENTITY_SHOPKEEPER, PennyPincher.PROGRESS_KEEPER_VARIANT, 0,
											center_pos + PennyPincher.PROGRESS_KEEPER_POSITION_OFFSET, ZERO_VECTOR, nil)
		end

		if PennyPincher.MAX_LEVEL_NUM - ModData.CurrentLevelNum <= 0 then -- reached the last floor of the Challenge

			for _, hanger_position_offset in pairs(PennyPincher.PENALTY_HANGER_ENEMIES_POSITION_OFFSETS) do
				Isaac.Spawn(EntityType.ENTITY_HANGER, 0, 0, center_pos + hanger_position_offset, ZERO_VECTOR, nil)
			end

			game:GetRoom():SetClear(false) -- close the doors
			sfx:Play(SoundEffect.SOUND_MOM_VOX_EVILLAUGH, 1.0, 0, false, 1.0)

		end

	end
end

mod:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, post_new_level)

local function post_shopkeeper_init(_, keeper)
	--Isaac.DebugString(string.format("-------------- [PENNY PINCHER] Keepers; GameFrameCount=%d", game:GetFrameCount()))
	if keeper.Variant == PennyPincher.TROPHY_KEEPER_VARIANT then
		keeper:GetSprite():PlayRandom(keeper.InitSeed)
	end
end                    

mod:AddCallback(ModCallbacks.MC_POST_NPC_INIT, post_shopkeeper_init, EntityType.ENTITY_SHOPKEEPER)

local function post_shopkeeper_update(_, keeper)
	if keeper.Variant == PennyPincher.PROGRESS_KEEPER_VARIANT then
		-- Unlike the keeper above, the Progress Keeper shows us which floor we are on meaning we have to use SetFrame(). Since this
		-- function always needs an Animation Name (and there is no GetCurrentAnimation()) we pick a seeded one. This ensures that
		-- it will always be the animation for the same entity (if we exit and come back, the keeper will look the same).
		-- This could have all been avoided if we could mess with Null Layers (come on Nicalis...)
		local rng = RNG()
		rng:SetSeed(keeper.InitSeed, 0) -- pick random animation (Lua tables are 1 indexed)
		local random_anim = PennyPincher.PROGRESS_KEEPER_ANIMATIONS[rng:RandomInt(#PennyPincher.PROGRESS_KEEPER_ANIMATIONS) + 1]
		--Isaac.DebugString(string.format("-------------- [PENNY PINCHER] Progress Keeper anim = %s", random_anim))
		keeper:SetSpriteFrame(random_anim, -- FrameNum = how many floors we have left (clamped between 0 and MAX_DIGIT)
							math.min(math.max(0, PennyPincher.MAX_LEVEL_NUM - ModData.CurrentLevelNum), PennyPincher.MAX_PROGRESS_DIGIT))
	end
end

mod:AddCallback(ModCallbacks.MC_NPC_UPDATE, post_shopkeeper_update, EntityType.ENTITY_SHOPKEEPER)

local function post_peffect_update(_, player) -- kill the player if they reach/pass the maximum number of floors in the Challenge
	if game.Challenge == PennyPincher.CHALLENGE_PENNY_PINCHER and PennyPincher.MAX_LEVEL_NUM - ModData.CurrentLevelNum <= 0 then
		local room_frame_count = game:GetRoom():GetFrameCount()
		if room_frame_count > 0 and room_frame_count % PennyPincher.PENALTY_DEATH_FREQUENCY == 0 then
			player:TakeDamage(1.0, DamageFlag.DAMAGE_INVINCIBLE, EntityRef(player), 0) -- potentially set LastDamageSource to the player
			-- so Isaac's face shows up in the game over screen (just like in other Challenges, e.g: Onan's Streak)
			player:Kill()
		end
	end
end

local function post_projectile_init(_, bullet) -- during the Challenge, every enemy projectile has the same effect as Greed's bullets
	if game.Challenge == PennyPincher.CHALLENGE_PENNY_PINCHER then
		bullet:AddProjectileFlags(ProjectileFlags.GREED)
	end
end

local function post_pickup_selection(_, pickup, variant, subtype) -- replace certain pickups during the Challenge (balancing)
	if game.Challenge == PennyPincher.CHALLENGE_PENNY_PINCHER then
		if variant == PickupVariant.PICKUP_TAROTCARD and subtype == Card.CARD_DIAMONDS_2 then
			return {PickupVariant.PICKUP_TAROTCARD, Card.CARD_ACE_OF_DIAMONDS}
		end
	end
end

local function post_game_started(_, from_save)

	-- Add/remove callbacks based on if we're starting/continuing the challenge:
	-- Callback removals need to be here otherwise you could potentially add the same callbacks by restarting.
	-- Remember that callbacks are reset when you (re)load a mod (luamod or from the menu). Since these are in a POST_GAME_STARTED
	-- callback, they could potentially be lost if the mod is reloaded mid game (not that a normal player would do that).
	mod:RemoveCallback(ModCallbacks.MC_POST_PROJECTILE_INIT, post_projectile_init)
	mod:RemoveCallback(ModCallbacks.MC_POST_PICKUP_SELECTION, post_pickup_selection)
	mod:RemoveCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, post_peffect_update)

	if game.Challenge == PennyPincher.CHALLENGE_PENNY_PINCHER then
		mod:AddCallback(ModCallbacks.MC_POST_PROJECTILE_INIT, post_projectile_init)
		mod:AddCallback(ModCallbacks.MC_POST_PICKUP_SELECTION, post_pickup_selection)
		mod:AddCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, post_peffect_update)

		if not from_save then  -- stuff only to be done at the start of the challenge run
			game_seeds:AddSeedEffect(SeedEffect.SEED_INFINITE_BASEMENT)
			itempool:RemoveCollectible(CollectibleType.COLLECTIBLE_COUPON) -- remove certain items from their pools
		end
	end

end

mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, post_game_started)