local TileDefs = {
    ["#"] = {
        solid = true,
        color = {0.2, 0.2, 0.2},
        -- path to the wall tile image (place your PNG at sprites/tiles/wall.png)
        spritePath = "sprites/tiles/wall.png"
    },
    ["."] = {
        solid = false,
        color = {0.7, 0.7, 0.7},
        -- path to the floor tile image (place your PNG at sprites/tiles/floor.png)
        spritePath = "sprites/tiles/floor.png"
    }
}

return TileDefs