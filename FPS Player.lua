-- asour's Tabletop Simulator FPS Player Script
-- License: Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International Public License
-- https://github.com/aMySour/Tabletop-Simulator-FPS

-- officially known as "FPS Player", or, long name, "asour's Tabletop Simulator FPS Player"
-- it is meant to go with the FPS Screen, which is a screen that shows the FPS Player's health and cursor position.
-- there are currently 4 FPS Players: red, blue, green and yellow.

-- due to limitations in what unity APIs are available to us, each FPS Player and FPS Screen pair must be a separate unity asset bundle.
-- because of this, theres currently only 4 FPS Players, and 4 FPS Screens.
-- each FPS Player script has an index that corresponds to the color: Red is 1, Blue is 2, Green is 3 and Yellow is 4. we use fpsPlayer tag on all of them but fpsPlayer<index> on each one as well.
-- we calculate this and set it on ourPlayerIndex in onLoad from the tag. currently, we hardcode an index for each tag (fpsPlayer1, etc) but later we can actually calculate it from the tag, which will allow us to have more than 4 FPS Players.

-- In the monorepo linked there's also the FPS Screen and the Unity source for everything, so be sure to check that out if you're interested
-- just remember its CC BY-NC-SA 4.0, so you have to credit asour if you publish anything based on it

-- Note: if you're using my Script Tool 2.0 for applying this, you have to run it through a lua minifier like https://mothereff.in/lua-minifier first, since it has a character limit that this exceeds greatly

ourPlayerIndex = 0 -- 1 = red, 2 = blue, 3 = green, 4 = yellow, 0 when not loaded yet

-- Soon, we can figure that out from the tags, but for now, we need to set it manually.

-- Controls (scripting buttons, numpad by default)
local upIndex = 8
local leftIndex = 4
local downIndex = 5
local rightIndex = 6
local spinLeftIndex = 7
local spinRightIndex = 9
local jumpIndex = 1 -- sets Y vel
local fireIndex = 2 -- line raycast to shoot gun
local interactIndex = 3 -- line raycast to interact with objects

-- Input values
local up = false
local left = false
local down = false
local right = false
local spinLeft = false
local spinRight = false
local automaticFire = false
local fire = false
local interact = false
local jump = false

local y = 0 -- Y rotation, change to spin

-- Speeds (exposed so interactables can make you faster/slower)
spinSpeed = 70
moveSpeed = 5

ourPlayer = nil -- exposed so stuff can broadcast to player
local canJump = true -- we assume that any collision means we can jump. this isnt accurate but its good enough for a basic tabletop sim fps and elss expensive than raycast

-- Health
hp = 100 -- starts at half health, change if you want
maxHP = 200

local controllingPlayerColor = nil

local previousCursorPos = nil

-- Update health, max health and crosshair Y on screen
function setScreenUI(screen, health, maxHealth, cursorY)
    screen.call("setUI", { health = health, maxHealth = maxHealth, cursorY = cursorY })
end

function setAllScreenUI(health, maxHealth, cursorY)
    -- get all objects with tag fpsScreen<ourPlayerIndex>
    local screens = getObjectsWithTag("fpsScreen" .. ourPlayerIndex)
    if screens == nil then
        return
    end
    for _, screen in ipairs(screens) do
        setScreenUI(screen, health, maxHealth, cursorY)
    end
end

-- For playing sound effects on the screen
function playTriggerOnScreen(screen, index)
    screen.AssetBundle.playTriggerEffect(index)
end

function playTriggerOnAllScreens(index)
    -- get all objects with tag fpsScreen<ourPlayerIndex>
    local screens = getObjectsWithTag("fpsScreen" .. ourPlayerIndex)
    if screens == nil then
        return
    end
    for _, screen in ipairs(screens) do
        playTriggerOnScreen(screen, index)
    end
end

function onScriptingButtonDown(index, color)
    -- make sure color matches
    if color ~= controllingPlayerColor then
        return
    end
    ourPlayer = Player[color]
    -- index 8 is up, index 4 is left, 5 is down and 6 is right. we can use this to make a fps script, which is what this is
    if index == upIndex then
        up = true
    elseif index == leftIndex then
        left = true
    elseif index == downIndex then
        down = true
    elseif index == rightIndex then
        right = true
    elseif index == spinLeftIndex then
        spinLeft = true
    elseif index == spinRightIndex then
        spinRight = true
    elseif index == jumpIndex then
        jump = true
    elseif index == fireIndex then
        fire = true
        automaticFire = true
    elseif index == interactIndex then
        interact = true
    end
end

function onScriptingButtonUp(index, color)
    -- make sure color matches
    if color ~= controllingPlayerColor then
        return
    end
    -- index 8 is up, index 4 is left, 5 is down and 6 is right. we can use this to make a fps script, which is what this is
    if index == upIndex then
        up = false
    elseif index == leftIndex then
        left = false
    elseif index == downIndex then
        down = false
    elseif index == rightIndex then
        right = false
    elseif index == spinLeftIndex then
        spinLeft = false
    elseif index == spinRightIndex then
        spinRight = false
    elseif index == jumpIndex then
        jump = false
    elseif index == fireIndex then
        automaticFire = false -- only set this false, since we set fire to false the minute we see it in update
    end
end

cursorY = 0.5 -- Start in middle of screen

-- Raycast helper function
function getLookingAt(maxDistance)
    local ourForward = self.getTransformRight()
    -- invert forward
    ourForward:inverse()
    local ourPosition = self.getPosition()

    ourForward.y = (cursorY - 0.5) * 1.7 -- pretty close, we should also offset ourPosition by camera height again which will make this value need to be different
    
    local hitList = Physics.cast({
        origin = ourPosition,
        direction = ourForward,
        type = 1, -- 1 = Ray, 2 = Sphere, 3 = Box
        max_distance = maxDistance
    })
    if hitList == nil then
        return nil
    end
    for _, hit in ipairs(hitList) do
        if hit.hit_object ~= nil then
            return hit
        end
    end
end

local objectOriginalColorsFire = {} -- When we fire, we set the object to our color for a bit, then reset it to this
local objectOriginalColorsHover = {} -- When we hover, we set the object to a lighter one, then reset it to this when we stop hovering

local autoFireTimer = 0 -- Gun cooldown
local objectColorResetTimerFire = 0 -- How long until we reset the color of the object we fired at
local hoveringObject = nil -- Highlighted object to reset color of

activeSpawnPoint = nil -- when you touch a spawnpoint, it becomes active. this lets you make a checkpoint system. itll automatically start with the closest spawn point to the player when the game starts

-- Makes a player take control of the FPS Player and moves the camera to the closest monitor. Most of the time, the camera will be perfectly aligned and zoomed to fit the monitor perfectly
function takeControl(playerColor)
    local closestMonitor = nil
    -- get all objects with tag fpsScreen<ourPlayerIndex>
    local screens = getObjectsWithTag("fpsScreen" .. ourPlayerIndex)
    if screens ~= nil then
       -- get closest monitor
        for _, screen in ipairs(screens) do
            local distance = self.getPosition():distance(screen.getPosition())
            if closestMonitor == nil or distance < closestMonitor.distance then
                closestMonitor = {
                    distance = distance,
                    screen = screen
                }
            end
        end

        if closestMonitor ~= nil then
            closestMonitor = closestMonitor.screen
        end
    end
    setPlayerColor(playerColor)
    Player[playerColor].broadcast("You are now controlling FPS Player")
    ourPlayer = Player[playerColor]

    if closestMonitor ~= nil then
        closestMonitor.call("lookAt", Player[playerColor])
    end

    local spawns = getObjectsWithTag("fpsPlayer" .. ourPlayerIndex .. "Spawn")
    if spawns ~= nil then
        for _, spawn in ipairs(spawns) do
            -- lets set the spawn color
            local colorDarker = self.getColorTint()
            colorDarker.r = colorDarker.r - 0.3
            colorDarker.g = colorDarker.g - 0.3
            colorDarker.b = colorDarker.b - 0.3
            if colorDarker.r < 0 then
                colorDarker.r = 0
            end
            if colorDarker.g < 0 then
                colorDarker.g = 0
            end
            if colorDarker.b < 0 then
                colorDarker.b = 0
            end
            spawn.setColorTint(colorDarker)
        end
    end
    -- if activeSpawnPoint, set it to our color
    if activeSpawnPoint ~= nil then
        activeSpawnPoint.setColorTint(self.getColorTint())
    end
end

function onLoad()
    -- set ourPlayerIndex based on tag. if we have fpsPlayer1, ourPlayerIndex is 1, if we have fpsPlayer2, its 2, etc, up to 4. for now, we manually directly == "fpsPlayer1" etc
    local tags = self.getTags()
    for _, tag in ipairs(tags) do
        if tag == "fpsPlayer1" then
            ourPlayerIndex = 1
        elseif tag == "fpsPlayer2" then
            ourPlayerIndex = 2
        elseif tag == "fpsPlayer3" then
            ourPlayerIndex = 3
        elseif tag == "fpsPlayer4" then
            ourPlayerIndex = 4
        end
    end

    -- set activeSpawnPoint to closest fpsPlayer<index>Spawn
    local spawns = getObjectsWithTag("fpsPlayer" .. ourPlayerIndex .. "Spawn")
    local closestSpawn = nil
    if spawns ~= nil then
        for _, spawn in ipairs(spawns) do
            local distance = self.getPosition():distance(spawn.getPosition())
            if closestSpawn == nil or distance < closestSpawn.distance then
                closestSpawn = {
                    distance = distance,
                    spawn = spawn
                }
            end
        end
    end
    if closestSpawn ~= nil then
        closestSpawn = closestSpawn.spawn
    end
    activeSpawnPoint = closestSpawn

    --controllingPlayerColor = self.getColorTint():toString()
    
    -- Since we don't want someone to control the player without hitting Take Control, we will set our color to gray so they see that its not their color
    self.setColorTint({ r = 0.5, g = 0.5, b = 0.5 })
    -- if you want a scene where they control immediately, you can make a manager script that calls takeControl(playerColor) on this object

    self.addContextMenuItem("Take Control", function(playerColor)
        takeControl(playerColor)
        -- currently you cant release control, but another player can take control from you
        -- TODO: maybe add system where when someone takes control it asks if you want to release control (unless its GM) and GM can force release control
        -- also TODO: add release control button
    end)
    self.addContextMenuItem("Set HP", function(playerColor)
        local player = Player[playerColor]
        player.showInputDialog("Set HP", function(input)
            local newHP = tonumber(input)
            if newHP == nil then
                player.broadcast("Invalid HP")
                return
            end
            hp = newHP
            if hp > maxHP then
                maxHP = hp
            elseif hp < 0 then
                hp = 0
            end
            player.broadcast("Set HP to " .. hp)
        end)
    end)
    self.addContextMenuItem("Set Max HP", function(playerColor)
        local player = Player[playerColor]
        player.showInputDialog("Set Max HP", function(input)
            local newMaxHP = tonumber(input)
            if newMaxHP == nil then
                player.broadcast("Invalid Max HP")
                return
            end
            maxHP = newMaxHP
            if maxHP < 1 then
                maxHP = 1
            end
            if hp > maxHP then
                hp = maxHP
            end
            player.broadcast("Set Max HP to " .. maxHP)
        end)
    end)
end

function setPlayerColor(color, player)
    controllingPlayerColor = color
    self.setColorTint(Color.fromString(color))
    if player then
        printToColor("Updated FPS player color to " .. color, player.color)
        ourPlayer = player
    end
end

local deathRespawnTimer = 0

function onUpdate()
    self.setName("FPS Player (" .. hp .. " / " .. maxHP .. " HP)")

    -- update all UI
    setAllScreenUI(hp, maxHP, cursorY)

    if hp <= 0 then
        -- lets respawn after 5 seconds
        deathRespawnTimer = deathRespawnTimer + Time.delta_time
        if deathRespawnTimer >= 5 then
            deathRespawnTimer = 0
            hp = maxHP
            
            -- go to spawn point
            if activeSpawnPoint ~= nil then
                local spawnPoint = activeSpawnPoint.getPosition()
                spawnPoint.y = spawnPoint.y + 1.5
                self.setPosition(spawnPoint)
            end

            if ourPlayer ~= nil then
                ourPlayer.broadcast("Respawned at active spawn point (touch a spawn point to set it as active)")
            end
        end

        return
    end

    -- make sure we arent being held
    if self.isSmoothMoving() or self.held_by_color then
        return
    end

    local cursorXDiff = 0
    local cursorYDiff = 0

    local closestMonitor = nil

    -- get all objects with tag fpsScreen<ourPlayerIndex>
    local screens = getObjectsWithTag("fpsScreen" .. ourPlayerIndex)
    if screens ~= nil then
        -- get closest monitor
        for _, screen in ipairs(screens) do
            local distance = self.getPosition():distance(screen.getPosition())
            if closestMonitor == nil or distance < closestMonitor.distance then
                closestMonitor = {
                    distance = distance,
                    screen = screen
                }
            end
        end

        if closestMonitor ~= nil then
            closestMonitor = closestMonitor.screen
        end
    end

    local screenFireDown = false
    if closestMonitor ~= nil then
        local screenFireDownValue = closestMonitor.getVar("fireDown")
        -- theres fireDowner which is the player that hit the screen. lets make sure its ourPlayer if ourPlayer isnt nil
        local fireDowner = closestMonitor.getVar("fireDowner")
        if fireDowner ~= nil and ourPlayer ~= nil then
            if fireDowner.color ~= ourPlayer.color then
                screenFireDownValue = false
            end
        end

        if screenFireDownValue ~= nil then
            screenFireDown = screenFireDownValue
        end
    end

    if ourPlayer ~= nil and closestMonitor ~= nil and ourPlayer.color ~= nil and Player[ourPlayer.color] ~= nil and Player[ourPlayer.color].seated then
        -- make sure player isnt in spectators
        local spectators = Player.getSpectators()
        local isSpectator = false
        for _, spectator in ipairs(spectators) do
            if spectator.steam_id == ourPlayer.steam_id then
                isSpectator = true
                break
            end
        end
        if not isSpectator then
            local playerCursorPos = ourPlayer.getPointerPosition()
        --local cursorPos = closestMonitor.positionToLocal()

        -- same thing but with pcall and it might be nil
        local cursorPos = nil
        local success, err = pcall(function()
            cursorPos = closestMonitor.positionToLocal(playerCursorPos)
        end)
        if success then
        -- if its outside of the screen, ignore it
        local inScreen = true
        local inLeftEdge = false
        local inRightEdge = false

        local width = 5.45 * 2
        local height = 3.13 * 2
        local edge = 4.36 * 2

        if cursorPos.x > width or cursorPos.x < -width or cursorPos.z < -height or cursorPos.z > height then
            inScreen = false
        end

        if cursorPos.x > edge then
            inLeftEdge = true
        end

        if cursorPos.x < -edge then
            inRightEdge = true
        end

        if previousCursorPos == nil then
            previousCursorPos = cursorPos
        end

        if inScreen then
            -- get difference
            cursorXDiff = cursorPos.x - previousCursorPos.x
            cursorYDiff = cursorPos.z - previousCursorPos.z

            cursorY = -cursorPos.z / 5

            -- right now its from -1 to 1, we want it from 0 to 1
            cursorY = (cursorY + 1) / 2
            if cursorY > 1 then
                cursorY = 1
            elseif cursorY < 0 then
                cursorY = 0
            end

            if inLeftEdge then
                y = y - (Time.delta_time * spinSpeed * 2)
            end
            if inRightEdge then
                y = y + (Time.delta_time * spinSpeed * 2)
            end
        end

        previousCursorPos = cursorPos -- even if outside of screen, we still want to update this so that when it comes back in, it doesnt jump
    end
    end
    end

    -- with the help of self.positionToLocal/self.positionToWorld and setVelocity (we dont need to get), we can make a fps script
    -- up

    local ourPosition = self.getPosition()
    local ourRotation = self.getRotation()
    local ourForward = self.getTransformRight()
    -- invert forward
    ourForward:inverse()
    local ourLeft = self.getTransformForward()
    -- invert left
    ourLeft:inverse()
    local ourRight = self.getTransformForward()
    local ourBack = self.getTransformRight()
    local ourForwardNormalized = Vector(ourForward.x, 0, ourForward.z)
    ourForwardNormalized:normalize()
    local ourLeftNormalized = Vector(ourLeft.x, 0, ourLeft.z)
    ourLeftNormalized:normalize()
    local ourRightNormalized = Vector(ourRight.x, 0, ourRight.z)
    ourRightNormalized:normalize()
    local ourBackNormalized = Vector(ourBack.x, 0, ourBack.z)
    ourBackNormalized:normalize()

    local velocityX = 0
    local velocityZ = 0

    if up then
        velocityX = velocityX + (ourForwardNormalized.x * moveSpeed)
        velocityZ = velocityZ + (ourForwardNormalized.z * moveSpeed)
    end
    if left then
        velocityX = velocityX + (ourLeftNormalized.x * moveSpeed)
        velocityZ = velocityZ + (ourLeftNormalized.z * moveSpeed)
    end
    if down then
        velocityX = velocityX + (ourBackNormalized.x * moveSpeed)
        velocityZ = velocityZ + (ourBackNormalized.z * moveSpeed)
    end
    if right then
        velocityX = velocityX + (ourRightNormalized.x * moveSpeed)
        velocityZ = velocityZ + (ourRightNormalized.z * moveSpeed)
    end

    local velocityY = self.getVelocity().y

    if jump and canJump then
        velocityY = moveSpeed * 2
        canJump = false
        playTriggerOnAllScreens(0)
    end


    self.setVelocity({x = velocityX, y = velocityY, z = velocityZ})

    -- spin
    if spinLeft then
        y = y - (Time.delta_time * spinSpeed)
    end
    if spinRight then
        y = y + (Time.delta_time * spinSpeed)
    end

    y = y - cursorXDiff * (spinSpeed / 2)

    self.setRotation({x = 0, y = y, z = 0})

    if objectColorResetTimerFire > 0 then
        objectColorResetTimerFire = objectColorResetTimerFire - Time.delta_time
    end

    if objectColorResetTimerFire <= 0 then
        -- set original colors back
        for guid, color in pairs(objectOriginalColorsFire) do
            local object = getObjectFromGUID(guid)
            if object ~= nil then
                object.setColorTint(color)
            end
        end
        objectOriginalColorsFire = {}
    end

    if autoFireTimer > 0 then
        autoFireTimer = autoFireTimer - Time.delta_time
    end

    local lookingAtTable = getLookingAt(100)
    local lookingAt = nil
    local lookingAtPoint = nil
    if lookingAtTable ~= nil then
        lookingAt = lookingAtTable.hit_object
        lookingAtPoint = lookingAtTable.point
    end

    if lookingAt ~= nil then
        if hoveringObject ~= nil then
                hoveringObject.setColorTint(objectOriginalColorsHover[hoveringObject.getGUID()])
                hoveringObject = nil
            end
        if lookingAt.getGUID() ~= nil and objectOriginalColorsFire[lookingAt.getGUID()] == nil then
            -- first, make sure its interesting, which means it has either food, stateFood, healthPotion, healthFruit, underageHealthPotion, or fpsInteractable tag
            local interesting = false
            local tags = lookingAt.getTags()
            for _, tag in pairs(tags) do
                if tag == "food" or tag == "stateFood" or tag == "healthPotion" or tag == "healthFruit" or tag == "underageHealthPotion" or tag == "fpsInteractable" then
                    interesting = true
                end
            end

            if interesting then
            objectOriginalColorsHover[lookingAt.getGUID()] = lookingAt.getColorTint()
            local colorBrighter = lookingAt.getColorTint()
            colorBrighter.r = colorBrighter.r + 0.3
            colorBrighter.g = colorBrighter.g + 0.3
            colorBrighter.b = colorBrighter.b + 0.3
            if colorBrighter.r > 1 then
                colorBrighter.r = 1
            end
            if colorBrighter.g > 1 then
                colorBrighter.g = 1
            end
            if colorBrighter.b > 1 then
                colorBrighter.b = 1
            end
            lookingAt.setColorTint(colorBrighter)
            hoveringObject = lookingAt
        end
        end
    end

    
    local fireDown = screenFireDown or automaticFire

    -- if fireDown and looking at something, add force in direction of looking at
    if fireDown and autoFireTimer <= 0 then
        -- slight up force
        self.addForce(Vector(0, 0.8, 0))

        if lookingAt ~= nil then
            local fireForce = ourForwardNormalized
            fireForce:scale(5)
            lookingAt.addForce(fireForce)

            --spawnObject({
            --    type = "BlockSquare",
            --    position = lookingAtPoint,
            --    scale = Vector(0.1, 0.1, 0.1),
            --    sound = false
            --})

            -- if its a smartmeeple or player with HP, this will hurt it
            if lookingAt.hasTag("fpsGunnable") then
                lookingAt.call("harm")
            end
            
            if lookingAt.getGUID() ~= nil and not lookingAt.getLock() then
                -- first, restore if hover
                if objectOriginalColorsHover[lookingAt.getGUID()] ~= nil then
                    lookingAt.setColorTint(objectOriginalColorsHover[lookingAt.getGUID()])
                end
                -- make sure its not in objectOriginalColorsFire
                if objectOriginalColorsFire[lookingAt.getGUID()] == nil then
                    objectOriginalColorsFire[lookingAt.getGUID()] = lookingAt.getColorTint()
                    lookingAt.setColorTint(self.getColorTint())
                    objectColorResetTimerFire = 0.05
                end
            end
            
        end

        autoFireTimer = 0.1
            -- get random int between 1 and 3 (both inclusive)
            local randomSound = math.random(1, 3)
            playTriggerOnAllScreens(randomSound)
    end

    if interact and lookingAt ~= nil then
        playTriggerOnAllScreens(5)
        if lookingAt.hasTag('food') then
            hp = hp + 10
            if hp > maxHP then
                hp = maxHP
            end
            if ourPlayer ~= nil then
                ourPlayer.broadcast("+10 HP (now at " .. hp .. ")")
            end
            lookingAt.destroy()
        end
        if lookingAt.hasTag('stateFood') then
            hp = hp + 10
            if hp > maxHP then
                hp = maxHP
            end
            if ourPlayer ~= nil then
                ourPlayer.broadcast("+10 HP (now at " .. hp .. ")")
            end
            lookingAt.setState(lookingAt.getStateId() + 1)
        end
        if lookingAt.hasTag('healthPotion') then
            hp = hp + 50
            if hp > maxHP then
                hp = maxHP
            end
            if ourPlayer ~= nil then
                ourPlayer.broadcast("+50 HP (now at " .. hp .. ")")
            end
            lookingAt.setState(lookingAt.getStateId() + 1)
        end
        if lookingAt.hasTag('healthFruit') then
            hp = hp + 30
            if hp > maxHP then
                hp = maxHP
            end
            if ourPlayer ~= nil then
                ourPlayer.broadcast("+30 HP (now at " .. hp .. ")")
            end
            lookingAt.destroy()
        end
        if lookingAt.hasTag('underageHealthPotion') then
            hp = hp + 100
            if hp > maxHP then
                hp = maxHP
            end
            if ourPlayer ~= nil then
                ourPlayer.broadcast("+100 HP (now at " .. hp .. ")")
            end
            lookingAt.setState(lookingAt.getStateId() + 1)
        end
        -- if it has fpsInteractable, call interact on it
        if lookingAt.hasTag('fpsInteractable') then
            lookingAt.call("interact", {player = ourPlayer, self = self})
        end
    end

    interact = false
end

function harm()
    if hp > 0 then
        playTriggerOnAllScreens(4)
        if ourPlayer ~= nil then
            hp = hp - 5
            if hp <= 0 then
                hp = 0
                ourPlayer.broadcast("You have been hit and died.")
            else
                ourPlayer.broadcast("You have been hit, lost 5 HP. (" .. hp .. " left)")
            end
        end
    end
end

function onCollisionEnter(info)
    canJump = true

    -- if it has tag "fpsPlayer" .. ourPlayerIndex .. "Spawn", then set activeSpawnPoint to it
    if info.collision_object.hasTag("fpsPlayer" .. ourPlayerIndex .. "Spawn") then
        -- if we have existing active spawn, set it to our color but darker
        if activeSpawnPoint ~= nil then
            activeSpawnPoint.setColorTint(self.getColorTint())
            local colorDarker = activeSpawnPoint.getColorTint()
            colorDarker.r = colorDarker.r - 0.3
            colorDarker.g = colorDarker.g - 0.3
            colorDarker.b = colorDarker.b - 0.3
            if colorDarker.r < 0 then
                colorDarker.r = 0
            end
            if colorDarker.g < 0 then
                colorDarker.g = 0
            end
            if colorDarker.b < 0 then
                colorDarker.b = 0
            end
            activeSpawnPoint.setColorTint(colorDarker)
        end
        activeSpawnPoint = info.collision_object
        if ourPlayer ~= nil then
            ourPlayer.broadcast("Spawn point set.")
        end
        activeSpawnPoint.setColorTint(self.getColorTint())
    end
end