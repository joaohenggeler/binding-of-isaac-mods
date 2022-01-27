-- If you want every item/trinket in this pack to spawn in the current room, use the following command in the Debug Console:
-- "showcase strawpack"

-- #######################################################################################################################################
-- #######################################################################################################################################
-- #######################################################################################################################################
--[[
?)]]

-- Quick note: only Moldy Cheese saves data.

-- 2018/04/13 - HEADS UP - this was made before I knew what the hell I was doing. For a more sensible approach to Item Packs, check out StrawPack 2.

local mod = RegisterMod("strawpack", 1)

-- import respective item files (require returns a table - in this case it contains functions and the item's ID (so we can spawn them in the starting room)):
local SCRIPTS_DIRECTORY = "scripts."

local APrescription = require(SCRIPTS_DIRECTORY .. "a prescription.lua")
mod:AddCallback(ModCallbacks.MC_POST_UPDATE, APrescription.update_a_prescription)

local BubbleWrap = require(SCRIPTS_DIRECTORY .. "bubble wrap.lua")
mod:AddCallback(ModCallbacks.MC_POST_TEAR_UPDATE, BubbleWrap.post_tear_update)
mod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, BubbleWrap.update_cache)

local ChastityBelt = require(SCRIPTS_DIRECTORY .. "chastity belt.lua")
mod:AddCallback(ModCallbacks.MC_NPC_UPDATE, ChastityBelt.post_npc_update)

-- now in Booster Pack #3
--local Doorstop = require(SCRIPTS_DIRECTORY .. "doorstop.lua")
--mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, Doorstop.update_doorstop)

-- now in Booster Pack #4
--local ExtensionCord = require(SCRIPTS_DIRECTORY .. "extension cord.lua")
--mod:AddCallback(ModCallbacks.MC_POST_UPDATE, ExtensionCord.extension_cord_update)
--mod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, ExtensionCord.update_cache)

local LarrysButt = require(SCRIPTS_DIRECTORY .. "larrys butt.lua")
mod:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, LarrysButt.update_larrysbutt, EntityType.ENTITY_PLAYER)

local MechanicalFlies = require(SCRIPTS_DIRECTORY .. "mechanical flies.lua")
mod:AddCallback(ModCallbacks.MC_FAMILIAR_INIT, MechanicalFlies.init_mechfly_tear, MechanicalFlies.MECHFLY_TEAR_VARIANT)
mod:AddCallback(ModCallbacks.MC_FAMILIAR_UPDATE, MechanicalFlies.update_mechfly_tear, MechanicalFlies.MECHFLY_TEAR_VARIANT)
mod:AddCallback(ModCallbacks.MC_FAMILIAR_INIT, MechanicalFlies.init_mechfly_body, MechanicalFlies.MECHFLY_BODY_VARIANT)
mod:AddCallback(ModCallbacks.MC_FAMILIAR_UPDATE, MechanicalFlies.update_mechfly_body, MechanicalFlies.MECHFLY_BODY_VARIANT)
mod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, MechanicalFlies.update_cache)

local MiniMaw = require(SCRIPTS_DIRECTORY .. "mini maw.lua")
mod:AddCallback(ModCallbacks.MC_FAMILIAR_INIT, MiniMaw.init_mini_maw, MiniMaw.MINI_MAW_VARIANT)
mod:AddCallback(ModCallbacks.MC_FAMILIAR_UPDATE, MiniMaw.update_mini_maw, MiniMaw.MINI_MAW_VARIANT)
mod:AddCallback(ModCallbacks.MC_PRE_FAMILIAR_COLLISION, MiniMaw.pre_mini_maw_collision,  MiniMaw.MINI_MAW_VARIANT)
mod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, MiniMaw.update_cache)

local MoldyCheese = require(SCRIPTS_DIRECTORY .. "moldy cheese.lua")
mod:AddCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, MoldyCheese.update_moldy_cheese)
mod:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, MoldyCheese.hit_moldy_cheese, EntityType.ENTITY_PLAYER)
mod:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, MoldyCheese.on_new_level)
mod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, MoldyCheese.update_cache)
mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, MoldyCheese.post_game_started)
mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, MoldyCheese.pre_game_exit)

local MomsRing = require(SCRIPTS_DIRECTORY .. "moms ring.lua")
mod:AddCallback(ModCallbacks.MC_POST_NPC_DEATH, MomsRing.post_npc_death)
mod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, MomsRing.update_cache)

local Planetoids = require(SCRIPTS_DIRECTORY .. "planetoids.lua")
mod:AddCallback(ModCallbacks.MC_FAMILIAR_INIT, Planetoids.init_planetoid_sun, Planetoids.SUN_VARIANT) -- sun
mod:AddCallback(ModCallbacks.MC_FAMILIAR_UPDATE, Planetoids.update_planetoid_sun, Planetoids.SUN_VARIANT)
mod:AddCallback(ModCallbacks.MC_PRE_FAMILIAR_COLLISION, Planetoids.pre_sun_collision,Planetoids.SUN_VARIANT)

mod:AddCallback(ModCallbacks.MC_FAMILIAR_INIT, Planetoids.init_planetoid_earth, Planetoids.EARTH_VARIANT) -- earth
mod:AddCallback(ModCallbacks.MC_FAMILIAR_UPDATE, Planetoids.update_planetoid_earth, Planetoids.EARTH_VARIANT)
mod:AddCallback(ModCallbacks.MC_PRE_FAMILIAR_COLLISION, Planetoids.pre_earth_collision, Planetoids.EARTH_VARIANT)

mod:AddCallback(ModCallbacks.MC_FAMILIAR_INIT, Planetoids.init_planetoid_moon, Planetoids.MOON_VARIANT) -- moon
mod:AddCallback(ModCallbacks.MC_FAMILIAR_UPDATE, Planetoids.update_planetoid_moon, Planetoids.MOON_VARIANT)
mod:AddCallback(ModCallbacks.MC_PRE_FAMILIAR_COLLISION, Planetoids.pre_moon_collision, Planetoids.MOON_VARIANT)

mod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, Planetoids.update_cache)

local RedSpiderEgg = require(SCRIPTS_DIRECTORY .. "red spider egg.lua")
mod:AddCallback(ModCallbacks.MC_POST_PROJECTILE_UPDATE, RedSpiderEgg.post_projectile_update)
mod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, RedSpiderEgg.update_cache)

-- ################################################## SPAWNS ITEMS IN STARTING ROOM ##################################################
local ZERO_VECTOR = Vector(0, 0)

local function execute_spawn_items_command(_, cmd, params)

	if cmd == "showcase" and params:lower() == "strawpack" then -- "showcase strawpack" command

		Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TRINKET, LarrysButt.ID, Vector(120, 210), ZERO_VECTOR, nil)
		Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TRINKET, RedSpiderEgg.ID, Vector(200, 210), ZERO_VECTOR, nil)
		Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TRINKET, ChastityBelt.ID, Vector(280, 210), ZERO_VECTOR, nil)
		Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TRINKET, APrescription.ID, Vector(360, 210), ZERO_VECTOR, nil)
		--Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TRINKET, Doorstop.ID, Vector(440, 210), ZERO_VECTOR, nil)
		Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, MomsRing.ID, Vector(520, 210), ZERO_VECTOR, nil)
		--Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, ExtensionCord.ID, Vector(120, 360), ZERO_VECTOR, nil)
		Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, MiniMaw.ID, Vector(200, 360), ZERO_VECTOR, nil) 
		Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, MechanicalFlies.ID, Vector(280, 360), ZERO_VECTOR, nil)
		Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, BubbleWrap.ID, Vector(360, 360), ZERO_VECTOR, nil)
		Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, MoldyCheese.ID, Vector(440, 360), ZERO_VECTOR, nil)
		Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, Planetoids.ID, Vector(520, 360), ZERO_VECTOR, nil)

		Isaac.ConsoleOutput("Spawned 10 StrawPack items in the current room.")

	end
end

mod:AddCallback(ModCallbacks.MC_EXECUTE_CMD, execute_spawn_items_command)