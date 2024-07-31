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
local function getContainer(sq)
    local container = nil

    local objects = sq:getObjects()
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if instanceof(obj, "IsoObject") then
            if obj:getContainerCount() > 0 then
                container = obj:getContainer()
            end
        end
    end

    return container
end

-- Function to get the container prefered type
function Cell:getContainerCategories(container, cell)
    local _cell = cell or nil
    local categories = {}
    local categoryCount = 0
    if container then
        local items = container:getItems()
        for i = 0, items:size() - 1 do
            local item = items:get(i)
            if item then
                local itemCat = item:getCategory()
                --print("Item category: " ..itemCat)
                if itemCat then
                    if categories[itemCat] == nil then 
                        categories[itemCat] = 1 
                        categoryCount = categoryCount + 1
                    else
                        categories[itemCat] = categories[itemCat] + 1
                    end
                end
            end
        end
    end
    if categoryCount > 0 then
        --print("Categories found: " ..categoryCount)
    end
    return categories
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
function Cell:initializeCell(cell, sq)
    if cell == nil or sq == nil then return nil end

    cell.room = getRoom(sq)
    if cell.room then
        cell.roomName = cell.room:getName()
        cell.building = cell.room:getBuilding()
        cell.isIndoor = true
    end

    cell.items = isItems(sq)
    cell.container = getContainer(sq)
    cell.containerCategories = self:getContainerCategories(cell.container, cell)

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
        containerPreferedType = {},

        items = {}
    }

    local oData = self:initializeCell(o, sq)

    if oData then o = oData end

    setmetatable(o, self)
    self.__index = self
    return o
end

-- Function to update the Cell object attributes
function Cell:update()
    if self.square == nil then return end
    self = self:initializeCell(self, self.square)
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

function Cell:populate(qty)
    if self.square == nil then return end

    local objects = self.square:getObjects()

    if objects:size() > 2 then return end
    for i = 1, qty do
        local item = InventoryItemFactory.CreateItem(DB_getRandItem())
        if item then
            self.square:AddWorldInventoryItem(item, ZombRandFloat(0,1), ZombRandFloat(0,1), 0.0)
        end
    end
end

function Cell:cleanContainer()
    if self.container ~= nil then
        self.container:emptyIt()
        --print("Container cleaned")
    end
end
