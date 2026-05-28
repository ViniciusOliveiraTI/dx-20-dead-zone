local PlayerShootAction = {}
PlayerShootAction.__index = PlayerShootAction

function PlayerShootAction.new(player, projectiles, camera, audioManager)
    local self = setmetatable({}, PlayerShootAction)

    self.player = player
    self.projectiles = projectiles
    self.camera = camera
    self.audioManager = audioManager

    return self
end

function PlayerShootAction:execute(gameState)
    if not gameState or not gameState:canUpdate() then
        return
    end

    if not love.mouse.isDown(1) then
        return
    end

    local weapon = self.player:getCurrentWeapon()
    if not weapon then
        return
    end

    if not self.player:isAlive() then
        return
    end

    if weapon:shoot() then
        if self.player.onShoot then
            self.player:onShoot()
        end

        if self.audioManager then
            if weapon.weaponId == "pistol" then
                self.audioManager:playSoundEffect("pistol_shot")
            elseif weapon.weaponId == "rifle" then
                self.audioManager:playSoundEffect("rifle_shot")
            end
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
        local damage = weapon.damage or 10
        local projectile = Projectile.new(px, py, dx, dy)
        projectile.damage = damage
        table.insert(self.projectiles, projectile)
    end
end

return PlayerShootAction
