--[[
?]]
-- ################################################## MONSTROS EYE ACTIVE ##################################################
-- Charge: 6 rooms.
-- When used, summons Monstro 2 to drop from above, landing on enemies, dealing 120 damage to them and destroying obstacles like rocks.
-- After dropping down, Monstro 2 will shoot a Brimstone laser with the player's tear effects and damage.
-- If no enemies are present, Monstro 2 will fall where Isaac is. He won't, however, home towards the player while falling.
-- While held, there's a 15% chance to shoot concussive tears, causing enemies to walk around randomly.

local mod = RegisterMod("strawpack 2 - monstros eye", 1)

local ZERO_VECTOR = Vector(0, 0)

local game = Game()
local level = game:GetLevel()
local sfx = SFXManager()

local MonstrosEye = {
	COLLECTIBLE_MONSTROS_EYE = Isaac.GetItemIdByName("Monstro's Eye"), -- item ID
	EFFECT_VARIANT_MONSTROS_EYE = Isaac.GetEntityVariantByName("Monstros Eye"), -- EffectVariant
	COSTUME_ID = Isaac.GetCostumeIdByPath("gfx/characters/c001_monstroseye.anm2"),

	DELIRIOUS_MONSTRO_2_SPRITE_PATH = "gfx/effects/boss_049_monstroii_delirium.png",
	ANIM_BODY_LAYER = 0, -- for sprite replacements on The Void floor
	ANIM_SHADOW_LAYER = 1,

	LAND_DAMAGE = 120.0, -- how much damage it deals to enemies; players are always dealt 1 heart (2 half hearts) worth of damage
	-- same as Monstro's Tooth
	LAND_RADIUS = 80.0, -- radius of effect (in game units); about the same as Monstro's Tooth
	LAND_HOME_VELOCITY_DIVISOR = 5.0, -- how much the target homing velocity is divided by (used to ease Monstro 2's fall so 
	-- he doesn't teleport/snap into place when dealing with teleporting/burrowing enemies like Round Worms or Little Horn)
	LASER_TIMEOUT = 29, -- how long Monstro 2's laser last for (in game frames); same as the Monstro 2 boss
	LASER_POSITION_OFFSET = Vector(0.0, -20.0), -- so the laser lines up with Monstro's mouth; same as the Monstro 2 boss
	LASER_SWIRL_POSITION_OFFSET_LEFT = Vector(-10.0, -25.0), -- same as above but for the Brimstone Swirl from Anti-Gravity
	LASER_SWIRL_POSITION_OFFSET_RIGHT = Vector(10.0, -25.0), -- same as above but flipped (no need to flip the X value in game
	-- and create another vector since it's only 2 directions)

	-- For the passive effect while Monstro's Eye is held:
	TEAR_CHANCE = 0.15, -- % chance of shooting a Concussive tear (0 to 1)
	TEAR_COLOR = Color(1.0, 1.0, 1.0, 1.0, 0, 0, 0) -- so these tears look kinda like Monstro's Eye (continued below)
}
MonstrosEye.TEAR_COLOR:SetColorize(0.72, 0.61, 0.64, 1.0) -- RGB taken from the item sprite

-- Returns a random vulnerable in the current room. If no such enemy exists, returns nil.
local function get_random_room_vulnerable_enemy()

	local enemy_table = {}

	for _, entity in pairs(Isaac.GetRoomEntities()) do

		if entity:IsVulnerableEnemy() then
			table.insert(enemy_table, entity)
		end

	end

	if #enemy_table > 0 then
		return enemy_table[math.random(#enemy_table)]
	end
	return nil
end

-- Handles spawning the effect in and giving him a target.
local function post_use_monstros_eye_item(_, collectible_type, rng)
	local target = get_random_room_vulnerable_enemy()
	if target == nil then target = Isaac.GetPlayer(0) end

	local monstro = Isaac.Spawn(EntityType.ENTITY_EFFECT, MonstrosEye.EFFECT_VARIANT_MONSTROS_EYE, 0, target.Position, ZERO_VECTOR, nil)
	monstro.Target = target

	return true -- show holding up item animation
end

mod:AddCallback(ModCallbacks.MC_USE_ITEM, post_use_monstros_eye_item, MonstrosEye.COLLECTIBLE_MONSTROS_EYE)

local had_monstros_eye = false -- helper variable for adding/removing the costume (were we previously holding the item?)
-- Handle the addition or removal of Monstro's Eye's costume.
local function post_peffect_update(_, player)

	if player:HasCollectible(MonstrosEye.COLLECTIBLE_MONSTROS_EYE) and not had_monstros_eye then
		had_monstros_eye = true
		player:AddNullCostume(MonstrosEye.COSTUME_ID)
	elseif not player:HasCollectible(MonstrosEye.COLLECTIBLE_MONSTROS_EYE) and had_monstros_eye then
		had_monstros_eye = false
		player:TryRemoveNullCostume(MonstrosEye.COSTUME_ID)
	end

end

mod:AddCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, post_peffect_update)

-- Handle turning some of Isaac's tears into colored Concussive tears when Monstro's Eye is held.
local function post_fire_tear(_, tear)
	if Isaac.GetPlayer(0):HasCollectible(MonstrosEye.COLLECTIBLE_MONSTROS_EYE) and MonstrosEye.TEAR_CHANCE > math.random() then
		tear:SetColor(MonstrosEye.TEAR_COLOR, 0, 0, false, false)
		tear.TearFlags = tear.TearFlags | TearFlags.TEAR_CONFUSION
	end
end

mod:AddCallback(ModCallbacks.MC_POST_FIRE_TEAR, post_fire_tear)

-- Handle changing the effect's spritesheet if we are on The Void.
local function post_monstros_eye_init(_, monstro)
	local sprite = monstro:GetSprite()
	sprite.FlipX = game:GetRoom():GetCenterPos().X > monstro.Position.X -- flip depending on where we are in the room
	
	if level:GetAbsoluteStage() == LevelStage.STAGE7 then -- on The Void floor
		sprite:ReplaceSpritesheet(MonstrosEye.ANIM_BODY_LAYER, MonstrosEye.DELIRIOUS_MONSTRO_2_SPRITE_PATH)
		sprite:LoadGraphics()
	end
end

mod:AddCallback(ModCallbacks.MC_POST_EFFECT_INIT, post_monstros_eye_init, MonstrosEye.EFFECT_VARIANT_MONSTROS_EYE)

-- Handle the effect's behavior: homing in on targetted enemies while falling and shooting a Brimstone laser with the players tear effects.
local function post_monstros_eye_update(_, monstro)

	local sprite = monstro:GetSprite()
	local data = monstro:GetData()

	if sprite:IsPlaying("JumpDown") and not sprite:WasEventTriggered("Land") and
		monstro.Target ~= nil and monstro.Target.Type ~= EntityType.ENTITY_PLAYER then -- while falling (before Land is triggered)
		monstro.Velocity = (monstro.Target.Position - monstro.Position) / MonstrosEye.LAND_HOME_VELOCITY_DIVISOR
	end

	if sprite:IsEventTriggered("Land") then -- Stomp stuff around Monstro and spawn friendly flies:

		monstro.Velocity = ZERO_VECTOR -- stop the slight enemy homing
		-- Make explosion without any visual or sound and with no special effects (flags)
		game:BombDamage(monstro.Position, MonstrosEye.LAND_DAMAGE, MonstrosEye.LAND_RADIUS, false, nil, 0, 0, false)
		sfx:Play(SoundEffect.SOUND_FORESTBOSS_STOMPS, 1.0, 0, false, 1.0)

	elseif sprite:IsEventTriggered("Shoot") then -- Shoot the respective laser:

		local angle = 180
		if sprite.FlipX then angle = 0 end

		local player = Isaac.GetPlayer(0)

		if player:HasCollectible(CollectibleType.COLLECTIBLE_ANTI_GRAVITY) then -- since none of the player's FireBrimstone() shoot the Swirl
			local laser_swirl = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.BRIMSTONE_SWIRL, 0, monstro.Position, ZERO_VECTOR, player):ToEffect()
			laser_swirl:Update() -- stops it flickering to the front of Monstro right after spawning
			laser_swirl.DepthOffset = monstro.DepthOffset + 1.0 -- puts the swirl in front of Monstro for the rest of its lifespan
			laser_swirl:SetColor(player.LaserColor, 0, 0, false, false)
			laser_swirl.Rotation = angle
			local pos_offset = MonstrosEye.LASER_SWIRL_POSITION_OFFSET_LEFT
			if sprite.FlipX then -- flip the horizontal offset so it matches if he turns right
				pos_offset = MonstrosEye.LASER_SWIRL_POSITION_OFFSET_RIGHT
			end 
			laser_swirl.PositionOffset = pos_offset
			sfx:Play(SoundEffect.SOUND_BOSS_SPIT_BLOB_BARF, 1.0, 0, false, 1.0) -- give feedback since the swirl doesn't make sound immediately
		else
			local laser = player:FireDelayedBrimstone(angle, monstro)
			laser.PositionOffset = MonstrosEye.LASER_POSITION_OFFSET
			laser:SetTimeout(MonstrosEye.LASER_TIMEOUT)
			-- these type of lasers already make sound
		end

	end

	if sprite:IsFinished("JumpDown") then
		sprite:Play("Taunt", false)
	elseif sprite:IsFinished("Taunt") then
		sprite:Play("JumpUp", false)
	elseif sprite:IsFinished("JumpUp") then
		monstro:Remove()
	end
	-- For reference (from the boss itself):
	-- Monstro 2's Stomp: frame 33 = false, frame 34 onwards = true
	-- Monstro 2's Laser: frame 19 = no laser, frame 20-60 (inclusive) = laser exists, frame 61 = no laser
end

mod:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, post_monstros_eye_update, MonstrosEye.EFFECT_VARIANT_MONSTROS_EYE)

return {
	ITEM_ID = MonstrosEye.COLLECTIBLE_MONSTROS_EYE
}