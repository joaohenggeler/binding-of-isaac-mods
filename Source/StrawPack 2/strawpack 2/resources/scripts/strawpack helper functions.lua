--[[
?]]

local game = Game()
local seeds = game:GetSeeds()

-- Returns a table with every SeedEffect present in the run. Can be called in the menus successfully.
local function get_seed_effects()
	local res = {}
	for _, seed in pairs(SeedEffect) do
		if seeds:HasSeedEffect(seed) then
			table.insert(res, seed)
		end
	end
	return res
end

return {
	get_seed_effects = get_seed_effects
}