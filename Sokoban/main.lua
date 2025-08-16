-- for debug
io.stdout:setvbuf("no")

-- const
TileSize = 64

-- feature
EnableMultipush = false
EnablePull = false

function love.load()
    tileSet = love.graphics.newImage('/images/sokoban_tilesheet.png')

    --[[
    sprite pos in tilesheet:
    1 = ground
    2 = wall
    3 = target
    4 = crate
    5 = player
    6 = crate on target
    ]] 
    quadInfo = {
        { 11, 6 },
        { 9, 6 },
        { 0, 3 },
        { 1, 0 },
        { 0, 4 },
        { 1, 1 }
    }

    --[[ 
    background object ID:
    0 = empty
    1 = wall
    2 = target

    entity object ID:
    0 = empty
    1 = player
    2 = crate
    ]]
    levels = {
        -- level 1
        {
            background = {
                { 1, 1, 1, 1, 1, 1 },
                { 1, 0, 2, 1, 1, 1 },
                { 1, 0, 0, 1, 1, 1 },
                { 1, 2, 0, 0, 0, 1 },
                { 1, 0, 0, 0, 0, 1 },
                { 1, 0, 0, 1, 1, 1 },
                { 1, 1, 1, 1, 1, 1 }
            },
            entity = {
                { 0, 0, 0, 0, 0, 0 },
                { 0, 0, 0, 0, 0, 0 },
                { 0, 0, 0, 0, 0, 0 },
                { 0, 2, 0, 0, 1, 0 },
                { 0, 0, 0, 2, 0, 0 },
                { 0, 0, 0, 0, 0, 0 },
                { 0, 0, 0, 0, 0, 0 }
            }
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
    level = { background, entity }
    level.background = deepCopy(levels[levelIndex].background)
    level.entity = deepCopy(levels[levelIndex].entity)

    offsetX, offsetY = getOffset()

    undoStack = {}
    redoStack = {}
end

function deepCopy(orig)
    local copy
    if type(orig) == 'table' then
        copy = {}
        for y, row in ipairs(orig) do
            copy[y] = {}
            for x, tile in ipairs(row) do
                copy[y][x] = tile
            end
        end
    else
        copy = orig
    end
    return copy
end

function getOffset()
    local levelWidth = #level.background[1] * TileSize
    local levelHeight = #level.background * TileSize
    local windowWidth, windowHeight = love.graphics.getDimensions()
    return (windowWidth - levelWidth) * 0.5, (windowHeight - levelHeight) * 0.5
end

function drawMap()
    for y, row in ipairs(level.background) do
        for x, tile in ipairs(row) do
            local i = (x - 1) * TileSize + offsetX
            local j = (y - 1) * TileSize + offsetY
            local tile2 = level.entity[y][x]

            love.graphics.draw(tileSet, quads[1], i, j)
            if tile == 0 then
                if tile2 == 1 then
                    love.graphics.draw(tileSet, quads[5], i, j)
                elseif tile2 == 2 then
                    love.graphics.draw(tileSet, quads[4], i, j)
                end
            elseif tile == 1 then
                love.graphics.draw(tileSet, quads[2], i, j)
            elseif tile == 2 then
                if tile2 ~= 2 then
                    love.graphics.draw(tileSet, quads[3], i, j)
                    if tile2 == 1 then
                        love.graphics.draw(tileSet, quads[5], i, j)
                    end
                elseif tile2 == 2 then
                    love.graphics.draw(tileSet, quads[6], i, j)
                end
            end
        end
    end
end

function love.keypressed(key)       
    local dx = 0
    local dy = 0

    canSave = true
    canMove = true

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

    local playerX, playerY = getPlayerPosition()
    checkMove(playerX, playerY, dx, dy)
    checkWinCondition()
end

function getPlayerPosition()
    for y, row in ipairs(level.entity) do
        for x, tile in ipairs(row) do
            if tile == 1 then
                return x, y
            end
        end
    end
end

function checkMove(x, y, dx, dy)
    local newX = x + dx
    local newY = y + dy
    local current = level.entity[y][x]
    local front = level.entity[newY][newX]
    local behind = level.entity[y - dy][x - dx]

    if not EnableMultipush then
        canMove = not (current == 2 and front == 2)
    end

    if front == 2 then
        -- call checkMove again with next tile
        checkMove(newX, newY, dx, dy)
        -- update front
        front = level.entity[newY][newX]
    elseif level.background[newY][newX] == 1 then
        canMove = false
    end

    if canMove == false then
        return
    end

    if canSave then
        saveLevel()
        canSave = false
    end

    if EnablePull and current == 1 and behind == 2 then
        level.entity[newY][newX] = 1
        level.entity[y][x] = 2
        level.entity[y - dy][x - dx] = 0
    elseif current == 1 then
        level.entity[newY][newX] = 1
        level.entity[y][x] = 0
    elseif current == 2 then
        level.entity[newY][newX] = 2
        level.entity[y][x] = 2
    end
end

function checkWinCondition()
    local levelWin = true
    -- all target on crate
    for y, row in ipairs(level.background) do
        for x, tile in ipairs(row) do
            if tile == 2 and level.entity[y][x] ~= 2 then
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

function saveLevel()
    table.insert(undoStack, deepCopy(level.entity))
    redoStack = {}
end

function undoLevel()
    if #undoStack > 0 then
        table.insert(redoStack, deepCopy(level.entity))
        level.entity = table.remove(undoStack)
    end
end

function redoLevel()
    if #redoStack > 0 then
        table.insert(undoStack, deepCopy(level.entity))
        level.entity = table.remove(redoStack)
    end
end