local Animation = require("core.animation")
local SpriteLoader = require("core.sprite_loader")
local SpriteNormalizer = require("systems.sprite_normalizer")

local Player = {}
Player.__index = Player

function Player.new(x, y, weapon)
    local self = setmetatable({}, Player)

    self.x = x or 0
    self.y = y or 0
    self.width = 24
    self.height = 30
    self.speed = 200

    self.maxHealth = 100
    self.health = self.maxHealth
    self.weapon = weapon

    self.rotation = 0
    self.isMoving = false
    self.aiming = false
    self.dead = false
    self.deathTimer = 0
    self.deathDuration = 1.2
    self.alpha = 1
    self.state = "idle"

    local sets = SpriteLoader.getSet("player")
    self.animations = {
        idle = sets.idle or sets.walk or sets.attack or Animation.new({}, 0.3, true),
        walk = sets.walk or sets.idle or sets.attack or Animation.new({}, 0.15, true),
        attack = sets.shot or sets.attack or sets.idle or sets.walk or Animation.new({}, 0.12, true),
        death = sets.death or sets.idle or Animation.new({}, 0.12, false)
    }
    self.currentAnimation = self.animations.idle
    self.attackCooldown = 0.5
    self.attackTimer = self.attackCooldown

    return self
end

function Player:onShoot()
    self.attackTimer = 0
end

function Player:update(dt, camera)
    if self.weapon then
        self.weapon:update(dt)
    end

    local mx, my = love.mouse.getPosition()
    if camera then
        mx, my = camera:toWorld(mx, my)
    end

    local px = self.x + self.width / 2
    local py = self.y + self.height / 2
    -- Offset -π/2 because sprites face south (down) and rotation must align with screen-space mouse direction
    self.rotation = math.atan2(my - py, mx - px) - math.pi / 2

    if self.dead then
        self.deathTimer = self.deathTimer + dt
        self.alpha = math.max(0, 1 - self.deathTimer / self.deathDuration)
        self:changeState("death")
        if self.currentAnimation then
            self.currentAnimation:update(dt)
        end
        return
    end

    self.aiming = love.mouse.isDown(1)
    self.attackTimer = math.min(self.attackTimer + dt, self.attackCooldown)

    local nextState = "idle"
    if self.attackTimer < self.attackCooldown then
        nextState = "attack"
    elseif self.isMoving then
        nextState = "walk"
    end

    self:changeState(nextState)
    if self.currentAnimation then
        self.currentAnimation:update(dt)
    end
end

function Player:draw()
    local frame = self.currentAnimation and self.currentAnimation:currentFrame()
    if frame then
        love.graphics.setColor(1, 1, 1, self.alpha)
        local norm = SpriteNormalizer.getScale("player") or 1
        local scale = frame.scale * norm
        love.graphics.draw(frame.image, frame.quad, self.x + self.width / 2, self.y + self.height / 2, self.rotation, scale, scale, frame.originX, frame.originY)
        love.graphics.setColor(1, 1, 1, 1)
        return
    end

    love.graphics.setColor(1, 1, 1, self.alpha)
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
    love.graphics.setColor(1, 1, 1, 1)
end

function Player:changeState(newState)
    if self.state == newState then
        return
    end

    self.state = newState
    local animation = self.animations[newState] or self.animations.idle
    if animation and animation ~= self.currentAnimation then
        self.currentAnimation = animation
        self.currentAnimation:reset()
        print("[Player] changeState:", newState, "frames=", self.currentAnimation:getFrameCount())
    end
end

function Player:takeDamage(amount)
    self.health = self.health - (amount or 0)
    if self.health <= 0 and not self.dead then
        self.health = 0
        self.dead = true
        self.deathTimer = 0
        self.alpha = 1
        self:changeState("death")
    end
end

function Player:isAlive()
    return not self.dead and self.health > 0
end

function Player:isDeathComplete()
    return self.dead and self.deathTimer >= self.deathDuration
end

function Player:pickupAmmo(amount)
    if not self.weapon or amount <= 0 then
        return
    end

    self.weapon:addReserve(amount)
end

return Player
