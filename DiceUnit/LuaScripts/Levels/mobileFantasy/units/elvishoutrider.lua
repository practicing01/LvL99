require "LuaScripts/Health"
require "LuaScripts/Blind"
require "LuaScripts/Projectile"

elvishoutrider = ScriptObject()

function elvishoutrider:Start()
  self.STRINGHASH_MAGNITUDE_ = StringHash("magnitude")
  self.STRINGHASH_FACTION = StringHash("Faction")
  
  self.projectileNode_ = nil
  
end

function elvishoutrider:DelayedStart()
  self.projectileNode_ = LevelScene_:GetChild("arrow")
  
  self.node:CreateScriptObject("Health")
  self:SubscribeToEvent(self.node, "HealthOperation", "elvishoutrider:HandleHealthOperation")
  --[[
  local sideCollision = self.node:GetChild("sideCollision")

  for i = 0, sideCollision:GetNumChildren() - 1, 1 do
    self:SubscribeToEvent(sideCollision:GetChild(i), "NodeCollisionStart", "elvishoutrider:HandleDiceNodeCollisionStart")
  end
--]]
  self:SubscribeToEvent(self.node, "NodeCollisionStart", "elvishoutrider:HandleDiceNodeCollisionStart")

  self.node:GetComponent("RigidBody"):SetRestitution(0.5)

end

function elvishoutrider:HandleHealthOperation(eventType, eventData)
  local operation = eventData["Operation"]:GetInt()
  local magnitude = eventData["Magnitude"]:GetInt()
  
  local healthSO = self.node:GetScriptObject("Health")
  
  if operation == -1 then
    healthSO.health_ = healthSO.health_ - magnitude
    
    if healthSO.health_ > 0 then
      --self:SetState(self.STATE_HURT)
      
    else
      healthSO.health_ = 100
      
      local vm = VariantMap()
      vm["Node"] = Variant(self.node)
      SendEvent("UnitCaptured", vm)
      
    end
    
  elseif operation == 1 then
    healthSO.health_ = healthSO.health_ + magnitude
    
  else
    healthSO.health_ = magnitude
    
  end

  self.node:GetChild("healthText"):GetComponent("Text3D"):SetText(healthSO.health_)

end
--[[
function elvishoutrider:HandleDiceNodeCollisionStart(eventType, eventData)
  local trigger = eventData["Trigger"]:GetBool()
  
  if trigger == false then return end
  
  local body = eventData["Body"]:GetPtr("RigidBody")
  local node = body:GetNode()
  local otherNode = eventData["OtherNode"]:GetPtr("Node")
  
  local nodePower = node:GetVar(self.STRINGHASH_MAGNITUDE_):GetInt()
  local otherNodeToughnessVariant = otherNode:GetVar(self.STRINGHASH_MAGNITUDE_)
  
  if otherNodeToughnessVariant:IsEmpty() == true then
    return
  end
  
  local nodefaction = node:GetParent():GetParent():GetVar(self.STRINGHASH_FACTION):GetString()
  local otherNodefaction = otherNode:GetParent():GetParent():GetVar(self.STRINGHASH_FACTION):GetString()
  
  if nodefaction == otherNodefaction then return end
  
  local otherNodeToughness = otherNodeToughnessVariant:GetInt()
  
  local diff = Max(0, nodePower - otherNodeToughness)
  
  local vm = VariantMap()
  vm["Operation"] = Variant(-1)-- 0 = set, 1 = add, -1 = subtract
  vm["Magnitude"] = Variant(diff)
  otherNode:GetParent():GetParent():SendEvent("HealthOperation", vm)
end
--]]
function elvishoutrider:HandleDiceNodeCollisionStart(eventType, eventData)
  if self.node:GetScriptObject("Blind") ~= nil then return end
    
  local body = eventData["Body"]:GetPtr("RigidBody")
  local node = body:GetNode()
  local otherNode = eventData["OtherNode"]:GetPtr("Node")
  
  local nodePower = Random(1, 21)
  
  local nodefaction = node:GetVar(self.STRINGHASH_FACTION):GetString()
  
  local otherNodeFactionVariant = otherNode:GetVar(self.STRINGHASH_FACTION)
  
  if otherNodeFactionVariant:IsEmpty() == true then return end
    
  local otherNodefaction = otherNodeFactionVariant:GetString()
  
  if nodefaction == otherNodefaction then return end
  
  local otherNodeToughness = Random(1, 21)
  
  local diff = Max(0, nodePower - otherNodeToughness)
  
  local vm = VariantMap()
  vm["Operation"] = Variant(-1)-- 0 = set, 1 = add, -1 = subtract
  vm["Magnitude"] = Variant(diff)
  otherNode:SendEvent("HealthOperation", vm)
  
  for i = 90, 270, 30 do
    local clone = self.projectileNode_:Clone(LOCAL)

    clone:SetVar(self.STRINGHASH_FACTION, Variant(nodefaction))

    clone:SetPosition(node:GetPosition())

    local quatRot = node:GetWorldRotation()

    local yaw = quatRot:YawAngle() + i

    quatRot:FromAngleAxis(yaw, Vector3(0.0, 1.0, 0.0))

    clone:SetRotation(quatRot)

    clone:SetDeepEnabled(true)

    clone:CreateScriptObject("Projectile")

    clone:GetComponent("RigidBody"):SetLinearVelocity(clone:GetWorldDirection() * 2)
    
  end
  
end
