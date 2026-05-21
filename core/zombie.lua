local Animation = require("core.animation")
local SpriteLoader = require("core.sprite_loader")
local Collision = require("core.collision")
local SpriteNormalizer = require("systems.sprite_normalizer")

local DEFAULT_ATTACK_COOLDOWN = 1.0
local DEATH_DURATION = 1.0
local STANDARD_ATTACK_RANGE = 40 -- circular attack range for standard enemies (pixels)

local Zombie = {}
Zombie.__index = Zombie

function Zombie.new(x, y, typeName, zombieType)
    local self = setmetatable({}, Zombie)

    self.x = x or 0
    self.y = y or 0
    self.width = 24
    self.height = 30

    self.typeName = typeName or "normal"
    self.speed = zombieType.speed
    self.damage = zombieType.damage

    self.maxHealth = zombieType.health
    self.health = self.maxHealth
    self.color = zombieType.color

    self.attackCooldown = DEFAULT_ATTACK_COOLDOWN
    self.attackTimer = 0.0
    self.attackPause = 0.0

    self.rotation = 0
    self.state = "idle"
    self.alive = true
    self.dying = false
    self.deathTimer = 0
    self.fadeAlpha = 1

    local sets = SpriteLoader.getSet("zombies." .. self.typeName)
    self.animations = {
        idle = sets.idle or sets.walk or sets.attack or Animation.new({}, 0.3, true),
        walk = sets.walk or sets.idle or sets.attack or Animation.new({}, 0.1, true),
        attack = sets.melee_attack or sets.attack or sets.walk or sets.idle or Animation.new({}, 0.1, true),
        death = sets.death or sets.idle or Animation.new({}, 0.12, false)
    }
    self.currentAnimation = self.animations.idle

    return self
end

function Zombie:changeState(newState)
    if self.state == newState then
        return
    end

    self.state = newState
    local nextAnim = self.animations[newState] or self.animations.idle
    if nextAnim and nextAnim ~= self.currentAnimation then
        self.currentAnimation = nextAnim
        self.currentAnimation:reset()
    end
end

function Zombie:update(dt, player, gameMap)
    if self.dying then
        self.deathTimer = self.deathTimer + dt
        self.fadeAlpha = math.max(0, 1 - self.deathTimer / DEATH_DURATION)
        self:changeState("death")
        if self.currentAnimation then
            self.currentAnimation:update(dt)
        end
        return
    end

    self.attackTimer = self.attackTimer + dt

    if self.attackPause > 0 then
        self.attackPause = math.max(0, self.attackPause - dt)
        self:changeState("attack")
        if self.currentAnimation then
            self.currentAnimation:update(dt)
        end
        return
    end

    local dx = player.x - self.x
    local dy = player.y - self.y
    local len = math.sqrt(dx * dx + dy * dy)

    if len > 0 then
        dx, dy = dx / len, dy / len
        -- Offset -π/2 because sprites face south (down) and rotation must align with player direction
        self.rotation = math.atan2(dy, dx) - math.pi / 2
    end

    local nx = self.x + dx * self.speed * dt
    if not gameMap:collidesWithRect(nx, self.y, self.width, self.height) then
        self.x = nx
    end

    local ny = self.y + dy * self.speed * dt
    if not gameMap:collidesWithRect(self.x, ny, self.width, self.height) then
        self.y = ny
    end

    local nextState = "idle"
    if len > STANDARD_ATTACK_RANGE * 1.25 then
        nextState = "walk"
    else
        if self.attackTimer >= self.attackCooldown and len <= STANDARD_ATTACK_RANGE then
            player:takeDamage(self.damage)
            self.attackTimer = 0
            self.attackPause = math.max(0.2, (self.animations.attack:getFrameCount() or 1) * self.animations.attack:getFrameDuration())
            nextState = "attack"
        end
    end

    self:changeState(nextState)
    if self.currentAnimation then
        self.currentAnimation:update(dt)
    end
end

function Zombie:draw()
    if not self.alive and not self.dying then
        return
    end

    local frame = self.currentAnimation and self.currentAnimation:currentFrame()
    if frame then
        love.graphics.setColor(1, 1, 1, self.fadeAlpha)
        local norm = SpriteNormalizer.getScale("zombies." .. self.typeName) or 1
        local scale = frame.scale * norm
        love.graphics.draw(frame.image, frame.quad, self.x + self.width / 2, self.y + self.height / 2, self.rotation, scale, scale, frame.originX, frame.originY)
        love.graphics.setColor(1, 1, 1, 1)
        return
    end

    love.graphics.setColor(self.color[1], self.color[2], self.color[3], self.fadeAlpha)
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
    love.graphics.setColor(1, 1, 1, 1)
end

function Zombie:takeDamage(amount)
    self.health = self.health - (amount or 0)
    if self.health <= 0 and not self.dying then
        self.alive = false
        self.dying = true
        self.deathTimer = 0
        self.fadeAlpha = 1
        self:changeState("death")
        return true
    end
    return false
end

function Zombie:shouldRemove()
    return self.dying and self.deathTimer >= DEATH_DURATION
end

return Zombie
