TileSet = love.graphics.newImage('/images/sokoban_tilesheet.png')
TileSize = 64

function love.load()
    -- sprite pos in tilesheet
    quadInfo = {
        {11, 6}, -- ground
        {9, 6}, -- wall
        {0, 3}, -- target
        {1, 0}, -- box
        {0, 4}, -- player
        {1, 1}, -- box on target
    }

    -- objects ID
    -- 0 = ground
    -- 1 = wall
    -- 2 = target
    -- 3 = box
    -- 4 = player
    -- 5 = box on target
    -- 6 = player on target
    levels = {
        -- level 1
        {
            {1, 1, 1, 1, 1, 1},
            {1, 0, 2, 1, 1, 1},
            {1, 0, 0, 1, 1, 1},
            {1, 5, 0, 0, 4, 1},
            {1, 0, 0, 3, 0, 1},
            {1, 0, 0, 1, 1, 1},
            {1, 1, 1, 1, 1, 1}
        },
        -- level 2
        {
            {1, 1, 1, 1, 1, 1},
            {1, 0, 0, 0, 0, 1},
            {1, 0, 1, 4, 0, 1},
            {1, 0, 3, 5, 0, 1},
            {1, 0, 2, 5, 0, 1},
            {1, 0, 0, 0, 0, 1},
            {1, 1, 1, 1, 1, 1}
        }
    }

    levelIndex = 1
    loadLevel()
end

function love.draw()
    drawMap()
end

function loadLevel()
    -- load images
    quads = {}
    for i, info in ipairs(quadInfo) do
        quads[i] = love.graphics.newQuad(info[1] * TileSize, info[2] * TileSize, TileSize, TileSize, TileSet:getDimensions())
    end
    
    -- deep copy level
    level = {}
    for y, row in ipairs(levels[levelIndex]) do
        level[y] = {}
        for x, cell in ipairs(row) do
            level[y][x] = cell
        end
    end
end

function drawMap()
    for columnIndex, row in ipairs(level) do
        for rowIndex, cell in ipairs(row) do
            local x = (rowIndex - 1) * TileSize
            local y = (columnIndex - 1) * TileSize
            love.graphics.draw(TileSet, quads[1], x, y)
            if cell >= 1 and cell <= 4 then
                love.graphics.draw(TileSet, quads[cell + 1], x, y)
            elseif cell == 5 then
                love.graphics.draw(TileSet, quads[6], x, y)
            elseif cell == 6 then
                love.graphics.draw(TileSet, quads[3], x, y)
                love.graphics.draw(TileSet, quads[5], x, y)
            end
        end
    end
end

function love.keypressed(key)
    if key == 'up' or key == 'down' or key == 'left' or key == 'right' or key == 'w' or key == 'a' or key == 's' or key == 'd' then
        local playerX = 0
        local playerY = 0
        local dx = 0
        local dy = 0

        -- get current player position
        for testY, row in ipairs(level) do
            for testX, cell in ipairs(row) do
                if cell == 4 or cell == 6 then
                    playerX = testX
                    playerY = testY
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
        local adjacent = level[playerY + dy][playerX + dx]
        local beyond = level[playerY + dy * 2][playerX + dx * 2]

        -- define moves
        local nextAdjacent = {
            [0] = 4,
            [2] = 6,
        }
        local nextCurrent = {
            [4] = 0,
            [6] = 2,
        }
        local nextBeyond = {
            [0] = 3,
            [2] = 5,
        }
        local nextAdjacentinsert = {
            [3] = 4,
            [5] = 6,
        }

        -- implement moves
        if nextAdjacent[adjacent] then
            level[playerY][playerX] = nextCurrent[current]
            level[playerY + dy][playerX + dx] = nextAdjacent[adjacent]

        elseif nextBeyond[beyond] and nextAdjacentinsert[adjacent] then
            level[playerY][playerX] = nextCurrent[current]
            level[playerY + dy][playerX + dx] = nextAdjacentinsert[adjacent]
            level[playerY + dy * 2][playerX + dx * 2] = nextBeyond[beyond]
        end

        -- check level win
        local complete = true

        for y, row in ipairs(level) do
            for x, cell in ipairs(row) do
                if cell == 2 or cell == 6 then
                    complete = false -- all box on target
                end
            end
        end

        if complete then
            levelIndex = levelIndex + 1
            if levelIndex > #levels then
                levelIndex = 1
            end
            loadLevel()
        end

    -- reset level
    elseif key == 'r' then
        loadLevel()
    end
end