local PlayerShootAction = {}
PlayerShootAction.__index = PlayerShootAction

function PlayerShootAction.new(player, projectiles, camera)
    local self = setmetatable({}, PlayerShootAction)

    self.player = player
    self.projectiles = projectiles
    self.camera = camera

    return self
end

function PlayerShootAction:execute(gameState)
    if not gameState or not gameState:canUpdate() then
        return
    end

    if not love.mouse.isDown(1) then
        return
    end

    if not self.player.weapon then
        return
    end

    if not self.player:isAlive() then
        return
    end

    if self.player.weapon:shoot() then
        if self.player.onShoot then
            self.player:onShoot()
        end
        local mx, my = love.mouse.getPosition()
        if self.camera then
            mx, my = self.camera:toWorld(mx, my)
        end

        local px = self.player.x + self.player.width / 2
        local py = self.player.y + self.player.height / 2

        local dx = mx - px
        local dy = my - py
        local len = math.sqrt(dx * dx + dy * dy)

        if len == 0 then
            return
        end

        dx = dx / len
        dy = dy / len

        local Projectile = require("core.projectile")
        table.insert(self.projectiles, Projectile.new(px, py, dx, dy))
    end
end

return PlayerShootAction
