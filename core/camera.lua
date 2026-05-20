local Camera = {}
Camera.__index = Camera

function Camera.new(screenWidth, screenHeight)
    local self = setmetatable({}, Camera)
    self.x = 0
    self.y = 0
    self.width = screenWidth or 800
    self.height = screenHeight or 600
    self.worldWidth = 0
    self.worldHeight = 0
    return self
end

function Camera:setViewport(width, height)
    self.width = width or self.width
    self.height = height or self.height
end

function Camera:setWorldSize(worldWidth, worldHeight)
    self.worldWidth = worldWidth or self.worldWidth
    self.worldHeight = worldHeight or self.worldHeight
end

function Camera:update(target)
    if not target then
        return
    end

    local targetX = target.x + (target.width or 0) / 2 - self.width / 2
    local targetY = target.y + (target.height or 0) / 2 - self.height / 2

    self.x = math.max(0, math.min(targetX, math.max(0, self.worldWidth - self.width)))
    self.y = math.max(0, math.min(targetY, math.max(0, self.worldHeight - self.height)))
end

function Camera:apply()
    love.graphics.translate(-math.floor(self.x), -math.floor(self.y))
end

function Camera:toWorld(screenX, screenY)
    return screenX + self.x, screenY + self.y
end

function Camera:toScreen(worldX, worldY)
    return worldX - self.x, worldY - self.y
end

return Camera
