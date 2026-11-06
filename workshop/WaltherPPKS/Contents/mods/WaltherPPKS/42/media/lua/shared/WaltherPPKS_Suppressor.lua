-- Walther PPK/S suppressor: sound radius 20 while WaltherPPKS.PPKSSuppressor is attached, 70 otherwise.
--
-- Vanilla weapon parts can't change noise, so the radius is set here. HandWeapon does not save its
-- sound radius (it resets to the script value, 70, on load), so it is reapplied:
--   * after the vanilla attach / detach timed actions complete (server side in multiplayer),
--   * when the gun is equipped,
--   * at game start, for guns already in the player's inventory,
--   * every player update, for the gun in hand (in multiplayer complete() runs on the server, so the
--     client's copy only learns about the part through the sync; OnWeaponSwing fires after the noise).
-- Shared: the client fires the shot noise (IsoLivingCharacter.DoAttack), the server runs complete().

require "TimedActions/ISUpgradeWeapon"
require "TimedActions/ISRemoveWeaponUpgrade"

WaltherPPKS = WaltherPPKS or {}

local GUN = "WaltherPPKS.PPKS"
local SUPPRESSOR = "WaltherPPKS.PPKSSuppressor"
local RADIUS_SUPPRESSED = 20
local RADIUS_NORMAL = 70

local S = WaltherPPKS.Suppressor or {}   -- kept across a Lua reload so the wrappers never stack
WaltherPPKS.Suppressor = S

-- The one radius rule. Returns the radius set, or nil when the item isn't a PPK/S.
function S.apply(item)
    if not item or not instanceof(item, "HandWeapon") or item:getFullType() ~= GUN then return nil end
    local part = item:getWeaponPart("Canon")
    local radius = (part and part:getFullType() == SUPPRESSOR) and RADIUS_SUPPRESSED or RADIUS_NORMAL
    if item:getSoundRadius() ~= radius then
        item:setSoundRadius(radius)
    end
    return radius
end

-- Vanilla complete() functions, kept so the wrappers call through them.
S.orig = S.orig or {
    upgrade = ISUpgradeWeapon.complete,
    remove = ISRemoveWeaponUpgrade.complete,
}

function ISUpgradeWeapon:complete()
    local result = S.orig.upgrade(self)
    S.apply(self.weapon)
    return result
end

function ISRemoveWeaponUpgrade:complete()
    local result = S.orig.remove(self)
    S.apply(self.weapon)
    return result
end

function S.onEquip(character, item)
    S.apply(item)
end

-- Every PPK/S in a container, including bags inside it.
function S.applyAll(container)
    if not container then return end
    local items = container:getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if not S.apply(item) and instanceof(item, "InventoryContainer") then
            S.applyAll(item:getInventory())
        end
    end
end

function S.onGameStart()
    for i = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(i)
        if player then
            S.applyAll(player:getInventory())
            S.apply(player:getPrimaryHandItem())
        end
    end
end

function S.onPlayerUpdate(player)
    if player then S.apply(player:getPrimaryHandItem()) end
end

if not S.eventsAdded then
    S.eventsAdded = true
    Events.OnEquipPrimary.Add(function(character, item) S.onEquip(character, item) end)
    Events.OnGameStart.Add(function() S.onGameStart() end)
    Events.OnPlayerUpdate.Add(function(player) S.onPlayerUpdate(player) end)
end
