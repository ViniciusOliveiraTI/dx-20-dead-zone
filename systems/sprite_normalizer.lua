local SpriteLoader = require("core.sprite_loader")

local SpriteNormalizer = {}

local cache = {}
local BASE_TARGET_HEIGHT = 120
local BOSS_TARGET_HEIGHT = 160
local ENTITY_TARGET_HEIGHTS = {
    player = BASE_TARGET_HEIGHT,
    turret = 90,
    ["zombies.normal"] = 150,
    ["zombies.fast"] = 170,
    ["zombies.brute"] = 155,
    ["zombies.boss"] = 190
}
local DEFAULT_TARGET_HEIGHT = BASE_TARGET_HEIGHT
local MIN_SCALE = 0.03
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
        maxDim = DEFAULT_TARGET_HEIGHT
    end

    local targetHeight = ENTITY_TARGET_HEIGHTS[entityKey] or DEFAULT_TARGET_HEIGHT
    local scale = targetHeight / maxDim
    scale = math.max(MIN_SCALE, math.min(MAX_SCALE, scale))

    cache[entityKey] = scale
    return scale
end

return SpriteNormalizer
