--[[
?)]]
-- ################################################## LARRY'S BUTT TRINKET ##################################################
-- When hurt to half a heart, if the damage was done by a projectile, a poop shield spawns around Isaac. Otherwise, Isaac spawns
-- a fart that deals knockback and poison damage.

local mod = RegisterMod("larrys butt", 1)

local game = Game() -- reference to current run (works across restarts and continues)

local LarrysButt = {
	TRINKET_LARRYS_BUTT = Isaac.GetTrinketIdByName("Larry's Butt"), -- trinket ID
	FART_RADIUS = 80.0, -- area of effect
	FART_SCALE = 1.5, -- how scaled up the fart cloud is (should match with the radius)
	FART_SUBTYPE = 0, -- normal green fart
	BASE_POOP = 0 -- poop variant when no synergies exist
}

-- Auxiliary function that spawns a grid entity type with a random variant in the 8 adjacent grid spaces around the center position
-- adjacent_grid_spawn(int , table , Vector)
local function adjacent_grid_spawn(grid_entity_type, entity_variants, center_pos, forced)
	
	local pos -- Where to spawn the grid_entity

	-- (ingame grids are 40x40) -40 = initial value, 40 = max value, 40 = increment
	for i = -40, 40, 40 do
		for j = -40, 40, 40 do
			if i ~= 0 or j ~= 0 then -- skip center entity's position
				pos = Vector(center_pos.X+i, center_pos.Y+j)
				-- GridSpawn(int gridEntityType, int Variant, Vector position, boolean forced)
				Isaac.GridSpawn(grid_entity_type, entity_variants[math.random(#entity_variants)], pos, forced)
			end
		end
	end
end

local function update_larrysbutt(_, dmg_target, dmg_amount, dmg_flags, dmg_source, dmg_countdown_frames)

	local player = Isaac.GetPlayer(0) -- always Isaac
	dmg_target = dmg_target:ToPlayer() -- Isaac or coop baby

	if player:HasTrinket(LarrysButt.TRINKET_LARRYS_BUTT) then

		-- GetSoulHearts() returns the number of soul hearts AND black hearts
		local health =  dmg_target:GetHearts() + dmg_target:GetSoulHearts() + dmg_target:GetEternalHearts()
		local final_health = health - dmg_amount -- dmg_amount is measured in half hearts for ENTITY_PLAYER

		-- If the damage would leave Isaac on half a heart or less
		if final_health <= 1 then

			-- If the damage was done by a projectile (ranged damage)
			if dmg_source.Type == EntityType.ENTITY_PROJECTILE then

				-- Poop variants:
				-- 0 = normal, 1 = red, 2 = corn+fly, 3 = gold, 4 = rainbow, 5 = black

				local poop_variants = {LarrysButt.BASE_POOP} -- normal poop

				if player:HasTrinket(TrinketType.TRINKET_MECONIUM) then -- Meconium trinket synergy
					table.insert(poop_variants, 5)
				end

				if player:HasCollectible(CollectibleType.COLLECTIBLE_MIDAS_TOUCH) then -- Midas Touch item synergy
					table.insert(poop_variants, 3)
				end

				if player:HasCollectible(CollectibleType.COLLECTIBLE_BOZO) then -- Bozo item synergy
					table.insert(poop_variants, 4)
				end

				-- In the following, dmg_target is used instead of player so it works in coop (multiple EntityPlayers)

				-- Auxiliary function that spawns poop in the 8 tiles adjacent to Isaac
				adjacent_grid_spawn(GridEntityType.GRID_POOP, poop_variants, dmg_target.Position, true)
				game:ButterBeanFart(dmg_target.Position, LarrysButt.FART_RADIUS, dmg_target, true)
			else -- If it was some other source (most likely contact damage)

				-- If we were to spawn the shield because of contact damage, the enemy would likely get stuck with us.
				-- So, we'll just spawn two fart clouds (one for knockback and the other for poison damage)
				game:ButterBeanFart(dmg_target.Position, LarrysButt.FART_RADIUS, dmg_target, false) -- knockback fart (no visual effect)
				game:Fart(dmg_target.Position, LarrysButt.FART_RADIUS, dmg_target, LarrysButt.FART_SCALE, LarrysButt.FART_SUBTYPE) -- poison fart (scaled up)
			end
		end
	end

	-- Apply the damage
	return nil
end

-- Called every time Isaac takes damage (before the damage is applied)
mod:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, update_larrysbutt, EntityType.ENTITY_PLAYER)