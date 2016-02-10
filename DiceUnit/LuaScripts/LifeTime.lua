LifeTime = ScriptObject()

function LifeTime:Start()
  self.elapsedTime_ = 0.0
  self.magnitude_ = 1.0
end

function LifeTime:DelayedStart()
  self:SubscribeToEvent("Update", "LifeTime:HandleUpdate")
  
end

function LifeTime:HandleUpdate(eventType, eventData)
  local timeStep = eventData["TimeStep"]:GetFloat()
  
  self.elapsedTime_ = self.elapsedTime_ + timeStep

  if self.elapsedTime_ >= self.magnitude_ then
     self.node:Remove()
     --self.instance:Remove()
     
  end

end
