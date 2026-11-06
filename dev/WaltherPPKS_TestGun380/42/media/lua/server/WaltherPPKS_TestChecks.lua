-- DEV ONLY: automatic checks, printed as "[WaltherPPKS-TEST] ...".
local TAG = "[WaltherPPKS-TEST] "
local fails, passes = 0, 0

local function check(ok, msg)
    if ok then
        passes = passes + 1
    else
        fails = fails + 1
        print(TAG .. "FAIL " .. msg)
    end
end

-- run fn, record a failure (not a crash) if it raises
local function try(label, fn)
    local ok, err = pcall(fn)
    if not ok then check(false, label .. " raised: " .. tostring(err)) end
end

local PAIRS = {
    Pistol = { "WaltherPPKS.PPKS", 0.75 },
    Bullets9mm = { "WaltherPPKS.Bullets380", 0.5 },
    Bullets9mmBox = { "WaltherPPKS.Bullets380Box", 0.5 },
    ["9mmClip"] = { "WaltherPPKS.PPKSClip", 0.5 },
}
local DENY = { "police", "army", "military", "swat", "security", "prisonguard", "sheriff", "outfit_",
               "inventorymale", "inventoryfemale" }

local function deniedKey(k)
    if type(k) ~= "string" then return false end
    k = k:lower()
    for _, t in ipairs(DENY) do
        if k:find(t, 1, true) then return true end
    end
    return false
end

local SUPPRESSOR = "WaltherPPKS.PPKSSuppressor"

local function short(name)
    return (name:gsub("^Base%.", ""))
end

-- Independently re-derive which item lists are reachable from a denied path, then check every list.
local lootChecked = false
local function checkLoot()
    -- handlers on the same event have no guaranteed order: make sure injection ran (it is idempotent)
    if WaltherPPKS and WaltherPPKS.injectLoot then WaltherPPKS.injectLoot() end
    local roots = {
        { "ProceduralDistributions.list", ProceduralDistributions and ProceduralDistributions.list },
        { "Distributions", Distributions },
        { "BagsAndContainers", BagsAndContainers },
        { "VehicleDistributions", VehicleDistributions },
        { "ClutterTables", ClutterTables },
    }
    local info, seen = {}, {}
    local function walk(t, path, denied)
        local key = denied and 2 or 1
        seen[t] = seen[t] or {}
        if seen[t][key] then return end
        seen[t][key] = true
        for k, v in pairs(t) do
            if type(v) == "table" then
                local p = path .. "." .. tostring(k)
                local d = denied or deniedKey(k)
                if k == "items" then
                    local e = info[v] or { path = p, denied = false }
                    e.denied = e.denied or d
                    info[v] = e
                end
                walk(v, p, d)
            end
        end
    end
    for _, r in ipairs(roots) do
        if r[2] then walk(r[2], r[1], false) end
    end

    local civilianLists, deniedLists, ppk, rounds = 0, 0, 0, 0
    local suppressorsByList, suppressorTotal = {}, 0
    for items, e in pairs(info) do
        local entries, has9 = {}, false
        for i = 1, #items - 1, 2 do
            local name, chance = items[i], items[i + 1]
            if name == SUPPRESSOR then
                suppressorTotal = suppressorTotal + 1
                suppressorsByList[items] = suppressorsByList[items] or {}
                table.insert(suppressorsByList[items], chance)
            elseif type(name) == "string" then
                entries[#entries + 1] = { name, chance }
                if PAIRS[short(name)] then has9 = true end
            end
        end
        if e.denied then
            for _, en in ipairs(entries) do
                check(not en[1]:find("^WaltherPPKS"), "denied list has " .. en[1] .. ": " .. e.path)
            end
            if has9 then deniedLists = deniedLists + 1 end
        else
            local want, have = {}, {}
            for _, en in ipairs(entries) do
                local p = PAIRS[short(en[1])]
                if p and type(en[2]) == "number" then
                    local k = p[1] .. "@" .. string.format("%.5f", en[2] * p[2])
                    want[k] = (want[k] or 0) + 1
                end
                if en[1]:find("^WaltherPPKS%.") and type(en[2]) == "number" then
                    local k = en[1] .. "@" .. string.format("%.5f", en[2])
                    have[k] = (have[k] or 0) + 1
                    if en[1] == "WaltherPPKS.PPKS" then ppk = ppk + 1 else rounds = rounds + 1 end
                end
            end
            if has9 then civilianLists = civilianLists + 1 end
            for k, n in pairs(want) do
                check(have[k] == n, "expected " .. n .. "x " .. k .. " (found " .. tostring(have[k]) .. "): " .. e.path)
            end
            for k, n in pairs(have) do
                check(want[k] == n, "unexpected " .. n .. "x " .. k .. ": " .. e.path)
            end
        end
    end
    -- Matrix row "Loot": the suppressor is in exactly the 8 procedural lists, once each, at the fixed weights.
    local lists = ProceduralDistributions and ProceduralDistributions.list or {}
    local SUPPRESSOR_LOOT = WaltherPPKS and WaltherPPKS.SUPPRESSOR_LOOT or {}
    local expected = 0
    for name, weight in pairs(SUPPRESSOR_LOOT) do
        expected = expected + 1
        local list = lists[name]
        local found = list and suppressorsByList[list.items]
        check(found ~= nil and #found == 1 and found[1] == weight,
              "suppressor in " .. name .. ": expected 1x at " .. weight .. ", found " ..
              (found and (#found .. "x, first " .. tostring(found[1])) or "none"))
    end
    check(expected == 8, "WaltherPPKS.SUPPRESSOR_LOOT should name 8 lists, names " .. expected)
    check(suppressorTotal == expected, "suppressor loot entries: expected " .. expected .. ", found " .. suppressorTotal)
    print(TAG .. "loot: " .. suppressorTotal .. " suppressor entries")

    lootChecked = true
    check(civilianLists > 0, "no civilian list with M9/9mm found")
    check(ppk > 0, "no PPK/S loot entry found")
    check(deniedLists > 0, "no police/military/zombie list with M9/9mm found")
    print(TAG .. "loot: " .. civilianLists .. " civilian lists with M9/9mm checked, " .. deniedLists ..
          " police/military/zombie lists with M9/9mm checked, " .. ppk .. " PPK/S entries, " ..
          rounds .. " .380 entries")
end

local function near(a, b)
    return type(a) == "number" and math.abs(a - b) < 0.0005
end

local scriptsChecked = false
local function checkScripts()
    if scriptsChecked then return end
    scriptsChecked = true
    local sm = getScriptManager()
    for _, id in ipairs({ "WaltherPPKS.PPKS", "WaltherPPKS.PPKSClip", "WaltherPPKS.Bullets380",
                          "WaltherPPKS.Bullets380Box", SUPPRESSOR, "WaltherPPKS_TestGun380.TestGun380" }) do
        try("FindItem " .. id, function() check(sm:FindItem(id) ~= nil, "missing script item " .. id) end)
    end
    for _, r in ipairs({ "WaltherPPKS_OpenBoxOfBullets380", "WaltherPPKS_PackBullets380" }) do
        try("getCraftRecipe " .. r, function() check(sm:getCraftRecipe(r) ~= nil, "missing craftRecipe " .. r) end)
    end
    -- Matrix rows "Open box" / "Pack box": 1 box -> 50 rounds, 50 rounds -> 1 box.
    local function io(recipeName)
        local r = sm:getCraftRecipe(recipeName)
        local ins, outs = r:getInputs(), r:getOutputs()
        check(ins:size() == 1 and outs:size() == 1, recipeName .. " should have exactly 1 input and 1 output")
        local inp, out = ins:get(0), outs:get(0)
        -- Item lists are resolved lazily, so match the declared line: exactly one item, by full ID.
        local function only(line, id)
            line = tostring(line)
            local ids = {}
            for w in line:gmatch("WaltherPPKS%.[%w_]+") do ids[#ids + 1] = w end
            return #ids == 1 and ids[1] == id
        end
        print(TAG .. recipeName .. ": " .. inp:getIntAmount() .. "x [" .. tostring(inp:getOriginalLine()) ..
              "] -> " .. out:getIntAmount() .. "x [" .. tostring(out:getOriginalLine()) .. "]")
        return inp:getIntAmount(), inp:getOriginalLine(), out:getIntAmount(), out:getOriginalLine(), only
    end
    try("open recipe io", function()
        local ia, il, oa, ol, only = io("WaltherPPKS_OpenBoxOfBullets380")
        check(ia == 1 and only(il, "WaltherPPKS.Bullets380Box"), "open: input should be 1 box")
        check(oa == 50 and only(ol, "WaltherPPKS.Bullets380"), "open: output should be 50 rounds")
    end)
    try("pack recipe io", function()
        local ia, il, oa, ol, only = io("WaltherPPKS_PackBullets380")
        check(ia == 50 and only(il, "WaltherPPKS.Bullets380"), "pack: input should be 50 rounds")
        check(oa == 1 and only(ol, "WaltherPPKS.Bullets380Box"), "pack: output should be 1 box")
    end)
    try("box DoubleClickRecipe", function()
        local box = instanceItem("WaltherPPKS.Bullets380Box")
        local dc = box:getDoubleClickRecipe()
        check(dc ~= nil and sm:getCraftRecipe(dc) ~= nil, "box double-click recipe does not resolve: " .. tostring(dc))
        check(near(box:getScriptItem():getActualWeight(), 0.6), "box weight " .. tostring(box:getScriptItem():getActualWeight()))
    end)
    try("round", function()
        local r = instanceItem("WaltherPPKS.Bullets380")
        check(near(r:getScriptItem():getActualWeight(), 0.02), "round weight " .. tostring(r:getScriptItem():getActualWeight()))
    end)
    try("gun", function()
        local gun = instanceItem("WaltherPPKS.PPKS")
        check(gun:getMaxAmmo() == 7, "PPKS MaxAmmo " .. tostring(gun:getMaxAmmo()))
        check(gun:getMagazineType() == "WaltherPPKS.PPKSClip", "PPKS magazine " .. tostring(gun:getMagazineType()))
        check(near(gun:getActualWeight(), 1.0), "PPKS weight " .. tostring(gun:getActualWeight()))
        check(near(gun:getSoundRadius(), 70), "PPKS sound radius " .. tostring(gun:getSoundRadius()))
        check(near(gun:getMaxRange(), 10), "PPKS range " .. tostring(gun:getMaxRange()))
        check(near(gun:getMinDamage(), 0.6) and near(gun:getMaxDamage(), 1.0),
              "PPKS damage " .. tostring(gun:getMinDamage()) .. "-" .. tostring(gun:getMaxDamage()))
    end)
    try("magazine", function()
        local mag = instanceItem("WaltherPPKS.PPKSClip")
        check(mag:getMaxAmmo() == 7, "magazine MaxAmmo " .. tostring(mag:getMaxAmmo()))
    end)
    try("ammo type", function()
        local gun = instanceItem("WaltherPPKS.PPKS")
        local test = instanceItem("WaltherPPKS_TestGun380.TestGun380")
        local mag = instanceItem("WaltherPPKS.PPKSClip")
        local a, b, c = tostring(gun:getAmmoType()), tostring(test:getAmmoType()), tostring(mag:getAmmoType())
        print(TAG .. "ammo types: PPKS=" .. a .. " magazine=" .. c .. " test gun=" .. b)
        check(a == b and a == c and a ~= "nil", "ammo types differ")
        check(a:find("bullets_380", 1, true) ~= nil or a:find("Bullets380", 1, true) ~= nil, "ammo type not .380: " .. a)
    end)
end

local function checkNames()
    try("names", function()
        local gun = instanceItem("WaltherPPKS.PPKS")
        local m9 = instanceItem("Base.Pistol"):getDisplayName()
        print(TAG .. "names: M9=" .. tostring(m9) .. " PPKS=" .. tostring(gun:getDisplayName()) ..
              " test=" .. tostring(instanceItem("WaltherPPKS_TestGun380.TestGun380"):getDisplayName()) ..
              " box=" .. tostring(instanceItem("WaltherPPKS.Bullets380Box"):getDisplayName()) ..
              " xlat=" .. tostring(getItemNameFromFullType and getItemNameFromFullType("WaltherPPKS.PPKS")))
        -- A dedicated server loads mod translations before mods are active, so no mod item is named
        -- there (the dev gun's own name is the control). Names are then checked in game instead.
        local control = instanceItem("WaltherPPKS_TestGun380.TestGun380"):getDisplayName()
        if control == "WaltherPPKS_TestGun380.TestGun380" then
            print(TAG .. "SKIP display names: this process has no mod translations loaded (control: " .. control .. ")")
        else
            check(gun:getDisplayName() == "Walther PPK/S", "PPKS display name " .. tostring(gun:getDisplayName()))
            check(instanceItem("WaltherPPKS.Bullets380Box"):getDisplayName() == "Box of .380 ACP Rounds", "box display name")
            check(instanceItem(SUPPRESSOR):getDisplayName() == "Walther PPK/S Suppressor", "suppressor display name")
            check(getText("Tooltip_WaltherPPKS_Suppressor") ~= "Tooltip_WaltherPPKS_Suppressor", "suppressor tooltip not translated")
        end
    end)
end

-- OnFillContainer guarantee: every PPK/S in a filled container (and in bags inside it) holds a magazine.
local function checkMagazineGuarantee()
    try("magazine guarantee", function()
        local outer = instanceItem("Base.Bag_DuffelBag")
        local inner = instanceItem("Base.Bag_Satchel")
        local inv = outer:getInventory()
        local g1 = instanceItem("WaltherPPKS.PPKS")
        local g2 = instanceItem("WaltherPPKS.PPKS")
        local m9 = instanceItem("Base.Pistol")
        g1:setContainsClip(false); g2:setContainsClip(false); m9:setContainsClip(false)
        inv:AddItem(g1); inv:AddItem(m9)
        inner:getInventory():AddItem(g2)
        inv:AddItem(inner)
        triggerEvent("OnFillContainer", "bedroom", "wardrobe", inv)
        check(g1:isContainsClip(), "PPK/S in container got no magazine")
        check(g2:isContainsClip(), "PPK/S in nested bag got no magazine")
        check(not m9:isContainsClip(), "M9 was changed by the PPK/S magazine guarantee")
    end)
end

-- Police/military containers that roll civilian lists: mod items are stripped after fill.
local function checkDeniedContainerStrip()
    try("denied container strip", function()
        local inv = instanceItem("Base.Bag_DuffelBag"):getInventory()
        local gun = instanceItem("WaltherPPKS.PPKS")
        local box = instanceItem("WaltherPPKS.Bullets380Box")
        local m9 = instanceItem("Base.Pistol")
        inv:AddItem(gun); inv:AddItem(box); inv:AddItem(m9)
        -- Vanilla fires OnFillContainer for bags with a loot-table object, not a container
        -- ("Container", <bag type>, ItemPickerContainer). The handler must ignore it, not throw.
        local ok, err = pcall(WaltherPPKS.onFillContainer, "Container", "Bag_DuffelBag", instanceItem("Base.Pistol"))
        check(ok, "handler threw on non-container argument: " .. tostring(err))
        local ok2, err2 = pcall(WaltherPPKS.onFillContainer, "Container", "Bag_DuffelBag", nil)
        check(ok2, "handler threw on nil container: " .. tostring(err2))
        triggerEvent("OnFillContainer", "gunstore", "militarylocker", inv)
        check(not inv:contains(gun), "PPK/S left in militarylocker")
        check(not inv:contains(box), "Bullets380Box left in militarylocker")
        check(inv:contains(m9), "M9 removed from militarylocker")
    end)
end

-- Suppressor (CAP-10, CAP-11): part definition, M9 rejection, attach/detach radius, reload reapply.
local function checkSuppressor()
    local S = WaltherPPKS and WaltherPPKS.Suppressor
    check(S ~= nil and S.apply ~= nil, "WaltherPPKS.Suppressor not loaded")
    if not S then return end
    try("suppressor part", function()
        local part = instanceItem(SUPPRESSOR)
        check(instanceof(part, "WeaponPart"), "suppressor is not a WeaponPart")
        check(part:getPartType() == "Canon", "suppressor part type " .. tostring(part:getPartType()))
        local mounts = part:getMountOn()
        check(mounts:size() == 1 and mounts:get(0) == "WaltherPPKS.PPKS", "suppressor MountOn " .. tostring(mounts))
        check(near(part:getScriptItem():getActualWeight(), 0.3), "suppressor weight " .. tostring(part:getScriptItem():getActualWeight()))
        check(near(part:getWeightModifier(), 0.3), "suppressor weight modifier " .. tostring(part:getWeightModifier()))
        local gun, m9 = instanceItem("WaltherPPKS.PPKS"), instanceItem("Base.Pistol")
        check(part:canAttach(nil, gun), "suppressor cannot attach to the PPK/S")
        check(part:canDetach(nil, gun), "suppressor cannot detach from the PPK/S")
        -- Matrix row "Other gun": the vanilla menu only offers parts whose canAttach is true.
        check(not part:canAttach(nil, m9), "suppressor can attach to the M9")
        check(not part:canAttach(nil, instanceItem("Base.Revolver")), "suppressor can attach to the revolver")
    end)
    try("attach/detach radius", function()
        local gun, part = instanceItem("WaltherPPKS.PPKS"), instanceItem(SUPPRESSOR)
        check(S.apply(gun) == 70 and gun:getSoundRadius() == 70, "bare PPK/S radius " .. gun:getSoundRadius())
        gun:attachWeaponPart(part)
        check(gun:getWeaponPart("Canon") ~= nil, "suppressor not attached")
        check(S.apply(gun) == 10 and gun:getSoundRadius() == 10, "suppressed radius " .. gun:getSoundRadius())
        gun:detachWeaponPart(part)
        check(gun:getWeaponPart("Canon") == nil, "suppressor not detached")
        check(S.apply(gun) == 70 and gun:getSoundRadius() == 70, "detached radius " .. gun:getSoundRadius())
        local m9 = instanceItem("Base.Pistol")
        check(S.apply(m9) == nil and m9:getSoundRadius() == 100, "radius rule touched the M9: " .. m9:getSoundRadius())
    end)
    -- Polish pass: suppressed shot sound swaps with the part, like the radius.
    try("attach/detach shot sound", function()
        local gun, part = instanceItem("WaltherPPKS.PPKS"), instanceItem(SUPPRESSOR)
        check(gun:getSwingSound() == "M9Shoot", "script shot sound " .. tostring(gun:getSwingSound()))
        check(S.SOUND_NORMAL == "M9Shoot", "normal shot sound constant " .. tostring(S.SOUND_NORMAL))
        S.apply(gun)
        check(gun:getSwingSound() == "M9Shoot", "bare PPK/S shot sound " .. tostring(gun:getSwingSound()))
        gun:attachWeaponPart(part)
        S.apply(gun)
        check(gun:getSwingSound() == "WaltherPPKS_ShootSuppressed", "suppressed shot sound " .. tostring(gun:getSwingSound()))
        gun:detachWeaponPart(part)
        S.apply(gun)
        check(gun:getSwingSound() == "M9Shoot", "detached shot sound " .. tostring(gun:getSwingSound()))
        local m9 = instanceItem("Base.Pistol")
        m9:attachWeaponPart(instanceItem(SUPPRESSOR))   -- forced; the menu never offers this
        S.apply(m9)
        check(m9:getSwingSound() == "M9Shoot", "sound rule touched the M9: " .. tostring(m9:getSwingSound()))
        local snd = getScriptManager():getGameSound("WaltherPPKS_ShootSuppressed")
        check(snd ~= nil, "sound script WaltherPPKS_ShootSuppressed missing")
        -- GameSoundScript/GameSoundClip methods aren't exposed to Lua in 42.21; check the file when they are.
        local okClip, file = pcall(function() return snd:getRandomClip():getFile() end)
        if snd and okClip then
            check(file == "media/sound/suppressed_pistol_shot.ogg", "suppressed clip file " .. tostring(file))
        elseif snd then
            print(TAG .. "SKIP suppressed clip file: sound clip API not exposed to Lua")
        end
    end)
    -- Polish pass: the dropped suppressor lies flat (world point turned 90 degrees about Z).
    try("suppressor ground pose", function()
        local ms = getScriptManager():getModelScript("WaltherPPKS.PPKSSuppressor_Ground")
        check(ms ~= nil, "ground model script missing")
        local w = ms and ms:getAttachmentById("world")
        check(w ~= nil, "ground model has no world attachment")
        if w then
            local r, o = w:getRotate(), w:getOffset()
            check(near(r:x(), 0) and near(r:y(), 0) and near(r:z(), 90),
                  "ground rotate " .. r:x() .. " " .. r:y() .. " " .. r:z())
            check(near(o:x(), 0.0088) and near(o:y(), 0.0514) and near(o:z(), 0),
                  "ground offset " .. o:x() .. " " .. o:y() .. " " .. o:z())
        end
    end)
    -- The vanilla attach/detach actions' complete() is wrapped. The original needs a real player, so it is
    -- replaced by a stub for this check; only the wrapper's reapply is exercised.
    try("timed action wrappers", function()
        check(type(S.orig.upgrade) == "function", "vanilla ISUpgradeWeapon.complete not captured")
        check(type(S.orig.remove) == "function", "vanilla ISRemoveWeaponUpgrade.complete not captured")
        check(ISUpgradeWeapon.complete ~= S.orig.upgrade, "ISUpgradeWeapon.complete not wrapped")
        check(ISRemoveWeaponUpgrade.complete ~= S.orig.remove, "ISRemoveWeaponUpgrade.complete not wrapped")
        local savedUp, savedRm = S.orig.upgrade, S.orig.remove
        local gun, part = instanceItem("WaltherPPKS.PPKS"), instanceItem(SUPPRESSOR)
        -- the wrappers read self.weapon: make sure the vanilla constructors still set it
        local okUp, up = pcall(ISUpgradeWeapon.new, ISUpgradeWeapon, nil, gun, part)
        if okUp then
            check(up.weapon == gun, "ISUpgradeWeapon:new did not set .weapon")
        else
            print(TAG .. "SKIP ISUpgradeWeapon:new needs a real character: " .. tostring(up))
        end
        local okRm, rm = pcall(ISRemoveWeaponUpgrade.new, ISRemoveWeaponUpgrade, nil, gun, "Canon")
        if okRm then
            check(rm.weapon == gun, "ISRemoveWeaponUpgrade:new did not set .weapon")
        else
            print(TAG .. "SKIP ISRemoveWeaponUpgrade:new needs a real character: " .. tostring(rm))
        end
        local ok, err = pcall(function()
            S.orig.upgrade = function(self) self.weapon:attachWeaponPart(self.part); return true end
            S.orig.remove = function(self) self.weapon:detachWeaponPart(self.weapon:getWeaponPart(self.partType)); return true end
            ISUpgradeWeapon.complete({ weapon = gun, part = part })
            check(gun:getSoundRadius() == 10, "radius after attach action " .. gun:getSoundRadius())
            ISRemoveWeaponUpgrade.complete({ weapon = gun, partType = "Canon" })
            check(gun:getSoundRadius() == 70, "radius after detach action " .. gun:getSoundRadius())
        end)
        S.orig.upgrade, S.orig.remove = savedUp, savedRm
        check(ok, "wrapper raised: " .. tostring(err))
    end)
    -- Bug fix: detaching the suppressor plays an animation and rebuilds the held gun's model.
    try("detach animation and model refresh", function()
        check(ISRemoveWeaponUpgrade.start ~= S.orig.removeStart, "ISRemoveWeaponUpgrade.start not wrapped")
        check(ISRemoveWeaponUpgrade.perform ~= S.orig.removePerform, "ISRemoveWeaponUpgrade.perform not wrapped")
        local function stubAction(weapon)
            local a = { weapon = weapon, partType = "Canon", anim = nil, hands = nil }
            function a:setActionAnim(name) self.anim = name end
            function a:setOverrideHandModels(p, s) self.hands = { p, s } end
            return a
        end
        local gun, part = instanceItem("WaltherPPKS.PPKS"), instanceItem(SUPPRESSOR)
        gun:attachWeaponPart(part)
        local a = stubAction(gun)
        ISRemoveWeaponUpgrade.start(a)
        check(a.anim == "Craft", "detach anim " .. tostring(a.anim))
        check(a.hands and a.hands[1] == gun and a.hands[2] == part, "detach hand models not set")
        -- another gun's part: no animation added (vanilla behaviour kept)
        local m9 = instanceItem("Base.Pistol")
        local b = stubAction(m9)
        ISRemoveWeaponUpgrade.start(b)
        check(b.anim == nil, "detach anim added to a non-PPK/S gun")
        -- perform() rebuilds the hand models on a client
        local resets = 0
        local chr = { resetEquippedHandsModels = function() resets = resets + 1 end }
        local savedPerform, savedHas = S.orig.removePerform, S.hasHandModels
        local ok, err = pcall(function()
            S.orig.removePerform = function() end
            S.hasHandModels = function() return true end
            ISRemoveWeaponUpgrade.perform({ weapon = gun, character = chr })
            check(resets == 1, "perform reset count " .. resets)
            ISRemoveWeaponUpgrade.perform({ weapon = m9, character = chr })
            check(resets == 1, "perform reset models for a non-PPK/S gun")
            -- player update: the held gun's suppressor state changes (multiplayer sync) -> one reset
            local held = instanceItem("WaltherPPKS.PPKS")
            held:attachWeaponPart(instanceItem(SUPPRESSOR))
            local pr = 0
            local player = { getPrimaryHandItem = function() return held end, getPlayerNum = function() return 9 end,
                             resetEquippedHandsModels = function() pr = pr + 1 end }
            S.onPlayerUpdate(player)
            S.onPlayerUpdate(player)
            check(pr == 0, "player update reset models without a change: " .. pr)
            held:detachWeaponPart(held:getWeaponPart("Canon"))
            S.onPlayerUpdate(player)
            check(pr == 1, "player update reset count after detach " .. pr)
            check(held:getSoundRadius() == 70, "radius after synced detach " .. held:getSoundRadius())
            check(held:getSwingSound() == "M9Shoot", "sound after synced detach " .. tostring(held:getSwingSound()))
            S.onPlayerUpdate(player)
            check(pr == 1, "player update reset models twice for one detach")
        end)
        S.orig.removePerform, S.hasHandModels = savedPerform, savedHas
        S.handState[9] = nil
        check(ok, "detach fix raised: " .. tostring(err))
        check(S.hasHandModels() == false, "dedicated server reports hand models")
    end)
    -- Matrix row "Save/reload": the radius is not saved, so a loaded gun has 70 until reapplied.
    try("reload reapply", function()
        local gun, part = instanceItem("WaltherPPKS.PPKS"), instanceItem(SUPPRESSOR)
        gun:attachWeaponPart(part)
        S.apply(gun)
        gun:setSoundRadius(70)   -- what loading does
        triggerEvent("OnEquipPrimary", nil, gun)
        check(gun:getSoundRadius() == 10, "radius after equipping a loaded suppressed gun " .. gun:getSoundRadius())
        check(gun:getSwingSound() == "WaltherPPKS_ShootSuppressed", "sound after equipping a loaded suppressed gun")
        -- game-start bag walk: duffel bag > satchel > suppressed PPK/S
        local duffel, satchel = instanceItem("Base.Bag_DuffelBag"), instanceItem("Base.Bag_Satchel")
        local bagged = instanceItem("WaltherPPKS.PPKS")
        bagged:attachWeaponPart(instanceItem(SUPPRESSOR))
        bagged:setSoundRadius(70)
        satchel:getInventory():AddItem(bagged)
        duffel:getInventory():AddItem(satchel)
        S.applyAll(duffel:getInventory())
        check(bagged:getSoundRadius() == 10, "radius after bag walk " .. bagged:getSoundRadius())
        -- per-update path (multiplayer client): gun in hand, reset to 70
        local held = instanceItem("WaltherPPKS.PPKS")
        held:attachWeaponPart(instanceItem(SUPPRESSOR))
        held:setSoundRadius(70)
        check(S.onPlayerUpdate ~= nil, "S.onPlayerUpdate missing")
        S.onPlayerUpdate({ getPrimaryHandItem = function() return held end, getPlayerNum = function() return 7 end })
        check(held:getSoundRadius() == 10, "radius after player update " .. held:getSoundRadius())
        S.handState[7] = nil
        -- the dedicated server has no players: onGameStart must not throw
        local ok, err = pcall(S.onGameStart)
        check(ok, "onGameStart raised: " .. tostring(err))
    end)
    -- Matrix row "Military fill": a militarylocker rolling GarageFirearms loses the suppressor.
    try("suppressor military strip", function()
        local inv = instanceItem("Base.Bag_DuffelBag"):getInventory()
        local part, scope = instanceItem(SUPPRESSOR), instanceItem("Base.x8Scope")
        inv:AddItem(part); inv:AddItem(scope)
        triggerEvent("OnFillContainer", "gunstore", "militarylocker", inv)
        check(not inv:contains(part), "suppressor left in militarylocker")
        check(inv:contains(scope), "x8 scope removed from militarylocker")
        local civ = instanceItem("Base.Bag_DuffelBag"):getInventory()
        local part2 = instanceItem(SUPPRESSOR)
        civ:AddItem(part2)
        triggerEvent("OnFillContainer", "gunstore", "counter", civ)
        check(civ:contains(part2), "suppressor removed from a civilian gun store counter")
    end)
end

local resultDone = false
local function result()
    if resultDone then return end
    resultDone = true
    check(lootChecked, "loot check never ran")
    checkScripts()
    checkNames()
    checkMagazineGuarantee()
    checkDeniedContainerStrip()
    checkSuppressor()
    print(TAG .. "RESULT " .. (fails == 0 and "PASS" or "FAIL") .. " (" .. passes .. " passed, " .. fails .. " failed)")
end

Events.OnPostDistributionMerge.Add(checkLoot)
Events.OnGameBoot.Add(checkScripts)
Events.OnServerStarted.Add(result)
Events.OnGameStart.Add(result)
