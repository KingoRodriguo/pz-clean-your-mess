-- DB
---------------------------------------------
local DB_GENERAL_ENABLED = false

-- File DB mode
---------------------------------------------
local DB_BUILDING_ENABLED = false
local DB_CELL_ENABLED = false
local DB_CLEANER_ENABLED = false
local DB_DEBUG_ENABLED = false

-- Local data
---------------------------------------------
local DB_HIGHLIGHT = false
local DB_HIGHLIGHT_CELLS = {}

local DB = {}

-- DB function
---------------------------------------------

function DB_GetDBMode(className)
    if className == "Building" then
        return DB_BUILDING_ENABLED
    elseif className == "Cell" then
        return DB_CELL_ENABLED
    elseif className == "Cleaner" then
        return DB_CLEANER_ENABLED
    else
        return DB_GENERAL_ENABLED
    end
end

function DB_Log(text, type)
    local s = ""
    if type == "Error" then s = "ERROR| CYM_DB_ " end
    if type == "Warning" then s = "WARNING| CYM_DB_ " end
    if type == "Info" then s = "INFO| CYM_DB_ " end

    if DB_GENERAL_ENABLED then
        print(s.. "" .. text)
    end
end

function DB_GetRandomItem()
    local RandItems = {
        "Base.Torch",
        "Base.Candle",
        "Base.Book",
        "Base.Knife",
        "Base.BottleEmpty",
        "Base.WaterBottleFull",
        "Base.Bandage",
        "Base.Soup",
        "Base.CannedBeans",
        "Base.CannedCornedBeef",
        "Base.CannedChili",
        "Base.CannedSoup",
        "Base.CannedBolognese",
        "Base.CannedCarrots",
        "Base.CannedCorn",
        "Base.CannedMushroomSoup",
        "Base.CannedPeas",
        "Base.CannedSardines",
        "Base.CannedTomato",
    }
    local s = RandItems[ZombRandBetween(1, #RandItems)]
end

function DB_GetHighLightCells()
    return DB_HIGHLIGHT_CELLS
end

function DB_AddHighLightCell(cell)
    if not cell then return end
    if DB_HIGHLIGHT then DB_Log("Adding Cell to HighLight", "Info") end
    table.insert(DB_HIGHLIGHT_CELLS, cell)
end

function DB_ToggleHighlight()
    DB_HIGHLIGHT = not DB_HIGHLIGHT
end

-- Local functions
---------------------------------------------

local function RenderHighLights()
    if not DB_HIGHLIGHT then return end

    local cells = DB_GetHighLightCells()

    for _, cell in ipairs(cells) do
        local r,g,b = 1,1,1
        local floorSprite = IsoSprite.new()
        floorSprite:LoadFramesNoDirPageSimple("media/ui/FloorHighlight.png")
        floorSprite:RenderGhostTileColor(cell.x, cell.y, cell.z, r, g, b, 0.5)
    end
end

-- Events
---------------------------------------------

Events.OnPostRender.Add(RenderHighLights)