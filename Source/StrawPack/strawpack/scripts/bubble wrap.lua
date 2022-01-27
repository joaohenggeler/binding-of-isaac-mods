--[[
?)]]
-- ################################################## BUBBLE WRAP PASSIVE ##################################################
-- Tears now linger for some frames right after they start to fall.

local ZERO_VECTOR = Vector(0, 0)

local BubbleWrap = {
	COLLECTIBLE_BUBBLE_WRAP = Isaac.GetItemIdByName("Bubble Wrap"), -- item ID
	SHOT_SPEED = 0.20, -- stat up
	TEAR_HEIGHT = 6.20, -- stat up (increase for greater range)
	TEAR_HEIGHT_CAP = -13.00, -- how low it can go if we have Bubble Wrap (stops certain rooms from becoming impossible if you have this + Cricket's Body and/or Number One)
	MAX_HEIGHT = -10.00, -- tears at a greater height (inverted Y axis) will be held in place
	HANGING_DURATION = 240 -- maximum tear floating limit (game updates)
}

-- For reference (height axis points down!):
--[[
	TEAR HEIGHT:
	-10.0	-> a travelling tear usually starts abruptly falling around this height (aprox. height for max range)

	-5.0	-> below this point they might as well have hit the ground

	 0.0	-> they never get here (ground?)
]]

local function post_tear_update(_, tear) -- EntityTear

	if Isaac.GetPlayer(0):HasCollectible(BubbleWrap.COLLECTIBLE_BUBBLE_WRAP) and tear.SpawnerType == EntityType.ENTITY_PLAYER then

		local tear_data = tear:GetData() -- get table unique to every tear entity (emptied out every new room/continue)

		if tear_data.BubbleWrapStopDescent == nil then -- initialize block flag
			tear_data.BubbleWrapStopDescent = false
		end
		if tear_data.BubbleWrapLastHeight == nil then -- initialize last height before falling
			tear_data.BubbleWrapLastHeight = 0
		end

		if not tear_data.BubbleWrapStopDescent and tear.Height >= BubbleWrap.MAX_HEIGHT then -- about to fall to the ground (see reference above)
			tear_data.BubbleWrapStopDescent = true
			tear_data.BubbleWrapLastHeight = tear.Height
			tear_data.BubbleWrapFramesBeforeBlock = tear.FrameCount
			tear_data.BubbleWrapOriginalSpeed = tear.Velocity:Length()
			tear.Velocity = ZERO_VECTOR
			
		end

		if tear_data.BubbleWrapStopDescent then -- fix it in place
			tear.Velocity:Resized(tear_data.BubbleWrapOriginalSpeed)
			tear.FallingSpeed = 0
			tear.FallingAcceleration = 0
			tear.Height = tear_data.BubbleWrapLastHeight
		end

		if tear_data.BubbleWrapStopDescent and tear.FrameCount - tear_data.BubbleWrapFramesBeforeBlock > BubbleWrap.HANGING_DURATION then -- max floating frames
			tear:Die() -- tear splat
		end

	end
end

-- Handles cache updates
local function update_cache(_, player, cache_flag)

	if player:HasCollectible(BubbleWrap.COLLECTIBLE_BUBBLE_WRAP) then

		if cache_flag == CacheFlag.CACHE_SHOTSPEED then -- Increase shot speed
			player.ShotSpeed = player.ShotSpeed + BubbleWrap.SHOT_SPEED * player:GetCollectibleNum(BubbleWrap.COLLECTIBLE_BUBBLE_WRAP)
		elseif cache_flag == CacheFlag.CACHE_RANGE then -- Tears are fired from heigher (range up)
			player.TearHeight = math.min(BubbleWrap.TEAR_HEIGHT_CAP, player.TearHeight - BubbleWrap.TEAR_HEIGHT * player:GetCollectibleNum(BubbleWrap.COLLECTIBLE_BUBBLE_WRAP))
			-- Remember that the change stat is negative! (Y axis points down)
		end

	end

end

return {
	ID = BubbleWrap.COLLECTIBLE_BUBBLE_WRAP,
	post_tear_update = post_tear_update,
	update_cache = update_cache
}