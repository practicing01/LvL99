require "LuaScripts/Fiends/FoinSpider/Snare"
require "LuaScripts/Health"

FoinSpider = ScriptObject()

function FoinSpider:Start()
  self.MOVE_FORCE = 1.0
  self.BRAKE_FORCE = 0.025
  self.rotDummy_ = nil
  self.rayDistance_ = 30.0
  self.gravityForce_ = Vector3(-9.81, -9.81, -9.81)
  self.slerpDest_ = Quaternion()
  self.slerpInterval_ = 0.1
  self.slerpProgress_ = 0.0
  self.footStepInterval_ = self.MOVE_FORCE * 0.01
  self.footStepElapsedTime_ = 0.0
  self.footStepGain_ = 0.75

  self.ANI_STAND = "Models/foinSpider/stand.ani"
  self.ANI_IDLE = "Models/foinSpider/idle.ani"
  self.ANI_WALK = "Models/foinSpider/walk.ani"
  self.ANI_SPIT = "Models/foinSpider/spit.ani"
  self.ANI_ATTACK = "Models/foinSpider/attack.ani"
  self.ANI_HURT = "Models/foinSpider/hit0.ani"
  self.ANI_DIE = "Models/foinSpider/death.ani"
  
  self.SFX_STAND = nil
  self.SFX_IDLE = nil
  self.SFX_WALK = nil
  self.SFX_SPIT = nil
  self.SFX_ATTACK = nil
  self.SFX_HURT = nil
  self.SFX_DIE = nil

  self.STATE_STAND = 0
  self.STATE_IDLE = 1
  self.STATE_FOLLOW = 2
  self.STATE_SPIT = 3
  self.STATE_ATTACK = 4
  self.STATE_SHOOT = 5
  self.STATE_HURT = 6
  self.STATE_DIE = 7
  self.currentState_ = 0

  self.animController_ = nil
  self.soundSource3D_ = nil
  self.targetNode_ = nil
  self.body_ = nil
  self.playerTarget_ = nil

  self.spitNode_ = nil
  self.spitOrigin_ = nil
  self.spitCooldown_ = 4.0
  self.spitCooling_ = false
  self.spitCDElapsedTime_ = 0.0
  self.spitImpulse_ = 100.0
  self.snareDuration_ = 5.0
  self.snareMagnitude_ = 1.0
  
  self.attackImpulseRadius_ = 50.0
  self.attackImpulseMagnitude_ = 100.0
  
  self.shootCooldown_ = 2.0
  self.shootCooling_ = false
  self.shootCDElapsedTime_ = 0.0
  self.shootOrigin_ = nil
  
  self.playerCollider_ = nil
end

function FoinSpider:DelayedStart()
  local file = cache:GetFile("Objects/Fiends/FoinSpider/spit.xml")
  self.spitNode_ = self.node:GetScene():InstantiateXML(file, Vector3.ZERO, Quaternion.IDENTITY, LOCAL)
  file:delete()
  self.spitNode_:SetEnabled(false)
  
  self.shootOrigin_ = self.node:GetChild("shootOrigin", true)
  self.shootOrigin_:SetEnabled(false)

  self.rotDummy_ = self.node:GetChild("rotDummy")
  self.spitOrigin_ = self.node:GetChild("spitOrigin")
  self.body_ = self.node:GetComponent("RigidBody")
  self.animController_ = self.node:GetChild("model"):GetComponent("AnimationController")
  self.soundSource3D_ = self.node:GetComponent("SoundSource3D")

  self.playerCollider_ = self.node:GetChild("playerCollider")
  self.playerCollider_:CreateScriptObject("Health")

  --self.SFX_STAND = cache:GetResource("Sound", "Sounds/foinSpider/stand.ogg")
  --self.SFX_IDLE = cache:GetResource("Sound", "Sounds/foinSpider/idle.ogg")
  self.SFX_WALK = cache:GetResource("Sound", "Sounds/foinSpider/walk.ogg")
  self.SFX_SPIT = cache:GetResource("Sound", "Sounds/foinSpider/spit.ogg")
  self.SFX_ATTACK = cache:GetResource("Sound", "Sounds/foinSpider/attack.ogg")
  self.SFX_HURT = cache:GetResource("Sound", "Sounds/foinSpider/hurt.ogg")
  self.SFX_DIE = cache:GetResource("Sound", "Sounds/foinSpider/die.ogg")
  
  self:SetState(self.STATE_STAND)
  
  --self:SubscribeToEvent("PostRenderUpdate", "FoinSpider:HandlePostRenderUpdate")

  self:SubscribeToEvent("WaypointTrigger", "FoinSpider:HandleWaypointTrigger")
  
  self:SubscribeToEvent(self.node:GetChild("playerTrigger"), "NodeCollisionStart", "FoinSpider:HandleNodeCollisionStart")
  self:SubscribeToEvent(self.node:GetChild("playerTrigger"), "NodeCollisionEnd", "FoinSpider:HandleNodeCollisionEnd")--]]
  
  self:SubscribeToEvent(self.node:GetChild("spitTrigger"), "NodeCollisionStart", "FoinSpider:HandleSpitNodeCollisionStart")
  self:SubscribeToEvent("AnimationFinished", "FoinSpider:HandleAnimationFinished")
  
  self:SubscribeToEvent(self.playerCollider_, "NodeCollisionStart", "FoinSpider:HandleAttackNodeCollisionStart")
  
  self:SubscribeToEvent(self.playerCollider_, "HealthOperation", "FoinSpider:HandleHealthOperation")
end

function FoinSpider:Stop()
  --
end

function FoinSpider:Update(timeStep)
  if self.spitCooling_ == true then
    self.spitCDElapsedTime_ = self.spitCDElapsedTime_ + timeStep
    if self.spitCDElapsedTime_ >= self.spitCooldown_ then
      self.spitCooling_ = false
    end
    
  end
  
  if self.shootCooling_ == true then
    self.shootCDElapsedTime_ = self.shootCDElapsedTime_ + timeStep
    if self.shootCDElapsedTime_ >= self.shootCooldown_ then
      self.shootCooling_ = false
    end
    
  end
  
end

function FoinSpider:FixedUpdate(timeStep)
  self:FollowPath(timeStep)

  if self.rotDummy_ == nil then return end

  local nodePos = self.node:GetWorldPosition()
  local aimPoint = self.rotDummy_:GetWorldPosition()
  local rayDir = (aimPoint - nodePos):Normalized()
  rayDir = rayDir * Vector3(-1.0, -1.0, -1.0)

  local result = LevelScene_:GetComponent("PhysicsWorld"):RaycastSingle(Ray(aimPoint, rayDir), self.rayDistance_, 2)

  if result.body ~= nil then
    local invertedNormal = result.normal * self.gravityForce_
    self.body_:SetGravityOverride(invertedNormal)
    local quat = Quaternion()
    quat:FromLookRotation(self.node:GetDirection(), result.normal)
    
    self.node:SetRotation(quat)

    --todo learn how to slerp
    
    --[[if quat ~= self.slerpDest_ then
      self.slerpDest_ = quat
      self.slerpProgress_ = 0.0
    end

    local rot = self.node:GetRotation()

    if self.slerpProgress_ < 1.0 then
      rot = rot:Slerp(self.slerpDest_, self.slerpProgress_)
      self.node:SetRotation(rot)

      self.slerpProgress_ = self.slerpProgress_ + (self.slerpInterval_ * timeStep)
      --self.slerpProgress_ = self.slerpProgress_ + (self.slerpInterval_)
      self.slerpProgress_ = Clamp(self.slerpProgress_, 0.0, 1.0)
    elseif rot ~= self.slerpDest_ then
      self.node:SetRotation(self.slerpDest_)
    end--]]

end

end

function FoinSpider:HandleNodeCollision(eventType, eventData)
  --
end

function FoinSpider:HandleNodeCollisionStart(eventType, eventData)
  local trigger = eventData["Trigger"]:GetBool()
  local otherNode = eventData["OtherNode"]:GetPtr("Node")

  if trigger == true then
    self.playerTarget_ = otherNode
    self:SetState(self.STATE_FOLLOW)
  end

end

function FoinSpider:HandleNodeCollisionEnd(eventType, eventData)
  local trigger = eventData["Trigger"]:GetBool()
  local otherNode = eventData["OtherNode"]:GetPtr("Node")

  if trigger == true then
    self.playerTarget_ = nil
    self:SetState(self.STATE_STAND)
  end

end

function FoinSpider:HandleSpitNodeCollisionStart(eventType, eventData)
  local trigger = eventData["Trigger"]:GetBool()
  local otherNode = eventData["OtherNode"]:GetPtr("Node")

  if trigger == true then
    self:SetState(self.STATE_SPIT)
  end

end

function FoinSpider:HandleAttackNodeCollisionStart(eventType, eventData)
  local otherNode = eventData["OtherNode"]:GetPtr("Node")
  local otherBody = eventData["OtherBody"]:GetPtr("RigidBody")
  
  if otherBody:GetCollisionLayer() ~= 128 then return end
  
  self:SetState(self.STATE_ATTACK)

end

function FoinSpider:HandleSpitCollisionStart(eventType, eventData)
  local otherNode = eventData["OtherNode"]:GetPtr("Node")
  local body = eventData["Body"]:GetPtr("RigidBody")
  local node = body:GetNode()
  
  local snareSO = otherNode:CreateScriptObject("Snare")
  snareSO:Snare(self.snareMagnitude_, self.snareDuration_)

  node:Remove()
end

function FoinSpider:SetState(state)
  if self.currentState_ == self.STATE_DIE then return end
  
  self.currentState_ = state
  self.shootOrigin_:SetEnabled(false)

  if state == self.STATE_STAND then
    self:StateStand()
  elseif state == self.STATE_IDLE then
    self:StateIdle()
  elseif state == self.STATE_FOLLOW then
    self:StateFollow()
  elseif state == self.STATE_SPIT then
    self:StateSpit()
  elseif state == self.STATE_ATTACK then
    self:StateAttack()
  elseif state == self.STATE_SHOOT then
    self:StateShoot()
  elseif state == self.STATE_HURT then
    self:StateHurt()
  elseif state == self.STATE_DIE then
    self:StateDie()
  end

end

function FoinSpider:StateStand()
  self.body_:SetLinearVelocity(Vector3.ZERO)
  self.body_:SetFriction(10.0)

  if self.animController_ ~= nil then
    self.animController_:StopAll(0.0)
    self.animController_:PlayExclusive(self.ANI_STAND, 0, true, 0.0)
  end
  
  self.soundSource3D_:Stop()
end

function FoinSpider:StateIdle()
  self.body_:SetLinearVelocity(Vector3.ZERO)
  self.body_:SetFriction(10.0)

  if self.animController_ ~= nil then
    self.animController_:StopAll(0.0)
    self.animController_:PlayExclusive(self.ANI_IDLE, 0, false, 0.0)
  end
  
  self.soundSource3D_:Stop()
end

function FoinSpider:StateFollow()
  self.body_:SetFriction(0.0)

  if self.animController_ ~= nil then
    self.animController_:StopAll(0.0)
    self.animController_:PlayExclusive(self.ANI_WALK, 0, true, 0.0)
  end
  
  self.soundSource3D_:Play(self.SFX_WALK)
  self.soundSource3D_:SetGain(self.footStepGain_)
end

function FoinSpider:FollowPath(timeStep)
  if self.currentState_ ~= self.STATE_FOLLOW then
    return
  end
  
  if self.playerTarget_ == nil then
    self:SetState(self.STATE_STAND)
    return
  end
  
  local nodePos = self.rotDummy_:GetWorldPosition()
  local targetPos = self.targetNode_:GetWorldPosition()

  if (targetPos - nodePos):Length() > 20.0 then
    if self.playerTarget_ == nil then
      self.node:LookAt(targetPos)
    else
      self.node:LookAt(self.playerTarget_:GetWorldPosition())
    end
  else
    if self.shootCooling_ == false then
      self:SetState(self.STATE_SHOOT)
    end
    return
  end
  
  local velocity = self.body_.linearVelocity
  --local speed = velocity:Length()

  --local speedRatio = speed / self.MOVE_FORCE

  self.body_:ApplyImpulse((targetPos - nodePos):Normalized() * self.MOVE_FORCE)

  local brakeForce = velocity * -self.BRAKE_FORCE
  self.body_:ApplyImpulse(brakeForce)
  
  local length = self.body_:GetLinearVelocity():Length()
  
  self.animController_:SetSpeed(self.ANI_WALK, length * 0.05)
  
  self.footStepElapsedTime_ = self.footStepElapsedTime_ + timeStep
  
  if self.footStepElapsedTime_ >= self.footStepInterval_ * length then
    self.footStepElapsedTime_ = 0.0
    self.soundSource3D_:Play(self.SFX_WALK)
    self.soundSource3D_:SetGain(self.footStepGain_)
  end
  
end

function FoinSpider:StateSpit()
  if self.spitCooling_ == true then return end
  
  self.spitCooling_ = true
  self.spitCDElapsedTime_ = 0.0
  
  self.body_:SetLinearVelocity(Vector3.ZERO)
  self.body_:SetFriction(10.0)
  if self.animController_ ~= nil then
    self.animController_:StopAll(0.0)
    self.animController_:PlayExclusive(self.ANI_SPIT, 0, false, 0.0)
  end
  
  self.soundSource3D_:Play(self.SFX_SPIT)
  
  local spitClone = self.spitNode_:Clone(LOCAL)
  spitClone:SetEnabled(true)
  spitClone:SetPosition(self.spitOrigin_:GetWorldPosition())
    
  self:SubscribeToEvent(spitClone, "NodeCollisionStart", "FoinSpider:HandleSpitCollisionStart")
  
  spitClone:GetComponent("RigidBody"):ApplyImpulse(self.spitOrigin_:GetWorldDirection() * self.spitImpulse_)
end

function FoinSpider:StateAttack()
  self.body_:SetLinearVelocity(Vector3.ZERO)
  self.body_:SetFriction(10.0)
  if self.animController_ ~= nil then
    self.animController_:StopAll(0.0)
    self.animController_:PlayExclusive(self.ANI_ATTACK, 0, false, 0.0)
  end
  
  self.soundSource3D_:Play(self.SFX_ATTACK)
  self:AttackImpulse()
end

function FoinSpider:StateHurt()
  self.body_:SetLinearVelocity(Vector3.ZERO)
  self.body_:SetFriction(10.0)

  if self.animController_ ~= nil then
    self.animController_:StopAll(0.0)
    self.animController_:PlayExclusive(self.ANI_HURT, 0, false, 0.0)
  end
  
  self.soundSource3D_:Play(self.SFX_HURT)
end

function FoinSpider:StateDie()
  self.body_:SetLinearVelocity(Vector3.ZERO)
  self.body_:SetFriction(10.0)

  if self.animController_ ~= nil then
    self.animController_:StopAll(0.0)
    self.animController_:PlayExclusive(self.ANI_DIE, 0, false, 0.0)
  end
  
  self.soundSource3D_:Play(self.SFX_DIE)
end

function FoinSpider:HandlePostRenderUpdate(eventType, eventData)
  local debug = LevelScene_:GetComponent("DebugRenderer")
  LevelScene_:GetComponent("PhysicsWorld"):DrawDebugGeometry(true)
  --LevelScene_:GetComponent("Octree"):DrawDebugGeometry(true)
  renderer:DrawDebugGeometry(true)

  local nodePos = self.node:GetWorldPosition()
  local aimPoint = self.rotDummy_:GetWorldPosition()
  local rayDir = (aimPoint - nodePos):Normalized()
  rayDir = rayDir * Vector3(-1.0, -1.0, -1.0)

  --debug:AddLine(aimPoint, aimPoint + (rayDir * self.rayDistance_), Color(1.0, 1.0, 1.0), false)
  debug:AddCross(aimPoint, 2.0 , Color(1.0, 1.0, 1.0), false)
  debug:AddCross(aimPoint + (rayDir * self.rayDistance_), 2.0, Color(1.0, 1.0, 1.0), false)
  
  debug:AddLine(nodePos, nodePos + (self.node:GetDirection() * self.rayDistance_), Color(1.0, 1.0, 1.0), false)
  debug:AddLine(aimPoint, aimPoint + (self.node:GetDirection() * self.rayDistance_), Color(1.0, 1.0, 1.0), false)
end

function FoinSpider:HandleWaypointTrigger(eventType, eventData)
  local waypoint = eventData["Waypoint"]:GetPtr("Node")
  
  self.targetNode_ = waypoint
  self:SetState(self.STATE_FOLLOW)
end

function FoinSpider:HandleAnimationFinished(eventType, eventData)
  local node = eventData["Node"]:GetPtr("Node")
  local ani = eventData["Animation"]:GetPtr("Animation")
  local name = eventData["Name"]:GetString()
  local looped = eventData["Looped"]:GetBool()
  
  if self.currentState_ == self.STATE_SPIT then
    if self.animController_:IsAtEnd(self.ANI_SPIT) then
      self:SetState(self.STATE_FOLLOW)
      return
    end
  end
  
  if self.currentState_ == self.STATE_ATTACK then
    if self.animController_:IsAtEnd(self.ANI_ATTACK) then
      self:SetState(self.STATE_FOLLOW)
      return
    end
  end
  
  if self.currentState_ == self.STATE_IDLE then
    if self.animController_:IsAtEnd(self.ANI_IDLE) then
      self:SetState(self.STATE_FOLLOW)
      return
    end
  end
  
  if self.currentState_ == self.STATE_SHOOT then
    if self.animController_:IsAtEnd(self.ANI_ATTACK) then
      self.shootOrigin_:SetEnabled(false)
      self:SetState(self.STATE_IDLE)
      return
    end
  end
  
  if self.currentState_ == self.STATE_HURT then
    if self.animController_:IsAtEnd(self.ANI_HURT) then
      self:SetState(self.STATE_IDLE)
      return
    end
  end
end

function FoinSpider:AttackImpulse()
  local bodies = LevelScene_:GetComponent("PhysicsWorld"):GetRigidBodies(Sphere(self.node:GetPosition(), self.attackImpulseRadius_), 128)
  
  local impulse = self.node:GetDirection() * self.attackImpulseMagnitude_
  
  for i, v in ipairs(bodies) do
    v:ApplyImpulse(impulse)
  end
  
end

function FoinSpider:StateShoot()
  self.body_:SetLinearVelocity(Vector3.ZERO)
  self.body_:SetFriction(10.0)

  if self.animController_ ~= nil then
    self.animController_:StopAll(0.0)
    self.animController_:PlayExclusive(self.ANI_ATTACK, 0, false, 0.0)
  end

  self.soundSource3D_:Play(self.SFX_ATTACK)
  
  self.shootOrigin_:SetEnabled(true)
  
  self.shootCooling_ = true
  self.shootCDElapsedTime_ = 0.0
  
  local aimPoint = self.rotDummy_:GetWorldPosition()
  local rayDir = self.rotDummy_:GetWorldDirection()

  local result = LevelScene_:GetComponent("PhysicsWorld"):SphereCast(Ray(aimPoint, rayDir), 50.0, self.rayDistance_, 128)

  if result.body ~= nil then
    rayDir = (aimPoint - result.body:GetNode():GetWorldPosition()):Normalized()
    rayDir = rayDir * self.attackImpulseMagnitude_
    rayDir.y = 1.0
    result.body:SetFriction(0.0)
    result.body:ApplyImpulse(rayDir)
  end
  
end

function FoinSpider:HandleHealthOperation(eventType, eventData)
  local operation = eventData["Operation"]:GetInt()
  local magnitude = eventData["Magnitude"]:GetInt()

  local healthSO = self.playerCollider_:GetScriptObject("Health")
  
  if operation == -1 then
    if healthSO.health_ > 0 then
      self:SetState(self.STATE_HURT)
    else
      self:SetState(self.STATE_DIE)
    end
  end

end
