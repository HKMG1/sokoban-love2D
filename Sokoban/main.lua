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

    levelIndex = 1
    loadQuad()
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

-- deep copy level
function loadLevel()
    level = {}
    for y, row in ipairs(levels[levelIndex]) do
        level[y] = {}
        for x, cell in ipairs(row) do
            level[y][x] = cell
        end
    end

    undoStack = {}
    change = {}
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
    if key == 'up' or key == 'down' or key == 'left' or key == 'right' or key == 'w' or key == 'a' or key == 's' or key == 'd' then
        local playerX, playerY
        local dx = 0
        local dy = 0

        -- get player position
        for y, row in ipairs(level) do
            for x, cell in ipairs(row) do
                if cell == 4 or cell == 6 then
                    playerX = x
                    playerY = y
                end
            end
        end

        -- set player position change
        if key == 'left' or key == 'a' then
            dx = -1
        elseif key == 'right' or key == 'd' then
            dx = 1
        elseif key == 'up' or key == 'w' then
            dy = -1
        elseif key == 'down' or key == 's' then
            dy = 1
        end

        -- get info about surroundings
        local current = level[playerY][playerX]
        local adjacent, beyond
        if level[playerY + dy] and level[playerY + dy][playerX + dx] then
            adjacent = level[playerY + dy][playerX + dx]
        end
        if level[playerY + dy * 2] and level[playerY + dy * 2][playerX + dx * 2] then
            beyond = level[playerY + dy * 2][playerX + dx * 2]
        end

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

        -- save level
        change[1] = {playerX, playerY, current}
        change[2] = {playerX + dx, playerY + dy, adjacent}
        change[3] = {playerX + dx * 2, playerY + dy * 2, beyond}

        -- implement moves
        if nextAdjacent[adjacent] then
            level[playerY][playerX] = nextCurrent[current]
            level[playerY + dy][playerX + dx] = nextAdjacent[adjacent]
            saveLevel()
        elseif nextAdjacentInsert[adjacent] and nextBeyond[beyond] then
            level[playerY][playerX] = nextCurrent[current]
            level[playerY + dy][playerX + dx] = nextAdjacentInsert[adjacent]
            level[playerY + dy * 2][playerX + dx * 2] = nextBeyond[beyond]
            saveLevel()
        end

        -- multipush
        -- [ > movable | crate ] -> [ > movable | > crate ]
        -- flood fill to find nearest non-crate

        -- check level win
        -- all crate on target
        local levelWin = true

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

    -- reset level
    elseif key == 'r' then
        loadLevel()
    -- undo level
    elseif key == 'z' then
        undoLevel()
    end
end

function saveLevel()
    table.insert(undoStack, change)
    change = {}
end

function undoLevel()
    if #undoStack > 0 then
        while #undoStack[#undoStack] > 0 do
            local change = table.remove(undoStack[#undoStack])
            level[change[2]][change[1]] = change[3]
        end
        table.remove(undoStack)
    end
end