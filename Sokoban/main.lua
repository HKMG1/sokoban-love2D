-- for debug
io.stdout:setvbuf("no")

-- const
TileSize = 64

-- feature
EnableMultipush = false
EnablePull = false

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

    --[[ 
    objects ID:
    0 = ground
    1 = wall
    2 = target
    3 = crate
    4 = player
    5 = crate on target
    6 = player on target
    ]]
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

function isObject(id, object)
    if object == "player" and (id == 4 or id == 6) then
        return true
    elseif object == "crate" and (id == 3 or id == 5) then
        return true
    elseif object == "target" and (id == 2 or id == 6) then -- target no crate
        return true
    elseif object == "wall" and id == 1 then -- may rename as obstacle
        return true
    else
        return false
    end
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
    level = deepCopy(levels[levelIndex])
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
    levelWidth = #level[1] * TileSize
    levelHeight = #level * TileSize
    windowWidth, windowHeight = love.graphics.getDimensions()
    return (windowWidth - levelWidth) * 0.5, (windowHeight - levelHeight) * 0.5
end

function drawMap()
    for y, row in ipairs(level) do
        for x, tile in ipairs(row) do
            local i = (x - 1) * TileSize + offsetX
            local j = (y - 1) * TileSize + offsetY
            love.graphics.draw(tileSet, quads[1], i, j)
            if tile >= 1 and tile <= 5 then
                love.graphics.draw(tileSet, quads[tile + 1], i, j)
            elseif tile == 6 then
                love.graphics.draw(tileSet, quads[3], i, j)
                love.graphics.draw(tileSet, quads[5], i, j)
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
    for y, row in ipairs(level) do
        for x, tile in ipairs(row) do
            if isObject(tile, "player") then
                return x, y
            end
        end
    end
end

function checkMove(x, y, dx, dy)
    local newX = x + dx
    local newY = y + dy
    local current = level[y][x]
    local front = level[newY][newX]
    local behind = level[y - dy][x - dx]

    if not EnableMultipush then
        canMove = not (isObject(current, "crate") and isObject(front, "crate"))
    end

    if isObject(front, "crate") then
        -- call checkMove again with next tile
        checkMove(newX, newY, dx, dy)
        -- update front
        front = level[newY][newX]
    elseif isObject(front, "wall") then
        canMove = false
    end

    if canMove == false then
        return
    end

    if canSave then
        saveLevel()
        canSave = false
    end

    local nextCurrent = {
        [4] = 0,
        [6] = 2
    }
    local nextFront = {
        [0] = 4,
        [2] = 6
    }
    local nextCurrentPush = {
        [3] = 0,
        [5] = 2
    }
    local nextFrontPush = {
        [0] = 3,
        [2] = 5
    }
    local nextCurrentPull = {
        [4] = 3,
        [6] = 5
    }
    local nextBehindPull = {
        [3] = 0,
        [5] = 2
    }

    if EnablePull and isObject(current, "player") and isObject(behind, "crate") then
        level[newY][newX] = nextFront[front]
        level[y][x] = nextCurrentPull[current]
        level[y - dy][x - dx] = nextBehindPull[behind]
    elseif isObject(current, "player") then
        level[newY][newX] = nextFront[front]
        level[y][x] = nextCurrent[current]
    elseif isObject(current, "crate") then
        level[newY][newX] = nextFrontPush[front]
        level[y][x] = nextCurrentPush[current]
    end
end

function checkWinCondition()
    local levelWin = true
    -- all target on crate
    for y, row in ipairs(level) do
        for x, tile in ipairs(row) do
            if isObject(tile, "target") then
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
    table.insert(undoStack, deepCopy(level))
    redoStack = {}
end

function undoLevel()
    if #undoStack > 0 then
        table.insert(redoStack, deepCopy(level))
        level = table.remove(undoStack)
    end
end

function redoLevel()
    if #redoStack > 0 then
        table.insert(undoStack, deepCopy(level))
        level = table.remove(redoStack)
    end
end