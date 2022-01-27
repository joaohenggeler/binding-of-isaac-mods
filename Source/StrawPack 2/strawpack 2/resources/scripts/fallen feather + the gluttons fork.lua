--[[
?]]
-- ################################################## FALLEN FEATHER PASSIVE ##################################################
-- +2 Soul Hearts.
-- Every time Isaac enters an uncleared room, a feather will fall from the sky.
-- After it reaches the ground, one of two effects will happen:
-- 1. If the room was cleared while it was falling, every consumable in the room will be doubled (Jera Rune effect). If no consumables
-- exist, a Soul Heart will spawn instead.
-- 2. If it remains uncleared, light beams will be shot down from the sky (Crack the Sky effect).
-- The time it takes to fall to the ground depends on the number of enemies at the start of the room. This value goes from 6 seconds
-- (when no enemies exist) to 15 seconds (at 16 or more enemies).
-- On Sheol and in the Dark Room, a Black Heart will spawn instead of a Soul Heart if no consumables exist. The item's costume and the 
-- feather's sprite will also be different on these floors.

-- The Glutton's Fork (challenge):
-- Isaac starts with Fallen Feather, PHD, Isaac's Fork and a Gulp! pill.
-- Every time a room is cleared before the feather hits the ground, every trinket, pill, card and rune held will be dropped on the ground.
-- In this challenge, the feather's Jera Rune effect is replaced with Diplopia's effect.
-- Duplicating a trinket with the feather will spawn another random trinket instead.
-- Conditions: no Treasure or Dice Rooms.
-- Goal: Satan.

-- This mod uses a cropped version of the following sound effect from Freesound: "01543 flying dragon" by Robinhood76.
-- See http://freesound.org/people/Robinhood76/sounds/93570/

local mod = RegisterMod("strawpack 2 - fallen feather", 1)

local ZERO_VECTOR = Vector(0, 0)

local game = Game()
local level = game:GetLevel()
local sfx = SFXManager()
local itempools = game:GetItemPool()

local FallenFeather = {
	COLLECTIBLE_FALLEN_FEATHER = Isaac.GetItemIdByName("Fallen Feather"), -- item ID
	EFFECT_VARIANT_FALLEN_FEATHER = Isaac.GetEntityVariantByName("Fallen Feather"), -- EffectVariant
	EFFECT_VARIANT_FEATHER_SHADOW = Isaac.GetEntityVariantByName("Fallen Feather's Shadow"), -- EffectVariant for the visual Shadow entity
	BLUE_URIEL_COSTUME_ID = Isaac.GetCostumeIdByPath("gfx/characters/c001_fallenfeather_blue_uriel.anm2"),
	RED_GABRIEL_COSTUME_ID = Isaac.GetCostumeIdByPath("gfx/characters/c002_fallenfeather_red_gabriel.anm2"),
	BLACK_FALLEN_FEATHER_SPRITE_PATH = "gfx/effects/fallenfeather_black.png",
	
	-- How it behaves:
	INITIAL_SPRITE_OFFSET_HEIGHT = -145.0, -- set on init; its Y component is how far up the Feather starts when spawned (inverted Y axis!)
	MIN_FALLING_SPEED = 0.32, -- slowest possible falling speed (when there are 15 or more enemies on the screen when the Feather spawns)
	FALLING_SPEED_DECREASE_PER_ENEMY = 0.03, -- how much each enemy counts decreases the falling speed by (MAX_SPEED - this * ENEMY_NUM)
	MAX_FALLING_SPEED = 0.80, -- fastest possible falling speed (when there are no enemies on the screen when the Feather spawns)
	-- The time it takes to reach the ground is given by the equation: FallingTime = InitialHeight / (FallingSpeed * 30)
	-- E.g: for Height = 145 and Speed = 0.32, FallingTime = 145 / (0.32 * 30) = 15 seconds
	-- The FallingSpeed is set on init and follows the formula max(MIN_SPEED, MAX_SPEED - EnemyNum * DECREASE_PER_ENEMY)
	-- E.g: 2 enemies with MIN = 0.32, MAX = 0.8 and DECREASE = 0.03, FallingSpeed = max(0.32, 0.8 - 2 * 0.03) = max(0.32, 0.74) = 0.74

	-- Visual effect - make it look like it's falling gently to the ground
	MAX_SWAY_DISTANCE = 30.0, -- the Feather can only ever be this far away from its original position (back and forth amplitude)
	SWAY_SPEED = 0.09, -- how fast the Feather goes back and forth horizontally (increase for faster swaying motion)
	SWAY_ROTATION_MULTIPLIER = 0.7, -- how much it curves upwards along its halfpipe movement while falling
	-- 0 = always flat; follows the equation: Rotation = -x * RotationMultiplier, where x is the current value for the SpriteOffset's X
	-- component (so it looks right no matter what speed we pick)

	ANIM_BODY_LAYER = 0, -- for sprite replacements

	DUPLICATABLE_PICKUPS_FILTER = { -- which PickupVariants CANNOT be duplicated by the feather
		[PickupVariant.PICKUP_NULL] = true,
		[PickupVariant.PICKUP_COLLECTIBLE] = true,
		[PickupVariant.PICKUP_SHOPITEM] = true,
		[PickupVariant.PICKUP_BIGCHEST] = true,
		[PickupVariant.PICKUP_TROPHY] = true,
		[PickupVariant.PICKUP_BED] = true
	}
}

local FallenFeatherStates = {
	STATE_FALLING = 0, -- updates it's SpriteOffset and SpriteRotation to make it look like it's falling gently to the ground
	STATE_DISAPPEAR = 1 -- after it hits the ground in the previous state. Removes the entity after the Disappear animation is finished.
}

local AngelFlyby = { -- The angel that soars across the screen and drops the feather mid flight.
	EFFECT_VARIANT_ANGEL_FLYBY = Isaac.GetEntityVariantByName("Angel Flyby"), -- EffectVariant
	SOUND_ANGEL_FLYBY_WING_FLAP = Isaac.GetSoundIdByName("Angel Flyby Wing Flap"),
	SOUND_VOLUME = 1.4, -- so the sound can be easily tweaked
	SOUND_FRAME_DELAY = 60, -- prevents the sound of closing doors (on room start) from drowning out the Angel's sound
	BLACK_ANGEL_FLYBY_SPRITE_PATH = "gfx/effects/angelflyby_black.png",
	DEPTH_OFFSET = 4001.0, -- so it's overlayed on top of Fallen Feather and pretty much every other entity in the game
	ANIM_SHADOW_LAYER = 0, -- for sprite replacements
	ANIM_BODY_LAYER = 1
}

local TheGluttonsFork = { -- Every value specifically for the challenge.
	CHALLENGE_THE_GLUTTONS_FORK = Isaac.GetChallengeIdByName("The Glutton's Fork")
}

-- Returns true if the player is in Sheol or the Dark Room in Normal or Greed modes (Dark Path). Otherwise, false.
-- Used to add/switch to the respective costume, to spawn a Black Heart instead of a Soul Heart and to spawn a black feather and angel.
local function is_fallen_feather_black()
	local absolute_level_stage, is_alt_stage, is_greed_mode = level:GetAbsoluteStage(), level:IsAltStage(), game:IsGreedMode()
	return (absolute_level_stage == LevelStage.STAGE5 or absolute_level_stage == LevelStage.STAGE6) -- Sheol or Dark Room (both modes)
			and (not is_greed_mode and not is_alt_stage or is_greed_mode)
			-- ^ because, even with absolute stage, IsAltStage() has different return values in Normal and Greed modes (and its needed
			-- to filter the Cathedral and the Chest). In Greed Mode, IsAltStage() is always true.
end

local had_fallen_feather = false -- helper variable for adding/removing the costume (were we previously holding the item?)
-- Handle the addition or removal of Fallen Feather's costume.
local function post_peffect_update(_, player)

	if player:HasCollectible(FallenFeather.COLLECTIBLE_FALLEN_FEATHER) and not had_fallen_feather then
		had_fallen_feather = true
		local costume_id = FallenFeather.BLUE_URIEL_COSTUME_ID
		if is_fallen_feather_black() then costume_id = FallenFeather.RED_GABRIEL_COSTUME_ID end
		player:AddNullCostume(costume_id)
	elseif not player:HasCollectible(FallenFeather.COLLECTIBLE_FALLEN_FEATHER) and had_fallen_feather then
		had_fallen_feather = false
		player:TryRemoveNullCostume(FallenFeather.BLUE_URIEL_COSTUME_ID)
		player:TryRemoveNullCostume(FallenFeather.RED_GABRIEL_COSTUME_ID)
	end

end

mod:AddCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, post_peffect_update)

-- Change costumes depending on the stage. If on Sheol or the Dark Room, we get a different one.
local function post_new_level(_)
	local player = Isaac.GetPlayer(0)
	if player:HasCollectible(FallenFeather.COLLECTIBLE_FALLEN_FEATHER) then

		local costume_to_add, costume_to_remove = FallenFeather.BLUE_URIEL_COSTUME_ID, FallenFeather.RED_GABRIEL_COSTUME_ID
		if is_fallen_feather_black() then
			costume_to_add, costume_to_remove = FallenFeather.RED_GABRIEL_COSTUME_ID, FallenFeather.BLUE_URIEL_COSTUME_ID
		end

		player:TryRemoveNullCostume(costume_to_remove)
		player:AddNullCostume(costume_to_add)
		
	end
end

mod:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, post_new_level)

-- Spawn a Flyby Angel (that in turn spawns Fallen Feather) if an uncleared room is visited while Fallen Feather is held.
local function post_new_room(_)
	if Isaac.GetPlayer(0):HasCollectible(FallenFeather.COLLECTIBLE_FALLEN_FEATHER) and not game:GetRoom():IsClear() then
		local position = Isaac.GetFreeNearPosition(game:GetRoom():GetCenterPos(), 0.0)
		Isaac.Spawn(EntityType.ENTITY_EFFECT, AngelFlyby.EFFECT_VARIANT_ANGEL_FLYBY, 0, position, ZERO_VECTOR, nil)
	end
end

mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, post_new_room)

-- Sets the correct FallingSpeed speed depending on the number of enemies when spawned. Swaps spritesheet if on Sheol or in the Dark Room.
local function post_fallen_feather_init(_, feather)

	local sprite = feather:GetSprite()

	if is_fallen_feather_black() then
		sprite:ReplaceSpritesheet(FallenFeather.ANIM_BODY_LAYER, FallenFeather.BLACK_FALLEN_FEATHER_SPRITE_PATH)
		sprite:LoadGraphics()
	end

	feather.State = FallenFeatherStates.STATE_FALLING
	feather.SpriteOffset = Vector(0.0, FallenFeather.INITIAL_SPRITE_OFFSET_HEIGHT)
	feather.FallingSpeed = math.max(FallenFeather.MAX_FALLING_SPEED - Isaac.CountEnemies() * FallenFeather.FALLING_SPEED_DECREASE_PER_ENEMY, FallenFeather.MIN_FALLING_SPEED)
end

mod:AddCallback(ModCallbacks.MC_POST_EFFECT_INIT, post_fallen_feather_init, FallenFeather.EFFECT_VARIANT_FALLEN_FEATHER)

-- Triggers the feather's effects depending on the outcome of the room. Also drops pocket items and trinkets if on The Glutton's Fork challenge.
local function post_fallen_feather_update(_, feather)

	local player = Isaac.GetPlayer(0)
	local sprite = feather:GetSprite()
	local data = feather:GetData()

	if feather.FrameCount == 1 then -- Spawn a shadow that follows our movement. Must be here since the Feather's position is (0, 0) in INIT
		local shadow = Isaac.Spawn(EntityType.ENTITY_EFFECT, FallenFeather.EFFECT_VARIANT_FEATHER_SHADOW, 0, feather.Position, ZERO_VECTOR, feather)
		shadow.Parent = feather
		feather.Child = shadow
	end

	if feather.State == FallenFeatherStates.STATE_FALLING then -- While gently falling to the ground. The SpriteOffset and SpriteRotation
		-- are changed here. After it's Y component passes 0, we go to STATE_DISAPPEAR.

		-- Falling movement:
		local x = FallenFeather.MAX_SWAY_DISTANCE * math.sin(FallenFeather.SWAY_SPEED * feather.FrameCount)
		feather.SpriteOffset = Vector(x, feather.SpriteOffset.Y + feather.FallingSpeed)
		feather.SpriteRotation = -x * FallenFeather.SWAY_ROTATION_MULTIPLIER

		-- For The Glutton's Fork challenge - drop cards, runes, pills and trinkets if the room is cleared before the Feather hits
		-- the ground
		if game.Challenge == TheGluttonsFork.CHALLENGE_THE_GLUTTONS_FORK and not data.CheckedTheGluttonsFork
			and game:GetRoom():IsClear() then

			data.CheckedTheGluttonsFork = true -- so we only drop them once per feather

			for _ = 1, player:GetMaxTrinkets() do -- drop every trinket on the ground
				player:DropTrinket(game:GetRoom():FindFreePickupSpawnPosition(player.Position, 10.0, true), true)
			end

			for pocket_index = 0, player:GetMaxPoketItems() - 1 do -- drop every card/pill/rune on the ground
				player:DropPoketItem(pocket_index, game:GetRoom():FindFreePickupSpawnPosition(player.Position, 10.0, true))
			end

		end

		-- If it hits the ground (inverted height axis!)
		if feather.SpriteOffset.Y >= 0 then
			sprite:Play("Disappear", false)
			feather.State = FallenFeatherStates.STATE_DISAPPEAR
		end

	elseif feather.State == FallenFeatherStates.STATE_DISAPPEAR then -- Plays the Disappearing animation and checks which feather effect
		-- case we landed on. After it's finished playing the animation, the entity is removed.

		if sprite:IsEventTriggered("FeatherEffect") then

			if game:GetRoom():IsClear() then -- room cleared BEFORE the feather hit the ground - Jera Rune effect or Soul Heart spawn
			
				local were_no_pickups_duplicated = true

				for _, pickup in pairs(Isaac.FindByType(EntityType.ENTITY_PICKUP, -1, -1, true, false)) do -- duplicate the appropriate pickups
					
					if not FallenFeather.DUPLICATABLE_PICKUPS_FILTER[pickup.Variant] then -- filter out stuff that shouldn't be doubled

						local pickup_subtype = pickup.SubType
						if pickup.Variant == PickupVariant.PICKUP_TRINKET then
							pickup_subtype = itempools:GetTrinket() -- pick another one from the Trinket Pool instead of duplicating it
						end
					
						local pickup_sprite = pickup:GetSprite() -- filter opened chests
						if not pickup_sprite:IsFinished("Open") and not pickup_sprite:IsFinished("Opened") then
							Isaac.Spawn(pickup.Type, pickup.Variant, pickup_subtype, game:GetRoom():FindFreePickupSpawnPosition(pickup.Position, 0.0, true), ZERO_VECTOR, nil)
							were_no_pickups_duplicated = false
						end

					end

				end

				if were_no_pickups_duplicated then -- when no duplicatable consumables exist, we spawn a Soul Heart
					local heart_subtype = HeartSubType.HEART_SOUL
					if is_fallen_feather_black() then heart_subtype = HeartSubType.HEART_BLACK end
					Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_HEART, heart_subtype, game:GetRoom():FindFreePickupSpawnPosition(feather.Position, 0.0, true), ZERO_VECTOR, nil)
				end

			else -- room cleared AFTER the feather hit the ground - Crack the Sky effect
				player:UseActiveItem(CollectibleType.COLLECTIBLE_CRACK_THE_SKY, false, true, false, false)
			end

			sfx:Play(SoundEffect.SOUND_THUMBSUP, 1.0, 0, false, 1.0) -- give feedback

		end

		if sprite:IsFinished("Disappear") then
			feather:Remove()
		end
	end

end

mod:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, post_fallen_feather_update, FallenFeather.EFFECT_VARIANT_FALLEN_FEATHER)

-- Moves the shadow so it's always under the Falling Feather. When the feather effect occurs or it's removed, the shadow entity is remove.
local function post_fallen_feather_shadow_update(_, shadow)
	if shadow.Parent == nil or shadow.Parent:GetSprite():IsEventTriggered("FeatherEffect") or shadow.Parent:IsDead()
		or not shadow.Parent:Exists() then
		shadow:Remove()
	else
		shadow.SpriteOffset = Vector(shadow.Parent.SpriteOffset.X, 0.0)
	end
end

mod:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, post_fallen_feather_shadow_update, FallenFeather.EFFECT_VARIANT_FEATHER_SHADOW)

-- Add the custom item for The Glutton's Fork challenge.
local function post_game_started(_, from_save)
	-- Add additional starting items - Fallen Feather (modded item)
	if not from_save and game.Challenge == TheGluttonsFork.CHALLENGE_THE_GLUTTONS_FORK then
		Isaac.GetPlayer(0):AddCollectible(FallenFeather.COLLECTIBLE_FALLEN_FEATHER, 0, true)
	end
end

mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, post_game_started)

-- Play sound and put the Angel overlayed on the feather so it looks like it dropped it. Swaps spritesheet if on Sheol or in the Dark Room.
local function post_angel_flyby_init(_, angel)

	local sprite = angel:GetSprite()

	if is_fallen_feather_black() then
		sprite:ReplaceSpritesheet(AngelFlyby.ANIM_BODY_LAYER, AngelFlyby.BLACK_ANGEL_FLYBY_SPRITE_PATH)
		sprite:LoadGraphics()
	end

	angel.DepthOffset = AngelFlyby.DEPTH_OFFSET
end

mod:AddCallback(ModCallbacks.MC_POST_EFFECT_INIT, post_angel_flyby_init, AngelFlyby.EFFECT_VARIANT_ANGEL_FLYBY)

-- Spawns the actual Feather mid flight.
local function post_angel_flyby_update(_, angel)

	local sprite = angel:GetSprite()

	if angel.FrameCount == 1 then -- Avoid playing the sound effect while the Boss Intro is playing. This way the sound only plays when the fight starts.
		sfx:Play(AngelFlyby.SOUND_ANGEL_FLYBY_WING_FLAP, AngelFlyby.SOUND_VOLUME, AngelFlyby.SOUND_FRAME_DELAY, false, 1.0)
	end

	if sprite:IsEventTriggered("DropFeather") then
		Isaac.Spawn(EntityType.ENTITY_EFFECT, FallenFeather.EFFECT_VARIANT_FALLEN_FEATHER, 0, angel.Position, ZERO_VECTOR, nil)
	end

	if sprite:IsFinished("Fly") then
		angel:Remove()
	end

end

mod:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, post_angel_flyby_update, AngelFlyby.EFFECT_VARIANT_ANGEL_FLYBY)

return {
	ITEM_ID = FallenFeather.COLLECTIBLE_FALLEN_FEATHER,
	CHALLENGE_ID = TheGluttonsFork.CHALLENGE_THE_GLUTTONS_FORK
}