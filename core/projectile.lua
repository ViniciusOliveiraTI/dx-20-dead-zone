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

    return self
end

function Projectile:update(dt)
    self.x = self.x + self.dirX * self.speed * dt
    self.y = self.y + self.dirY * self.speed * dt
end

function Projectile:draw()
    love.graphics.circle("fill", self.x, self.y, self.radius)
end

return Projectile
