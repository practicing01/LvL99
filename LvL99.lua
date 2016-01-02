require "LuaScripts/GameMenu/GameMenu"

LvL99Scene_ = nil
LvL99Node_ = nil
LevelScene_ = nil

function Start()
  SetRandomSeed(time:GetTimeSinceEpoch())
  input:SetMouseVisible(true)
	--input:SetTouchEmulation(true)
  
  if GetPlatform() == "Android" then
    renderer:SetMobileShadowBiasAdd(0.001)
  end
  
  SubscribeToEvent("KeyDown", "HandleKeyDown")
  
  LvL99Scene_ = Scene()
  
  LvL99Node_ = Node()
  
  LvL99Scene_:AddChild(LvL99Node_)
  
  LvL99Node_:CreateScriptObject("GameMenu")
end

function HandleKeyDown(eventType, eventData)
  local key = eventData["Key"]:GetInt()
  
  if key == KEY_ESC then
    engine:Exit()
  end
  
end
