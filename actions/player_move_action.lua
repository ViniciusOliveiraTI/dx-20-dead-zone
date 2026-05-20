local PlayerMoveAction = {}
PlayerMoveAction.__index = PlayerMoveAction

function PlayerMoveAction.new(player)
    local self = setmetatable({}, PlayerMoveAction)
    self.player = player
    return self
end

function PlayerMoveAction:execute(dt, gameMap, gameState)
    if not gameState or not gameState:canUpdate() then
        self.player.isMoving = false
        return
    end

    if not self.player:isAlive() then
        self.player.isMoving = false
        return
    end

    local dx, dy = 0, 0

    if love.keyboard.isDown("w", "up") then dy = dy - 1 end
    if love.keyboard.isDown("s", "down") then dy = dy + 1 end
    if love.keyboard.isDown("a", "left") then dx = dx - 1 end
    if love.keyboard.isDown("d", "right") then dx = dx + 1 end

    local isMoving = dx ~= 0 or dy ~= 0
    self.player.isMoving = isMoving

    if isMoving then
        local len = math.sqrt(dx*dx + dy*dy)
        dx, dy = dx / len, dy / len
    end

    local px = self.player.x
    local py = self.player.y
    local sp = self.player.speed * dt

    local nextX = px + dx * sp
    if not gameMap:collidesWithRect(
        nextX, py,
        self.player.width, self.player.height
    ) then
        self.player.x = nextX
    end

    local nextY = py + dy * sp
    if not gameMap:collidesWithRect(
        self.player.x, nextY,
        self.player.width, self.player.height
    ) then
        self.player.y = nextY
    end
end

return PlayerMoveAction
