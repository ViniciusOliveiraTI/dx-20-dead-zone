local Cutscene = {}
Cutscene.__index = Cutscene

local function fitRect(srcW, srcH, dstW, dstH)
    local scale = math.min(dstW / srcW, dstH / srcH)
    local w = srcW * scale
    local h = srcH * scale
    return (dstW - w) / 2, (dstH - h) / 2, scale
end

local function videoCandidates(path)
    local candidates = {}
    local base = path:match("^(.*)%.%w+$")
    if base then
        table.insert(candidates, base .. ".ogv")
        table.insert(candidates, base .. ".ogg")
    end
    table.insert(candidates, path)
    return candidates
end

function Cutscene.new()
    local self = setmetatable({}, Cutscene)
    self.active = false
    self.kind = nil
    self.media = nil
    self.duration = 0
    self.elapsed = 0
    self.onFinish = nil
    self.skipEnabled = false
    self.skipButton = { x = 0, y = 0, width = 120, height = 42 }
    self.videoStarted = false
    self.videoEndGrace = 0.75
    self.errorMessage = nil
    return self
end

local function getVideoDuration(video)
    if not video or not video.getSource then
        return 0
    end

    local source = video:getSource()
    if not source or not source.getDuration then
        return 0
    end

    local ok, duration = pcall(source.getDuration, source, "seconds")
    if ok and duration and duration > 0 then
        return duration
    end

    ok, duration = pcall(source.getDuration, source)
    if ok and duration and duration > 0 then
        return duration
    end

    return 0
end

function Cutscene:playVideo(path, onFinish)
    self:stop()

    local ok, video
    local loadedPath
    local lastError
    for _, candidate in ipairs(videoCandidates(path)) do
        if love.filesystem.getInfo(candidate) then
            ok, video = pcall(love.graphics.newVideo, candidate)
            if ok then
                loadedPath = candidate
                break
            end
            lastError = video
        end
    end

    if not ok then
        print("[Cutscene] Nao foi possivel carregar o video: " .. tostring(lastError or path))
        self.active = true
        self.kind = "error"
        self.media = nil
        self.elapsed = 0
        self.duration = 0
        self.onFinish = onFinish
        self.skipEnabled = true
        self.errorMessage = "Nao foi possivel carregar a cutscene.\nClique em PULAR para iniciar o jogo."
        return false
    end

    self.active = true
    self.kind = "video"
    self.media = video
    self.elapsed = 0
    self.duration = getVideoDuration(video)
    self.onFinish = onFinish
    self.skipEnabled = true
    self.videoStarted = false
    self.errorMessage = nil

    video:play()
    print("[Cutscene] Tocando video: " .. loadedPath)
    return true
end

function Cutscene:showImage(path, duration, onFinish)
    self:stop()

    local ok, image = pcall(love.graphics.newImage, path)
    if not ok then
        print("[Cutscene] Nao foi possivel carregar a imagem: " .. tostring(image))
        if onFinish then
            onFinish()
        end
        return false
    end

    self.active = true
    self.kind = "image"
    self.media = image
    self.elapsed = 0
    self.duration = duration or 5
    self.onFinish = onFinish
    self.skipEnabled = false
    self.videoStarted = false
    self.errorMessage = nil
    return true
end

function Cutscene:stop()
    if self.kind == "video" and self.media then
        self.media:pause()
        self.media:rewind()
    end

    self.active = false
    self.kind = nil
    self.media = nil
    self.elapsed = 0
    self.duration = 0
    self.onFinish = nil
    self.skipEnabled = false
    self.videoStarted = false
    self.errorMessage = nil
end

function Cutscene:finish()
    local onFinish = self.onFinish
    self:stop()
    if onFinish then
        onFinish()
    end
end

function Cutscene:update(dt)
    if not self.active then
        return
    end

    self.elapsed = self.elapsed + dt

    if self.kind == "video" then
        if self.media and self.media:isPlaying() then
            self.videoStarted = true
        elseif self.media and self.videoStarted and self.duration <= 0 then
            self:finish()
        elseif self.duration > 0 and self.elapsed >= self.duration + self.videoEndGrace then
            self:finish()
        end
    elseif self.kind == "image" and self.elapsed >= self.duration then
        self:finish()
    end
end

function Cutscene:draw()
    if not self.active then
        return
    end

    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    if self.media then
        local mw, mh = self.media:getWidth(), self.media:getHeight()
        local x, y, scale = fitRect(mw, mh, sw, sh)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(self.media, x, y, 0, scale, scale)
    elseif self.errorMessage then
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.printf(self.errorMessage, 40, sh / 2 - 32, sw - 80, "center")
    end

    if self.skipEnabled then
        local margin = 24
        local button = self.skipButton
        button.x = sw - button.width - margin
        button.y = sh - button.height - margin

        love.graphics.setColor(0.03, 0.03, 0.03, 0.78)
        love.graphics.rectangle("fill", button.x, button.y, button.width, button.height, 6, 6)
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.rectangle("line", button.x, button.y, button.width, button.height, 6, 6)
        love.graphics.printf("PULAR", button.x, button.y + 12, button.width, "center")
        love.graphics.setColor(1, 1, 1, 1)
    end
end

function Cutscene:mousepressed(x, y, button)
    if not self.active or not self.skipEnabled or button ~= 1 then
        return false
    end

    local rect = self.skipButton
    if x >= rect.x and x <= rect.x + rect.width and y >= rect.y and y <= rect.y + rect.height then
        self:finish()
        return true
    end

    return false
end

return Cutscene
