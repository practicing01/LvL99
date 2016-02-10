require "LuaScripts/Health"
require "LuaScripts/Blind"
require "LuaScripts/LifeTime"

humanshocktrooper = ScriptObject()

function humanshocktrooper:Start()
  self.STRINGHASH_MAGNITUDE_ = StringHash("magnitude")
  self.STRINGHASH_FACTION = StringHash("Faction")
  
  self.flingMagnitude_ = 10.0
  
  self.aoeTrigger_ = nil
end

function humanshocktrooper:DelayedStart()
  self.aoeTrigger_ = LevelScene_:GetChild("aoeTrigger")
  
  self.node:CreateScriptObject("Health")
  self:SubscribeToEvent(self.node, "HealthOperation", "humanshocktrooper:HandleHealthOperation")
  --[[
  local sideCollision = self.node:GetChild("sideCollision")

  for i = 0, sideCollision:GetNumChildren() - 1, 1 do
    self:SubscribeToEvent(sideCollision:GetChild(i), "NodeCollisionStart", "humanshocktrooper:HandleDiceNodeCollisionStart")
  end
--]]
  self:SubscribeToEvent(self.node, "NodeCollisionStart", "humanshocktrooper:HandleDiceNodeCollisionStart")

end

function humanshocktrooper:HandleHealthOperation(eventType, eventData)
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
function humanshocktrooper:HandleDiceNodeCollisionStart(eventType, eventData)
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
function humanshocktrooper:HandleDiceNodeCollisionStart(eventType, eventData)
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
--[[
  local dir = ( otherNode:GetWorldPosition() - node:GetWorldPosition() ):Normalized()
  dir = dir * self.flingMagnitude_
  dir.y = self.flingMagnitude_
  
  local otherBody = eventData["OtherBody"]:GetPtr("RigidBody")
  
  otherBody:ApplyImpulse(dir)
  --]]
  
  local clone = self.aoeTrigger_:Clone(LOCAL)
  
  clone:SetPosition(node:GetPosition())
  
  clone:SetDeepEnabled(true)
  
  clone:CreateScriptObject("LifeTime")
    
  self:SubscribeToEvent(clone, "NodeCollisionStart", "humanshocktrooper:HandleAOETriggerCollisionStart")
  
end

function humanshocktrooper:HandleAOETriggerCollisionStart(eventType, eventData)
  local body = eventData["Body"]:GetPtr("RigidBody")
  local node = body:GetNode():GetParent()
  local otherNode = eventData["OtherNode"]:GetPtr("Node")
  
  if self.node == otherNode then return end
  
  local nodefaction = self.node:GetVar(self.STRINGHASH_FACTION):GetString()

  local otherNodeFactionVariant = otherNode:GetVar(self.STRINGHASH_FACTION)

  if otherNodeFactionVariant:IsEmpty() == true then return end

  local otherNodefaction = otherNodeFactionVariant:GetString()

  if nodefaction == otherNodefaction then return end

  local dir = ( otherNode:GetWorldPosition() - node:GetWorldPosition() ):Normalized()
  dir = dir * self.flingMagnitude_

  local otherBody = eventData["OtherBody"]:GetPtr("RigidBody")

  otherBody:ApplyImpulse(dir)

end
