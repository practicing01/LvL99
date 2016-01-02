FoinSpider = ScriptObject()

function FoinSpider:Start()
  self.MOVE_FORCE = 2.0
  self.BRAKE_FORCE = 0.025
  self.rotDummy_ = nil
  self.rayDistance_ = 25.0
  self.gravityForce_ = Vector3(-9.81, -9.81, -9.81)
  self.slerpDest_ = Quaternion()
  self.slerpInterval_ = 0.1
  self.slerpProgress_ = 0.0

  self.STATE_STAND = 0
  self.STATE_IDLE = 1
  self.STATE_FOLLOW = 2
  self.STATE_SPIT = 3
  self.currentState_ = 0

  self.targetNode_ = nil
  self.pathEndPos_ = nil
  self.currentPath_ = nil
  self.nearestExtents_ = 10.0
end

function FoinSpider:DelayedStart()
  local body  = self.node:GetComponent("RigidBody")
  body.collisionEventMode = COLLISION_ALWAYS

  body:SetFriction(0.0)

  self.rotDummy_ = self.node:GetChild("rotDummy")

  self:SetState(self.STATE_STAND)

  --[[local agent = self.node:GetComponent("CrowdAgent")
  agent.height = 2.0
  agent.maxSpeed = 3.0
  agent.maxAccel = 3.0--]]

  local nodePos = self.node:GetWorldPosition()
  local aimPoint = self.rotDummy_:GetWorldPosition()
  local rayDir = (aimPoint - nodePos):Normalized()
  rayDir = rayDir * Vector3(-1.0, -1.0, -1.0)
  local octree = LevelScene_:GetComponent("Octree")
  local result = octree:RaycastSingle(Ray(aimPoint, Vector3.DOWN), RAY_TRIANGLE, 10000.0, DRAWABLE_GEOMETRY)
  local navMesh = LevelScene_:GetComponent("NavigationMesh")
  if result.drawable ~= nil then
    local pathPos = navMesh:FindNearestPoint(result.position, Vector3.ONE * self.nearestExtents)
    self.node:SetPosition(pathPos)
  else
    print("drawable nil")
  end
  
  local crowdManager = LevelScene_:GetComponent("CrowdManager")
  local allAgents = crowdManager:GetAgents()
    
  --[[print("allAgents " .. table.maxn(allAgents))

  for i, v in ipairs(allAgents) do
    print(v:GetName())
  end--]]

  --self:SubscribeToEvent("Update", "FoinSpider:HandleUpdate")
  --self:SubscribeToEvent(self.node, "NodeCollision", "FoinSpider:HandleNodeCollision")
  self:SubscribeToEvent(self.node:GetChild("playerTrigger"), "NodeCollisionStart", "FoinSpider:HandleNodeCollisionStart")
  self:SubscribeToEvent(self.node:GetChild("playerTrigger"), "NodeCollisionEnd", "FoinSpider:HandleNodeCollisionStart")
  self:SubscribeToEvent("PostRenderUpdate", "FoinSpider:HandlePostRenderUpdate")
  self:SubscribeToEvent("CrowdAgentFailure", "FoinSpider:HandleCrowdAgentFailure")
  self:SubscribeToEvent("CrowdAgentReposition", "FoinSpider:HandleCrowdAgentReposition")
  self:SubscribeToEvent("CrowdAgentFormation", "FoinSpider:HandleCrowdAgentFormation")
end

function FoinSpider:Stop()
  --
end

function FoinSpider:HandleUpdate(eventType, eventData)
  local timeStep = eventData["TimeStep"]:GetFloat()
end

function FoinSpider:FixedUpdate(timeStep)
  if 1 == 1 then return end
  if self.rotDummy_ == nil then return end

  local body  = self.node:GetComponent("RigidBody")

  local nodePos = self.node:GetWorldPosition()
  local aimPoint = self.rotDummy_:GetWorldPosition()
  local rayDir = (aimPoint - nodePos):Normalized()
  rayDir = rayDir * Vector3(-1.0, -1.0, -1.0)

  local result = LevelScene_:GetComponent("PhysicsWorld"):RaycastSingle(Ray(aimPoint, rayDir), self.rayDistance_, 2)

  if result.body ~= nil then
    local invertedNormal = result.normal * self.gravityForce_
    --body:SetGravityOverride(invertedNormal)
    body:SetGravityOverride(Vector3(0.0, -9.81, 0.0))
    local quat = Quaternion()
    quat:FromLookRotation(self.node:GetDirection(), result.normal)

    --body:SetRotation(quat)
--[[
    if quat ~= self.slerpDest_ then
      self.slerpDest_ = quat
      self.slerpProgress_ = 0.0
    end

    local rot = body:GetRotation()

    if self.slerpProgress_ < 1.0 then
      rot = rot:Slerp(self.slerpDest_, self.slerpProgress_)
      body:SetRotation(rot)

      --self.slerpProgress_ = self.slerpProgress_ + (self.slerpInterval_ * timeStep)
      self.slerpProgress_ = self.slerpProgress_ + (self.slerpInterval_)
      self.slerpProgress_ = Clamp(self.slerpProgress_, 0.0, 1.0)
    elseif rot ~= self.slerpDest_ then
      body:SetRotation(self.slerpDest_)
    end--]]

  end

self:FollowPath(timeStep)
end

function FoinSpider:HandleNodeCollision(eventType, eventData)
  --
end

function FoinSpider:HandleNodeCollisionStart(eventType, eventData)
  local trigger = eventData["Trigger"]:GetBool()
  local otherNode = eventData["OtherNode"]:GetPtr("Node")

  if trigger == true then
    self.targetNode_ = otherNode
    self:SetState(self.STATE_FOLLOW)
  end

end

function FoinSpider:SetState(state)
  self.currentState_ = state

  if state == self.STATE_STAND then
    self:StateStand()
  elseif state == self.STATE_FOLLOW then
    self:StateFollow()
  end

end

function FoinSpider:StateStand()
  local STAND_ANI = "Models/foinSpider/stand.ani"
  local animCtrl = self.node:GetComponent("AnimationController")

  local body = self.node:GetComponent("RigidBody")
  body:SetLinearVelocity(Vector3.ZERO)
  body:SetFriction(10.0)

  if animCtrl ~= nil then
    animCtrl:PlayExclusive(STAND_ANI, 0, true, 0.0)
    --[[if animCtrl:IsPlaying(STAND_ANI) then
      print("stand playing")
    else
      animCtrl:Play(STAND_ANI, 0, true, 0.1)
      print("setting stand")
    end--]]
end
end

function FoinSpider:StateFollow()
  local WALK_ANI = "Models/foinSpider/walk.ani"
  local animCtrl = self.node:GetComponent("AnimationController")
  local body = self.node:GetComponent("RigidBody")

  local navMesh = LevelScene_:GetComponent("NavigationMesh")
  local pathPos = navMesh:FindNearestPoint(self.targetNode_:GetWorldPosition(), Vector3.ONE * self.nearestExtents_)
  
  local crowdManager = LevelScene_:GetComponent("CrowdManager")
  LevelScene_:GetComponent("CrowdManager"):SetCrowdTarget(pathPos, self.node)
  local agent = self.node:GetComponent("CrowdAgent")
print("SetCrowdTarget " .. pathPos:ToString() .. " agent target " .. agent:GetTargetPosition():ToString())
 -- self.pathEndPos_ = pathPos
  --self.currentPath_ = navMesh:FindPath(self.node:GetPosition(), self.pathEndPos_)
  --self.currentPath_ = crowdManager:FindPath(self.node:GetPosition(), self.pathEndPos_, 16)

  if self.currentPath_ == nil then return end
  
  if table.maxn(self.currentPath_) == 0 then
    print("no path")
    --body:SetGravityOverride(Vector3(0.0, -9.81, 0.0))
  else
    body:SetFriction(0.0)

    if animCtrl ~= nil then
      animCtrl:PlayExclusive(WALK_ANI, 0, true, 0.0)
      animCtrl:SetSpeed(WALK_ANI, (body:GetLinearVelocity():Length()) / (self.MOVE_FORCE * 20.0))
      --[[if animCtrl:IsPlaying(WALK_ANI) then
        animCtrl:SetSpeed(WALK_ANI, (body:GetLinearVelocity():Length()) / (self.MOVE_FORCE * 5.0))
        else
        animCtrl:Play(WALK_ANI, 0, true, 0.1)
        animCtrl:SetSpeed(WALK_ANI, (body:GetLinearVelocity():Length()) / (self.MOVE_FORCE * 5.0))
      end--]]

    --[[local nextWaypoint = self.currentPath_[1]
    local nodePos = self.node:GetWorldPosition()
    local aimPoint = self.rotDummy_:GetWorldPosition()
    local rayDir = (aimPoint - nodePos):Normalized()
    --local rotbak = self.node:GetRotation()
    --self.node:LookAt(nextWaypoint, rayDir, TS_LOCAL)
    self.node:LookAt(nextWaypoint, Vector3.UP, TS_WORLD)
    --[[local rotdest = self.node:GetRotation()
    self.node:SetRotation(rotbak)
    body:SetRotation(rotdest)--]]
    --[[local quat = Quaternion()
    quat:FromLookRotation(self.node:GetDirection(), rayDir)
--]]
    body:SetRotation(quat)--]]
    end
  end
end

function FoinSpider:FollowPath(timeStep)
  if self.currentPath_ == nil then
    return
  end

  if table.maxn(self.currentPath_) > 0 then
    if self.currentState_ ~= self.STATE_FOLLOW then
      self:SetState(self.STATE_FOLLOW)
    end

    local nextWaypoint = self.currentPath_[1]

    local nodePos = self.node:GetWorldPosition()

    local body  = self.node:GetComponent("RigidBody")

    local velocity = body.linearVelocity
    local speed = velocity:Length()

    local speedRatio = speed / self.MOVE_FORCE
    --local rot = self.slerpDest_:Slerp(Quaternion(Vector3.FORWARD, velocity), self.MOVE_FORCE * timeStep * speedRatio)
    --local rot = self.slerpDest_:Slerp(Quaternion(Vector3.FORWARD, velocity), 1.0)

    --self.slerpDest_ = rot

    --todo should moveDir be normal dir + target dir?
    local moveDir = (nextWaypoint - nodePos):Normalized()
    body:ApplyImpulse(moveDir * self.MOVE_FORCE)
    --body:ApplyImpulse(rot * moveDir * self.MOVE_FORCE)
    --body:ApplyImpulse(rot:EulerAngles() * self.MOVE_FORCE)
    --body:ApplyImpulse(--[[rot *--]] moveDir * self.MOVE_FORCE * timeStep)

    local brakeForce = velocity * -self.BRAKE_FORCE
    body:ApplyImpulse(brakeForce)

    --todo combine slerp dest with target dir

    --local aimPoint = self.rotDummy_:GetWorldPosition()
    --local rayDir = (aimPoint - nodePos):Normalized()
    --local rotbak = self.node:GetRotation()
    --self.node:LookAt(nextWaypoint, rayDir, TS_LOCAL)
    --[[local rotdest = self.node:GetRotation()
    self.node:SetRotation(rotbak)
    --self.slerpDest_ = rotdest
    body:SetRotation(rotdest)--]]

    if (nextWaypoint - nodePos):Length() < 5.0 then
      table.remove(self.currentPath_, 1)

      if table.maxn(self.currentPath_) > 0 then
        local aimPoint = self.rotDummy_:GetWorldPosition()
        local rayDir = (aimPoint - nodePos):Normalized()
        --local rotbak = self.node:GetRotation()
        --self.node:LookAt(nextWaypoint, rayDir, TS_LOCAL)
        self.node:LookAt(nextWaypoint, Vector3.UP, TS_WORLD)
        --[[local rotdest = self.node:GetRotation()
        self.node:SetRotation(rotbak)
        body:SetRotation(rotdest)--]]
        --[[local quat = Quaternion()
        quat:FromLookRotation(self.node:GetDirection(), rayDir)

        body:SetRotation(quat)--]]
        print("set rot")
      end

    end
  elseif self.currentState_ ~= self.STATE_STAND then
    self:SetState(self.STATE_STAND)
  end
end

function FoinSpider:HandleCrowdAgentFailure(eventType, eventData)
  print("HandleCrowdAgentFailure")
  local node = eventData["Node"]:GetPtr("Node")
  local agentState = eventData["CrowdAgentState"]:GetInt()

  if agentState == CA_STATE_INVALID then
    local newPos = LevelScene_:GetComponent("NavigationMesh"):FindNearestPoint(node.position, self.nearestExtents_)
    node.position = newPos
  end
end

function FoinSpider:HandleCrowdAgentReposition(eventType, eventData)
  print("HandleCrowdAgentReposition")
  local WALK_ANI = "Models/foinSpider/walk.ani"

  local node = eventData["Node"]:GetPtr("Node")
  local agent = eventData["CrowdAgent"]:GetPtr("CrowdAgent")
  local velocity = eventData["Velocity"]:GetVector3()
  local timeStep = eventData["TimeStep"]:GetFloat()
  local animCtrl = node:GetComponent("AnimationController")
  local body = node:GetComponent("RigidBody")

  if animCtrl ~= nil then
    local speed = velocity:Length()
    if animCtrl:IsPlaying(WALK_ANI) then
      --local speedRatio = speed / agent.maxSpeed
      --local rot = body.GetRotation():Slerp(Quaternion(Vector3.FORWARD, velocity), self.MOVE_FORCE * timeStep * speedRatio)
      --body.SetRotation(rot)
      --animCtrl:SetSpeed(WALKING_ANI, speedRatio)
    else
      animCtrl:PlayExclusive(WALKING_ANI, 0, true, 0.0)
    end

    if speed < agent.radius then
      animCtrl:Stop(WALKING_ANI, 0.8)
      --todo set stand ani
    end
  end
end

function FoinSpider:HandleCrowdAgentFormation(eventType, eventData)
  print("HandleCrowdAgentFormation")
  local index = eventData["Index"]:GetUInt()
  local size = eventData["Size"]:GetUInt()
  local position = eventData["Position"]:GetVector3()

  if index > 0 then
    local crowdManager = GetEventSender()
    local agent = eventData["CrowdAgent"]:GetPtr("CrowdAgent")
    eventData["Position"] = crowdManager:GetRandomPointInCircle(position, agent.radius, agent.queryFilterType)
  end
end

function FoinSpider:HandlePostRenderUpdate(eventType, eventData)
  local debug = LevelScene_:GetComponent("DebugRenderer")
  --LevelScene_:GetComponent("PhysicsWorld"):DrawDebugGeometry(true)
  --LevelScene_:GetComponent("Octree"):DrawDebugGeometry(true)
  --renderer:DrawDebugGeometry(true)
  LevelScene_:GetComponent("CrowdManager"):DrawDebugGeometry(true)

  local nodePos = self.node:GetWorldPosition()
  local aimPoint = self.rotDummy_:GetWorldPosition()
  local rayDir = (aimPoint - nodePos):Normalized()
  rayDir = rayDir * Vector3(-1.0, -1.0, -1.0)

  debug:AddLine(aimPoint, aimPoint + (rayDir * self.rayDistance_), Color(1.0, 1.0, 1.0), false)
  debug:AddCross(aimPoint, 2.0 , Color(1.0, 1.0, 1.0), false)
  debug:AddCross(aimPoint + (rayDir * self.rayDistance_), 2.0, Color(1.0, 1.0, 1.0), false)

  local navMesh = LevelScene_:GetComponent("NavigationMesh")
  navMesh:DrawDebugGeometry(true)

  if self.currentPath_ == nil then
    return
  end

  local size = table.maxn(self.currentPath_)
  if size > 0 then
    debug:AddBoundingBox(BoundingBox(self.pathEndPos_ - Vector3(0.1, 0.1, 0.1), self.pathEndPos_ + Vector3(0.1, 0.1, 0.1)), Color(1.0, 1.0, 1.0))

    local bias = Vector3(0.0, 0.05, 0.0)
    debug:AddLine(nodePos + bias, self.currentPath_[1] + bias, Color(1.0, 1.0, 1.0))

    if size > 1 then
      for i = 1, size - 1 do
        debug:AddLine(self.currentPath_[i] + bias, self.currentPath_[i + 1] + bias, Color(1.0, 1.0, 1.0))
      end
    end
  end
end
