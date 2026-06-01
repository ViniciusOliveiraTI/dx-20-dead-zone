local GameState = {}
GameState.__index = GameState

GameState.states = {
    main_menu = "main_menu",
    playing = "playing",
    paused = "paused",
    game_over = "game_over",
    victory = "victory",
    cutscene = "cutscene"
}

function GameState.new()
    local self = setmetatable({}, GameState)
    self.state = GameState.states.main_menu
    return self
end

function GameState:set(state)
    self.state = state
end

function GameState:isPlaying()
    return self.state == GameState.states.playing
end

function GameState:isMainMenu()
    return self.state == GameState.states.main_menu
end

function GameState:isPaused()
    return self.state == GameState.states.paused
end

function GameState:isGameOver()
    return self.state == GameState.states.game_over
end

function GameState:isVictory()
    return self.state == GameState.states.victory
end

function GameState:isCutscene()
    return self.state == GameState.states.cutscene
end

function GameState:canUpdate()
    return self:isPlaying()
end

function GameState:togglePause()
    if self:isPlaying() then
        self:set(GameState.states.paused)
    elseif self:isPaused() then
        self:set(GameState.states.playing)
    end
end

return GameState
