io.stdout:setvbuf("no")

TileSize = 64

EnableMultipush = true
EnablePull = true

function love.load()
    tileSet = love.graphics.newImage('/images/sokoban_tilesheet.png')
    windowWidth, windowHeight = love.graphics.getDimensions()

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
                { 1, 0, 0, 0, 0, 1 },
                { 1, 0, 2, 2, 0, 1 },
                { 1, 0, 0, 0, 0, 1 },
                { 1, 0, 0, 0, 0, 1 },
                { 1, 2, 0, 0, 0, 1 },
                { 1, 1, 1, 1, 1, 1 }
            },
            entity = {
                { 0, 0, 0, 0, 0, 0 },
                { 0, 0, 0, 0, 0, 0 },
                { 0, 0, 2, 0, 0, 0 },
                { 0, 0, 0, 0, 2, 0 },
                { 0, 0, 0, 1, 0, 0 },
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
    for i, coord in ipairs(quadInfo) do
        quads[i] = love.graphics.newQuad(coord[1] * TileSize, coord[2] * TileSize, TileSize, TileSize, tileSet:getDimensions())
    end
end

function loadLevel()
    level = { background, entity }
    level.background = deepCopy(levels[levelIndex].background)
    level.entity = deepCopy(levels[levelIndex].entity)

    levelHeight = #level.background
    levelWidth = #level.background[1]

    offsetX = (windowWidth - levelWidth * TileSize) * 0.5
    offsetY = (windowHeight - levelHeight * TileSize) * 0.5

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

function drawMap()
    for y, row in ipairs(level.background) do
        for x, bgtile in ipairs(row) do
            local i = (x - 1) * TileSize + offsetX
            local j = (y - 1) * TileSize + offsetY
            local tile = level.entity[y][x]

            love.graphics.draw(tileSet, quads[1], i, j)
            if bgtile == 0 then
                if tile == 1 then
                    love.graphics.draw(tileSet, quads[5], i, j)
                elseif tile == 2 then
                    love.graphics.draw(tileSet, quads[4], i, j)
                end
            elseif bgtile == 1 then
                love.graphics.draw(tileSet, quads[2], i, j)
            elseif bgtile == 2 then
                if tile < 2 then
                    love.graphics.draw(tileSet, quads[3], i, j)
                    if tile == 1 then
                        love.graphics.draw(tileSet, quads[5], i, j)
                    end
                elseif tile == 2 then
                    love.graphics.draw(tileSet, quads[6], i, j)
                end
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

    local playerX, playerY = getPlayerPosition()
    canMove = true
    saveLevel()
    checkMove(playerX, playerY, dx, dy)
    if not canMove then
        undoLevel()
    end
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
    local front, behind
    if level.entity[newY] and level.entity[newY][newX] then
        front = level.entity[newY][newX]
    end
    if EnablePull and level.entity[y - dy] and level.entity[y - dy][x - dx] then
        behind = level.entity[y - dy][x - dx]
    end

    if not EnableMultipush then
        canMove = not (current == 2 and front == 2)
    end

    if front == 2 then
        checkMove(newX, newY, dx, dy)
        front = level.entity[newY][newX]
    elseif level.background[newY][newX] == 1 then
        canMove = false
    end

    if canMove == false then
        return
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