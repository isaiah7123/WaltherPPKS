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
    for items, e in pairs(info) do
        local entries, has9 = {}, false
        for i = 1, #items - 1, 2 do
            local name, chance = items[i], items[i + 1]
            if type(name) == "string" then
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
                          "WaltherPPKS.Bullets380Box", "WaltherPPKS_TestGun380.TestGun380" }) do
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

local resultDone = false
local function result()
    if resultDone then return end
    resultDone = true
    check(lootChecked, "loot check never ran")
    checkScripts()
    checkNames()
    checkMagazineGuarantee()
    checkDeniedContainerStrip()
    print(TAG .. "RESULT " .. (fails == 0 and "PASS" or "FAIL") .. " (" .. passes .. " passed, " .. fails .. " failed)")
end

Events.OnPostDistributionMerge.Add(checkLoot)
Events.OnGameBoot.Add(checkScripts)
Events.OnServerStarted.Add(result)
Events.OnGameStart.Add(result)
