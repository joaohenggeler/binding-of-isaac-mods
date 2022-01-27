--[[
?]]
-- If you want every item/trinket in this pack to spawn in the current room, use the following command in the Debug Console:
-- "showcase strawpack2"

-- ##########################################################################################################################
-- ##################################################   STRAWPACK 2   #######################################################
-- ##########################################################################################################################

local mod = RegisterMod("strawpack 2", 1)

local SCRIPTS_PATH = "resources.scripts."

 -- Trinkets and items are loaded by the following order:
local ITEM_NAMES = {
	"fallen feather + the gluttons fork", "fly mod", "moms mole", "monstros eye"
}

local TRINKET_NAMES = {
	"car key", "familiar doll", "plucked daisy", "seed of discord", "social circle"
} -- Social Circle must be loaded after any follower in the pack

-- Run mod scripts:
require(SCRIPTS_PATH .. "strawpack helper functions")
require(SCRIPTS_PATH .. "strawpack data loader and saver") -- manages StrawPack 2's data loading and saving

local ITEM_REQUIRE_TABLES = {} -- table with the tables returned by every item's require()
for _, item_name in pairs(ITEM_NAMES) do
	table.insert(ITEM_REQUIRE_TABLES, require(SCRIPTS_PATH .. item_name))
end

local TRINKET_REQUIRE_TABLES = {} -- table with the tables returned by every trinket's require()
for _, trinket_name in pairs(TRINKET_NAMES) do
	table.insert(TRINKET_REQUIRE_TABLES, require(SCRIPTS_PATH .. trinket_name))
end

-- ################################################## SPAWNS ITEMS COMMAND ##################################################
local game = Game()
local ZERO_VECTOR = Vector(0, 0)

local StrawPack = {
	TRINKET_STARTING_GRID_INDEX = 47, -- in which grid cell do the trinkets spawn when the command is executed?
	ITEM_STARTING_GRID_INDEX = 77 -- same as above for item pedestals
}

local function execute_spawn_items_command(_, cmd, params)

	if cmd == "showcase" and params:lower() == "strawpack2" then -- "showcase strawpack2" command

		for i, trinket_table in ipairs(TRINKET_REQUIRE_TABLES) do -- spawn trinkets
			Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TRINKET, trinket_table.TRINKET_ID,
				game:GetRoom():GetGridPosition(StrawPack.TRINKET_STARTING_GRID_INDEX + i - 1), ZERO_VECTOR, nil)
		end

		for i, item_table in ipairs(ITEM_REQUIRE_TABLES) do -- spawn item pedestals
			Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, item_table.ITEM_ID,
				game:GetRoom():GetGridPosition(StrawPack.ITEM_STARTING_GRID_INDEX + i - 1), ZERO_VECTOR, nil)
		end

		Isaac.ConsoleOutput(string.format("Spawned %d trinkets and %d items in the current room.", #TRINKET_NAMES, #ITEM_NAMES))

		-- return "..." --> still crashes the game :/
	end
end

mod:AddCallback(ModCallbacks.MC_EXECUTE_CMD, execute_spawn_items_command)