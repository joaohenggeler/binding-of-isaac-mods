-- ################################################## CAR KEY TRINKET ##################################################
-- While held, if Isaac collides with a locked object with a speed greater than his current maximum possible speed, it will be
-- unlocked.
-- Locked objects include: Chests (golden + eternal), Doors (Treasure, Shop, Double-key, Arcade), Locks (kinda)

local mod = RegisterMod("car key", 1)

-- For reference:
--[[
	Isaac's velocity vector length is aprox. 2.37 + 2.17*speed - 1.09*speed^2 + 0.92*speed^3, where speed is the Player.MoveSpeed (0.1 to 2.0)
?)]]

local CarKey = {
	TRINKET_CAR_KEY = Isaac.GetTrinketIdByName("Car Key"), -- trinket ID
	SPEED_TO_BEAT_OFFSET = 0.05 -- how much velocity_length_from_speed()'s return value is offset by; used to make up for the fact that
	-- this value is a rough approximation
}

local game = Game() -- reference to current run (works across restarts and continues)
local sfx = SFXManager()

-- Returns true if entity_1 and entity_2 (Entity) are touching each other. Otherwise false.
-- Simple collisions (not useful for lasers).
local function are_entities_colliding(entity_1, entity_2)
	return entity_1.Position:DistanceSquared(entity_2.Position) <= (entity_1.Size + entity_2.Size) * (entity_1.Size + entity_2.Size)
end

-- Returns Isaac's max velocity vector length given his speed stat value (rough aproximation!)
local function velocity_length_from_speed(move_speed)
	--return 2.3647 + 2.233854*move_speed - 1.18513*move_speed^2 + 0.9567174*move_speed^3
	return 2.37 + 2.17*move_speed - 1.09*move_speed*move_speed + 0.92*move_speed*move_speed*move_speed
end

local function update_car_key(_, player)

	if player:HasTrinket(CarKey.TRINKET_CAR_KEY) and player.Velocity:Length() > velocity_length_from_speed(player.MoveSpeed) + CarKey.SPEED_TO_BEAT_OFFSET then

		-- For Grid Entities (lock blocks and locked doors):
		-- player:CollidesWithGrid() wouldn't work here because, by the time this returns true, our velocity vector is going to aprox. 0.0

		-- The object we hit will be where we are plus a vector with the same direction as our speed that stretches enough
		-- to overtake our collision radius and a little bit (objects are 40x40) to guarantee that we are on the right grid cell
		local grid_position = player.Position + player.Velocity:Resized(player.Size + 20)

		local room = game:GetRoom()
		-- GetGridEntityFromPos() is currently broken I think? It's supposed to take a position (above) but it says it takes an index
		local grid_entity = room:GetGridEntity(room:GetGridIndex(grid_position)) -- hence this trickery

		if grid_entity ~= nil then -- if it exists in that grid cell

			local grid_type = grid_entity.Desc.Type

			if grid_type == GridEntityType.GRID_DOOR then
				
				local door = grid_entity:ToDoor()

				if door:IsLocked() and door:GetVariant() ~= DoorVariant.DOOR_LOCKED_KEYFAMILIAR then -- locked doors (not Mega Satan)
					door:TryUnlock(true)
					sfx:Play(SoundEffect.SOUND_GOLDENKEY, 1.0, 0, false, 1.0) -- confirm that the effect happened
				end

			-- NOTE: no class for Locks exists yet
			elseif grid_type == GridEntityType.GRID_LOCK and grid_entity.State ~= 1 then

				-- For locks: state = 0 = locked, state = 1 = unlocked
				grid_entity.State = 1 -- This only works when you exit the room
				-- Destroy() + Hurt() + Forcing sprite animation + Update sprite, grid entity and room don't work
				sfx:Play(SoundEffect.SOUND_GOLDENKEY, 1.0, 0, false, 1.0) -- confirm that the effect happened
				
			end
			
		end

		-- For Entities (locked chests):
		for _, entity in pairs(Isaac.FindByType(EntityType.ENTITY_PICKUP, -1, -1, true, false)) do

			-- Find chests that can be unlocked by keys
			if entity.Variant == PickupVariant.PICKUP_LOCKEDCHEST or entity.Variant == PickupVariant.PICKUP_ETERNALCHEST then

				local chest = entity:ToPickup()
				if are_entities_colliding(player, chest) and chest:TryOpenChest() then -- condition order!!			
					sfx:Play(SoundEffect.SOUND_GOLDENKEY, 1.0, 0, false, 1.0) -- confirm that the effect happened
				end
			end
		end

	end
end

mod:AddCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, update_car_key)