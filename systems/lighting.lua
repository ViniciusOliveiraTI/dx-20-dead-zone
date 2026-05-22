local Lighting = {}

function Lighting.new(screenWidth, screenHeight)
    local self = {}
    self.screenWidth = screenWidth
    self.screenHeight = screenHeight

    self.defaultRadius = 200
    self.defaultSoftness = 45

    local shaderCode = [[
        extern vec2 lightPos;
        extern number radius;
        extern number softness;
        extern number angle;
        extern vec3 darkColor;

        vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc)
        {
            vec2 toPixel = sc - lightPos;

            float dist = length(toPixel);
            vec2 dirToPixel = normalize(toPixel);

            // direção da lanterna
            vec2 dir = vec2(cos(angle), sin(angle));

            // cone de 45 graus
            float coneAngle = radians(60.0);
            float coneLimit = cos(coneAngle * 0.5);

            float d = dot(dir, dirToPixel);

            // suavidade lateral
            float angleMask = smoothstep(coneLimit, coneLimit + 0.05, d);

            // alcance
            float distMask = 1.0 - smoothstep(radius - softness, radius, dist);

            // ponta arredondada
            float frontFade = smoothstep(radius - softness * 1.5, radius, dist);
            distMask *= (1.0 - frontFade * 0.6);

            float t = angleMask * distMask;

            // cor da lanterna
            vec3 lightColor = vec3(1.0, 0.9, 0.6);

            vec3 finalLight = lightColor * (0.85 + 0.35 * t);

            vec3 col = mix(darkColor, finalLight, t);

            return vec4(col, 1.0);
        }
    ]]

    if love and love.graphics and love.graphics.newShader then
        local ok, sh = pcall(love.graphics.newShader, shaderCode)
        if ok then
            self.shader = sh

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

    local mx, my = love.mouse.getPosition()
    local angle = math.atan2(my - playerY, mx - playerX)

    if self.shader then
        love.graphics.setShader(self.shader)

        self.shader:send("lightPos", {playerX, playerY})
        self.shader:send("radius", radius)
        self.shader:send("softness", softness)
        self.shader:send("angle", angle)

        love.graphics.setBlendMode("multiply", "premultiplied")
        love.graphics.setColor(1, 1, 1, 1)

        love.graphics.rectangle("fill", 0, 0, self.screenWidth, self.screenHeight)

        love.graphics.setShader()
        love.graphics.setBlendMode("alpha")
        love.graphics.setColor(1, 1, 1, 1)
        return
    end

    -- fallback
    love.graphics.setBlendMode("multiply", "premultiplied")
    love.graphics.setColor(0.1, 0.1, 0.1, 1)
    love.graphics.rectangle("fill", 0, 0, self.screenWidth, self.screenHeight)

    -- pequena luz circular (fallback simples)
    for i = 0, 10 do
        local t = i / 10
        local r = 70 * (1 - t)
        local a = 0.6 * (1 - t)

        love.graphics.setColor(1.0, 0.9, 0.6, a)
        love.graphics.circle("fill", playerX, playerY, r)
    end

    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(1, 1, 1, 1)
end

return Lighting