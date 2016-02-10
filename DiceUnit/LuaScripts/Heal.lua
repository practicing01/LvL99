require "LuaScripts/Health"

Heal = ScriptObject()

function Heal:Start()
  self.elapsedTime_ = 0.0
  self.interval_ = 1.0
  self.magnitude_ = 1.0
  self.dotCount_ = 0.0
  self.dotMax_ = 10.0
end

function Heal:DelayedStart()
  self:SubscribeToEvent("Update", "Heal:HandleUpdate")
  
end

function Heal:HandleUpdate(eventType, eventData)
  local timeStep = eventData["TimeStep"]:GetFloat()
  
  self.elapsedTime_ = self.elapsedTime_ + timeStep

  if self.elapsedTime_ >= self.interval_ then
    self.elapsedTime_ = 0.0
    
    self.dotCount_ = self.dotCount_ + 1
    
    if self.dotCount_ >= self.dotMax_ then
      self.instance:Remove()
      return
    end
    
    local vm = VariantMap()
    vm["Operation"] = Variant(1)-- 0 = set, 1 = add, -1 = subtract
    vm["Magnitude"] = Variant(self.magnitude_)
    self.node:SendEvent("HealthOperation", vm)
  
  end

end
