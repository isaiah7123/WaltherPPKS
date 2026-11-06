-- Walther PPK/S loot injection (data-driven, no hand-written list).
--
-- Every loot table that holds a vanilla M9 / 9mm entry gets the PPK/S / .380 counterpart:
--   Pistol        -> WaltherPPKS.PPKS           at 75% of the M9 chance
--   Bullets9mm    -> WaltherPPKS.Bullets380     at half the 9mm chance
--   Bullets9mmBox -> WaltherPPKS.Bullets380Box  at half
--   9mmClip       -> WaltherPPKS.PPKSClip       at half
-- (no carton counterpart).
--
-- Never added to police, military, SWAT, security, prison-guard or sheriff loot, nor to zombies:
-- a table is skipped when ANY path that reaches it matches the deny list. Vanilla shares tables
-- between containers (e.g. a pistol case used by both civilian and military cases), so a table
-- reachable from a denied container is left alone everywhere.
--
-- After a container is filled, every PPK/S in it is given a magazine (the vanilla picker only
-- inserts magazines at random).

WaltherPPKS = WaltherPPKS or {}

local SOURCES = {
    ["Pistol"]        = { target = "WaltherPPKS.PPKS",          factor = 0.75 },
    ["Bullets9mm"]    = { target = "WaltherPPKS.Bullets380",    factor = 0.5 },
    ["Bullets9mmBox"] = { target = "WaltherPPKS.Bullets380Box", factor = 0.5 },
    ["9mmClip"]       = { target = "WaltherPPKS.PPKSClip",      factor = 0.5 },
}

local DENY = { "police", "army", "military", "swat", "security", "prisonguard", "sheriff",
               "outfit_", "inventorymale", "inventoryfemale" }

local function sourceFor(name)
    if type(name) ~= "string" then return nil end
    local short = name:gsub("^Base%.", "")
    return SOURCES[short]
end

local function isDeniedKey(key)
    if type(key) ~= "string" then return false end
    local k = key:lower()
    for _, token in ipairs(DENY) do
        if k:find(token, 1, true) then return true end
    end
    return false
end

local function roots()
    local list = {}
    if ProceduralDistributions and ProceduralDistributions.list then
        table.insert(list, { "ProceduralDistributions.list", ProceduralDistributions.list })
    end
    if Distributions then table.insert(list, { "Distributions", Distributions }) end
    if SuburbsDistributions then table.insert(list, { "SuburbsDistributions", SuburbsDistributions }) end
    if BagsAndContainers then table.insert(list, { "BagsAndContainers", BagsAndContainers }) end
    if VehicleDistributions then table.insert(list, { "VehicleDistributions", VehicleDistributions }) end
    if ClutterTables then table.insert(list, { "ClutterTables", ClutterTables }) end
    return list
end

-- Pass 1: every table reachable through a denied key.
local function collectDenied()
    local denied, seen = {}, {}
    local function walk(t, isDenied)
        local state = isDenied and 2 or 1
        seen[t] = seen[t] or {}
        if seen[t][state] then return end
        seen[t][state] = true
        if isDenied then denied[t] = true end
        for k, v in pairs(t) do
            if type(v) == "table" then
                walk(v, isDenied or isDeniedKey(k))
            end
        end
    end
    for _, r in ipairs(roots()) do walk(r[2], false) end
    return denied
end

local function fmt(n)
    return string.format("%.4g", n)
end

function WaltherPPKS.injectLoot()
    if WaltherPPKS.lootInjected then return end
    WaltherPPKS.lootInjected = true

    local denied = collectDenied()
    local done, visited = {}, {}
    local added, skipped = 0, 0
    local dump = WaltherPPKS_DebugDump == true

    local function scanItems(items, path)
        if done[items] then return end
        done[items] = true
        local additions = {}
        for i = 1, #items - 1, 2 do
            local src = sourceFor(items[i])
            local chance = items[i + 1]
            if src and type(chance) == "number" then
                table.insert(additions, { src.target, chance * src.factor, items[i], chance })
            end
        end
        if #additions == 0 then return end
        if denied[items] then
            skipped = skipped + 1
            if dump then print("[WaltherPPKS] DENIED " .. path) end
            return
        end
        for _, a in ipairs(additions) do
            table.insert(items, a[1])
            table.insert(items, a[2])
            added = added + 1
            if dump then
                print("[WaltherPPKS] ADD " .. path .. " " .. a[1] .. " " .. fmt(a[2]) ..
                      " (from " .. a[3] .. " " .. fmt(a[4]) .. ")")
            end
        end
    end

    local function walk(t, path)
        if visited[t] then return end
        visited[t] = true
        for k, v in pairs(t) do
            if type(v) == "table" then
                local p = path .. "." .. tostring(k)
                if k == "items" then
                    scanItems(v, p)
                end
                walk(v, p)
            end
        end
    end

    for _, r in ipairs(roots()) do walk(r[2], r[1]) end
    print("[WaltherPPKS] loot injected: " .. added .. " entries; " .. skipped .. " police/military/zombie lists skipped")
end

Events.OnPostDistributionMerge.Add(WaltherPPKS.injectLoot)

-- Every looted PPK/S holds one magazine.
local function giveMagazines(container)
    if not container then return end
    local items = container:getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item:getFullType() == "WaltherPPKS.PPKS" then
            if not item:isContainsClip() then
                item:setContainsClip(true)
            end
        elseif instanceof(item, "InventoryContainer") then
            giveMagazines(item:getInventory())
        end
    end
end

-- Police/military containers can roll civilian-named procedural lists (e.g. a militarylocker in a gun
-- store uses GarageFirearms), so table-level denial is not enough: strip mod items from them after fill.
local function removeModItems(container)
    if not container then return end
    local items = container:getItems()
    for i = items:size() - 1, 0, -1 do
        local item = items:get(i)
        if item:getFullType():find("^WaltherPPKS%.") then
            container:Remove(item)
        elseif instanceof(item, "InventoryContainer") then
            removeModItems(item:getInventory())
        end
    end
end

function WaltherPPKS.onFillContainer(roomType, containerType, container)
    -- When vanilla rolls a bag inside a container it fires this event with its internal
    -- ItemPickerContainer (a loot table), not an ItemContainer. Skip those; the parent
    -- container's own event reaches the bag through the nested-bag walk.
    if not instanceof(container, "ItemContainer") then return end
    if isDeniedKey(roomType) or isDeniedKey(containerType) then
        removeModItems(container)
    else
        giveMagazines(container)
    end
end

Events.OnFillContainer.Add(WaltherPPKS.onFillContainer)
