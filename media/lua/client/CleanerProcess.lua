-- Requirements
---------------------------------------------
require "class_DEBUG"
require "class_Building"

-- DB Data
---------------------------------------------
local _DB = DB_GetDBMode("Cleaner")

-- local data
---------------------------------------------
local isEnabled = false
local state = "Clean"

local building = nil
local dirtyCells = {}
local containerCell = {}

local player = nil
local inventory = nil

local queue = nil

-- Local functions
---------------------------------------------

local function getPlayerSquare(player)
    if not player then 
        if _DB then DB_Log("Can't get player square because player is nil", "Error") end
        return nil
    end

    local x, y, z = player:getX(), player:getY(), player:getZ()
    local playerSquare = getCell():getGridSquare(x, y, z)

    if _DB then DB_Log("Player Square: " .. tostring(playerSquare), "Info") end
    return playerSquare
end

local function resetCleaner()
    if _DB then DB_Log("Reset Cleaner", "Info") end
    player = nil
    isEnabled = false
    state = "Clean"

    building = nil
    dirtyCells = {}
    containerCell = {}

    queue = nil
    inventory = nil
end

local function createBuilding(startSquare)
    if not startSquare then 
        if _DB then DB_Log("Can't create building because startSquare is nil", "Error") end
        return 
    end

    if building then 
        if _DB then DB_Log("Can't create building because there is already a building", "Error") end
        return 
    end
    
    -- Initialize building
    building = Building:new(startSquare)
    building.building = building:SetBuilding()
    building.cells = building:GetCells(startSquare)
end

local function getClosestCell(player, cells)
    if not player then 
        if _DB then DB_Log("Can't get closest cell because player is nil", "Error") end
        return nil
    end

    if not cells or #cells == 0 then 
        if _DB then DB_Log("Can't get closest cell because cells is nil or empty", "Error") end
        return nil
    end

    local closestCell = nil
    local closestDistance = 999999

    for i = 1, #cells do
        local cell = cells[i]
        local distance = cell.square:DistTo(getPlayerSquare(player))
        if distance < closestDistance then
            closestCell = cell
            closestDistance = distance
        end
    end

    return closestCell
end

local function removeElement(_table, _element)
    if not _table then 
        if _DB then DB_Log("Can't remove element because table is nil", "Error") end
        return 
    end

    if not _element then 
        if _DB then DB_Log("Can't remove element because element is nil", "Error") end
        return 
    end

    for i = #_table, 1, -1 do
        if _table[i] == _element then
            table.remove(_table, i)
        end
    end
end

local function moveToCell(cell)
    if not cell then 
        if _DB then DB_Log("Can't move to cell because cell is nil", "Error") end
        return nil
    end
    local square = cell.square
    local playerSquare = getPlayerSquare(player)
    if playerSquare:isBlockedTo(square) then
        if _DB then DB_Log("Can't move to cell because path is blocked", "Warning") end
        square = AdjacentFreeTileFinder.Find(square, player)
        if not square then
            if _DB then DB_Log("Can't move to cell because there is no adjacent square", "Error") end
            return nil
        end
    end
    local action = ISWalkToTimedAction:new(player, square)
    return action
end

local function takeItem(item)
    if not item then 
        if _DB then DB_Log("Can't take item because item is nil", "Error") end
        return nil
    end

    local time = ISWorldObjectContextMenu.grabItemTime(player, item)
    local action = ISGrabItemAction:new(player, item, time)
    return action
end

local function getNextAction()
    local action = nil
    if state == "Clean" then
        -- If player full switch to state "Store"
        if inventory:getCapacityWeight() >= inventory:getMaxWeight() then
            state = "Store"
            return "SKIP"
        end
        if #dirtyCells > 0 then
            local cell = getClosestCell(player, dirtyCells)
            if cell == getPlayerSquare(player) then
                -- Check if cell is dirty
                if cell:getDirtiness() > 0 then
                    if _DB then DB_Log("Cleaning cell", "Info") end
                    local items = cell:GetItems()
                    -- Take item
                    if #items > 0 then
                        action = takeItem(items[1])
                        return action
                    end
                else
                    -- Remove clean cell from dirtyCells
                    removeElement(dirtyCells, cell)
                    return "SKIP"
                end
            else
                action = moveToCell(cell)
                return action
            end
        end
    end
    if state == "Store" then
        isEnabled = false
    end
end

local function UpdateCleaner()
    for _, cell in pairs(dirtyCells) do
        DB_AddHighLightCell(cell)
    end
    if not isEnabled then return end
    if queue == nil then return end
    if player == nil then return end

    if #queue.queue == 0 and not queue.isPlayerDoingAction(player) then
        local action = getNextAction()
        if action then
            if action == "SKIP" then
                return
            else
                queue.add(action)
            end
        end
    end
end

-- Global functions
---------------------------------------------

function CleanYourMess()
    --Startup procedure
    if isEnabled then
        if _DB then DB_Log("Cleaner is already enabled", "Info") end
        return
    end
    
    resetCleaner()

    player = getPlayer()
    inventory = player:getInventory()
    queue = ISTimedActionQueue.getTimedActionQueue(player)

    -- Setup for starting to clean
    local start_square = getPlayerSquare(player)

    -- Check if start_square is nil
    if not start_square then
        if _DB then DB_Log("Can't clean because start_square is nil", "Error") end
        return
    end
    -- Check if start_square is indoor
    if not start_square:getRoom() then
        player:Say("I cannot clean outside")
        if _DB then DB_Log("Can't clean because start_square is outdoor", "Info") end
        return
    end

    -- Create Building Structure
    createBuilding(start_square)

    -- Check if building is nil
    if not building then
        if _DB then DB_Log("Can't clean because building is nil", "Error") end
        return
    end

    -- Initialize dirtyCells
    dirtyCells = building:GetDirtyCells()
    if not dirtyCells or #dirtyCells == 0 then
        player:Say("There is nothing to clean")
        if _DB then DB_Log("Can't clean because there is nothing to clean", "Info") end
        return
    end

    -- Initialize containerCell
    containerCell = building:GetContainersCells()
    if not containerCell or #containerCell == 0 then
        player:Say("There is no container to store items")
        if _DB then DB_Log("Can't clean because there is no container to store items", "Info") end
        return
    end

    isEnabled = true
end

Events.OnTick.Add(UpdateCleaner)