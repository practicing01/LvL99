GameMenu = ScriptObject()

function GameMenu:Start()  
  self.gameMenu_ = nil
  self.mainMenuButt_ = nil
  self.configButt_ = nil
  self.playButt_ = nil
  self.shopButt_ = nil
  self.playerList_ = nil
  self.fiendList_ = nil
  self.levelList_ = nil
  self.playerPreview_ = nil
  self.fiendPreview_ = nil
  self.levelPreview_ = nil
  self.playerPaths_ = {}
  self.fiendPaths_ = {}
  self.levelPaths_ = {}
end

function GameMenu:DelayedStart()
  local style = cache:GetResource("XMLFile", "UI/DefaultStyle.xml")
  ui.root.defaultStyle = style

  self.gameMenu_ = ui:LoadLayout(cache:GetResource("XMLFile", "UI/LvL99GameMenu.xml"))
  self.mainMenuButt_ = ui:LoadLayout(cache:GetResource("XMLFile", "UI/mainMenuButt.xml"))

  ui.root:AddChild(self.gameMenu_)
  ui.root:AddChild(self.mainMenuButt_)

  local vm = VariantMap()
  vm["Element"] = Variant(self.gameMenu_)
  SendEvent("AddGuiTargets", vm)

  vm["Element"] = Variant(self.mainMenuButt_)
  SendEvent("AddGuiTargets", vm)

  vm["Element"] = Variant(self.gameMenu_)
  SendEvent("Resized", vm)

  vm["Element"] = Variant(self.mainMenuButt_)
  SendEvent("Resized", vm)

  self.configButt_ = self.gameMenu_:GetChild("configButt", true)
  self.playButt_ = self.gameMenu_:GetChild("playButt", true)
  self.shopButt_ = self.gameMenu_:GetChild("shopButt", true)
  self.playerList_ = self.gameMenu_:GetChild("playerList", true)
  self.fiendList_ = self.gameMenu_:GetChild("fiendList", true)
  self.levelList_ = self.gameMenu_:GetChild("levelList", true)
  self.playerPreview_ = self.gameMenu_:GetChild("playerPreview", true)
  self.fiendPreview_ = self.gameMenu_:GetChild("fiendPreview", true)
  self.levelPreview_ = self.gameMenu_:GetChild("levelPreview", true)

  self.mainMenuButt_:SetEnabled(false)
  self.mainMenuButt_:SetVisible(false)

  self:SubscribeToEvent("GameMenuDisplay", "GameMenu:HandleGameMenuDisplay")
  self:SubscribeToEvent(self.mainMenuButt_, "Released", "GameMenu:HandleReleased")
  self:SubscribeToEvent(self.configButt_, "Released", "GameMenu:HandleReleased")
  self:SubscribeToEvent(self.playButt_, "Released", "GameMenu:HandleReleased")
  self:SubscribeToEvent(self.shopButt_, "Released", "GameMenu:HandleReleased")
  self:SubscribeToEvent(self.playerList_, "ItemSelected", "GameMenu:HandleItemSelected")
  self:SubscribeToEvent(self.fiendList_, "ItemSelected", "GameMenu:HandleItemSelected")
  self:SubscribeToEvent(self.levelList_, "ItemSelected", "GameMenu:HandleItemSelected")
  self:SubscribeToEvent(self.playerList_, "ItemDeselected", "GameMenu:HandleItemDeselected")
  self:SubscribeToEvent(self.fiendList_, "ItemDeselected", "GameMenu:HandleItemDeselected")
  self:SubscribeToEvent(self.levelList_, "ItemDeselected", "GameMenu:HandleItemDeselected")
  self:SubscribeToEvent("GetSelectedObjects", "GameMenu:HandleGetSelectedObjects")

  --todo LoadScene()
  self:PopulateLists()
end

function GameMenu:HandleGameMenuDisplay(eventType, eventData)
  local state = eventData["State"]:GetBool()

  if state == true then
    LevelScene_:RemoveAllChildren()
    LevelScene_:Remove()

    self.mainMenuButt_:SetEnabled(false)
    self.mainMenuButt_:SetVisible(false)

    self.gameMenu_:SetEnabled(true)
    self.gameMenu_:SetVisible(true)
    
    input:SetMouseVisible(true)

    --todo LoadScene()
    self:PopulateLists()
  else
    self.mainMenuButt_:SetEnabled(true)
    self.mainMenuButt_:SetVisible(true)

    self.gameMenu_:SetEnabled(false)
    self.gameMenu_:SetVisible(false)

    --todo UnloadScene()
  end

end

function GameMenu:HandleReleased(eventType, eventData)
  local butt = eventData["Element"]:GetPtr("UIElement")

  if butt == self.mainMenuButt_ then
    local vm = VariantMap()
    vm["State"] = Variant(true)
    SendEvent("GameMenuDisplay", vm)
  elseif butt == self.configButt_ then
    --print("config")
  elseif butt == self.playButt_ then
    if self.levelList_:GetSelection() == M_MAX_UNSIGNED then
      return
    end

    local vm = VariantMap()
    vm["State"] = Variant(false)
    SendEvent("GameMenuDisplay", vm)

    LevelScene_ = Scene()
    local file = cache:GetFile(self.levelPaths_[self.levelList_:GetSelection() + 1] .. "/Scene.xml")
    LevelScene_:LoadXML(file)
    file:delete()

    --[[cameraNode = LevelScene_:CreateChild("Camera")
    cameraNode:CreateComponent("Camera")
    cameraNode.position = Vector3(0.0, 2.0, -10.0)
    local viewport = Viewport:new(LevelScene_, cameraNode:GetComponent("Camera"))
    renderer:SetViewport(0, viewport)
    local fiendSpawn = LevelScene_:GetChild("Spawns"):GetChild("Fiend")
    cameraNode:LookAt(fiendSpawn:GetPosition())--]]
  elseif butt == self.shopButt_ then
    --print("shop")
  end

end

function GameMenu:HandleItemSelected(eventType, eventData)
  local list = eventData["Element"]:GetPtr("UIElement")
  local index = eventData["Selection"]:GetInt()

  list:GetItem(index):SetColor(Color(0.0, 0.5, 0.5, 1.0))

  local rootFolder = fileSystem:GetProgramDir() .. "Data/Textures/PreviewIcons/"

  if list == self.playerList_ then
    rootFolder = rootFolder .. "Players/" .. list:GetItem(index):GetText()
    self.playerPreview_:SetTexture(cache:GetResource("Texture2D", rootFolder .. "/icon.png"))
    self.playerPreview_:SetOpacity(1.0)
  elseif list == self.fiendList_ then
    rootFolder = rootFolder .. "Fiends/" .. list:GetItem(index):GetText()
    self.fiendPreview_:SetTexture(cache:GetResource("Texture2D", rootFolder .. "/icon.png"))
    self.fiendPreview_:SetOpacity(1.0)
  elseif list == self.levelList_ then
    rootFolder = rootFolder .. "Levels/" .. list:GetItem(index):GetText()
    self.levelPreview_:SetTexture(cache:GetResource("Texture2D", rootFolder .. "/icon.png"))
    self.levelPreview_:SetOpacity(1.0)
  end

end

function GameMenu:HandleItemDeselected(eventType, eventData)
  local list = eventData["Element"]:GetPtr("UIElement")
  local index = eventData["Selection"]:GetInt()

  list:GetItem(index):SetColor(Color(1.0, 1.0, 1.0, 1.0))
end

function GameMenu:PopulateLists()
  self.playerList_:RemoveAllItems()
  self.fiendList_:RemoveAllItems()
  self.levelList_:RemoveAllItems()
  self.playerPaths_ = {}
  self.fiendPaths_ = {}
  self.levelPaths_ = {}

  self.playerPreview_:SetTexture(nil)
  self.playerPreview_:SetOpacity(0.0)
  self.fiendPreview_:SetTexture(nil)
  self.fiendPreview_:SetOpacity(0.0)
  self.levelPreview_:SetTexture(nil)
  self.levelPreview_:SetOpacity(0.0)

  local rootFolder = fileSystem:GetProgramDir() .. "Data/Objects/Players/"

  --if fileSystem:DirExists(rootFolder) == true then
  if 1 == 1 then
    local files = fileSystem:ScanDir(rootFolder, "", SCAN_DIRS, false)

    if table.maxn(files) ~= 0 then
      for i=1, table.maxn(files) do
        if files[i] ~= "." and files[i] ~= ".." then
          local text = ui:LoadLayout(cache:GetResource("XMLFile", "UI/text.xml"))
          text:SetText(files[i])
          self.playerList_:AddItem(text)
          table.insert(self.playerPaths_, rootFolder .. files[i])
        end

      end

    end

  end

  rootFolder = fileSystem:GetProgramDir() .. "Data/Objects/Fiends/"

  --if fileSystem:DirExists(rootFolder) == true then
  if 1 == 1 then
    local files = fileSystem:ScanDir(rootFolder, "", SCAN_DIRS, false)

    if table.maxn(files) ~= 0 then
      for i=1, table.maxn(files) do
        if files[i] ~= "." and files[i] ~= ".." then
          local text = ui:LoadLayout(cache:GetResource("XMLFile", "UI/text.xml"))
          text:SetText(files[i])
          self.fiendList_:AddItem(text)
          table.insert(self.fiendPaths_, rootFolder .. files[i])
        end

      end

    end

  end

  rootFolder = fileSystem:GetProgramDir() .. "Data/Scenes/Levels/"

  --if fileSystem:DirExists(rootFolder) == true then
  if 1 == 1 then
    local files = fileSystem:ScanDir(rootFolder, "", SCAN_DIRS, false)
    
    if table.maxn(files) ~= 0 then
      for i=1, table.maxn(files) do
        if files[i] ~= "." and files[i] ~= ".." then
          local text = ui:LoadLayout(cache:GetResource("XMLFile", "UI/text.xml"))
          text:SetText(files[i])
          self.levelList_:AddItem(text)
          table.insert(self.levelPaths_, rootFolder .. files[i])
        end

      end

    end

end
  print(rootFolder)

end

function GameMenu:HandleGetSelectedObjects(eventType, eventData)
  local vm = VariantMap()
  
  if self.playerList_:GetSelection() ~= M_MAX_UNSIGNED then
    vm["Player"] = Variant(self.playerPaths_[self.playerList_:GetSelection() + 1])
  else
    vm["Player"] = Variant("")
  end
  
  if self.fiendList_:GetSelection() ~= M_MAX_UNSIGNED then
    vm["Fiend"] = Variant(self.fiendPaths_[self.fiendList_:GetSelection() + 1])
  else
    vm["Fiend"] = Variant("")
  end
  
  if self.levelList_:GetSelection() ~= M_MAX_UNSIGNED then
    vm["Level"] = Variant(self.levelPaths_[self.levelList_:GetSelection() + 1])
  else
    vm["Level"] = Variant("")
  end
  
  SendEvent("SetSelectedObjects", vm)
end
