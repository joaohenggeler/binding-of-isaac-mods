--[[
)?]]
-- ################################################## FAMILIAR DOLL TRINKET ##################################################
-- While held, bosses have a 40% chance to drop items thematically related to them.
-- Mom will always drop The Polaroid and The Negative first.
-- Drops from other sources such as Mystery Gift and Eden's Soul are also affected while in the Boss Room.
-- Synergizes with Mom's Box: chance is 80% instead.

local mod = RegisterMod("familiar doll", 1)

local game = Game()

local FamiliarDoll = {
	TRINKET_FAMILIAR_DOLL = Isaac.GetTrinketIdByName("Familiar Doll"), -- trinket ID
	CHANCE = 0.40, -- chance of the trinkt effect happening (0 to 1)
	MOMS_BOX_CHANCE_MULTIPLIER = 2.0, -- how much the above is multiplied by when Isaac has Mom's Box (synergy)
	SPOILS = { -- table that maps a Boss Id to a table of CollectibleTypes to possibly spawn instead of the normal drop
	-- IDs taken from bossportraits.xml (not in the enums)
		[1] = {CollectibleType.COLLECTIBLE_MONSTROS_TOOTH, CollectibleType.COLLECTIBLE_LIL_MONSTRO}, -- Monstro
		[2] = {CollectibleType.COLLECTIBLE_POOP}, -- Larry Jr
		[3] = {CollectibleType.COLLECTIBLE_LITTLE_CHUBBY, CollectibleType.COLLECTIBLE_BIG_CHUBBY}, -- Chub
		[4] = {CollectibleType.COLLECTIBLE_LIL_GURDY}, -- Gurdy
		[5] = {CollectibleType.COLLECTIBLE_MONSTROS_TOOTH, CollectibleType.COLLECTIBLE_MONSTROS_LUNG}, -- Monstro 2
		[6] = {CollectibleType.COLLECTIBLE_MOMS_UNDERWEAR, CollectibleType.COLLECTIBLE_MOMS_HEELS, CollectibleType.COLLECTIBLE_MOMS_LIPSTICK,
				CollectibleType.COLLECTIBLE_MOMS_BRA, CollectibleType.COLLECTIBLE_MOMS_PAD, CollectibleType.COLLECTIBLE_MOMS_EYE,
				CollectibleType.COLLECTIBLE_MOMS_BOTTLE_PILLS, CollectibleType.COLLECTIBLE_MOMS_CONTACTS, CollectibleType.COLLECTIBLE_MOMS_KNIFE,
			   	CollectibleType.COLLECTIBLE_MOMS_PURSE, CollectibleType.COLLECTIBLE_MOMS_COIN_PURSE, CollectibleType.COLLECTIBLE_MOMS_KEY,
			    CollectibleType.COLLECTIBLE_MOMS_EYESHADOW, CollectibleType.COLLECTIBLE_MOMS_WIG, CollectibleType.COLLECTIBLE_MOMS_PERFUME,
		     	CollectibleType.COLLECTIBLE_MOMS_PEARLS, CollectibleType.COLLECTIBLE_MOMS_BOX, CollectibleType.COLLECTIBLE_MOMS_RAZOR,
		      	CollectibleType.COLLECTIBLE_MAMA_MEGA}, -- Mom (The Polaroid and The Negative ALWAYS drop first; these only drop if rerolled or with Mystery Gift)
		-- 7 - Scolex
		[8] = {CollectibleType.COLLECTIBLE_ISAACS_HEART, CollectibleType.COLLECTIBLE_SACRED_HEART,
				CollectibleType.COLLECTIBLE_BFFS, CollectibleType.COLLECTIBLE_HEART,
				CollectibleType.COLLECTIBLE_YUM_HEART}, -- Mom's Heart
		[9] = {CollectibleType.COLLECTIBLE_LIL_HARBINGERS, CollectibleType.COLLECTIBLE_RAW_LIVER}, -- Famine (extra drops besides Cube of Meat)
		[10] = {CollectibleType.COLLECTIBLE_LIL_HARBINGERS, CollectibleType.COLLECTIBLE_COMMON_COLD, CollectibleType.COLLECTIBLE_SINUS_INFECTION,
				CollectibleType.COLLECTIBLE_LEPROCY}, -- Pestilence
		[11] = {CollectibleType.COLLECTIBLE_LIL_HARBINGERS, CollectibleType.COLLECTIBLE_CURSE_OF_THE_TOWER, CollectibleType.COLLECTIBLE_PYROMANIAC}, -- War
		[12] = {CollectibleType.COLLECTIBLE_HOURGLASS, CollectibleType.COLLECTIBLE_DEATHS_TOUCH, CollectibleType.COLLECTIBLE_LIL_HARBINGERS,
				CollectibleType.COLLECTIBLE_DEATH_LIST}, -- Death
		[13] = {CollectibleType.COLLECTIBLE_SKATOLE, CollectibleType.COLLECTIBLE_HALO_OF_FLIES, CollectibleType.COLLECTIBLE_DISTANT_ADMIRATION,
				CollectibleType.COLLECTIBLE_FOREVER_ALONE, CollectibleType.COLLECTIBLE_MULLIGAN, CollectibleType.COLLECTIBLE_BEST_BUD,
				CollectibleType.COLLECTIBLE_FRIEND_ZONE, CollectibleType.COLLECTIBLE_LOST_FLY,  CollectibleType.COLLECTIBLE_OBSESSED_FAN}, -- Duke of Flies
		[14] = {CollectibleType.COLLECTIBLE_NUMBER_ONE, CollectibleType.COLLECTIBLE_LEMON_MISHAP, CollectibleType.COLLECTIBLE_PEEPER}, -- Peep
		[15] = {CollectibleType.COLLECTIBLE_LOKIS_HORNS, CollectibleType.COLLECTIBLE_LIL_LOKI}, -- Loki
		-- 16 - Blastocyst
		[17] = {CollectibleType.COLLECTIBLE_GEMINI}, -- Gemini
		-- 18 - Fistula
		[19] = {CollectibleType.COLLECTIBLE_BALL_OF_TAR}, -- Gish (already has a drop but this still works - this goes for some of the ones below too)
		[20] = {CollectibleType.COLLECTIBLE_BOX, CollectibleType.COLLECTIBLE_BUDDY_IN_A_BOX, CollectibleType.COLLECTIBLE_MOVING_BOX}, -- Steven (get in the box!)
		[21] = {CollectibleType.COLLECTIBLE_SMB_SUPER_FAN, CollectibleType.COLLECTIBLE_CUBE_OF_MEAT, CollectibleType.COLLECTIBLE_BALL_OF_BANDAGES,
				CollectibleType.COLLECTIBLE_SUPER_BANDAGE, CollectibleType.COLLECTIBLE_DR_FETUS}, -- CHAD
		[22] = {CollectibleType.COLLECTIBLE_PINKING_SHEARS, CollectibleType.COLLECTIBLE_SCISSORS}, -- Headless Horseman
		-- 23 - The Fallen
		[24] = {CollectibleType.COLLECTIBLE_MEGA_SATANS_BREATH}, -- Satan (possible with Mystery Gift and in the Void)
		[25] = {CollectibleType.COLLECTIBLE_CAMBION_CONCEPTION, CollectibleType.COLLECTIBLE_IMMACULATE_CONCEPTION}, -- It Lives! (possible with Mystery Gift)
		-- 26 - The Hollow
		-- 27 - Carrion Queen
		[28] = {CollectibleType.COLLECTIBLE_LIL_GURDY}, -- Gurdy Jr
		[29] = {CollectibleType.COLLECTIBLE_JAR_OF_FLIES, CollectibleType.COLLECTIBLE_PAPA_FLY, CollectibleType.COLLECTIBLE_HIVE_MIND,
				CollectibleType.COLLECTIBLE_SMART_FLY, CollectibleType.COLLECTIBLE_BBF, CollectibleType.COLLECTIBLE_BIG_FAN,
				CollectibleType.COLLECTIBLE_BLUEBABYS_ONLY_FRIEND, CollectibleType.COLLECTIBLE_PARASITOID, CollectibleType.COLLECTIBLE_ANGRY_FLY}, -- The Husk
		[30] = {CollectibleType.COLLECTIBLE_PEEPER, CollectibleType.COLLECTIBLE_POP}, -- The Bloat
		[31] = {CollectibleType.COLLECTIBLE_LOKIS_HORNS, CollectibleType.COLLECTIBLE_LIL_LOKI}, -- Lokii
		[32] = {CollectibleType.COLLECTIBLE_GEMINI, CollectibleType.COLLECTIBLE_LIL_HAUNT}, -- Blighted Ovum
		-- 33 - Teratoma
		[34] = {CollectibleType.COLLECTIBLE_SPIDER_BITE, CollectibleType.COLLECTIBLE_SPIDER_BUTT, CollectibleType.COLLECTIBLE_SPIDERBABY,
				CollectibleType.COLLECTIBLE_INFESTATION_2, CollectibleType.COLLECTIBLE_BOX_OF_SPIDERS, CollectibleType.COLLECTIBLE_BURSTING_SACK}, -- The Widow
		[35] = {CollectibleType.COLLECTIBLE_ISAACS_HEART, CollectibleType.COLLECTIBLE_INFAMY, CollectibleType.COLLECTIBLE_WHORE_OF_BABYLON}, -- Mask of Infamy
		[36] = {CollectibleType.COLLECTIBLE_MUTANT_SPIDER, CollectibleType.COLLECTIBLE_HIVE_MIND, CollectibleType.COLLECTIBLE_JUICY_SACK,
				CollectibleType.COLLECTIBLE_STICKY_BOMBS, CollectibleType.COLLECTIBLE_SPIDER_MOD, CollectibleType.COLLECTIBLE_PARASITOID}, -- The Wretched
		-- 37 - Pin
		[38] = {CollectibleType.COLLECTIBLE_LIL_HARBINGERS}, -- Conquest (extra drop)
		[39] = {CollectibleType.COLLECTIBLE_ISAACS_HEART, CollectibleType.COLLECTIBLE_ISAACS_TEARS, CollectibleType.COLLECTIBLE_D6}, -- Isaac (possible in the Void)
		[40] = {CollectibleType.COLLECTIBLE_BROTHER_BOBBY, CollectibleType.COLLECTIBLE_FATE, CollectibleType.COLLECTIBLE_FATES_REWARD,
				CollectibleType.COLLECTIBLE_BLUEBABYS_ONLY_FRIEND}, -- Blue Baby (possible in the Void)
		[41] = {CollectibleType.COLLECTIBLE_DADDY_LONGLEGS, CollectibleType.COLLECTIBLE_SISSY_LONGLEGS}, -- Daddy Long Legs
		[42] = {CollectibleType.COLLECTIBLE_DADDY_LONGLEGS}, -- Triachnid
		[43] = {CollectibleType.COLLECTIBLE_GHOST_BABY, CollectibleType.COLLECTIBLE_LIL_HAUNT, CollectibleType.COLLECTIBLE_GHOST_PEPPER}, -- The Haunt
		[44] = {CollectibleType.COLLECTIBLE_POOP, CollectibleType.COLLECTIBLE_BUTT_BOMBS, CollectibleType.COLLECTIBLE_E_COLI,
				CollectibleType.COLLECTIBLE_FLUSH}, -- Dingle
		[45] = {CollectibleType.COLLECTIBLE_FIRE_MIND}, -- Mega Maw
		[46] = {CollectibleType.COLLECTIBLE_HOST_HAT}, -- The Gate
		[47] = {CollectibleType.COLLECTIBLE_FARTING_BABY, CollectibleType.COLLECTIBLE_MEGA_BEAN}, -- Mega Fatty
		-- 48 - The Cage
		[49] = {CollectibleType.COLLECTIBLE_LIL_GURDY, CollectibleType.COLLECTIBLE_MAMA_MEGA}, -- Mama Gurdy
		[50] = {CollectibleType.COLLECTIBLE_BLACK_CANDLE}, -- The Dark One
		[51] = {CollectibleType.COLLECTIBLE_BLACK_CANDLE}, -- The Adversary
		[52] = {CollectibleType.COLLECTIBLE_POLYDACTYLY, CollectibleType.COLLECTIBLE_POLYPHEMUS, CollectibleType.COLLECTIBLE_STEVEN,
				CollectibleType.COLLECTIBLE_STEM_CELLS}, -- Polycephalus
		[53] = {CollectibleType.COLLECTIBLE_HARLEQUIN_BABY}, -- Mr Fred
		-- 54 - The Lamb
		[55] = {CollectibleType.COLLECTIBLE_MEGA_SATANS_BREATH}, -- Mega Satan (possible with Mystery Gift)
		[56] = {CollectibleType.COLLECTIBLE_LIL_GURDY}, -- Gurglings
		-- 57 - The Stain
		[58] = {CollectibleType.COLLECTIBLE_POOP, CollectibleType.COLLECTIBLE_BUTT_BOMBS, CollectibleType.COLLECTIBLE_E_COLI,
				CollectibleType.COLLECTIBLE_FLUSH, CollectibleType.COLLECTIBLE_BROWN_NUGGET}, -- Brownie (same as Dingle + Brown Nugget)
		[59] = {CollectibleType.COLLECTIBLE_GHOST_BABY, CollectibleType.COLLECTIBLE_COMPOUND_FRACTURE, CollectibleType.COLLECTIBLE_GHOST_PEPPER}, -- The Forsaken
		[60] = {CollectibleType.COLLECTIBLE_LITTLE_HORN}, -- Little Horn
		[61] = {CollectibleType.COLLECTIBLE_LAZARUS_RAGS, CollectibleType.COLLECTIBLE_OLD_BANDAGE, CollectibleType.COLLECTIBLE_SPOON_BENDER}, -- Rag Man
		[62] = {CollectibleType.COLLECTIBLE_HEAD_OF_THE_KEEPER, CollectibleType.COLLECTIBLE_EYE_OF_GREED, CollectibleType.COLLECTIBLE_GREEDS_GULLET}, -- Ultra Greed (possible with Mystery Gift)
		[63] = {CollectibleType.COLLECTIBLE_HUSHY}, -- Hush (possible with Mystery Gift)
		[64] = {CollectibleType.COLLECTIBLE_POOP, CollectibleType.COLLECTIBLE_BUTT_BOMBS, CollectibleType.COLLECTIBLE_E_COLI,
				CollectibleType.COLLECTIBLE_FLUSH, CollectibleType.COLLECTIBLE_NUMBER_TWO}, -- Dangle (same as Dingle + No. 2)
		[65] = {CollectibleType.COLLECTIBLE_POOP, CollectibleType.COLLECTIBLE_BUTT_BOMBS, CollectibleType.COLLECTIBLE_E_COLI,
				CollectibleType.COLLECTIBLE_FLUSH, CollectibleType.COLLECTIBLE_LIL_GURDY}, -- Turdling (same as Dingle + Lil Gurdy)
		-- 66 - The Frail
		[67] = {CollectibleType.COLLECTIBLE_LAZARUS_RAGS, CollectibleType.COLLECTIBLE_OLD_BANDAGE, CollectibleType.COLLECTIBLE_SPOON_BENDER}, -- Rag Mega
		[68] = {CollectibleType.COLLECTIBLE_GIMPY}, -- Sisters Vis
		[69] = {CollectibleType.COLLECTIBLE_LITTLE_HORN}, -- Big Horn
		[70] = {CollectibleType.COLLECTIBLE_DELIRIOUS, CollectibleType.COLLECTIBLE_LIL_DELIRIUM} -- Delirium (last one for now + possible with Mystery Gift)
	}
}

if not __eidTrinketDescriptions then __eidTrinketDescriptions = {}; end -- External Item Descriptions compatibility
__eidTrinketDescriptions[FamiliarDoll.TRINKET_FAMILIAR_DOLL] = "Chance to replace boss drops with thematically related items";

local function post_get_collectible(_, collectible, pool_type, decrease, seed)

	local player = Isaac.GetPlayer(0)

	if player:HasTrinket(FamiliarDoll.TRINKET_FAMILIAR_DOLL) and game:GetRoom():GetBossID() ~= 0 then
		-- We don't filter by the Pool Type since bosses drop pools can change (Chaos or in The Void floor)

		if game:GetRoom():GetBossID() == 6 and (collectible == CollectibleType.COLLECTIBLE_POLAROID
			or collectible == CollectibleType.COLLECTIBLE_NEGATIVE) then -- The Polaroid or the Negative were chosen in Mom's Boss Room
			return nil -- ignore the trinket's effect
		end

		local rng = player:GetTrinketRNG(FamiliarDoll.TRINKET_FAMILIAR_DOLL)
		local chance_multiplier = 1.0
		if player:HasCollectible(CollectibleType.COLLECTIBLE_MOMS_BOX) then -- Mom's Box synergy
			chance_multiplier = FamiliarDoll.MOMS_BOX_CHANCE_MULTIPLIER
		end

		if FamiliarDoll.CHANCE * chance_multiplier >= rng:RandomFloat() then -- lucky enough for the trinket effect

			local next_item_table = FamiliarDoll.SPOILS[game:GetRoom():GetBossID()]
			if next_item_table ~= nil then
				return next_item_table[rng:RandomInt(#next_item_table) + 1] -- random choice (tables are 1 indexed)
				-- the return value can be nil (somehow not found in the table), the normal item will be chosen instead - it's fine!
			end

		end

	end

end

mod:AddCallback(ModCallbacks.MC_POST_GET_COLLECTIBLE, post_get_collectible)