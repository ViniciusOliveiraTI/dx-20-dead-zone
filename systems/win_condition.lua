local WinCondition = {}
WinCondition.__index = WinCondition

WinCondition.levels = {
    { mapPath = "maps/map01.txt", target = 2 },
    { mapPath = "maps/map02.txt", target = 1 },
    { mapPath = "maps/map03.txt", target = 1 },
    { mapPath = "maps/map04.txt", target = 1 },
    { mapPath = "maps/map05.txt", target = 1 }
}

function WinCondition.new()
    local self = setmetatable({}, WinCondition)
    self.currentLevel = 1
    self.killCount = 0
    self.bossSpawned = false
    self.isBossDefeated = false
    return self
end

function WinCondition:currentMapPath()
    return self.levels[self.currentLevel].mapPath
end

function WinCondition:currentTarget()
    return self.levels[self.currentLevel].target
end

function WinCondition:isLevelComplete()
    -- Non-final levels: reach kill target
    if not self:isFinalLevel() then
        return self.killCount >= self:currentTarget()
    end
    
    -- Final level: reach kill target AND defeat boss
    return self.killCount >= self:currentTarget() and self.isBossDefeated
end

function WinCondition:isComplete()
    return self:isLevelComplete()
end

function WinCondition:isFinalLevel()
    return self.currentLevel == #self.levels
end

function WinCondition:registerKill()
    if self:isLevelComplete() then
        return
    end

    self.killCount = self.killCount + 1
end

function WinCondition:advanceLevel()
    if self.currentLevel < #self.levels then
        self.currentLevel = self.currentLevel + 1
        self.killCount = 0
        self.bossSpawned = false
        self.isBossDefeated = false
    end
end

function WinCondition:reset()
    self.currentLevel = 1
    self.killCount = 0
    self.bossSpawned = false
    self.isBossDefeated = false
end

function WinCondition:shouldSpawnBoss()
    -- Spawn boss when kill target is reached in final level, regardless of boss defeat
    return self:isFinalLevel() and self.killCount >= self:currentTarget() and not self.bossSpawned
end

function WinCondition:markBossSpawned()
    self.bossSpawned = true
end

function WinCondition:markBossDefeated()
    self.isBossDefeated = true
end

return WinCondition
