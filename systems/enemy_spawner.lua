local Zombie = require("core.zombie")
local ZombieTypes = require("core.zombie_types")

local EnemySpawner = {}
EnemySpawner.__index = EnemySpawner

function EnemySpawner.new(map, zombies, maxEnemies)
    local self = setmetatable({}, EnemySpawner)

    self.map = map
    self.zombies = zombies
    self.maxEnemies = maxEnemies or 12

    self.spawnCooldown = 2
    self.timer = 0

    self.typeNames = { "normal", "fast", "brute" }

    return self
end

function EnemySpawner:getRandomSpawnPoint()
    if #self.map.enemySpawns == 0 then
        return nil
    end

    local spawn = self.map.enemySpawns[love.math.random(#self.map.enemySpawns)]
    if self.map:collidesWithRect(spawn.x, spawn.y, 24, 30) then
        return nil
    end
    return spawn
end

function EnemySpawner:update(dt, gameState, winCondition)
    if not gameState or not gameState:canUpdate() then
        return
    end

    if winCondition and winCondition:isLevelComplete() then
        return
    end

    self.timer = self.timer + dt

    if self.timer < self.spawnCooldown then return end
    if #self.zombies >= self.maxEnemies then return end
    if #self.map.enemySpawns == 0 then return end

    self.timer = 0

    local spawn = self:getRandomSpawnPoint()
    if not spawn then
        return
    end

    local typeName = self.typeNames[love.math.random(#self.typeNames)]
    local zType = ZombieTypes[typeName]
    if not zType then
        return
    end

    table.insert(self.zombies, Zombie.new(spawn.x, spawn.y, typeName, zType))
end

return EnemySpawner
