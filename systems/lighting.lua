local Lighting = {}

function Lighting.new(screenWidth, screenHeight)
    local self = {}
    self.screenWidth = screenWidth
    self.screenHeight = screenHeight
    return setmetatable(self, { __index = Lighting })
end

function Lighting:resize(w, h)
    self.screenWidth = w
    self.screenHeight = h
end

function Lighting:draw(playerX, playerY, radius)
    radius = radius or 160

    -- Darken the screen using multiply blend mode and a visible light circle
    love.graphics.setBlendMode("multiply", "premultiplied")
    love.graphics.setColor(0.22, 0.22, 0.22, 1)
    love.graphics.rectangle("fill", 0, 0, self.screenWidth, self.screenHeight)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", playerX, playerY, radius)
    love.graphics.circle("fill", playerX, playerY, radius * 0.6)
    love.graphics.circle("fill", playerX, playerY, radius * 0.3)

    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(1, 1, 1, 1)
end

return Lighting
