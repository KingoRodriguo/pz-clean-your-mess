-- Requirements
---------------------------------------------
require "class_DEBUG"
require "class_Cell"

-- DB Data
---------------------------------------------
local _DB = DB_GetDBMode("Building")

-- local data
---------------------------------------------
Building = {}

local maxRadius = 10

-- DB functions
---------------------------------------------

function Building:DB_MESS()
    for i = 1, #self.cells do
        local prob = ZombRandFloat(0, 1)
        local itemCount = ZombRand(5, 15)
        if prob > 0.5 then
            self.cells[i]:DB_MESS(itemCount)
        end
    end
end

function Building:DB_CLEAN_CELLS()
    for i = 1, #self.cells do
        self.cells[i]:DB_CLEAN_CELLS()
    end
end

function Building:DB_CLEAN_CONTAINERS()
    for i = 1, #self.containers do
        self.containers[i]:DB_CLEAN_CONTAINERS()
    end
end

-- Global functions
---------------------------------------------

function Building:GetDirtyCells()
    local dirtyCells = {}
    --if _DB then DB_Log("Get dirty cells", "Info") end
    for i = 1, #self.cells do
       -- if _DB then DB_Log(string.format("Cells %d / %d", i, #self.cells), "Info") end
        if self.cells[i]:GetDirtiness() > 0 then
            --if _DB then DB_Log("Cell is dirty: " .. tostring(self.cells[i]:GetDirtiness()), "Info") end
            table.insert(dirtyCells, self.cells[i])
        else
            --if _DB then DB_Log("Cell is clean", "Info") end
        end
    end
    if _DB then DB_Log(string.format("Found %d dirty cells", #dirtyCells), "Info") end

    return dirtyCells
end

function Building:GetContainersCells()
    local containerCells = {}
    --if _DB then DB_Log("Get container cells", "Info") end
    for i = 1, #self.cells do
        --if _DB then DB_Log(string.format("Cells %d / %d", i, #self.cells), "Info") end
        if self.cells[i]:GetCellContainer() then
            --if _DB then DB_Log("Cell is a container", "Info") end
            table.insert(containerCells, self.cells[i])
        else
            --if _DB then DB_Log("Cell is not a container", "Info") end
        end
    end
    if _DB then DB_Log(string.format("Found %d container cells", #containerCells), "Info") end

    return containerCells
end

function Building:GetCells(startSquare)
    if _DB then DB_Log("Getting building cells", "Info") end
    local startX = startSquare:getX()
    local startY = startSquare:getY()
    local startZ = startSquare:getZ()

    local _cells = {}
    for x = startX - maxRadius, startX + maxRadius do
        for y = startY - maxRadius, startY + maxRadius do
            local square = getCell():getGridSquare(x, y, startZ)
            --if _DB then DB_Log(string.format("Checking square %d, %d, %d", x, y, startZ), "Info") end
            if square then
                local cell = Cell:new(square)
                if cell then
                    if cell.square then
                        if cell.square:getRoom() ~= nil then
                            if self.building == cell.square:getRoom():getBuilding() then
                                --if _DB then DB_Log("Adding Cell", "Info") end
                                table.insert(_cells, cell)
                            else
                                if _DB then 
                                    --DB_Log("Cell is not in the same building", "Info") 
                                    --DB_Log("Building: " .. tostring(self.building) .. " | Cell: " .. tostring(cell.square:getRoom():getBuilding()) , "Info")
                                end
                            end
                        else
                            --if _DB then DB_Log("Cell is not in a room", "Info") end
                        end
                    else
                        --if _DB then DB_Log("cell.Square is nil", "Info") end
                    end
                else
                    --if _DB then DB_Log("Cell is nil", "Info") end
                end
            else
                --if _DB then DB_Log("Square is nil", "Info") end
            end
        end
    end
    if _DB then DB_Log(string.format("Found %d cells", #_cells), "Info") end
    return _cells
end

function Building:SetBuilding()
    if self.startSquare then
        if self.startSquare:getRoom() then
            if _DB then DB_Log("Building set to:" .. tostring(self.startSquare:getRoom():getBuilding()), "Info") end
            return self.startSquare:getRoom():getBuilding()
        else
            if _DB then DB_Log("Room is nil", "Error") end
        end
    else
        if _DB then DB_Log("StartSquare is nil", "Error") end
    end
end

-- Constructor
---------------------------------------------

function Building:new(startSquare)
    local o = {
        startSquare = startSquare,
        building = nil,
        cells = {},
        containersCells = {},
    }
    setmetatable(o, self)
    self.__index = self
    return o
end