-- const
TileSize = 64

function love.load()
    tileSet = love.graphics.newImage('/images/sokoban_tilesheet.png')

    -- sprite pos in tilesheet
    quadInfo = {
        { 11, 6 }, -- ground
        { 9, 6 }, -- wall
        { 0, 3 }, -- target
        { 1, 0 }, -- crate
        { 0, 4 }, -- player
        { 1, 1 }, -- crate on target
    }

    -- objects ID
    -- 0 = ground
    -- 1 = wall
    -- 2 = target
    -- 3 = crate
    -- 4 = player
    -- 5 = crate on target
    -- 6 = player on target
    levels = {
        -- level 1: 6x7
        {
            { 1, 1, 1, 1, 1, 1 },
            { 1, 0, 2, 1, 1, 1 },
            { 1, 0, 0, 1, 1, 1 },
            { 1, 5, 0, 0, 4, 1 },
            { 1, 0, 0, 3, 0, 1 },
            { 1, 0, 0, 1, 1, 1 },
            { 1, 1, 1, 1, 1, 1 }
        },
        -- level 2: 6x7
        {
            { 1, 1, 1, 1, 1, 1 },
            { 1, 0, 0, 0, 0, 1 },
            { 1, 0, 1, 4, 0, 1 },
            { 1, 0, 3, 5, 0, 1 },
            { 1, 0, 2, 5, 0, 1 },
            { 1, 0, 0, 0, 0, 1 },
            { 1, 1, 1, 1, 1, 1 }
        }
    }

    loadQuad()
    levelIndex = 1
    loadLevel()
end

function love.draw()
    drawMap()
end

function loadQuad()
    quads = {}
    for i, info in ipairs(quadInfo) do
        quads[i] = love.graphics.newQuad(info[1] * TileSize, info[2] * TileSize, TileSize, TileSize, tileSet:getDimensions())
    end
end

function loadLevel()
    level = deepcopy(levels[levelIndex])

    undoStack = {}
    redoStack = {}
end

function deepcopy(orig)
    local copy
    if type(orig) == 'table' then
        copy = {}
        for y, row in ipairs(orig) do
            copy[y] = {}
            for x, cell in ipairs(row) do
                copy[y][x] = cell
            end
        end
    else
        copy = orig
    end
    return copy
end

function drawMap()
    for columnIndex, row in ipairs(level) do
        for rowIndex, cell in ipairs(row) do
            local x = (rowIndex - 1) * TileSize
            local y = (columnIndex - 1) * TileSize
            love.graphics.draw(tileSet, quads[1], x, y)
            if cell >= 1 and cell <= 5 then
                love.graphics.draw(tileSet, quads[cell + 1], x, y)
            elseif cell == 6 then
                love.graphics.draw(tileSet, quads[3], x, y)
                love.graphics.draw(tileSet, quads[5], x, y)
            end
        end
    end
end

function love.keypressed(key)       
    local dx = 0
    local dy = 0

    if key == 'left' or key == 'a' then
        dx = -1
    elseif key == 'right' or key == 'd' then
        dx = 1
    elseif key == 'up' or key == 'w' then
        dy = -1
    elseif key == 'down' or key == 's' then
        dy = 1
    elseif key == 'r' then 
        loadLevel() 
        return
    elseif key == 'z' then
        undoLevel()
        return
    elseif key == 'c' then
        redoLevel()
        return
    else 
        return
    end

    attemptMove(dx, dy)
    checkWinCondition()
end

function saveLevel()
    table.insert(undoStack, deepcopy(level))
    redoStack = {}
end

function undoLevel()
    if #undoStack > 0 then
        table.insert(redoStack, deepcopy(level))
        level = table.remove(undoStack)
    end
end

function redoLevel()
    if #redoStack > 0 then
        table.insert(undoStack, deepcopy(level))
        level = table.remove(redoStack)
    end
end

function attemptMove(dx, dy)
    -- get forward info
    local playerX, playerY = getPlayerPosition()
    local forwardPos = {}
    for i = 1, 3 do
        forwardPos[i] = level[playerY + dy * (i - 1)][playerX + dx * (i - 1)]
    end

    local nextState = getNextState(forwardPos)
    if nextState then
        saveLevel()

        -- apply move
        level[playerY][playerX] = nextState[1]
        level[playerY + dy][playerX + dx] = nextState[2]
        if nextState[3] then
            level[playerY + dy * 2][playerX + dx * 2] = nextState[3]
        end
    end
end

function getPlayerPosition()
    for y, row in ipairs(level) do
        for x, cell in ipairs(row) do
            if cell == 4 or cell == 6 then
                return x, y
            end
        end
    end
end

function getNextState(forwardPos)
    -- define moves
    local nextAdjacent = {
        [0] = 4, -- [ > player | ] -> [ | player ]
        [2] = 6, -- [ > player | target ] -> [ | player target ]
    }
    local nextCurrent = {
        [4] = 0, -- [ > player | ] -> [ | player ]
        [6] = 2, -- [ > player target | ] -> [ target | player ]
    }
    local nextBeyond = {
        [0] = 3, -- [ > crate | ] -> [ | crate ]
        [2] = 5, -- [ > crate | target ] -> [ | crate target ]
    }
    local nextAdjacentInsert = {
        [3] = 4, -- [ > crate | ] -> [ | crate ]
        [5] = 6, -- [ > crate target ] -> [ target | crate ]
    }

    -- multipush
    -- [ > movable | crate ] -> [ > movable | > crate ]
    -- flood fill to find nearest non-crate

    if nextAdjacent[forwardPos[2]] then
        return {nextCurrent[forwardPos[1]], nextAdjacent[forwardPos[2]], nil}
    elseif nextAdjacentInsert[forwardPos[2]] and nextBeyond[forwardPos[3]] then
        return {nextCurrent[forwardPos[1]], nextAdjacentInsert[forwardPos[2]], nextBeyond[forwardPos[3]]}
    else
        return nil
    end
end

function checkWinCondition()
    local levelWin = true
    -- all target on crate
    for y, row in ipairs(level) do
        for x, cell in ipairs(row) do
            if cell == 2 or cell == 6 then
                levelWin = false
            end
        end
    end

    if levelWin then
        levelIndex = levelIndex + 1
        if levelIndex > #levels then
            -- should have ending
            levelIndex = 1
        end
        loadLevel()
    end
end