require "LuaScripts/Health"

Regenerate = ScriptObject()

function Regenerate:Start()
  self.elapsedTime_ = 0.0
  self.interval_ = 1.0
  self.magnitude_ = 1.0
end

function Regenerate:DelayedStart()
  self:SubscribeToEvent("Update", "Regenerate:HandleUpdate")
  
end

function Regenerate:HandleUpdate(eventType, eventData)
  local timeStep = eventData["TimeStep"]:GetFloat()
  
  self.elapsedTime_ = self.elapsedTime_ + timeStep

  if self.elapsedTime_ >= self.interval_ then
    self.elapsedTime_ = 0.0
    
    local healthSO = self.node:GetScriptObject("Health")
    
    if healthSO.health_ >= 100 then return end
    
    local vm = VariantMap()
    vm["Operation"] = Variant(1)-- 0 = set, 1 = add, -1 = subtract
    vm["Magnitude"] = Variant(self.magnitude_)
    self.node:SendEvent("HealthOperation", vm)
  
  end

end
