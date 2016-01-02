Snare = ScriptObject()

function Snare:Start()
  self.active_ = false
  self.magnitude_ = 1.0
  self.duration_ = -1.0
  self.elapsedTime_ = 0.0
end

function Snare:Snare(magnitude, duration)
  local speedSO = self.node:GetScriptObject("Speed")
  if speedSO == nil then return end
  
  self.active_ = true
  self.magnitude_ = magnitude
  self.duration_ = duration
  self.elapsedTime_ = 0.0
  
  speedSO.speed_ = speedSO.speed_ - self.magnitude_
  
  self.node:GetComponent("RigidBody"):SetAngularFactor(Vector3(1.0, 1.0, 1.0))
  self.node:GetComponent("RigidBody"):SetAngularDamping(0.75)
  self.node:GetComponent("RigidBody"):SetLinearDamping(0.75)
end

function Snare:Update(timeStep)
  if self.active_ == false then return end
  
  if self.duration_ == -1.0 then return end
  
  self.elapsedTime_ = self.elapsedTime_ + timeStep
  
  if self.elapsedTime_ >= self.duration_ then
    local speedSO = self.node:GetScriptObject("Speed")
    
    if speedSO ~= nil then
      speedSO.speed_ = speedSO.speed_ + self.magnitude_
    end
    
    self.node:GetComponent("RigidBody"):SetAngularFactor(Vector3(0.0, 0.0, 0.0))
    self.node:GetComponent("RigidBody"):SetAngularDamping(0.0)
    self.node:GetComponent("RigidBody"):SetLinearDamping(0.0)
    self.instance:Remove()
  end
  
end
