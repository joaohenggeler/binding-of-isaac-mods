--[[
?)]]

-- ################################################## TURN TO TOAD - CARD ##################################################
-- When used, the closest vulnerable enemy to Isaac is turned into a Blue Toad.
-- Blue Toads jump around like Hoppers and always drop a soul heart on death.
-- After 10 seconds of turning into a toad, if they haven't been killed yet, they'll change back and be CONFUSED for 120 frames.
-- Certain toad bosses (Hush, Ultra Greed, Delirium and some variants of these) take even more damage than regular toads.

-- NOTE: In the original design, blue frogs would be stripped of boss armor and could be affected by every status effect.

local mod = RegisterMod("turn to toad", 1)

local FrogVariants = { -- aka Flaming Hopper variants
	BLUE_FROG = Isaac.GetEntityVariantByName("Blue Frog"),
	BLUE_FROG_BOSS = Isaac.GetEntityVariantByName("Blue Frog Boss")
}

local TurnToToad = {
	CARD_TURN_TO_TOAD = Isaac.GetCardIdByName("c01_TurnToToad"), -- you get them by the HUD and not the NAME
	ENTITY_BLUE_FROG = Isaac.GetEntityTypeByName("Blue Frog"), -- entity type (should be the same as a Flaming Hopper's ID)
	SOUND_FROG_CROAK = Isaac.GetSoundIdByName("frog croaking"), -- sound ID
	SPAWN_CHANCE = 50, -- 1 / SPAWN_CHANCE to spawn Turn To Toad when the game is picking which card to spawn
	TIMEOUT = 600, -- how long until a Blue Frog turns back into a regular enemy (60 = 1 second at 60 fps)
	CONFUSION_FRAMES = 120, -- how many frames an enemy that turn back into its regular self is confused for
	NORMAL_DMG_MULT = 1.5, -- how much extra damage Blue Frogs take if they came from regular enemies
	BOSS_DMG_MULT = 1.5, -- above for bosses
	HUSH1_DMG_MULT = 3.0, -- above for Hush's first phase
	HUSH2_DMG_MULT = 6.0, -- above for Hush's second phase
	UG_DMG_MULT = 4.5, -- above for Ultra Greed or Ultra Greedier
	DELIRIUM_MULT = 3.0, -- above for Delirium (form itself doesn't have boss armor but he still has a ton of health so consider it a little bonus)
	GIBS_COLOR = Color(0.5608, 0.502, 1.0, 1.0, 0, 0, 0), -- gibs and splat color (offsets have to be integers here)
	GIBS_SIZE = 2.0,
	SOUND_FRAMES = 120, -- Blue Frogs might (see below) croak every SOUND_FRAMES frames
	SOUND_CHANCE = 2, -- 1 / SOUND_CHANCE chance to croak every SOUND_FRAMES frames
	FLASH_COLOR = Color(5.0, 5.0, 5.0, 0.5, 0, 0, 0), -- to warn the player that the frog's turning back (offsets have to be integers here)
	FLASH_DURATION = 20, -- how many frames the color above lasts for (keep in mind there is fade out)
	FLASH_TIME = 0.85 -- (0.0 to 1.0) at what % through the TIMEOUT does the flash occur to warn players that the frog will turn back soon?
}

-- In the code it is assumed that IDLE is the default (unless the table below tells us otherwise, i.e., we get something that's not nil)
local ProperBossState = { -- because there isn't a single state that works fine for every entity
	[EntityType.ENTITY_FALLEN] = {[0] = NpcState.STATE_MOVE}, -- variant 0 = normal fallen
	[EntityType.ENTITY_SATAN] = {[0] = NpcState.STATE_MOVE, [10] = NpcState.STATE_INIT}, -- 0 = satan himself, 10 = goat feet
	[EntityType.ENTITY_THE_LAMB] = {[0] = NpcState.STATE_MOVE, [10] = NpcState.STATE_INIT}, -- 0 = Lamb first phase/floating head, 10 = body with blue flame
	[EntityType.ENTITY_ISAAC] = {[0] = NpcState.STATE_INIT, [1] = NpcState.STATE_INIT, [2] = NpcState.STATE_INIT}, -- 0 = Isaac, 1 = Blue Baby
	[EntityType.ENTITY_SLOTH] = {[0] = NpcState.STATE_MOVE, [1] = NpcState.STATE_MOVE, [2] = NpcState.STATE_MOVE}, -- 0 = normal, 1 = super sin, 2 = Ultra Pride (yes, it's a Sloth)
	[EntityType.ENTITY_LUST] = {[0] = NpcState.STATE_MOVE, [1] = NpcState.STATE_MOVE}, -- 0 = normal, 1 = super sin
	[EntityType.ENTITY_WRATH] = {[0] = NpcState.STATE_MOVE, [1] = NpcState.STATE_MOVE}, -- see above
	[EntityType.ENTITY_GLUTTONY] = {[0] = NpcState.STATE_MOVE, [1] = NpcState.STATE_MOVE}, -- see above
	[EntityType.ENTITY_ENVY] = {[0] = NpcState.STATE_MOVE, [1] = NpcState.STATE_MOVE}, -- see above
	[EntityType.ENTITY_PRIDE] = {[0] = NpcState.STATE_MOVE, [1] = NpcState.STATE_MOVE}, -- see above
	[EntityType.ENTITY_URIEL] = {[0] = NpcState.STATE_MOVE, [1] = NpcState.STATE_MOVE}, -- 0 = normal, 1 = Mega Satan dark angel
	[EntityType.ENTITY_GABRIEL] = {[0] = NpcState.STATE_MOVE, [1] = NpcState.STATE_MOVE}, -- same as above
	[EntityType.ENTITY_BABY] = {[2] = NpcState.STATE_MOVE}, -- 2 = Ultra Pride baby
	[EntityType.ENTITY_MAMA_GURDY] = {[0] = NpcState.STATE_INIT}, -- 0 = normal
	[EntityType.ENTITY_DARK_ONE] = {[0] = NpcState.STATE_MOVE},
	[EntityType.ENTITY_ADVERSARY] = {[0] = NpcState.STATE_MOVE},
	[EntityType.ENTITY_CHUB] = {[0] = NpcState.STATE_MOVE, [1] = NpcState.STATE_MOVE, [2] = NpcState.STATE_MOVE}, -- 0 = Chub, 1 = CHAD, 2 = Carrion Queen (now unused do to new much better way of handling segmented enemies)
	[EntityType.ENTITY_WIDOW] = {[0] = NpcState.STATE_INIT, [1] = NpcState.STATE_INIT}, -- 0 = Widow, 1 = Wretched
	[EntityType.ENTITY_GEMINI] = {[2] = NpcState.STATE_MOVE}, -- 2 = Blighted Ovum
	[EntityType.ENTITY_GURGLING] = {[1] = NpcState.STATE_INIT, [2] = NpcState.STATE_INIT}, -- 1 = Gurglings boss, 2 = Turdlings
	[EntityType.ENTITY_THE_HAUNT] = {[0] = NpcState.STATE_INIT}, -- 0 = The Haunt boss (every other state either doesn't work or teleports him offscreen)
	[EntityType.ENTITY_RAG_MEGA] = {[0] = NpcState.STATE_MOVE},
	[EntityType.ENTITY_PEEP] = {[0] = NpcState.STATE_MOVE, [1] = NpcState.STATE_MOVE}, -- 0 = Peep, 1 = The Bloat
	[EntityType.ENTITY_HEADLESS_HORSEMAN] = {[0] = NpcState.STATE_MOVE},
	[EntityType.ENTITY_HORSEMAN_HEAD] = {[0] = NpcState.STATE_MOVE},
	[EntityType.ENTITY_FAMINE] = {[0] = NpcState.STATE_MOVE},
	[EntityType.ENTITY_PESTILENCE] = {[0] = NpcState.STATE_MOVE},
	[EntityType.ENTITY_WAR] = {[0] = NpcState.STATE_MOVE, [1] = NpcState.STATE_MOVE, [10] = NpcState.STATE_MOVE}, -- 0 = War, 1 = Conquest, 10 = War without a Horse
	[EntityType.ENTITY_DEATH] = {[0] = NpcState.STATE_MOVE, [10] = NpcState.STATE_MOVE, [20] = NpcState.STATE_INIT, [30] = NpcState.STATE_MOVE}, -- 0 = Death, 10 = Scythe, 20 = Horse, 30 = Death without horse
	[EntityType.ENTITY_ULTRA_GREED] = {[0] = NpcState.STATE_MOVE, [1] = NpcState.STATE_MOVE} -- 0 = Ultra Greed, 1 = Ultra Greedier
} -- Thinking back, maybe MOVE should have been the default, ah well, they both seemed common

local game = Game() -- reference to current run (works across restarts and continues)

local ZERO_VECTOR = Vector(0, 0)

local function update_blue_frog(_, npc)

	if npc.Variant == FrogVariants.BLUE_FROG or npc.Variant == FrogVariants.BLUE_FROG_BOSS then -- Blue Frogs only (exclude Flaming Hoppers)

		local blue_frog_data = npc:GetData()

		npc.PositionOffset = ZERO_VECTOR -- these can be changed (despite what the documentation says)
		npc.SpriteOffset = ZERO_VECTOR -- they prevent weird offsets for a frog (e.g. floating above ground if it came from a flying enemy)

		if npc:IsDead() and blue_frog_data.CheckedBlueFrogDeath == nil then -- Handle death once (TAKE_MG callback works ok but excludes some cases, e.g. Chaos Card death)

			blue_frog_data.CheckedBlueFrogDeath = true -- avoid possible multiple spawns

			-- Drop soul heart on death
			Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_HEART, HeartSubType.HEART_SOUL, npc.Position, ZERO_VECTOR, nil)
			-- Colored gibs:
			local gibs = npc:MakeSplat(TurnToToad.GIBS_SIZE)
			gibs:SetColor(TurnToToad.GIBS_COLOR, 0, 0, false, true)

			-- In some cases, killing a Blue Frog Boss can skip certain parts of a fight.
			-- This feels ok if you are fighting Satan, kill him as a frog and no goat feet spawn (since he's been squashed how can he stomp you?)
			-- But for some fights that feels too powerful and odd: Hush 1 -> Hush 2, Ultra Greed -> Ultra Greedier
			local level = game:GetLevel()

			if blue_frog_data.Type == EntityType.ENTITY_ISAAC and blue_frog_data.Variant == 2 -- Hush phase 1 killed in a boss room in the ??? floor
				and level:GetStage() == LevelStage.STAGE4_3 and game:GetRoom():GetType() == RoomType.ROOM_BOSS then

				local isaac_hush_npc = Isaac.Spawn(EntityType.ENTITY_ISAAC, 2, 0, npc.Position, ZERO_VECTOR, nil):ToNPC() -- Spawn Hush phase 2
				isaac_hush_npc:Kill()

			elseif blue_frog_data.Type == EntityType.ENTITY_ULTRA_GREED and blue_frog_data.Variant == 0 -- Ultra Greed killed in a boss room in the last floor of Greedier mode
				and level:GetStage() == LevelStage.STAGE7_GREED and game:GetRoom():GetType() == RoomType.ROOM_BOSS 
				and game.Difficulty == Difficulty.DIFFICULTY_GREEDIER then

				local ultra_greed_npc = Isaac.Spawn(EntityType.ENTITY_ULTRA_GREED, 0, 0, npc.Position, ZERO_VECTOR, nil):ToNPC() -- spawn Ultra Greed
				ultra_greed_npc:Kill() -- and kill it to skip to the 2nd phase (works much better than just spawning Ultra Greedier
				-- since the game takes care of the animation and transition + Chaos Card doesn't immidietelly kill it)

			end
		end

		-- Try to fix jumping towards a target (0, 0) and getting stuck on the top left corner of the screen
		if npc.TargetPosition ~= nil and npc.TargetPosition.X < 0.1 and npc.TargetPosition.Y < 0.1 then
			npc:ResetPathFinderTarget()
			npc:GetPlayerTarget()
		end

		-- Play croaking sounds
		if npc.FrameCount % TurnToToad.SOUND_FRAMES == 0 and math.random(TurnToToad.SOUND_CHANCE) == 1 then
			npc:PlaySound(TurnToToad.SOUND_FROG_CROAK, 3.0, 0, false, 1.0)
		end

		-- in case something goes wrong (spawned on its own) a non-champion black fly is what will be spawned instead
		if blue_frog_data.StartFrames == nil then
			blue_frog_data.StartFrames = game:GetFrameCount()
		end

		if blue_frog_data.Type == nil then
			blue_frog_data.Type = EntityType.ENTITY_FLY
		end

		if blue_frog_data.Variant == nil then
			blue_frog_data.Variant = 0
		end

		if blue_frog_data.SubType == nil then
			blue_frog_data.SubType = 0
		end

		if blue_frog_data.Segments == nil then
			blue_frog_data.Segments = 0
		end

		-- blue_frog_data.NoStatusEffects can be true or false (nil) - it's ok!

		-- /END in case something goes wrong (spawned on its own)

		local frames_since_turning = game:GetFrameCount() - blue_frog_data.StartFrames

		if frames_since_turning > TurnToToad.TIMEOUT * TurnToToad.FLASH_TIME and not blue_frog_data.ShownFlash then -- 75% of the time has passed

			blue_frog_data.ShownFlash = true
			npc:SetColor(TurnToToad.FLASH_COLOR, TurnToToad.FLASH_DURATION, 0, true, false)

		end

		if frames_since_turning > TurnToToad.TIMEOUT then -- timer exceded

			-- Two cases:
			-- 1. Non-segmented enemy (most cases) - morph back into the old self and keep the health
			-- 2. Segmented enemy - rebuild old self, keep health and remove blue frog

			local last_max_hp = npc.MaxHitPoints
			local last_hp = npc.HitPoints

			if blue_frog_data.Segments == 0 then -- normal enemy (not segmented)

				npc:Morph(blue_frog_data.Type, blue_frog_data.Variant, blue_frog_data.SubType, -1) -- -1 = keep champion
				npc:Update()

				-- [!] we are the regular enemy/boss beyond this point

				npc.MaxHitPoints = last_max_hp
				npc.HitPoints = last_hp

				if npc:IsBoss() then -- bosses are complex and have different variants/can be segmented so they require special care

					-- first we'll look in our table - if that type of boss doesn't require special care when changing it's state
					-- it means IDLE works fine
					if ProperBossState[npc.Type] == nil then
						npc.State = NpcState.STATE_IDLE
					else -- otherwise, it's state based AI isn't defined for IDLE or has a weird interaction, meaning we have to find one that works

						npc.State = ProperBossState[npc.Type][npc.Variant] -- bosses can have different variants (e.g. Satan: 0 = himself,
						-- 10 = Goat Feet)
					end

				else -- regular enemies are all pretty simple so reseting them looks fine
					npc.State = NpcState.STATE_INIT
				end

				if blue_frog_data.NoStatusEffects then -- add flag back in case it had it
					npc:AddEntityFlags(EntityFlag.FLAG_NO_STATUS_EFFECTS)
				end

				npc:ResetPathFinderTarget()
				npc:GetPlayerTarget()
				npc:AddConfusion(EntityRef(nil), TurnToToad.CONFUSION_FRAMES, true) -- true = affects bosses too

				npc:GetSprite():Update()
				npc:Update()

			else -- rebuild segmented enemy

				-- Entities whose segments we might have eliminated but who are fully spawned when you just spawn the head
				if blue_frog_data.Type == EntityType.ENTITY_PIN or blue_frog_data.Type == EntityType.ENTITY_CHUB then

					blue_frog_data.Segments = 0 -- avoid spawning multiples (one only)
				end -- ^ to guarantee one cycle in the for below

				for i = 1, blue_frog_data.Segments + 1 do -- for some reason, one always dies, so we need to spawn an extra one (Larry Jr, Hollow and Buttlickers only)
					
					local spawned_npc = Isaac.Spawn(blue_frog_data.Type, blue_frog_data.Variant, blue_frog_data.SubType, npc.Position, Vector(0,0), nil):ToNPC()
					
					spawned_npc.MaxHitPoints = last_max_hp
					spawned_npc.HitPoints = last_hp
					spawned_npc:Update()
					spawned_npc:AddConfusion(EntityRef(nil), TurnToToad.CONFUSION_FRAMES, true) -- true = affects bosses too

				end

				-- No need to change the state here since we are spawning them in

				npc:Remove() -- get rid of the frog (would normally be morphed)

			end

			Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF01, 0, npc.Position, Vector(0,0), nil) -- visual poof
		end

	end
end

-- Called for Flaming Hoppers and Blue Frogs
mod:AddCallback(ModCallbacks.MC_NPC_UPDATE, update_blue_frog, TurnToToad.ENTITY_BLUE_FROG)

-- Handle a Blue Frog taking extra damage
local function take_dmg_blue_frog(_, dmg_target, dmg_amount, dmg_flags, dmg_source, dmg_countdown_frames)

	-- exclude Flaming Hoppers
	if dmg_target.Variant == FrogVariants.BLUE_FROG or dmg_target.Variant == FrogVariants.BLUE_FROG_BOSS then
		
		local frog = dmg_target:ToNPC()
		local frog_data = frog:GetData()

		if frog_data.ApplyMultiDamage then -- multiply the damage taken (it won't be multiplied if it would kill the frog but it doesn't matter in that case)
			frog_data.ApplyMultiDamage = nil
			return nil -- take the actual
		else
			frog_data.ApplyMultiDamage = true

			local dmg_multi = TurnToToad.NORMAL_DMG_MULT
			if frog.Variant == FrogVariants.BLUE_FROG_BOSS then
				dmg_multi = TurnToToad.BOSS_DMG_MULT
			end

			if frog_data.Type == EntityType.ENTITY_ISAAC and frog_data.Variant == 2 then -- Hush Phase 1
				dmg_multi = TurnToToad.HUSH1_DMG_MULT
			elseif frog_data.Type == EntityType.ENTITY_HUSH then -- Hush Phase 2
				dmg_multi = TurnToToad.HUSH2_DMG_MULT
			elseif frog_data.Type == EntityType.ENTITY_ULTRA_GREED then -- Ultra Greed + Ultra Greedier
				dmg_multi = TurnToToad.UG_DMG_MULT
			elseif frog_data.Type == EntityType.ENTITY_DELIRIUM then -- Delirium (no boss armor himself but still has a ton of health)
				dmg_multi = TurnToToad.DELIRIUM_MULT
			end

			frog:TakeDamage(dmg_multi * dmg_amount, dmg_flags, dmg_source, dmg_countdown_frames)
			return false -- ignore the first damage taken
		end

	end
end

-- Called every time a Hopper takes damage (before the damage is applied)
mod:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, take_dmg_blue_frog, TurnToToad.ENTITY_BLUE_FROG)

-- Use Turn to Toad card:
local function use_card(_, card)

	local player = Isaac.GetPlayer(0)
	local chosen_enemy = nil
	local closest_distance = math.huge

	for _, entity in pairs(Isaac.GetRoomEntities()) do

		if entity:IsVulnerableEnemy() and entity:Exists() and not entity:IsDead() then -- find enemy that can take damage

			local npc = entity:ToNPC()

			-- Filter banned entities
			if not (npc.Type == TurnToToad.ENTITY_BLUE_FROG and (npc.Variant == FrogVariants.BLUE_FROG or npc.Variant == FrogVariants.BLUE_FROG_BOSS) -- blue frogs (regular + boss)
				or npc.Type == EntityType.ENTITY_MOM  and npc.Variant == 0 -- Mom's Door Eyes (from Mom's boss room)
				or npc.Type == EntityType.ENTITY_BIG_HORN  and npc.Variant == 1 -- Big Horn's Hands
				or npc.Type == EntityType.ENTITY_CHUB and npc.ParentNPC ~= nil -- Chub, CHAD and Carrion Queen's body segments (only the head is allowed)
				or npc.Type == EntityType.ENTITY_PIN and npc.ParentNPC ~= nil -- same as above for Pin, Scolex and Frail segments
				or npc.Type == EntityType.ENTITY_LARRYJR and npc.ParentNPC ~= nil -- same as above for Larry Jr and The Hollow
				or npc.Type == EntityType.ENTITY_BUTTLICKER and npc.ParentNPC ~= nil -- same as above for Buttlickers (a regular enemy for once)
				or npc.Type == EntityType.ENTITY_GRUB and npc.ParentNPC ~= nil -- same as above for Grubs
				or npc.Type == EntityType.ENTITY_THE_HAUNT  and npc.Variant == 10 -- The Lil' Haunts that are part of the boss fight
				or npc.Type == EntityType.ENTITY_DADDYLONGLEGS and npc.State == NpcState.STATE_STOMP -- Daddy Long Legs and Triachnid's feet
				or npc.Type == EntityType.ENTITY_MRMAW and (npc.Variant == 0 or npc.Variant == 10) -- Mr Maw's body (spawns whole enemy again if morphed back into) and neck segment
				or npc.Type == EntityType.ENTITY_SWINGER and (npc.Variant == 0 or npc.Variant == 10) -- Swinger's body (same as above) and neck
				or npc.Type == EntityType.ENTITY_GEMINI and npc.Variant == 20 -- Gemini's umbilical cord segments
				or npc.Type == EntityType.ENTITY_SWARM and npc.ParentNPC == nil and npc.ChildNPC == nil -- yellow Swarm flies that have no parent or child (morphing back to these spawns the full swarm for some reason); there only exists one of these in the full swarm
				) then

				local distance = player.Position:Distance(npc.Position)
				if distance < closest_distance then
					chosen_enemy = npc
					closest_distance = distance
				end

			end
		end
	end

	if chosen_enemy ~= nil then -- is an EntityNPC beyond here

		-- It's possible that our chosen_enemy is the head of a multi segmented boss (Chub, Pin, Larry Jr, Buttlickers, Gemini, Mr Maw, etc)
		-- For Pin and Chub (+ variants) all we need to do is eliminate the body segments since the game respawns them when you spawn the head
		-- For Larry Jr and Grubs  (+ variants) you need to count the number of segments so you can rebuild it later
		local segment = chosen_enemy.ChildNPC
		local segment_count = 0 -- all segments except for the head (number of extra body segments)

		-- Only these entities will get their segments removed (exclude some who also have parent-child relationships but whose
		-- neck/cord we want to keep, e.g. Gemini, Mr. Maw, Swingers, Homunculus, Mask of Infamy, Sisters Vis, etc)
		if chosen_enemy.Type == EntityType.ENTITY_CHUB or chosen_enemy.Type == EntityType.ENTITY_PIN
			or chosen_enemy.Type == EntityType.ENTITY_LARRYJR or chosen_enemy.Type == EntityType.ENTITY_BUTTLICKER
			or chosen_enemy.Type == EntityType.ENTITY_GRUB then

			-- Remove segments
			while segment ~= nil do -- most enemies will pass right along

				local child = segment.ChildNPC
				segment:Remove()
				segment = child
				segment_count = segment_count + 1
			end

		end

		local chosen_enemy_data = chosen_enemy:GetData() -- save types for when we need to turn back
		chosen_enemy_data.Type = chosen_enemy.Type
		chosen_enemy_data.Variant = chosen_enemy.Variant
		chosen_enemy_data.SubType = chosen_enemy.SubType

		chosen_enemy_data.MaxHP = chosen_enemy.MaxHitPoints -- total health
		chosen_enemy_data.HP = chosen_enemy.HitPoints -- current health

		chosen_enemy_data.Segments = segment_count -- for segments (see while above)

		if chosen_enemy:HasEntityFlags(EntityFlag.FLAG_NO_STATUS_EFFECTS) then -- for removal (so we remember to put it back)
			chosen_enemy_data.NoStatusEffects = true
		end

		chosen_enemy_data.ShownFlash = false -- for showing flash (visual indicator before turning back)

		chosen_enemy_data.StartFrames = game:GetFrameCount() -- for the timer

		local frog_variant = FrogVariants.BLUE_FROG
		if chosen_enemy:IsBoss() then
			frog_variant = FrogVariants.BLUE_FROG_BOSS -- necessary so turning a boss into a frog doesn't advance fights (Boss Rush, Fallen in the Satan fight, etc)
		end

		chosen_enemy:Morph(TurnToToad.ENTITY_BLUE_FROG, frog_variant, 0, -1) -- -1 = no champion/don't change the champion
		chosen_enemy:Update()

		-- [!] our enemy is a Blue Frog beyond this point

		-- When it morphs, its hit points get set to the Blue Frog's base ones, so we need to change that:
		chosen_enemy.MaxHitPoints = chosen_enemy_data.MaxHP
		chosen_enemy.HitPoints = chosen_enemy_data.HP

		chosen_enemy:ResetPathFinderTarget() -- avoid weird interactions
		chosen_enemy:GetPlayerTarget() -- ^
		chosen_enemy.State = NpcState.STATE_INIT -- all frogs start at a initial state to avoid problems
		chosen_enemy:ClearEntityFlags(EntityFlag.FLAG_NO_STATUS_EFFECTS) -- can now be affected by status effects

		-- Deal with posible enemy offsets (e.g. flying or jumping enemies like Dark Ball and Pin) or weird sprites
		local sprite = chosen_enemy:GetSprite()

		chosen_enemy.PositionOffset = ZERO_VECTOR -- these can be changed (despite what the documentation says)
		chosen_enemy.SpriteOffset = ZERO_VECTOR

		sprite.Rotation = 0.0 -- so the sprite looks right for certain enemies (e.g. wall spiders)
		sprite.FlipX = false
		sprite.FlipY = false
		sprite:Update()
		chosen_enemy:Update()

		Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF01, 0, chosen_enemy.Position, Vector(0,0), nil) -- visual poof
	end

end

-- Called when you use Turn To Toad card
mod:AddCallback(ModCallbacks.MC_USE_CARD, use_card, TurnToToad.CARD_TURN_TO_TOAD)

-- For reference -> is_playing, is_rune, only_runes
-- Deck of Cards: 	true, 		false, 	false
-- Book of Sin: 	true, 		true, 	false
-- Crystal Ball: 	true, 		true, 	false
-- Box, Starter Deck or Tarot Cloth (on pickup): true, true, false
-- Lil Chest: 		true, 		true, 	false
-- Rune Bag: 		false, 		true, 	true
-- Locked Chest: 	true, 		true, 	false
local function get_card(_, rng, current_card, is_playing, is_rune, only_runes)

	-- Good seed to test this on: C7LL 9L98 -> give Deck of Cards (Turn to Toad should always be the 19th card)
	local roll = rng:RandomInt(TurnToToad.SPAWN_CHANCE-1) -- RandomInt goes from 0 (inclusive) to max (exclusive) - max=0 crashes the game

	-- When choosing what to spawn, if the game is looking for a playing card, there is a SPAWN_CHANCE for it to be a Turn To Toad card
	if is_playing and roll == 1 then
		return TurnToToad.CARD_TURN_TO_TOAD
	end

end

-- Called when the game needs to pick a card to spawn from a certain pool of cards
mod:AddCallback(ModCallbacks.MC_GET_CARD, get_card)