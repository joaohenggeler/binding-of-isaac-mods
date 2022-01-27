--[[
?)]]
-- ################################################## MINI MAW FAMILIAR ##################################################
-- Follows Isaac, sucking enemy projectiles within a certain range. Fires a normal tear towards the closest enemy when hit
-- by an enemy projectile.

local mod = RegisterMod("mini maw", 1)

local sfx = SFXManager()

-- Returns an Entity and its distance if one is found within that range and can be targetted. Otherwise nil and math.huge.
local function get_nearest_vulnerable_enemy(position, range)

	local nearest_enemy = nil
	local closest_distance = math.huge

	for _, entity in pairs(Isaac.GetRoomEntities()) do

		if entity:IsVulnerableEnemy() and not entity:HasEntityFlags(EntityFlag.FLAG_NO_TARGET) then
			local distance = entity.Position:Distance(position)
			if distance <= range and distance < closest_distance then
				closest_distance = distance
				nearest_enemy = entity
			end
		end
	end

	return nearest_enemy, closest_distance
end

local MiniMaw = {
	COLLECTIBLE_MINI_MAW = Isaac.GetItemIdByName("Mini Maw"), -- item ID
	VARIANT = Isaac.GetEntityVariantByName("Mini Maw"), -- familiar variant
	PULL_RANGE = 120.0, -- area of influence (ingame units) for sucking
	PULL_STRENGTH = 0.16, -- how hard an enemy projectile is pulled towards Mini Maw when in pulling range (light attraction)
	TEAR_VELOCITY = 12.0, -- how fast tears shot by Mini Maw travel
	TEAR_DAMAGE = 4.50 -- how much damage these deal
}

-- Called once after a Mini Maw familiar is initialized (first spawn/on run continues)
local function init_mini_maw(_, mini_maw) -- EntityFamiliar

	local sprite = mini_maw:GetSprite()
	-- Play the sucking effect animation under the default animation ("Float"):
	sprite:PlayOverlay("Effect", true) -- forced = true
	sprite:SetOverlayRenderPriority(true) -- RenderFirst = true
	-- Both of these being true makes it so that the sucking effect is played under the body animation (i.e. it looks right)

	mini_maw:AddToFollowers() -- if it's part of the familiar train that follows Isaac (necessary for CheckFamiliar())
end

mod:AddCallback(ModCallbacks.MC_FAMILIAR_INIT, init_mini_maw, MiniMaw.VARIANT)

-- Called every game update for each Mini Maw
local function update_mini_maw(_, mini_maw) -- EntityFamiliar

	-- Follow whoever the parent is at the moment (if the parent is nil, the familiar will follow Isaac)
	mini_maw:FollowParent()

	local sprite = mini_maw:GetSprite()

	if sprite:IsEventTriggered("Shoot") then -- Shoot a tear or more back at the closest enemy

		local target = get_nearest_vulnerable_enemy(mini_maw.Position, math.huge) -- infinite range

		if target ~= nil then -- if there is something to shoot at in the given range

			sfx:Play(SoundEffect.SOUND_STONESHOOT, 1.0, 0, false, 1.2) -- increased pitch (it's a MINI maw after all)

			-- Velocity vector that points from this Mini Maw's position towards the closest target's position (target_pos - source_pos)
			local tear_vel = (target.Position - mini_maw.Position):Resized(MiniMaw.TEAR_VELOCITY)

			local tear = Isaac.Spawn(EntityType.ENTITY_TEAR, TearVariant.BLUE, 0, mini_maw.Position, tear_vel, mini_maw):ToTear()
			tear.CollisionDamage = MiniMaw.TEAR_DAMAGE

			-- this is a bit clumsy, sorry
			if mini_maw.Player:HasCollectible(CollectibleType.COLLECTIBLE_BFFS) then -- BFFS synergy: shoot triple shot
				local angle = 20.0
				for i = 1, 2 do
					tear = Isaac.Spawn(EntityType.ENTITY_TEAR, TearVariant.BLUE, 0, mini_maw.Position, tear_vel:Rotated(angle), mini_maw):ToTear()
					tear.CollisionDamage = MiniMaw.TEAR_DAMAGE
					angle = -angle
				end
			end

		end
	end

	-- After shooting, go back to floating and sucking (underlay) animations
	if sprite:IsFinished("Shoot") then
		sprite:Play("Float", false)
		sprite:PlayOverlay("Effect", false)
	end

	-- Pull enemy projectiles towards the familiar
	for _, entity in pairs(Isaac.FindInRadius(mini_maw.Position, MiniMaw.PULL_RANGE, EntityPartition.BULLET)) do

		if sprite:IsPlaying("Float") then -- Pull bullet towards Mini Maw
			entity:AddVelocity((mini_maw.Position - entity.Position):Resized(MiniMaw.PULL_STRENGTH))
		end

	end
end

mod:AddCallback(ModCallbacks.MC_FAMILIAR_UPDATE, update_mini_maw, MiniMaw.VARIANT)

-- Called when an entity collides with a Mini Maw familiar
local function pre_mini_maw_collision(_, familiar, collider, low)

	if collider.Type == EntityType.ENTITY_PROJECTILE then

		local sprite = familiar:GetSprite()

		if sprite:IsPlaying("Float") then
			collider:Remove() -- eat bullet
		else
			collider:Die() -- bullet splat
		end
		sprite:RemoveOverlay() -- restarted after Shoot animation
		sprite:Play("Shoot", false) -- see event trigger near start

	end

end

mod:AddCallback(ModCallbacks.MC_PRE_FAMILIAR_COLLISION, pre_mini_maw_collision, MiniMaw.VARIANT)

-- Handles cache updates
local function update_cache(_, player, cache_flag)

	-- Handle the addition/removal and reallignments of Isaac's familiars/orbitals
	if cache_flag == CacheFlag.CACHE_FAMILIARS then
		player:CheckFamiliar(MiniMaw.VARIANT, player:GetCollectibleNum(MiniMaw.COLLECTIBLE_MINI_MAW), player:GetCollectibleRNG(MiniMaw.COLLECTIBLE_MINI_MAW))
	end
end

mod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, update_cache)