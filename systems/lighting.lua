local Lighting = {}

function Lighting.new(screenWidth, screenHeight)
    local self = {}
    self.screenWidth = screenWidth
    self.screenHeight = screenHeight
    -- default softness and radius
    self.defaultRadius = 150
    self.defaultSoftness = 60

    -- radial light shader: outputs a color between darkColor and white based on distance to light
    local shaderCode = [[
        extern vec2 lightPos;
        extern number radius;
        extern number softness;
        extern vec3 darkColor;

        vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
            float dx = sc.x - lightPos.x;
            float dy = sc.y - lightPos.y;
            float dist = sqrt(dx*dx + dy*dy);

            float edge0 = radius - softness;
            float t = 1.0 - smoothstep(edge0, radius, dist);

            // 🔥 NOVO: tom amarelado suave
            vec3 lightColor = vec3(1.0, 0.95, 0.85);

            vec3 col = mix(darkColor, lightColor, t);
            return vec4(col, 1.0);
        }
    ]]

    if love and love.graphics and love.graphics.newShader then
        local ok, sh = pcall(love.graphics.newShader, shaderCode)
        if ok then
            self.shader = sh
            -- sensible defaults
            self.shader:send("darkColor", {0.18, 0.18, 0.16})
            self.shader:send("radius", self.defaultRadius)
            self.shader:send("softness", self.defaultSoftness)
        else
            self.shader = nil
        end
    else
        self.shader = nil
    end
    return setmetatable(self, { __index = Lighting })
end

function Lighting:resize(w, h)
    self.screenWidth = w
    self.screenHeight = h
end

function Lighting:draw(playerX, playerY, radius)
    radius = radius or self.defaultRadius
    local softness = self.defaultSoftness

    -- If shader available, draw full-screen rectangle with shader using multiply blend mode
    if self.shader then
        love.graphics.setShader(self.shader)
        self.shader:send("lightPos", {playerX, playerY})
        self.shader:send("radius", radius)
        self.shader:send("softness", softness)

        love.graphics.setBlendMode("multiply", "premultiplied")
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", 0, 0, self.screenWidth, self.screenHeight)
        love.graphics.setShader()
        love.graphics.setBlendMode("alpha")
        love.graphics.setColor(1, 1, 1, 1)
        return
    end

    -- Fallback: approximate soft circle using multiple concentric circles
    love.graphics.setBlendMode("multiply", "premultiplied")
    love.graphics.setColor(0.08, 0.08, 0.08, 1)
    love.graphics.rectangle("fill", 0, 0, self.screenWidth, self.screenHeight)
    love.graphics.setColor(1, 1, 1, 1)
    for i = 0, 10 do
        local t = i / 10
        local r = radius * (1.0 - t * 0.6)
        local a = 1.0 - t
        love.graphics.setColor(1, 1, 1, a)
        love.graphics.circle("fill", playerX, playerY, r)
    end
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(1, 1, 1, 1)
end

return Lighting
