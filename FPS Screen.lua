-- asour's Tabletop Simulator FPS Screen Script
-- License: Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International Public License
-- https://github.com/aMySour/Tabletop-Simulator-FPS
-- in that monorepo theres the unity assetbundle source and the player code

function onLoad()
    self.UI.setXml([[
        <Panel
            rotation="0 0 180"
            width="1600"
            height="920"
            position="0 0 -5"
            onMouseDown="onMouseDown"
            onMouseUp="onMouseUp"
        >
        <Text
            id="healthText"
            text="100/200 HP"
            rectAlignment="UpperLeft"
            width="200"
            height="50"
            fontSize="30"
            color="#ffffff"
            outline="#000000"
            outlineSize="2"
            offsetXY="190 0"
            alignment="MiddleRight"
        ></Text>
        <ProgressBar
            id="healthBar"
            rectAlignment="UpperLeft"
            width="200"
            height="25"
            color="#3d0008"
            offsetXY="0 -13"
            percentage="50"
            showPercentageText="false"
            fillImageColor="#ff1e34"
            interactable="false"
        ></ProgressBar>
        <Button
            id="viewButton"
            rectAlignment="LowerCenter"
            width="400"
            height="100"
            color="#555555"
            textColor="#ffffff"
            fontSize="40"
            offsetXY="0 -350"
            onClick="viewButtonClicked"
        >View</Button>
        <Button
            rectAlignment="UpperRight"
            width="180"
            height="40"
            color="#555555"
            textColor="#ffffff"
            fontSize="20"
            offsetXY="-170 0"
            onClick="exitViewerButtonClicked"
        >Exit Screen</Button>
        <Button
            rectAlignment="UpperRight"
            width="180"
            height="25"
            color="#555555"
            textColor="#ffffff"
            fontSize="15"
            offsetXY="-170 -40"
            onClick="backAwayCamera"
        >Back Away Camera</Button>
        <Button
            rectAlignment="UpperRight"
            width="180"
            height="25"
            color="#555555"
            textColor="#ffffff"
            fontSize="15"
            offsetXY="-170 -65"
            onClick="bringCameraCloser"
        >Bring Camera Closer</Button>
        <Image
            id="crosshair1"
            rectAlignment="Center"
            width="15"
            height="15"
            color="#000000ff"
            raycastTarget="false"
            offsetXY="0 0"
            image="fpsCrosshair1"
        ></Image>
        <Image
            id="crosshair3"
            rectAlignment="Center"
            width="5"
            height="30"
            color="#000000ff"
            raycastTarget="false"
            offsetXY="0 0"
            image="fpsCrosshair1"
        ></Image>
        <Image
            id="crosshair4"
            rectAlignment="Center"
            width="30"
            height="5"
            color="#000000ff"
            raycastTarget="false"
            offsetXY="0 0"
            image="fpsCrosshair1"
        ></Image>
        <Image
            id="crosshair2"
            rectAlignment="Center"
            width="8"
            height="8"
            color="#ffffffff"
            raycastTarget="false"
            offsetXY="0 0"
            image="fpsCrosshair1"
        ></Image>
        </Panel>
    ]])

end

function viewButtonClicked(player)
    lookAt(player)
    player.broadcast('Now looking at screen. If you didn\'t take control of the player, you can only watch. If the camera gets stuck when your mouse in on the sides of the screen, bring the camera further away using the buttons.')
end

fireDown = false
fireDowner = nil

function onMouseDown(player, value)
    fireDowner = player
    fireDown = true
end

function onMouseUp(player, value)
    fireDowner = player
    fireDown = false
end

local cameraDistance = 10

function lookAt(player)
    local pos = self.getPosition()
    pos.y = pos.y - 4.8
    player.lookAt({
        position = pos,
        pitch    = 90,
        yaw      = self.getRotation().y + 180,
        distance = cameraDistance,
    })
    self.setLock(true)
end

function setUI(params)
    local health = params.health
    local maxHealth = params.maxHealth
    local cursorY = params.cursorY -- it goes from 0 (bottom) to 1 (top), we can use 920/2
    self.UI.setValue('healthText', health .. '/' .. maxHealth .. ' HP')
    self.UI.setAttribute('healthBar', 'percentage', health / maxHealth * 100)

    -- crosshair is always in middle, all we gotta do is change the Y
    self.UI.setAttribute('crosshair1', 'offsetXY', '0 ' .. (cursorY - 0.5) * 920)
    self.UI.setAttribute('crosshair2', 'offsetXY', '0 ' .. (cursorY - 0.5) * 920)
    self.UI.setAttribute('crosshair3', 'offsetXY', '0 ' .. (cursorY - 0.5) * 920)
    self.UI.setAttribute('crosshair4', 'offsetXY', '0 ' .. (cursorY - 0.5) * 920)
end

function exitViewerButtonClicked(player)
    -- opposite of lookat, lets set y to 0 and pitch to 15
    local pos = self.getPosition()
    pos.y = 0
    player.lookAt({
        position = pos,
        pitch    = 45,
        yaw      = self.getRotation().y + 180,
        distance = 15,
    })
end

function backAwayCamera(player)
    cameraDistance = cameraDistance + 0.25
    lookAt(player)
    player.broadcast('Camera distance is now ' .. cameraDistance)
end

function bringCameraCloser(player)
    cameraDistance = cameraDistance - 0.25
    lookAt(player)
    player.broadcast('Camera distance is now ' .. cameraDistance)
end