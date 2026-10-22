scriptFuncs = {};
comboSpellsWidget = {};
fugaSpellsWidgets = {};

scriptFuncs.readProfile = function(filePath, callback)
    if g_resources.fileExists(filePath) then
        local status, result = pcall(function()
            return json.decode(g_resources.readFileContents(filePath))
        end)
        if not status then
            return onError("Erro carregando arquivo (" .. filePath .. "). Para consertar o problema, exclua o arquivo. Detalhes: " .. result)
        end

        callback(result);
    end
end

scriptFuncs.saveProfile = function(configFile, content)
    local status, result = pcall(function()
        return json.encode(content, 2)
    end);

    if not status then
        return onError("Erro salvando configuração. Detalhes: " .. result);
    end

    if result:len() > 100 * 1024 * 1024 then
        return onError("Arquivo de configuração acima de 100MB, não será salvo.");
    end

    g_resources.writeFileContents(configFile, result);
end

storageProfiles = {
    comboSpells = {},
    fugaSpells = {},
    keySpells = {}
}

MAIN_DIRECTORY = "/bot/" .. modules.game_bot.contentsPanel.config:getCurrentOption().text .. "/storage/"
STORAGE_DIRECTORY = "" .. MAIN_DIRECTORY .. g_game.getWorldName() .. '.json';


if not g_resources.directoryExists(MAIN_DIRECTORY) then
    g_resources.makeDir(MAIN_DIRECTORY);
end

function resetCooldowns()
    if storageProfiles then
        if storageProfiles.comboSpells then
            for _, spell in ipairs(storageProfiles.comboSpells) do
                spell.cooldownSpells = nil 
            end
        end
        if storageProfiles.fugaSpells then
            for _, spell in ipairs(storageProfiles.fugaSpells) do
                spell.totalCooldown = nil;
                spell.activeCooldown = nil;
            end
        end
     end
end


scriptFuncs.readProfile(STORAGE_DIRECTORY, function(result)
    storageProfiles = result;
    if (type(storageProfiles.comboSpells) ~= 'table') then
        storageProfiles.comboSpells = {};
    end
    if (type(storageProfiles.fugaSpells) ~= 'table') then
        storageProfiles.fugaSpells = {};
    end
    if (type(storageProfiles.keySpells) ~= 'table') then
        storageProfiles.keySpells = {};
    end
    resetCooldowns();
end);


scriptFuncs.reindexTable = function(t)
    if not t or type(t) ~= "table" then return end

    local i = 0
    for _, e in pairs(t) do
        i = i + 1
        e.index = i
    end
end

firstLetterUpper = function(str)
    return (str:gsub("(%a)([%w_']*)", function(first, rest) return first:upper()..rest:lower() end))
end

storage['iconScripts'] = storage['iconScripts'] or {
    comboMacro = true,
    fugaMacro = false,
    showInfos = false,
    keyMacro = false
}

local isOn = storage['iconScripts'];

function removeTable(tbl, index)
    table.remove(tbl, index)
end

function canCastFuga()
    for key, value in ipairs(storageProfiles.fugaSpells) do
        local isLifesActive = (value.activeCooldown and value.activeCooldown >= now) and (value.enableLifes and value.lifes > 0);
        local isMultipleActive = value.enableMultiple and value.count > 0 ;
        local isNormalActive = value.activeCooldown and value.activeCooldown >= now;
        if (isLifesActive or isNormalActive) then
            return true;
        end
    end
    return false;
end

function getPlayersAttack(multifloor)
    multifloor = multifloor or false;
    local count = 0;
    for _, spec in ipairs(getSpectators(multifloor)) do
        if spec:isPlayer() and spec:isTimedSquareVisible() and table.equals(spec:getTimedSquareColor(), colorToMatch) then
            count = count + 1;
	delay(3500)
        end
    end
    return count;
end

local storageAttackers = {};
local timeClean = 3;

onTextMessage(function(mode, text)
    if text:find('hitpoints due to an attack by') then
        local pattern = 'You lose (%d+) hitpoints due to an attack by (.+)%.'
        local hp, attackerName = text:match(pattern)
        local attackerCreature = getCreatureByName(attackerName)
        if attackerCreature and attackerCreature:isPlayer() then
            local alreadyExists = false
            for _, attackerInfo in ipairs(storageAttackers) do
                if attackerInfo.name == attackerName then
                    alreadyExists = true;
                    attackerInfo.time = os.time();
                    break
                end
            end
            if not alreadyExists then
                table.insert(storageAttackers, {name = attackerName, time = os.time()})
            end
        end
    end
end);

macro(100, function()
    local currentTime = os.time()
    for i = #storageAttackers, 1, -1 do
        local attackerInfo = storageAttackers[i]
        if (currentTime - attackerInfo.time) > timeClean then
            table.remove(storageAttackers, i)
        end
    end
end);

function calculatePercentage(var)
    local multiplier = #storageAttackers;
    return multiplier and var + (multiplier * 7) or var
end

function stopToCast()
    if not fugaIcon.title:isOn() then return false; end
    for index, value in ipairs(storageProfiles.fugaSpells) do
        if value.enabled and value.activeCooldown and value.activeCooldown >= now then return false; end
        if hppercent() <= calculatePercentage(value.selfHealth) + 3 then
            if (not value.totalCooldown or value.totalCooldown <= now) then
                return true;
            end
        end
    end
    return false;
end

function isAnySelectedKeyPressed()
    for index, value in ipairs(storageProfiles.keySpells) do
        if value.enabled and (modules.corelib.g_keyboard.isKeyPressed(value.keyPress)) then
            return true;
        end
    end
    return false;
end

function formatTime(seconds)
    if seconds < 60 then
        return seconds .. 's'
    else
        local minutes = math.floor(seconds / 60)
        local remainingSeconds = seconds % 60
        return string.format("%dm %02ds", minutes, remainingSeconds)
    end
end

formatRemainingTime = function(time)
    local remainingTime = (time - now) / 1000;
    local timeText = '';
    timeText = string.format("%.0f", (time - now) / 1000).. "s";
    return timeText;
end

attachSpellWidgetCallbacks = function(widget, spellId, table)
    widget.onDragEnter = function(self, mousePos)
        if not modules.corelib.g_keyboard.isCtrlPressed() then
            return false
        end
        self:breakAnchors()
        self.movingReference = { x = mousePos.x - self:getX(), y = mousePos.y - self:getY() }
        return true
    end

    widget.onDragMove = function(self, mousePos, moved)
        local parentRect = self:getParent():getRect()
        local newX = math.min(math.max(parentRect.x, mousePos.x - self.movingReference.x), parentRect.x + parentRect.width - self:getWidth())
        local newY = math.min(math.max(parentRect.y - self:getParent():getMarginTop(), mousePos.y - self.movingReference.y), parentRect.y + parentRect.height - self:getHeight())
        self:move(newX, newY)
        if table[spellId] then
            table[spellId].widgetPos = {x = newX, y = newY}
            scriptFuncs.saveProfile(STORAGE_DIRECTORY, storageProfiles)
        end
        return true
    end

    widget.onDragLeave = function(self, pos)
        return true
    end
end

forceSay = function(t)
    if type(t) ~= 'table' then
        for i = 0, 10 do
            stopCombo = now + 250;
            return say(t)
        end
    end
    for i = 0, 10 do
        stopCombo = now + 250;
        return say(t.toSay or t.text)
    end
end


----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
setDefaultTab("Home")

local spellEntry = [[
UIWidget
  background-color: alpha
  text-offset: 18 0
  focusable: true
  height: 16

  CheckBox
    id: enabled
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    width: 15
    height: 15
    margin-top: 2
    margin-left: 3
    image-source: /images/ui/checkbox_round

    $hover !disabled:
      image-color: white
  
    $!checked:
      image-color: #FF4500
  
    $checked:
      image-color: #FF4500
  
    $disabled:
      image-color: #dfdfdf88
      color: #dfdfdf88
      opacity: 0.8
      change-cursor-image: false

  $focus:
    background-color: black
    opacity: 0.4

  CheckBox
    id: showTimespell
    anchors.left: enabled.left
    anchors.verticalCenter: parent.verticalCenter
    width: 15
    height: 15
    margin-top: 2
    margin-left: 15
    image-source: /images/ui/checkbox_round

    $hover !disabled:
      image-color: white
  
    $!checked:
      image-color: #FF4500
  
    $checked:
      image-color: #FF4500
  
    $disabled:
      image-color: #dfdfdf88
      color: #dfdfdf88
      opacity: 0.8
      change-cursor-image: false

  $focus:
    background-color: gray		
    opacity: 0.9


  Label
    id: textToSet
    anchors.left: showTimespell.left
    anchors.verticalCenter: parent.verticalCenter
    margin-left: 20

  Button
    id: remove
    !text: tr('x')
    color: #FF4500
    anchors.right: parent.right
    margin-right: 15
    width: 15
    height: 15
    tooltip: Remove Spell
]]

local spellEntry2 = [[
UIWidget
  background-color: alpha
  text-offset: 18 0
  focusable: true
  height: 16

  CheckBox
    id: enabled
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    width: 15
    height: 15
    margin-top: 2
    margin-left: 3
    image-source: /images/ui/checkbox_round

    $hover !disabled:
      image-color: white
  
    $!checked:
      image-color: #FF4500
  
    $checked:
      image-color: #FF4500
  
    $disabled:
      image-color: #dfdfdf88
      color: #dfdfdf88
      opacity: 0.8
      change-cursor-image: false

  $focus:
    background-color: black
    opacity: 0.4

  Label
    id: textToSet
    anchors.left: enabled.left
    anchors.verticalCenter: parent.verticalCenter
    margin-top: 2
    margin-left: 20

  Button
    id: remove
    !text: tr('X')
    color: #FF4500
    anchors.right: parent.right
    margin-right: 2
    margin-top: 2
    width: 15
    height: 15
    tooltip: Remove Spell
]]

local widgetConfig = [[
UIWidget
  background-color: black
  font: verdana-11px-rounded
  opacity: 0.70
  padding: 0 8
  focusable: true
  phantom: false
  draggable: true
  text-auto-resize: true
]]

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

combobotPanelName = "combobot"
local comboIcon = setupUI([[
Panel
  height: 20
  margin-top: 5
  BotSwitch
    id: title
    anchors.top: parent.top
    anchors.left: parent.left
    text-align: center
    width: 130
    text: COMBO
    font: cipsoftFont

  Button
    id: settings
    anchors.top: prev.top
    anchors.left: prev.right
    anchors.right: parent.right
    margin-left: 3
    height: 17
    text: CONFIG
    font: cipsoftFont
]])
comboIcon:setId(combobotPanelName);

keyIcon = setupUI([[
Panel
  height: 20
  BotSwitch
    id: title
    anchors.top: parent.top
    anchors.left: parent.left
    text-align: center
    width: 130
    text: MANUAL KEYS
    font: cipsoftFont

  Button
    id: settings
    anchors.top: prev.top
    anchors.left: prev.right
    anchors.right: parent.right
    margin-left: 3
    height: 17
    text: CONFIG
    font: cipsoftFont
]])

comboInterface = setupUI([[
MainWindow
  text: Combo Panel
  font: sans-bold-16px
  color: white
  size: 280 400
  opacity: 1.00
  anchors.centerIn: parent

  Panel
    anchors.top: parent.top
    anchors.right: sep2.left
    anchors.left: parent.left
    anchors.bottom: separator.top
    margin: 40 15 10 18
    image-border: 6
    padding: 3
    size: 100 100
    background-color: black
    opacity: 0.75

  Panel
    anchors.top: parent.top
    anchors.left: sep2.left
    anchors.right: parent.right
    anchors.bottom: separator.top
    margin: 40 15 10 18
    image-border: 6
    padding: 3
    size: 10 105
    background-color: black
    opacity: 0.75

  TextList
    opacity: 1.00
    id: spellList
    anchors.left: parent.left
    anchors.top: parent.top
    padding: 1
    size: 240 120  
    margin-top: 3
    margin-left: 5
    vertical-scrollbar: spellListScrollBar
    opacity: 1.00

  VerticalScrollBar
    id: spellListScrollBar
    anchors.top: spellList.top
    anchors.bottom: spellList.bottom
    anchors.right: spellList.right
    step: 10
    pixels-scroll: true
    visible: false
    background-color: white
    opacity: 0.90

  Button
    id: moveUp
    anchors.bottom: parent.bottom
    anchors.horizontalCenter: parent.horizontalCenter
    margin-bottom: 197
    margin-left: 85
    text: /\
    size: 20 20
    font: verdana-11px-rounded

  Button
    id: moveDown
    anchors.bottom: parent.bottom
    anchors.left: moveUp.left
    margin-bottom: 197
    margin-left: 25
    text: \/
    size: 20 20
    font: verdana-11px-rounded
    
  HorizontalSeparator
    id: separator
    anchors.right: parent.right
    anchors.left: parent.left
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: closeButton.top
    margin-bottom: 5
    margin-left: 15
    margin-right: 15

  Label
    id: castSpellLabel
    anchors.left: spellList.left
    anchors.top: spellList.bottom
    text: MAGIA:
    margin-top: 10
    font: cipsoftFont
    color: white

  TextEdit
    id: castSpell
    background-color: black
    anchors.left: spellList.left
    anchors.right: spellList.right
    anchors.top: prev.bottom
    width: 150

  Label
    id: orangeSpellLabel
    anchors.left: prev.left
    anchors.top: prev.bottom
    text: ORANGE SPELL:
    margin-top: 10
    font: cipsoftFont
    color: white

  TextEdit
    id: orangeSpell
    anchors.left: spellList.left
    anchors.right: spellList.right
    anchors.top: prev.bottom
    margin-right: 20
    width: 115

  CheckBox
    id: sameSpell
    anchors.left: orangeSpell.right
    anchors.top: orangeSpell.top
    margin-left: 3
    margin-top: 3

    $hover !disabled:
      image-color: white
  
    $!checked:
      image-color: white
  
    $checked:
      image-color: white
  
    $disabled:
      image-color: #dfdfdf88
      color: #dfdfdf88
      opacity: 0.8
      change-cursor-image: false

  Label
    id: cooldownLabel
    anchors.left: spellList.left
    anchors.right: spellList.right
    anchors.top: prev.bottom
    margin-top: 15
    text: COOLDOWN TOTAL:
    font: cipsoftFont
    color: white

  HorizontalScrollBar
    id: cooldown
    anchors.left: spellList.left
    anchors.right: spellList.right
    anchors.top: prev.bottom
    width: 160
    minimum: 0
    maximum: 60000
    step: 100

  Button
    id: findCD
    anchors.top: cooldownLabel.top
    anchors.right: cooldownLabel.right
    tooltip: Calcular cooldown automatico?
    text: CATCH
    font: cipsoftFont
    margin-top: -3
    color: white
    size: 40 15

  Label
    id: distanceLabel
    anchors.left: spellList.left
    anchors.right: spellList.right
    anchors.top: prev.bottom
    margin-top: 25
    text: DISTANCE:
    color: white
    font: cipsoftFont

  HorizontalScrollBar
    id: distance
    anchors.left: spellList.left
    anchors.right: spellList.right
    anchors.top: distanceLabel.bottom
    width: 160
    minimum: 0
    maximum: 10
    step: 1

  Button
    id: insertSpell
    text: Adicionar
    font: verdana-11px-rounded
    anchors.left: spellList.left
    anchors.right: spellList.right
    anchors.top: prev.bottom
    margin-top: 8

  Button
    id: closeButton
    !text: tr('Close')
    color: white
    font: cipsoftFont
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    size: 50 20
    margin-right: 5
      
]], g_ui.getRootWidget())
comboInterface:hide();

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

fugaIcon = setupUI([[
Panel
  height: 40
  BotSwitch
    id: title
    anchors.top: parent.top
    anchors.left: parent.left
    text-align: center
    width: 130
    text: FUGAS
    font: cipsoftFont

  Button
    id: settings
    anchors.top: prev.top
    anchors.left: prev.right
    anchors.right: parent.right
    margin-left: 3
    height: 17
    text: CONFIG
    font: cipsoftFont

  CheckBox
    id: showInfos
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: prev.bottom
    margin-top: 5
    text: ENEMYS INFO?
    font: cipsoftFont
]])

fugaInterface = setupUI([[
MainWindow
  text: Fuga Panel
  font: sans-bold-16px
  size: 550 322

  Panel
    image-source: /images/ui/panel_flat
    anchors.top: parent.top
    anchors.right: sep2.left
    anchors.left: parent.left
    anchors.bottom: separator.top
    margin: 5 5 5 5
    image-border: 6
    padding: 3
    size: 320 235

  Panel
    image-source: /images/ui/panel_flat
    anchors.top: parent.top
    anchors.left: sep2.left
    anchors.right: parent.right
    anchors.bottom: separator.top
    margin: 5 5 5 5
    image-border: 6
    padding: 3
    size: 320 235


  TextList
    id: spellList
    anchors.left: parent.left
    anchors.top: parent.top
    padding: 1
    size: 240 215
    margin-top: 11
    margin-left: 11
    vertical-scrollbar: spellListScrollBar

  VerticalScrollBar
    id: spellListScrollBar
    anchors.top: spellList.top
    anchors.bottom: spellList.bottom
    anchors.right: spellList.right
    step: 14
    pixels-scroll: true

  Button
    id: moveUp
    anchors.bottom: parent.bottom
    anchors.horizontalCenter: parent.horizontalCenter
    margin-bottom: 40
    margin-left: 50
    text: Move Up
    size: 60 17
    font: cipsoftFont

  Button
    id: moveDown
    anchors.bottom: parent.bottom
    anchors.left: moveUp.left
    margin-bottom: 40
    margin-left: 65
    text: Move Down
    size: 60 17
    font: cipsoftFont

  VerticalSeparator
    id: sep2
    anchors.top: parent.top
    anchors.bottom: closeButton.top
    anchors.horizontalCenter: parent.horizontalCenter
    margin-left: 3
    margin-bottom: 5

  HorizontalSeparator
    id: separator
    anchors.right: parent.right
    anchors.left: parent.left
    anchors.bottom: closeButton.top
    margin-bottom: 5

  Label
    id: castSpellLabel
    anchors.left: castSpell.right
    anchors.top: parent.top
    text: Cast Spell
    margin-top: 19
    margin-left: 15

  TextEdit
    id: castSpell
    anchors.left: spellList.right
    anchors.top: parent.top
    margin-left: 34
    margin-top: 15
    width: 100

  Label
    id: orangeSpellLabel
    anchors.left: orangeSpell.right
    anchors.top: parent.top
    text: Orange Spell
    margin-top: 49
    margin-left: 15

  TextEdit
    id: orangeSpell
    anchors.left: spellList.right
    anchors.top: parent.top
    margin-top: 45
    margin-left: 34
    width: 100

  CheckBox
    id: sameSpell
    anchors.left: orangeSpellLabel.right
    anchors.top: parent.top
    margin-top: 49
    margin-left: 8
    tooltip: Same Spell

  Label
    id: onScreenLabel
    anchors.left: orangeSpell.right
    anchors.top: parent.top
    text: On Screen
    margin-top: 79
    margin-left: 15

  TextEdit
    id: onScreen
    anchors.left: spellList.right
    anchors.top: parent.top
    margin-left: 34
    margin-top: 75
    width: 100

  Label
    id: hppercentLabel
    anchors.left: hppercent.right
    anchors.top: parent.top
    margin-top: 105
    margin-left: 5
    text: Self Health

  HorizontalScrollBar
    id: hppercent
    anchors.left: spellList.right
    margin-left: 20
    anchors.top: parent.top
    margin-top: 105
    width: 125
    minimum: 0
    maximum: 100
    step: 1

  Label
    id: cooldownTotalLabel
    anchors.left: hppercent.right
    anchors.top: parent.top
    margin-top: 135
    margin-left: 5
    text: Total Cooldown

  HorizontalScrollBar
    id: cooldownTotal
    anchors.left: spellList.right
    margin-left: 20
    anchors.top: parent.top
    margin-top: 135
    width: 125
    minimum: 0
    maximum: 180
    step: 1

  Label
    id: cooldownActiveLabel
    anchors.left: hppercent.right
    anchors.top: parent.top
    margin-top: 165
    margin-left: 5
    text: Active Cooldown

  HorizontalScrollBar
    id: cooldownActive
    anchors.left: spellList.right
    margin-left: 20
    anchors.top: parent.top
    margin-top: 165
    width: 125
    minimum: 0
    maximum: 180
    step: 1

  CheckBox
    id: reviveOption
    anchors.bottom: parent.bottom
    anchors.horizontalCenter: parent.horizontalCenter
    !text: tr('Revive')
    tooltip: Revive Fuga
    width: 60
    margin-bottom: 65
    margin-left: 40

  CheckBox
    id: lifesOption
    anchors.bottom: parent.bottom
    anchors.left: reviveOption.right
    tooltip: Lifes Fuga
    width: 60
    !text: tr('Lifes')
    margin-bottom: 65
    margin-left: 10

  CheckBox
    id: multipleOption
    anchors.bottom: parent.bottom
    anchors.left: lifesOption.right
    !text: tr('Multiple')
    tooltip: Multiple Scape
    margin-bottom: 65
    width: 80
    margin-left: 5

  SpinBox
    id: lifesValue
    anchors.bottom: parent.bottom
    anchors.left: lifesOption.right
    margin-bottom: 60
    margin-left: 5
    size: 27 20
    minimum: 0
    maximum: 10
    step: 1
    editable: true
    focusable: true

  Button
    id: insertSpell
    text: Insert Spell
    font: cipsoftFont
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    size: 60 21
    margin-bottom: 40
    margin-right: 20


  Button
    id: closeButton
    !text: tr('Close')
    font: cipsoftFont
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    size: 45 21
    margin-right: 5

]], g_ui.getRootWidget())
fugaInterface:hide();

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


keyInterface = setupUI([[
MainWindow
  text: Keys Panel
  font: sans-bold-16px
  color: white
  size: 300 400

  Panel
    image-source: /images/ui/panel_flat
    anchors.right: parent.right
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.bottom: separator.top
    margin: 5 5 5 5
    image-border: 6
    padding: 3
    size: 320 235

  TextList
    id: spellList
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top
    padding: 1
    size: 240 215  
    margin-top: 11
    vertical-scrollbar: spellListScrollBar

  Label
    id: castSpellLabel
    anchors.right: parent.right
    anchors.bottom: castSpell.top
    text: Spell Name
    margin-bottom: 5
    margin-right: 75

  TextEdit
    id: castSpell
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    margin-bottom: 60
    margin-right: 14
    width: 125

  Label
    id: keyLabel
    anchors.left: parent.left
    anchors.bottom: castSpell.top
    text: Key
    margin-bottom: 5
    margin-left: 15

  TextEdit
    id: key
    anchors.left: parent.left
    anchors.bottom: parent.bottom
    margin-bottom: 60
    margin-left: 14
    width: 70
    editable: false

  VerticalScrollBar
    id: spellListScrollBar
    anchors.top: spellList.top
    anchors.bottom: spellList.bottom
    anchors.right: spellList.right
    step: 14
    pixels-scroll: true

  Button
    id: insertKey
    text: Insert Key
    font: cipsoftFont
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    size: 60 25
    margin-right: 5
    margin-bottom: 5

  HorizontalSeparator
    id: separator
    anchors.right: parent.right
    anchors.left: parent.left
    anchors.bottom: closeButton.top
    margin-bottom: 5

  Button
    id: closeButton
    !text: tr('Close')
    font: cipsoftFont
    anchors.left: parent.left
    anchors.bottom: parent.bottom
    size: 45 25
    margin-left: 4
    margin-bottom: 5
      
]], g_ui.getRootWidget())
keyInterface:hide();

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

comboIcon.title:setOn(isOn.comboMacro);
comboIcon.title.onClick = function(widget)
    isOn.comboMacro = not isOn.comboMacro;
    widget:setOn(isOn.comboMacro);
    scriptFuncs.saveProfile(STORAGE_DIRECTORY, storageProfiles);
end

warning = function() 
  return
end

comboIcon.settings.onClick = function(widget)
    if not comboInterface:isVisible() then
        comboInterface:show();
        comboInterface:raise();
        comboInterface:focus();
    else
        comboInterface:hide();
        scriptFuncs.saveProfile(STORAGE_DIRECTORY, storageProfiles);
    end
end

comboInterface.closeButton.onClick = function(widget)
    comboInterface:hide();
    scriptFuncs.saveProfile(STORAGE_DIRECTORY, storageProfiles);
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

comboInterface.cooldown:setText('0ms')
comboInterface.cooldown.onValueChange = function(widget, value)
    if value >= 1000 then
        widget:setText(value/1000 .. 's')
    else
        widget:setText(value .. 'ms')
    end
end

comboInterface.distance:setText('0')
comboInterface.distance.onValueChange = function(widget, value)
    widget:setText(value)
end


comboInterface.sameSpell:setChecked(true);
comboInterface.orangeSpell:setEnabled(false);
comboInterface.sameSpell.onCheckChange = function(widget, checked)
    if checked then
        comboInterface.orangeSpell:setEnabled(false)
    else
        comboInterface.orangeSpell:setEnabled(true)
        comboInterface.orangeSpell:setText(comboInterface.castSpell:getText())
    end
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

function refreshComboList(list, table)
    if table then
        for i, child in pairs(list.spellList:getChildren()) do
            child:destroy();
        end
        for _, widget in pairs(comboSpellsWidget) do
            widget:destroy()
        end
        for index, entry in ipairs(table) do
            local label = setupUI(spellEntry2, list.spellList)
            local newWidget = setupUI(widgetConfig, g_ui.getRootWidget())
            newWidget:setText(firstLetterUpper(entry.spellCast))
            attachSpellWidgetCallbacks(newWidget, entry.index, storageProfiles.comboSpells)
            if not entry.widgetPos then
                entry.widgetPos = {x = 0, y = 50}
            end
            newWidget:hide()
            comboSpellsWidget[entry.index] = newWidget;
            comboSpellsWidget[entry.index] = newWidget;
            label.onDoubleClick = function(widget)
                local spellTable = entry;
                list.castSpell:setText(spellTable.spellCast);
                list.orangeSpell:setText(spellTable.orangeSpell);
                list.cooldown:setValue(spellTable.cooldown);
                list.distance:setValue(spellTable.distance);
                for i, v in ipairs(storageProfiles.comboSpells) do
                    if v == entry then
                        removeTable(storageProfiles.comboSpells, i)
                    end
                end
                scriptFuncs.reindexTable(table);
                newWidget:destroy();
                label:destroy();
            end
            label.enabled:setChecked(entry.enabled);
            label.enabled:setTooltip(not entry.enabled and 'Enable Spell' or 'Disable Spell');
            label.enabled.onClick = function(widget)
                entry.enabled = not entry.enabled;
                label.enabled:setChecked(entry.enabled);
                label.enabled:setTooltip(not entry.enabled and 'Enable Spell' or 'Disable Spell');
                scriptFuncs.saveProfile(STORAGE_DIRECTORY, storageProfiles);
            end
            label.remove.onClick = function(widget)
                for i, v in ipairs(storageProfiles.comboSpells) do
                    if v == entry then
                        removeTable(storageProfiles.comboSpells, i)
                    end
                end
                scriptFuncs.reindexTable(table);
                newWidget:destroy();
                label:destroy();
            end
            label.onClick = function(widget)
                comboInterface.moveDown:show();
                comboInterface.moveUp:show();
            end
            label.textToSet:setText(firstLetterUpper(entry.spellCast .. ' | CD: ' .. entry.cooldown ..' | DIST: '.. entry.distance ..''));
	    label.textToSet:setColor("white")
	    label.textToSet:setFont("verdana-11px-rounded")
            label:setTooltip('Msg Laranja: ' .. entry.orangeSpell .. '')
        end
    end
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

comboInterface.insertSpell.onClick = function(widget)
  local spellName = comboInterface.castSpell:getText():trim():lower();
  local orangeMsg = comboInterface.orangeSpell:getText():trim():lower();
  orangeMsg = (orangeMsg:len() == 0) and spellName or orangeMsg;
  local cooldown = comboInterface.cooldown:getValue();
  local distance = comboInterface.distance:getValue();
  if (not spellName or spellName:len() == 0) then
      return warn('Invalid Spell Name.');
  end
  if (not comboInterface.sameSpell:isChecked() and comboInterface.orangeSpell:getText():len() == 0) then
      return warn('Invalid Orange Spell.')
  end
  if (cooldown == 0) then
      return warn('Invalid Cooldown.')
  end
  if (distance == 0) then
      return warn('Invalid Distance')
  end
  local newSpell = {
      index = #storageProfiles.comboSpells + 1,
      spellCast = spellName,
      orangeSpell = orangeMsg,
      cooldown = cooldown,
      distance = distance,
      enableTimeSpell = true,
      enabled = true
  }
  table.insert(storageProfiles.comboSpells, newSpell)
  scriptFuncs.saveProfile(STORAGE_DIRECTORY, storageProfiles)
  refreshComboList(comboInterface, storageProfiles.comboSpells)
  comboInterface.castSpell:clearText();
  comboInterface.orangeSpell:clearText();
  comboInterface.sameSpell:setChecked(true);
  comboInterface.orangeSpell:setEnabled(false);
  comboInterface.cooldown:setValue(0);
  comboInterface.distance:setValue(0);
end

refreshComboList(comboInterface, storageProfiles.comboSpells);

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

comboInterface.moveUp.onClick = function()
  local action = comboInterface.spellList:getFocusedChild();
  if (not action) then return; end
  local index = comboInterface.spellList:getChildIndex(action);
  if (index < 2) then return; end
  comboInterface.spellList:moveChildToIndex(action, index - 1);
  comboInterface.spellList:ensureChildVisible(action);
  storageProfiles.comboSpells[index].index = index - 1;
  storageProfiles.comboSpells[index - 1].index = index;
  table.sort(storageProfiles.comboSpells, function(a,b) return a.index < b.index end)
  scriptFuncs.saveProfile(STORAGE_DIRECTORY, storageProfiles);
end

comboInterface.moveDown.onClick = function()
  local action = comboInterface.spellList:getFocusedChild()
  if not action then return end
  local index = comboInterface.spellList:getChildIndex(action)
  if index >= comboInterface.spellList:getChildCount() then return end
  comboInterface.spellList:moveChildToIndex(action, index + 1);
  comboInterface.spellList:ensureChildVisible(action);
  storageProfiles.comboSpells[index].index = index + 1;
  storageProfiles.comboSpells[index + 1].index = index;
  table.sort(storageProfiles.comboSpells, function(a,b) return a.index < b.index end)
  scriptFuncs.saveProfile(STORAGE_DIRECTORY, storageProfiles);
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

comboInterface.findCD.onClick = function(widget)
    detectOrangeSpell, testSpell = true, true;
    spellTime = {0, ''}
end

macro(100, function()
    if testSpell then
        say(comboInterface.castSpell:getText())
    end
end);

onTalk(function(name, level, mode, text, channelId, pos)
    if not detectOrangeSpell then return; end
    if player:getName() ~= name then return; end

    local verifying = comboInterface.orangeSpell:getText():len() > 0 and comboInterface.orangeSpell:getText():lower():trim() or comboInterface.castSpell:getText():lower():trim();

    if text:lower():trim() == verifying then
        if spellTime[2] == verifying then
            comboInterface.cooldown:setValue(now - spellTime[1]);
            spellTime = {now, verifying}
            detectOrangeSpell = false;
            testSpell = false;
        else
            spellTime = {now, verifying}
        end
    end
end);

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

fugaIcon.title:setOn(isOn.fugaMacro);
fugaIcon.title.onClick = function(widget)
    isOn.fugaMacro = not isOn.fugaMacro;
    widget:setOn(isOn.fugaMacro);
    scriptFuncs.saveProfile(STORAGE_DIRECTORY, storageProfiles);
end

fugaIcon.settings.onClick = function(widget)
    if not fugaInterface:isVisible() then
        fugaInterface:show();
        fugaInterface:raise();
        fugaInterface:focus();
    else
        fugaInterface:hide();
        scriptFuncs.saveProfile(STORAGE_DIRECTORY, storageProfiles);
    end
end

fugaInterface.closeButton.onClick = function(widget)
    fugaInterface:hide();
    scriptFuncs.saveProfile(STORAGE_DIRECTORY, storageProfiles);
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

fugaInterface.hppercent:setText('0%')
fugaInterface.hppercent.onValueChange = function(widget, value)
    widget:setText(value .. '%')
end

fugaInterface.cooldownTotal:setText('0s')
fugaInterface.cooldownTotal.onValueChange = function(widget, value)
    local formattedTime = formatTime(value)
    widget:setText(value .. 's')
    --widget:setText(formattedTime)
end

fugaInterface.cooldownActive:setText('0s')
fugaInterface.cooldownActive.onValueChange = function(widget, value)
    local formattedTime = formatTime(value)
    widget:setText(value .. 's')
    --widget:setText(formattedTime)
end


fugaIcon.showInfos:setChecked(isOn.showInfos)
fugaIcon.showInfos.onClick = function(widget)
    isOn.showInfos = not isOn.showInfos
    widget:setChecked(isOn.showInfos)
end

fugaInterface.sameSpell:setChecked(true);
fugaInterface.orangeSpell:setEnabled(false);
fugaInterface.sameSpell.onCheckChange = function(widget, checked)
    if checked then
        fugaInterface.orangeSpell:setEnabled(false)
    else
        fugaInterface.orangeSpell:setEnabled(true)
        fugaInterface.orangeSpell:setText(fugaInterface.castSpell:getText())
    end
end

fugaInterface.lifesValue:hide();
fugaInterface.lifesOption.onCheckChange = function(self, checked)
    if checked then
        fugaInterface.multipleOption:hide();
        fugaInterface.lifesValue:show();
    else
        fugaInterface.multipleOption:show();
        fugaInterface.lifesValue:hide();
    end
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


function refreshFugaList(list, table)
    if table then
        for i, child in pairs(list.spellList:getChildren()) do
            child:destroy();
        end
        for _, widget in pairs(fugaSpellsWidgets) do
            widget:destroy();
        end
        for index, entry in ipairs(table) do
            local label = setupUI(spellEntry, list.spellList)
            local newWidget = setupUI(widgetConfig, g_ui.getRootWidget())
            newWidget:setText(firstLetterUpper(entry.spellCast))
            attachSpellWidgetCallbacks(newWidget, entry.index, storageProfiles.fugaSpells)
  
            if not entry.widgetPos then
                entry.widgetPos = {x = 0, y = 50}
            end
            if entry.enableTimeSpell then
              newWidget:show();
            else
              newWidget:hide();
            end
            newWidget:setPosition(entry.widgetPos)
            fugaSpellsWidgets[entry.index] = newWidget;
            label.onDoubleClick = function(widget)
                local spellTable = entry;
                list.castSpell:setText(spellTable.spellCast);
                list.orangeSpell:setText(spellTable.orangeSpell);
                list.onScreen:setText(spellTable.onScreen);
                list.hppercent:setValue(spellTable.selfHealth);
                list.cooldownTotal:setValue(spellTable.cooldownTotal);
                list.cooldownActive:setValue(spellTable.cooldownActive);
                for i, v in ipairs(storageProfiles.fugaSpells) do
                    if v == entry then
                        removeTable(storageProfiles.fugaSpells, i)
                    end
                end
                scriptFuncs.reindexTable(table);
                newWidget:destroy();
                label:destroy();
            end
            label.enabled:setChecked(entry.enabled);
            label.enabled:setTooltip(not entry.enabled and 'Enable Spell' or 'Disable Spell');
            label.enabled.onClick = function(widget)
                entry.enabled = not entry.enabled;
                label.enabled:setChecked(entry.enabled);
                label.enabled:setTooltip(not entry.enabled and 'Enable Spell' or 'Disable Spell');
                scriptFuncs.saveProfile(STORAGE_DIRECTORY, storageProfiles);
            end
            label.showTimespell:setChecked(entry.enableTimeSpell)
            label.showTimespell:setTooltip(not entry.enableTimeSpell and 'Enable Time Spell' or 'Disable Time Spell');
            label.showTimespell.onClick = function(widget)
                entry.enableTimeSpell = not entry.enableTimeSpell;
                label.showTimespell:setChecked(entry.enableTimeSpell);
                label.showTimespell:setTooltip(not entry.enableTimeSpell and 'Enable Time Spell' or 'Disable Time Spell');
                if entry.enableTimeSpell then
                    newWidget:show();
                else
                    newWidget:hide();
                end
                scriptFuncs.saveProfile(STORAGE_DIRECTORY, storageProfiles);
            end
            label.remove.onClick = function(widget)
                for i, v in ipairs(storageProfiles.fugaSpells) do
                    if v == entry then
                        removeTable(storageProfiles.fugaSpells, i)
                    end
                end
                scriptFuncs.reindexTable(table);
                newWidget:destroy();
                label:destroy();
            end
            label.onClick = function(widget)
                fugaInterface.moveDown:show();
                fugaInterface.moveUp:show();
            end
            label.textToSet:setText(firstLetterUpper(entry.spellCast));
	    label.textToSet:setColor("white")
	    label.textToSet:setFont("verdana-11px-rounded")
            label:setTooltip('Orange Message: ' .. entry.orangeSpell .. ' | On Screen: ' .. entry.onScreen .. ' | Total Cooldown: ' .. entry.cooldownTotal.. 's | Active Cooldown: ' .. entry.cooldownActive .. 's | Hppercent: ' .. entry.selfHealth)
        end
    end
  end
  
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

fugaInterface.moveUp.onClick = function()
  local action = fugaInterface.spellList:getFocusedChild();
  if (not action) then return; end
  local index = fugaInterface.spellList:getChildIndex(action);
  if (index < 2) then return; end
  fugaInterface.spellList:moveChildToIndex(action, index - 1);
  fugaInterface.spellList:ensureChildVisible(action);
  storageProfiles.fugaSpells[index].index = index - 1;
  storageProfiles.fugaSpells[index - 1].index = index;
  table.sort(storageProfiles.fugaSpells, function(a,b) return a.index < b.index end)
  scriptFuncs.saveProfile(STORAGE_DIRECTORY, storageProfiles);
end

fugaInterface.moveDown.onClick = function()
  local action = fugaInterface.spellList:getFocusedChild()
  if not action then return; end
  local index = fugaInterface.spellList:getChildIndex(action)
  if index >= fugaInterface.spellList:getChildCount() then return end
  fugaInterface.spellList:moveChildToIndex(action, index + 1);
  fugaInterface.spellList:ensureChildVisible(action);
  storageProfiles.fugaSpells[index].index = index + 1;
  storageProfiles.fugaSpells[index + 1].index = index;
  table.sort(storageProfiles.fugaSpells, function(a,b) return a.index < b.index end)
  scriptFuncs.saveProfile(STORAGE_DIRECTORY, storageProfiles);
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

fugaInterface.insertSpell.onClick = function(widget)
    local spellName = fugaInterface.castSpell:getText():trim();
    local orangeMsg = fugaInterface.orangeSpell:getText():trim();
    local onScreen = fugaInterface.onScreen:getText();
    orangeMsg = (orangeMsg:len() == 0) and spellName or orangeMsg;
    local hppercent = fugaInterface.hppercent:getValue();
    local cooldownTotal = fugaInterface.cooldownTotal:getValue();
    local cooldownActive = fugaInterface.cooldownActive:getValue();
    
    if spellName:len() == 0 then
        return warn('Invalid Spell Name.');
    end
    if not fugaInterface.sameSpell:isChecked() and orangeMsg:len() == 0 then
        return warn('Invalid Orange Spell.')
    end
    if onScreen:len() == 0 then
        return warn('Invalid Text On Screen')
    end
    if hppercent == 0 then
        return warn('Invalid Hppercent.')
    end
    if cooldownTotal == 0 then
        return warn('Invalid Cooldown Total.')
    end
  
    local spellConfig = {
        index = #storageProfiles.fugaSpells + 1,
        spellCast = spellName,
        orangeSpell = orangeMsg,
        onScreen = onScreen,
        selfHealth = hppercent,
        cooldownActive = cooldownActive,
        cooldownTotal = cooldownTotal,
        enableTimeSpell = true,
        enabled = true
    }
  
    if fugaInterface.lifesOption:isChecked() then
        spellConfig.lifes = 0;
        spellConfig.enableLifes = true;
        if fugaInterface.lifesValue:getValue() == 0 then
          return warn('Invalid Life Value.')
        end
        spellConfig.amountLifes = fugaInterface.lifesValue:getValue();
    end
    if fugaInterface.reviveOption:isChecked() then
        spellConfig.enableRevive = true;
        spellConfig.alreadyChecked = false;
    end
    if fugaInterface.multipleOption:isChecked() then
        spellConfig.enableMultiple = true; 
        spellConfig.count = 3;
    end
    table.insert(storageProfiles.fugaSpells, spellConfig)
    refreshFugaList(fugaInterface, storageProfiles.fugaSpells)
    scriptFuncs.saveProfile(STORAGE_DIRECTORY, storageProfiles)
  
    fugaInterface.castSpell:clearText()
    fugaInterface.orangeSpell:clearText()
    fugaInterface.onScreen:clearText()
    fugaInterface.cooldownTotal:setValue(0)
    fugaInterface.cooldownActive:setValue(0)
    fugaInterface.hppercent:setValue(0)
    fugaInterface.reviveOption:setChecked(false);
    fugaInterface.lifesOption:setChecked(false);
    fugaInterface.multipleOption:setChecked(false);
    fugaInterface.multipleOption:show();
    fugaInterface.lifesValue:hide();
  end
  
  refreshFugaList(fugaInterface, storageProfiles.fugaSpells);

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

storage.widgetPos = storage.widgetPos or {};
informationWidget = {};

local widgetNames = {
  'showText',
}

for i, widgetName in ipairs(widgetNames) do
    informationWidget[widgetName] = setupUI(widgetConfig, g_ui.getRootWidget())
end

local function attachSpellWidgetCallbacks(key)
  informationWidget[key].onDragEnter = function(widget, mousePos)
      if not modules.corelib.g_keyboard.isCtrlPressed() then
        return false
      end
      widget:breakAnchors()
      widget.movingReference = { x = mousePos.x - widget:getX(), y = mousePos.y - widget:getY() }
      return true
  end

  informationWidget[key].onDragMove = function(widget, mousePos, moved)
      local parentRect = widget:getParent():getRect()
      local x = math.min(math.max(parentRect.x, mousePos.x - widget.movingReference.x), parentRect.x + parentRect.width - widget:getWidth())
      local y = math.min(math.max(parentRect.y - widget:getParent():getMarginTop(), mousePos.y - widget.movingReference.y), parentRect.y + parentRect.height - widget:getHeight())        
      widget:move(x, y)
      return true
  end

  informationWidget[key].onDragLeave = function(widget, pos)
    storage.widgetPos[key] = {}
    storage.widgetPos[key].x = widget:getX();
    storage.widgetPos[key].y = widget:getY();
    return true
  end
end

for key, value in pairs(informationWidget) do
  attachSpellWidgetCallbacks(key)
  informationWidget[key]:setPosition(
      storage.widgetPos[key] or {0, 50}
  )
end

local toShow = informationWidget['showText'];

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

macro(100, function()
  if isOn.showInfos then
      for _, value in ipairs(storageProfiles.fugaSpells) do
          if value.selfHealth then
              toShow:show()
              toShow:setText('INIMIGOS: ' .. getPlayersAttack(false) .. ' | PERCENT: ' .. calculatePercentage(value.selfHealth) .. '%')
              return;
          end
      end
  else
      toShow:hide();
  end
end);
 
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
macro(100, function()
    if not (fugaSpellsWidgets and storageProfiles.fugaSpells) then return; end
    
    for index, spellConfig in ipairs(storageProfiles.fugaSpells) do
        local widget = fugaSpellsWidgets[spellConfig.index];
        if widget then
            local textToSet = firstLetterUpper(spellConfig.onScreen)
            local color = 'green'
            if spellConfig.activeCooldown and spellConfig.activeCooldown > now then
                textToSet = textToSet .. ': ' .. formatRemainingTime(spellConfig.activeCooldown)
                color = '#00FFFF'
                if spellConfig.enableLifes and spellConfig.lifes == 0 then
                    spellConfig.activeCooldown = nil;
                end
            elseif spellConfig.totalCooldown and spellConfig.totalCooldown > now then
                textToSet = textToSet .. ': ' .. formatRemainingTime(spellConfig.totalCooldown)
                color = '#FF4040'
            else
                textToSet = textToSet .. ': 0s'
                if spellConfig.enableMultiple and spellConfig.canReset then
                    spellConfig.count = 3;
                    spellConfig.canReset = false;
                end
                if spellConfig.enableLifes then
                    spellConfig.lifes = 0;
                end
                if spellConfig.enableRevive then
                    spellConfig.alreadyChecked = false;
                end
            end
            if spellConfig.enableMultiple and spellConfig.count > 0 then
                textToSet = '' .. spellConfig.count .. ' | ' .. textToSet
            end
            if spellConfig.enableLifes and spellConfig.lifes > 0 then
                textToSet = '' .. spellConfig.lifes .. ' | ' .. textToSet
            end
            widget:setText(textToSet)
            widget:setColor(color)
        end
    end
end);



----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

keyIcon.title:setOn(isOn.keyMacro);
keyIcon.title.onClick = function(widget)
    isOn.keyMacro = not isOn.keyMacro;
    widget:setOn(isOn.keyMacro);
    scriptFuncs.saveProfile(STORAGE_DIRECTORY, storageProfiles);
end

keyIcon.settings.onClick = function(widget)
    if not keyInterface:isVisible() then
        keyInterface:show();
        keyInterface:raise();
        keyInterface:focus();
    else
        keyInterface:hide();
        scriptFuncs.saveProfile(STORAGE_DIRECTORY, storageProfiles);
    end
end

keyInterface.closeButton.onClick = function(widget)
    keyInterface:hide();
    scriptFuncs.saveProfile(STORAGE_DIRECTORY, storageProfiles);
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

keyInterface.key.onHoverChange = function(widget, hovered)
  if hovered then
      x = true;
      onKeyPress(function(key)
          if not x then return; end
          widget:setText(key)
      end)
  else
      x = false;
  end
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

function refreshKeyList(list, table)
  if table then
      for i, child in pairs(list.spellList:getChildren()) do
          child:destroy();
      end
      for index, entry in ipairs(table) do
          local label = setupUI(spellEntry, list.spellList)
          label.showTimespell:hide();
          label.onDoubleClick = function(widget)
              local spellTable = entry;
              list.key:setText(spellTable.keyPress);
              list.castSpell:setText(spellTable.spellCast);
              for i, v in ipairs(storageProfiles.keySpells) do
                  if v == entry then
                      removeTable(storageProfiles.keySpells, i)
                  end
              end
              scriptFuncs.reindexTable(table);
              label:destroy();
          end
          label.enabled:setChecked(entry.enabled);
          label.enabled:setTooltip(not entry.enabled and 'Enable Spell' or 'Disable Spell');
          label.enabled.onClick = function(widget)
              entry.enabled = not entry.enabled;
              label.enabled:setChecked(entry.enabled);
              label.enabled:setTooltip(not entry.enabled and 'Enable Spell' or 'Disable Spell');
              scriptFuncs.saveProfile(STORAGE_DIRECTORY, storageProfiles);
          end
          label.remove.onClick = function(widget)
              for i, v in ipairs(storageProfiles.keySpells) do
                  if v == entry then
                      removeTable(storageProfiles.keySpells, i)
                  end
              end
              scriptFuncs.reindexTable(storageProfiles.keySpells);
              label:destroy();
          end
          label.textToSet:setText(firstLetterUpper(entry.spellCast) .. ' | Key: ' .. entry.keyPress);
      end
  end
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

keyInterface.insertKey.onClick = function(widget)
  local keyPressed = keyInterface.key:getText();
  local spellName = keyInterface.castSpell:getText():lower():trim();

  if not keyPressed or keyPressed:len() == 0 then
      return warn('Invalid Key.')
  end
  for _, config in ipairs(storageProfiles.keySpells) do
    if config.keyPress == keyPressed then
      return warn('Key Already Added.')
    end
  end
  table.insert(storageProfiles.keySpells, {
      index = #storageProfiles.keySpells+1,
      spellCast = spellName,
      keyPress = keyPressed,
      enabled = true
  });
  refreshKeyList(keyInterface, storageProfiles.keySpells)
  scriptFuncs.saveProfile(STORAGE_DIRECTORY, storageProfiles);
  keyInterface.key:clearText();
  keyInterface.castSpell:clearText();
end

refreshKeyList(keyInterface, storageProfiles.keySpells);

macro(storage.scrollBars1.macroDelay, function()
    if (not comboIcon.title:isOn()) then return; end
    if stopCombo and stopCombo >= now then return; end
    if stopToCast() or isAnySelectedKeyPressed() or not g_game.isAttacking() then return; end
    local playerPos = player:getPosition();
    local target = g_game.getAttackingCreature();
    local targetPos = target:getPosition();
    if not targetPos then return; end
    local targetDistance = getDistanceBetween(playerPos, targetPos);
    for index, value in ipairs(storageProfiles.comboSpells) do
        if value.enabled and targetDistance <= value.distance then
            if (not value.cooldownSpells or value.cooldownSpells <= now) then
                say(value.spellCast)
            end
        end
    end
end);

local selfPlayer = g_game.getLocalPlayer();
macro(1, function()
    if not fugaIcon.title:isOn() then return; end
    if isInPz() then return; end
    local selfHealth = selfPlayer:getHealthPercent();
    for key, value in ipairs(storageProfiles.fugaSpells) do
        if value.enabled and selfHealth <= calculatePercentage(value.selfHealth) then
            if (not value.totalCooldown or value.totalCooldown <= now) then
                if not canCastFuga() then
			  stopCombo = now + 250;
                    forceSay(value.spellCast);
                end
            end
        end
    end
end);

macro(1, function()
if not g_mouse.isPressed(7) then return; end
    if not fugaIcon.title:isOn() then return; end
    for key, value in ipairs(storageProfiles.fugaSpells) do
       if value.enabled and (g_mouse.isPressed(7))then
            if (not value.totalCooldown or value.totalCooldown <= now) then
                if not canCastFuga() then
		    stopCombo = now + 250;
                    return forceSay(value.spellCast);
        end
            end
        end
    end
end)

macro(storage.scrollBars1.macroDelay, function()
  if not keyIcon.title:isOn() then return; end
  if modules.game_console:isChatEnabled() then return; end
  for index, value in ipairs(storageProfiles.keySpells) do
      if value.enabled and (modules.corelib.g_keyboard.areKeysPressed(value.keyPress)) then
	stopCombo = now + 250;
          say(value.spellCast)
      end
  end
end);

onTalk(function(name, level, mode, text, channelId, pos)
    text = text:lower();
    if name ~= player:getName() then return; end
    if text == 'Bijuu Yaiba' then
        yaibaSlow = os.time() + 15
    end
    for index, value in ipairs(storageProfiles.comboSpells) do
        if text == value.orangeSpell then
            value.cooldownSpells = now + value.cooldown;
        end
    end
    for index, value in ipairs(storageProfiles.fugaSpells) do
        if text == value.orangeSpell then
            if value.enableLifes then
                value.activeCooldown = now + (value.cooldownActive * 1000) - 250;
                value.totalCooldown = now + (value.cooldownTotal * 1000) - 250;
                value.lifes = value.amountLifes;
            end
            if value.enableRevive and not value.alreadyChecked then
                value.totalCooldown = now + (value.cooldownTotal * 1000) - 250;
                value.activeCooldown = now + (value.cooldownActive * 1000) - 250;
                value.alreadyChecked = true;
            end
            if value.enableMultiple then
                if value.count > 0 then
                    value.count = value.count - 1
                    value.activeCooldown = now + (value.cooldownActive * 1000) - 250
                    if value.count == 0 then
                        value.totalCooldown = now + (value.cooldownTotal * 1000) - 250
                        value.canReset = true;
                        break;
                    end
                end
            end
            if not (value.enableLifes or value.enableRevive or value.enableMultiple) then
                value.activeCooldown = now + (value.cooldownActive * 1000) - 250;
                value.totalCooldown = now + (value.cooldownTotal * 1000) - 250;
                warn(text)
                break
            end
        end
    end
end);

onTextMessage(function(mode, text)
    for key, value in ipairs(storageProfiles.fugaSpells) do
        if value.enableLifes then
            if text:lower():find('morreu e renasceu') and value.activeCooldown and value.activeCooldown >= now then
                value.lifes = value.lifes - 1;
            end
        end
    end
end);

onPlayerPositionChange(function(newPos, oldPos)
    local izanagiPos = { x = 1214, y = 686, z = 6 };
    for key, value in ipairs(storageProfiles.fugaSpells) do
        if value.enableRevive and value.spellCast == 'izanagi' then
            if newPos.x == izanagiPos.x and newPos.y == izanagiPos.y and newPos.z == izanagiPos.z then
                value.activeCooldown = nil;
                value.alreadyChecked = true;
            end
        end
    end
end);

UI.Separator()

-- ======================================================
-- BUG MAP + AUTO TURN COM ÍCONE FLUTUANTE
-- ======================================================

storage.autoBugMapEnabled = storage.autoBugMapEnabled or false
storage.botIconPositions = storage.botIconPositions or {}

-- ------------------------------------------------------
-- 1. ÍCONE FLUTUANTE (TOGGLE BUG MAP)
-- ------------------------------------------------------
local bugMapIcon = addIcon("iconBugMap", {
  text = "Bug Map",
  switchable = false,
  moveable = true
}, function()
  storage.autoBugMapEnabled = not storage.autoBugMapEnabled
end)

bugMapIcon:setSize({width = 80, height = 40})
bugMapIcon.text:setFont("verdana-11px-rounded")
bugMapIcon:setOpacity(1.0)

bugMapIcon.onMouseRelease = function(widget, mousePos, button)
  if modules.corelib.g_keyboard.isCtrlPressed() then
    storage.botIconPositions.iconBugMap = {
      x = widget:getX(),
      y = widget:getY()
    }
  end
  return true
end

-- Restaura / Define posição do Ícone
schedule(10, function()
  if storage.botIconPositions.iconBugMap then
    bugMapIcon:setPosition(storage.botIconPositions.iconBugMap)
  else
    bugMapIcon:setPosition({x = 420, y = 310})
  end
end)

-- Atualiza visual do Ícone (ON/OFF)
macro(200, function()
  if storage.autoBugMapEnabled then
    bugMapIcon.text:setColoredText({"Bug Map\n", "white", "ON", "green"})
  else
    bugMapIcon.text:setColoredText({"Bug Map\n", "white", "OFF", "red"})
  end
end)

-- ------------------------------------------------------
-- 2. FUNÇÕES AUXILIARES
-- ------------------------------------------------------
function Keys(x)
  return modules.corelib.g_keyboard.isKeyPressed(x)
end

function getClosest(table)
  local closest
  if table and table[1] then
    for v, x in pairs(table) do
      if not closest or getDistanceBetween(closest:getPosition(), player:getPosition()) > getDistanceBetween(x:getPosition(), player:getPosition()) then
        closest = x
      end
    end
  end
  if closest then
    return getDistanceBetween(closest:getPosition(), player:getPosition())
  else
    return false
  end
end

function hasNonWalkable(direc)
  local tabela = {}
  for i = 1, #direc do
    local tile = g_map.getTile({
      x = player:getPosition().x + direc[i][1], 
      y = player:getPosition().y + direc[i][2], 
      z = player:getPosition().z
    })
    if tile and (not tile:isWalkable() or tile:getTopThing():getName():len() > 0) and tile:canShoot() then
      table.insert(tabela, tile)
    end
  end
  return tabela
end

function getClosestBetween(x, y)
  if x or y then
    if x and not y then
      return 1
    elseif y and not x then
      return 2
    end
  else
    return false
  end
  if x < y then
    return 1
  else
    return 2
  end
end

function getDash(dir)
  local dirs
  local tiles = {}
  if not dir then
    return false
  elseif dir == 'n' then
    dirs = {{0, -1}, {0, -2}, {0, -3}, {0, -4}, {0, -5}, {0, -6}, {0, -7}, {0, -8}}
  elseif dir == 's' then
    dirs = {{0, 1}, {0, 2}, {0, 3}, {0, 4}, {0, 5}, {0, 6}, {0, 7}, {0, 8}}
  elseif dir == 'w' then
    dirs = {{-1, 0}, {-2, 0}, {-3, 0}, {-4, 0}, {-5, 0}, {-6, 0}}
  elseif dir == 'e' then
    dirs = {{1, 0}, {2, 0}, {3, 0}, {4, 0}, {5, 0}, {6, 0}}
  end

  for i = 1, #dirs do
    local tile = g_map.getTile({
      x = player:getPosition().x + dirs[i][1], 
      y = player:getPosition().y + dirs[i][2], 
      z = player:getPosition().z
    })
    if tile and Stairs and Stairs.checkTile(tile) and tile:canShoot() then
      table.insert(tiles, tile)
    end
  end

  if not tiles[1] or getClosestBetween(getClosest(hasNonWalkable(dirs)), getClosest(tiles)) == 1 then
    return false
  else
    return true
  end
end

function checkPos(x, y)
  local xyz = g_game.getLocalPlayer():getPosition()
  xyz.x = xyz.x + x
  xyz.y = xyz.y + y
  local tile = g_map.getTile(xyz)
  if tile then
    return g_game.use(tile:getTopUseThing())   
  else
    return false
  end
end

-- ------------------------------------------------------
-- 3. CHECKBOX "USE DIAGONAL"
-- ------------------------------------------------------
local bugMap = {}

bugMap.checkBox = setupUI([[
CheckBox
  id: checkBox
  font: cipsoftFont
  text: Use Diagonal
]])

bugMap.checkBox.onCheckChange = function(widget, checked)
  storage.bugMapCheck = checked
end

if storage.bugMapCheck == nil then
  storage.bugMapCheck = true
end

bugMap.checkBox:setChecked(storage.bugMapCheck)
bugMap.isKeyPressed = modules.corelib.g_keyboard.isKeyPressed

bugMap.directions = {
  ["W"] = {x = 0, y = -5, direction = 0},
  ["E"] = {x = 3, y = -3},
  ["D"] = {x = 5, y = 0, direction = 1},
  ["C"] = {x = 3, y = 3},
  ["S"] = {x = 0, y = 5, direction = 2},
  ["Z"] = {x = -3, y = 3},
  ["A"] = {x = -5, y = 0, direction = 3},
  ["Q"] = {x = -3, y = -3}
}

-- ------------------------------------------------------
-- 4. MACROS DE AÇÃO
-- ------------------------------------------------------

-- Turn Rápido (WASD)
macro(1, function()
  if not storage.autoBugMapEnabled then return end
  local playerDir = player:getDirection()

  if bugMap.isKeyPressed('w') and playerDir ~= 0 then
    return turn(0)
  elseif bugMap.isKeyPressed('d') and playerDir ~= 1 then
    return turn(1)
  elseif bugMap.isKeyPressed('s') and playerDir ~= 2 then
    return turn(2)
  elseif bugMap.isKeyPressed('a') and playerDir ~= 3 then
    return turn(3)
  end
end)

-- Macro Bug Map
bugMap.macro = macro(1, function()
  if not storage.autoBugMapEnabled then return end
  if (modules.game_console:isChatEnabled() or modules.corelib.g_keyboard.isCtrlPressed()) then return end

  local pPos = pos()
  for key, config in pairs(bugMap.directions) do
    if bugMap.isKeyPressed(key) then
      if storage.bugMapCheck or config.direction then
        if config.direction then
          turn(config.direction)
        end
        local tile = g_map.getTile({x = pPos.x + config.x, y = pPos.y + config.y, z = pPos.z})
        if tile then
          return g_game.use(tile:getTopUseThing())
        end
      end
    end
  end
end)

-- ======================================================
-- MACRO ATACAR SEGUINDO COM ÍCONE FLUTUANTE
-- ======================================================

storage.autoChaseEnabled = storage.autoChaseEnabled or false
storage.botIconPositions = storage.botIconPositions or {}

-- ------------------------------------------------------
-- 1. ÍCONE FLUTUANTE
-- ------------------------------------------------------
local chaseIcon = addIcon("iconAutoChase", {
  text = "Atacar\nSeguindo",
  switchable = false,
  moveable = true
}, function()
  storage.autoChaseEnabled = not storage.autoChaseEnabled
end)

chaseIcon:setSize({width = 90, height = 40})
chaseIcon.text:setFont("verdana-11px-rounded")
chaseIcon:setOpacity(1.0)

-- Salvar Posição do Ícone (Ctrl + Arrastar)
chaseIcon.onMouseRelease = function(widget, mousePos, button)
  if modules.corelib.g_keyboard.isCtrlPressed() then
    storage.botIconPositions.iconAutoChase = {
      x = widget:getX(),
      y = widget:getY()
    }
  end
  return true
end

-- Posicionamento Inicial / Salvo
schedule(10, function()
  if storage.botIconPositions.iconAutoChase then
    chaseIcon:setPosition(storage.botIconPositions.iconAutoChase)
  else
    chaseIcon:setPosition({x = 320, y = 310})
  end
end)

-- Atualiza Visual do Ícone (ON / OFF)
macro(200, function()
  if storage.autoChaseEnabled then
    chaseIcon.text:setColoredText({"Atacar Seguindo\n", "white", "ON", "green"})
  else
    chaseIcon.text:setColoredText({"Atacar Seguindo\n", "white", "OFF", "red"})
  end
end)

-- ------------------------------------------------------
-- 2. MACRO ATACAR SEGUINDO (HOTKEY SHIFT+R + LÓGICA)
-- ------------------------------------------------------
macro(250, "Atacar Seguindo", "Shift+R", function()
  if storage.autoChaseEnabled then
    if g_game.isOnline() and g_game.isAttacking() then
      g_game.setChaseMode(1)
    end
  end
end)

-- ============================================================
-- PROJETO: COMBO DE ÁREA (PAINEL + ÍCONE FLUTUANTE ON/OFF)
-- ============================================================

-- Inicialização das variáveis de armazenamento
storage.areaCombo = storage.areaCombo or "Chidori Nagashi"
storage.areaCombo2 = storage.areaCombo2 or "Kirin"
storage.areaComboEnabled = storage.areaComboEnabled or false
storage.botIconPositions = storage.botIconPositions or {}

-- ============================================================
-- 1) PAINEL / JANELA DE CONFIGURAÇÃO (UI)
-- ============================================================
areaConfigUI = setupUI([[
MainWindow
  id: areaComboWindow
  text: Configurar Combo Area
  size: 320 230
  draggable: true
  moveable: true
  background-color: #121212
  font: verdana-11px-rounded
  padding: 16

  Label
    id: labelArea1
    text: Nome do 1º Jutsu em Area:
    anchors.top: parent.top
    anchors.left: parent.left
    margin-top: 28
    margin-left: 5
    color: #00e6b8

  TextEdit
    id: areaField1
    text: ""
    anchors.top: labelArea1.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 6
    margin-left: 5
    margin-right: 5
    height: 24

  Label
    id: labelArea2
    text: Nome do 2º Jutsu em Area:
    anchors.top: areaField1.bottom
    anchors.left: parent.left
    margin-top: 14
    margin-left: 5
    color: #00e6b8

  TextEdit
    id: areaField2
    text: ""
    anchors.top: labelArea2.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 6
    margin-left: 5
    margin-right: 5
    height: 24

  HorizontalSeparator
    id: sepBottom
    anchors.bottom: closeBtn.top
    anchors.left: parent.left
    anchors.right: parent.right
    margin-bottom: 12

  Button
    id: closeBtn
    text: Concluir
    anchors.bottom: parent.bottom
    anchors.right: parent.right
    margin-right: 5
    width: 90
    height: 24
]], g_ui.getRootWidget())

areaConfigUI:hide()

-- Carrega os textos salvos no armazenamento
areaConfigUI.areaField1:setText(storage.areaCombo)
areaConfigUI.areaField2:setText(storage.areaCombo2)

-- Atualização automática ao digitar
areaConfigUI.areaField1.onTextChange = function(widget, text)
  storage.areaCombo = text:trim()
end

areaConfigUI.areaField2.onTextChange = function(widget, text)
  storage.areaCombo2 = text:trim()
end

areaConfigUI.closeBtn.onClick = function()
  areaConfigUI:hide()
end

-- Botão no painel do bot para abrir as configurações
UI.Separator()
local configBtn = UI.Button("Config Combo Area", function()
  if areaConfigUI:isVisible() then
    areaConfigUI:hide()
  else
    areaConfigUI:show()
    areaConfigUI:raise()
    areaConfigUI:focus()
  end
end)
configBtn:setColor("#00e6b8")
UI.Separator()

-- ============================================================
-- 2) ÍCONE FLUTUANTE (CONTROLE ON/OFF)
-- ============================================================
local areaIcon = addIcon("iconComboAreaPanel", {
  text = "Combo Area",
  switchable = false,
  moveable = true
}, function()
  storage.areaComboEnabled = not storage.areaComboEnabled
end)

areaIcon:setSize({width = 90, height = 40})
areaIcon.text:setFont("verdana-11px-rounded")
areaIcon:setOpacity(1.0)

areaIcon.onMousePress = function(widget, mousePos, button)
  return true
end

areaIcon.onMouseRelease = function(widget, mousePos, button)
  if modules.corelib.g_keyboard.isCtrlPressed() then
    storage.botIconPositions.iconComboAreaPanel = {
      x = widget:getX(),
      y = widget:getY()
    }
  end
  return true
end

schedule(10, function()
  local saved = storage.botIconPositions.iconComboAreaPanel
  if saved then
    areaIcon:setPosition(saved)
  else
    areaIcon:setPosition({x = 520, y = 360})
  end
end)

macro(200, function()
  if storage.areaComboEnabled then
    areaIcon.text:setColoredText({
      "Combo Area\n", "white",
      "ON", "green"
    })
  else
    areaIcon.text:setColoredText({
      "Combo Area\n", "white",
      "OFF", "red"
    })
  end
end)

-- ============================================================
-- 3) MACRO EXECUTORA
-- ============================================================
macro(500, function()
  if not storage.areaComboEnabled then return end
  if not g_game.isAttacking() then return end

  if storage.areaCombo and #storage.areaCombo > 0 then
    say(storage.areaCombo)
  end

  if storage.areaCombo2 and #storage.areaCombo2 > 0 then
    say(storage.areaCombo2)
  end
end)

-- ============================================================
-- PROJETO: BUFFS FULL (PAINEL + ÍCONE FLUTUANTE ON/OFF)
-- ============================================================

-- Inicialização das variáveis de armazenamento
storage.buff1 = storage.buff1 or "Funyu no Jutsu"
storage.buff2 = storage.buff2 or "kekkei genkai"
storage.buff3 = storage.buff3 or "chakra shield"
storage.buffsFullEnabled = storage.buffsFullEnabled or false
storage.botIconPositions = storage.botIconPositions or {}

-- ============================================================
-- 1) PAINEL / JANELA DE CONFIGURAÇÃO (UI)
-- ============================================================
buffsConfigUI = setupUI([[
MainWindow
  id: buffsConfigWindow
  text: Configurar Buffs Full
  size: 320 280
  draggable: true
  moveable: true
  background-color: #121212
  font: verdana-11px-rounded
  padding: 16

  Label
    id: labelBuff1
    text: Buff Principal:
    anchors.top: parent.top
    anchors.left: parent.left
    margin-top: 28
    margin-left: 5
    color: #00e6b8

  TextEdit
    id: buffField1
    text: ""
    anchors.top: labelBuff1.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 6
    margin-left: 5
    margin-right: 5
    height: 24

  Label
    id: labelBuff2
    text: Buff Secundario:
    anchors.top: buffField1.bottom
    anchors.left: parent.left
    margin-top: 10
    margin-left: 5
    color: #00e6b8

  TextEdit
    id: buffField2
    text: ""
    anchors.top: labelBuff2.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 6
    margin-left: 5
    margin-right: 5
    height: 24

  Label
    id: labelBuff3
    text: Buff Terciario:
    anchors.top: buffField2.bottom
    anchors.left: parent.left
    margin-top: 10
    margin-left: 5
    color: #00e6b8

  TextEdit
    id: buffField3
    text: ""
    anchors.top: labelBuff3.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 6
    margin-left: 5
    margin-right: 5
    height: 24

  HorizontalSeparator
    id: sepBottom
    anchors.bottom: closeBtn.top
    anchors.left: parent.left
    anchors.right: parent.right
    margin-bottom: 12

  Button
    id: closeBtn
    text: Concluir
    anchors.bottom: parent.bottom
    anchors.right: parent.right
    margin-right: 5
    width: 90
    height: 24
]], g_ui.getRootWidget())

buffsConfigUI:hide()

-- Carrega os textos salvos no armazenamento
buffsConfigUI.buffField1:setText(storage.buff1)
buffsConfigUI.buffField2:setText(storage.buff2)
buffsConfigUI.buffField3:setText(storage.buff3)

-- Atualização automática ao digitar
buffsConfigUI.buffField1.onTextChange = function(widget, text)
  storage.buff1 = text:trim()
end

buffsConfigUI.buffField2.onTextChange = function(widget, text)
  storage.buff2 = text:trim()
end

buffsConfigUI.buffField3.onTextChange = function(widget, text)
  storage.buff3 = text:trim()
end

buffsConfigUI.closeBtn.onClick = function()
  buffsConfigUI:hide()
end

-- Botão no painel do bot para abrir as configurações
UI.Separator()
local configBuffsBtn = UI.Button("Config Buffs Full", function()
  if buffsConfigUI:isVisible() then
    buffsConfigUI:hide()
  else
    buffsConfigUI:show()
    buffsConfigUI:raise()
    buffsConfigUI:focus()
  end
end)
configBuffsBtn:setColor("#00e6b8")
UI.Separator()

-- ============================================================
-- 2) ÍCONE FLUTUANTE (CONTROLE ON/OFF)
-- ============================================================
local buffsIcon = addIcon("iconBuffsFullPanel", {
  text = "Buffs Full",
  switchable = false,
  moveable = true
}, function()
  storage.buffsFullEnabled = not storage.buffsFullEnabled
end)

buffsIcon:setSize({width = 90, height = 40})
buffsIcon.text:setFont("verdana-11px-rounded")
buffsIcon:setOpacity(1.0)

buffsIcon.onMousePress = function(widget, mousePos, button)
  return true
end

buffsIcon.onMouseRelease = function(widget, mousePos, button)
  if modules.corelib.g_keyboard.isCtrlPressed() then
    storage.botIconPositions.iconBuffsFullPanel = {
      x = widget:getX(),
      y = widget:getY()
    }
  end
  return true
end

schedule(10, function()
  local saved = storage.botIconPositions.iconBuffsFullPanel
  if saved then
    buffsIcon:setPosition(saved)
  else
    buffsIcon:setPosition({x = 520, y = 260})
  end
end)

macro(200, function()
  if storage.buffsFullEnabled then
    buffsIcon.text:setColoredText({
      "Buffs Full\n", "white",
      "ON", "green"
    })
  else
    buffsIcon.text:setColoredText({
      "Buffs Full\n", "white",
      "OFF", "red"
    })
  end
end)

-- ============================================================
-- 3) MACRO EXECUTORA
-- ============================================================
macro(1000, function()
  if not storage.buffsFullEnabled then return end

  if storage.buff1 and storage.buff1:len() > 0 then
    say(storage.buff1)
    delay(1000)
  end

  if storage.buff2 and storage.buff2:len() > 0 then
    say(storage.buff2)
    delay(1500)
  end

  if storage.buff3 and storage.buff3:len() > 0 then
    say(storage.buff3)
    delay(1500)
  end
end)

UI.Separator()

macro(1000, "Abrir Bag Principal", function()
    bpItem = getBack()
    bp = getContainer(0)

    if not bp and bpItem ~= nil then
        g_game.open(bpItem)
    end

end)

-- ============================================================
-- SCRIPT: JUTSU SELAR BIJUU (COM ÍCONE FLUTUANTE ON/OFF)
-- ============================================================

storage.botIconPositions = storage.botIconPositions or {}

UI.Label("--Jutsu Selar Bijuu--"):setColor('#EBDAA2')

local config = { 
  [1] = {20, "Fuinjutsu"},
}
local exhausted = 200

-- 1) Macro Principal
local selarBijuuMacro = macro(100, "Jutsu Selar Bijuu", function()
  if not g_game.isAttacking() then return end
  local c = g_game.getAttackingCreature()
  if not c then return end

  local hp = c:getHealthPercent()
  for e, entry in ipairs(config) do
    if hp <= entry[1] then
      say(entry[2])
      delay(exhausted)
      return
    end
  end
end)

-- ============================================================
-- 2) ÍCONE FLUTUANTE (DRAG & DROP COM CTRL + STATUS ON/OFF)
-- ============================================================
local selarBijuuIcon = addIcon("iconSelarBijuu", {
  text = "Selar Bijuu",
  switchable = false,
  moveable = true
}, function()
  if selarBijuuMacro.isOn() then
    selarBijuuMacro.setOff()
  else
    selarBijuuMacro.setOn()
  end
end)

selarBijuuIcon:setSize({width = 90, height = 40})
selarBijuuIcon.text:setFont("verdana-11px-rounded")
selarBijuuIcon:setOpacity(1.0)

-- Eventos para salvar a posição com Ctrl + Arrastar
selarBijuuIcon.onMousePress = function(widget, mousePos, button)
  return true
end

selarBijuuIcon.onMouseRelease = function(widget, mousePos, button)
  if modules.corelib.g_keyboard.isCtrlPressed() then
    storage.botIconPositions.iconSelarBijuu = {
      x = widget:getX(),
      y = widget:getY()
    }
  end
  return true
end

-- Restaura a posição salva do ícone na tela
schedule(10, function()
  local saved = storage.botIconPositions.iconSelarBijuu
  if saved then
    selarBijuuIcon:setPosition(saved)
  else
    selarBijuuIcon:setPosition({x = 520, y = 210}) -- Posição padrão
  end
end)

-- Atualização visual em tempo real (ON / OFF)
macro(200, function()
  if selarBijuuMacro.isOn() then
    selarBijuuIcon.text:setColoredText({
      "Selar Bijuu\n", "white",
      "ON", "green"
    })
  else
    selarBijuuIcon.text:setColoredText({
      "Selar Bijuu\n", "white",
      "OFF", "red"
    })
  end
end)

UI.Separator()

local jumpBySave = {};


jumpBySave.extraJumpDirections = {
	['W'] = {x = 0, y = -1, dir = 0},
	['D'] = {x = 1, y = 0, dir = 1},
	['S'] = {x = 0, y = 1, dir = 2},
	['A'] = {x = -1, y = 0, dir = 3}
}

local arrowXkey = {
	["W"] = "Up",
	["S"] = "Down",
	["D"] = "Right",
	["A"] = "Left"
};

for KEY, ARROW in pairs(arrowXkey) do
	jumpBySave.extraJumpDirections[ARROW] = table.copy(jumpBySave.extraJumpDirections[KEY]);
end

jumpBySave.standingTime = now;

onPlayerPositionChange(function(newPos, oldPos)
	jumpBySave.standingTime = now
end)

jumpBySave.standTime = function()
	return now - jumpBySave.standingTime;
end

local isMobile = modules._G.g_app.isMobile();
if (isMobile) then
	local keypad = g_ui.getRootWidget():recursiveGetChildById("keypad");
	jumpBySave.pointer = keypad.pointer;

	local North = {
		highest = {x = -16, y = 29},
		lowest = {x = -75, y = -30},
		info = {
			dir = 0,
			x = 0,
			y = -1
		};
	};
	local East = {
		highest = {x = 29, y = 75},
		lowest = {x = -30, y = 15},
		info = {
			dir = 1,
			x = 1,
			y = 0
		};
	};
	local South = {
		highest = {x = 75, y = 29},
		lowest = {x = 16, y = -30},
		info = {
			dir = 2,
			x = 0,
			y = 1
		};
	};
	local West = {
		highest = {x = 29, y = -15},
		lowest = {x = -30, y = -75},
		info = {
			dir = 3,
			x = -1,
			y = 0
		};
	}
	jumpBySave.DIRS = {North, East, South, West};
end

jumpBySave.getPressedKeys = function()
	local wasdWalking = modules.game_walking.wsadWalking;
	
	if (isMobile) then
		local marginTop, marginLeft = jumpBySave.pointer:getMarginTop(), jumpBySave.pointer:getMarginLeft();
		for index, value in ipairs(jumpBySave.DIRS) do
			if (
				(marginTop >= value.lowest.x and marginTop <= value.highest.x) and
				(marginLeft >= value.lowest.y and marginLeft <= value.highest.y)
			) then
				return value.info;
			end
		end
	else
		for walkKey, value in pairs(jumpBySave.extraJumpDirections) do
			if (modules.corelib.g_keyboard.isKeyPressed(walkKey)) then
				-- local tbl = pressedKeys[value.wasdWalking and 'wordKey' or 'arrowKey'];
				-- info(walkKey);
				if (#walkKey > 1 or wasdWalking) then
					return value;
				end
			end
		end
	end
end

macro(100, "Automatic Jump", function()
	if (stopCombo and stopCombo - 100 >= now) then return; end
	if (player:isWalking() or jumpBySave.standTime() <= 100) then return; end
	local values = jumpBySave.getPressedKeys();
	if (not values) then return; end
	local pos = pos();
	
	turn(values.dir);
	pos.x = pos.x + values.x;
	pos.y = pos.y + values.y;
	local tile = g_map.getTile(pos);
	say(tile and tile:isFullGround() and "Jump up" or "Jump Down");
end)

storage.jumps = storage.jumps or {};

local config = storage.jumps;

jumpBySave.posToString = function(pos)
	return pos.x .. ',' .. pos.y .. ',' .. pos.z;
end

if (#config > 0) then
	for index, value in ipairs(config) do
		config[jumpBySave.posToString(value)] = {
			direction = value.direction,
			jumpTo = value.jumpTo
		};
		config[index] = nil;
	end
end

onPlayerPositionChange(function(newPos, oldPos)
	jumpBySave.lastWalkPos = oldPos;
	jumpBySave.actualWalkPos = newPos;
	jumpBySave.isWalking = nil;
end)

function Creature:setAndClear(text, delay)
	self:setText(text);
	delay = delay or 100;
	local time = now + delay;
	self.time = time;
	schedule(delay, function()
		if (self.time ~= time) then return; end
		self:clearText();
	end)
end

onTalk(function(name, level, mode, text)
	if (not storage.jumps.savePositions) then return; end
	if (name ~= player:getName()) then return; end
	if (mode ~= 44) then return; end
	if (not jumpBySave.actualWalkPos or not jumpBySave.lastWalkPos) then return; end
	if (jumpBySave.actualWalkPos.z == jumpBySave.lastWalkPos.z) then return; end
	if text:lower():find('jump') then
		local lastWalkPos = jumpBySave.posToString(jumpBySave.lastWalkPos);
		if (not storage.jumps[lastWalkPos]) then
			text = text:gsub('"', "");
			text = text:gsub(":", "");
			saveJump = text:trim();
			config[lastWalkPos] = {
				direction = jumpBySave.correctDirection(),
				jumpTo = saveJump
			};
			player:setAndClear(lastWalkPos .. '\n Saved as: ' .. saveJump);
		end
	end
end)

jumpBySave.correctDirection = function()

	local dir = player:getDirection();
	
	if (dir <= 3) then
		return dir;
	end
	
	return dir < 6 and 1 or 3;
end

jumpBySave.getDistance = function(p1, p2)

    local distx = math.abs(p1.x - p2.x);
    local disty = math.abs(p1.y - p2.y);

    return math.sqrt(distx * distx + disty * disty);
end
	
	
jumpBySave.findNearestJump = function()
	local playerPos = pos();
	local nearest = {};
	
	if (jumpBySave.tile) then
		jumpBySave.tile:setText("");
		jumpBySave.tile = nil;
	end
	
	for stringPos, value in pairs(config) do
		
		local splitPos = stringPos:split(',');
		if (#splitPos == 3) then
			local tilePos = {
				x = tonumber(splitPos[1]),
				y = tonumber(splitPos[2]),
				z = tonumber(splitPos[3])
			};
			if (tilePos.z == playerPos.z) then
				local distance = jumpBySave.getDistance(tilePos, playerPos);
				if (not nearest.distance or distance < nearest.distance) then
					local tile = g_map.getTile(tilePos);
					if (tile and tile:isWalkable() and tile:isPathable()) then
						if (findPath(playerPos, tilePos)) then
							nearest = {
								tile = tile,
								distance = distance,
								direction = value.direction,
								jumpTo = value.jumpTo;
							};
						end
					end
				end
				
			end
		end
	end
	
	return nearest;
end

local qqcoisa = UI.TextEdit(storage.kunaiId or "", function(widget, text)
    storage.kunaiId = text
end)
qqcoisa:setFont("verdana-11px-rounded")
qqcoisa:setColor("white")
qqcoisa:setTooltip("Para utilizar o sunshin jump e escada, preencha com o ID da Kunai. Caso contrario deixe vazio.")



local JUMPKEY = UI.TextEdit(storage.autojumper or "coloque a tecla para ativar", function(widget, text)    
    storage.autojumper = text
end)
JUMPKEY:setFont("verdana-11px-rounded")
JUMPKEY:setColor("white")
JUMPKEY:setTooltip("Preencha com o atalho que deseja para utilizar o auto-jump")




isKeyPressed = modules.corelib.g_keyboard.isKeyPressed;
jumpBySave.executeMacro = macro(200, "Jump Marcacao", function()
	if (jumpBySave.isWalking) then return; end
	local jumpInfo = jumpBySave.findNearestJump();
	if (not isKeyPressed(not isMobile and storage.autojumper)) then
		if (jumpInfo.tile) then
			jumpBySave.tile = jumpInfo.tile;
			jumpInfo.tile:setText(jumpInfo.jumpTo, "red");
		end
		local pos = jumpBySave.posToString(pos());
		if (isKeyPressed("Delete")) then
			if (storage.jumps[pos]) then
				player:setAndClear(pos .. '\n Removed.');
				storage.jumps[pos] = nil;
			end
		end
	elseif (jumpInfo.tile) then
		local tilePos = jumpInfo.tile:getPosition();
		if (tilePos) then
			jumpBySave.tile = jumpInfo.tile;
			jumpBySave.tile:setText(jumpInfo.jumpTo, "green");
			local distanceFromTile = getDistanceBetween(tilePos, pos());
			
			if (distanceFromTile == 0) then
				g_game.turn(jumpInfo.direction);
				say(jumpInfo.jumpTo);
				-- if (jumpBySave.correctDirection() == jumpInfo.direction) then
				-- else
				-- end
			elseif (distanceFromTile == 1) then
				autoWalk(tilePos, 1);
				jumpBySave.isWalking = true;
			else
				jumpBySave.doWalk(tilePos);
			end
		end
	else
		player:setAndClear("No jump nearby.");
	end
end)

error = function(msg)
	return modules.game_bot.message("error", msg);
end


jumpBySave.nextPosition = {
    {x = 0, y = -1},
    {x = 1, y = 0},
    {x = 0, y = 1},
    {x = -1, y = 0},
    {x = 1, y = -1},
    {x = 1, y = 1},
    {x = -1, y = 1},
    {x = -1, y = -1}
}

jumpBySave.getNextDirection = function(pos, dir)
	local offSet = jumpBySave.nextPosition[dir + 1];
	
	pos.x = pos.x + offSet.x;
	pos.y = pos.y + offSet.y;
	
	return pos;
end


jumpBySave.doWalk = function(pos)
	local playerPos = player:getPosition();
	local path = findPath(playerPos, pos);
	
	if (not path) then return; end
	
	local kunaiThing;
	for index, dir in ipairs(path) do
		if (index > 10) then break; end
		
		playerPos = jumpBySave.getNextDirection(playerPos, dir);
		local tmpTile = g_map.getTile(playerPos);
		if (tmpTile and tmpTile:isWalkable(true) and tmpTile:isPathable() and tmpTile:canShoot()) then
			kunaiThing = tmpTile:getTopThing();
		end
	end
	local tile = g_map.getTile(playerPos);
	
	if (tile) then
		
		local topThing = tile:getTopThing();
		local distance = getDistanceBetween(playerPos, player:getPosition());
		if (distance > 1 and storage.kunaiId and kunaiThing) then
			g_game.stop();
			useWith(tonumber(storage.kunaiId), kunaiThing);
		end
		if (not topThing) then return; end
		use(topThing);
	end
end

local checkBox = setupUI([[
CheckBox
  id: checkBox
  font: cipsoftFont
  text: Save Positions
]]);

checkBox.onCheckChange = function(widget, checked)
	storage.jumps.savePositions = checked;
end

if (storage.jumps.savePositions == nil) then
	storage.jumps.savePositions = true;
end

checkBox:setChecked(storage.jumps.savePositions);

addIcon("jumpIcon", {item = 3001, text = "Jump"}, jumpBySave.executeMacro);

timeEnemy = {};
enemy_data = {spells={}};
storage._enemy = storage._enemy or {};
local dir = "/bot/storage";
local path = dir .. "/" .. g_game.getWorldName() .. ".json";

if not g_resources.directoryExists(dir) then
    g_resources.makeDir(dir);
end

timeEnemy.save = function()
    local status, result = pcall(json.encode, enemy_data, 4);
    if status then
        local success = g_resources.writeFileContents(path, result);
        if success then
        end
    end
end

timeEnemy.load = function()
    local data = enemy_data;
    if modules._G.g_resources.fileExists(path) then
        local content = modules._G.g_resources.readFileContents(path);
        local status, result = pcall(json.decode, content);
        if status then
            data = result;
        else
            warn("Erro ao decodificar o arquivo JSON: " .. result);
        end
    else
        timeEnemy.save();
    end
    enemy_data = data;
end

local spellEntryTimeSpell = [[
UIWidget
  background-color: alpha
  text-offset: 18 0
  focusable: true
  height: 16

  CheckBox
    id: enabled
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    width: 15
    height: 15
    margin-top: 2
    margin-left: 3

  Label
    id: text
    anchors.left: parent.left
    margin-left: 25
    margin-top: 5
    font: terminus-14px-bold

  $focus:
    background-color: #00000055

  Button
    id: remove
    !text: tr('X')
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    margin-right: 15
    margin-top: 2
    width: 15
    height: 15
    tooltip: Remove
]];

local timer_add = [[
Label
  text-auto-resize: true
  font: verdana-11px-rounded
  color: orange
  margin-bottom: 5
  text-offset: 3 1
]];

timeEnemy.buttons = setupUI([[
Panel
  height: 90
  BotSwitch
    id: title
    anchors.top: parent.top
    anchors.left: parent.left
    text-align: center
    width: 130
    !text: tr('Time Spell Enemy')

  Button
    id: settings
    anchors.top: prev.top
    anchors.left: prev.right
    anchors.right: parent.right
    margin-left: 3
    height: 17
    text: Setup

  CheckBox
    id: target
    anchors.top: settings.bottom
    anchors.left: parent.left
    margin-top: 3
    margin-left: 5
    text: Targets
    width: 68
    tooltip: Time Spell Targets
    checked: false

  CheckBox
    id: enemy
    anchors.top: target.bottom
    anchors.left: parent.left
    margin-top: 3
    margin-left: 5
    text: Enemies
    width: 68
    tooltip: Time Spell Enemies
    checked: false

  CheckBox
    id: guild
    anchors.top: enemy.bottom
    anchors.left: parent.left
    margin-top: 3
    margin-left: 5
    text: Guilds
    width: 68
    tooltip: Time Spell Guilds
    checked: false

]]);

timeEnemy.widget = setupUI([[
UIWindow
  size: 240 300
  background-color: black
  opacity: 0.55
  border: 2 orange
  anchors.right: parent.right
  anchors.top: parent.top
  margin-right: 300
  margin-top: 150

  Label
    id: title
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top
    text-align: center
    font: sans-bold-16px
    margin-top: 15
    color: orange
    text: Time Spell Enemy

  ScrollablePanel
    id: enemyList
    layout:
      type: verticalBox
    anchors.fill: parent
    margin-top: 35
    margin-left: 10
    margin-right: 10
    margin-bottom: 30

  ResizeBorder
    id: bottomResizeBorder
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    enabled: true

  ResizeBorder
    id: rightResizeBorder
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    enabled: true
]], g_ui.getRootWidget());

timeEnemy.interface = setupUI([[
MainWindow
  !text: tr('Time Spell Enemy Interface')
  font: sans-bold-16px
  color: white
  size: 450 315

  Panel
    id: leftPanel
    image-source: /images/ui/panel_flat
    anchors.horizontalCenter: spellList.horizontalCenter
    anchors.verticalCenter: spellList.verticalCenter
    image-border: 6
    padding: 3
    size: 210 210

  TextList
    id: spellList
    anchors.left: parent.left
    anchors.top: parent.top
    padding: 1
    size: 200 200  
    margin-top: 10
    margin-left: 10
    vertical-scrollbar: spellListScrollbar

  VerticalScrollBar
    id: spellListScrollbar
    anchors.top: spellList.top
    anchors.bottom: spellList.bottom
    anchors.right: spellList.right
    step: 14
    pixels-scroll: true

  VerticalSeparator
    id: sep
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: leftPanel.top
    anchors.bottom: separator.top
    margin-bottom: 8
    margin-left: 15

  Panel
    id: rightPanel
    image-source: /images/ui/panel_flat
    anchors.verticalCenter: spellList.verticalCenter
    anchors.right: parent.right
    anchors.left: sep.right
    image-border: 6
    padding: 3
    size: 210 210
    margin-left: 7
    margin-right: 5

  Label
    id: spellNameLabel
    anchors.horizontalCenter: rightPanel.horizontalCenter
    anchors.top: parent.top
    margin-top: 15
    text: Spell Name

  TextEdit
    id: spellName
    anchors.horizontalCenter: rightPanel.horizontalCenter
    anchors.top: spellNameLabel.bottom
    margin-top: 5
    width: 100

  Label
    id: onScreenLabel
    anchors.horizontalCenter: rightPanel.horizontalCenter
    anchors.top: spellName.bottom
    margin-top: 5
    text: On Screen

  TextEdit
    id: onScreen
    anchors.horizontalCenter: rightPanel.horizontalCenter
    anchors.top: onScreenLabel.bottom
    margin-top: 5
    width: 100

  Label
    id: cooldownTotalLabel
    anchors.horizontalCenter: rightPanel.horizontalCenter
    anchors.top: onScreen.bottom
    text: Cooldown Total
    margin-top: 5

  HorizontalScrollBar
    id: cooldownTotal
    anchors.horizontalCenter: rightPanel.horizontalCenter
    anchors.top: cooldownTotalLabel.bottom
    margin-top: 5
    width: 125
    minimum: 0
    maximum: 200
    step: 1

  Label
    id: cooldownAtivoLabel
    anchors.horizontalCenter: rightPanel.horizontalCenter
    anchors.top: cooldownTotal.bottom
    text: Cooldown Ativo
    margin-top: 5

  HorizontalScrollBar
    id: cooldownAtivo
    anchors.horizontalCenter: rightPanel.horizontalCenter
    anchors.top: cooldownAtivoLabel.bottom
    margin-top: 5
    width: 125
    minimum: 0
    maximum: 360
    step: 1

  Button
    id: addButton
    anchors.horizontalCenter: rightPanel.horizontalCenter
    anchors.top: cooldownAtivo.bottom
    margin-top: 10
    text: Adicionar
    image-color: #dfdfdf

  Label
    id: warnText
    anchors.left: worldSettings.right
    anchors.bottom: parent.bottom
    margin-bottom: 10
    margin-left: 10
    color: yellow
    width: 200


  HorizontalSeparator
    id: separator
    anchors.right: parent.right
    anchors.left: parent.left
    anchors.bottom: closeButton.top
    margin-bottom: 5   
    margin-left: 5
    margin-right: 5

  ComboBox
    id: worldSettings
    anchors.left: parent.left
    anchors.bottom: parent.bottom
    width: 150
    margin-bottom: 5
    margin-left: 5

  Button
    id: closeButton
    !text: tr('Close')
    font: cipsoftFont
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    size: 50 21
    margin-bottom: 5
    margin-right: 5

]], g_ui.getRootWidget());
timeEnemy.interface:hide();

local function hide_logic()
    if not timeEnemy.interface:isVisible() then
        timeEnemy.interface:show();
    else
        timeEnemy.interface:hide();
        timeEnemy.save();
    end
end

local button_add_color = function(bool)
    local color = (bool and "green") or "red";
    timeEnemy.interface.addButton:setImageColor(color);
    schedule(2000, function()
        timeEnemy.interface.addButton:setImageColor("#dfdfdf");
    end);
end

local warning_text = function(text)
    local widget = timeEnemy.interface.warnText;
    widget:setVisible(true);
    widget:setText(text);
    schedule(2000, function()
        widget:setText("");
        widget:setVisible(false);
    end);
end

timeEnemy.interface.closeButton.onClick = hide_logic;
timeEnemy.buttons.settings.onClick = hide_logic;
timeEnemy.buttons.title.onClick = function(widget)
    enemy_data.enabled = not enemy_data.enabled;
    widget:setOn(enemy_data.enabled);
    timeEnemy.widget:setVisible(enemy_data.enabled);
    timeEnemy.save();
end

timeEnemy.clear = function()
    timeEnemy.interface.spellName:setTooltip("Mensagem laranja que sobe ao usar a spell.");
    timeEnemy.interface.onScreen:setTooltip("O que vai aparecer no time spell.");
    timeEnemy.interface.spellName:setText("");
    timeEnemy.interface.onScreen:setText("");
    timeEnemy.interface.cooldownAtivo:setText("0seg");
    timeEnemy.interface.cooldownTotal:setText("0seg");
end

timeEnemy.addOption = function()
    local worldName = g_game.getWorldName();
    timeEnemy.interface.worldSettings:addOption(worldName);
    timeEnemy.interface.worldSettings:setOption(worldName);
end

timeEnemy.checkBoxes = function()
    timeEnemy.buttons.target:setChecked(enemy_data.target or false);
    timeEnemy.buttons.enemy:setChecked(enemy_data.enemy or false);
    timeEnemy.buttons.guild:setChecked(enemy_data.guild or false);
end

timeEnemy.onLoading = function()
    timeEnemy.load();
    timeEnemy.checkBoxes();
    timeEnemy.clear();
    timeEnemy.addOption();
    timeEnemy.refreshList();
    timeEnemy.buttons.title:setOn(enemy_data.enabled or false);
    timeEnemy.widget:setVisible(enemy_data.show_panel or false);
    timeEnemy.widget:setVisible(enemy_data.enabled or false);
end

timeEnemy.refreshList = function()
    for i, child in pairs(timeEnemy.interface.spellList:getChildren()) do
        child:destroy();
    end
    for index, entry in ipairs(enemy_data.spells) do
        local label = setupUI(spellEntryTimeSpell, timeEnemy.interface.spellList);
        label.remove.onClick = function(widget)
            table.remove(enemy_data.spells, index);
            timeEnemy.save();
            timeEnemy.refreshList();
        end;
        label.enabled:setChecked(entry.enabled);
        label.enabled.onClick = function(widget)
            entry.enabled = not entry.enabled;
            label.enabled:setChecked(entry.enabled);
            timeEnemy.save();
        end;
        label.onDoubleClick = function(widget)
            timeEnemy.interface.spellName:setText(entry.spellName);
            timeEnemy.interface.onScreen:setText(entry.onScreen);
            timeEnemy.interface.cooldownAtivo:setValue(entry.cooldownActive);
            timeEnemy.interface.cooldownTotal:setValue(entry.cooldownTotal);
            table.remove(enemy_data.spells, index);
            timeEnemy.save();
            timeEnemy.refreshList();
        end;
        label.text:setText(entry.spellName);
        label:setTooltip("On Screen: " .. entry.onScreen .. " | CD Ativo: " .. entry.cooldownActive .. " | CD Total: " .. entry.cooldownTotal);
    end
end

timeEnemy.doCheckCreature = function(name)
    if (name == player:getName():lower()) then
        return false;
    end
    if (enemy_data.target and g_game.isAttacking() and (g_game.getAttackingCreature():getName() == name)) then
        return true;
    end
    if enemy_data.enemy then
        local findCreature = getCreatureByName(name);
        if not findCreature then
            return false;
        end
        if (findCreature:getEmblem() ~= 1) then
            return true;
        end
    end
    if enemy_data.guild then
        local findCreature = getCreatureByName(name);
        if not findCreature then
            return false;
        end
        if ((findCreature:getEmblem() ~= 1) or findCreature:isPartyMember()) then
            return true;
        end
    end
    return false;
end

timeEnemy.interface.cooldownAtivo.onValueChange = function(widget, value)
    widget:setText(value .. "seg");
    if (value > 60) then
        widget:setTooltip(string.format("%.1fmin", value / 60));
    else
        widget:setTooltip("");
    end
end

timeEnemy.interface.cooldownTotal.onValueChange = function(widget, value)
    widget:setText(value .. "seg");
    if (value > 60) then
        widget:setTooltip(string.format("%.1fmin", value / 60));
    else
        widget:setTooltip("");
    end
end

timeEnemy.buttons.target.onCheckChange = function(widget, checked)
    enemy_data.target = checked;
    timeEnemy.save();
end

timeEnemy.buttons.enemy.onCheckChange = function(widget, checked)
    enemy_data.enemy = checked;
    timeEnemy.save();
end

timeEnemy.buttons.guild.onCheckChange = function(widget, checked)
    enemy_data.guild = checked;
    timeEnemy.save();
end

timeEnemy.interface.addButton.onClick = function()
    local timeWidget = timeEnemy.interface;
    local spellName = timeWidget.spellName:getText():lower():trim();
    local onScreen = timeWidget.onScreen:getText();
    local cooldownAtivo = timeWidget.cooldownAtivo:getValue();
    local cooldownTotal = timeWidget.cooldownTotal:getValue();
    if (not spellName or (spellName:len() == 0)) then
        button_add_color(false);
        warning_text("Spell Name Invalida.");
        return;
    end
    if (not onScreen or (onScreen:len() == 0)) then
        button_add_color(false);
        warning_text("On Screen Invalida.");
        return;
    end
    if (not cooldownAtivo or (cooldownAtivo == 0)) then
        button_add_color(false);
        warning_text("Cooldown Ativo Invalido.");
        return;
    end
    if (not cooldownTotal or (cooldownTotal == 0)) then
        button_add_color(false);
        warning_text("Cooldown Total Invalido.");
        return;
    end
    table.insert(enemy_data.spells, {enabled=true,spellName=spellName,onScreen=onScreen,cooldownActive=cooldownAtivo,cooldownTotal=cooldownTotal});
    button_add_color(true);
    warning_text("Spell Inserida com Sucesso.");
    timeEnemy.save();
    timeEnemy.clear();
    timeEnemy.refreshList();
end

macro(100, function()
    for _, child in pairs(timeEnemy.widget.enemyList:getChildren()) do
        child:destroy();
    end
    for index = #storage._enemy, 1, -1 do
        local entry = storage._enemy[index];
        if (entry.totalCooldown <= os.time()) then
            table.remove(storage._enemy, index);
        else
            local label = setupUI(timer_add, timeEnemy.widget.enemyList);
            if (entry.activeCooldown >= os.time()) then
                label:setColoredText({entry.playerName,"white",":    ","white",(entry.onScreen),"orange","    [ CD: ","orange",(entry.activeCooldown - os.time()),"orange"," ]","orange"});
            else
                label:setColoredText({entry.playerName,"white",":    ","white",(entry.onScreen),"orange","    [ CD: ","red",(entry.totalCooldown - os.time()),"red"," ]","red"});
            end
        end
    end
end);

onTalk(function(name, level, mode, text, channelId, pos)
    if not timeEnemy.doCheckCreature(name) then
        return;
    end
    text = text:lower():trim();
    for _, entry in ipairs(enemy_data.spells) do
        if (entry.spellName == text) then
            local activeCooldown = os.time() + entry.cooldownActive;
            local totalCooldown = os.time() + entry.cooldownTotal;
            table.insert(storage._enemy, {playerName=name,onScreen=entry.onScreen,activeCooldown=activeCooldown,totalCooldown=totalCooldown});
        end
    end
end);

timeEnemy.onLoading();

-- =========================================================
-- Ícones para CaveBot e TargetBot com movimento e status
-- =========================================================

storage.botIconPositions = storage.botIconPositions or {}

local function newBotIcon(id, label, pos, toggleFunction)
  local btn = addIcon(id, {text = label, switchable = false, moveable = true}, toggleFunction)
  btn:setSize({width = 80, height = 40}) -- altura maior para duas linhas
  btn.text:setFont('verdana-11px-rounded')
  btn:setOpacity(1.0)

  -- Previne clique atravessar
  btn.onMousePress = function(widget, mousePos, button)
    return true
  end

  btn.onMouseRelease = function(widget, mousePos, button)
    if modules.corelib.g_keyboard.isCtrlPressed() then
      storage.botIconPositions[id] = {x = widget:getX(), y = widget:getY()}
    end
    return true
  end

  local saved = storage.botIconPositions[id]
  if saved then
    schedule(10, function() btn:setPosition(saved) end)
  else
    schedule(10, function() btn:setPosition(pos) end)
  end

  return btn
end

local caveIcon = newBotIcon("iconCave", "Cavebot", {x = 620, y = 210}, function()
  CaveBot.setOn(not CaveBot.isOn())
end)

local targetIcon = newBotIcon("iconTarget", "Target", {x = 620, y = 260}, function()
  TargetBot.setOn(not TargetBot.isOn())
end)

macro(200, function()
  if CaveBot.isOn() then
    caveIcon.text:setColoredText({"Cavebot\n", "white", "ON", "green"})
  else
    caveIcon.text:setColoredText({"Cavebot\n", "white", "OFF", "red"})
  end

  if TargetBot.isOn() then
    targetIcon.text:setColoredText({"Target\n", "white", "ON", "green"})
  else
    targetIcon.text:setColoredText({"Target\n", "white", "OFF", "red"})
  end
end)


-- ============================================================
-- ÍCONE FLUTUANTE PARA O COMBO (ON / OFF + CTRL + ARRASTAR)
-- ============================================================

storage.botIconPositions = storage.botIconPositions or {}

local comboFloatingIcon = addIcon("iconComboMacroScript", {
  text = "Combo",
  switchable = false,
  moveable = true
}, function()
  -- Alterna o estado do combo no painel e na variável global
  local newState = not comboIcon.title:isOn()
  comboIcon.title:setOn(newState)
  storage['iconScripts'].comboMacro = newState
  scriptFuncs.saveProfile(STORAGE_DIRECTORY, storageProfiles)
end)

comboFloatingIcon:setSize({width = 90, height = 40})
comboFloatingIcon.text:setFont("verdana-11px-rounded")
comboFloatingIcon:setOpacity(1.0)

comboFloatingIcon.onMousePress = function(widget, mousePos, button)
  return true
end

-- Salvar posição ao arrastar com Ctrl pressionado
comboFloatingIcon.onMouseRelease = function(widget, mousePos, button)
  if modules.corelib.g_keyboard.isCtrlPressed() then
    storage.botIconPositions.iconComboMacroScript = {
      x = widget:getX(),
      y = widget:getY()
    }
  end
  return true
end

-- Restaura ou define a posição inicial do ícone
schedule(10, function()
  local saved = storage.botIconPositions.iconComboMacroScript
  if saved then
    comboFloatingIcon:setPosition(saved)
  else
    comboFloatingIcon:setPosition({x = 620, y = 310}) -- Posição inicial na tela
  end
end)

-- Macro para atualização em tempo real do texto ON / OFF e cores
macro(200, function()
  if comboIcon.title:isOn() then
    comboFloatingIcon.text:setColoredText({
      "Combo\n", "white",
      "ON", "green"
    })
  else
    comboFloatingIcon.text:setColoredText({
      "Combo\n", "white",
      "OFF", "red"
    })
  end
end)
