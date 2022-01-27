--[[
?]]

local mod = RegisterMod("strawpack 2 - data loader and saver", 1)

local json = require("json") -- for saving and loading data
local HelperFunctions = require("resources.scripts.strawpack helper functions")

local game = Game()

local ModData = {}
local decode_status, decode_retval = pcall(json.decode, mod:LoadData()) -- prevent an error while reading data from stopping the mod completely
-- LoadData() returns an empty string if no save.dat file exists (decode would throw an error in this case)

if decode_status then -- successfully decoded the data into a table
	ModData = decode_retval
else -- error while trying to decode the data
	Isaac.DebugString(string.format("[%s] Couldn't load StrawPack 2's data. New values will be put in place and a new file will be created when the run is exited.", mod.Name))
end

-- Two cases:
-- Successfully loaded but one or more variables could have been removed by some dingus.
-- Failed to load but ModData is already a table which means that all variables below will be nil.

if ModData.SeedOfDiscordData == nil then ModData.SeedOfDiscordData = {} end -- Seed of Discord trinket
if ModData.SeedOfDiscordData.OriginalChallenge == nil then ModData.SeedOfDiscordData.OriginalChallenge = game.Challenge end
if ModData.SeedOfDiscordData.OriginalSeedEffects == nil then ModData.SeedOfDiscordData.OriginalSeedEffects = HelperFunctions.get_seed_effects() end

if ModData.MomsMoleData == nil then ModData.MomsMoleData = {} end -- Mom's Mole item
if ModData.MomsMoleData.UndergroundTearNum == nil then ModData.MomsMoleData.UndergroundTearNum = 0 end
if ModData.MomsMoleData.UndergroundTearFlags == nil then ModData.MomsMoleData.UndergroundTearFlags = 0 end

-- Save current mod data. Used for mods that need to save at a specific time. E.g: Seed of Discord needs to save the original seed effects
-- after the game starts.
local function save_mod_data()
	mod:SaveData(json.encode(ModData))
end

-- Most common behavior, save before exiting to the menu. Right now, only Mom's Mole takes advantage of this.
local function pre_game_exit(_, should_save)
	if should_save then -- we always come through here before it's possible to reload mods in the Mods menu
		save_mod_data()
	end -- even if we choose to continue, ModData still holds the correct values, regardless of whether the mod has been reloaded
	-- (not should_save) is when you win/lose a run. It's not really necessary to save then in this particular mod.
end

mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, pre_game_exit)

local function get_seed_of_discord_data()
	return ModData.SeedOfDiscordData
end

local function get_moms_mole_data()
	return ModData.MomsMoleData
end

return {
	save_mod_data = save_mod_data,
	get_seed_of_discord_data = get_seed_of_discord_data,
	get_moms_mole_data = get_moms_mole_data
}