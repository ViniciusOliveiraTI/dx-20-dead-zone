local LevelConfig = require("systems.level_config")

local WinCondition = {}
WinCondition.__index = WinCondition

WinCondition.levels = {
    { mapPath = "maps/map01.txt" },
    { mapPath = "maps/map02.txt" },
    { mapPath = "maps/map03.txt" },
    { mapPath = "maps/map04.txt" },
    { mapPath = "maps/map05.txt" }
}

function WinCondition.new()
    local self = setmetatable({}, WinCondition)
    self.currentLevel = 1
    self.killCount = 0
    self.fragmentCount = 0
    self.bossSpawned = false
    self.isBossDefeated = false
    self.hasDXSample = false
    return self
end

function WinCondition:currentMapPath()
    return self.levels[self.currentLevel].mapPath
end

function WinCondition:currentTarget()
    local config = LevelConfig.getForLevel(self.currentLevel)
    return config.killTarget or 5
end

function WinCondition:currentFragmentTarget()
    local config = LevelConfig.getForLevel(self.currentLevel)
    return config.fragmentTarget or 0
end

function WinCondition:hasAllFragments()
    return self.fragmentCount >= self:currentFragmentTarget()
end

function WinCondition:hasKillTarget()
    return self.killCount >= self:currentTarget()
end

function WinCondition:isLevelComplete()
    -- Non-final levels: reach kill and fragment targets
    if not self:isFinalLevel() then
        return self.killCount >= self:currentTarget() and self:hasAllFragments()
    end
    
    -- Final level: reach targets, defeat boss, and collect the DX sample
    return self.killCount >= self:currentTarget()
        and self:hasAllFragments()
        and self.isBossDefeated
        and self.hasDXSample
end

function WinCondition:isComplete()
    return self:isLevelComplete()
end

function WinCondition:isFinalLevel()
    return self.currentLevel == #self.levels
end

function WinCondition:registerKill()
    if self.killCount >= self:currentTarget() then
        return
    end

    self.killCount = self.killCount + 1
end

function WinCondition:advanceLevel()
    if self.currentLevel < #self.levels then
        self.currentLevel = self.currentLevel + 1
        self.killCount = 0
        self.fragmentCount = 0
        self.bossSpawned = false
        self.isBossDefeated = false
        self.hasDXSample = false
    end
end

function WinCondition:reset()
    self.currentLevel = 1
    self.killCount = 0
    self.fragmentCount = 0
    self.bossSpawned = false
    self.isBossDefeated = false
    self.hasDXSample = false
end

function WinCondition:shouldSpawnBoss()
    return self:isFinalLevel()
        and self.killCount >= self:currentTarget()
        and self:hasAllFragments()
        and not self.bossSpawned
end

function WinCondition:markBossSpawned()
    self.bossSpawned = true
end

function WinCondition:markBossDefeated()
    self.isBossDefeated = true
end

function WinCondition:registerFragment()
    if self.fragmentCount < self:currentFragmentTarget() then
        self.fragmentCount = self.fragmentCount + 1
    end
end

function WinCondition:markDXSampleCollected()
    self.hasDXSample = true
end

return WinCondition
