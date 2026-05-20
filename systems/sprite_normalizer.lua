local SpriteLoader = require("core.sprite_loader")

local SpriteNormalizer = {}

local cache = {}
local STANDARD_TARGET_HEIGHT = 160
local BOSS_TARGET_HEIGHT = 220
local MIN_SCALE = 0.25
local MAX_SCALE = 2.0

local function getMaxFrameDimension(set)
    local maxDim = 0
    for _, anim in pairs(set) do
        if anim and anim.frames then
            for i = 1, #anim.frames do
                local f = anim.frames[i]
                if f and f.width and f.height then
                    maxDim = math.max(maxDim, f.width, f.height)
                end
            end
        end
    end
    return maxDim
end

function SpriteNormalizer.getScale(entityKey)
    if cache[entityKey] ~= nil then
        return cache[entityKey]
    end

    local set = SpriteLoader.getSet(entityKey) or {}
    local maxDim = getMaxFrameDimension(set)
    if maxDim == 0 then
        maxDim = STANDARD_TARGET_HEIGHT
    end

    local targetHeight = STANDARD_TARGET_HEIGHT
    if entityKey == "zombies.boss" then
        targetHeight = BOSS_TARGET_HEIGHT
    end

    local scale = targetHeight / maxDim
    scale = math.max(MIN_SCALE, math.min(MAX_SCALE, scale))

    cache[entityKey] = scale
    return scale
end

return SpriteNormalizer
