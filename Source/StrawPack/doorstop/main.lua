--[[
?)]]
-- ################################################## DOORSTOP TRINKET ##################################################
-- When Isaac enters a new room, the door he came through will be opened (does not apply to devil/angel/boss rush rooms).

local mod = RegisterMod("doorstop", 1)

local game = Game() -- reference to current run (works across restarts and continues)
local level = game:GetLevel() -- reference to current stage (works across restarts and continues)

local Doorstop = {
	TRINKET_DOORSTOP = Isaac.GetTrinketIdByName("Doorstop") -- trinket ID
}

local function update_doorstop(_)

	local player = Isaac.GetPlayer(0)

	if player:HasTrinket(Doorstop.TRINKET_DOORSTOP) then

		local room = level:GetCurrentRoom()

		-- level.EnterDoor is a DoorSlot (see enums)
		local enter_door = room:GetDoor(level.EnterDoor) -- Get reference to GridEntityDoor from DoorSlot (where we entered)

		-- If the door exists and is closed
		if enter_door ~= nil and not enter_door:IsOpen() then
			enter_door:Open()
		end

	end
end

-- Called every new room
mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, update_doorstop)