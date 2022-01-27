--[[
?)]]
-- ################################################## A PRESCRIPTION TRINKET ##################################################
-- While held, activates a random pill effect (that doesn't change Isaac's stats) every minute.

local game = Game() -- reference to current run (works across restarts and continues)

local APrescription = {
	TRINKET_A_PRESCRIPTION = Isaac.GetTrinketIdByName("A Prescription"), -- trinket ID
	INTERVAL = 1800, -- 30 = 1 sec (in game updates)
	PILLS = {PillEffect.PILLEFFECT_BAD_GAS, PillEffect.PILLEFFECT_BOMBS_ARE_KEYS, PillEffect.PILLEFFECT_EXPLOSIVE_DIARRHEA,
						PillEffect.PILLEFFECT_I_FOUND_PILLS, PillEffect.PILLEFFECT_PUBERTY, PillEffect.PILLEFFECT_HEMATEMESIS,
						PillEffect.PILLEFFECT_PARALYSIS, PillEffect.PILLEFFECT_SEE_FOREVER, PillEffect.PILLEFFECT_PHEROMONES,
						PillEffect.PILLEFFECT_AMNESIA, PillEffect.PILLEFFECT_LEMON_PARTY, PillEffect.PILLEFFECT_WIZARD,
						PillEffect.PILLEFFECT_PERCS, PillEffect.PILLEFFECT_ADDICTED, PillEffect.PILLEFFECT_RELAX,
						PillEffect.PILLEFFECT_QUESTIONMARK, PillEffect.PILLEFFECT_LARGER, PillEffect.PILLEFFECT_SMALLER,
						PillEffect.PILLEFFECT_INFESTED_EXCLAMATION, PillEffect.PILLEFFECT_INFESTED_QUESTION, PillEffect.PILLEFFECT_POWER,
						PillEffect.PILLEFFECT_FRIENDS_TILL_THE_END, PillEffect.PILLEFFECT_X_LAX, PillEffect.PILLEFFECT_SOMETHINGS_WRONG,
						PillEffect.PILLEFFECT_IM_DROWSY, PillEffect.PILLEFFECT_IM_EXCITED, PillEffect.PILLEFFECT_GULP,
						PillEffect.PILLEFFECT_HORF, PillEffect.PILLEFFECT_SUNSHINE, PillEffect.PILLEFFECT_VURP}
						-- no Retro Vision because it sucks
}

local function update_a_prescription(_)

	local player = Isaac.GetPlayer(0)

	if player:HasTrinket(APrescription.TRINKET_A_PRESCRIPTION) then

		local frequency = APrescription.INTERVAL

		if player:HasCollectible(CollectibleType.COLLECTIBLE_MOMS_BOX) then -- Mom's Box synergy
			frequency = frequency / 2
		end

		if game.TimeCounter % frequency == 0 then

			-- Pill effects that don't affect stats
			local pills = APrescription.PILLS
			-- Use a random pill from that table (random color)
			player:UsePill( pills[math.random(#pills)], math.random(PillColor.NUM_PILLS-1) )

		end
	end
end

return {
	ID = APrescription.TRINKET_A_PRESCRIPTION,
	update_a_prescription = update_a_prescription
}