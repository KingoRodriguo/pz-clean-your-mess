local maxPopulateRadius = 20

Building = {}

local checked = {

}

local nextCheck = {

}

function Building:new(startSquare)
    local o = {
        rooms = {},
        cells = {},
        building = nil,
    }

    if startSquare then
        self.building = startSquare:getRoom():getBuilding()
    end
    setmetatable(o, self)
    self.__index = self
    return o
end

function Building:getRoomsCount()
    local n = 0;
    for k,v in pairs(self.rooms) do
      n = n + 1;
    end
    return n;
end

local function getPlayerCoord()
    local player = getPlayer()
    local x = player:getX()
    local y = player:getY()
    local z = player:getZ()
    return x, y, z
end

local function dist(x1, y1, x2, y2)
    return math.sqrt((x2 - x1)^2 + (y2 - y1)^2)
end

--function that check for duplicates in the list
function Building:checkDuplicates(list)
    for i = 1, #self.cells do
        for j = i + 1, #list do
            if list[i] == list[j] then
                print("duplicates found")
            end
        end
    end
end

--Function qui ajoute la list des cells du batiment a self.cells
function Building:populate(startX, startY, startZ)
    local startSquare = getCell():getGridSquare(startX, startY, startZ)
    local visited = {}
    for x = startX - maxPopulateRadius, startX + maxPopulateRadius do
        for y = startY - maxPopulateRadius, startY + maxPopulateRadius do
            local square = getCell():getGridSquare(x, y, startZ)
            if square then
                local key = x .. "," .. y .. "," .. startZ
                if not visited[key] then
                    visited[key] = true
                    local cell = Cell:new(x, y, startZ)
                    if cell.isIndoor then
                        if square:TreatAsSolidFloor() then
                            if self.building == cell.building then
                                table.insert(self.cells, cell)
                                if self.rooms[cell.roomName] == nil then
                                    self.rooms[cell.roomName] = {}
                                end
                                table.insert(self.rooms[cell.roomName], cell)
                            end
                        end
                    end
                end
            end
        end
    end
    self:checkDuplicates(self.cells)
end

function Building:clean()
    for _, cell in ipairs(self.cells) do
        cell:update()
        cell:clean()
    end
end

function Building:doMess()    
    for i = 1, #self.cells do
        local rand = ZombRandFloat(0,1)
        local itemRand = ZombRand(5, 15)
        if rand > 0.5 then
            self.cells[i]:populate(itemRand)
        end
    end
end