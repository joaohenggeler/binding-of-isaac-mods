--[[
?)]]
-- ################################################## EXTENSION CORD PASSIVE ##################################################
-- Familiars (excluding blue spiders and flies) are now connected by a yellow laser chain.

local mod = RegisterMod("extension cord", 1)

local game = Game() -- reference to current run (works across restarts and continues)
local sfx = SFXManager()

local ZERO_VECTOR = Vector(0, 0)

-- Returns table with every EntityFamiliar in the current room (except blue flies and spiders), in the order which they were spawned
local function get_familiars()

	local my_familiars = {}

	for _, familiar in pairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, -1, -1, false, false)) do
		-- Ignore blue flies and spiders
		if familiar.Variant ~= FamiliarVariant.BLUE_FLY and familiar.Variant ~= FamiliarVariant.BLUE_SPIDER then
			table.insert(my_familiars, familiar:ToFamiliar()) -- insert an EntityFamiliar in the last position of the table
		end
	end

	return my_familiars
end

local ExtensionCord = {
	COLLECTIBLE_EXTENSION_CORD = Isaac.GetItemIdByName("Extension Cord"),
	LASER_MIN_DISTANCE = 20.0, -- minimum distance for a laser to be spawned (must be >0 to avoid bug on new room entrance)
	LASER_TIMEOUT = 3, -- (~ chain size) how long it stays on screen (0 = forever = don't)
	LASER_DAMAGE = 6.00, -- damage per tick
	LASER_COLOR = Color(1.0, 1.0, 1.0, 0.5, 255.0, 255.0, 0.0), -- yellow
	LASER_OFFSET = Vector(0.0, -20.0), -- how much above the ground it is so it lines up with familiars (inverted Y axis)
	LASER_VOLUME = 0.4 -- how loud the laser sound effect is
}

local familiars = get_familiars() -- table with every EntityFamiliar in the room (excluding blue spiders and flies)
-- called once here because of mod reloads
local familiar_update_flag = false -- whether or not get_familiars() should be called again below (can't be called directly in
-- update_cache due to callback order)

local function extension_cord_update(_)

	local player = Isaac.GetPlayer(0)
	local player_data = player:GetData()

	if player:HasCollectible(ExtensionCord.COLLECTIBLE_EXTENSION_CORD) then

		-- Tries to make repeating laser sounds less annoying
		sfx:AdjustVolume(SoundEffect.SOUND_REDLIGHTNING_ZAP, ExtensionCord.LASER_VOLUME)
		--sfx:AdjustPitch(SoundEffect.SOUND_REDLIGHTNING_ZAP, 0.0)

		-- Get familars every time update_cache is called with CACHE_FAMILIAR  or on new room entrance (should be covered
		-- by the cache update)
		if familiar_update_flag or familiars == nil or game:GetRoom():GetFrameCount() == 1 then -- avoid being called every frame
			familiars = get_familiars()
			familiar_update_flag = false
		end

		local familiar_num = #familiars

		if familiar_num > 0 then

			local frequency -- frames between laser chain spawns
			-- best values from testing:
			if familiar_num == 1 then
				frequency = 60
			elseif familiar_num == 2 then
				frequency = 10
			elseif familiar_num >= 3 and familiar_num <= 8 then
				frequency = 4
			else
				frequency = 2
			end

			if game:GetFrameCount() % frequency == 0 then -- game instead of Isaac so it doesn't count the pause screen

				-- initialize familiar index (which familiar we are on) + avoid indexing a nil value
				if player_data.ExtensionCordIndex == nil or player_data.ExtensionCordIndex > familiar_num then 
					player_data.ExtensionCordIndex = familiar_num -- start at the end and work backwards (last one shoots towards Isaac)
				end

				local source_pos = familiars[player_data.ExtensionCordIndex].Position
				local target_pos

				if player_data.ExtensionCordIndex == 1 then -- Familiar 1 --> Player
					target_pos = player.Position
				else -- Familiar i --> Familiar i-1
					target_pos = familiars[player_data.ExtensionCordIndex-1].Position
				end

				local direction = target_pos - source_pos -- direction vector that points from source_pos towards target_pos
				local angle = direction:GetAngleDegrees() -- angle at which the laser will be shot
				local distance = source_pos:Distance(target_pos) -- distance between the two familiars (laser's max distance)

				if distance > ExtensionCord.LASER_MIN_DISTANCE then -- distance must be >0 to avoid bug on new room entrance

					-- ShootAngle(integer Variant, Vector SourcePos, float AngleDegrees, integer Timeout, Vector PosOffset, Entity Source)
					local laser = EntityLaser.ShootAngle(2, source_pos, angle, ExtensionCord.LASER_TIMEOUT, ExtensionCord.LASER_OFFSET, familiars[player_data.ExtensionCordIndex])
					sfx:AdjustVolume(SoundEffect.SOUND_REDLIGHTNING_ZAP, ExtensionCord.LASER_VOLUME) -- these can get pretty annoying but there's not much to be done about them
					laser:SetMaxDistance(distance)
					laser.CollisionDamage = ExtensionCord.LASER_DAMAGE
					laser.EndPoint = target_pos
					laser.Color = ExtensionCord.LASER_COLOR
					
				end

				if player_data.ExtensionCordIndex <= 1 then -- go to next familiar in the chain
					player_data.ExtensionCordIndex = familiar_num
				else
					player_data.ExtensionCordIndex = player_data.ExtensionCordIndex - 1
				end

			end
		end

	elseif player_data.ExtensionCordIndex ~= nil then -- item lost/rerolled
		player_data.ExtensionCordIndex = nil -- back to original state
		familiars = nil
	end
end

mod:AddCallback(ModCallbacks.MC_POST_UPDATE, extension_cord_update)

-- Handles cache updates
local function update_cache(_, player, cache_flag)

	-- Handle the addition/removal and reallignments of Isaac's familiars/orbitals
	if player:HasCollectible(ExtensionCord.COLLECTIBLE_EXTENSION_CORD) and cache_flag == CacheFlag.CACHE_FAMILIARS then
		familiar_update_flag = true -- for Extension Cord item (whether or not we should call get_familiars() again)
	end -- get_familiars() will only be called when it is needed (which is why we can have the first condition)
	
end

mod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, update_cache)