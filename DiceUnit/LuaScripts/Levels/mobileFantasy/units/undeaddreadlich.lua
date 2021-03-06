require "LuaScripts/Health"
require "LuaScripts/Blind"
require "LuaScripts/LifeTime"
require "LuaScripts/Poison"

undeaddreadlich = ScriptObject()

function undeaddreadlich:Start()
  self.STRINGHASH_MAGNITUDE_ = StringHash("magnitude")
  self.STRINGHASH_FACTION = StringHash("Faction")
  
  self.aoeMagnitude_ = 1.0
  self.aoeTrigger_ = nil
  self.aoeNode_ = nil
  
end

function undeaddreadlich:DelayedStart()
  self.aoeTrigger_ = LevelScene_:GetChild("aoeTrigger")
  self.aoeNode_ = LevelScene_:GetChild("poison")
  
  self.node:CreateScriptObject("Health")
  self:SubscribeToEvent(self.node, "HealthOperation", "undeaddreadlich:HandleHealthOperation")
  --[[
  local sideCollision = self.node:GetChild("sideCollision")

  for i = 0, sideCollision:GetNumChildren() - 1, 1 do
    self:SubscribeToEvent(sideCollision:GetChild(i), "NodeCollisionStart", "undeaddreadlich:HandleDiceNodeCollisionStart")
  end
--]]
  self:SubscribeToEvent(self.node, "NodeCollisionStart", "undeaddreadlich:HandleDiceNodeCollisionStart")

end

function undeaddreadlich:HandleHealthOperation(eventType, eventData)
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
function undeaddreadlich:HandleDiceNodeCollisionStart(eventType, eventData)
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
function undeaddreadlich:HandleDiceNodeCollisionStart(eventType, eventData)
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
  
  local healthSO = self.node:GetScriptObject("Health")
  
  local lifesteal = Min(100, healthSO.health_ + diff)
  
  vm["Operation"] = Variant(0)-- 0 = set, 1 = add, -1 = subtract
  vm["Magnitude"] = Variant(lifesteal)
  self.node:SendEvent("HealthOperation", vm)
  
  local clone = self.aoeTrigger_:Clone(LOCAL)
  
  clone:SetPosition(node:GetPosition())
  --[[
  local aoe = self.aoeNode_:Clone(LOCAL)
  
  clone:AddChild(aoe)
  
  aoe:SetPosition(Vector3(0.0, 0.0, 0.0))
  
  aoe:SetScale(2.0)
  --]]
  clone:SetDeepEnabled(true)
  
  local lifeTimeSO = clone:CreateScriptObject("LifeTime")
  
  lifeTimeSO.magnitude_ = 1.0
  
  self:SubscribeToEvent(clone, "NodeCollisionStart", "undeaddreadlich:HandleAOETriggerCollisionStart")

end

function undeaddreadlich:HandleAOETriggerCollisionStart(eventType, eventData)
  local body = eventData["Body"]:GetPtr("RigidBody")
  local node = body:GetNode():GetParent()
  local otherNode = eventData["OtherNode"]:GetPtr("Node")
  
  if self.node == otherNode then return end
  
  local nodefaction = self.node:GetVar(self.STRINGHASH_FACTION):GetString()

  local otherNodeFactionVariant = otherNode:GetVar(self.STRINGHASH_FACTION)

  if otherNodeFactionVariant:IsEmpty() == true then return end

  local otherNodefaction = otherNodeFactionVariant:GetString()

  if nodefaction == otherNodefaction then return end

  otherNode:CreateScriptObject("Poison")
  
end
