local PlayerReloadAction = {}
PlayerReloadAction.__index = PlayerReloadAction

function PlayerReloadAction.new(player)
    local self = setmetatable({}, PlayerReloadAction)
    self.player = player
    return self
end

function PlayerReloadAction:execute(gameState)
    if not gameState or not gameState:canUpdate() then
        return
    end

    local weapon = self.player:getCurrentWeapon()
    if not weapon then
        return
    end

    if love.keyboard.isDown("r") then
        weapon:reload()
    end
end

return PlayerReloadAction
