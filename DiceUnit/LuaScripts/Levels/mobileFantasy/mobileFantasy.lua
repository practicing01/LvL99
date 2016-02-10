local bit = require("bit")
require "LuaScripts/SunRotator"

mobileFantasy = ScriptObject()

function mobileFantasy:Start()
  self.joyID_ = 0
  self.cameraBody_ = nil
  self.cameraNode_ = nil
  self.viewport_ = nil
  self.MOVE_FORCE = 1.0
  self.BRAKE_FORCE = 0.025
  self.CTRL_FORWARD = 1
  self.CTRL_BACK = 2
  self.CTRL_LEFT = 4
  self.CTRL_RIGHT = 8
  self.CTRL_JUMP = 1
  self.controls_ = Controls()
  self.buttControls_ = Controls()
  self.cameraSlerpInterval_ = 0.1
  
  self.gameMenu_ = nil
  self.unitSelectWindow_ = nil
  self.greyFactionButt_ = nil
  self.lightFactionButt_ = nil
  self.darkFactionButt_ = nil
  self.unitList_ = nil
  self.unitListSprite_ = nil
  self.unitSelectButt_ = nil
  self.prevFactiontButt_ = nil
  self.resetButt_ = nil
  
  self.dicePreviewNode_ = nil
  self.diceNode_ = nil
  
  self.unitMaterialPathsVariantMap_ = nil
  
  self.greyUnitNodeTable_ = {}
  self.lightUnitNodeTable_ = {}
  self.darkUnitNodeTable_ = {}
  self.selectedUnitTable_ = nil
  self.selectedUnitIndex_ = M_MAX_UNSIGNED
  
  self.TURNPHASE_LIGHT = 0
  self.TURNPHASE_DARK = 1
  self.turnPhase_ = self.TURNPHASE_LIGHT
  self.phaseText_ = nil
  self.STRINGHASH_FACTION = StringHash("Faction")
    
  self.canSpawn_ = true
  self.lookAtVector_ = Vector3(0.0, 0.0, 0.0)
  
  self.birdPathNode_ = nil
end

function mobileFantasy:DelayedStart()
  self.cameraNode_ = LevelScene_:GetChild("camera")
  self.cameraBody_ = self.cameraNode_:GetComponent("RigidBody")
  self.viewport_ = Viewport:new(LevelScene_, self.cameraNode_:GetComponent("Camera"))
  renderer:SetViewport(0, self.viewport_) 
 
  self.dicePreviewNode_ = self.cameraNode_:GetChild("dice")
  self.diceNode_ = LevelScene_:GetChild("dice")
  
  LevelScene_:GetChild("Lamp"):CreateScriptObject("SunRotator")
  self.birdPathNode_ = LevelScene_:GetChild("birdPath"):GetChild("bat")
  LevelScene_:GetChild("birdPath"):SetDeepEnabled(true)
  
  local camJoyXMLFile = XMLFile()
  
  camJoyXMLFile:FromString(self:GetCamJoyGuiString())
  
  self.joyID_ = input:AddScreenJoystick(camJoyXMLFile, cache:GetResource("XMLFile", "UI/DefaultStyle.xml"))
  
  if GetPlatform() == "Android" then
    input:SetScreenJoystickVisible(self.joyID_, true)
  else
    input:SetScreenJoystickVisible(self.joyID_, false)
  end
  
  self.gameMenu_ = ui:LoadLayout(cache:GetResource("XMLFile", "UI/DiceUnitMenus.xml"))
  
  local vm = VariantMap()
  vm["Element"] = Variant(self.gameMenu_)
  SendEvent("AddGuiTargets", vm)

  ui.root:AddChild(self.gameMenu_)
  
  self:RecursiveResize(self.gameMenu_)
  
  vm["Element"] = Variant(self.gameMenu_)
  SendEvent("Resized", vm)
  
  self.greyFactionButt_ = self.gameMenu_:GetChild("grey", true)
  self.lightFactionButt_ = self.gameMenu_:GetChild("light", true)
  self.darkFactionButt_ = self.gameMenu_:GetChild("dark", true)
  self.unitListSprite_ = self.gameMenu_:GetChild("unitSelectSprite", true)
  self.unitList_ = self.gameMenu_:GetChild("unitSelectList", true)
  self.unitSelectButt_ = self.gameMenu_:GetChild("select", true)
  self.phaseText_ = self.gameMenu_:GetChild("turnPhase", true)
  self.resetButt_ = self.gameMenu_:GetChild("reset", true)
  
  self:SubscribeToEvent("Update", "mobileFantasy:HandleUpdate")
  
  self:SubscribeToEvent(LevelScene_:GetChild("spawnZone"), "NodeCollisionStart", "mobileFantasy:HandleSpawnZoneNodeCollisionStart")
  self:SubscribeToEvent(LevelScene_:GetChild("spawnZone"), "NodeCollisionEnd", "mobileFantasy:HandleSpawnZoneNodeCollisionEnd")
    
  self:SubscribeToEvent(self.greyFactionButt_, "Released", "mobileFantasy:HandleReleased")
  self:SubscribeToEvent(self.lightFactionButt_, "Released", "mobileFantasy:HandleReleased")
  self:SubscribeToEvent(self.darkFactionButt_, "Released", "mobileFantasy:HandleReleased")
  self:SubscribeToEvent(self.unitList_, "ItemSelected", "mobileFantasy:HandleItemSelected")
  self:SubscribeToEvent(self.unitList_, "ItemDeselected", "mobileFantasy:HandleItemDeselected")
  self:SubscribeToEvent(self.unitSelectButt_, "Released", "mobileFantasy:HandleReleased")
  self:SubscribeToEvent(self.resetButt_, "Released", "mobileFantasy:HandleReleased")
  
  self:PopulateUnitVariantMap()
  
  self:SubscribeToEvent("UnitCaptured", "mobileFantasy:HandleUnitCaptured")
  
  audio:SetListener(self.cameraNode_:GetComponent("SoundListener"));
  self:SubscribeToEvent(LevelScene_:GetChild("collisionShapes"), "NodeCollisionStart", "mobileFantasy:HandleWallNodeCollisionStart")
  
  --self:SubscribeToEvent("PostRenderUpdate", "mobileFantasy:HandlePostRenderUpdate")
end

function mobileFantasy:Stop()
  input:RemoveScreenJoystick(self.joyID_)
  ui.root:RemoveChild(self.gameMenu_)
end

function mobileFantasy:HandlePostRenderUpdate(eventType, eventData)
  local debug = LevelScene_:GetComponent("DebugRenderer")
  LevelScene_:GetComponent("PhysicsWorld"):DrawDebugGeometry(true)
  --LevelScene_:GetComponent("Octree"):DrawDebugGeometry(true)
  --renderer:DrawDebugGeometry(true)

  --[[local nodePos = self.node:GetWorldPosition()
  local aimPoint = self.rotDummy_:GetWorldPosition()
  local rayDir = (aimPoint - nodePos):Normalized()
  rayDir = rayDir * Vector3(-1.0, -1.0, -1.0)

  --debug:AddLine(aimPoint, aimPoint + (rayDir * self.rayDistance_), Color(1.0, 1.0, 1.0), false)
  debug:AddCross(aimPoint, 2.0 , Color(1.0, 1.0, 1.0), false)
  debug:AddCross(aimPoint + (rayDir * self.rayDistance_), 2.0, Color(1.0, 1.0, 1.0), false)
  
  debug:AddLine(nodePos, nodePos + (self.node:GetDirection() * self.rayDistance_), Color(1.0, 1.0, 1.0), false)
  debug:AddLine(aimPoint, aimPoint + (self.node:GetDirection() * self.rayDistance_), Color(1.0, 1.0, 1.0), false)--]]
end

function mobileFantasy:UpdateTouches(joyID, controls, buttControls)
  local joystick = input:GetJoystick(joyID)
  
  if joystick.numButtons > 0 then
    if joystick:GetButtonDown(0) == true then controls:Set(self.CTRL_LEFT, true) end
    if joystick:GetButtonDown(1) == true then controls:Set(self.CTRL_RIGHT, true) end
    if joystick:GetButtonDown(2) == true then controls:Set(self.CTRL_FORWARD, true) end
    if joystick:GetButtonDown(3) == true then controls:Set(self.CTRL_BACK, true) end
  end
  
end

function mobileFantasy:HandleUpdate(eventType, eventData)
  local timeStep = eventData["TimeStep"]:GetFloat()

  self.controls_:Set(self.CTRL_FORWARD + self.CTRL_BACK + self.CTRL_LEFT + self.CTRL_RIGHT, false)
  self.buttControls_:Set(self.CTRL_JUMP, false)

  if GetPlatform() == "Android" or input.touchEmulation then
    self:UpdateTouches(self.joyID_, self.controls_, self.buttControls_)
  end

  if ui.focusElement == nil then
    if input:GetKeyDown(KEY_W) then self.controls_:Set(self.CTRL_FORWARD, true) end
    if input:GetKeyDown(KEY_S) then self.controls_:Set(self.CTRL_BACK, true) end
    if input:GetKeyDown(KEY_A) then self.controls_:Set(self.CTRL_LEFT, true) end
    if input:GetKeyDown(KEY_D) then self.controls_:Set(self.CTRL_RIGHT, true) end
    if input:GetKeyDown(KEY_SPACE) then self.buttControls_:Set(self.CTRL_JUMP, true) end
  end
  
  
  --local rotBak = self.cameraNode_:GetRotation()
  
  self.cameraNode_:LookAt(self.lookAtVector_)
  
  --local rotNew = self.cameraNode_:GetRotation()
  
  --self.cameraNode_:SetRotation(rotBak:Slerp(rotNew, self.cameraSlerpInterval_ * timeStep))
  
  self.birdPathNode_:GetComponent("SplinePath"):Move(timeStep)
  
  if self.birdPathNode_:GetComponent("SplinePath"):IsFinished() == true then
    self.birdPathNode_:GetComponent("SplinePath"):Reset()
  end
  
end

function mobileFantasy:FixedUpdate(timeStep)
  local rot = self.cameraBody_:GetRotation()
  
  local moveDir = Vector3(0.0, 0.0, 0.0)

  if self.controls_:IsDown(self.CTRL_FORWARD) then
    moveDir = moveDir + Vector3(0.0, 0.0, 1.0)
  end
  if self.controls_:IsDown(self.CTRL_BACK) then
    moveDir = moveDir + Vector3(0.0, 0.0, -1.0)
  end
  if self.controls_:IsDown(self.CTRL_LEFT) then
    moveDir = moveDir + Vector3(-1.0, 0.0, 1.0)    
  end
  if self.controls_:IsDown(self.CTRL_RIGHT) then
    moveDir = moveDir + Vector3(1.0, 0.0, 1.0)
  end

  if moveDir:LengthSquared() > 0.0 then
    moveDir:Normalize()
  end
  
  if moveDir == Vector3(0.0, 0.0, 0.0) then
    self.cameraBody_:SetLinearVelocity(Vector3(0.0, 0.0, 0.0))
  end
  
  local velocity = self.cameraBody_.linearVelocity
  local planeVelocity = Vector3(velocity.x, 0.0, velocity.z)

  self.cameraBody_:ApplyImpulse(rot * moveDir * Max(0.0, self.MOVE_FORCE))

  local brakeForce = planeVelocity * -self.BRAKE_FORCE
  self.cameraBody_:ApplyImpulse(brakeForce)

end

function mobileFantasy:HandleNodeCollision(eventType, eventData)
    --[[local contacts = eventData["Contacts"]:GetBuffer()

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
    end--]]
end

function mobileFantasy:TransformResize(targetRes, targetSize, targetPos)
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

function mobileFantasy:GetCamJoyGuiString()
  local rootExtent, rootPosition = self:TransformResize(IntVector2(800, 480), IntVector2(800, 480), IntVector2(0, 0))
  local butt0Extent, butt0Position = self:TransformResize(IntVector2(800, 480), IntVector2(24, 48), IntVector2(0, 216))
  local butt1Extent, butt1Position = self:TransformResize(IntVector2(800, 480), IntVector2(24, 48), IntVector2(776, 216))
  local butt2Extent, butt2Position = self:TransformResize(IntVector2(800, 480), IntVector2(48, 24), IntVector2(376, 0))
  local butt3Extent, butt3Position = self:TransformResize(IntVector2(800, 480), IntVector2(48, 24), IntVector2(376, 456))
  
  return
  "<?xml version=\"1.0\"?>" ..
  "<element>" ..
  "<attribute name=\"Name\" value=\"DiceUnitCamJoy\" />" ..
  "<attribute name=\"Size\" value=\"" .. rootExtent.x .. " " .. rootExtent.y .. "\" />" ..
  "<attribute name=\"Variables\">" ..
  "<variant hash=\"633459751\" type=\"String\" value=\"/home/practicing01/Desktop/Programming/Urho3D/Build/bin/Data/UI/DiceUnitCamJoy.xml\" name=\"fileName\" />" ..
  "</attribute>" ..
  "<element type=\"Button\">" ..
  "<attribute name=\"Name\" value=\"Button0\" />" ..
  "<attribute name=\"Position\" value=\"" .. butt0Position.x .. " " .. butt0Position.y .. "\" />" ..
  "<attribute name=\"Size\" value=\"" .. butt0Extent.x .. " " .. butt0Extent.y .. "\" />" ..
  "<attribute name=\"Texture\" value=\"Texture2D;Textures/barV.png\" />" ..
  "<attribute name=\"Image Rect\" value=\"0 0 24 48\" />" ..
  "<attribute name=\"Border\" value=\"0 0 0 0\" />" ..
  "<attribute name=\"Hover Image Offset\" value=\"0 0\" />" ..
  "<attribute name=\"Blend Mode\" value=\"alpha\" />" ..
  "<attribute name=\"Pressed Image Offset\" value=\"0 0\" />" ..
  "</element>" ..
  "<element type=\"Button\">" ..
  "<attribute name=\"Name\" value=\"Button1\" />" ..
  "<attribute name=\"Position\" value=\"" .. butt1Position.x .. " " .. butt1Position.y .. "\" />" ..
  "<attribute name=\"Size\" value=\"" .. butt1Extent.x .. " " .. butt1Extent.y .. "\" />" ..
  "<attribute name=\"Texture\" value=\"Texture2D;Textures/barV.png\" />" ..
  "<attribute name=\"Image Rect\" value=\"0 0 24 48\" />" ..
  "<attribute name=\"Border\" value=\"0 0 0 0\" />" ..
  "<attribute name=\"Hover Image Offset\" value=\"0 0\" />" ..
  "<attribute name=\"Blend Mode\" value=\"alpha\" />" ..
  "<attribute name=\"Pressed Image Offset\" value=\"0 0\" />" ..
  "</element>" ..
  "<element type=\"Button\">" ..
  "<attribute name=\"Name\" value=\"Button2\" />" ..
  "<attribute name=\"Position\" value=\"" .. butt2Position.x .. " " .. butt2Position.y .. "\" />" ..
  "<attribute name=\"Size\" value=\"" .. butt2Extent.x .. " " .. butt2Extent.y .. "\" />" ..
  "<attribute name=\"Texture\" value=\"Texture2D;Textures/barH.png\" />" ..
  "<attribute name=\"Image Rect\" value=\"0 0 48 24\" />" ..
  "<attribute name=\"Border\" value=\"0 0 0 0\" />" ..
  "<attribute name=\"Hover Image Offset\" value=\"0 0\" />" ..
  "<attribute name=\"Blend Mode\" value=\"alpha\" />" ..
  "<attribute name=\"Pressed Image Offset\" value=\"0 0\" />" ..
  "</element>" ..
  "<element type=\"Button\">" ..
  "<attribute name=\"Name\" value=\"Button3\" />" ..
  "<attribute name=\"Position\" value=\"" .. butt3Position.x .. " " .. butt3Position.y .. "\" />" ..
  "<attribute name=\"Size\" value=\"" .. butt3Extent.x .. " " .. butt3Extent.y .. "\" />" ..
  "<attribute name=\"Texture\" value=\"Texture2D;Textures/barH.png\" />" ..
  "<attribute name=\"Image Rect\" value=\"0 0 48 24\" />" ..
  "<attribute name=\"Border\" value=\"0 0 0 0\" />" ..
  "<attribute name=\"Hover Image Offset\" value=\"0 0\" />" ..
  "<attribute name=\"Blend Mode\" value=\"alpha\" />" ..
  "<attribute name=\"Pressed Image Offset\" value=\"0 0\" />" ..
  "</element>" ..
  "</element>"
end

function mobileFantasy:RecursiveResize(ele)
  local targetSize = ele:GetSize()
  local targetPos = ele:GetPosition()
  
  local scaledSize, scaledPos = self:TransformResize(IntVector2(800, 480), targetSize, targetPos)
  
  ele:SetSize(scaledSize)
  ele:SetPosition(scaledPos)
  
  for x = 0, ele:GetNumChildren() - 1, 1 do
    local child = ele:GetChild(x)
    self:RecursiveResize(child)
  end
end

function mobileFantasy:HandleReleased(eventType, eventData)
  local butt = eventData["Element"]:GetPtr("UIElement")
  
  if butt == self.resetButt_ then
    self:ResetUnits()
    return
    
  end
  
  if self.unitListSprite_:GetOpacity() == 0.0 then
    self:ToggleUnitList()
    
    if butt == self.lightFactionButt_ then
      self.selectedUnitTable_ = self.lightUnitNodeTable_
      self:PopulateUnitList(self.lightUnitNodeTable_)
      
    elseif butt == self.darkFactionButt_ then
      self.selectedUnitTable_ = self.darkUnitNodeTable_
      self:PopulateUnitList(self.darkUnitNodeTable_)
      
    elseif butt == self.greyFactionButt_ then
      self.selectedUnitTable_ = self.greyUnitNodeTable_
      self:PopulateUnitList(self.greyUnitNodeTable_)
      
    end

  elseif self.unitListSprite_:GetOpacity() == 1.0 and self.prevFactiontButt_ == butt then
    self:ToggleUnitList()
    
  else
    if butt == self.lightFactionButt_ then
      self.selectedUnitTable_ = self.lightUnitNodeTable_
      self:PopulateUnitList(self.lightUnitNodeTable_)
      
    elseif butt == self.unitSelectButt_ then
      self:SelectUnit()
    
    elseif butt == self.darkFactionButt_ then
      self.selectedUnitTable_ = self.darkUnitNodeTable_
      self:PopulateUnitList(self.darkUnitNodeTable_)
      
    elseif butt == self.greyFactionButt_ then
      self.selectedUnitTable_ = self.greyUnitNodeTable_
      self:PopulateUnitList(self.greyUnitNodeTable_)
      
    end
  end
  
  self.prevFactiontButt_ = butt
  
end

function mobileFantasy:HandleItemSelected(eventType, eventData)
  local list = eventData["Element"]:GetPtr("UIElement")
  local index = eventData["Selection"]:GetInt()

  list:GetItem(index):SetColor(Color(0.0, 0.5, 0.5, 1.0))
  
  self.dicePreviewNode_:GetChild("unit"):GetComponent("StaticModel"):ApplyMaterialList(self.unitMaterialPathsVariantMap_[list:GetItem(index):GetText()]:GetString())
end

function mobileFantasy:HandleItemDeselected(eventType, eventData)
  local list = eventData["Element"]:GetPtr("UIElement")
  local index = eventData["Selection"]:GetInt()

  list:GetItem(index):SetColor(Color(1.0, 1.0, 1.0, 1.0))
end

function mobileFantasy:PopulateUnitVariantMap()
  self.unitMaterialPathsVariantMap_ = VariantMap()

  local rootFolder = fileSystem:GetProgramDir() .. "Data/Models/mobileFantasyUnits/"
  local rootScriptFolder = "LuaScripts/Levels/mobileFantasy/units/"

  --if fileSystem:DirExists(rootFolder) == true then
  if 1 == 1 then
    local files = fileSystem:ScanDir(rootFolder, "", SCAN_FILES, false)

    if table.maxn(files) ~= 0 then
      for i=1, table.maxn(files) do
        if files[i] ~= "dice.mdl" and files[i] ~= "dice.txt" and files[i] ~= "diceDark.txt" and files[i] ~= "unit.mdl" and files[i] ~= "unit.txt" then
          local file = files[i].sub(files[i], 0, files[i].find(files[i], ".txt") - 1)
          
          file = file.gsub(file, "-", " ")

          self.unitMaterialPathsVariantMap_[file] = (rootFolder .. files[i])
          
          local scriptFile = file:gsub('%W','')
          require (rootScriptFolder .. scriptFile)
          
          dice = Node()
          dice = self.diceNode_:Clone(LOCAL)
          LevelScene_:AddChild(dice)
          table.insert(self.greyUnitNodeTable_, dice)
          
          dice:SetName(file)
          dice:GetChild("unit"):GetComponent("StaticModel"):ApplyMaterialList((rootFolder .. files[i]))
          dice:CreateScriptObject(scriptFile)
        end

      end

    end

  end

end

function mobileFantasy:PopulateUnitList(SourceTable)
  self.unitList_:RemoveAllItems()
  for i=1, table.maxn(SourceTable) do
    local text = ui:LoadLayout(cache:GetResource("XMLFile", "UI/text0.xml"))
    text:SetText(SourceTable[i]:GetName())
    self.unitList_:AddItem(text)
  end

end

function mobileFantasy:ToggleUnitList()
  if self.unitListSprite_:GetOpacity() == 0.0 then
    self.unitListSprite_:SetOpacity(1.0)
    self.unitList_:SetOpacity(0.5)
    self.unitSelectButt_:SetOpacity(1.0)
    self.unitListSprite_:SetDeepEnabled(true)
    self.unitList_:SetDeepEnabled(true)
    self.unitSelectButt_:SetDeepEnabled(true)
    self.dicePreviewNode_:SetDeepEnabled(true)
    self.unitList_:SetFocusMode(FM_FOCUSABLE_DEFOCUSABLE)
  else
    self.unitList_:RemoveAllItems()
    self.unitListSprite_:SetOpacity(0.0)
    self.unitList_:SetOpacity(0.0)
    self.unitSelectButt_:SetOpacity(0.0)
    self.unitListSprite_:SetDeepEnabled(false)
    self.unitList_:SetDeepEnabled(false)
    self.unitSelectButt_:SetDeepEnabled(false)
    self.dicePreviewNode_:SetDeepEnabled(false)
    self.unitList_:SetFocusMode(FM_NOTFOCUSABLE)
  end
  
end

function mobileFantasy:SelectUnit()
  self.selectedUnitIndex_ = self.unitList_:GetSelection()
  self:ToggleUnitList()

  if self.selectedUnitIndex_ == M_MAX_UNSIGNED then return end
  
  self.selectedUnitIndex_ = self.selectedUnitIndex_ + 1--fucking lua
  
  --[[if self.selectedUnitTable_ ~= self.greyUnitNodeTable_ then
    self.lookAtVector_ = self.selectedUnitTable_[self.selectedUnitIndex_]:GetWorldPosition()
  end--]]

  self:SubscribeToEvent("TouchBegin", "mobileFantasy:HandleTouchBegin")
  
end

function mobileFantasy:HandleTouchBegin(eventType, eventData)
  self.lookAtVector_ = Vector3(0.0, 0.0, 0.0)
  
  local x = eventData["X"]:GetInt()
  local y = eventData["Y"]:GetInt()

  local camera = self.cameraNode_:GetComponent("Camera")
  local cameraRay = camera:GetScreenRay(x / graphics.width, y / graphics.height)

  local result = LevelScene_:GetComponent("PhysicsWorld"):RaycastSingle(cameraRay, 1000.0, 128)

  if result.body ~= nil then
    --local hitNode = result.body:GetNode()

    if self.selectedUnitTable_ == self.greyUnitNodeTable_ then
      if self.canSpawn_ == false then
        self:UnsubscribeFromEvent("TouchBegin")
        return
      end
      
      local diff = (result.position - self.cameraNode_:GetWorldPosition())
      local dir = diff:Normalized() * diff:Length()
      dir.y = math.sqrt(diff:Length() + 4.0)

      self.greyUnitNodeTable_[self.selectedUnitIndex_]:SetPosition(self.cameraNode_:GetWorldPosition())
      self.greyUnitNodeTable_[self.selectedUnitIndex_]:SetDeepEnabled(true)

      self.greyUnitNodeTable_[self.selectedUnitIndex_]:GetComponent("RigidBody"):ApplyImpulse(dir)
      
      if self.turnPhase_ == self.TURNPHASE_LIGHT then
        local rootFolder = fileSystem:GetProgramDir() .. "Data/Models/mobileFantasyUnits/dice.txt"
        self.greyUnitNodeTable_[self.selectedUnitIndex_]:GetComponent("StaticModel"):ApplyMaterialList(rootFolder)
        
        self.greyUnitNodeTable_[self.selectedUnitIndex_]:SetVar(self.STRINGHASH_FACTION, Variant("light"))
        
        table.insert(self.lightUnitNodeTable_, self.greyUnitNodeTable_[self.selectedUnitIndex_])
        table.remove(self.greyUnitNodeTable_, self.selectedUnitIndex_)

      elseif self.turnPhase_ == self.TURNPHASE_DARK then
        local rootFolder = fileSystem:GetProgramDir() .. "Data/Models/mobileFantasyUnits/diceDark.txt"
        self.greyUnitNodeTable_[self.selectedUnitIndex_]:GetComponent("StaticModel"):ApplyMaterialList(rootFolder)
        
        self.greyUnitNodeTable_[self.selectedUnitIndex_]:SetVar(self.STRINGHASH_FACTION, Variant("dark"))
        
        table.insert(self.darkUnitNodeTable_, self.greyUnitNodeTable_[self.selectedUnitIndex_])
        table.remove(self.greyUnitNodeTable_, self.selectedUnitIndex_)
        
      end

    else
      if self.selectedUnitTable_ == self.darkUnitNodeTable_ and self.turnPhase_ == self.TURNPHASE_LIGHT then
        self:UnsubscribeFromEvent("TouchBegin")
        return
      end
      if self.selectedUnitTable_ == self.lightUnitNodeTable_ and self.turnPhase_ == self.TURNPHASE_DARK then
        self:UnsubscribeFromEvent("TouchBegin")
        return
      end
    
      local diff = (result.position - self.selectedUnitTable_[self.selectedUnitIndex_]:GetWorldPosition())
      local dir = diff:Normalized() * diff:Length()
      --dir.y = math.sqrt(diff:Length()) + Max(result.position.y, self.selectedUnitTable_[self.selectedUnitIndex_]:GetWorldPosition().y)
      dir.y = 8
      
      self.selectedUnitTable_[self.selectedUnitIndex_]:GetComponent("RigidBody"):ApplyImpulse(dir)

    end

    self:NextPhase()

  end

  self:UnsubscribeFromEvent("TouchBegin")
end

function mobileFantasy:NextPhase()  
  if self.turnPhase_ == self.TURNPHASE_LIGHT then
    self.turnPhase_ = self.TURNPHASE_DARK
    self.phaseText_:SetText("Dark Phase")
    self.phaseText_:SetColor(Color(0.5, 0.0, 0.5, 1.0))
    
  else
    self.turnPhase_ = self.TURNPHASE_LIGHT
    self.phaseText_:SetText("Light Phase")
    self.phaseText_:SetColor(Color(1.0, 1.0, 0.0, 1.0))
    
  end
  
end

function mobileFantasy:HandleSpawnZoneNodeCollisionStart(eventType, eventData)
  local otherNode = eventData["OtherNode"]:GetPtr("Node")

  if otherNode:GetName() == "camera" then
    self.canSpawn_ = true
  end

end

function mobileFantasy:HandleSpawnZoneNodeCollisionEnd(eventType, eventData)
  local otherNode = eventData["OtherNode"]:GetPtr("Node")

  if otherNode:GetName() == "camera" then
    self.canSpawn_ = false
  end

end

function mobileFantasy:HandleUnitCaptured(eventType, eventData)
  local node = eventData["Node"]:GetPtr("Node")
  
  local faction = node:GetVar(self.STRINGHASH_FACTION):GetString()
  
  if faction == "light" then
    local rootFolder = fileSystem:GetProgramDir() .. "Data/Models/mobileFantasyUnits/diceDark.txt"
    node:GetComponent("StaticModel"):ApplyMaterialList(rootFolder)

    node:SetVar(self.STRINGHASH_FACTION, Variant("dark"))

    table.insert(self.darkUnitNodeTable_, node)
    
    for i = 1, table.maxn(self.lightUnitNodeTable_), 1 do
      if self.lightUnitNodeTable_[i] == node then
        table.remove(self.lightUnitNodeTable_, i)
        break
        
      end
      
    end
    
    if table.maxn(self.lightUnitNodeTable_) == 0 then
      self.resetButt_:SetOpacity(1.0)
      self.resetButt_:SetDeepEnabled(true)
      
      if self.unitListSprite_:GetOpacity() == 1.0 then
        self:ToggleUnitList()
      end
      
      return
    end
    
  else
    local rootFolder = fileSystem:GetProgramDir() .. "Data/Models/mobileFantasyUnits/dice.txt"
    node:GetComponent("StaticModel"):ApplyMaterialList(rootFolder)

    node:SetVar(self.STRINGHASH_FACTION, Variant("light"))

    table.insert(self.lightUnitNodeTable_, node)
    
    for i = 1, table.maxn(self.darkUnitNodeTable_), 1 do
      if self.darkUnitNodeTable_[i] == node then
        table.remove(self.darkUnitNodeTable_, i)
        break
        
      end
      
    end
    
    if table.maxn(self.darkUnitNodeTable_) == 0 then
      self.resetButt_:SetOpacity(1.0)
      self.resetButt_:SetDeepEnabled(true)
      
      if self.unitListSprite_:GetOpacity() == 1.0 then
        self:ToggleUnitList()
      end
      
      return
      
    end
    
  end
  
  self:PopulateUnitList(self.selectedUnitTable_)
end

function mobileFantasy:ResetUnits()
  self.resetButt_:SetOpacity(0.0)
  self.resetButt_:SetDeepEnabled(false)
  
  for i = 1, table.maxn(self.darkUnitNodeTable_), 1 do
      table.insert(self.greyUnitNodeTable_, self.darkUnitNodeTable_[i])

  end

  self.darkUnitNodeTable_ = {}

  for i = 1, table.maxn(self.lightUnitNodeTable_), 1 do
      table.insert(self.greyUnitNodeTable_, self.lightUnitNodeTable_[i])

  end

  self.lightUnitNodeTable_ = {}

  for i = 1, table.maxn(self.greyUnitNodeTable_), 1 do
    self.greyUnitNodeTable_[i]:GetComponent("RigidBody"):ResetForces()
    self.greyUnitNodeTable_[i]:GetComponent("RigidBody"):SetLinearVelocity(Vector3(0.0, 0.0, 0.0))
    self.greyUnitNodeTable_[i]:GetComponent("RigidBody"):SetAngularVelocity(Vector3(0.0, 0.0, 0.0))
    --[[
    local sideCollision = self.greyUnitNodeTable_[i]:GetChild("sideCollision")

    for i = 0, sideCollision:GetNumChildren() - 1, 1 do
      sideCollision:GetChild(i):GetComponent("RigidBody"):ResetForces()
      sideCollision:GetChild(i):GetComponent("RigidBody"):SetLinearVelocity(Vector3(0.0, 0.0, 0.0))
      sideCollision:GetChild(i):GetComponent("RigidBody"):SetAngularVelocity(Vector3(0.0, 0.0, 0.0))
    end
--]]
    self.greyUnitNodeTable_[i]:SetDeepEnabled(false)

  end

end

function mobileFantasy:HandleWallNodeCollisionStart(eventType, eventData)
  local otherNode = eventData["OtherNode"]:GetPtr("Node")
  
  if otherNode:HasComponent("SoundSource3D") == false then return end
  
  local soundSource3d = otherNode:GetComponent("SoundSource3D")
  
  soundSource3d:Play(soundSource3d:GetSound())
  
end
