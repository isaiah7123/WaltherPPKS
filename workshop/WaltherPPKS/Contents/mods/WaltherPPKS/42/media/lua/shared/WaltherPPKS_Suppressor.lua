-- Walther PPK/S suppressor: while WaltherPPKS.PPKSSuppressor is attached the sound radius is 10 and each
-- shot plays WaltherPPKS_ShootSuppressed; otherwise 70 and the vanilla M9Shoot.
--
-- Vanilla weapon parts can't change noise or the shot sound, so both are set here. HandWeapon does not
-- save its sound radius (it resets to the script value, 70, on load), so both are reapplied:
--   * after the vanilla attach / detach timed actions complete (server side in multiplayer),
--   * when the gun is equipped,
--   * at game start, for guns already in the player's inventory,
--   * every player update, for the gun in hand (in multiplayer complete() runs on the server, so the
--     client's copy only learns about the part through the sync; OnWeaponSwing fires after the noise).
-- Shared: the client fires the shot noise (IsoLivingCharacter.DoAttack), the server runs complete().
--
-- Detach fixes (PPK/S suppressor only; vanilla ISRemoveWeaponUpgrade has an empty start() and never
-- rebuilds the hand models):
--   * start() plays the "Craft" animation with the gun and suppressor in hand,
--   * perform() rebuilds the equipped hand models so the held gun loses the suppressor,
--   * OnPlayerUpdate also rebuilds them whenever the in-hand gun's suppressor state changes
--     (in multiplayer the part change reaches the client through a sync).

require "TimedActions/ISUpgradeWeapon"
require "TimedActions/ISRemoveWeaponUpgrade"

WaltherPPKS = WaltherPPKS or {}

local GUN = "WaltherPPKS.PPKS"
local SUPPRESSOR = "WaltherPPKS.PPKSSuppressor"
local RADIUS_SUPPRESSED = 10
local RADIUS_NORMAL = 70
local SOUND_SUPPRESSED = "WaltherPPKS_ShootSuppressed"
local SOUND_NORMAL = "M9Shoot"

local S = WaltherPPKS.Suppressor or {}   -- kept across a Lua reload so the wrappers never stack
WaltherPPKS.Suppressor = S

S.SOUND_SUPPRESSED, S.SOUND_NORMAL = SOUND_SUPPRESSED, SOUND_NORMAL

-- The one radius and shot-sound rule. Returns the radius set, or nil when the item isn't a PPK/S.
function S.apply(item)
    if not item or not instanceof(item, "HandWeapon") or item:getFullType() ~= GUN then return nil end
    local part = item:getWeaponPart("Canon")
    local suppressed = part ~= nil and part:getFullType() == SUPPRESSOR
    local radius = suppressed and RADIUS_SUPPRESSED or RADIUS_NORMAL
    local sound = suppressed and SOUND_SUPPRESSED or SOUND_NORMAL
    if item:getSoundRadius() ~= radius then
        item:setSoundRadius(radius)
    end
    if item:getSwingSound() ~= sound then
        item:setSwingSound(sound)
    end
    return radius
end

-- Hand models only exist on a client (or single player); the dedicated server has none.
function S.hasHandModels()
    return not isServer()
end

-- Is this action removing the suppressor from a PPK/S?
local function isSuppressorDetach(action)
    local weapon = action.weapon
    if not weapon or not instanceof(weapon, "HandWeapon") or weapon:getFullType() ~= GUN then return false end
    local part = weapon:getWeaponPart(action.partType or "Canon")
    return part ~= nil and part:getFullType() == SUPPRESSOR, part
end

-- Vanilla functions, kept so the wrappers call through them.
S.orig = S.orig or {
    upgrade = ISUpgradeWeapon.complete,
    remove = ISRemoveWeaponUpgrade.complete,
}
S.orig.removeStart = S.orig.removeStart or ISRemoveWeaponUpgrade.start
S.orig.removePerform = S.orig.removePerform or ISRemoveWeaponUpgrade.perform

function ISRemoveWeaponUpgrade:start()
    S.orig.removeStart(self)
    local ok, part = isSuppressorDetach(self)
    if ok then
        self:setActionAnim("Craft")
        self:setOverrideHandModels(self.weapon, part)
    end
end

function ISRemoveWeaponUpgrade:perform()
    local isPPKS = self.weapon and self.weapon:getFullType() == GUN
    S.orig.removePerform(self)
    if isPPKS and self.character and S.hasHandModels() then
        self.character:resetEquippedHandsModels()
    end
end

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

-- Last seen suppressor state of the gun in each player's hand: { id = item ID, radius = radius }.
S.handState = S.handState or {}

function S.onPlayerUpdate(player)
    if not player then return end
    local item = player:getPrimaryHandItem()
    local radius = S.apply(item)
    local key = player:getPlayerNum() or 0
    local last = S.handState[key]
    if radius then
        local id = item:getID()
        if last and last.id == id and last.radius ~= radius and S.hasHandModels() then
            player:resetEquippedHandsModels()
        end
        S.handState[key] = { id = id, radius = radius }
    elseif last then
        S.handState[key] = nil
    end
end

if not S.eventsAdded then
    S.eventsAdded = true
    Events.OnEquipPrimary.Add(function(character, item) S.onEquip(character, item) end)
    Events.OnGameStart.Add(function() S.onGameStart() end)
    Events.OnPlayerUpdate.Add(function(player) S.onPlayerUpdate(player) end)
end
