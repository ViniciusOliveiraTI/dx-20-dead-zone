local AmmoPickup = {}
AmmoPickup.__index = AmmoPickup

function AmmoPickup.new(x, y, amount)
    local self = setmetatable({}, AmmoPickup)

    self.width = 16
    self.height = 16
    self.x = (x or 0) - self.width / 2
    self.y = (y or 0) - self.height / 2
    self.amount = amount or 0
    self.color = {0.2, 0.8, 0.8}

    return self
end

function AmmoPickup:draw()
    love.graphics.setColor(self.color)
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(tostring(self.amount), self.x + 2, self.y + 2)
end

return AmmoPickup
