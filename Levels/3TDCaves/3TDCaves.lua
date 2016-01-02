Caves3TD = ScriptObject()

function Caves3TD:Start()
  self.player_ = nil
  self.fiend_ = nil
end

function Caves3TD:DelayedStart()
  self:SubscribeToEvent("SetSelectedObjects", "Caves3TD:HandleSetSelectedObjects")
  local vm = VariantMap()
  SendEvent("GetSelectedObjects", vm)
  
  --local navMesh = LevelScene_:GetComponent("NavigationMesh")
  
  --[[navMesh.agentHeight = 10
  navMesh.cellHeight = 0.05
  navMesh.padding = Vector3(0.0, 10.0, 0.0)--]]
  
  --[[local crowdManager = LevelScene_:GetComponent("CrowdManager")
  local params = crowdManager:GetObstacleAvoidanceParams(0)
  params.velBias = 0.5
  params.adaptiveDivs = 7
  params.adaptiveRings = 3
  params.adaptiveDepth = 3
  crowdManager:SetObstacleAvoidanceParams(0, params)--]]
  
  --[[navMesh:Build()
  
  local crowdManager = LevelScene_:GetComponent("CrowdManager")
  crowdManager:SetNavigationMesh(navMesh)--]]
  
  local waypoints = self.node:GetScene():GetChild("waypoints")
  
  for x = 0, waypoints:GetNumChildren() - 1 do
    self:SubscribeToEvent(waypoints:GetChild(x), "NodeCollisionStart", "Caves3TD:HandleNodeCollisionStart")
  end
end

function Caves3TD:Stop()
  --
end

function Caves3TD:HandleSetSelectedObjects(eventType, eventData)
  local player = eventData["Player"]:GetString()
  local fiend = eventData["Fiend"]:GetString()
  local level = eventData["Level"]:GetString()
    
  if player ~= "" then
    local playerSpawn = self.node:GetScene():GetChild("Spawns"):GetChild("Player")
    
    local file = cache:GetFile(player .. "/Node.xml")
    self.player_ = self.node:GetScene():InstantiateXML(file, playerSpawn:GetWorldPosition(), playerSpawn:GetWorldRotation(), LOCAL)
    
    if self.player_:HasComponent("RigidBody") then
      self.player_:GetComponent("RigidBody"):SetPosition(playerSpawn:GetWorldPosition())
      self.player_:GetComponent("RigidBody"):SetRotation(playerSpawn:GetWorldRotation())
    end
    
    file:delete()
    self.player_:SetName("Player")
    
    file = cache:GetFile("Objects/3TDCaveLight.xml")
    local light = self.node:GetScene():InstantiateXML(file, Vector3(), Quaternion(), LOCAL)
    file:delete()
    self.player_:GetChild("camera"):AddChild(light)
  end
  
  if fiend ~= "" then
    local fiendSpawn = self.node:GetScene():GetChild("Spawns"):GetChild("Fiend")
    
    local file = cache:GetFile(fiend .. "/Node.xml")
    self.fiend_ = self.node:GetScene():InstantiateXML(file, fiendSpawn:GetWorldPosition(), fiendSpawn:GetWorldRotation(), LOCAL)
    
    if self.fiend_:HasComponent("RigidBody") then
      self.fiend_:GetComponent("RigidBody"):SetPosition(fiendSpawn:GetWorldPosition())
      self.fiend_:GetComponent("RigidBody"):SetRotation(fiendSpawn:GetWorldRotation())
    end
    
    file:delete()
    self.fiend_:SetName("Fiend")
  end
end

function Caves3TD:HandleNodeCollisionStart(eventType, eventData)
  local body = eventData["Body"]:GetPtr("RigidBody")
  local trigger = eventData["Trigger"]:GetBool()
  local otherNode = eventData["OtherNode"]:GetPtr("Node")

  if trigger == true then
    local vm = VariantMap()
    vm["Waypoint"] = Variant(body:GetNode())
    SendEvent("WaypointTrigger", vm)
  end

end
