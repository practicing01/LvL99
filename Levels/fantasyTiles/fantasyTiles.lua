require "LuaScripts/ShadedSprite"

fantasyTiles = ScriptObject()

function fantasyTiles:Start()
  self.player_ = nil
  self.playerBody_ = nil
  self.cameraNode = nil
  self.viewport_ = nil
  self.MOVE_FORCE = 0.1
  self.INAIR_MOVE_FORCE = 0.1
  self.BRAKE_FORCE = 0.025
  self.JUMP_FORCE = 9.0
  self.CTRL_FORWARD = 1
  self.CTRL_BACK = 2
  self.CTRL_LEFT = 4
  self.CTRL_RIGHT = 8
  self.CTRL_JUMP = 1
  self.controls_ = Controls()
  self.buttControls_ = Controls()
  self.onGround_ = false
  self.okToJump_ = false
  self.ShadedSprite_ = nil
end

function fantasyTiles:DelayedStart()
  self.player_ = LevelScene_:GetChild("pepper")
  self.playerBody_ = self.player_:GetComponent("RigidBody")
  self.cameraNode = self.player_:GetChild("camera")
  self.viewport_ = Viewport:new(LevelScene_, self.cameraNode:GetComponent("Camera"))
  renderer:SetViewport(0, self.viewport_)
  
  self.playerBody_.collisionEventMode = COLLISION_ALWAYS
    
  self:LoadPlayerSprite()
  
  self:SubscribeToEvent("Update", "fantasyTiles:HandleUpdate")
  self:SubscribeToEvent(self.player_, "NodeCollision", "fantasyTiles:HandleNodeCollision")
end

function fantasyTiles:Stop()
  --
end

function fantasyTiles:HandleUpdate(eventType, eventData)
  local timeStep = eventData["TimeStep"]:GetFloat()

  self.controls_:Set(self.CTRL_FORWARD + self.CTRL_BACK + self.CTRL_LEFT + self.CTRL_RIGHT, false)
  self.buttControls_:Set(self.CTRL_JUMP, false)

  if ui.focusElement == nil then
    if input:GetKeyDown(KEY_W) then self.controls_:Set(self.CTRL_FORWARD, true) end
    if input:GetKeyDown(KEY_S) then self.controls_:Set(self.CTRL_BACK, true) end
    if input:GetKeyDown(KEY_A) then self.controls_:Set(self.CTRL_LEFT, true) end
    if input:GetKeyDown(KEY_D) then self.controls_:Set(self.CTRL_RIGHT, true) end
    if input:GetKeyDown(KEY_SPACE) then self.buttControls_:Set(self.CTRL_JUMP, true) end
  end
  
end

function fantasyTiles:FixedUpdate(timeStep)
  --local rot = self.player_.rotation
  local moveDir = Vector3(0.0, 0.0, 0.0)

  if self.controls_:IsDown(self.CTRL_FORWARD) then
    moveDir = moveDir + Vector3(0.0, 0.0, 1.0)
  end
  if self.controls_:IsDown(self.CTRL_BACK) then
    moveDir = moveDir + Vector3(0.0, 0.0, -1.0)
  end
  if self.controls_:IsDown(self.CTRL_LEFT) then
    moveDir = moveDir + Vector3(-1.0, 0.0, 0.0)
    
    self.playerBody_:SetRotation(Quaternion(0.0, 180.0, 0.0))
    self.cameraNode:SetRotation(Quaternion(0.0, 180.0, 0.0))
  end
  if self.controls_:IsDown(self.CTRL_RIGHT) then
    moveDir = moveDir + Vector3(1.0, 0.0, 0.0)
    
    self.playerBody_:SetRotation(Quaternion(0.0, 0.0, 0.0))
    self.cameraNode:SetRotation(Quaternion(0.0, 0.0, 0.0))
  end

  if moveDir:LengthSquared() > 0.0 then
    moveDir:Normalize()
  end
  
  if moveDir == Vector3(0.0, 0.0, 0.0) then
    self.playerBody_:SetFriction(10.0)
    self.ShadedSprite_:AnimateNode("idle", false)
  else
    self.playerBody_:SetFriction(0.0)
  end
  
  if self.onGround_ == false then
    self.playerBody_:ApplyImpulse(--[[rot *--]] moveDir * self.INAIR_MOVE_FORCE)
    self.ShadedSprite_:AnimateNode("fly", false)
  else
    if moveDir ~= Vector3(0.0, 0.0, 0.0) then
      self.ShadedSprite_:AnimateNode("run", false)
    end
    
    local velocity = self.playerBody_.linearVelocity
    local planeVelocity = Vector3(velocity.x, 0.0, velocity.z)

    self.playerBody_:ApplyImpulse(--[[rot *--]] moveDir * Max(0.0, self.MOVE_FORCE))

    local brakeForce = planeVelocity * -self.BRAKE_FORCE
    self.playerBody_:ApplyImpulse(brakeForce)
    
    if self.buttControls_:IsDown(self.CTRL_JUMP) == true then
      if self.okToJump_ then
        self.playerBody_:ApplyImpulse(Vector3(0.0, 1.0, 0.0) * (self.JUMP_FORCE - velocity.y))
        self.okToJump_ = false
      end
    else
      self.okToJump_ = true
    end
    
  end

  self.onGround_ = false
  
end

function fantasyTiles:HandleNodeCollision(eventType, eventData)
    local contacts = eventData["Contacts"]:GetBuffer()

    while not contacts.eof do
        local contactPosition = contacts:ReadVector3()
        local contactNormal = contacts:ReadVector3()
        local contactDistance = contacts:ReadFloat()
        local contactImpulse = contacts:ReadFloat()

        -- If contact is below node center and mostly vertical, assume it's a ground contact
        if contactPosition.y < self.player_.position.y then
            local level = Abs(contactNormal.y)
            if level > 0.0 then
                self.onGround_ = true
                self.okToJump_ = true
            end
        end
    end
end

function fantasyTiles:LoadPlayerSprite()
  self.ShadedSprite_ = self.player_:CreateScriptObject("ShadedSprite")
  
  self.ShadedSprite_.shadedSprite_.model_ = self.player_:GetComponent("AnimatedModel")
  
  local files = {"idle", "run", "fly"}
  
  for i, v in ipairs(files) do
    local sheet = cache:GetResource("SpriteSheet2D", "Data/Textures/pepper/" .. v .. "Sheet.xml")
    table.insert(self.ShadedSprite_.shadedSprite_.sheets_, sheet)
    
    local ani = cache:GetResource("XMLFile", "Data/Textures/pepper/" .. v .. "Ani.xml"):GetRoot()

    --todo check if this local disappears after scope
    local spriteSheetAni = {
      name_ = "",
      material_ = "",
      loop_ = false,
      frames_ = {}
      }

    table.insert(self.ShadedSprite_.shadedSprite_.animations_, spriteSheetAni)

		spriteSheetAni.name_ = ani:GetChild("Name"):GetAttribute("name")
		spriteSheetAni.material_ = ani:GetChild("Material"):GetAttribute("material")
		spriteSheetAni.loop_ = ani:GetChild("Loop"):GetBool("loop")

		local frameCount = ani:GetChild("FrameCount"):GetInt("frameCount")

    for x = 0, frameCount - 1, 1 do
      
      local frame = {
        duration_ = 0,
        sprite_ = ""
      }

			local child = "Frame" .. x

			frame.duration_ = ani:GetChild(child):GetFloat("duration")
			frame.sprite_ = ani:GetChild(child):GetAttribute("sprite")
      
      table.insert(spriteSheetAni.frames_, frame)
		end
  end
  
  --[[local vm = VariantMap()
  vm["Animation"] = Variant("fly")
  vm["FlipX"] = Variant(false)
  --self.player_:SendEvent("AnimateNode", vm)
  
  self.ShadedSprite_:HandleAnimateNode(nil, vm)--]]
  self.ShadedSprite_:AnimateNode("idle", false)
end
