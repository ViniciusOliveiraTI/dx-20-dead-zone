local Projectile = {}
Projectile.__index = Projectile

function Projectile.new(x, y, dirX, dirY, damage, fromEnemy)
    local self = setmetatable({}, Projectile)

    self.x = x or 0
    self.y = y or 0
    self.radius = 3
    self.speed = 600
    self.damage = damage or 25
    self.dirX = dirX or 0
    self.dirY = dirY or 0
    self.fromEnemy = fromEnemy or false
    self.rotation = math.atan2(self.dirY, self.dirX)

    return self
end

function Projectile:update(dt)
    self.x = self.x + self.dirX * self.speed * dt
    self.y = self.y + self.dirY * self.speed * dt
end

function Projectile:draw()
    love.graphics.push()
    love.graphics.translate(self.x, self.y)
    love.graphics.rotate(self.rotation)

    if self.fromEnemy then
        love.graphics.setColor(1, 0.2, 0.1, 0.25)
        love.graphics.rectangle("fill", -10, -3, 20, 6, 4, 4)
        love.graphics.setColor(1, 0.35, 0.1, 1)
        love.graphics.rectangle("fill", -6, -2, 12, 4, 3, 3)
        love.graphics.setColor(1, 0.85, 0.35, 1)
        love.graphics.circle("fill", 7, 0, 2)
    else
        love.graphics.setColor(1, 0.9, 0.35, 0.25)
        love.graphics.rectangle("fill", -14, -2.5, 24, 5, 4, 4)
        love.graphics.setColor(0.95, 0.62, 0.18, 1)
        love.graphics.rectangle("fill", -5, -2, 13, 4, 2, 2)
        love.graphics.setColor(1, 0.95, 0.65, 1)
        love.graphics.polygon("fill", 8, -2.5, 14, 0, 8, 2.5)
    end

    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
end

return Projectile
