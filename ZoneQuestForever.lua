-- ZoneQuest: An addon to track quests by zone, relevance and distance.

-- Always show tracked quest at the top of the list, then complete, important, meta, then the rest sorted by distance.
-- Don't track newest quest if it is auto-accepted.
-- If you do track it, make sure to track the quest that was selected before accepting the new quest,
--   so that the selected quest doesn't get lost when accepting a new quest.
-- add option to reset list without any selected or newest quests so order is based purely on zone and distance

-- not sure that accepting a new quest is working properly
-- track for levelling and re-calculate quests then

ZoneQuestForever = {}

local ZoneQuestForever_EventFrame = CreateFrame("Frame")
ZoneQuestForever_EventFrame:RegisterEvent("VARIABLES_LOADED")
ZoneQuestForever_EventFrame:RegisterEvent("PLAYER_LOGIN")
ZoneQuestForever_EventFrame:RegisterEvent("ZONE_CHANGED")
ZoneQuestForever_EventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
ZoneQuestForever_EventFrame:RegisterEvent("QUEST_ACCEPTED") -- Fires when a quest is accepted, including auto-accepted quests.
ZoneQuestForever_EventFrame:RegisterEvent("QUEST_COMPLETE")
ZoneQuestForever_EventFrame:RegisterEvent("QUEST_AUTOCOMPLETE")
ZoneQuestForever_EventFrame:RegisterEvent("QUEST_TURNED_IN")
ZoneQuestForever_EventFrame:RegisterEvent("QUEST_REMOVED")
ZoneQuestForever_EventFrame:RegisterEvent("QUEST_ACCEPT_CONFIRM") -- Fires when agreeing to join a group quest that a party member has started
ZoneQuestForever_EventFrame:RegisterEvent("QUEST_FINISHED")
ZoneQuestForever_EventFrame:RegisterEvent("QUEST_WATCH_UPDATE")
ZoneQuestForever_EventFrame:RegisterEvent("QUEST_WATCH_LIST_CHANGED")
ZoneQuestForever_EventFrame:RegisterEvent("PLAYER_LEVEL_CHANGED")

ZoneQuestForever_SelectedQuestID = nil -- quest the player selected (super-tracked) themselves
ZoneQuestForever_NewestQuestID = nil -- newest accepted quest, kept on the tracked list
ZoneQuestForever_JustAcceptedQuestID = nil -- quest accepted since the last update, may take focus once
ZoneQuestForever_UpdatedQuestID = nil -- quest whose objectives updated since the last update, may take focus once
ZoneQuestForever_AutoFocusQuestID = nil -- last just accepted or updated quest that took focus, keeps it while tracked

ZoneQuestForever_UpdatingQuests = false
ZoneQuestForever_ManuallyUntrackedQuests = {}
ZoneQuestForever_ManuallyTrackedQuests = {}
ZoneQuestForever_KnownQuestIDs = {} -- quests in the log at the last update, used to spot newly accepted quests

ZoneQuestForever_DebugMode = false

ZoneQuestForever_EventFrame:SetScript(
  "OnEvent",
  function(self, event, questID, added, ...)
    -- if ZoneQuestForever_UpdatingQuests == false then
    --   print(event, questID, added, ...)
    -- end
    if event == "VARIABLES_LOADED" then
      ZoneQuestForever:Initialize()
    elseif event == "PLAYER_LOGIN" then
      ZoneQuestForever_ShowWelcome()
      ZoneQuestForever_DelayedUpdate(1)
    elseif event == "ZONE_CHANGED" or event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_LEVEL_CHANGED" then
      ZoneQuestForever_DelayedUpdate(1)
    elseif event == "QUEST_ACCEPTED" or event == "QUEST_ACCEPT_CONFIRM" then
      if questID and questID > 0 then
        ZoneQuestForever_HandleNewQuest(questID)
      end
    elseif event == "QUEST_WATCH_UPDATE" then
      if questID and questID > 0 then
        local haveRemoved = ZoneQuestForever_RemoveQuestFromManualUntracking(questID)
        if haveRemoved then
          ZoneQuestForever_DebugPrint("Removed updated quest from manual tracking: " .. questID)
        end
        ZoneQuestForever_UpdatedQuestID = questID
        ZoneQuestForever_DelayedUpdate(1)
      end
    elseif
      event == "QUEST_COMPLETE" or event == "QUEST_TURNED_IN" or event == "QUEST_REMOVED" or
        event == "QUEST_AUTOCOMPLETE" or
        event == "QUEST_FINISHED"
     then
      -- the player's selection only lasts until the quest is turned in or abandoned
      if (event == "QUEST_TURNED_IN" or event == "QUEST_REMOVED") and questID == ZoneQuestForever_SelectedQuestID then
        ZoneQuestForever_SelectedQuestID = nil
      end
      ZoneQuestForever_DelayedUpdate(1)
    elseif event == "QUEST_WATCH_LIST_CHANGED" and ZoneQuestForever_UpdatingQuests == false then
      if questID and questID > 0 then
        if added and not ZoneQuestForever_KnownQuestIDs[questID] then
          -- a newly accepted quest is auto-watched before QUEST_ACCEPTED fires, so this isn't a manual track
          -- mark it as known so that later manual changes to its watch are followed
          ZoneQuestForever_DebugPrint("Ignoring auto-watch of new quest: " .. questID)
          ZoneQuestForever_KnownQuestIDs[questID] = true
        else
          ZoneQuestForever_UpdateManualTracking(questID, added)
        end
      end
      ZoneQuestForever_DelayedUpdate(1)
    end
  end
)

-- the player selecting (focusing) a quest calls C_SuperTrack.SetSuperTrackedQuestID(),
-- so hook it to remember the player's choice, ignoring the calls this addon makes while updating
hooksecurefunc(
  C_SuperTrack,
  "SetSuperTrackedQuestID",
  function(questID)
    if ZoneQuestForever_UpdatingQuests then
      return
    end
    ZoneQuestForever_SelectedQuestID = (questID and questID > 0) and questID or nil
    ZoneQuestForever_DebugPrint("Player selected quest: " .. tostring(ZoneQuestForever_SelectedQuestID))
  end
)

if C_SuperTrack.ClearAllSuperTracked then
  hooksecurefunc(
    C_SuperTrack,
    "ClearAllSuperTracked",
    function()
      if not ZoneQuestForever_UpdatingQuests then
        ZoneQuestForever_SelectedQuestID = nil
      end
    end
  )
end

function ZoneQuestForever:Initialize()
  SLASH_ZoneQuestForever1, SLASH_ZoneQuestForever2, SLASH_ZoneQuestForever3 = "/ZoneQuestForever", "/zq", "/zqf"
  SlashCmdList["ZoneQuestForever"] = ZoneQuestForeverCommandHandler
  if not zqForeverSettings then
    zqForeverSettings = {}
    ZoneQuestForever_ApplyDefaultSettings(false)
  end

  ZoneQuestForever_addInterfaceOptions()
end

function ZoneQuestForever_ApplyDefaultSettings(withMessage)
  if withMessage then
    ZoneQuestForever_DisplayMessage("ZoneQuestForever settings have been reset to the defaults.", true)
  end

  zqForeverSettings = {
    showCompletes = true,
    maxTrackedQuests = 10,
    manualFocusOnly = false,
    hideOrange = true,
    hideRed = true
  }
end

function ZoneQuestForeverCommandHandler(msg)
  if msg == "reset" then
    ZoneQuestForever_Reset()
  elseif msg == "info" then
    ZoneQuestForever_Report()
  else
    ZoneQuestForever_DisplayHelp()
  end
end

function ZoneQuestForever_ShowWelcome()
  local v = C_AddOns.GetAddOnMetadata("ZoneQuestForever", "Version")
  local msg =
    "|c0000FF00Welcome to ZoneQuestForever v" .. v .. ": " .. "|c0000FFFFType |c00FFD100/zq |c0000FFFFfor help."
  ZoneQuestForever_DisplayMessage(msg, false)
end

function ZoneQuestForever_DisplayMessage(msg, format)
  if format == true then
    local formatted_msg = "|c0000FF00ZoneQuestForever: |c0000FFFF" .. msg
    ChatFrame1:AddMessage(formatted_msg)
  else
    ChatFrame1:AddMessage(msg)
  end
end

function ZoneQuestForever_DisplayHelp()
  local msg
  msg = "|c0000FF00ZoneQuestForever" .. "|c0000FFFFattempts to track quests by zone, relevance and distance."
  ChatFrame1:AddMessage(msg)
  msg = "|c0000FF00ZoneQuestForever: " .. "|c0000FFFFType |cFFFFFFFF/zqf reset|c0000FFFF to reset the quest list order."
  ChatFrame1:AddMessage(msg)
  msg =
    "|c0000FF00ZoneQuestForever: " ..
    "|c0000FFFFType |cFFFFFFFF/zqf info|c0000FFFF for a report on your current quests."
  ChatFrame1:AddMessage(msg)
  msg = "|c0000FFFFUse Game Menu > Options > AddOns > ZoneQuestForever to configure the options."
  ChatFrame1:AddMessage(msg)
end

-- test function
function ZoneQuestForever_ListQuests()
  local maxNumQuests = C_QuestLog.GetMaxNumQuests()
  for i = 1, maxNumQuests do
    local questID = C_QuestLog.GetQuestIDForLogIndex(i)
    if questID > 0 then
      local isOnQuest = C_QuestLog.IsOnQuest(questID)
      if isOnQuest then
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHidden then
          local isComplete = C_QuestLog.IsComplete(questID)
          local isRed = info.level and info.level >= UnitLevel("player") + 5
          local isOrange = info.level and info.level >= UnitLevel("player") + 3

          local title = info.title
          local isOnMap = info.isOnMap
          local distanceSq, onContinent = C_QuestLog.GetDistanceSqToQuest(questID)

          print(
            "Quest ID: " ..
              questID ..
                ", Title: " ..
                  title ..
                    ", Complete: " ..
                      tostring(isComplete) ..
                        ", Red: " ..
                          tostring(isRed) ..
                            ", Orange: " ..
                              tostring(isOrange) ..
                                ", OnMap: " ..
                                  tostring(isOnMap) ..
                                    ", DistanceSq: " ..
                                      (distanceSq or "N/A") .. ", OnContinent: " .. tostring(onContinent)
          )
        end
      end
    end
  end
end

-- /run ZoneQuestForever_ListQuests()

function ZoneQuestForever_UntrackAllQuests()
  local maxNumQuests = C_QuestLog.GetNumQuestWatches()
  local index = 1
  for i = 1, maxNumQuests do
    local questID = C_QuestLog.GetQuestIDForQuestWatchIndex(index)
    if questID and questID > 0 then
      local info = C_QuestLog.GetInfo(questID)
      C_QuestLog.RemoveQuestWatch(questID)
    end
  end
end

-- /run ZoneQuestForever_UntrackAllQuests()

function ZoneQuestForever_WatchQuests(doReset)
  ZoneQuestForever_UpdatingQuests = true
  ZoneQuestForever_UntrackAllQuests()

  if doReset then
    ZoneQuestForever_ManuallyUntrackedQuests = {}
    ZoneQuestForever_ManuallyTrackedQuests = {}
  end

  -- valid quests list all appropriate quests sorted by distance
  -- this includes manually tracked quests, completed quests, red quests, orange quests as appropriate based on settings

  local validQuests = ZoneQuestForever_GetValidQuests()
  ZoneQuestForever_DebugPrint(
    "Valid Quests: " ..
      #validQuests ..
        ", Manually Untracked: " ..
          #ZoneQuestForever_ManuallyUntrackedQuests .. ", Manually Tracked: " .. #ZoneQuestForever_ManuallyTrackedQuests
  )

  local inInstance, instanceType = IsInInstance()
  if inInstance then
    ZoneQuestForever_WatchInstanceQuests(validQuests)
    ZoneQuestForever_UpdatingQuests = false
    return
  end

  local questsToShow = {}

  -- forget the player's selection if the quest has left the log
  if ZoneQuestForever_SelectedQuestID and not ZoneQuestForever_KnownQuestIDs[ZoneQuestForever_SelectedQuestID] then
    ZoneQuestForever_SelectedQuestID = nil
  end

  if doReset then
    ZoneQuestForever_SelectedQuestID = nil
    ZoneQuestForever_NewestQuestID = nil
    ZoneQuestForever_JustAcceptedQuestID = nil
    ZoneQuestForever_UpdatedQuestID = nil
    ZoneQuestForever_AutoFocusQuestID = nil
    ZoneQuestForever_ManuallyUntrackedQuests = {}
    ZoneQuestForever_ManuallyTrackedQuests = {}
  else
    questsToShow.selected = ZoneQuestForever_SelectedQuestID
    questsToShow.newest = ZoneQuestForever_NewestQuestID
  end

  local alreadyWatched = {}
  local numWatches = C_QuestLog.GetNumQuestWatches()
  for i = 1, numWatches do
    local watchInfo = C_QuestLog.GetQuestWatchInfo(i)
    if watchInfo then
      alreadyWatched[watchInfo.questID] = true
    end
  end

  local function addWatch(questID)
    if not alreadyWatched[questID] then
      C_QuestLog.AddQuestWatch(questID)
      alreadyWatched[questID] = true
    end
  end

  local function distanceOf(quest)
    return quest.distanceSq or math.huge
  end

  local validQuestsByID = {}
  for _, quest in ipairs(validQuests) do
    validQuestsByID[quest.questID] = quest
  end

  -- Quest List:
  -- reduce list to the maximum number of quests to track
  -- validQuests is already sorted by distance, so the first quests in this zone are the closest
  local maxQuests = zqForeverSettings.maxTrackedQuests or 10
  local shortlist = {}
  local onShortlist = {}
  for _, quest in ipairs(validQuests) do
    if #shortlist >= maxQuests then
      break
    end
    if quest.isOnQuest and quest.isOnMap and quest.onContinent and quest.distanceSq then
      table.insert(shortlist, quest)
      onShortlist[quest.questID] = true
    end
  end

  -- if this shortlist is empty, try again without the onMap requirement, so that quests that are not on the map but are on the continent can be tracked
  if #shortlist == 0 then
    for _, quest in ipairs(validQuests) do
      if #shortlist >= maxQuests then
        break
      end
      if quest.isOnQuest and quest.onContinent and quest.distanceSq then
        table.insert(shortlist, quest)
        onShortlist[quest.questID] = true
      end
    end
  end

  -- then calculate extras - manually tracked, new, focused
  -- only include those that that not already in the shortlist of closest quests
  local extras = {}
  local isExtra = {}
  local function addExtra(questID)
    if not questID or onShortlist[questID] or isExtra[questID] then
      return
    end
    local quest = validQuestsByID[questID]
    if quest and quest.isOnQuest then
      table.insert(extras, quest)
      isExtra[questID] = true
    end
  end

  for _, quest in ipairs(validQuests) do
    if quest.isManuallyTracked then
      addExtra(quest.questID)
    end
  end
  addExtra(questsToShow.newest)
  addExtra(questsToShow.selected)
  if not doReset then
    addExtra(ZoneQuestForever_UpdatedQuestID)
  end

  -- if there are any extras, check if adding them would go over the limit
  -- if so, remove the furthest quest(s) from the shortlist to make room for the extras
  local excess = #shortlist + #extras - maxQuests
  while excess > 0 and #shortlist > 0 do
    local removed = table.remove(shortlist)
    onShortlist[removed.questID] = nil
    excess = excess - 1
  end

  -- then add the extras to the shortlist and sort by distance again
  for _, quest in ipairs(extras) do
    table.insert(shortlist, quest)
    onShortlist[quest.questID] = true
  end

  table.sort(
    shortlist,
    function(a, b)
      return distanceOf(a) < distanceOf(b)
    end
  )

  -- display the new shortlist of quests to track
  -- add the furthest first so the closest ends up at the top
  for i = #shortlist, 1, -1 do
    addWatch(shortlist[i].questID)
  end

  ZoneQuestForever_DebugPrint("Tracking " .. #shortlist .. " quests, including " .. #extras .. " extras")

  -- Focus:
  -- with manualFocusOnly enabled, the addon never changes the focus, so the player's selection (or lack of one) stands
  if not zqForeverSettings.manualFocusOnly then
    local focusQuestID = nil

    if questsToShow.selected then
      -- respect a quest the player selected
      focusQuestID = questsToShow.selected
    else
      -- otherwise select a just accepted quest if it is within the closest 3 quests
      local justAccepted = not doReset and ZoneQuestForever_JustAcceptedQuestID
      if justAccepted then
        for i = 1, math.min(3, #shortlist) do
          if shortlist[i].questID == justAccepted then
            focusQuestID = justAccepted
            break
          end
        end
      end

      -- or a quest whose objectives were just updated
      local updated = not doReset and ZoneQuestForever_UpdatedQuestID
      if not focusQuestID and updated and onShortlist[updated] then
        focusQuestID = updated
      end

      if focusQuestID then
        ZoneQuestForever_AutoFocusQuestID = focusQuestID
      elseif ZoneQuestForever_AutoFocusQuestID and onShortlist[ZoneQuestForever_AutoFocusQuestID] then
        -- keep focus on the last accepted or updated quest while it is still being tracked
        focusQuestID = ZoneQuestForever_AutoFocusQuestID
      else
        ZoneQuestForever_AutoFocusQuestID = nil
      end

      -- otherwise select the closest quest
      if not focusQuestID and shortlist[1] then
        focusQuestID = shortlist[1].questID
      end
    end

    ZoneQuestForever_DebugPrint(
      "Focus: " ..
        tostring(focusQuestID) ..
          ", selected: " ..
            tostring(questsToShow.selected) ..
              ", just accepted: " ..
                tostring(ZoneQuestForever_JustAcceptedQuestID) ..
                  ", updated: " ..
                    tostring(ZoneQuestForever_UpdatedQuestID) ..
                      ", auto focus: " .. tostring(ZoneQuestForever_AutoFocusQuestID)
    )

    if focusQuestID and C_SuperTrack.GetSuperTrackedQuestID() ~= focusQuestID then
      C_SuperTrack.SetSuperTrackedQuestID(focusQuestID)
    end
  end

  -- just accepted and just watched quests only get one chance at focus
  ZoneQuestForever_JustAcceptedQuestID = nil
  ZoneQuestForever_UpdatedQuestID = nil

  ZoneQuestForever_UpdatingQuests = false
end

-- /run ZoneQuestForever_WatchQuests()

function ZoneQuestForever_GetValidQuests()
  local quests = {}
  local allQuestIDs = {}
  local maxNumQuests = C_QuestLog.GetMaxNumQuests()
  local userLevel = UnitLevel("player")

  for i = 1, maxNumQuests do
    local info = C_QuestLog.GetInfo(i)
    if info and not info.isHidden then
      local questID = info.questID
      allQuestIDs[questID] = true

      local isValid = ZoneQuestForever_IsQuestValid(info, userLevel)
      if isValid then
        local distanceSq, onContinent = C_QuestLog.GetDistanceSqToQuest(questID)
        local onMap, hasLocalPOI = C_QuestLog.IsOnMap(questID)

        table.insert(
          quests,
          {
            questID = questID,
            title = info.title,
            level = info.level,
            isOnMap = info.isOnMap,
            questClassification = info.questClassification,
            isOnQuest = C_QuestLog.IsOnQuest(questID),
            isComplete = C_QuestLog.IsComplete(questID),
            isImportant = C_QuestLog.IsImportantQuest(questID),
            isMeta = C_QuestLog.IsMetaQuest(questID),
            distanceSq = distanceSq,
            onContinent = onContinent,
            onMap = onMap,
            hasLocalPOI = hasLocalPOI,
            isManuallyTracked = tContains(ZoneQuestForever_ManuallyTrackedQuests, questID)
          }
        )
      end
    end
  end

  ZoneQuestForever_RemoveMissingQuestsFromManualTracking(allQuestIDs)
  ZoneQuestForever_KnownQuestIDs = allQuestIDs

  -- quests with no distance sort to the end
  table.sort(
    quests,
    function(a, b)
      return (a.distanceSq or math.huge) < (b.distanceSq or math.huge)
    end
  )
  return quests
end

function ZoneQuestForever_IsQuestValid(questInfo, userLevel)
  if not questInfo or not questInfo.level then
    return false
  end

  if not questInfo.questID or questInfo.questID <= 0 then
    return false
  end

  if ZoneQuestForever_ManuallyTrackedQuests and tContains(ZoneQuestForever_ManuallyTrackedQuests, questInfo.questID) then
    return true
  end

  if zqForeverSettings.hideOrange and questInfo.level >= userLevel + 3 then
    return false
  end

  if zqForeverSettings.hideRed and questInfo.level >= userLevel + 5 then
    return false
  end

  local questID = questInfo.questID
  local isComplete = C_QuestLog.IsComplete(questID)
  if zqForeverSettings.showCompletes == false and isComplete then
    return false
  end

  if ZoneQuestForever_ManuallyUntrackedQuests and tContains(ZoneQuestForever_ManuallyUntrackedQuests, questInfo.questID) then
    return false
  end

  return true
end

function ZoneQuestForever_GetAllQuests()
  local quests = {}
  local allQuestIDs = {}
  local maxNumQuests = C_QuestLog.GetMaxNumQuests()

  for i = 1, maxNumQuests do
    local info = C_QuestLog.GetInfo(i)
    if info and not info.isHidden then
      local questID = info.questID
      allQuestIDs[questID] = true

      if questID and questID > 0 then
        local distanceSq, onContinent = C_QuestLog.GetDistanceSqToQuest(questID)
        local onMap, hasLocalPOI = C_QuestLog.IsOnMap(questID)

        table.insert(
          quests,
          {
            questID = questID,
            title = info.title,
            level = info.level,
            isOnMap = info.isOnMap,
            questClassification = info.questClassification,
            isOnQuest = C_QuestLog.IsOnQuest(questID),
            isComplete = C_QuestLog.IsComplete(questID),
            distanceSq = distanceSq,
            onContinent = onContinent,
            onMap = onMap,
            hasLocalPOI = hasLocalPOI
          }
        )
      end
    end
  end

  return quests
end

function ZoneQuestForever_GetManuallyTrackedQuests(validQuests)
  local manuallyTracked = {}

  for _, quest in ipairs(validQuests) do
    if quest.isOnQuest and quest.isManuallyTracked then
      local distanceSq = quest.distanceSq or 0
      table.insert(manuallyTracked, {questID = quest.questID, distanceSq = distanceSq, title = quest.title})
    end
  end

  return manuallyTracked
end

function ZoneQuestForever_GetManuallyUntrackedQuests()
  local manuallyUntracked = {}

  for _, questID in ipairs(ZoneQuestForever_ManuallyUntrackedQuests) do
    local info = C_QuestLog.GetInfo(questID)
    if info then
      local distanceSq, onContinent = C_QuestLog.GetDistanceSqToQuest(questID)
      local onMap, hasLocalPOI = C_QuestLog.IsOnMap(questID)
      table.insert(
        manuallyUntracked,
        {
          questID = questID,
          title = info.title,
          isOnMap = info.isOnMap,
          questClassification = info.questClassification,
          isOnQuest = C_QuestLog.IsOnQuest(questID),
          isComplete = C_QuestLog.IsComplete(questID),
          isImportant = C_QuestLog.IsImportantQuest(questID),
          isMeta = C_QuestLog.IsMetaQuest(questID),
          distanceSq = distanceSq,
          onContinent = onContinent,
          onMap = onMap,
          hasLocalPOI = hasLocalPOI,
          isManuallyTracked = tContains(ZoneQuestForever_ManuallyTrackedQuests, questID)
        }
      )
    end
  end

  return manuallyUntracked
end

function ZoneQuestForever_HandleNewQuest(questID)
  if questID and questID > 0 then
    local userLevel = UnitLevel("player")

    local questLogIndex = C_QuestLog.GetLogIndexForQuestID(questID)
    if questLogIndex and questLogIndex > 0 then
      local info = C_QuestLog.GetInfo(questLogIndex)
      if info and not info.isHidden and info.questClassification and info.questClassification <= 7 then
        ZoneQuestForever_NewestQuestID = questID
        ZoneQuestForever_JustAcceptedQuestID = questID
        ZoneQuestForever_UpdatedQuestID = nil
        if zqForeverSettings.manualFocusOnly then
          if C_QuestLog.ShouldDisplayTimeRemaining(questID) == false then
            ZoneQuestForever_NewestQuestID = nil
          end
        end

      -- if zqForeverSettings.hideRed and info.level >= userLevel + 5 then
      --   ZoneQuestForever_NewestQuestID = nil
      -- elseif zqForeverSettings.hideOrange and info.level >= userLevel + 3 then
      --   ZoneQuestForever_NewestQuestID = nil
      -- elseif zqForeverSettings.manualFocusOnly then
      --   ZoneQuestForever_NewestQuestID = nil
      -- else
      --   ZoneQuestForever_NewestQuestID = questID
      --   ZoneQuestForever_JustAcceptedQuestID = questID
      --   ZoneQuestForever_UpdatedQuestID = nil
      -- end
      end
    end
    ZoneQuestForever_DelayedUpdate(1)
  end
end

function ZoneQuestForever_WatchInstanceQuests(validQuests)
  for _, quest in ipairs(validQuests) do
    if quest.onMap or quest.hasLocalPOI then
      C_QuestLog.AddQuestWatch(quest.questID)
    end
  end
end

local _delayedUpdateTimer
function ZoneQuestForever_DelayedUpdate(delay)
  -- an update is already scheduled, so let it run rather than pushing it back
  if _delayedUpdateTimer then
    return
  end
  _delayedUpdateTimer =
    C_Timer.NewTimer(
    delay,
    function()
      _delayedUpdateTimer = nil
      ZoneQuestForever_DebugPrint("Updating quest list")
      ZoneQuestForever_WatchQuests(false)
    end
  )
end

function ZoneQuestForever_UpdateManualTracking(questID, added)
  if added then
    for i, id in ipairs(ZoneQuestForever_ManuallyUntrackedQuests) do
      if id == questID then
        table.remove(ZoneQuestForever_ManuallyUntrackedQuests, i)
        break
      end
    end
    if not tContains(ZoneQuestForever_ManuallyTrackedQuests, questID) then
      table.insert(ZoneQuestForever_ManuallyTrackedQuests, questID)
    end
  else
    for i, id in ipairs(ZoneQuestForever_ManuallyTrackedQuests) do
      if id == questID then
        table.remove(ZoneQuestForever_ManuallyTrackedQuests, i)
        break
      end
    end
    if not tContains(ZoneQuestForever_ManuallyUntrackedQuests, questID) then
      table.insert(ZoneQuestForever_ManuallyUntrackedQuests, questID)
    end
  end
end

function ZoneQuestForever_RemoveQuestFromManualUntracking(questID)
  local haveRemoved = false
  for i, id in ipairs(ZoneQuestForever_ManuallyUntrackedQuests) do
    if id == questID then
      table.remove(ZoneQuestForever_ManuallyUntrackedQuests, i)
      haveRemoved = true
      break
    end
  end
  return haveRemoved
end

function ZoneQuestForever_RemoveQuestFromManualTracking(questID)
  local haveRemoved = false
  for i, id in ipairs(ZoneQuestForever_ManuallyTrackedQuests) do
    if id == questID then
      table.remove(ZoneQuestForever_ManuallyTrackedQuests, i)
      haveRemoved = true
      break
    end
  end
  return haveRemoved
end

function ZoneQuestForever_RemoveMissingQuestsFromManualTracking(allQuestIDs)
  for i = #ZoneQuestForever_ManuallyUntrackedQuests, 1, -1 do
    if not allQuestIDs[ZoneQuestForever_ManuallyUntrackedQuests[i]] then
      table.remove(ZoneQuestForever_ManuallyUntrackedQuests, i)
    end
  end

  for i = #ZoneQuestForever_ManuallyTrackedQuests, 1, -1 do
    if not allQuestIDs[ZoneQuestForever_ManuallyTrackedQuests[i]] then
      table.remove(ZoneQuestForever_ManuallyTrackedQuests, i)
    end
  end
end

function ZoneQuestForever_Reset()
  ZoneQuestForever_WatchQuests(true)
  ZoneQuestForever_DisplayMessage("The ZoneQuestForever quest tracking has been reset.", true)
end

function ZoneQuestForever_Report()
  local quests = ZoneQuestForever_GetAllQuests()
  local userLevel = UnitLevel("player")

  local totalQuests = 0
  local completedCount = 0
  local mapCount = 0
  local redCount = 0
  local orangeCount = 0

  for _, quest in ipairs(quests) do
    if quest.isOnQuest then
      totalQuests = totalQuests + 1
      if quest.isComplete then
        completedCount = completedCount + 1
      end
      if quest.isOnMap then
        mapCount = mapCount + 1
      end
      if quest.level and quest.level > 0 then
        if quest.level >= userLevel + 5 then
          redCount = redCount + 1
        elseif quest.level >= userLevel + 3 then
          orangeCount = orangeCount + 1
        end
      end
    end
  end

  ZoneQuestForever_DisplayMessage("Quest Report:", true)
  ZoneQuestForever_FormatReport("Total Quests", totalQuests)
  ZoneQuestForever_FormatReport("Completed Quests", completedCount)
  ZoneQuestForever_FormatReport("Orange Quests", orangeCount)
  ZoneQuestForever_FormatReport("Red Quests", redCount)
  ZoneQuestForever_FormatReport("Quests in this Map", mapCount)
end

function ZoneQuestForever_FormatReport(header, info)
  local formatted_msg = "|c0000FFFF    " .. header .. ": |cFFFFFFFF" .. info
  ChatFrame1:AddMessage(formatted_msg)
end

function ZoneQuestForever_DebugPrint(msg)
  if ZoneQuestForever_DebugMode then
    print(msg)
  end
end
