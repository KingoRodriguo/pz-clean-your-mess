Cell = {}

-- Liste des types d'objets aléatoires possibles (vous pouvez ajouter ou modifier les types)
local objectTypes = {
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

-- Fonction pour vérifier si une tuile est à l'intérieur d'un bâtiment
local function isIndoor(square)
    -- Vérifier si le carré existe et s'il a une pièce (room) associée
    if square and square:getRoom() then
        return true
    end
    
    return false
end

-- Fonction pour obtenir la pièce (room) d'un carré
function Cell:getRoom(square)    
    -- Vérifier si le carré existe et s'il a une pièce (room) associée
    if square and square:getRoom() then
        self.roomName = tostring(square:getRoom():getName())
        self.room = square:getRoom()
    end
    
    return nil
end

-- Fonction pour vérifier s'il y a une porte sur une tuile spécifique
local function isDoor(square)
    -- Vérifier si le carré existe
    if square then
        -- Parcourir les objets du carré
        for i = 0, square:getObjects():size() - 1 do
            local object = square:getObjects():get(i)
            
            -- Vérifier si l'objet est une porte
            if object:getType() == IsoObjectType.doorFrN
                or object:getType() == IsoObjectType.doorFrW
                or object:getType() == IsoObjectType.doorN
                or object:getType() == IsoObjectType.doorW then
                return true
            end
        end
    end
    
    return false
end

-- Fonction pour vérifier s'il y a un mur sur une tuile spécifique
local function isWall(square)
    -- Vérifier si le carré existe
    if square then
        -- Parcourir les objets du carré
        for i = 0, square:getObjects():size() - 1 do
            local object = square:getObjects():get(i)
            
            -- Vérifier si l'objet est un mur
            if object:getType() == IsoObjectType.wall then
                return true
            end
        end
    end
    
    return false
end

-- Fonction pour vérifier s'il y a des objets au sol ou placés sur une tuile spécifique
local function isItems(square)
    local items = {}
    -- Vérifier si le carré existe
    if square then
        -- Vérifier les objets au sol (items dropped)
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

function Cell:getContainerData(sq)
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
    self.container = container
    self.containerCapacity = containerCapacity
    self.containerContentWeight = containerContentWeight
end

function Cell:new(x, y, z)
    local sq = getCell():getGridSquare(x, y, z)
    local o = {
        square = sq,
        x = sq:getX(),
        y = sq:getY(),
        z = sq:getZ(),
        isIndoor = isIndoor(sq),
        isWall = isWall(sq),
        isDoor = isDoor(sq),
        room =  nil,
        roomName = nil,
        building = nil,
        container = nil,
        containerCapacity = 0,
        containerContentWeight = 0,

        items = isItems(sq)
    }
    self:getRoom(sq)
    if self.room then
        self.building = self.room:getBuilding()
        --print("Building found: " .. tostring(self.building))
    end

    self:getContainerData(sq)

    setmetatable(o, self)
    self.__index = self
    return o
end

function Cell:update()
    self.square = getCell():getGridSquare(self.x, self.y, self.z)
    self.isIndoor = isIndoor(self.square)
    self.isWall = isWall(self.square)
    self.isDoor = isDoor(self.square)
    self:getRoom(self.square)
    self.items = {}
    self.items = isItems(self.square)
    self.building = self.room:getBuilding()
    self:getContainerData(self.square)
end

function Cell:populate(numberOfObjects)
    local randomPos = true
    -- Vérifier si le carré existe
    if not self.square then
        print("La tuile spécifiée n'existe pas.")
        return
    end

    if not self.square:TreatAsSolidFloor() then
        print("La tuile spécifiée n'est pas un sol solide.")
        return
    end

    -- Ajouter des objets aléatoires à la tuile
    for i = 1, numberOfObjects do
        local randomIndex = ZombRand(#objectTypes) + 1
        local itemType = objectTypes[randomIndex]

        local posX = 0.1
        local posY = 0.1

        if randomPos then 
            posX = ZombRandFloat(0,1)
            posY = ZombRandFloat(0,1)
        end
        
        -- Créer l'objet et l'ajouter au carré
        local item = objectTypes[randomIndex]
        if item then
            self.square:AddWorldInventoryItem(item, posX, posY, 0)
        else
            print("Échec de la création de l'objet : " .. itemType)
        end
    end
    self:update()
end

function Cell:clean()
	local items = self.items

	-- Supprimer tous les objets placés sur la tuile
	if items ~= nil then
		if #items > 0 then
			for i = #items, 1, -1 do
				local item = items[i]
				if item ~= nil then
					self.square:removeWorldObject(item)
				end
			end
		end
	end
end
