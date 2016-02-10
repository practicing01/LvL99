require "LuaScripts/Health"

SunRotator = ScriptObject()

function SunRotator:Start()
  self.elapsedTime_ = 0.0
  self.interval_ = 0.1
  self.magnitude_ = 0.1
  
end

function SunRotator:DelayedStart()
  self:SubscribeToEvent("Update", "SunRotator:HandleUpdate")
  
end

function SunRotator:HandleUpdate(eventType, eventData)
  local timeStep = eventData["TimeStep"]:GetFloat()
  
  self.elapsedTime_ = self.elapsedTime_ + timeStep

  if self.elapsedTime_ >= self.interval_ then
    self.elapsedTime_ = 0.0
    
    self.node:Pitch(self.magnitude_)
  
  end

end
