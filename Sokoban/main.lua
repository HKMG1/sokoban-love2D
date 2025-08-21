io.stdout:setvbuf("no")

TileSize = 64

EnableMultipush = false
EnablePull = false

function love.load()
    tileSet = love.graphics.newImage('/images/sokoban_tilesheet.png')
    windowWidth, windowHeight = love.graphics.getDimensions()

    quadCoord = getQuadData()
    loadQuad()

    levels = getLevelData()
    levelIndex = 1
    loadLevel()
end

function love.draw()
    drawMap()
end

function getQuadData()
    --[[
    sprites:
    1 = ground
    2 = wall
    3 = target
    4 = crate
    5 = player
    6 = crate on target
    ]]
    return {
        { 11, 6 },
        { 9, 6 },
        { 0, 3 },
        { 1, 0 },
        { 0, 4 },
        { 1, 1 }
    }
end

function getLevelData()
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
    return {
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
end

function loadQuad()
    quads = {}
    for i, coord in ipairs(quadCoord) do
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

            drawGround(i, j)
            if isWall(bgtile, tile) then
                drawWall(i, j)
            elseif isTarget(bgtile, tile) then
                drawTarget(i, j)
            elseif isPlayer(bgtile, tile) then
                drawPlayer(i, j)
            elseif isPlayerOnTarget(bgtile, tile) then
                drawPlayerOnTarget(i, j)
            elseif isCrate(bgtile, tile) then
                drawCrate(i, j)
            elseif isCrateOnTarget(bgtile, tile) then
                drawCrateOnTarget(i, j)
            end
        end
    end
end

function isWall(id1, id2)
    return id1 == 1
end

function isTarget(id1, id2)
    id2 = id2 or 0
    return id1 == 2 and id2 == 0
end

function isPlayer(id1, id2)
    id1 = id1 or 0
    return id1 == 0 and id2 == 1
end

function isPlayerOnTarget(id1, id2)
    return id1 == 2 and id2 == 1
end

function isCrate(id1, id2)
    id1 = id1 or 0
    return id1 == 0 and id2 == 2
end

function isCrateOnTarget(id1, id2)
    return id1 == 2 and id2 == 2
end

function isTargetNoCrate(id1, id2)
    return isTarget(id1, id2) or isPlayerOnTarget(id1, id2)
end

function drawGround(x, y)
    love.graphics.draw(tileSet, quads[1], x, y)
end

function drawWall(x, y)
    love.graphics.draw(tileSet, quads[2], x, y)
end

function drawTarget(x, y)
    love.graphics.draw(tileSet, quads[3], x, y)
end

function drawPlayer(x, y)
    love.graphics.draw(tileSet, quads[5], x, y)
end

function drawPlayerOnTarget(x, y)
    drawTarget(x, y)
    drawPlayer(x, y)
end

function drawCrate(x, y)
    love.graphics.draw(tileSet, quads[4], x, y)
end

function drawCrateOnTarget(x, y)
    love.graphics.draw(tileSet, quads[6], x, y)
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
    elseif key == 'n' then
        nextLevel()
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
    if isLevelWin() then
        nextLevel()
    end
end

function getPlayerPosition()
    for y, row in ipairs(level.entity) do
        for x, tile in ipairs(row) do
            if isPlayer(nil, tile) then
                return x, y
            end
        end
    end
end

-- need to refactor
-- attemptMove and applyMove
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

    -- attempt move
    if not EnableMultipush then
        canMove = not (isCrate(nil, current) and isCrate(nil, front))
    end

    if isCrate(nil, front) then
        checkMove(newX, newY, dx, dy)
        front = level.entity[newY][newX]
    elseif isWall(level.background[newY][newX], nil) then
        canMove = false
    end

    if not canMove then
        return
    end

    -- apply move
    if EnablePull and isPlayer(nil, current) and isCrate(nil, behind) then
        level.entity[newY][newX] = 1
        level.entity[y][x] = 2
        level.entity[y - dy][x - dx] = 0
    elseif isPlayer(nil, current) then
        level.entity[newY][newX] = 1
        level.entity[y][x] = 0
    elseif isCrate(nil, current) then
        level.entity[newY][newX] = 2
        level.entity[y][x] = 2
    end
end

function isLevelWin()
    for y, row in ipairs(level.background) do
        for x, bgtile in ipairs(row) do
            tile = level.entity[y][x]
            if isTargetNoCrate(bgtile, tile) then
                return false
            end
        end
    end
    return true
end

function nextLevel()
    levelIndex = levelIndex + 1
    if levelIndex > #levels then
        levelIndex = 1
    end
    loadLevel()
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