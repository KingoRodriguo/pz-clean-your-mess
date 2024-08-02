-- Requirements
---------------------------------------------
require "class_DEBUG"

-- DB Data
-------------------------------------------
local _DB = DB_GetDBMode("Cell")

-- local data
---------------------------------------------
Cell = {}

-- DB functions
---------------------------------------------

function Cell:DB_MESS(itemCount)
    if self.square then 
        local objects = self.square:getObjects()

        -- Wanky way to check to exclude unwalkable tiles (dont alway work)
        if objects:size() > 2 then return end
        for i = 1, itemCount do
            local randItem = DB_GetRandomItem()
            if type(randItem) ~= "string" then return end 
            local item = InventoryItemFactory.CreateItem(randItem)
            if item then
                self.square:AddWorldInventoryItem(item, ZombRandFloat(0,1), ZombRandFloat(0,1), 0.0)
            end
        end
    end
end

function Cell:DB_CLEAN_CELLS()
    local items = self:GetItems()
    if #items > 0 then
        for i = #items, 1, -1  do
            self.square:removeWorldObject(items[i])
        end
    end
end

function Cell:DB_CLEAN_CONTAINERS()
    local container = self:GetContainer()
    if container then
        container:emptyIt()
    end
end

-- Global functions
---------------------------------------------

function Cell:GetDirtiness()
    local dirtiness = 0
    if self.square then
        local objects = self.square:getObjects()
        for i = 0, objects:size() - 1 do
            local obj = objects:get(i)
            if instanceof(obj, "IsoWorldInventoryObject") then
                dirtiness = dirtiness + 1
            end
        end
    end
    return dirtiness
end

function Cell:GetItems()
    local items = {}
    if self.square then 
        local objects = self.square:getObjects()
        for i = 0, objects:size() - 1 do
            local obj = objects:get(i)
            if instanceof(obj, "IsoWorldInventoryObject") then
                table.insert(items, obj)
            end
        end
    end

    return items
end

function Cell:GetCellContainer()
    local container = nil

    local objects = self.square:getObjects()
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

-- Constructor
---------------------------------------------

function Cell:new(square)
    local o = {
        square = square,

        x = square:getX(),
        y = square:getY(),
        z = square:getZ(),
    }
    setmetatable(o, self)
    self.__index = self
    return o
end