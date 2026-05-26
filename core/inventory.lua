local Inventory = {}
Inventory.__index = Inventory

function Inventory.new()
    local self = setmetatable({}, Inventory)
    
    self.weapons = {}  -- {weaponId = weapon}
    self.weaponOrder = {}
    self.currentWeaponId = nil
    
    return self
end

function Inventory:addWeapon(weaponId, weapon)
    if self.weapons[weaponId] then
        return false  -- Already have this weapon
    end
    
    self.weapons[weaponId] = weapon
    table.insert(self.weaponOrder, weaponId)
    
    -- Set as current if this is the first weapon
    if not self.currentWeaponId then
        self.currentWeaponId = weaponId
    end
    
    return true
end

function Inventory:hasWeapon(weaponId)
    return self.weapons[weaponId] ~= nil
end

function Inventory:getCurrentWeapon()
    if not self.currentWeaponId then
        return nil
    end
    return self.weapons[self.currentWeaponId]
end

function Inventory:getCurrentWeaponId()
    return self.currentWeaponId
end

function Inventory:switchWeapon()
    if #self.weaponOrder <= 1 then
        return false
    end
    
    local currentIndex = 1
    for i, id in ipairs(self.weaponOrder) do
        if id == self.currentWeaponId then
            currentIndex = i
            break
        end
    end
    
    local nextIndex = currentIndex % #self.weaponOrder + 1
    self.currentWeaponId = self.weaponOrder[nextIndex]
    
    return true
end

function Inventory:getWeaponIds()
    local ids = {}
    for _, id in ipairs(self.weaponOrder) do
        table.insert(ids, id)
    end
    return ids
end

function Inventory:getWeapon(weaponId)
    return self.weapons[weaponId]
end

function Inventory:addAmmoToWeapon(weaponId, amount)
    local weapon = self.weapons[weaponId]
    if weapon then
        weapon:addReserve(amount)
        return true
    end
    return false
end

function Inventory:addAmmoToCurrentWeapon(amount)
    local weapon = self:getCurrentWeapon()
    if weapon then
        weapon:addReserve(amount)
        return true
    end
    return false
end

return Inventory
