--[[
	typedef struct
	{
		float duration_;
		String sprite_;
	}Frame;

	typedef struct
	{
		String name_;
		String material_;
		bool loop_;
		Vector<Frame*> frames_;
	}Animation;

	typedef struct
	{
		float elapsedTime_;
		int curFrame_;
		bool flipX_;
		bool playing_;
		Vector<Animation*> animations_;
		Animation* animation_;
		SpriteSheet2D* sheet_;
		AnimatedModel* model_;
	}ShadedSprite;
--]]

ShadedSprite = ScriptObject()

function ShadedSprite:Start()
  self.shadedSprite_ = {
    elapsedTime_ = 0.0,
    curFrame_ = 1,
    flipX_ = false,
    playing_ = false,
    animations_ = {},
    animation_ = nil,
    sheets_ = {},
    sheet_ = nil,
    model_ = nil
    }
end

function ShadedSprite:DelayedStart()
  --self:SubscribeToEvent(self.node,"AnimateNode", "ShadedSprite:HandleAnimateNode")
end

--function ShadedSprite:HandleAnimateNode(eventType, eventData)
function ShadedSprite:AnimateNode(animation, flipX)
  
  for i, v in ipairs(self.shadedSprite_.animations_) do
    if v.name_ == animation then
      if self.shadedSprite_.animation_ == v then return end
      self.shadedSprite_.animation_ = v
      
      self.shadedSprite_.sheet_ = self.shadedSprite_.sheets_[i]
      
      self.shadedSprite_.model_:ApplyMaterialList(v.material_)
      
      self.shadedSprite_.elapsedTime_ = 0.0
      self.shadedSprite_.curFrame_ = 1 --remember, lua arrays start at 1
      self.shadedSprite_.playing_ = true
      --todo deal with flip
      
      local sprite = self.shadedSprite_.sheet_:GetSprite(self.shadedSprite_.animation_.frames_[self.shadedSprite_.curFrame_].sprite_)
      local rect = sprite:GetRectangle()

      local texture = self.shadedSprite_.sheet_:GetTexture()

      local material = self.shadedSprite_.model_:GetMaterial()

      material:SetShaderParameter("UOffset", Variant(Vector4(256/texture:GetWidth(), 0.0, 0.0, rect.left/texture:GetWidth())))
      material:SetShaderParameter("VOffset", Variant(Vector4(0.0, 256/texture:GetHeight(), 0.0, rect.top/texture:GetHeight())))
      break
    end
    
  end
  
end

function ShadedSprite:Update(timeStep)
  if self.shadedSprite_.playing_ == false then return end
  
  self.shadedSprite_.elapsedTime_ = self.shadedSprite_.elapsedTime_ + timeStep
  
  if self.shadedSprite_.elapsedTime_ >= self.shadedSprite_.animation_.frames_[self.shadedSprite_.curFrame_].duration_ then
    self.shadedSprite_.elapsedTime_ = 0.0
    self.shadedSprite_.curFrame_ = self.shadedSprite_.curFrame_ + 1
    
    if self.shadedSprite_.curFrame_ >= table.getn(self.shadedSprite_.animation_.frames_) then
      self.shadedSprite_.curFrame_ = 1
      
      if self.shadedSprite_.animation_.loop_ == false then
        self.shadedSprite_.playing_ = false
        --send animation finished event
        return
      end
      
    end

    --set new frame
    local sprite = self.shadedSprite_.sheet_:GetSprite(self.shadedSprite_.animation_.frames_[self.shadedSprite_.curFrame_].sprite_)
    local rect = sprite:GetRectangle()
    
    local texture = self.shadedSprite_.sheet_:GetTexture()
    
    local material = self.shadedSprite_.model_:GetMaterial()
    
    material:SetShaderParameter("UOffset", Variant(Vector4(256/texture:GetWidth(), 0.0, 0.0, rect.left/texture:GetWidth())))
    material:SetShaderParameter("VOffset", Variant(Vector4(0.0, 256/texture:GetHeight(), 0.0, rect.top/texture:GetHeight())))
    
  end
  
end
