local TileDefs = require("core.tile_definitions")

local Map = {}
Map.__index = Map

function Map.new(tileSize)
    local self = setmetatable({}, Map)

    self.tileSize = tileSize or 32
    self.tiles = {}
    self.width = 0
    self.height = 0
    self.playerSpawn = nil
    self.enemySpawns = {}
    self.turretSpawns = {}
    self.bossSpawn = nil
    self.rifleSpawn = nil
    self.fragmentSpawns = {}

    return self
end

function Map:loadFromFile(path)
    self.tiles = {}
    self.width = 0
    self.height = 0
    self.playerSpawn = nil
    self.enemySpawns = {}
    self.turretSpawns = {}
    self.bossSpawn = nil
    self.rifleSpawn = nil
    self.fragmentSpawns = {}

    local y = 1
    for line in love.filesystem.lines(path) do
        self.tiles[y] = {}
        self.width = math.max(self.width, #line)

        for x = 1, #line do
            local char = line:sub(x, x)

            if char == "P" then
                self.playerSpawn = {
                    x = (x - 1) * self.tileSize,
                    y = (y - 1) * self.tileSize
                }
                char = "."
            elseif char == "S" then
                table.insert(self.enemySpawns, {
                    x = (x - 1) * self.tileSize,
                    y = (y - 1) * self.tileSize
                })
                char = "."
            elseif char == "T" then
                table.insert(self.turretSpawns, {
                    x = (x - 1) * self.tileSize,
                    y = (y - 1) * self.tileSize
                })
                char = "."
            elseif char == "B" then
                self.bossSpawn = {
                    x = (x - 1) * self.tileSize,
                    y = (y - 1) * self.tileSize
                }
                char = "."
            elseif char == "G" then
                self.rifleSpawn = {
                    x = (x - 1) * self.tileSize,
                    y = (y - 1) * self.tileSize
                }
                char = "."
            elseif char == "F" then
                table.insert(self.fragmentSpawns, {
                    x = (x - 1) * self.tileSize + self.tileSize / 2,
                    y = (y - 1) * self.tileSize + self.tileSize / 2
                })
                char = "."
            end

            self.tiles[y][x] = char
        end

        y = y + 1
    end

    self.height = y - 1
    self:validateSpawnPoints()
end

function Map:isSolidTile(tx, ty)
    local row = self.tiles[ty]
    if not row then
        return false
    end

    local char = row[tx]
    if not char then
        return false
    end

    local def = TileDefs[char]
    return def and def.solid
end

function Map:tileCoords(x, y)
    return math.floor(x / self.tileSize) + 1, math.floor(y / self.tileSize) + 1
end

function Map:isWalkableTile(tx, ty)
    if tx < 1 or ty < 1 or tx > self.width or ty > self.height then
        return false
    end
    return not self:isSolidTile(tx, ty)
end

function Map:collidesWithRect(x, y, w, h)
    local ts = self.tileSize

    local startX = math.floor(x / ts) + 1
    local endX = math.floor((x + w - 1) / ts) + 1
    local startY = math.floor(y / ts) + 1
    local endY = math.floor((y + h - 1) / ts) + 1

    for ty = startY, endY do
        for tx = startX, endX do
            if self:isSolidTile(tx, ty) then
                return true
            end
        end
    end

    return false
end

function Map:findReachableTiles(startTx, startTy)
    local reachable = {}
    local queue = {{x = startTx, y = startTy}}
    reachable[startTy] = {[startTx] = true}

    local directions = {
        {x = 1, y = 0},
        {x = -1, y = 0},
        {x = 0, y = 1},
        {x = 0, y = -1}
    }

    while #queue > 0 do
        local current = table.remove(queue, 1)
        for _, dir in ipairs(directions) do
            local tx = current.x + dir.x
            local ty = current.y + dir.y
            if self:isWalkableTile(tx, ty) and not (reachable[ty] and reachable[ty][tx]) then
                reachable[ty] = reachable[ty] or {}
                reachable[ty][tx] = true
                table.insert(queue, {x = tx, y = ty})
            end
        end
    end

    return reachable
end

function Map:findNearestReachableTile(x, y, reachable)
    local tx, ty = self:tileCoords(x, y)
    local best = nil
    local bestDistance = math.huge
    for ry, row in pairs(reachable) do
        for rx, _ in pairs(row) do
            local distance = math.abs(rx - tx) + math.abs(ry - ty)
            if distance < bestDistance then
                bestDistance = distance
                best = {
                    x = (rx - 1) * self.tileSize,
                    y = (ry - 1) * self.tileSize
                }
            end
        end
    end
    return best
end

function Map:repairSpawnList(list, reachable)
    local repaired = {}
    for _, spawn in ipairs(list) do
        local tx, ty = self:tileCoords(spawn.x, spawn.y)
        if reachable[ty] and reachable[ty][tx] then
            table.insert(repaired, spawn)
        else
            local fallback = self:findNearestReachableTile(spawn.x, spawn.y, reachable)
            if fallback then
                table.insert(repaired, fallback)
            end
        end
    end
    return repaired
end

function Map:validateSpawnPoints()
    if not self.playerSpawn then
        return
    end

    local startTx, startTy = self:tileCoords(self.playerSpawn.x, self.playerSpawn.y)
    if not self:isWalkableTile(startTx, startTy) then
        return
    end

    local reachable = self:findReachableTiles(startTx, startTy)
    self.enemySpawns = self:repairSpawnList(self.enemySpawns, reachable)
    self.turretSpawns = self:repairSpawnList(self.turretSpawns, reachable)
    self.fragmentSpawns = self:repairSpawnList(self.fragmentSpawns, reachable)

    if self.bossSpawn then
        local btX, btY = self:tileCoords(self.bossSpawn.x, self.bossSpawn.y)
        if not (reachable[btY] and reachable[btY][btX]) then
            local fallback = self:findNearestReachableTile(self.bossSpawn.x, self.bossSpawn.y, reachable)
            self.bossSpawn = fallback or self.bossSpawn
        end
    end
end

function Map:draw()
    for y = 1, self.height do
        for x = 1, self.width do
            local char = self.tiles[y][x]
            local def = TileDefs[char]

            if def then
                -- If a sprite path is provided, attempt lazy load and draw the image
                if def.spritePath then
                    if not def._spriteImage and love and love.graphics and love.graphics.newImage then
                        local ok, img = pcall(love.graphics.newImage, def.spritePath)
                        if ok and img then
                            def._spriteImage = img
                            local iw, ih = img:getDimensions()
                            def._spriteScale = { x = self.tileSize / iw, y = self.tileSize / ih }
                            def._spriteOrig = { x = iw / 2, y = ih / 2 }
                        end
                    end

                    if def._spriteImage then
                        local img = def._spriteImage
                        local s = def._spriteScale or { x = 1, y = 1 }
                        love.graphics.setColor(1, 1, 1)
                        love.graphics.draw(
                            img,
                            (x - 1) * self.tileSize + self.tileSize / 2,
                            (y - 1) * self.tileSize + self.tileSize / 2,
                            0,
                            s.x,
                            s.y,
                            def._spriteOrig.x,
                            def._spriteOrig.y
                        )
                    else
                        love.graphics.setColor(def.color)
                        love.graphics.rectangle(
                            "fill",
                            (x - 1) * self.tileSize,
                            (y - 1) * self.tileSize,
                            self.tileSize,
                            self.tileSize
                        )
                    end
                else
                    love.graphics.setColor(def.color)
                    love.graphics.rectangle(
                        "fill",
                        (x - 1) * self.tileSize,
                        (y - 1) * self.tileSize,
                        self.tileSize,
                        self.tileSize
                    )
                end
            end
        end
    end

    -- Draw rifle spawn if available
    if self.rifleSpawn and not self._rifleImage then
        local ok, img = pcall(love.graphics.newImage, "sprites/items/rifle.png")
        if ok and img then
            self._rifleImage = img
        end
    end

    if self.rifleSpawn and self._rifleImage then
        local iw, ih = self._rifleImage:getDimensions()
        local scale = math.min(self.tileSize / iw, self.tileSize / ih, 1)
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(
            self._rifleImage,
            self.rifleSpawn.x + self.tileSize / 2,
            self.rifleSpawn.y + self.tileSize / 2,
            0,
            scale,
            scale,
            iw / 2,
            ih / 2
        )
    end

    love.graphics.setColor(1, 1, 1)
end

return Map
