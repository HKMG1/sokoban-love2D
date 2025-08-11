TileSet = love.graphics.newImage('/images/sokoban_tilesheet.png')
TileSize = 64

function love.load()
    quadInfo = {
        {11, 6}, -- ground
        {9, 6}, -- wall
        {0, 3}, -- target
        {1, 0}, -- box
        {0, 4}, -- player
        {1, 1}, -- box on target
    }

    levels = {
        -- 0 = ground
        -- 1 = wall
        -- 2 = target
        -- 3 = box
        -- 4 = player
        -- 5 = box and target
        -- 6 = player and target

        {
            {1, 1, 1, 1, 1, 1},
            {1, 0, 2, 1, 1, 1},
            {1, 0, 0, 1, 1, 1},
            {1, 5, 0, 0, 4, 1},
            {1, 0, 0, 3, 0, 1},
            {1, 0, 0, 1, 1, 1},
            {1, 1, 1, 1, 1, 1}
        },
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

    currentLevel = 1
    loadLevel()
end

function love.draw()
    drawMap()
end

function loadLevel()
    local tileSetW, tileSetH = TileSet:getWidth(), TileSet:getHeight()

    quads = {}
    for i, info in ipairs(quadInfo) do
        quads[i] = love.graphics.newQuad(info[1] * TileSize, info[2] * TileSize, TileSize, TileSize, tileSetW, tileSetH)
    end
    
    level = {}
    for y, row in ipairs(levels[currentLevel]) do
        level[y] = {}
        for x, cell in ipairs(row) do
            level[y][x] = cell
        end
    end
end

function map2World(mx, my)
    return (my - 1) * TileSize, (mx - 1) * TileSize
end

function drawMap()
    for columnIndex, row in ipairs(level) do
        for rowIndex, cell in ipairs(row) do
            local x, y = map2World(rowIndex, columnIndex)
            love.graphics.draw(TileSet, quads[1], y, x)
            if cell >= 1 and cell <= 4 then
                love.graphics.draw(TileSet, quads[cell + 1], y, x)
            elseif cell == 5 then
                love.graphics.draw(TileSet, quads[6], y, x)
            elseif cell == 6 then
                love.graphics.draw(TileSet, quads[3], y, x)
                love.graphics.draw(TileSet, quads[5], y, x)
            end
        end
    end
end

function love.keypressed(key)
    if key == 'up' or key == 'down' or key == 'left' or key == 'right' or key == 'w' or key == 'a' or key == 's' or key == 'd' then
        local playerX, playerY
        local dx, dy = 0, 0

        for testY, row in ipairs(level) do
            for testX, cell in ipairs(row) do
                if cell == 4 or cell == 6 then
                    playerX = testX
                    playerY = testY
                end
            end
        end

        if key == 'left' or key == 'a' then
            dx = -1
        elseif key == 'right' or key == 'd' then
            dx = 1
        elseif key == 'up' or key == 'w' then
            dy = -1
        elseif key == 'down' or key == 's' then
            dy = 1
        end

        local current = level[playerY][playerX]
        local adjacent = level[playerY + dy][playerX + dx]
        local beyond
        if level[playerY + dy * 2] then
            beyond = level[playerY + dy * 2][playerX + dx * 2]
        end

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
        local nextAdjacentPush = {
            [3] = 4,
            [5] = 6,
        }

        if nextAdjacent[adjacent] then
            level[playerY][playerX] = nextCurrent[current]
            level[playerY + dy][playerX + dx] = nextAdjacent[adjacent]

        elseif nextBeyond[beyond] and nextAdjacentPush[adjacent] then
            level[playerY][playerX] = nextCurrent[current]
            level[playerY + dy][playerX + dx] = nextAdjacentPush[adjacent]
            level[playerY + dy * 2][playerX + dx * 2] = nextBeyond[beyond]
        end

        local complete = true

        for y, row in ipairs(level) do
            for x, cell in ipairs(row) do
                if cell == 3 then
                    complete = false
                end
            end
        end

        if complete then
            currentLevel = currentLevel + 1
            if currentLevel > #levels then
                currentLevel = 1
            end
            loadLevel()
        end

    elseif key == 'r' then
        loadLevel()
    end
end