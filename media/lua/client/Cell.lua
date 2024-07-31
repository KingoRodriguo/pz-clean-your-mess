Cell = {}

-----------------------------------------
-- local functions for Cell class only --
-----------------------------------------

-- Function to initialize the room attribute of the cell
local function getRoom(square)
    local room = nil
    if square and square:getRoom() then
        room = square:getRoom()
    end
    return room
end

-- Function to get the container data of the cell
local function getContainerData(sq)
    local container = nil
    local containerCapacity = 0
    local containerContentWeight = 0

    local objects = sq:getObjects()
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if instanceof(obj, "IsoObject") then
            if obj:getContainerCount() > 0 then
                container = obj:getContainer()
                containerCapacity = container:getMaxWeight()
                containerContentWeight = container:getContentsWeight()
            end
        end
    end

    return container, containerCapacity, containerContentWeight
end

-- Function to get the items on the cell
local function isItems(square)
    local items = {}
    if square then
        local objects = square:getObjects()
        for i = objects:size() - 1, 0, -1 do
            local obj = objects:get(i)
            if instanceof(obj, "IsoWorldInventoryObject") then
                table.insert(items, obj)
            end
        end
    end

    return items
end

-- Function to initialize the Cell object attributes
local function initializeCell(cell, sq)
    if cell == nil or sq == nil then return nil end

    cell.room = getRoom(sq)
    if cell.room then
        cell.roomName = cell.room:getName()
        cell.building = cell.room:getBuilding()
        cell.isIndoor = true
    end

    cell.items = isItems(sq)
    cell.container, cell.containerCapacity, cell.containerContentWeight = getContainerData(sq)

    return cell
end

-----------------------------------------
-- Cell constructor
-----------------------------------------
-- Cell attributes definition
--  square: IsoGridSquare object
--  x: x coordinate of the cell
--  y: y coordinate of the cell
--  z: z coordinate of the cell
--  isIndoor: boolean value to check if the cell is indoor
--  room: IsoRoom object
--  roomName: name of the room
--  building: Building object
--  container: ItemContainer object
--  containerCapacity: maximum weight capacity of the container
--  containerContentWeight: total weight of the container's content
--  items: list of IsoWorldInventoryObject objects on the cell

function Cell:new(_x, _y, _z)
    local sq = getCell():getGridSquare(_x, _y, _z)
    local o = {
        square = sq,

        x = _x,
        y = _y,
        z = _z,

        room =  nil,
        roomName = nil,
        building = nil,
        isIndoor = false,

        container = nil,
        containerCapacity = 0,
        containerContentWeight = 0,

        items = {}
    }

    local oData = initializeCell(o, sq)

    if oData then o = oData end

    setmetatable(o, self)
    self.__index = self
    return o
end

-- Function to update the Cell object attributes
function Cell:update()
    self = initializeCell(self, self.square)
end

-- Function to clean the cell by removing all items on it
function Cell:clean()
    if self.items ~= nil then
        for i = #self.items, 1, -1 do
            local item = self.items[i]
            if item ~= nil then
                self.square:removeWorldObject(item)
            end
        end
    end
end
