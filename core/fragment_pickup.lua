local FragmentPickup = {}
FragmentPickup.__index = FragmentPickup

function FragmentPickup.new(x, y)
    local self = setmetatable({}, FragmentPickup)
    self.centerX = x or 0
    self.centerY = y or 0
    self.width = 26
    self.height = 26
    self.x = self.centerX - self.width / 2
    self.y = self.centerY - self.height / 2
    self.elapsed = 0
    return self
end

function FragmentPickup:update(dt)
    self.elapsed = self.elapsed + dt
end

function FragmentPickup:draw()
    local pulse = 0.5 + 0.5 * math.sin(self.elapsed * 4)
    local glow = 10 + pulse * 8

    love.graphics.setColor(0.2, 0.8, 1, 0.18)
    love.graphics.circle("fill", self.centerX, self.centerY, glow)

    love.graphics.setColor(0.05, 0.35, 0.55, 0.8)
    love.graphics.polygon(
        "fill",
        self.centerX, self.centerY - 12,
        self.centerX + 9, self.centerY - 2,
        self.centerX + 4, self.centerY + 12,
        self.centerX - 8, self.centerY + 8,
        self.centerX - 10, self.centerY - 4
    )

    love.graphics.setColor(0.65, 0.95, 1, 0.95)
    love.graphics.polygon(
        "line",
        self.centerX, self.centerY - 12,
        self.centerX + 9, self.centerY - 2,
        self.centerX + 4, self.centerY + 12,
        self.centerX - 8, self.centerY + 8,
        self.centerX - 10, self.centerY - 4
    )

    love.graphics.setColor(1, 1, 1, 0.6 + pulse * 0.3)
    love.graphics.line(self.centerX - 4, self.centerY - 5, self.centerX + 3, self.centerY + 4)
    love.graphics.setColor(1, 1, 1, 1)
end

return FragmentPickup
