local Animation = require("core.animation")
local SpriteLoader = require("core.sprite_loader")
local Collision = require("core.collision")
local SpriteNormalizer = require("systems.sprite_normalizer")

local DEATH_DURATION = 1.4
local FIRE_DURATION = 3.0
local FIRE_COOLDOWN = 7
local FIRE_PREPARE = 1
local FIRE_DAMAGE_TICK = 0.3

local Boss = {}
Boss.__index = Boss

function Boss.new(x, y)
    local self = setmetatable({}, Boss)

    self.x = x or 0
    self.y = y or 0

    self.width = 64
    self.height = 96

    local bossType = require("core.zombie_types").boss
    self.speed = bossType.speed
    self.meleeDamage = bossType.meleeDamage
    self.rangedDamage = bossType.rangedDamage
    self.rangedRange = bossType.rangedRange
    self.maxHealth = bossType.health
    self.health = self.maxHealth
    self.color = bossType.color
    self.meleeRange = bossType.meleeRange
    self.meleeCooldown = bossType.meleeCooldown

    self.meleeTimer = 0.0
    self.rotation = 0
    self.state = "idle"
    self.alive = true
    self.dying = false
    self.deathTimer = 0
    self.fadeAlpha = 1

    self.fireTimer = 0.0
    self.fireCooldownTimer = FIRE_COOLDOWN
    self.fireDamageTimer = 0.0
    self.isFiring = false
    self.isPreparingFire = false
    self.fireDelayTimer = 0.0
    self.meleePause = 0.0

    local sets = SpriteLoader.getSet("zombies.boss")
    self.animations = {
        idle = sets.idle or sets.walk or Animation.new({}, 0.3, true),
        walk = sets.walk or sets.idle or Animation.new({}, 0.15, true),
        fire_attack = sets.fire_attack or sets.attack,
        melee_attack = sets.melee_attack or sets.attack,
        attack = sets.attack or sets.walk or sets.idle or Animation.new({}, 0.1, true),
        death = sets.death or sets.idle or Animation.new({}, 0.12, false)
    }
    self.currentAnimation = self.animations.idle

    return self
end

function Boss:changeState(newState, animationKey)
    if self.state == newState and not animationKey then
        return
    end
    self.state = newState
    local nextAnim = animationKey and self.animations[animationKey] or self.animations[newState] or self.animations.idle
    if nextAnim and nextAnim ~= self.currentAnimation then
        self.currentAnimation = nextAnim
        self.currentAnimation:reset()
        print("[Boss] changeState:", newState, "animationKey:", animationKey or newState, "frames=", self.currentAnimation:getFrameCount())
    end
end

function Boss:isPlayerInBreath(player)
    local px = player.x + player.width / 2
    local py = player.y + player.height / 2
    local cx = self.x + self.width / 2
    local cy = self.y + self.height / 2

    local dx = px - cx
    local dy = py - cy
    local len = math.sqrt(dx * dx + dy * dy)
    if len == 0 then return false end
    local ndx, ndy = dx / len, dy / len
    local angle = math.atan2(ndy, ndx)

    local breathOffset = math.max(self.width * 0.45, 20)
    local breathRange = self.rangedRange or self.meleeRange * 4
    local breathWidth = math.max(breathRange * 0.35, self.width * 1.2)

    -- Project player onto forward axis
    local forwardX, forwardY = math.cos(angle), math.sin(angle)
    local localX = dx * forwardX + dy * forwardY
    local localY = -dx * forwardY + dy * forwardX

    return localX > breathOffset
        and localX <= breathOffset + breathRange
        and math.abs(localY) <= breathWidth / 2
end

function Boss:dealBreathDamage(player)
    if self:isPlayerInBreath(player) then
        player:takeDamage(self.rangedDamage)
    end
end

function Boss:update(dt, player, gameMap)
    if self.dying then
        self.deathTimer = self.deathTimer + dt
        self.fadeAlpha = math.max(0, 1 - self.deathTimer / DEATH_DURATION)
        self:changeState("death")
        if self.currentAnimation then
            self.currentAnimation:update(dt)
        end
        return
    end

    local cx = self.x + self.width / 2
    local cy = self.y + self.height / 2
    local dx = player.x + player.width / 2 - cx
    local dy = player.y + player.height / 2 - cy
    local distance = math.sqrt(dx * dx + dy * dy)
    if distance > 0 then
        -- compute direction angle and keep sprite rotation offset for rendering
        local angle = math.atan2(dy, dx)
        self.rotation = angle - math.pi / 2
    end

    if self.isFiring then
        self.fireTimer = self.fireTimer + dt
        self.fireDamageTimer = self.fireDamageTimer + dt
        if self.fireDamageTimer >= FIRE_DAMAGE_TICK then
            self.fireDamageTimer = 0
            self:dealBreathDamage(player)
        end

        if self.fireTimer >= FIRE_DURATION then
            self.isFiring = false
            self.fireTimer = 0
            self.fireCooldownTimer = 0
            print("[Boss] fire_attack complete")
        end

    elseif self.isPreparingFire then
        self:changeState("attack", "fire_attack")
        self.fireDelayTimer = self.fireDelayTimer + dt
        
        if self.fireDelayTimer >= FIRE_PREPARE then
            self.isPreparingFire = false
            self.isFiring = true
            self.fireTimer = 0
            self.fireDamageTimer = 0
            print("[Boss] fire_attack started")
        end
    else
        self.fireCooldownTimer = self.fireCooldownTimer + dt
        self.meleeTimer = self.meleeTimer + dt
        if self.fireCooldownTimer >= FIRE_COOLDOWN and distance > self.meleeRange then
            self.isPreparingFire = true
            self.fireDelayTimer = 0
            self.fireCooldownTimer = 0
            print("[Boss] preparing fire_attack delay=", FIRE_PREPARE)
        end
    end

    if self.meleePause > 0 then
        self.meleePause = math.max(0, self.meleePause - dt)
    end

    if not self.isFiring and not self.isPreparingFire and self.meleePause <= 0 then
        local nx = self.x + (distance > 0 and (dx / distance) or 0) * self.speed * dt
        if not gameMap:collidesWithRect(nx, self.y, self.width, self.height) then
            self.x = nx
        end

        local ny = self.y + (distance > 0 and (dy / distance) or 0) * self.speed * dt
        if not gameMap:collidesWithRect(self.x, ny, self.width, self.height) then
            self.y = ny
        end
    end

    local nextState = "idle"
    local animationKey = nil
    if self.isFiring then
        nextState = "attack"
        animationKey = "fire_attack"
    elseif self.meleePause > 0 then
        nextState = "attack"
        animationKey = "melee_attack"
    elseif distance > self.meleeRange then
        nextState = "walk"
    end

    if not self.isFiring and not self.isPreparingFire and self.meleePause <= 0 and distance <= self.meleeRange and self.meleeTimer >= self.meleeCooldown then
        if Collision.checkAABB(
            self.x, self.y, self.width, self.height,
            player.x, player.y, player.width, player.height
        ) then
            player:takeDamage(self.meleeDamage)
            self.meleeTimer = 0
            self.meleePause = math.max(0.25, (self.animations.melee_attack and self.animations.melee_attack:getFrameCount() or 1) * self.animations.melee_attack:getFrameDuration())
            nextState = "attack"
            animationKey = "melee_attack"
        end
    end

    self:changeState(nextState, animationKey)
    if self.currentAnimation then
        self.currentAnimation:update(dt)
    end
end

function Boss:draw()
    if not self.alive and not self.dying then
        return
    end
        
    local cx = self.x + self.width / 2
    local cy = self.y + self.height / 2

    if self.isFiring or self.isPreparingFire then
        local breathOffset = math.max(self.width * 0.45, 20)
        local breathRange = self.rangedRange or self.meleeRange * 4
        local breathWidth = math.max(breathRange * 0.35, self.width * 1.2)

        local angle = self.rotation + math.pi / 2

        love.graphics.push()
        love.graphics.translate(cx, cy)
        love.graphics.rotate(angle)

        if self.isPreparingFire then
            -- 🔥 PREPARO (telegraph)
            love.graphics.setColor(1, 0.8, 0.2, 0.25 * self.fadeAlpha)
        else
            -- 🔥 ATAQUE ativo
            love.graphics.setColor(1, 0.5, 0, 0.35 * self.fadeAlpha)
        end

        love.graphics.rectangle("fill", breathOffset, -breathWidth / 2, breathRange, breathWidth)
        love.graphics.pop()
    end

    local frame = self.currentAnimation and self.currentAnimation:currentFrame()
    if frame then
        love.graphics.setColor(1, 1, 1, self.fadeAlpha)
        local norm = SpriteNormalizer.getScale("zombies.boss") or 1
        local scale = frame.scale * norm
        love.graphics.draw(frame.image, frame.quad, cx, cy, self.rotation, scale, scale, frame.originX, frame.originY)
        love.graphics.setColor(1, 1, 1, 1)
        return
    end

    love.graphics.setColor(self.color[1], self.color[2], self.color[3], self.fadeAlpha)
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
    love.graphics.setColor(1, 1, 1, 1)
end

function Boss:takeDamage(amount)
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

function Boss:shouldRemove()
    return self.dying and self.deathTimer >= DEATH_DURATION
end

return Boss
