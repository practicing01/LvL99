require "LuaScripts/Health"

Snare = ScriptObject()

function Snare:Start()
  self.elapsedTime_ = 0.0
  self.interval_ = 1.0
  self.magnitude_ = 1.0
  self.dotCount_ = 0.0
  self.dotMax_ = 10.0
  self.linearDamping_ = 1.0
  self.angularDamping_ = 1.0
  self.friction_ = 1.0
  self.fxNode_ = nil
end

function Snare:DelayedStart()
  self.fxNode_ = LevelScene_:GetChild("snare"):Clone(LOCAL)
  
  self.node:AddChild(self.fxNode_)
  
  self.fxNode_:SetPosition(Vector3(0.0, 0.0, 0.0))
  
  --self.fxNode_:SetScale(2.0)
  
  self.fxNode_:SetDeepEnabled(true)
  
  self:SubscribeToEvent("Update", "Snare:HandleUpdate")
  
  local body = self.node:GetComponent("RigidBody")
  
  body:SetFriction(body:GetFriction() + self.friction_)
  body:SetLinearDamping(body:GetLinearDamping() + self.linearDamping_)
  body:SetAngularDamping(body:GetAngularDamping() + self.angularDamping_)
end

function Snare:HandleUpdate(eventType, eventData)
  local timeStep = eventData["TimeStep"]:GetFloat()
  
  self.elapsedTime_ = self.elapsedTime_ + timeStep

  if self.elapsedTime_ >= self.interval_ then
    self.elapsedTime_ = 0.0
    
    self.dotCount_ = self.dotCount_ + 1
    
    if self.dotCount_ >= self.dotMax_ then
      
      local body = self.node:GetComponent("RigidBody")
      body:SetFriction(body:GetFriction() - self.friction_)
      body:SetLinearDamping(body:GetLinearDamping() - self.linearDamping_)
      body:SetAngularDamping(body:GetAngularDamping() - self.angularDamping_)

      self.fxNode_:Remove()
      self.instance:Remove()
      return
    end
    
  end

end
