local bit = require("bit")
require "LuaScripts/Speed"
require "LuaScripts/Projectile"

FirstPerson = ScriptObject()

function FirstPerson:Start()
  self.viewport_ = nil
  self.joyID_ = 0
  self.GYROSCOPE_THRESHOLD = 0.1
  self.TOUCH_SENSITIVITY = 2
  self.YAW_SENSITIVITY = 0.1
  self.HATYAW_SENSITIVITY = 1.5
  self.MOVE_FORCE = 2.0
  self.INAIR_MOVE_FORCE = 0.02
  self.BRAKE_FORCE = 0.025
  self.JUMP_FORCE = 30.0
  self.CTRL_FORWARD = 1
  self.CTRL_BACK = 2
  self.CTRL_LEFT = 4
  self.CTRL_RIGHT = 8
  self.CTRL_CAMDOWN = 16
  self.CTRL_CAMUP = 32
  self.CTRL_CAMLEFT = 64
  self.CTRL_CAMRIGHT = 128
  self.CTRL_JUMP = 1
  self.CTRL_GRAB = 2
  self.controls_ = Controls()
  self.buttControls_ = Controls()
  self.cameraNode_ = nil
  self.onGround_ = false
  self.mouseVisible_ = false
  self.okToJump_ = false
  self.speedSO = nil
  self.body_ = nil
  self.grabOrigin_ = nil
  self.grabButtDown_ = false
  self.grabRayDistance_ = 20.0
  self.throwImpulse_ = 100.0
end

function FirstPerson:DelayedStart()
  input:SetMouseVisible(false)
  
  audio:SetListener(self.node:GetComponent("SoundListener"))
  
  self.cameraNode_ = self.node:GetChild("camera")
  self.viewport_ = Viewport:new(LevelScene_, self.cameraNode_:GetComponent("Camera"))
  renderer:SetViewport(0, self.viewport_)
  
  self.grabOrigin_ = self.node:GetChild("grabOrigin")
  
  local dualJoyXMLFile = XMLFile()
  
  dualJoyXMLFile:FromString(self:GetDualJoyGuiString())
  
  self.joyID_ = input:AddScreenJoystick(dualJoyXMLFile, cache:GetResource("XMLFile", "UI/DefaultStyle.xml"))
  
  if GetPlatform() == "Android" or input.touchEmulation then
    input:SetScreenJoystickVisible(self.joyID_, true)
  else
    input:SetScreenJoystickVisible(self.joyID_, false)
  end
  
  self.body_ = self.node:GetComponent("RigidBody")
  self.body_.collisionEventMode = COLLISION_ALWAYS
  
  self.speedSO = self.node:CreateScriptObject("Speed")
  self.speedSO.speed_ = self.MOVE_FORCE
  
  self:SubscribeToEvent("Update", "FirstPerson:HandleUpdate")
  --self:SubscribeToEvent("PostUpdate", "FirstPerson:HandlePostUpdate")
  self:SubscribeToEvent(self.node, "NodeCollision", "FirstPerson:HandleNodeCollision")
  self:SubscribeToEvent("KeyDown", "FirstPerson:HandleKeyDown")
end

function FirstPerson:Stop()
  input:RemoveScreenJoystick(self.joyID_)
end

function FirstPerson:UpdateTouches(joyID, controls, buttControls)
  local joystick = input:GetJoystick(joyID)
  
  if joystick.numHats > 0 then
    if bit.band(joystick:GetHatPosition(0), HAT_LEFT) ~= 0 then controls:Set(self.CTRL_LEFT, true) end
    if bit.band(joystick:GetHatPosition(0), HAT_RIGHT) ~= 0 then controls:Set(self.CTRL_RIGHT, true) end
    if bit.band(joystick:GetHatPosition(0), HAT_UP) ~= 0 then controls:Set(self.CTRL_FORWARD, true) end
    if bit.band(joystick:GetHatPosition(0), HAT_DOWN) ~= 0 then controls:Set(self.CTRL_BACK, true) end
    
    if bit.band(joystick:GetHatPosition(1), HAT_LEFT) ~= 0 then controls:Set(self.CTRL_CAMLEFT, true) end
    if bit.band(joystick:GetHatPosition(1), HAT_RIGHT) ~= 0 then controls:Set(self.CTRL_CAMRIGHT, true) end
    if bit.band(joystick:GetHatPosition(1), HAT_UP) ~= 0 then controls:Set(self.CTRL_CAMDOWN, true) end
    if bit.band(joystick:GetHatPosition(1), HAT_DOWN) ~= 0 then controls:Set(self.CTRL_CAMUP, true) end
    --[[
    --if bit.band(joystick:GetHatPosition(1), bit.bor(HAT_UP, HAT_LEFT)) ~= 0 then
    if bit.band(joystick:GetHatPosition(1), HAT_LEFTUP) ~= 0 then
      controls:Set(self.CTRL_CAMUP, true)
      controls:Set(self.CTRL_CAMLEFT, true)
    end
    
    --if bit.band(joystick:GetHatPosition(1), bit.bor(HAT_UP, HAT_RIGHT)) ~= 0 then
    if bit.band(joystick:GetHatPosition(1), HAT_RIGHTUP) ~= 0 then
      controls:Set(self.CTRL_CAMUP, true)
      controls:Set(self.CTRL_CAMRIGHT, true)
    end
    
    --if bit.band(joystick:GetHatPosition(1), bit.bor(HAT_DOWN, HAT_LEFT)) ~= 0 then
    if bit.band(joystick:GetHatPosition(1), HAT_LEFTDOWN) ~= 0 then
      controls:Set(self.CTRL_CAMDOWN, true)
      controls:Set(self.CTRL_CAMLEFT, true)
    end
    
    --if bit.band(joystick:GetHatPosition(1), bit.bor(HAT_DOWN, HAT_RIGHT)) ~= 0 then
    if bit.band(joystick:GetHatPosition(1), HAT_RIGHTDOWN) ~= 0 then
      controls:Set(self.CTRL_CAMDOWN, true)
      controls:Set(self.CTRL_CAMRIGHT, true)
    end
    --]]
  end
  
  if joystick.numButtons > 0 then
    if joystick:GetButtonDown(0) == true then buttControls:Set(self.CTRL_JUMP, true) end
    if joystick:GetButtonDown(1) == true then buttControls:Set(self.CTRL_GRAB, true) end
  end
  
end

function FirstPerson:HandleUpdate(eventType, eventData)
  local timeStep = eventData["TimeStep"]:GetFloat()

  self.controls_:Set(self.CTRL_FORWARD + self.CTRL_BACK + self.CTRL_LEFT + self.CTRL_RIGHT + self.CTRL_CAMLEFT + self.CTRL_CAMRIGHT + self.CTRL_CAMDOWN + self.CTRL_CAMUP, false)
  
  self.buttControls_:Set(self.CTRL_JUMP + self.CTRL_GRAB, false)

  if GetPlatform() == "Android" or input.touchEmulation then
    self:UpdateTouches(self.joyID_, self.controls_, self.buttControls_)
  end

  if ui.focusElement == nil then
    if input:GetKeyDown(KEY_W) then self.controls_:Set(self.CTRL_FORWARD, true) end
    if input:GetKeyDown(KEY_S) then self.controls_:Set(self.CTRL_BACK, true) end
    if input:GetKeyDown(KEY_A) then self.controls_:Set(self.CTRL_LEFT, true) end
    if input:GetKeyDown(KEY_D) then self.controls_:Set(self.CTRL_RIGHT, true) end
    if input:GetKeyDown(KEY_SPACE) then self.buttControls_:Set(self.CTRL_JUMP, true) end
    if input:GetKeyDown(KEY_TAB) then self.buttControls_:Set(self.CTRL_GRAB, true) end
  end

  if GetPlatform() == "Android" or input.touchEmulation then
    if self.controls_:IsDown(self.CTRL_CAMLEFT) == true then
      self.controls_.yaw = self.controls_.yaw - self.HATYAW_SENSITIVITY
    elseif self.controls_:IsDown(self.CTRL_CAMRIGHT) == true then
      self.controls_.yaw = self.controls_.yaw + self.HATYAW_SENSITIVITY
    end

    if self.controls_:IsDown(self.CTRL_CAMUP) == true then
      self.controls_.pitch = self.controls_.pitch + self.HATYAW_SENSITIVITY
    elseif self.controls_:IsDown(self.CTRL_CAMDOWN) == true then
      self.controls_.pitch = self.controls_.pitch - self.HATYAW_SENSITIVITY
    end
   else
    self.controls_.yaw = self.controls_.yaw + input.mouseMoveX * self.YAW_SENSITIVITY
    self.controls_.pitch = self.controls_.pitch + input.mouseMoveY * self.YAW_SENSITIVITY
  end

  if self.body_ == nil then
    return
  end
  
  if self.body_:GetAngularFactor() == Vector3(0.0, 0.0, 0.0) then
    if GetPlatform() == "Android" or input.touchEmulation then
      self.controls_.pitch = Clamp(self.controls_.pitch, 0.0, 0.0)
    else
      self.controls_.pitch = Clamp(self.controls_.pitch, -80.0, 80.0)
    end
  
    self.node.rotation = Quaternion(self.controls_.yaw, Vector3(0.0, 1.0, 0.0))
    
    self.cameraNode_.rotation = Quaternion(self.controls_.pitch, Vector3(1.0, 0.0, 0.0))
  end

end

function FirstPerson:FixedUpdate(timeStep)
  if self.body_ == nil then return end
  
  if self.onGround_ == false then
    self.body_:SetGravityOverride(Vector3(0.0, -50.0, 0.0))
  else
    self.body_:SetGravityOverride(Vector3(0.0, -9.81, 0.0))
  end
  
  local rot = self.node.rotation
  local moveDir = Vector3(0.0, 0.0, 0.0)

  if self.controls_:IsDown(self.CTRL_FORWARD) then
    moveDir = moveDir + Vector3(0.0, 0.0, 1.0)
  end
  if self.controls_:IsDown(self.CTRL_BACK) then
    moveDir = moveDir + Vector3(0.0, 0.0, -1.0)
  end
  if self.controls_:IsDown(self.CTRL_LEFT) then
    moveDir = moveDir + Vector3(-1.0, 0.0, 0.0)
  end
  if self.controls_:IsDown(self.CTRL_RIGHT) then
    moveDir = moveDir + Vector3(1.0, 0.0, 0.0)
  end

  if moveDir:LengthSquared() > 0.0 then
    moveDir:Normalize()
  end
  
  if moveDir == Vector3(0.0, 0.0, 0.0) then
    self.body_:SetFriction(10.0)
  else
    self.body_:SetFriction(0.0)
  end
  
  if self.onGround_ == false then
    self.body_:ApplyImpulse(rot * moveDir * self.INAIR_MOVE_FORCE)
  else
    local velocity = self.body_.linearVelocity
    local planeVelocity = Vector3(velocity.x, 0.0, velocity.z)

    self.body_:ApplyImpulse(rot * moveDir * Max(0.0, self.speedSO.speed_))

    local brakeForce = planeVelocity * -self.BRAKE_FORCE
    self.body_:ApplyImpulse(brakeForce)
    
    if self.buttControls_:IsDown(self.CTRL_JUMP) then
      if self.okToJump_ then
        self.body_:ApplyImpulse(Vector3(0.0, 1.0, 0.0) * self.JUMP_FORCE)
        self.okToJump_ = false
      end
    else
      self.okToJump_ = true
    end
  end

  self.onGround_ = false
  
  if self.buttControls_:IsDown(self.CTRL_GRAB) then
    if self.grabButtDown_ == false then
      self.grabButtDown_ = true
      
      if self.grabOrigin_:GetNumChildren() == 0 then
        
        if GetPlatform() == "Android" or input.touchEmulation then
          local bodies = LevelScene_:GetComponent("PhysicsWorld"):GetRigidBodies(Sphere(self.node:GetPosition(), self.grabRayDistance_), 1)

          for i, v in ipairs(bodies) do
            v:SetEnabled(false)
            local grabbedNode = v:GetNode()
            self.grabOrigin_:AddChild(grabbedNode)
            grabbedNode:SetPosition(Vector3(0.0, 0.0, 0.0))
          end
          
        else
          local camera = self.cameraNode_:GetComponent("Camera")
          local cameraRay = camera:GetScreenRay((graphics.width * 0.5) / graphics.width, (graphics.height * 0.5) / graphics.height)

          local result = LevelScene_:GetComponent("PhysicsWorld"):RaycastSingle(cameraRay, self.grabRayDistance_, 1)

          if result.body ~= nil then
            result.body:SetEnabled(false)
            local grabbedNode = result.body:GetNode()
            self.grabOrigin_:AddChild(grabbedNode)
            grabbedNode:SetPosition(Vector3(0.0, 0.0, 0.0))
          end

        end

      else
        local grabbedNode = self.grabOrigin_:GetChild(0)
        local worldpos = grabbedNode:GetWorldPosition()
        
        LevelScene_:AddChild(grabbedNode)
        grabbedNode:SetWorldPosition(worldpos)
        
        local body = grabbedNode:GetComponent("RigidBody")
        body:SetEnabled(true)
        
        local projectileSO = grabbedNode:CreateScriptObject("Projectile")
        
        body:ApplyImpulse(self.cameraNode_:GetWorldDirection() * self.throwImpulse_)
      end
      
    end
    
  else
    self.grabButtDown_ = false
  end
  
end

function FirstPerson:HandlePostUpdate(eventType, eventData)
end

function FirstPerson:HandleNodeCollision(eventType, eventData)
    local contacts = eventData["Contacts"]:GetBuffer()

    while not contacts.eof do
        local contactPosition = contacts:ReadVector3()
        local contactNormal = contacts:ReadVector3()
        local contactDistance = contacts:ReadFloat()
        local contactImpulse = contacts:ReadFloat()

        -- If contact is below node center and mostly vertical, assume it's a ground contact
        if contactPosition.y < self.node.position.y + 1.0 then
            local level = Abs(contactNormal.y)
            if level > 0.75 then
                self.onGround_ = true
            end
        end
    end
end

function FirstPerson:HandleKeyDown(eventType, eventData)
  local key = eventData["Key"]:GetInt()
  
  if key == KEY_SHIFT then
    self.mouseVisible_ = not self.mouseVisible_
    input:SetMouseVisible(self.mouseVisible_)
  end
  
end

function FirstPerson:TransformResize(targetRes, targetSize, targetPos)
		local rootExtent = IntVector2()

		rootExtent.x = graphics:GetWidth()
		rootExtent.y = graphics:GetHeight()

		local scaledExtent = IntVector2()

		scaledExtent.x = ( targetSize.x *  rootExtent.x ) / targetRes.x
		scaledExtent.y = ( targetSize.y *  rootExtent.y ) / targetRes.y

		local scaledPosition = IntVector2(
				( targetPos.x *  rootExtent.x ) / targetRes.x,
				( targetPos.y *  rootExtent.y ) / targetRes.y)

    return scaledExtent, scaledPosition
end

function FirstPerson:GetDualJoyGuiString()
  local rootExtent, rootPosition = self:TransformResize(IntVector2(800, 480), IntVector2(800, 480), IntVector2(0, 0))
  local hat0Extent, hat0Position = self:TransformResize(IntVector2(800, 480), IntVector2(48, 48), IntVector2(48, 384))
  local hat1Extent, hat1Position = self:TransformResize(IntVector2(800, 480), IntVector2(48, 48), IntVector2(704, 384))
  local butt0Extent, butt0Position = self:TransformResize(IntVector2(800, 480), IntVector2(48, 48), IntVector2(704, 288))
  local butt1Extent, butt1Position = self:TransformResize(IntVector2(800, 480), IntVector2(48, 48), IntVector2(704, 192))
  
  return
  "<?xml version=\"1.0\"?>" ..
  "<element>" ..
  "<attribute name=\"Name\" value=\"DualJoy\" />" ..
  "<attribute name=\"Size\" value=\"" .. rootExtent.x .. " " .. rootExtent.y .. "\" />" ..
  "<attribute name=\"Variables\">" ..
  "<variant hash=\"633459751\" type=\"String\" value=\"/home/practicing01/Desktop/Programming/Urho3D/Build/bin/Data/UI/DualJoy.xml\" name=\"fileName\" />" ..
  "</attribute>" ..
  "<element type=\"Button\">" ..
  "<attribute name=\"Name\" value=\"Hat0\" />" ..
  "<attribute name=\"Position\" value=\"" .. hat0Position.x .. " " .. hat0Position.y .. "\" />" ..
  "<attribute name=\"Size\" value=\"" .. hat0Extent.x .. " " .. hat0Extent.y .. "\" />" ..
  "<attribute name=\"Texture\" value=\"Texture2D;Textures/roundSquare.png\" />" ..
  "<attribute name=\"Image Rect\" value=\"0 0 48 48\" />" ..
  "<attribute name=\"Border\" value=\"0 0 0 0\" />" ..
  "<attribute name=\"Hover Image Offset\" value=\"0 0\" />" ..
  "<attribute name=\"Blend Mode\" value=\"alpha\" />" ..
  "<attribute name=\"Pressed Image Offset\" value=\"0 0\" />" ..
  "</element>" ..
  "<element type=\"Button\">" ..
  "<attribute name=\"Name\" value=\"Hat1\" />" ..
  "<attribute name=\"Position\" value=\"" .. hat1Position.x .. " " .. hat1Position.y .. "\" />" ..
  "<attribute name=\"Size\" value=\"" .. hat1Extent.x .. " " .. hat1Extent.y .. "\" />" ..
  "<attribute name=\"Texture\" value=\"Texture2D;Textures/roundSquare.png\" />" ..
  "<attribute name=\"Image Rect\" value=\"0 0 48 48\" />" ..
  "<attribute name=\"Border\" value=\"0 0 0 0\" />" ..
  "<attribute name=\"Hover Image Offset\" value=\"0 0\" />" ..
  "<attribute name=\"Blend Mode\" value=\"alpha\" />" ..
  "<attribute name=\"Pressed Image Offset\" value=\"0 0\" />" ..
  "</element>" ..
  "<element type=\"Button\">" ..
  "<attribute name=\"Name\" value=\"Button0\" />" ..
  "<attribute name=\"Position\" value=\"" .. butt0Position.x .. " " .. butt0Position.y .. "\" />" ..
  "<attribute name=\"Size\" value=\"" .. butt0Extent.x .. " " .. butt0Extent.y .. "\" />" ..
  "<attribute name=\"Texture\" value=\"Texture2D;Textures/foot.png\" />" ..
  "<attribute name=\"Image Rect\" value=\"0 0 48 48\" />" ..
  "<attribute name=\"Border\" value=\"0 0 0 0\" />" ..
  "<attribute name=\"Hover Image Offset\" value=\"0 0\" />" ..
  "<attribute name=\"Blend Mode\" value=\"alpha\" />" ..
  "<attribute name=\"Pressed Image Offset\" value=\"0 0\" />" ..
  "</element>" ..
  "<element type=\"Button\">" ..
  "<attribute name=\"Name\" value=\"Button1\" />" ..
  "<attribute name=\"Position\" value=\"" .. butt1Position.x .. " " .. butt1Position.y .. "\" />" ..
  "<attribute name=\"Size\" value=\"" .. butt1Extent.x .. " " .. butt1Extent.y .. "\" />" ..
  "<attribute name=\"Texture\" value=\"Texture2D;Textures/hand.png\" />" ..
  "<attribute name=\"Image Rect\" value=\"0 0 48 48\" />" ..
  "<attribute name=\"Border\" value=\"0 0 0 0\" />" ..
  "<attribute name=\"Hover Image Offset\" value=\"0 0\" />" ..
  "<attribute name=\"Blend Mode\" value=\"alpha\" />" ..
  "<attribute name=\"Pressed Image Offset\" value=\"0 0\" />" ..
  "</element>" ..
  "</element>"
end
