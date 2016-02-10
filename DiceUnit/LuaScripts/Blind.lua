require "LuaScripts/Health"

Blind = ScriptObject()

function Blind:Start()
  self.elapsedTime_ = 0.0
  self.interval_ = 1.0
  self.magnitude_ = 1.0
  self.dotCount_ = 0.0
  self.dotMax_ = 10.0
  self.fxNode_ = nil
end

function Blind:DelayedStart()
  self.fxNode_ = LevelScene_:GetChild("blind"):Clone(LOCAL)
  
  self.node:AddChild(self.fxNode_)
  
  self.fxNode_:SetPosition(Vector3(0.0, 0.0, 0.0))
  
  --self.fxNode_:SetScale(2.0)
  
  self.fxNode_:SetDeepEnabled(true)
  
  self:SubscribeToEvent("Update", "Blind:HandleUpdate")

end

function Blind:HandleUpdate(eventType, eventData)
  local timeStep = eventData["TimeStep"]:GetFloat()
  
  self.elapsedTime_ = self.elapsedTime_ + timeStep

  if self.elapsedTime_ >= self.interval_ then
    self.elapsedTime_ = 0.0
    
    self.dotCount_ = self.dotCount_ + 1
    
    if self.dotCount_ >= self.dotMax_ then
      self.fxNode_:Remove()
      self.instance:Remove()
      return
      
    end
    
  end

end
