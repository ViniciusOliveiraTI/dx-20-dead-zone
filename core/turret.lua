local Projectile = require("core.projectile")
local Animation = require("core.animation")
local SpriteLoader = require("core.sprite_loader")
local SpriteNormalizer = require("systems.sprite_normalizer")

local DEATH_DURATION = 1.0

local Turret = {}
Turret.__index = Turret

function Turret.new(x, y)
    local self = setmetatable({}, Turret)

    self.x = x or 0
    self.y = y or 0
    self.width = 26
    self.height = 34
    self.speed = 0

    self.damage = 12
    self.maxHealth = 90
    self.health = self.maxHealth
    self.attackCooldown = 1.8
    self.attackTimer = 0
    self.alive = true
    self.color = {0.7, 0.2, 0.7}

    self.rotation = 0
    self.dying = false
    self.deathTimer = 0
    self.fadeAlpha = 1
    self.state = "idle"
    local sets = SpriteLoader.getSet("turret")
    self.animations = {
        idle = sets.idle or Animation.new({}, 0.15, true),
        attack = sets.shot or sets.attack or sets.idle or Animation.new({}, 0.1, true)
    }
    self.currentAnimation = self.animations.idle

    -- Ensure attack animation does not loop (shot should play once)
    if self.animations.attack and type(self.animations.attack) == "table" then
        self.animations.attack.loop = false
    end

    -- Ensure attack cooldown is at least the animation duration so it can finish
    if self.animations.attack and type(self.animations.attack.getFrameCount) == "function" then
        local frameCount = self.animations.attack:getFrameCount() or 1
        local frameDur = self.animations.attack:getFrameDuration() or 0.1
        local animDur = frameCount * frameDur
        self.attackCooldown = math.max(self.attackCooldown, animDur + 0.05)
    end

    return self
end

function Turret:update(dt, player, projectiles)
    if self.dying then
        self.deathTimer = self.deathTimer + dt
        self.fadeAlpha = math.max(0, 1 - self.deathTimer / DEATH_DURATION)
        if self.currentAnimation then
            self.currentAnimation:update(dt)
        end
        return
    end

    if not self.alive then
        return
    end

    self.attackTimer = self.attackTimer + dt

    local centerX = self.x + self.width / 2
    local centerY = self.y + self.height / 2
    local dx = player.x + player.width / 2 - centerX
    local dy = player.y + player.height / 2 - centerY
    local len = math.sqrt(dx * dx + dy * dy)

    if len > 0 then
        dx = dx / len
        dy = dy / len

        self.rotation = math.atan2(dy, dx) - math.pi / 2
    end

    if self.currentAnimation then
        self.currentAnimation:update(dt)
    end

    -- If a fire was queued, spawn the projectile when animation reaches middle frame
    if self.pendingFire and self.currentAnimation then
        local mid = math.max(1, math.ceil(self.currentAnimation:getFrameCount() / 2))
        if self.currentAnimation:getCurrentIndex() >= mid then
            local dir = self.pendingFireDir or { x = 0, y = 0 }
            table.insert(projectiles, Projectile.new(centerX, centerY, dir.x, dir.y, self.damage, true))
            self.pendingFire = false
            self.pendingFireDir = nil
        end
    end

    -- If attack animation finished (non-looping), return to idle
    if self.state == "attack" and self.currentAnimation and not self.currentAnimation.loop then
        if self.currentAnimation:getCurrentIndex() >= self.currentAnimation:getFrameCount() then
            self:changeState("idle")
        end
    end

    if self.attackTimer < self.attackCooldown then
        if self.state ~= "attack" then
            self:changeState("idle")
        end
        return
    end

    self.attackTimer = self.attackTimer - self.attackCooldown
    -- Trigger shot animation and defer projectile spawn until animation timing
    self:changeState("attack")
    if len <= 0 then
        return
    end

    -- queue projectile to spawn when animation reaches its mid frame
    self.pendingFire = true
    self.pendingFireDir = { x = dx, y = dy }
end

function Turret:changeState(newState)
    if self.state == newState then
        return
    end
    self.state = newState
    local nextAnim = self.animations[newState] or self.animations.idle
    if nextAnim and nextAnim ~= self.currentAnimation then
        self.currentAnimation = nextAnim
        self.currentAnimation:reset()
        print("[Turret] changeState:", newState, "frames=", self.currentAnimation:getFrameCount())
    end
end

function Turret:draw()
    if not self.alive and not self.dying then
        return
    end

    local alpha = self.fadeAlpha or 1
    local frame = self.currentAnimation and self.currentAnimation:currentFrame()
    if frame then
        love.graphics.setColor(1, 1, 1, alpha)
        local norm = SpriteNormalizer.getScale("turret") or 1
        local scale = frame.scale * norm
        love.graphics.draw(frame.image, frame.quad, self.x + self.width / 2, self.y + self.height / 2, self.rotation, scale, scale, frame.originX, frame.originY)
        love.graphics.setColor(1, 1, 1, 1)
        return
    end

    love.graphics.setColor(self.color)
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
    love.graphics.setColor(1, 1, 1)
end

function Turret:takeDamage(amount)
    self.health = self.health - (amount or 0)
    if self.health <= 0 and not self.dying then
        self.alive = false
        self.dying = true
        self.deathTimer = 0
        self.fadeAlpha = 1
        return true
    end
    return false
end

function Turret:shouldRemove()
    return self.dying and self.deathTimer >= DEATH_DURATION
end

return Turret
