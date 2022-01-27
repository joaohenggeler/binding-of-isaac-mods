--[[
?)]]
-- ################################################## MYSTERY EGG FAMILIAR ##################################################
-- When Isaac takes damage, Mystery Egg breaks and releases a charmed enemy. The type of enemy spawned depends on how many rooms have been cleared with the familiar (see below).
-- Spawned monsters have more health than normal.
-- Synergizes with BFFS!: spawned enemies turn into a random champion type.

local mod = RegisterMod("mystery egg", 1)

local game = Game()
local sfx = SFXManager()

local ZERO_VECTOR = Vector(0, 0)

-- Callback order (reference): NEW ROOM -> CACHE FOR FAMILIARS -> FAMILIAR UPDATE

local MysteryEgg = {
	COLLECTIBLE_MYSTERY_EGG = Isaac.GetItemIdByName("Mystery Egg"), -- item ID
	VARIANT_MYSTERY_EGG = Isaac.GetEntityVariantByName("Mystery Egg"), -- familiar variant
	FRIEND_HP_MULTIPLIER = 1.5, -- how much more HP the friendly egg spawns have

	LVL0_ROOMS_CLEARED = 1, -- <= rooms have to be cleared with a whole egg for a Level 0 buddy (see SPAWNS) to spawn (0 to 1, inclusive)
	LVL1_ROOMS_CLEARED = 4, -- 2 to 4
	LVL2_ROOMS_CLEARED = 7, -- 5 to 7
	LVL3_ROOMS_CLEARED = 10, -- 8 to 10
	LVL4_ROOMS_CLEARED = 13, -- 11 to 13
	-- LVL5 -> greater than LVL4 - >13
	SPAWNS = { -- table that maps an "egg level" to a table of monsters to spawn
		[0] = {EntityType.ENTITY_FLY, EntityType.ENTITY_ATTACKFLY, EntityType.ENTITY_DIP, EntityType.ENTITY_SPIDER,
				EntityType.ENTITY_MAGGOT, EntityType.ENTITY_NERVE_ENDING, EntityType.ENTITY_EMBRYO},
		[1] = {EntityType.ENTITY_MOTER, EntityType.ENTITY_POOTER, EntityType.ENTITY_FLY_L2, EntityType.ENTITY_FULL_FLY,
				EntityType.ENTITY_SUCKER, EntityType.ENTITY_DART_FLY, EntityType.ENTITY_BIGSPIDER, EntityType.ENTITY_HOPPER,
				EntityType.ENTITY_GUSHER, EntityType.ENTITY_HORF, EntityType.ENTITY_SWARM, EntityType.ENTITY_ROUND_WORM,
				EntityType.ENTITY_HEART, EntityType.ENTITY_GUTS, EntityType.ENTITY_GUSH},
		[2] = {EntityType.ENTITY_SQUIRT, EntityType.ENTITY_RAGLING, EntityType.ENTITY_HOMUNCULUS, EntityType.ENTITY_SPIDER_L2,
				EntityType.ENTITY_BABY_LONG_LEGS, EntityType.ENTITY_WALL_CREEP, EntityType.ENTITY_NIGHT_CRAWLER,
				EntityType.ENTITY_ULCER, EntityType.ENTITY_MULLIGAN, EntityType.ENTITY_HIVE, EntityType.ENTITY_NEST,
				EntityType.ENTITY_DUKIE, EntityType.ENTITY_FLAMINGHOPPER, EntityType.ENTITY_GAPER, EntityType.ENTITY_CYCLOPIA,
				EntityType.ENTITY_SKINNY, EntityType.ENTITY_MAW, EntityType.ENTITY_PSY_HORF, EntityType.ENTITY_TUMOR,
				EntityType.ENTITY_FATTY, EntityType.ENTITY_HALF_SACK, EntityType.ENTITY_CLOTTY, EntityType.ENTITY_CHARGER,
				EntityType.ENTITY_BRAIN, EntityType.ENTITY_BUTTLICKER, EntityType.ENTITY_HOST, EntityType.ENTITY_DOPLE,
				EntityType.ENTITY_BABY, EntityType.ENTITY_GLOBIN, EntityType.ENTITY_BLACK_GLOBIN_HEAD, EntityType.ENTITY_BLACK_GLOBIN_BODY,
				EntityType.ENTITY_PARA_BITE, EntityType.ENTITY_CONJOINED_SPITTY, EntityType.ENTITY_MINISTRO, EntityType.ENTITY_ONE_TOOTH},
		[3] = {EntityType.ENTITY_SPLASHER, EntityType.ENTITY_BEGOTTEN, EntityType.ENTITY_PSY_TUMOR, EntityType.ENTITY_BOOMFLY,
				EntityType.ENTITY_BLACK_GLOBIN, EntityType.ENTITY_BONY, EntityType.ENTITY_COD_WORM, EntityType.ENTITY_NULLS,
				EntityType.ENTITY_MEMBRAIN, EntityType.ENTITY_FRED, EntityType.ENTITY_LEECH, EntityType.ENTITY_LUMP,
				EntityType.ENTITY_IMP, EntityType.ENTITY_FAT_BAT, EntityType.ENTITY_CONJOINED_FATTY, EntityType.ENTITY_FLOATING_KNIGHT,
				EntityType.ENTITY_KNIGHT, EntityType.ENTITY_SWINGER, EntityType.ENTITY_BLUBBER, EntityType.ENTITY_OOB,
				EntityType.ENTITY_WIZOOB, EntityType.ENTITY_KEEPER, EntityType.ENTITY_HANGER, EntityType.ENTITY_MUSHROOM,
				EntityType.ENTITY_BONE_KNIGHT, EntityType.ENTITY_FLESH_DEATHS_HEAD, EntityType.ENTITY_MRMAW, EntityType.ENTITY_LEAPER,
				EntityType.ENTITY_THE_THING, EntityType.ENTITY_BLISTER, EntityType.ENTITY_POISON_MIND, EntityType.ENTITY_BLIND_CREEP,
				EntityType.ENTITY_TARBOY, EntityType.ENTITY_FISTULOID},
		[4] = {EntityType.ENTITY_GURGLE, EntityType.ENTITY_WALKINGBOIL, EntityType.ENTITY_CAMILLO_JR, EntityType.ENTITY_MOBILE_HOST,
				EntityType.ENTITY_EYE, EntityType.ENTITY_ROUNDY, EntityType.ENTITY_MOMS_HAND, EntityType.ENTITY_BLACK_MAW,
				EntityType.ENTITY_MEGA_CLOTTY, EntityType.ENTITY_FAT_SACK, EntityType.ENTITY_BLACK_BONY, EntityType.ENTITY_SWARMER},
		[5] = {EntityType.ENTITY_RED_GHOST, EntityType.ENTITY_GURGLING, EntityType.ENTITY_DINGA, EntityType.ENTITY_PORTAL,
				EntityType.ENTITY_RAGE_CREEP, EntityType.ENTITY_VIS}
	}
}

if not __eidItemDescriptions then __eidItemDescriptions = {}; end -- External Item Descriptions compatibility
__eidItemDescriptions[MysteryEgg.COLLECTIBLE_MYSTERY_EGG] = "Breaks and spawns a charmed enemy when Isaac takes damage#Respawns every room#The longer the egg is kept intact, the better the enemy";

local cracked_eggs = 0 -- used to control the number of Eggs in CheckFamiliar() since they're removed when they die

-- Called when the follower first spawns or when we come back after an exit/continue
local function init_mystery_egg(_, mystery_egg) -- EntityFamiliar
	mystery_egg:AddToFollowers() -- set IsFollower to true so the familiar is alligned correctly in the familiar train (in CheckFamiliar())
end

mod:AddCallback(ModCallbacks.MC_FAMILIAR_INIT, init_mystery_egg, MysteryEgg.VARIANT_MYSTERY_EGG)

-- Called every game update for each Mystery Egg follower
local function update_mystery_egg(_, mystery_egg) -- EntityFamiliar

	mystery_egg:FollowParent() -- follow the familiar train
	local sprite = mystery_egg:GetSprite()

	if sprite:IsEventTriggered("Spawn") then

		local spawn_table = MysteryEgg.SPAWNS[5]
		if mystery_egg.RoomClearCount <= MysteryEgg.LVL0_ROOMS_CLEARED then
			spawn_table = MysteryEgg.SPAWNS[0]
		elseif mystery_egg.RoomClearCount <= MysteryEgg.LVL1_ROOMS_CLEARED then
			spawn_table = MysteryEgg.SPAWNS[1]
		elseif mystery_egg.RoomClearCount <= MysteryEgg.LVL2_ROOMS_CLEARED then
			spawn_table = MysteryEgg.SPAWNS[2]
		elseif mystery_egg.RoomClearCount <= MysteryEgg.LVL3_ROOMS_CLEARED then
			spawn_table = MysteryEgg.SPAWNS[3]
		elseif mystery_egg.RoomClearCount <= MysteryEgg.LVL4_ROOMS_CLEARED then
			spawn_table = MysteryEgg.SPAWNS[4]
		end

		local buddy = Isaac.Spawn(spawn_table[math.random(#spawn_table)], 0, 0, mystery_egg.Position, ZERO_VECTOR, nil):ToNPC()
		buddy:AddCharmed(-1) -- permanent charm (like Friend Ball)

		if mystery_egg.Player:HasCollectible(CollectibleType.COLLECTIBLE_BFFS) then -- BFFS! synergy
			buddy:MakeChampion(buddy.DropSeed)
		end -- this should be before the hit point changes (MakeChampion messes with those attributes)

		buddy.MaxHitPoints = buddy.MaxHitPoints * MysteryEgg.FRIEND_HP_MULTIPLIER
		buddy.HitPoints = buddy.HitPoints * MysteryEgg.FRIEND_HP_MULTIPLIER

		mystery_egg.RoomClearCount = 0
		cracked_eggs = cracked_eggs + 1
		sfx:Play(SoundEffect.SOUND_PLOP, 1.0, buddy.Index % 11, false, 1.0) -- FrameDelay prevents various eggs breaking from sounding weird

		mystery_egg:BloodExplode() -- based on the gibs tag in entities2.xml

	end

	if sprite:IsFinished("Crack") then
		mystery_egg:Remove()
	end

end

mod:AddCallback(ModCallbacks.MC_FAMILIAR_UPDATE, update_mystery_egg, MysteryEgg.VARIANT_MYSTERY_EGG)

-- Called every new room to set the state back to "idle" (whole egg)
local function on_new_room(_)
	local player = Isaac.GetPlayer(0)	
	if player:HasCollectible(MysteryEgg.COLLECTIBLE_MYSTERY_EGG) then
		cracked_eggs = 0
		player:RespawnFamiliars()
	end
end

mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, on_new_room)

-- Called every time Isaac takes damage to set the state to "cracked" and play the right animation
local function player_damaged(_, dmg_target, dmg_amount, dmg_flags, dmg_source, dmg_countdown_frames)

	local player = Isaac.GetPlayer(0)
	if player:HasCollectible(MysteryEgg.COLLECTIBLE_MYSTERY_EGG) then
		for _, mystery_egg in pairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, MysteryEgg.VARIANT_MYSTERY_EGG, -1, false, false)) do
			mystery_egg:GetSprite():Play("Crack", false) -- will trigger spawn event
		end
	end
end

mod:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, player_damaged, EntityType.ENTITY_PLAYER)

-- Called when the run starts to reset the number of cracked eggs
local function on_game_start(_, from_save) -- from_save = is_continue
	if not from_save then -- run start
		cracked_eggs = 0
	end
end

mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, on_game_start)

-- Called every time the cache is reevaluated to add/remove a Mystery Egg
local function update_cache(_, player, cache_flag)
	if cache_flag == CacheFlag.CACHE_FAMILIARS then
		--if cracked_eggs == nil then cracked_eggs = player:GetCollectibleNum(MysteryEgg.COLLECTIBLE_MYSTERY_EGG) end
		player:CheckFamiliar(MysteryEgg.VARIANT_MYSTERY_EGG, math.max(0, player:GetCollectibleNum(MysteryEgg.COLLECTIBLE_MYSTERY_EGG) - cracked_eggs), player:GetCollectibleRNG(MysteryEgg.COLLECTIBLE_MYSTERY_EGG))
	end
end

mod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, update_cache)