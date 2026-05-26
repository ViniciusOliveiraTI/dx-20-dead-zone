local ItemPickup = {}
ItemPickup.__index = ItemPickup

-- Item types: "ammo_pistol", "ammo_rifle", "medkit", "rifle"
local itemSprites = {}
local itemTargetSizes = {
    ammo_pistol = 24,
    ammo_rifle = 24,
    medkit = 30,
    rifle = 100
}

function ItemPickup.new(x, y, itemType, amount)
    local self = setmetatable({}, ItemPickup)
    
    self.centerX = x or 0
    self.centerY = y or 0
    self.itemType = itemType or "ammo_pistol"
    self.amount = amount or 0
    self.sprite = nil
    self.spriteScale = 1
    self.width = 24
    self.height = 24
    self.x = self.centerX - self.width / 2
    self.y = self.centerY - self.height / 2
    
    return self
end

function ItemPickup:loadSprite()
    if not itemSprites[self.itemType] then
        local spritePath
        
        if self.itemType == "ammo_pistol" then
            spritePath = "sprites/items/pistol_ammo.png"
        elseif self.itemType == "ammo_rifle" then
            spritePath = "sprites/items/rifle_ammo.png"
        elseif self.itemType == "medkit" then
            spritePath = "sprites/items/medkit.png"
        elseif self.itemType == "rifle" then
            spritePath = "sprites/items/rifle.png"
        else
            return false
        end
        
        local ok, img = pcall(love.graphics.newImage, spritePath)
        if ok and img then
            itemSprites[self.itemType] = img
        else
            return false
        end
    end

    local sprite = itemSprites[self.itemType]
    if not sprite then
        return false
    end

    local iw, ih = sprite:getDimensions()
    local targetSize = itemTargetSizes[self.itemType] or 24
    local scale = math.min(targetSize / iw, targetSize / ih, 1)

    self.sprite = sprite
    self.spriteScale = scale
    self.width = iw * scale
    self.height = ih * scale
    self.x = self.centerX - self.width / 2
    self.y = self.centerY - self.height / 2

    return true
end

function ItemPickup:draw()
    if self:loadSprite() then
        local sprite = self.sprite
        local iw, ih = sprite:getDimensions()
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(sprite, self.centerX, self.centerY, 0, self.spriteScale, self.spriteScale, iw / 2, ih / 2)
    else
        -- Fallback: draw colored rectangle if sprite not found
        local colors = {
            ammo_pistol = {0.2, 0.8, 0.8},
            ammo_rifle = {0.8, 0.2, 0.8},
            medkit = {0.8, 0.2, 0.2},
            rifle = {0.2, 0.8, 0.2}
        }
        local color = colors[self.itemType] or {0.5, 0.5, 0.5}
        love.graphics.setColor(color)
        love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
        love.graphics.setColor(1, 1, 1)
    end
end

return ItemPickup
