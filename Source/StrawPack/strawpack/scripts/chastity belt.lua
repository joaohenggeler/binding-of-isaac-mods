--[[
?)]]
-- ################################################## CHASTITY BELT TRINKET ##################################################
-- Enemies that are spawned by other enemies are removed/killed. Portals are instantly killed (bonus). 

local ChastityBelt = {
	TRINKET_CHASTITY_BELT = Isaac.GetTrinketIdByName("Chastity Belt"), -- trinket ID
	CHANCE = 2 -- 1 in CHANCE to block enemy spawn
}

-- Called after every EntityNPC update though we only want the first update where SpawnerType is set (it's always 0 in INIT)
local function post_npc_update(_, npc)
	
	if npc.FrameCount == 1 then -- SpawnerType isn't set until the first update (after init)

		local player = Isaac.GetPlayer(0)

		if player:HasTrinket(ChastityBelt.TRINKET_CHASTITY_BELT) and npc:IsVulnerableEnemy() and not npc:IsBoss()
			and npc.SpawnerType ~= EntityType.ENTITY_NULL and npc.SpawnerType ~= EntityType.ENTITY_PLAYER
			and npc.SpawnerType ~= EntityType.ENTITY_FAMILIAR then

			local chance = ChastityBelt.CHANCE
			if player:HasCollectible(CollectibleType.COLLECTIBLE_MOMS_BOX) then
				chance = chance // 2 -- twice as likely
			end

			if math.random(chance) == 1 then
				npc:Remove()
			end

		end

	end

end

return {
	ID = ChastityBelt.TRINKET_CHASTITY_BELT,
	post_npc_update = post_npc_update
}