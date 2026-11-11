function ZoneQuestForever_addInterfaceOptions()
  local y = -16
  ZoneQuestForever.panel = CreateFrame("Frame", "ZoneQuestPanel", UIParent)
  ZoneQuestForever.panel.name = "ZoneQuestForever"

  local category, layout =
    Settings.RegisterCanvasLayoutCategory(
    ZoneQuestForever.panel,
    ZoneQuestForever.panel.name,
    ZoneQuestForever.panel.name
  )
  category.ID = ZoneQuestForever.panel.name
  Settings.RegisterAddOnCategory(category)

  local Title = ZoneQuestForever.panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  Title:SetJustifyV("TOP")
  Title:SetJustifyH("LEFT")
  Title:SetPoint("TOPLEFT", 16, y)
  local v = C_AddOns.GetAddOnMetadata("ZoneQuestForever", "Version")
  Title:SetText("ZoneQuestForever v" .. v)
  y = y - 44

  local btnCompletes = CreateFrame("CheckButton", nil, ZoneQuestForever.panel, "UICheckButtonTemplate")
  btnCompletes:SetSize(26, 26)
  btnCompletes:SetHitRectInsets(-2, -160, -2, -2)
  btnCompletes.text:SetText("  Hide Completed Quests")
  btnCompletes.text:SetFontObject("GameFontNormal")
  btnCompletes:SetPoint("TOPLEFT", 40, y)
  btnCompletes:SetChecked(zqForeverSettings.showCompletes == false)
  btnCompletes:SetScript(
    "OnClick",
    function()
      local isChecked = btnCompletes:GetChecked()
      if isChecked then
        zqForeverSettings.showCompletes = false
      else
        zqForeverSettings.showCompletes = true
      end
      ZoneQuestForever_DelayedUpdate(1)
    end
  )
  y = y - 25

  local completedInfo = ZoneQuestForever.panel:CreateFontString(nil, "ARTWORK", "GameFontWhite")
  completedInfo:SetJustifyV("TOP")
  completedInfo:SetJustifyH("LEFT")
  completedInfo:SetPoint("TOPLEFT", 100, y)
  completedInfo:SetText("If this is checked, completed quests will always be hidden.")
  y = y - 40

  local btnOrange = CreateFrame("CheckButton", nil, ZoneQuestForever.panel, "UICheckButtonTemplate")
  btnOrange:SetSize(26, 26)
  btnOrange:SetHitRectInsets(-2, -160, -2, -2)
  btnOrange.text:SetText("  Hide Orange Quests")
  btnOrange.text:SetFontObject("GameFontNormal")
  btnOrange:SetPoint("TOPLEFT", 40, y)
  btnOrange:SetChecked(zqForeverSettings.hideOrange == true)
  btnOrange:SetScript(
    "OnClick",
    function()
      local isChecked = btnOrange:GetChecked()
      if isChecked then
        zqForeverSettings.hideOrange = true
      else
        zqForeverSettings.hideOrange = false
      end
      ZoneQuestForever_DelayedUpdate(1)
    end
  )
  y = y - 25

  local orangeInfo = ZoneQuestForever.panel:CreateFontString(nil, "ARTWORK", "GameFontWhite")
  orangeInfo:SetJustifyV("TOP")
  orangeInfo:SetJustifyH("LEFT")
  orangeInfo:SetPoint("TOPLEFT", 100, y)
  orangeInfo:SetText("If this is checked, orange quests (3 or more levels above your character) will be hidden.")
  y = y - 40

  local btnRed = CreateFrame("CheckButton", nil, ZoneQuestForever.panel, "UICheckButtonTemplate")
  btnRed:SetSize(26, 26)
  btnRed:SetHitRectInsets(-2, -160, -2, -2)
  btnRed.text:SetText("  Hide Red Quests")
  btnRed.text:SetFontObject("GameFontNormal")
  btnRed:SetPoint("TOPLEFT", 40, y)
  btnRed:SetChecked(zqForeverSettings.hideRed == true)
  btnRed:SetScript(
    "OnClick",
    function()
      local isChecked = btnRed:GetChecked()
      if isChecked then
        zqForeverSettings.hideRed = true
      else
        zqForeverSettings.hideRed = false
      end
      ZoneQuestForever_DelayedUpdate(1)
    end
  )
  y = y - 25

  local redInfo = ZoneQuestForever.panel:CreateFontString(nil, "ARTWORK", "GameFontWhite")
  redInfo:SetJustifyV("TOP")
  redInfo:SetJustifyH("LEFT")
  redInfo:SetPoint("TOPLEFT", 100, y)
  redInfo:SetText("If this is checked, red quests (5 or more levels above your character) will be hidden.")
  y = y - 40

  -- add a slider to choose max tracked quests from 3 to 20
  local slider = CreateFrame("Slider", nil, ZoneQuestForever.panel, "OptionsSliderTemplate")
  ZoneQuestForever.maxTrackedSlider = slider
  slider:SetPoint("TOPLEFT", 40, y)
  slider:SetMinMaxValues(3, 20)
  slider:SetValueStep(1)
  slider:SetObeyStepOnDrag(true)
  slider:SetValue(zqForeverSettings.maxTrackedQuests or 10)
  slider.Text:ClearAllPoints()
  slider.Text:SetPoint("LEFT", slider, "RIGHT", 10, 0)
  slider.Text:SetFontObject("GameFontNormal")
  slider.Text:SetText("Max Tracked Quests: " .. (zqForeverSettings.maxTrackedQuests or 10))
  slider:SetScript(
    "OnValueChanged",
    function(self, value)
      zqForeverSettings.maxTrackedQuests = value
      slider.Text:SetText("Max Tracked Quests: " .. value)
      ZoneQuestForever_DelayedUpdate(1)
    end
  )
  y = y - 35

  local maxTrackedInfo = ZoneQuestForever.panel:CreateFontString(nil, "ARTWORK", "GameFontWhite")
  maxTrackedInfo:SetJustifyV("TOP")
  maxTrackedInfo:SetJustifyH("LEFT")
  maxTrackedInfo:SetPoint("TOPLEFT", 100, y)
  maxTrackedInfo:SetText(
    "Set the maximum number of quests to track at once.\nDepending on quest availability and other settings, you may see a different number."
  )
  y = y - 40

  local btnFocus = CreateFrame("CheckButton", nil, ZoneQuestForever.panel, "UICheckButtonTemplate")
  btnFocus:SetSize(26, 26)
  btnFocus:SetHitRectInsets(-2, -160, -2, -2)
  btnFocus.text:SetText("  Focus on Quests Automatically")
  btnFocus.text:SetFontObject("GameFontNormal")
  btnFocus:SetPoint("TOPLEFT", 40, y)
  btnFocus:SetChecked(zqForeverSettings.manualFocusOnly == false)
  btnFocus:SetScript(
    "OnClick",
    function()
      local isChecked = btnFocus:GetChecked()
      if isChecked then
        zqForeverSettings.manualFocusOnly = false
      else
        zqForeverSettings.manualFocusOnly = true
      end
      ZoneQuestForever_DelayedUpdate(1)
    end
  )
  y = y - 25

  local focusInfo = ZoneQuestForever.panel:CreateFontString(nil, "ARTWORK", "GameFontWhite")
  focusInfo:SetJustifyV("TOP")
  focusInfo:SetJustifyH("LEFT")
  focusInfo:SetPoint("TOPLEFT", 100, y)
  focusInfo:SetText(
    "If this is checked, the game will automatically decide which quest to focus on:\nthe closest tracked quest or the quest you just interacted with."
  )
  y = y - 60

  local resetBtn = CreateFrame("Button", nil, ZoneQuestForever.panel, "UIPanelButtonTemplate")
  resetBtn:SetSize(160, 26)
  resetBtn:SetText("Reset to Default Settings")
  resetBtn:SetPoint("TOPLEFT", 40, y)
  resetBtn:SetScript(
    "OnClick",
    function()
      ZoneQuestForever_ResetSettings()
    end
  )
  y = y - 60

  local resetInfo = ZoneQuestForever.panel:CreateFontString(nil, "ARTWORK", "GameFontWhite")
  resetInfo:SetJustifyV("TOP")
  resetInfo:SetJustifyH("LEFT")
  resetInfo:SetPoint("TOPLEFT", 40, y)
  resetInfo:SetText(
    "If the order of quests in the list looks wrong, type '/zq reset' in the chat to reset.\nUse '/zq info' to see the numbers for each type of quest."
  )
end

function ZoneQuestForever_ResetSettings()
  ZoneQuestForever_ApplyDefaultSettings(true)
  ZoneQuestForever_DelayedUpdate(1)
  ZoneQuestForever_UpdateInterfaceOptions()
end

function ZoneQuestForever_UpdateInterfaceOptions()
  if not ZoneQuestForever.panel then
    return
  end

  for _, child in ipairs({ZoneQuestForever.panel:GetChildren()}) do
    if child.Text and child.Text:GetText() and string.find(child.Text:GetText(), "Max Tracked Quests:") then
      child.Text:SetText("Max Tracked Quests: " .. (zqForeverSettings.maxTrackedQuests or 10))
      if ZoneQuestForever.maxTrackedSlider then
        ZoneQuestForever.maxTrackedSlider:SetValue(zqForeverSettings.maxTrackedQuests or 10)
      end
    elseif child.text and child.text:GetText() == "  Hide Completed Quests" then
      child:SetChecked(zqForeverSettings.showCompletes == false)
    elseif child.text and child.text:GetText() == "  Focus on Closest Quest Automatically" then
      child:SetChecked(zqForeverSettings.manualFocusOnly == false)
    elseif child.text and child.text:GetText() == "  Hide Orange Quests" then
      child:SetChecked(zqForeverSettings.hideOrange == true)
    elseif child.text and child.text:GetText() == "  Hide Red Quests" then
      child:SetChecked(zqForeverSettings.hideRed == true)
    end
  end
end
