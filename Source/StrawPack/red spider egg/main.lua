--[[
?)]]
-- ################################################## RED SPIDER EGG TRINKET ##################################################
-- Damage up + Speed up + enemy projectiles have a 1/10 chance to turn into spiders when spawned.

local mod = RegisterMod("red spider egg", 1)

local TRINKET_CHASTITY_BELT = Isaac.GetTrinketIdByName("Chastity Belt") -- -1 or the ID (cross mod synergy)

local RedSpiderEgg = {
	TRINKET_RED_SPIDER_EGG = Isaac.GetTrinketIdByName("Red Spider Egg"),
	CHANCE = 10, -- 1 in CHANCE to spawn spider
	DAMAGE = 2.10, -- stat up
	SPEED = 0.15 -- stat up
}

local function post_projectile_update(_, projectile)

	if projectile.FrameCount == 1 then

		local player = Isaac.GetPlayer(0)

		if player:HasTrinket(RedSpiderEgg.TRINKET_RED_SPIDER_EGG) then

			local max_roll = RedSpiderEgg.CHANCE
			if player:HasCollectible(CollectibleType.COLLECTIBLE_MOMS_BOX) then -- Mom's Box synergy
				max_roll = max_roll // 2 -- twice as likely
			end

			if math.random(max_roll) == 1 and -- we were unlucky enough and either the Chastity Belt exists and Isaac has it on (don't spawn spiders) or the Chastity Belt doesn't exist (we still spawn spiders)
				(TRINKET_CHASTITY_BELT ~= -1 and not player:HasTrinket(TRINKET_CHASTITY_BELT) or TRINKET_CHASTITY_BELT == -1) then

				local target_pos = projectile.Position + projectile.Velocity:Resized(120.0)
				--ThrowSpider (Vector Position, Entity Spawner, Vector TargetPos, boolean Big, float YOffset)
				EntityNPC.ThrowSpider(projectile.Position, projectile.SpawnerEntity, target_pos, false, 1.0)

				projectile:Remove() -- remove projectile

			end

		end

	end

end

mod:AddCallback(ModCallbacks.MC_POST_PROJECTILE_UPDATE, post_projectile_update)

-- Handles cache updates
local function update_cache(_, player, cache_flag)

	if player:HasTrinket(RedSpiderEgg.TRINKET_RED_SPIDER_EGG) then

		local multiplier = 1.0
		if player:HasCollectible(CollectibleType.COLLECTIBLE_MOMS_BOX) then -- Mom's Box synergy
			multiplier = 2.0
		end

		if cache_flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + RedSpiderEgg.DAMAGE * multiplier
		elseif cache_flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + RedSpiderEgg.SPEED * multiplier
		end
	end

end

mod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, update_cache)