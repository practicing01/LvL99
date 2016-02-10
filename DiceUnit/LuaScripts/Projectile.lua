Projectile = ScriptObject()

function Projectile:Start()
  self.magnitude_ = 10
  self.STRINGHASH_FACTION = StringHash("Faction")
end

function Projectile:DelayedStart()
  self:SubscribeToEvent(self.node, "NodeCollisionStart", "Projectile:HandleNodeCollisionStart")
end

function Projectile:HandleNodeCollisionStart(eventType, eventData)
  local body = eventData["Body"]:GetPtr("RigidBody")
  local node = body:GetNode()
  local otherNode = eventData["OtherNode"]:GetPtr("Node")
  
  local nodefaction = node:GetVar(self.STRINGHASH_FACTION):GetString()
  
  local otherNodeFactionVariant = otherNode:GetVar(self.STRINGHASH_FACTION)
  
  if otherNodeFactionVariant:IsEmpty() == true then
    self.node:Remove()
    self.instance:Remove()
    return
    
  end
    
  local otherNodefaction = otherNodeFactionVariant:GetString()
  
  if nodefaction == otherNodefaction then return end
  
  local vm = VariantMap()
  vm["Operation"] = Variant(-1)-- 0 = set, 1 = add, -1 = subtract
  vm["Magnitude"] = Variant(diff)
  otherNode:SendEvent("HealthOperation", vm)

  self.node:Remove()
  self.instance:Remove()
end
