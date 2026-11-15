-- X-Wing United : chargement des données du squad builder depuis GitHub.
--
-- Les fichiers JSON sont téléchargés une seule fois par session (WebRequest),
-- puis indexés par identifiant. Les données ne sont jamais modifiées ni
-- renvoyées vers le dépôt.

local UnitedMapping = require("Game.Component.Spawner.United.UnitedMapping")

local UnitedData = {}

local cache = nil        -- données indexées une fois le chargement terminé
local loading = false
local waiting = {}       -- callbacks en attente pendant le téléchargement

local function normalizeName(name)
    return string.lower(tostring(name or "")):gsub("[^%w]", "")
end

-- Construit les index à partir des tableaux JSON décodés.
-- Exposé pour les tests hors TTS.
function UnitedData.index(raw)
    local data = {
        ships = {},
        shipsByName = {},
        shipsByNormName = {},
        pilots = {},
        upgrades = {},
        leaders = {},
        chassis = {},
    }
    for _, ship in ipairs(raw.ships or {}) do
        data.ships[ship.id] = ship
        data.shipsByName[ship.name] = ship
        data.shipsByNormName[normalizeName(ship.name)] = ship
    end
    for _, pilot in ipairs(raw.pilots or {}) do
        data.pilots[pilot.id] = pilot
    end
    for _, upgrade in ipairs(raw.upgrades or {}) do
        data.upgrades[upgrade.id] = upgrade
    end
    for _, leader in ipairs(raw.leaders or {}) do
        data.leaders[leader.leaderid] = leader
    end
    for _, chassis in ipairs(raw.chassis or {}) do
        data.chassis[chassis.id] = chassis
    end
    return data
end

-- Retrouve le vaisseau d'un pilote. Le champ "shipId" des pilotes n'est pas
-- toujours fiable, on se base donc d'abord sur le nom (comme le builder).
function UnitedData.shipForPilot(data, pilot)
    return data.shipsByName[pilot.ship]
        or data.shipsByNormName[normalizeName(pilot.ship)]
        or data.ships[pilot.shipId]
end

local function finish(err)
    loading = false
    local callbacks = waiting
    waiting = {}
    for _, callback in ipairs(callbacks) do
        callback(cache, err)
    end
end

-- Appelle callback(data, err) quand les données sont disponibles.
-- forceReload = true pour retélécharger (après une mise à jour du builder).
function UnitedData.load(callback, forceReload)
    if cache ~= nil and not forceReload then
        callback(cache, nil)
        return
    end
    table.insert(waiting, callback)
    if loading then
        return
    end
    loading = true

    local raw = {}
    local remaining = #UnitedMapping.DATA_FILES
    local failed = nil

    for _, name in ipairs(UnitedMapping.DATA_FILES) do
        local url = UnitedMapping.DATA_BASE_URL .. name .. ".json"
        WebRequest.get(url, function(request)
            if request.is_error then
                failed = failed or ("téléchargement impossible de " .. name .. ".json : " .. tostring(request.error))
            elseif request.is_done then
                local ok, decoded = pcall(JSON.decode, request.text)
                if ok and type(decoded) == "table" then
                    raw[name] = decoded
                else
                    failed = failed or ("fichier " .. name .. ".json illisible (JSON invalide ?)")
                end
            else
                return
            end
            remaining = remaining - 1
            if remaining == 0 then
                if failed then
                    finish(failed)
                else
                    cache = UnitedData.index(raw)
                    finish(nil)
                end
            end
        end)
    end
end

function UnitedData.isLoaded()
    return cache ~= nil
end

return UnitedData
