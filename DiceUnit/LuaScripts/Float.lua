Float = ScriptObject()

function Float:Start()
  self.elapsedTime_ = 0.0
  self.interval_ = 1.0
  self.magnitude_ = 1.0
  self.dotCount_ = 0.0
  self.dotMax_ = 10.0
end

function Float:DelayedStart()
  local body = self.node:GetComponent("RigidBody")
  
  if body:GetUseGravity() == false then
    self.instance:Remove()
    return
  end
  
  body:SetUseGravity(false)
  self:SubscribeToEvent("Update", "Float:HandleUpdate")

end

function Float:HandleUpdate(eventType, eventData)
  local timeStep = eventData["TimeStep"]:GetFloat()
  
  self.elapsedTime_ = self.elapsedTime_ + timeStep

  if self.elapsedTime_ >= self.interval_ then
    self.elapsedTime_ = 0.0
    
    self.dotCount_ = self.dotCount_ + 1
    
    if self.dotCount_ >= self.dotMax_ then
      local body = self.node:GetComponent("RigidBody")
      body:SetUseGravity(true)
      body:Activate()

      self.instance:Remove()
      return
    end
    
  end

end
