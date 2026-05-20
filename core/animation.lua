local Animation = {}
Animation.__index = Animation

local function sortNames(a, b)
    return a < b
end

local function canUseFileSystem()
    return love and love.filesystem and love.filesystem.getInfo and love.filesystem.getDirectoryItems
end

local function buildFrame(image, targetSize)
    local width, height = image:getDimensions()
    local quad = love.graphics.newQuad(0, 0, width, height, width, height)
    local scale = targetSize and (targetSize / math.max(width, height)) or 1

    return {
        image = image,
        quad = quad,
        width = width,
        height = height,
        scale = scale,
        originX = width / 2,
        originY = height / 2
    }
end

function Animation.loadFramesFromDirectory(directory, extensionPattern, targetSize)
    extensionPattern = extensionPattern or "%.png$"
    local frames = {}

    if not canUseFileSystem() then
        return frames
    end

    if not love.filesystem.getInfo(directory, "directory") then
        return frames
    end

    local fileNames = love.filesystem.getDirectoryItems(directory)
    table.sort(fileNames, sortNames)

    for _, filename in ipairs(fileNames) do
        if filename:match(extensionPattern) then
            local path = directory .. "/" .. filename
            local image = love.graphics.newImage(path)
            if image then
                table.insert(frames, buildFrame(image, targetSize))
            end
        end
    end

    return frames
end

function Animation.loadSpriteSheet(path, frameWidth, frameHeight, targetSize)
    local frames = {}
    if not love or not love.graphics then
        return frames
    end

    local image = love.graphics.newImage(path)
    local sheetWidth, sheetHeight = image:getDimensions()

    for y = 0, sheetHeight - frameHeight, frameHeight do
        for x = 0, sheetWidth - frameWidth, frameWidth do
            local quad = love.graphics.newQuad(x, y, frameWidth, frameHeight, sheetWidth, sheetHeight)
            local scale = targetSize and (targetSize / math.max(frameWidth, frameHeight)) or 1
            table.insert(frames, {
                image = image,
                quad = quad,
                width = frameWidth,
                height = frameHeight,
                scale = scale,
                originX = frameWidth / 2,
                originY = frameHeight / 2
            })
        end
    end

    return frames
end

function Animation.new(frames, frameDuration, loop)
    local self = setmetatable({}, Animation)
    self.frames = frames or {}
    self.frameDuration = frameDuration or 0.1
    self.loop = loop ~= false
    self.timer = 0
    self.currentIndex = 1
    return self
end

function Animation:reset()
    self.timer = 0
    self.currentIndex = 1
end

function Animation:clone()
    local copy = Animation.new(self.frames, self.frameDuration, self.loop)
    copy.timer = self.timer
    copy.currentIndex = self.currentIndex
    return copy
end

function Animation:update(dt)
    if #self.frames <= 1 then
        return
    end

    self.timer = self.timer + dt
    while self.timer >= self.frameDuration do
        self.timer = self.timer - self.frameDuration
        self.currentIndex = self.currentIndex + 1

        if self.currentIndex > #self.frames then
            if self.loop then
                self.currentIndex = 1
            else
                self.currentIndex = #self.frames
                break
            end
        end
    end
end

function Animation:currentFrame()
    return self.frames[self.currentIndex]
end

function Animation:getCurrentIndex()
    return self.currentIndex
end

function Animation:getFrameCount()
    return #self.frames
end

function Animation:getFrameDuration()
    return self.frameDuration
end

function Animation:draw(x, y, rotation, extraScale, alpha)
    local frame = self:currentFrame()
    if not frame or not frame.quad then
        return
    end

    local scale = frame.scale * (extraScale or 1)
    love.graphics.setColor(1, 1, 1, alpha or 1)
    love.graphics.draw(frame.image, frame.quad, x, y, rotation or 0, scale, scale, frame.originX, frame.originY)
    love.graphics.setColor(1, 1, 1, 1)
end

return Animation
