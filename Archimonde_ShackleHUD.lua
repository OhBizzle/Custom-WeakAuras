-- Auro: Archimonde - ShackleHUD
-- Version: 0.2.1
-- Load: Zone[Hellfire Citadel]
-- Do Not Load: EncounterID

-- Trigger [ENCOUNTER_START, ENCOUNTER_END, COMBAT_LOG_EVENT_UNFILTERED, AuroBM_ShackleHUD]
function(event, encounterID, msg, _, srcGUID, srcName, _, _, destGUID, destName, _, _, spellID, spellName)
  if (event == "ENCOUNTER_START" and aura_env.encounterIDs[encounterID] == true) then
    aura_env.wipe2DTable(aura_env.shackles);
    aura_env.wipeTable(aura_env.rosterIDs);
    aura_env.playerRaidID = nil;
    aura_env.rosterSize = GetNumGroupMembers();
    for i = 1, aura_env.rosterSize do
      local guid = UnitGUID("raid" .. i);
      aura_env.rosterIDs[guid] = i;
      if (guid == aura_env.playerGUID) then
        aura_env.playerRaidID = i;
      end
    end
    print("Auro: Archimonde ShackleHUD - Loaded");
  elseif (event == "ENCOUNTER_END" and aura_env.encounterIDs[encounterID] == true) then
    aura_env.wipe2DTable(aura_env.shackles);
    aura_env.wipeTable(aura_env.rosterIDs);
    aura_env.playerRaidID = nil;
    -- Turns off HUD
    aura_env.core:Request2Show(aura_env.id, false);
    WeakAuras.ScanEvents(aura_env.eventName);
  end
  if (event == "COMBAT_LOG_EVENT_UNFILTERED") then
    if (msg == "SPELL_AURA_APPLIED" and spellID == aura_env.shackleDebuffSpellID) then
      -- Delete leftover disks
      if (aura_env.shackles[destGUID]) then
        aura_env.wipeTable(aura_env.shackles[destGUID]);
        aura_env.shackles[destGUID] = nil;
      end
      -- Find Unit
      local unit = aura_env.core.roster[destGUID];
      if not unit then return end
      local pos = {unpack(aura_env.core.positions[unit])};
      if not pos then return end
      local raidID = aura_env.rosterIDs[destGUID];
      if not raidID then return false; end
      local x, y, z, map = UnitPosition("raid" .. raidID);
      if not x then return false; end
      if not y then return false; end

      -- Create disk
      local disk = aura_env.core:NewDisk(aura_env.shackleRange * aura_env.core.db.scale);
      -- Assumes destGUID is focused and destGUID is wrought
      disk:Stick(pos);
      -- Color / put in table
      aura_env.shackles[destGUID] = {};
      aura_env.shackles[destGUID]["x"] = x;
      aura_env.shackles[destGUID]["y"] = y;
      aura_env.shackles[destGUID]["unit"] = raidID;
      aura_env.shackles[destGUID]["disk"] = disk;

      if (destGUID == aura_env.playerGUID) then
        disk = aura_env.core:NewDisk(aura_env.personalShackleRange * aura_env.core.db.scale);
        disk:Stick(pos);
        disk:Color(0, 0, 1, aura_env.diskOpacity - 0.05);
        aura_env.personalShackle = disk;
      end

      return true;
    elseif ((msg == "SPELL_AURA_REMOVED" and spellID == aura_env.shackleDebuffSpellID) or (msg == "UNIT_DIED" and aura_env.shackles[destGUID])) then
      -- Clear Disk
      if (aura_env.shackles[destGUID]) then
        aura_env.wipeTable(aura_env.shackles[destGUID]);
        aura_env.shackles[destGUID] = nil;
      end

      if (destGUID == aura_env.playerGUID) then
        local disk = aura_env.personalShackle;
        if disk then
          disk:Free();
          aura_env.personalShackle = nil;
        end
      end

      if not next(aura_env.shackles) then
        aura_env.core:Request2Show(aura_env.id, false);
        WeakAuras.ScanEvents(aura_env.eventName);
      end
    elseif (msg == "SPELL_CAST_START" and spellID == aura_env.ascensionSpellID) then
      -- P3 Disable HUD
      aura_env.wipe2DTable(aura_env.shackles);
      local disk = aura_env.personalShackle;
      if disk then
        disk:Free();
        aura_env.personalShackle = nil;
      end
      -- Turns off HUD
      aura_env.core:Request2Show(aura_env.id, false);
      WeakAuras.ScanEvents(aura_env.eventName);
    elseif (msg == "SPELL_CAST_START" and spellID == aura_env.shackleCastSpellID) then
      -- If shackles from last shackle are still out the new shackles do not show
      -- I think I should hide here, and show on cast success
      aura_env.wipe2DTable(aura_env.shackles);
      local disk = aura_env.personalShackle;
      if disk then
        disk:Free();
        aura_env.personalShackle = nil;
      end
    elseif (msg == "SPELL_CAST_SUCCESS" and spellID == aura_env.shackleCastSpellID) then
      aura_env.core:Request2Show(aura_env.id, true, aura_env.hudScale);
    end
  end
end

-- Untrigger
function(event)
  if (event == aura_env.eventName) then
    return true;
  end
end

-- Custom Text [Every Frame]
function()
  if not aura_env.core then return "" end
  if not aura_env.rosterSize then return "" end
  if not aura_env.rosterIDs then return "" end
  if not aura_env.playerRaidID then return "" end

  local chaosOpacity = 0;
  local wroughtCheck = UnitDebuff("player", "Wrought Chaos");
  local focusCheck = UnitDebuff("player", "Focused Chaos");
  if (wroughtCheck ~= nil or focusCheck ~= nil) then
    chaosOpacity = 0.1;
  end

  for guid in pairs (aura_env.shackles) do
    -- Variables
    local shackleUnit = aura_env.shackles[guid]["unit"];
    local shackleX = aura_env.shackles[guid]["x"];
    local shackleY = aura_env.shackles[guid]["y"];
    local disk = aura_env.shackles[guid]["disk"];
    local num = 0;
    local playerIn = false;
    local personalDisk = aura_env.personalShackle;

    if not shackleX then break end
    if not shackleY then break end
    if not shackleUnit then break end
    if not disk then break end

    for i = 1, aura_env.rosterSize do
      local isDead = UnitIsDeadOrGhost("raid" .. i);
      if (shackleUnit ~= i and isDead == false) then
        local raidX, raidY = UnitPosition("raid" .. i);
        if not raidX then break end
        local distance = aura_env.distance(shackleX, shackleY, raidX, raidY);
        if (distance <= aura_env.shackleRange) then
          num = num + 1;
          if (i == aura_env.playerRaidID) then
            playerIn = true;
          end
        end;
      end
    end

    disk.timer:SetText(num);
    if (num > 0 and playerIn == true) then
      disk:Color(1, 0, 0, aura_env.diskOpacity - chaosOpacity);
    elseif (num > 0 and playerIn == false) then
      disk:Color(1, 1, 0, aura_env.diskOpacity - chaosOpacity);
    else
      disk:Color(0, 0.5, 0, aura_env.diskOpacity - chaosOpacity);
    end
  end
  if personalDisk then
    disk:Color(0, 0, 1, aura_env.diskOpacity - chaosOpacity - 0.05);
  end

  if not next(aura_env.shackles) then
    aura_env.core:Request2Show(aura_env.id, false);
    WeakAuras.ScanEvents(aura_env.eventName);
  end
  return "";
end


-- Init
aura_env.core = WA_RaidHUD;
aura_env.hudScale = 6;
aura_env.eventName = "AuroBM_ShackleHUD";
aura_env.playerGUID = UnitGUID("player");
aura_env.playerRaidID = nil;
aura_env.rosterSize = nil;
aura_env.rosterIDs = {};
aura_env.shackles = {};
aura_env.personalShackle = nil;
aura_env.shackleCastSpellID = 184931;
aura_env.shackleDebuffSpellID = 184964;
aura_env.ascensionSpellID = 190313;
aura_env.shackleRange = 25;
aura_env.personalShackleRange = 30;
aura_env.encounterIDs = {};
aura_env.encounterIDs[1799] = true;
aura_env.diskOpacity = 0.2;
aura_env.wipeTable = function(table)
  -- Clear Table
  for guid in pairs(table) do
    if (guid == "disk" or guid == "line") then
      local disk = table[guid];
      disk:Free();
    end
    table[guid] = nil;
  end
end
aura_env.wipe2DTable = function(table)
  -- Clear Table
  for guid in pairs(table) do
      for v in pairs(table[guid]) do
        if (v == "disk" or v == "line") then
          local disk = table[guid][v];
          if (disk) then
            disk:Free();
          end
        end
        table[guid][v] = nil;
      end
      table[guid] = nil;
  end
end
aura_env.distance = function(x1, y1, x2, y2)
  local dx = x2 - x1;
  local dy = y2 - y1;
  local distance = (dx * dx) + (dy * dy);
  distance = math.sqrt(distance);
  return distance;
end
