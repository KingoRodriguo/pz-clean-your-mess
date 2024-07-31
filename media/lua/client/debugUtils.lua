require "TileSorter"

local highlightCells = {}

--Debug oriented functions
--DONT USE IN RELEASE --

-- item list for random generation
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

local roomColors = {}

local DB_HIGHLIGHT = true
local DB_HIGHLIGHTMODE = "None"
-- Available Modes: CleanList, ContainerCells, AllCells, None

function DB_getRandItem()
    local s = RandItems[ZombRandBetween(1, #RandItems)]
    --print("Item: " ..s)
    return s
end

-- Fonction pour ajouter un GridSquare à la liste de surbrillance
function addHighlightCell(cell)
    if not cell then return end
    --print("Highlighting cell: " ..cell.x .. "," .. cell.y .. "," .. cell.z)
    table.insert(highlightCells, cell)
end

function updateHighlightCells()
    if DB_HIGHLIGHT ~= "None" then
        highlightCells = {}
    end

    if DB_HIGHLIGHT then
        if DB_HIGHLIGHTMODE == "CleanList" then
            for _, room in pairs(cleanList) do
                for _, cell in ipairs(room) do
                    addHighlightCell(cell)
                end
            end
        elseif DB_HIGHLIGHTMODE == "ContainerCells" then
            for _, cell in ipairs(containerCells) do
                addHighlightCell(cell)
            end
        elseif DB_HIGHLIGHTMODE == "AllCells" then
            for _, building in ipairs(testList) do
                for _, room in pairs(building.rooms) do
                    for _, cell in pairs(room) do
                        addHighlightCell(cell)
                    end
                end
            end
        end
    end
end

-- Fonction de rendu pour dessiner la surbrillance
local function renderHighlights()
    updateHighlightCells()

    for _, cell in ipairs(highlightCells) do
        print("Rendering cell: " ..cell.x .. "," .. cell.y .. "," .. cell.z)
        local hc = getCore():getGoodHighlitedColor()
        local floorSprite = IsoSprite.new()
        local room = cell.roomName
        local r,g,b = 0,0,0
        if roomColors[room] == nil then
            roomColors[room] = {r = ZombRandFloat(0,1), g = ZombRandFloat(0,1), b = ZombRandFloat(0,1)}
            r,g,b = roomColors[room].r, roomColors[room].g, roomColors[room].b
        else
            r,g,b = roomColors[room].r, roomColors[room].g, roomColors[room].b
        end
        floorSprite:LoadFramesNoDirPageSimple('media/ui/FloorTileCursor.png')
        floorSprite:RenderGhostTileColor(cell.x, cell.y, cell.z, r, g, b, 0.8)
    end
end

-- Enregistrer la fonction de rendu dans l'événement OnPostRender
Events.OnPostRender.Add(renderHighlights)