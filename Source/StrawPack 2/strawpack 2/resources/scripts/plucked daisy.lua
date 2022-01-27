--[[
?)]]
-- ################################################## PLUCKED DAISY TRINKET ##################################################
-- While held, every amount of damage taken has a 50% to either be doubled or ignored.
-- Synergizes with Mom's Box: same penalty but instead of ignoring the damage, Isaac gets healed for that amount.

local mod = RegisterMod("strawpack 2 - plucked daisy", 1)

local game = Game() -- reference to current run (works across restarts and continues)
local sfx = SFXManager()

local PluckedDaisy = { -- This color is called Paris Daisy RGB=(251,235,80)
	TRINKET_PLUCKED_DAISY = Isaac.GetTrinketIdByName("Plucked Daisy"), -- trinket ID
	COLOR = Color(0.984, 0.922, 0.314, 1.0, 0.0, 0.0, 0.0), -- ignored damage color (fades out quickly like Infamy item)
	COLOR_DURATION = 30, -- how long (in frames) the above lasts for until it completely fades out
	HEART_EFFECT_OFFSET = Vector(0.0, -25.0), -- position offset for heart heal effect (for Mom's Box synergy)
	DAMAGE_MULTIPLIER = 2 -- remember that invincibility frames = GetDamageCooldown()=60 * dmg_amount (so don't set this too high!)
} -- ^ should be >0 (non-positive amounts of damage get set to 1 by the game - for player damage)

-- old yellow color = Color(1.0, 0.827, 0.098, 0.8, 0.0, 0.0, 0.0)

local damage_twice_flag = false -- used to apply our own damage after intercepting the original one (will be toggled back to false
-- after the damage is applied so there is no need to worry about mod reloads)

local function take_dmg_plucked_daisy(_, dmg_target, dmg_amount, dmg_flags, dmg_source, dmg_countdown_frames)

	local player = Isaac.GetPlayer(0) -- limit effect to Isaac (and not coop babies)

	if player:HasTrinket(PluckedDaisy.TRINKET_PLUCKED_DAISY) then

		-- (see below) Second time we come here
		if damage_twice_flag then
			damage_twice_flag = false
			return nil -- deal damage doubled damage (and get out earlier)
		end

		-- First time we come here
		if math.random(2) == 1 then -- 50% chance to ignore damage

			if player:HasCollectible(CollectibleType.COLLECTIBLE_MOMS_BOX) then -- Mom's Box synergy

				-- Get healed that amount instead of just ignoring it
				player:AddHearts(dmg_amount) -- red hearts only
				local effect = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.HEART, 0, player.Position + PluckedDaisy.HEART_EFFECT_OFFSET, Vector(0, 0), player):ToEffect()
				effect.DepthOffset = 3000.0 -- bring to the very front (overlayed on top of everything)
				sfx:Play(SoundEffect.SOUND_VAMP_GULP, 1.0, 0, false, 1.0)

			end 

			-- Give some visual feedback:
			player:SetColor(PluckedDaisy.COLOR, PluckedDaisy.COLOR_DURATION, 0, true, false) -- true = fade out

			return false

		else -- 50% chance to have damage received doubled (Issac's dmg_countdown_frames are the issue here)

			damage_twice_flag = true
			player:TakeDamage(PluckedDaisy.DAMAGE_MULTIPLIER * dmg_amount, dmg_flags, dmg_source, dmg_countdown_frames) -- with original invincibility frames
			-- IMPORTANT: dmg_countdown_frames are proportional to damage taken: invincibility frames = GetDamageCooldown() * dmg_amount (keep this in mind while looking at countdown frames)
			return false -- ignore original damage

		end
	end
end

-- Called every time Isaac takes damage (before the damage is applied)
mod:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, take_dmg_plucked_daisy, EntityType.ENTITY_PLAYER)

return {
	TRINKET_ID = PluckedDaisy.TRINKET_PLUCKED_DAISY
}