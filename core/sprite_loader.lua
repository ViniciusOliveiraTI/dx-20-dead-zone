local Animation = require("core.animation")
local unpack = table.unpack or unpack

local SpriteLoader = {
    cache = {}
}

local categoryPatterns = {
    { "fire_attack", { "fire_attack", "fire", "breath" } },
    { "melee_attack", { "melee_attack", "melee" } },
    { "shot", { "shot" } },
    { "attack", { "attack" } },
    { "walk", { "walk", "run", "move" } },
    { "idle", { "idle", "stand", "rest" } },
    { "death", { "death", "die", "dead" } }
}

local function containsAny(value, patterns)
    if not value then
        return false
    end
    local lower = value:lower()
    for _, pattern in ipairs(patterns) do
        if lower:find(pattern, 1, true) then
            return true
        end
    end
    return false
end

local function classifyToken(token)
    for _, entry in ipairs(categoryPatterns) do
        local category, patterns = entry[1], entry[2]
        if containsAny(token, patterns) then
            return category
        end
    end
    return nil
end

local function classifySegments(segments)
    for i = #segments, 1, -1 do
        local category = classifyToken(segments[i])
        if category then
            return category
        end
    end
    return nil
end

local function getEntityKey(segments)
    if segments[1] == "zombies" and segments[2] then
        return "zombies." .. segments[2]
    end
    return segments[1]
end

local function extractNumericSuffix(name)
    local base = name:match("(.+)%.%w+$") or name
    local numeric = base:match("(%d+)$")
    return numeric and tonumber(numeric)
end

local function sortNames(a, b)
    local aIndex = extractNumericSuffix(a)
    local bIndex = extractNumericSuffix(b)
    if aIndex and bIndex then
        if aIndex ~= bIndex then
            return aIndex < bIndex
        end
        return a < b
    elseif aIndex then
        return true
    elseif bIndex then
        return false
    end
    return a < b
end

local function loadRawFrames(path)
    local items = love.filesystem.getDirectoryItems(path)
    if not items then
        return nil
    end

    local imageFiles = {}
    for _, item in ipairs(items) do
        if item:match("%.png$") then
            table.insert(imageFiles, item)
        end
    end

    if #imageFiles == 0 then
        return nil
    end

    table.sort(imageFiles, sortNames)
    local frames = {}
    for _, fileName in ipairs(imageFiles) do
        local fullPath = path .. "/" .. fileName
        local image = love.graphics.newImage(fullPath)
        local width, height = image:getDimensions()
        local quad = love.graphics.newQuad(0, 0, width, height, width, height)
        table.insert(frames, {
            image = image,
            quad = quad,
            width = width,
            height = height,
            originX = width / 2,
            originY = height / 2
        })
    end
    return frames
end

local function getFrameDuration(category)
    if category == "idle" then
        return 0.3
    elseif category == "walk" then
        return 0.1
    elseif category == "death" then
        return 0.12
    end
    return 0.1
end

local function buildAnimationsForEntity(rawAnimationSets, targetSize)
    local bestDimension = math.huge
    for _, frames in pairs(rawAnimationSets) do
        for _, frame in ipairs(frames) do
            local size = math.max(frame.width, frame.height)
            if size < bestDimension then
                bestDimension = size
            end
        end
    end

    if bestDimension == math.huge then
        bestDimension = targetSize or 64
    end

    local scale = targetSize and (targetSize / bestDimension) or 1
    local animations = {}

    for category, rawFrames in pairs(rawAnimationSets) do
        local frames = {}
        for _, raw in ipairs(rawFrames) do
            table.insert(frames, {
                image = raw.image,
                quad = raw.quad,
                width = raw.width,
                height = raw.height,
                scale = scale,
                originX = raw.originX,
                originY = raw.originY
            })
        end

        if #frames > 0 then
            local loop = category ~= "death" and category ~= "attack"
            animations[category] = Animation.new(frames, getFrameDuration(category), loop)
        end
    end

    return animations
end

local function scanDirectory(path, segments, rawSets)
    local items = love.filesystem.getDirectoryItems(path)
    if not items then
        return
    end

    local hasImageFiles = false
    for _, item in ipairs(items) do
        local fullPath = path .. "/" .. item
        local info = love.filesystem.getInfo(fullPath)
        if info and info.type == "file" and item:match("%.png$") then
            hasImageFiles = true
            break
        end
    end

    if hasImageFiles then
        local entityKey = getEntityKey(segments)
        if entityKey then
            local category = classifySegments(segments) or "idle"
            local frames = loadRawFrames(path)
            if frames then
                rawSets[entityKey] = rawSets[entityKey] or {}
                rawSets[entityKey][category] = frames
                print("[SpriteLoader] Loaded:", entityKey, category, "#frames=", #frames, "path=", path)
            end
        end
    end

    for _, item in ipairs(items) do
        local fullPath = path .. "/" .. item
        local info = love.filesystem.getInfo(fullPath)
        if info and info.type == "directory" then
            local nextSegments = { unpack(segments) }
            table.insert(nextSegments, item)
            scanDirectory(fullPath, nextSegments, rawSets)
        end
    end
end

local function cloneAnimation(animation)
    if not animation or type(animation.clone) ~= "function" then
        return animation
    end
    return animation:clone()
end

local function cloneAnimationSet(set)
    local clone = {}
    for key, animation in pairs(set) do
        clone[key] = cloneAnimation(animation)
    end
    return clone
end

local function loadAnimations(targetSize)
    local cacheKey = tostring(targetSize or "default")
    if SpriteLoader.cache[cacheKey] then
        return SpriteLoader.cache[cacheKey]
    end

    local sets = {}
    if not love or not love.filesystem then
        SpriteLoader.cache[cacheKey] = sets
        return sets
    end

    local rawSets = {}
    scanDirectory("sprites", {}, rawSets)

    for entityKey, rawAnimationSets in pairs(rawSets) do
        sets[entityKey] = buildAnimationsForEntity(rawAnimationSets, targetSize)
    end

    SpriteLoader.cache[cacheKey] = sets
    print("[SpriteLoader] Animation cache ready for targetSize=", tostring(targetSize or "default"))
    return sets
end

function SpriteLoader.getSet(key, targetSize)
    local allSets = loadAnimations(targetSize)
    local set = allSets[key] or {}
    return cloneAnimationSet(set)
end

return SpriteLoader
