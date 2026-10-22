setDefaultTab("User")

UI.Separator()


function fakeHoverChange(creature)
    if not creature then return end

    if not modules.game_battle or not modules.game_battle.onBattleButtonHoverChange then return end

    local fakeButton = {
        creature = creature,
        isHovered = false,
        update = function() end
    }

    modules.game_battle.onBattleButtonHoverChange(fakeButton, true)
    modules.game_battle.onBattleButtonHoverChange(fakeButton, false)
end

local foco
local switchState = false
Maker = { target = nil, buttons = {}, pendingRemoval = {} }
storage.leaders = storage.leaders or { "Lider 1", "Lider 2", "Lider 3" }

function isLeaderOnScreen()
    for _, spec in ipairs(getSpectators()) do
        for _, leader in ipairs(storage.leaders) do
            if spec:isPlayer() and spec:getName() == leader then
                return true
            end
        end
    end
    return false
end

function isTargetOnScreen(targetId)
    for _, spec in ipairs(getSpectators()) do
        if spec:isPlayer() and spec:getId() == targetId then
            return spec
        end
    end
    return nil
end

HOLDER = macro(1,  function()
	if g_game.isAttacking() and not isInPz() then
	if not (Maker.target == target():getId()) then
    if g_game.getAttackingCreature():isPlayer() and not target():isPartyMember()  and not isFriend(target():getName()) then

		delay(100)
        Maker.target = g_game.getAttackingCreature():getId()
	end
end
end


end)

onTextMessage(function(mode, text)
  local match = text:match("Seu jutsu foi selado por (%d+) segundos.")
  
  if match then
      storage.timesela.t = now + tonumber(match)*1000
      
  end
end)

macro(1,  function()
	if g_game.isAttacking() and not isInPz() then
	if not (Maker.target == target():getId()) then
    if (not g_game.getAttackingCreature():isPlayer()) then
      Maker.target = 0
	end
end
end


end)

-- Resetar alvo com tecla "2"
onKeyPress(function(pressedKey)
    if pressedKey == "2" or pressedKey == "Escape" then
        
        Maker.target = 0
        modules.game_battle.autoAtaqueTarget = nil
        g_game.cancelAttackAndFollow()
        
    end
end)


onTalk(function(name, level, mode, text, channelId, pos)
  if (player:getName() ~= name) then return; end
  if string.sub(text, 1, 1):lower() == 'x' then
      local checkMsg = string.sub(text, 2):trim()
      if checkMsg == '0' then
          storage.senseNames.lastName = false;
      else
          storage.senseNames.lastName = checkMsg;
      end
  end
end)

local senseMaintain = {
senseRegex = "([a-z A-Z]*) is ([a-z -A-Z]*)to the ([a-z -A-Z]*)."
};

local http = {"H", "T", "T", "P"};
http = modules.corelib[table.concat(http)];

gameMapPanel = "gameMapPanel = g_ui.getRootWidget():%s('gameMapPanel')";

local rec_ch_by_id = {"r", "e", "c", "u", "r", "s", "i", "v", "e", "G", "e", "t", "C", "h", "i", "l", "d", "B", "y", "I", "d"};
rec_ch_by_id = table.concat(rec_ch_by_id);
gameMapPanel = gameMapPanel:format(rec_ch_by_id);
loadstring(gameMapPanel)();

senseMaintain.widget = [[
Panel
  image-source: /images/ui/panel_flat
  size: 45 45
  anchors.centerIn: parent
]];

senseMaintain.setupPointer = function()
if (senseMaintain.pointer) then
  senseMaintain.pointer:destroy();
end
senseMaintain.pointer = setupUI(senseMaintain.widget, gameMapPanel);

senseMaintain.pointer:setImageSource("/bot/" .. ConfigName .. "/img/styleSense", function(image)
  senseMaintain.pointer:setImageSource(image);
end)

storage.senseNames = storage.senseNames or {};
senseMaintain.initialPosition = senseMaintain.pointer:getPosition();

senseMaintain.pointer:breakAnchors();
senseMaintain.pointer:hide();

local initialPos = senseMaintain.initialPosition;

senseMaintain.positions = {
  
  north = {x = initialPos.x, y = initialPos.y - 200, rotation = 0},
  
  south = {x = initialPos.x, y = initialPos.y + 200, rotation = 180},
  
  west = {x = initialPos.x - 200, y = initialPos.y, rotation = 270},

  east = {x = initialPos.x + 200, y = initialPos.y, rotation = 90},

  ["north-west"] = {x = initialPos.x - 200, y = initialPos.y - 200, rotation = 315},
  
  ["north-east"] = {x = initialPos.x + 200, y = initialPos.y - 200, rotation = 45},
  
  ["south-west"] = {x = initialPos.x - 200, y = initialPos.y + 200, rotation = 225},
  
  ["south-east"] = {x = initialPos.x + 200, y = initialPos.y + 200, rotation = 135}
}
end

senseMaintain.setupPointer();

gameMapPanel.onGeometryChange = senseMaintain.setupPointer;

local isKeyPressed = modules.corelib.g_keyboard.isKeyPressed;

function Creature:isNearby()
local creaturePos = self:getPosition();
local playerPos = player:getPosition();
return creaturePos and creaturePos.z == playerPos.z and getDistanceBetween(playerPos, creaturePos) <= 5;
end

senseMaintain.searchWithinVariables = function() -- forEach function that contains "getatt", will try to get the creature
for key, func in pairs(g_game) do
  key = key:lower();
  if (key:match("getatt") and type(func) == 'function') then
    local result = func();
    if (result) then
      if (result:isPlayer() or result:isMonster()) then
        return result;
      end
    end
  end
end
end

battlePanel = g_ui.getRootWidget():recursiveGetChildById("battlePanel");
local ATTACKING_COLORS = {'#FF8888', '#FF0000'};

senseMaintain.getAttackingCreature = function()
local pos = pos();
for _, child in ipairs(battlePanel:getChildren()) do
  local creature = child.creature;
  if (creature) then
    local creaturePos = creature:getPosition();
    if (creaturePos and creaturePos.z == pos.z) then
      if (table.find(ATTACKING_COLORS, child.color)) then
        return creature;
      end
    end
  end
end
return senseMaintain.searchWithinVariables();
end

if (not getPlayerByName(player:getName())) then
getPlayerByName = function(name)
  if (type(name) ~= 'string') then return; end
  name = name:trim():lower();
  
  for _, tile in ipairs(g_map.getTiles(posz())) do
    for _, creature in ipairs(tile:getCreatures()) do
      if (creature:isPlayer()) then
        if (creature:getName():lower() == name) then
          return creature;
        end
      end
    end
  end
end
end

macro(1, function()
  if stopToCast() or (stopCombo and stopCombo >= now) then return; end
local target = senseMaintain.getAttackingCreature();

if (target and target:isPlayer()) then
  local targetName = target:getName();
  if (not table.find(storage.senseNames, targetName, true)) then
    storage.senseNames.targetName = targetName;
  end
end



for _, value in ipairs({
  {
    key = storage.keySenseTarget,
    name = storage.senseNames.targetName;
  },
  
  {
    key = storage.keySenseX,
    name = storage.senseNames.lastName;
  }	
}) do 
  if (value.name) then
    if (isKeyPressed(value.key)) then
      local creature = getPlayerByName(value.name);
      if (not creature or not creature:isNearby()) then
        return say('sense "' .. value.name);
      end
    end
  end
end
end)

senseMaintain.getPositionByName = function(name)
name = name:trim();

return senseMaintain.positions[name];
end

onTextMessage(function(mode, text)
if (mode ~= 20) then return; end
local data = regexMatch(text, senseMaintain.senseRegex)[1];
if (not data or #data < 4) then return; end

local position = senseMaintain.getPositionByName(data[4]);
senseMaintain.pointer.timeLapse = now + 5000;
local senseName = data[2];
if (not table.find(storage.senseNames, senseName, true)) then
  storage.senseNames.lastName = senseName:trim();
end
senseMaintain.pointer:setPosition({x = position.x, y = position.y});
senseMaintain.pointer:setRotation(position.rotation);
senseMaintain.lastName = senseName;
end)


macro(1, function()
senseMaintain.pointer:hide();
local timer = senseMaintain.pointer.timeLapse;
if (not timer or timer < now) then return; end

local creature = getPlayerByName(senseMaintain.lastName);

if (creature and creature:isNearby()) then return; end

senseMaintain.pointer:show();
end)

UI.Separator()


local qqca = UI.Label("Atalhos SENSE")
qqca:setFont("verdana-11px-rounded")
qqca:setColor("orange")

local qqcoisa = UI.TextEdit(storage.keySenseTarget or "V", function(widget, text)
  storage.keySenseTarget = text
  end)
  qqcoisa:setFont("verdana-11px-rounded")
  qqcoisa:setColor("white")
  qqcoisa:setTooltip("Preencha com o atalho que deseja para utilizar o sense target")

local qqcoisa = UI.TextEdit(storage.keySenseX or "T", function(widget, text)
    storage.keySenseX = text
end)
qqcoisa:setFont("verdana-11px-rounded")
qqcoisa:setColor("white")
qqcoisa:setTooltip("Preencha com o atalho que deseja para utilizar o sense X")
