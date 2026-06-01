local PlayerReloadAction = {}
PlayerReloadAction.__index = PlayerReloadAction

function PlayerReloadAction.new(player, audioManager)
    local self = setmetatable({}, PlayerReloadAction)
    self.player = player
    self.audioManager = audioManager
    return self
end

function PlayerReloadAction:reload()
    local weapon = self.player:getCurrentWeapon()
    if not weapon then
        return false
    end

    if weapon:reload() then
        if self.audioManager then
            self.audioManager:playSoundEffect(weapon.weaponId .. "_reloading")
        end
        return true
    end

    return false
end

function PlayerReloadAction:execute(gameState)
    if not gameState or not gameState:canUpdate() then
        return
    end

    if love.keyboard.isDown("r") then
        self:reload()
    end
end

return PlayerReloadAction
