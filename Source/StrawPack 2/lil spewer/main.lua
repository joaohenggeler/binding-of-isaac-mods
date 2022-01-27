--[[
?)]]
-- ################################################## LIL SPEWER FAMILIAR ##################################################
-- When picked up, a random pill is dropped on the floor.
-- Gives Isaac a follower that shoots charged creep shots whose type and pattern changes depending on Lil Spewer's variant.
-- Every time Isaac takes a pill, Lil Spewer changes into a different variant.
-- Synergizes with BFFS: longer range and the creep line lasts longer.
-- Synergizes with Lost Cork: larger puddles of creep.
----> 5 Possible Lil Spewer Variants:
-- Normal:
-- Shoots a medium-range line of green medium-damage creep. Always the first variant when the item is picked up.
-- Black:
-- Shoots a long-range line of black slowing creep. The line has a longer lifespan than the previous variant.
-- Red:
-- Shoots a fast long-range line of red high-damage creep. These puddles have a very short lifespan.
-- A larger puddle of red creep with a longer lifespan is spawned at the end of its range.
-- Yellow:
-- Shoots a short-range line of yellow creep whose size and damage increases with range.
-- The last puddle of creep in the line can potentially deal more damage than any other Lil Spewer variant.
-- White:
-- Shoots two arching lines of white slowing creep that form a circle. The lines have the longest lifespan of any variant.

local mod = RegisterMod("lil spewer", 1)

local game = Game()
local itempool = game:GetItemPool() -- for the pill drop on item pick up
local seeds = game:GetSeeds() -- so the pill drop above is seeded
local sfx = SFXManager()

local ZERO_VECTOR = Vector(0, 0)

local DirectionVector = { -- maps a Direction to a normalized vector pointing in that direction (except NO_DIRECTION)
	[Direction.NO_DIRECTION] =  ZERO_VECTOR, 
	[Direction.LEFT] = Vector(-1.0, 0.0),
	[Direction.UP] =  Vector(0.0, -1.0),
	[Direction.RIGHT] = Vector(1.0, 0.0),
	[Direction.DOWN] =  Vector(0.0, 1.0)
}

local SpewerStates = { -- types of Lil Spewer; each one has it's own spritesheet and creep type
	STATE_NORMAL = 0, -- default; type when you first get the familiar
	STATE_WHITE = 1,
	STATE_RED = 2,
	STATE_BLACK = 3,
	STATE_YELLOW = 4,
	NUM_STATES = 5 -- how many there are
} -- these are more SubTypes than states, but you can't really have the game assign you both a free variant AND subtype + GetEntitySubTypeByName() isn't a thing yet

local LilSpewer = {
	COLLECTIBLE_LIL_SPEWER = Isaac.GetItemIdByName("Lil Spewer"), -- item ID
	VARIANT_LIL_SPEWER = Isaac.GetEntityVariantByName("Lil Spewer"), -- familiar variant
	SOUND_SPEWER_BARF = Isaac.GetSoundIdByName("Lil Spewer Barf Shot"), -- sound ID (taken from the Ed's flash Spewer game itself; volume increased by 300%)
	SOUND_SPEWER_BARF_PITCH = 1.2, -- so it sounds less like the death sound it really was in the original game

	STATE_SPRITESHEET = { -- maps a Lil Spewer state (type/color) to its corresponding sprite sheet relative path
		[SpewerStates.STATE_NORMAL] = "gfx/familiar/familiar_lilspewer.png", -- default when first spawned
		[SpewerStates.STATE_WHITE] = "gfx/familiar/familiar_lilspewer_white.png",
		[SpewerStates.STATE_RED] = "gfx/familiar/familiar_lilspewer_red.png",
		[SpewerStates.STATE_BLACK] = "gfx/familiar/familiar_lilspewer_black.png",
		[SpewerStates.STATE_YELLOW] = "gfx/familiar/familiar_lilspewer_yellow.png"
	},

	DIRECTION_FLOAT_ANIM = { -- maps a Direction to an animation name ("Float___") in the .anm2 file (bobbing animation)
		[Direction.NO_DIRECTION] = "FloatDown", -- same as down
		[Direction.LEFT] = "FloatSide", -- FlipX = true on this one since the default points right
		[Direction.UP] = "FloatUp",
		[Direction.RIGHT] = "FloatSide",
		[Direction.DOWN] = "FloatDown"
	},

	DIRECTION_CHARGE_ANIM = { -- maps a Direction to an animation name ("Charge___") in the .anm2 file (static animation)
		[Direction.NO_DIRECTION] = "ChargeDown", -- same as down
		[Direction.LEFT] = "ChargeSide", -- FlipX = true on this one since the default points right
		[Direction.UP] = "ChargeUp",
		[Direction.RIGHT] = "ChargeSide",
		[Direction.DOWN] = "ChargeDown"
	},

	-- Last frame of Charge___ and FloatCharge___ animations (don't change unless the .anm2 file is also changed)
	LAST_CHARGE_FRAME = 14,
	LAST_FLOAT_CHARGE_FRAME = 29, -- unused

	DIRECTION_SHOOT_ANIM = { -- maps a Direction to an animation name ("FloatShoot___") in the .anm2 file (bobbing animation)
		[Direction.NO_DIRECTION] = "FloatShootDown", -- same as down
		[Direction.LEFT] = "FloatShootSide", -- FlipX = true on this one since the default points right
		[Direction.UP] = "FloatShootUp",
		[Direction.RIGHT] = "FloatShootSide",
		[Direction.DOWN] = "FloatShootDown"
	},

	MAX_CHARGE = 30, -- how many game frames it takes to fully charge Lil Spewer (2 render frames = 1 game frame)
	-- 30 for Lil Brimstone and Lil Monstro's charge time
	CHARGE_COOLDOWN = 15, -- how many game frames a Lil Spewer has to wait for after shooting before it can begin charging again. Also the
	-- number of game frames the FloatShoot animation is played for (on loop). Similar to how Lil Brimstone has his mouth open for a while
	-- before he can charge again.

	-- Used by Lil Brimstone and Lil Monstro: Color(1.0, 0.8, 0.8, 1.0, 0.2, 0.0, 0.0)
	FLASH_COLORS = { -- maps a Lil Spewer state (type/color) to the flash color to show that the familiar is at full charge (continued below)
		[SpewerStates.STATE_NORMAL] = Color(1.0, 0.8, 0.8, 1.0, 0, 0, 0),
		[SpewerStates.STATE_WHITE] = Color(1.0, 0.8, 0.8, 1.0, 0, 0, 0),
		[SpewerStates.STATE_RED] = Color(0.8, 1.0, 1.0, 1.0, 0, 0, 0),
		[SpewerStates.STATE_BLACK] = Color(1.0, 0.8, 0.8, 1.0, 0, 0, 0),
		[SpewerStates.STATE_YELLOW] = Color(1.0, 0.8, 0.8, 1.0, 0, 0, 0)
	}, -- offsets are set after this table of constants ends (most are different from each other)
	FLASH_DURATION = 5, -- small values => more flashes in a given period (5 is pretty close to the way Lil Brimstone and Lil Monstro change color)

	SHOT_OFFSET = 20, -- length of the offset vector in any given Direction

	STATE_CREEP = { -- maps a Lil Spewer state (type/color) to the variant of player creep (EntityEffect) it shoots
		[SpewerStates.STATE_NORMAL] = EffectVariant.PLAYER_CREEP_GREEN, -- default when first spawned
		[SpewerStates.STATE_WHITE] = EffectVariant.PLAYER_CREEP_WHITE,
		[SpewerStates.STATE_RED] = EffectVariant.PLAYER_CREEP_RED,
		[SpewerStates.STATE_BLACK] = EffectVariant.PLAYER_CREEP_BLACK,
		[SpewerStates.STATE_YELLOW] = EffectVariant.PLAYER_CREEP_LEMON_MISHAP
	},

	-- Lil Spewer stats:
	PUDDLE_NUM = { -- how many creep puddles are spawned (length/range of the whole trail)
		[SpewerStates.STATE_NORMAL] = 10,
		[SpewerStates.STATE_WHITE] = 18,
		[SpewerStates.STATE_RED] = 14,
		[SpewerStates.STATE_BLACK] = 14,
		[SpewerStates.STATE_YELLOW] = 6
	},
	BFFS_PUDDLE_NUM_INCREASE = { -- how much is added to the above if the player has BFFS! (synergy)
		[SpewerStates.STATE_NORMAL] = 4,
		[SpewerStates.STATE_WHITE] = 0,
		[SpewerStates.STATE_RED] = 0,
		[SpewerStates.STATE_BLACK] = 6,
		[SpewerStates.STATE_YELLOW] = 2
	},
	PUDDLE_STEP = { -- how many ingame units between each creep puddle (smaller => looks like a continuos trail)
		[SpewerStates.STATE_NORMAL] = 20,
		[SpewerStates.STATE_WHITE] = 20,
		[SpewerStates.STATE_RED] = 20,
		[SpewerStates.STATE_BLACK] = 20,
		[SpewerStates.STATE_YELLOW] = 21 -- small enough that the puddles connect
	},
	LOST_CORK_PUDDLE_STEP_INCREASE = { -- how much is added to the above if the player has the Lost Cork trinket (synergy)
		[SpewerStates.STATE_NORMAL] = 0,
		[SpewerStates.STATE_WHITE] = 0,
		[SpewerStates.STATE_RED] = 0,
		[SpewerStates.STATE_BLACK] = 0,
		[SpewerStates.STATE_YELLOW] = 16 -- because of Lemon Mishap's different puddles
	},
	PUDDLE_DMG = { -- how much CollisionDamage each puddle has; would usually be useless for all except STATE_YELLOW (out of these,
		-- only yellow creep can have its damage changed). However, we'll intercept it and deal our own custom amounts.
		[SpewerStates.STATE_NORMAL] = 0.35, -- green creep has the most damage ticks per second of any creep type hence the low damage
		[SpewerStates.STATE_WHITE] = 0.0,
		[SpewerStates.STATE_RED] = 12.00, -- the trail itself will only hit an enemy once
		[SpewerStates.STATE_BLACK] = 0.0,
		[SpewerStates.STATE_YELLOW] = 2.00 -- base damage (multiplied with each successive puddle spawn, see below)
	},
	PUDDLE_SCALE = { -- size multiplier for each creep puddle (1.0 is the size of the creep spawned by Headless Baby, Anemic, Shard of Glass, etc)
		[SpewerStates.STATE_NORMAL] = 0.8,
		[SpewerStates.STATE_WHITE] = 0.8,
		[SpewerStates.STATE_RED] = 0.85,
		[SpewerStates.STATE_BLACK] = 0.8, 
		[SpewerStates.STATE_YELLOW] = 0.27 -- base scale (increased with each successive puddle spawn, see below)
		-- 0.4 is about the size of a normal creep puddle for Lemon Mishap (yellow creep doesn't exist)
	},
	LOST_CORK_PUDDLE_SCALE_INCREASE = { -- how much is added to the above if the player has the Lost Cork trinket (synergy)
		[SpewerStates.STATE_NORMAL] = 0.3,
		[SpewerStates.STATE_WHITE] = 0.3,
		[SpewerStates.STATE_RED] = 0.3,
		[SpewerStates.STATE_BLACK] = 0.3,
		[SpewerStates.STATE_YELLOW] = 0.2
	},
	PUDDLE_DELAY = { -- how many game frames before the next creep puddle in the trail is spawned, relative to the previous one.
		-- Tiny values >0 => looks good
		[SpewerStates.STATE_NORMAL] = 1,
		[SpewerStates.STATE_WHITE] = 1,
		[SpewerStates.STATE_RED] = 1,
		[SpewerStates.STATE_BLACK] = 1,
		[SpewerStates.STATE_YELLOW] = 2 -- because of Lemon Mishap's slightly diferent spawn animation
	},
	PUDDLE_TIMEOUT = { -- how many game frames each creep puddle lives for
		[SpewerStates.STATE_NORMAL] = 25,
		[SpewerStates.STATE_WHITE] = 100,
		[SpewerStates.STATE_RED] = 4, -- only one high-damage hit
		[SpewerStates.STATE_BLACK] = 80,
		[SpewerStates.STATE_YELLOW] = 70
	},
	BFFS_PUDDLE_TIMEOUT_INCREASE = { -- how much is added to the above if the player has BFFS! (synergy)
		[SpewerStates.STATE_NORMAL] = 25,
		[SpewerStates.STATE_WHITE] = 25,
		[SpewerStates.STATE_RED] = 4, -- allows you to get a second high-damage hit in
		[SpewerStates.STATE_BLACK] = 25,
		[SpewerStates.STATE_YELLOW] = 30
	},
	-- Stats unique to some Lil Spewer types:
	-- Yellow: initially small puddle that increases in size and damage with each successive puddle
	YELLOW_DMG_MULTIPLIER = 1.5, -- how much the Puddle Damage of every successive creep puddle grows by
	YELLOW_MAX_DMG = 20.0, -- maximum amount of damage that a Lemon Mishap puddle shot by the Yellow variant can deal
	YELLOW_SCALE_INCREASE = 0.1, -- how much is added to the Puddle Scale of every successive creep puddle
	-- Red: fast creep trail that spawns a bigger puddle when it reaches the end
	RED_LAST_PUDDLE_SCALE = 1.75, -- size multiplier of the last red creep puddle (creep "explosion")
	RED_LAST_PUDDLE_TIMEOUT = 60, -- how many game frames the last red creep puddle is alive for
	-- White: two arching creeps trails that form a slowing circle
	WHITE_TRAIL_ROTATION = 10 -- how many angles the direction vector is rotated by between creep puddles (starts at 90 degrees; inverted Y axis!)
	-- PUDDLE_NUM might need tweaking if this is changed
	-- 0 = two vertical trails, >0 = begin curving towards each other
}

-- because the constructor expects ints even though the Offsets are floats
LilSpewer.FLASH_COLORS[SpewerStates.STATE_NORMAL]:SetOffset(0.2, 0.0, 0.0)
LilSpewer.FLASH_COLORS[SpewerStates.STATE_WHITE]:SetOffset(0.3, 0.0, 0.0)
LilSpewer.FLASH_COLORS[SpewerStates.STATE_RED]:SetOffset(0.0, 0.1, 0.1)
LilSpewer.FLASH_COLORS[SpewerStates.STATE_BLACK]:SetOffset(0.2, 0.0, 0.0)
LilSpewer.FLASH_COLORS[SpewerStates.STATE_YELLOW]:SetOffset(0.3, 0.0, 0.0)

-- Helper function that "shoots" a line of creep. In reality, since we don't want creep to spawn instantly (because that looks bad),
-- we only set certain parameters in one creep puddle's Data Table. Each puddle is responsible for spawning the next creep puddle and
-- passing on the same parameters. The behavior is only defined for the following creep variants:
-- PLAYER_CREEP_GREEN, PLAYER_CREEP_WHITE, PLAYER_CREEP_RED, PLAYER_CREEP_BLACK, PLAYER_CREEP_LEMON_MISHAP
-- Returns a reference to the spawned creep or nil if it can't spawn one (puddle_num was reached or the next position isn't in the room).
local function shoot_creep(creep_variant, spewer_state, position, direction_vector, puddle_num, puddle_step, puddle_dmg, puddle_scale, puddle_delay, puddle_timeout, spawner, trail_rotation)

	if puddle_num <= 0 or not game:GetRoom():IsPositionInRoom(position, 0.0) then
		return nil
	end

	local creep = Isaac.Spawn(EntityType.ENTITY_EFFECT, creep_variant, 0, position, ZERO_VECTOR, spawner):ToEffect()
	creep.Scale = puddle_scale
	creep.CollisionDamage = puddle_dmg -- even though changing it normally doesn't affect green and red creep, it's still dealt in TAKE_DMG
	creep:SetTimeout(puddle_timeout)
	creep:Update() -- prevents it from going from a normal puddle to the right scale in a frame

	local data = creep:GetData()
	data.IsLilSpewerCreep = true -- will look at the following attributes
	data.LilSpewerPuddleDirection = direction_vector -- normalized vector that points towards where the next creep puddle should be
	data.LilSpewerPuddleNum = math.max(0, puddle_num - 1) -- how many are left to spawn
	data.LilSpewerPuddleStep = puddle_step -- distance between puddles; used with the Direction vector to calculated the next position
	data.LilSpewerPuddleDamage = puddle_dmg -- how much damage each puddle deals
	data.LilSpewerPuddleScale = puddle_scale -- size multiplier for each puddle
	data.LilSpewerPuddleDelay = puddle_delay -- how many game frames a puddle has to be alive for before spawning the next one
	data.LilSpewerPuddleTimeout = puddle_timeout -- how many grame frames a puddle is alive for
	data.LilSpewerState = spewer_state -- easy access to which Lil Spewer type shot the puddle
	data.LilSpewerSpawner = spawner -- easy access to the reference of the Lil Spewer that shot it (used in TAKE_DMG so that green and red creep deal custom amounts of damage)
	data.LilSpewerTrailRotation = trail_rotation -- used by the White Lil Spewer so both white trails curve (left at 0 for the others)

	return creep
end

-- Called after every game update for green, red, yellow, white, black and lemon mishap player creep. Used by shoot_creep() to create
-- a smoother motion with custom attributes and effects.
local function post_player_creep_update(_, creep)

	local data = creep:GetData()
	if data.IsLilSpewerCreep and data.LilSpewerPuddleDelay ~= nil and creep.FrameCount == data.LilSpewerPuddleDelay then -- spawn next creep puddle

		-- Change some custom attributes based on the type of Lil Spewer
		if data.LilSpewerState == SpewerStates.STATE_YELLOW then -- yellow's shot pattern
			data.LilSpewerPuddleDamage = math.min(data.LilSpewerPuddleDamage * LilSpewer.YELLOW_DMG_MULTIPLIER, LilSpewer.YELLOW_MAX_DMG) -- capped
			data.LilSpewerPuddleScale = data.LilSpewerPuddleScale + LilSpewer.YELLOW_SCALE_INCREASE
		elseif data.LilSpewerState == SpewerStates.STATE_RED and data.LilSpewerPuddleNum == 1 then -- last red creep puddle (creep explosion)
			data.LilSpewerPuddleScale = LilSpewer.RED_LAST_PUDDLE_SCALE
			data.LilSpewerPuddleTimeout = LilSpewer.RED_LAST_PUDDLE_TIMEOUT
		elseif data.LilSpewerState == SpewerStates.STATE_WHITE then -- White circle (two arching trails)
			data.LilSpewerPuddleDirection = data.LilSpewerPuddleDirection:Rotated(data.LilSpewerTrailRotation)
		end

		-- where the next creep puddle should spawn
		local next_position = creep.Position + data.LilSpewerPuddleDirection:Resized(data.LilSpewerPuddleStep)
		shoot_creep(creep.Variant, data.LilSpewerState, next_position, data.LilSpewerPuddleDirection,
					data.LilSpewerPuddleNum, data.LilSpewerPuddleStep, data.LilSpewerPuddleDamage,
					data.LilSpewerPuddleScale, data.LilSpewerPuddleDelay, data.LilSpewerPuddleTimeout,
					data.LilSpewerSpawner, data.LilSpewerTrailRotation)

	end

end

mod:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, post_player_creep_update, EffectVariant.PLAYER_CREEP_GREEN)
mod:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, post_player_creep_update, EffectVariant.PLAYER_CREEP_WHITE)
mod:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, post_player_creep_update, EffectVariant.PLAYER_CREEP_RED)
mod:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, post_player_creep_update, EffectVariant.PLAYER_CREEP_BLACK)
mod:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, post_player_creep_update, EffectVariant.PLAYER_CREEP_LEMON_MISHAP)

-- Called every time an entity is damaged. Used to intercept Green or Red Player Creep's fixed damage (1.00 and 2.00) and to
-- deal our own custom amount (this is pretty silly, nothing else in the game is like this).
local function on_take_dmg(_, dmg_target, dmg_amount, dmg_flags, dmg_source, dmg_countdown_frames)

	if dmg_source.Type == EntityType.ENTITY_EFFECT and (dmg_source.Variant == EffectVariant.PLAYER_CREEP_GREEN
		or dmg_source.Variant == EffectVariant.PLAYER_CREEP_RED) then -- creep variants that have fixed damage

		-- spawned by Lil Spewer (EntityRef's SpawnerType attribute returns userdata instead of a number)
		if dmg_source.Entity.SpawnerType == EntityType.ENTITY_FAMILIAR and dmg_source.SpawnerVariant == LilSpewer.VARIANT_LIL_SPEWER then

			local target_data = dmg_target:GetData()

			-- intercept fixed creep damage and deal our own correct damage
			if target_data.LilSpewerCreepTakeNewDamage then -- we'll come through here the second time...
				target_data.LilSpewerCreepTakeNewDamage = nil
				return nil -- take the new damage
			else -- ... and through here the first time
				target_data.LilSpewerCreepTakeNewDamage = true
				dmg_flags = dmg_flags & ~DamageFlag.DAMAGE_COUNTDOWN -- removing this flag prevents it from only dealing it the fixed amount
				dmg_target:TakeDamage(dmg_source.Entity.CollisionDamage, dmg_flags, dmg_source, dmg_countdown_frames) -- deal our own
				return false -- ignore the first damage taken
			end

		end

	end

end

mod:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, on_take_dmg)

-- Called when the follower first spawns or when we come back after an exit/continue
local function init_lil_spewer(_, lil_spewer) -- EntityFamiliar
	lil_spewer:AddToFollowers() -- set IsFollower to true so the familiar is alligned correctly in the familiar train (in CheckFamiliar())	
	lil_spewer.FireCooldown = LilSpewer.MAX_CHARGE
end

mod:AddCallback(ModCallbacks.MC_FAMILIAR_INIT, init_lil_spewer, LilSpewer.VARIANT_LIL_SPEWER)

-- Called every game update for each Lil Spewer follower
local function update_lil_spewer(_, lil_spewer) -- EntityFamiliar

	lil_spewer:FollowParent() -- follow the familiar train
	
	local sprite = lil_spewer:GetSprite()

	if lil_spewer.FrameCount == 4 then -- MC_FAMILIAR_UPDATE only starts being called on FrameCount == 4. It's only reset when you
		-- exit and continue (going to different rooms/floors doesn't reset it).
		-- This is done here because the State isn't set yet on MC_FAMILIAR_INIT
		if lil_spewer.State ~= SpewerStates.STATE_NORMAL then -- no need to reload it if it's the default State
			sprite:ReplaceSpritesheet(0, LilSpewer.STATE_SPRITESHEET[lil_spewer.State]) -- change the look of the familiar to the appropriate one
			sprite:LoadGraphics()
		end
	end

	local data = lil_spewer:GetData()
	-- NOTE: previously, data.LilSpewerCharge was used for Lil Spewer's puke charge. It's been since replaced with the EntityFamiliar
	-- FireCooldown attribute (like vanilla familiars use). Remember that: Charge = MAX_CHARGE - FireCooldown or
	-- FireCooldown = MAX_CHARGE - Charge. FireCooldown is clamped from 0 to MAX_CHARGE.
	if data.LilSpewerChargeCooldown == nil then data.LilSpewerChargeCooldown = 0 end
	-- There are two cooldowns: FireCooldown = can we shoot?, ChargeCooldown = can we charge? This last one is used so that you
	-- can't charge while Lil Spewer is shooting creep (didn't see right even though vanilla familiars do it anyways).
	if data.LilSpewerLastPlayerFireDirection == nil then data.LilSpewerLastPlayerFireDirection = Direction.NO_DIRECTION end
	-- ^ although this is a EntityFamiliar attribute (LastDirection), it currently returns userdata and not a number (needs to be fixed)

	data.LilSpewerChargeCooldown = math.max(0, data.LilSpewerChargeCooldown - 1) -- so the cooldown is >=0

	local player_fire_direction = lil_spewer.Player:GetFireDirection() -- this animation takes precedence over the moving one
	local player_move_direction = lil_spewer.Player:GetMovementDirection()

	if player_fire_direction == Direction.NO_DIRECTION then -- Isaac stopped firing/charging shots

		-- If we aren't shooting and the Shoot animation had enough time to show (cooldown), we can now float in whichever direction the
		-- player is going
		if data.LilSpewerChargeCooldown == 0 then
			if player_move_direction == Direction.LEFT then -- because ChargeSide points right
				sprite.FlipX = true
			else
				sprite.FlipX = false
			end
			sprite:Play(LilSpewer.DIRECTION_FLOAT_ANIM[player_move_direction], false)
		end

		if lil_spewer.FireCooldown <= 0 then -- fire creep when we hit max charge
	
			data.LilSpewerChargeCooldown = LilSpewer.CHARGE_COOLDOWN -- Lil Spewer won't be able to charge for this many game frames
			-- Here so that we can actually see the Shoot animation (when the cooldown hits 0 we play the normal Float one)

			if data.LilSpewerLastPlayerFireDirection == Direction.LEFT then -- because ShootSide points right
				sprite.FlipX = true
			else
				sprite.FlipX = false
			end
			sprite:Play(LilSpewer.DIRECTION_SHOOT_ANIM[data.LilSpewerLastPlayerFireDirection], false)
			-- will override the Float movement animation about for CHARGE_COOLDOWN game frames

			----> STUFF NOT RELATED TO CHARGING
			-- Fire Creep - every creep puddle is responsible for spawning the next (with a certain delay)
			local first_creep_position = lil_spewer.Position + lil_spewer.Velocity
										+ DirectionVector[data.LilSpewerLastPlayerFireDirection] * LilSpewer.SHOT_OFFSET

			-- stats affected by BFFS or the Lost Cork trinket (others are always constants from the table)
			local puddle_num = LilSpewer.PUDDLE_NUM[lil_spewer.State]
			local puddle_timeout = LilSpewer.PUDDLE_TIMEOUT[lil_spewer.State]
			local puddle_scale =  LilSpewer.PUDDLE_SCALE[lil_spewer.State]
			local puddle_step = LilSpewer.PUDDLE_STEP[lil_spewer.State]

			if lil_spewer.Player:HasCollectible(CollectibleType.COLLECTIBLE_BFFS) then -- BFFS synergy
				puddle_num = puddle_num + LilSpewer.BFFS_PUDDLE_NUM_INCREASE[lil_spewer.State]
				puddle_timeout = puddle_timeout + LilSpewer.BFFS_PUDDLE_TIMEOUT_INCREASE[lil_spewer.State]
			end

			if lil_spewer.Player:HasTrinket(TrinketType.TRINKET_LOST_CORK) then -- Lost Cork synergy
				puddle_scale = puddle_scale + LilSpewer.LOST_CORK_PUDDLE_SCALE_INCREASE[lil_spewer.State]
				puddle_step = puddle_step + LilSpewer.LOST_CORK_PUDDLE_STEP_INCREASE[lil_spewer.State]
			end
			
			-- Actual creep shot:
			if lil_spewer.State == SpewerStates.STATE_WHITE then -- the White Lil Spewer shoots two arching trails to form a circle

				local trail_rotation = LilSpewer.WHITE_TRAIL_ROTATION
				local angle = -90 -- we rotate the shot direction because we're curving two vertical creep trails
				for _ = 1, 2 do

					shoot_creep(LilSpewer.STATE_CREEP[lil_spewer.State], lil_spewer.State, first_creep_position, DirectionVector[data.LilSpewerLastPlayerFireDirection]:Rotated(angle),
						puddle_num, puddle_step, LilSpewer.PUDDLE_DMG[lil_spewer.State],
						puddle_scale, LilSpewer.PUDDLE_DELAY[lil_spewer.State], puddle_timeout,
						lil_spewer, trail_rotation)

					trail_rotation = -trail_rotation -- symmetrical trails
					angle = -angle
				end

			else -- all others shoot one straight trail
				shoot_creep(LilSpewer.STATE_CREEP[lil_spewer.State], lil_spewer.State, first_creep_position, DirectionVector[data.LilSpewerLastPlayerFireDirection],
						puddle_num, puddle_step, LilSpewer.PUDDLE_DMG[lil_spewer.State],
						puddle_scale, LilSpewer.PUDDLE_DELAY[lil_spewer.State], puddle_timeout,
						lil_spewer, 0)
			end

			-- old: SoundEffect.SOUND_BOSS_SPIT_BLOB_BARF pitch=2.0
			sfx:Play(LilSpewer.SOUND_SPEWER_BARF, 1.0, 0, false, LilSpewer.SOUND_SPEWER_BARF_PITCH) -- feedback
			-- /END of stuff not related to charging
		end

		lil_spewer.FireCooldown = LilSpewer.MAX_CHARGE -- after firing creep or if we didn't charge all the way; either way, it's reset

	elseif data.LilSpewerChargeCooldown <= 0 then -- Isaac is firing/charging shots and the charge cooldown allows us - Lil Spewer charges here

		lil_spewer.FireCooldown = math.max(0, lil_spewer.FireCooldown - 1) -- charge shot (capped between 0 and MAX_CHARGE)

		if player_fire_direction == Direction.LEFT then -- because ChargeSide points right
			sprite.FlipX = true
		else
			sprite.FlipX = false
		end

		-- Get frame where we should be in the anm2 file given our charge percentage (current/total).
		-- If charge = 0 (FireCooldown=MAX) ==> frame_num = 0 (first frame of charge)
		-- If charge = MAX (FireCooldown=0) ==> frame_num = LAST_CHARGE_FRAME
		-- Previous equation (see note in line 335): frame_num = math.floor( CHARGE / MAX_CHARGE * LAST_CHARGE_FRAME)
		local frame_num = math.floor( (1 - lil_spewer.FireCooldown / LilSpewer.MAX_CHARGE) * LilSpewer.LAST_CHARGE_FRAME)
		sprite:SetFrame(LilSpewer.DIRECTION_CHARGE_ANIM[player_fire_direction], frame_num)

		if lil_spewer.FireCooldown <= 0 then -- flash at max charge (can now shoot)
			if lil_spewer:IsFrame(LilSpewer.FLASH_DURATION, 0) then
				lil_spewer:SetColor(LilSpewer.FLASH_COLORS[lil_spewer.State], LilSpewer.FLASH_DURATION, 0, true, false) -- true = fades out
			end
		end

		data.LilSpewerLastPlayerFireDirection = player_fire_direction -- saved because it's NO_DIRECTION when we have to shoot creep
	end

end

mod:AddCallback(ModCallbacks.MC_FAMILIAR_UPDATE, update_lil_spewer, LilSpewer.VARIANT_LIL_SPEWER)

-- Called every time a pill is used.
local function use_pill(_, pill_effect)
	if Isaac.GetPlayer(0):HasCollectible(LilSpewer.COLLECTIBLE_LIL_SPEWER) then

		local was_atleast_one_changed = false

		for _, lil_spewer in pairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, LilSpewer.VARIANT_LIL_SPEWER, 0, false, false)) do

			was_atleast_one_changed = true
			lil_spewer = lil_spewer:ToFamiliar()
			local rng = Isaac.GetPlayer(0):GetCollectibleRNG(LilSpewer.COLLECTIBLE_LIL_SPEWER) -- seeded
			local original_state = lil_spewer.State
			local new_state = nil -- is number after one iteration
			repeat

				-- Lua is kinda weird with this; you can't index enum tables? (SpewerStates[1] returns nil)
				new_state = rng:RandomInt(SpewerStates.NUM_STATES) -- random state choice; [0,NUM_STATES(

			until new_state ~= original_state -- guarantee a different state

			lil_spewer.State = new_state
			local sprite = lil_spewer:GetSprite()
			sprite:ReplaceSpritesheet(0, LilSpewer.STATE_SPRITESHEET[lil_spewer.State]) -- change spritesheet
			sprite:LoadGraphics()

			-- give feedback
			Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF01, 0, lil_spewer.Position + lil_spewer.Velocity, ZERO_VECTOR, nil)
		end

		-- also give feedback but avoid sound tear when there are many Lil Spewers
		if was_atleast_one_changed then sfx:Play(SoundEffect.SOUND_POWERUP_SPEWER, 1.0, 0, false, 1.0) end

	end
end

mod:AddCallback(ModCallbacks.MC_USE_PILL, use_pill) -- no PillEffect ID (converted to -1) calls it for every one

-- For reference (callback order in ONE game frame):
-- ... -> POST_PEFFECT_UPDATE -> POST_PlAYER_UPDATE -> POST_UPDATE -> POST_PlAYER_UPDATE -> MC_EVALUATE_CACHE -> POST_PlAYER_UPDATE -> ...
local previous_lil_spewer_item_num = nil -- how many Lil Spewer items we had; used to spawn drops on pick up
if Isaac.GetPlayer(0) ~= nil then previous_lil_spewer_item_num = Isaac.GetPlayer(0):GetCollectibleNum(LilSpewer.COLLECTIBLE_LIL_SPEWER) end
-- if the mod is reloaded in the game, previous_lil_spewer_item_num will hold the correct value (its only nil if its loaded from the menu)

-- Called every time the cache is evaluated
local function update_cache(_, player, cache_flag)
	if cache_flag == CacheFlag.CACHE_FAMILIARS then
		----> Potentially add/remove a Lil Spewer from the familiar train
		player:CheckFamiliar(LilSpewer.VARIANT_LIL_SPEWER, player:GetCollectibleNum(LilSpewer.COLLECTIBLE_LIL_SPEWER), player:GetCollectibleRNG(LilSpewer.COLLECTIBLE_LIL_SPEWER))
		----> Spawn a random pill on the ground on pick up (because of CACHE_FAMILIARS, this will be called back when we add/remove one)
		-- Works on mod reloads, between runs/exits/continues, given by the console or if it's there from the start of the run (Eden's Blessing, etc)
		if player:HasCollectible(LilSpewer.COLLECTIBLE_LIL_SPEWER) then

			local current_lil_spewer_item_num = player:GetCollectibleNum(LilSpewer.COLLECTIBLE_LIL_SPEWER)

			if previous_lil_spewer_item_num == nil then
				if game:GetFrameCount() == 0 then -- cache is evaluated for ALL on game frame 0, before MC_POST_GAME_STARTED
					previous_lil_spewer_item_num = 0 -- spawn pills if we have it at the beginning of a new run (Eden's Blessing, etc)
				else
					previous_lil_spewer_item_num = current_lil_spewer_item_num -- spawn nothing if we are continuing after reloading mods
				end
			end -- guarantee that previous_lil_spewer_item_num is a number

			local free_spawn_position, random_pill_color
			local rng = player:GetCollectibleRNG(LilSpewer.COLLECTIBLE_LIL_SPEWER) -- seeded drops

			for _ = 1, current_lil_spewer_item_num - previous_lil_spewer_item_num do -- stuff to do when we pick up the item itself
				
				free_spawn_position  = game:GetRoom():FindFreePickupSpawnPosition(player.Position, 40.0, true)
				random_pill_color = itempool:GetPill(rng:RandomInt(seeds:GetStartSeed())) -- get random PillColor from the current pill pool
				if free_spawn_position ~= nil and random_pill_color ~= nil then
					Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_PILL, random_pill_color, free_spawn_position, ZERO_VECTOR, nil)
				end

			end

			previous_lil_spewer_item_num = current_lil_spewer_item_num

		else -- lost the item (removed or rerolled) or resetting the value on a new run start (cache is evaluated for ALL on start)
			previous_lil_spewer_item_num = 0
		end
	end
end

mod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, update_cache)