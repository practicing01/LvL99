Projectile = ScriptObject()

function Projectile:Start()
  self.magnitude_ = 10
end

function Projectile:DelayedStart()
  self:SubscribeToEvent(self.node, "NodeCollisionStart", "Projectile:HandleNodeCollisionStart")
end

function Projectile:HandleNodeCollisionStart(eventType, eventData)
  local otherNode = eventData["OtherNode"]:GetPtr("Node")
  
  local healthSO = otherNode:GetScriptObject("Health")

  if healthSO ~= nil then
    healthSO.health_ = healthSO.health_ - self.magnitude_
    
    local vm = VariantMap()
    vm["Operation"] = Variant(-1)-- 0 = set, 1 = add, -1 = subtract
    vm["Magnitude"] = Variant(self.magnitude_)
    otherNode:SendEvent("HealthOperation", vm)
  end

  self.instance:Remove()
end
