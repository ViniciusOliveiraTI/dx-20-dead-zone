local DXSamplePickup = {}
DXSamplePickup.__index = DXSamplePickup

function DXSamplePickup.new(x, y)
    local self = setmetatable({}, DXSamplePickup)
    self.centerX = x or 0
    self.centerY = y or 0
    self.width = 30
    self.height = 34
    self.x = self.centerX - self.width / 2
    self.y = self.centerY - self.height / 2
    self.elapsed = 0
    return self
end

function DXSamplePickup:update(dt)
    self.elapsed = self.elapsed + dt
end

function DXSamplePickup:draw()
    local pulse = 0.5 + 0.5 * math.sin(self.elapsed * 5)
    local glow = 18 + pulse * 10

    love.graphics.setColor(0.1, 1, 0.35, 0.2)
    love.graphics.circle("fill", self.centerX, self.centerY, glow)

    love.graphics.setColor(0.02, 0.12, 0.08, 0.9)
    love.graphics.rectangle("fill", self.centerX - 9, self.centerY - 14, 18, 28, 4, 4)

    love.graphics.setColor(0.2, 1, 0.45, 0.9)
    love.graphics.rectangle("fill", self.centerX - 5, self.centerY - 9, 10, 18, 3, 3)

    love.graphics.setColor(0.75, 1, 0.78, 0.9)
    love.graphics.rectangle("line", self.centerX - 9, self.centerY - 14, 18, 28, 4, 4)
    love.graphics.line(self.centerX - 4, self.centerY - 4, self.centerX + 4, self.centerY + 4)
    love.graphics.line(self.centerX + 4, self.centerY - 4, self.centerX - 4, self.centerY + 4)

    love.graphics.setColor(1, 1, 1, 1)
end

return DXSamplePickup
