-- asour's Tabletop Simulator FPS Basic Enemy Script
-- License: Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International Public License
-- https://github.com/aMySour/Tabletop-Simulator-FPS

-- we look for any fpsPlayer object within range of us and go towards it, dealing damage if we touch it
local range = 10
local speed = 5.1 -- slightly faster than player to be an actual threat
hp = 100
maxHP = 100
target = nil

function lookAtY(otherPosition)
    -- first, we get our current pos
    local selfPosition = self.getPosition()
    -- then, we get the difference between our position and the other position
    local difference = otherPosition - selfPosition
    -- then, we get the angle of the difference
    local angle = math.deg(math.atan2(difference.z, difference.x))
    -- then, we set our rotation to the angle
    self.setRotation(Vector(0, -angle - 180, 0))
end

local canJump = true

function onUpdate()
    if hp <= 0 or self.isSmoothMoving() or self.held_by_color then
        return
    end

    -- find the closest player
    local players = getObjectsWithTag("fpsPlayer")
    local closestPlayer = nil -- table of {player, distance}
    if players ~= nil then
        for i, player in ipairs(players) do
            local distance = self.getPosition():distance(player.getPosition())
            if closestPlayer == nil or distance < closestPlayer.distance then
                closestPlayer = {player = player, distance = distance}
            end
        end
    end
    if closestPlayer ~= nil and closestPlayer.distance < range then
        target = closestPlayer.player
    end

    -- move towards the target by setting velocity. if the target is more than 0.4 units above us, set velocity Y to speed * 2 to jump
    if target ~= nil then
        local targetPos = target.getPosition()
        local targetPosNoY = Vector(targetPos.x, self.getPosition().y, targetPos.z)
        local direction = targetPosNoY - self.getPosition()
        direction:normalize()
        local velocity = direction * speed
        if targetPos.y - self.getPosition().y > 0.4 and canJump then
            velocity.y = speed * 2
            canJump = false
        else
            velocity.y = self.getVelocity().y - 0.2 -- they get stuck in the air if we dont do this
        end
        self.setVelocity(velocity)

        -- set rotation to look at the target
        lookAtY(targetPos)
    else
        lookAtY(Vector(0, 0, 0))
    end
end

function onCollisionEnter(info)
    canJump = true
    -- if we collide with a player, deal damage to it
    if hp > 0 and info.collision_object ~= nil and info.collision_object.hasTag("fpsPlayer") then
        info.collision_object.call("harm")
    end
end

function harm()
    -- deal damage to us
    hp = hp - 10
end