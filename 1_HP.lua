setDefaultTab("User")

-- ============================================================
-- SEÇÃO DE CURA (HEAL)
-- ============================================================
local lblHeal = UI.Label("-- [[ HEAL ]] --")
lblHeal:setColor("#00e6b8")
addSeparator()

if Panels and Panels.Health then
  Panels.Health()
end

addSeparator() 

-- ============================================================
-- SEÇÃO DE FUGA (FUGAS)
-- ============================================================
local lblFuga = UI.Label("-- [[ FUGA ]] --")
lblFuga:setColor("#00e6b8")
addSeparator()

-- Inicialização das Storages
if type(storage.healing1) ~= "table" then
  storage.healing1 = {on = false, title = "Fuga 1", text = "fuga", min = 0, max = 80}
end
if type(storage.healing2) ~= "table" then
  storage.healing2 = {on = false, title = "Fuga 2", text = "fuga", min = 0, max = 70}
end
if type(storage.healing3) ~= "table" then
  storage.healing3 = {on = false, title = "Fuga 3", text = "fuga", min = 0, max = 50}
end
if type(storage.healing4) ~= "table" then
  storage.healing4 = {on = false, title = "Fuga 4", text = "fuga", min = 0, max = 30}
end
if type(storage.healing5) ~= "table" then
  storage.healing5 = {on = false, title = "Fuga 5", text = "fuga", min = 0, max = 15}
end

local fugasStorages = {
  storage.healing1,
  storage.healing2,
  storage.healing3,
  storage.healing4,
  storage.healing5
}

-- Macro de Execução
for _, hInfo in ipairs(fugasStorages) do
  macro(100, function()
    if hInfo.on then
      local hp = player:getHealthPercent()
      if hp <= hInfo.max and hp >= hInfo.min then
        say(hInfo.text)
      end
    end
  end)
end

-- ============================================================
-- PAINEL ESPAÇOSO, MODERN & CLEAN (LARGURA 480PX)
-- ============================================================
fugasConfigUI = setupUI([[
MainWindow
  id: fugasConfigWindow
  text: Configuraçoes de Fugas
  size: 480 430
  draggable: true
  moveable: true
  opacity: 0.90
  background-color: #0b0e14
  border: 1 #1f293d
  font: verdana-11px-rounded
  padding: 16

  Label
    id: windowHeader
    text: Painel de Controle de Fugas
    anchors.top: parent.top
    anchors.horizontalCenter: parent.horizontalCenter
    margin-top: 22
    color: #00e6b8
    font: verdana-11px-rounded

  HorizontalSeparator
    id: topSep
    anchors.top: windowHeader.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 8

  ScrollablePanel
    id: contentPanel
    anchors.top: topSep.bottom
    anchors.left: parent.left
    anchors.right: fugasScrollBar.left
    anchors.bottom: closeBtn.top
    margin-top: 10
    margin-bottom: 12
    margin-right: 6
    vertical-scrollbar: fugasScrollBar
    layout:
      type: verticalBox
      spacing: 10

  VerticalScrollBar
    id: fugasScrollBar
    anchors.top: topSep.bottom
    anchors.bottom: closeBtn.top
    anchors.right: parent.right
    margin-top: 10
    margin-bottom: 12
    step: 20
    pixels-scroll: true
    opacity: 0.70

  Button
    id: closeBtn
    text: Concluir
    font: verdana-11px-rounded
    color: white
    background-color: #1a2332
    anchors.bottom: parent.bottom
    anchors.horizontalCenter: parent.horizontalCenter
    width: 140
    height: 26
]], g_ui.getRootWidget())

fugasConfigUI:hide()

fugasConfigUI.closeBtn.onClick = function()
  fugasConfigUI:hide()
end

-- Adiciona os DualScrollPanels no contêiner expandido
for i, hInfo in ipairs(fugasStorages) do
  UI.DualScrollPanel(hInfo, function(widget, newParams)
    fugasStorages[i] = newParams
  end, fugasConfigUI.contentPanel)
end

-- Botão de Abertura na Aba Lateral (User)
local btnOpenFugas = UI.Button("Configurar Fugas", function()
  if fugasConfigUI:isVisible() then
    fugasConfigUI:hide()
  else
    fugasConfigUI:show()
    fugasConfigUI:raise()
    fugasConfigUI:focus()
  end
end)
btnOpenFugas:setColor("#00e6b8")

addSeparator()

UI.Separator()

-- ============================================================
-- LABEL INFORMATIVO DE SEÇÃO
-- ============================================================
local lblInfo = UI.Label("-- [[ TARGET PLAYER % ]] --")
lblInfo:setColor("#00e6b8")
UI.Separator()

-- ============================================================
-- INICIALIZAÇÃO DAS STORAGES (5 FAIXAS DE HP DO ALVO)
-- ============================================================
if type(storage.targetpl1) ~= "table" then
  storage.targetpl1 = {on=false, title="Target HP (81% a 100%)", text="jutsu", min=81, max=100}
end

if type(storage.targetpl2) ~= "table" then
  storage.targetpl2 = {on=false, title="Target HP (61% a 80%)", text="jutsu", min=61, max=80}
end

if type(storage.targetpl3) ~= "table" then
  storage.targetpl3 = {on=false, title="Target HP (41% a 60%)", text="jutsu", min=41, max=60}
end

if type(storage.targetpl4) ~= "table" then
  storage.targetpl4 = {on=false, title="Target HP (21% a 40%)", text="jutsu", min=21, max=40}
end

if type(storage.targetpl5) ~= "table" then
  storage.targetpl5 = {on=false, title="Target HP (0% a 20%)", text="jutsu", min=0, max=20}
end

local targetStorages = {
  storage.targetpl1,
  storage.targetpl2,
  storage.targetpl3,
  storage.targetpl4,
  storage.targetpl5
}

-- ============================================================
-- MACROS (EXECUÇÃO BASEADA NO HP DO JOGADOR INIMIGO)
-- ============================================================
for _, targetplInfo in ipairs(targetStorages) do
  local targetplMacro = macro(100, function()
    if not targetplInfo.on then return end
    if not g_game.isAttacking() then return end

    local target = g_game.getAttackingCreature()
    if not target or not target:isPlayer() then return end

    local hp = target:getHealthPercent()
    if not hp then return end

    if targetplInfo.max >= hp and hp >= targetplInfo.min then
      if TargetBot then
        TargetBot.saySpell(targetplInfo.text)
      else
        say(targetplInfo.text)
      end
    end
  end)

  targetplMacro.setOn(targetplInfo.on)
end

-- ============================================================
-- PAINEL MODERNO & ESPAÇOSO (LARGURA 480PX + TRANSPARÊNCIA)
-- ============================================================
targetPlConfigUI = setupUI([[
MainWindow
  id: targetPlConfigWindow
  text: Configuraçoes de Target Player
  size: 480 430
  draggable: true
  moveable: true
  opacity: 0.90
  background-color: #0b0e14
  border: 1 #1f293d
  font: verdana-11px-rounded
  padding: 16

  Label
    id: windowHeader
    text: Painel Target Player HP%
    anchors.top: parent.top
    anchors.horizontalCenter: parent.horizontalCenter
    margin-top: 22
    color: #00e6b8
    font: verdana-11px-rounded

  HorizontalSeparator
    id: topSep
    anchors.top: windowHeader.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 8

  ScrollablePanel
    id: contentPanel
    anchors.top: topSep.bottom
    anchors.left: parent.left
    anchors.right: targetScrollBar.left
    anchors.bottom: closeBtn.top
    margin-top: 10
    margin-bottom: 12
    margin-right: 6
    vertical-scrollbar: targetScrollBar
    layout:
      type: verticalBox
      spacing: 10

  VerticalScrollBar
    id: targetScrollBar
    anchors.top: topSep.bottom
    anchors.bottom: closeBtn.top
    anchors.right: parent.right
    margin-top: 10
    margin-bottom: 12
    step: 20
    pixels-scroll: true
    opacity: 0.70

  Button
    id: closeBtn
    text: Concluir
    font: verdana-11px-rounded
    color: white
    background-color: #1a2332
    anchors.bottom: parent.bottom
    anchors.horizontalCenter: parent.horizontalCenter
    width: 140
    height: 26
]], g_ui.getRootWidget())

targetPlConfigUI:hide()

targetPlConfigUI.closeBtn.onClick = function()
  targetPlConfigUI:hide()
end

-- Adiciona os seletores duplos dentro do painel espaçoso
for i, tInfo in ipairs(targetStorages) do
  UI.DualScrollPanel(tInfo, function(widget, newParams)
    targetStorages[i] = newParams
  end, targetPlConfigUI.contentPanel)
end

-- Botão de Abertura na Aba Lateral do Bot
local btnOpenTarget = UI.Button("Configurar Target Player", function()
  if targetPlConfigUI:isVisible() then
    targetPlConfigUI:hide()
  else
    targetPlConfigUI:show()
    targetPlConfigUI:raise()
    targetPlConfigUI:focus()
  end
end)
btnOpenTarget:setColor("#00e6b8")

UI.Separator()

lblInfo= UI.Label("-- [[ FOOD ]] --")
lblInfo:setColor("green")
addSeparator()
addSeparator()
if type(storage.foodItems) ~= "table" then
  storage.foodItems = {3582, 3577}
end

local foodContainer = UI.Container(function(widget, items)
  storage.foodItems = items
end, true)
foodContainer:setHeight(35)
foodContainer:setItems(storage.foodItems)

UI.Separator()


macro(10000, "Eat Food", function()
  if player:getRegenerationTime() > 400 or not storage.foodItems[1] then return end
  -- search for food in containers
  for _, container in pairs(g_game.getContainers()) do
    for __, item in ipairs(container:getItems()) do
      for i, foodItem in ipairs(storage.foodItems) do
        if item:getId() == foodItem.id then
          return g_game.use(item)
        end
      end
    end
  end
end)

UI.Separator()

-- ============================================================
-- LABEL INFORMATIVO DE SEÇÃO
-- ============================================================
local lblInfo = UI.Label("-- [[ TREINO ]] --")
lblInfo:setColor("#00e6b8")
addSeparator()
addSeparator()

-- ============================================================
-- INICIALIZAÇÃO DA STORAGE DE TREINO DE MANA
-- ============================================================
if type(storage.manatrainer) ~= "table" then
  storage.manatrainer = {on = false, title = "mana%", text = "Power Down", min = 0, max = 90}
end

local lastTreinoCast = 0

-- ============================================================
-- 1) MACRO EXECUTORA DE TREINO (RESPEITA A % DE MANA)
-- ============================================================
local healingmacro = macro(100, function()
  if not storage.manatrainer.on then return end

  local mana = manapercent()

  -- Verifica se a mana está dentro da faixa e respeita o intervalo de 1 segundo (1000ms)
  if mana >= storage.manatrainer.min and mana <= storage.manatrainer.max then
    if now - lastTreinoCast >= 1000 then
      say(storage.manatrainer.text)
      lastTreinoCast = now
    end
  end
end)

healingmacro.setOn(storage.manatrainer.on)

-- ============================================================
-- 2) MACRO EXECUTORA DE DANCE (SUAVE - 500MS)
-- ============================================================
local danceMacro = macro(500, function()
  if not storage.manatrainer.on then return end
  turn(math.random(0, 3))
end)

danceMacro.setOn(storage.manatrainer.on)

-- ============================================================
-- 3) PAINEL DE CONFIGURAÇÃO (480PX + TRANSPARÊNCIA)
-- ============================================================
treinoConfigUI = setupUI([[
MainWindow
  id: treinoConfigWindow
  text: Configuraçoes de Treino
  size: 480 300
  draggable: true
  moveable: true
  opacity: 0.90
  background-color: #0b0e14
  border: 1 #1f293d
  font: verdana-11px-rounded
  padding: 16

  Label
    id: windowHeader
    text: Painel de Controle Treino
    anchors.top: parent.top
    anchors.horizontalCenter: parent.horizontalCenter
    margin-top: 22
    color: #00e6b8
    font: verdana-11px-rounded

  HorizontalSeparator
    id: topSep
    anchors.top: windowHeader.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 8

  ScrollablePanel
    id: contentPanel
    anchors.top: topSep.bottom
    anchors.left: parent.left
    anchors.right: treinoScrollBar.left
    anchors.bottom: closeBtn.top
    margin-top: 10
    margin-bottom: 12
    margin-right: 6
    vertical-scrollbar: treinoScrollBar
    layout:
      type: verticalBox
      spacing: 10

  VerticalScrollBar
    id: treinoScrollBar
    anchors.top: topSep.bottom
    anchors.bottom: closeBtn.top
    anchors.right: parent.right
    margin-top: 10
    margin-bottom: 12
    step: 20
    pixels-scroll: true
    opacity: 0.70

  Button
    id: closeBtn
    text: Concluir
    font: verdana-11px-rounded
    color: white
    background-color: #1a2332
    anchors.bottom: parent.bottom
    anchors.horizontalCenter: parent.horizontalCenter
    width: 140
    height: 26
]], g_ui.getRootWidget())

treinoConfigUI:hide()

treinoConfigUI.closeBtn.onClick = function()
  treinoConfigUI:hide()
end

-- Adiciona os controles de mana ao painel
UI.DualScrollPanel(storage.manatrainer, function(widget, newParams)
  storage.manatrainer = newParams
  healingmacro.setOn(storage.manatrainer.on)
  danceMacro.setOn(storage.manatrainer.on)
end, treinoConfigUI.contentPanel)

-- Botão de Abertura na Aba Lateral (User)
local btnOpenTreino = UI.Button("Configurar Treino", function()
  if treinoConfigUI:isVisible() then
    treinoConfigUI:hide()
  else
    treinoConfigUI:show()
    treinoConfigUI:raise()
    treinoConfigUI:focus()
  end
end)
btnOpenTreino:setColor("#00e6b8")

-- ============================================================
-- 4) ÍCONE FLUTUANTE ON/OFF ("Treino")
-- ============================================================
storage.botIconPositions = storage.botIconPositions or {}

local treinoIcon = addIcon("iconTreinoOnlyScript", {
  text = "Treino",
  switchable = false,
  moveable = true
}, function()
  storage.manatrainer.on = not storage.manatrainer.on
  healingmacro.setOn(storage.manatrainer.on)
  danceMacro.setOn(storage.manatrainer.on)
end)

treinoIcon:setSize({width = 90, height = 40})
treinoIcon.text:setFont("verdana-11px-rounded")
treinoIcon:setOpacity(1.0)

treinoIcon.onMousePress = function(widget, mousePos, button)
  return true
end

-- Salvar posição ao arrastar segurando Ctrl
treinoIcon.onMouseRelease = function(widget, mousePos, button)
  if modules.corelib.g_keyboard.isCtrlPressed() then
    storage.botIconPositions.iconTreinoOnlyScript = {
      x = widget:getX(),
      y = widget:getY()
    }
  end
  return true
end

-- Posicionamento inicial/carregamento salvo
schedule(10, function()
  local saved = storage.botIconPositions.iconTreinoOnlyScript
  if saved then
    treinoIcon:setPosition(saved)
  else
    treinoIcon:setPosition({x = 620, y = 360})
  end
end)

-- Atualização contínua do status visual no ícone (ON / OFF)
macro(200, function()
  if storage.manatrainer.on then
    treinoIcon.text:setColoredText({
      "Treino\n", "white",
      "ON", "green"
    })
    if not healingmacro.isOn() then healingmacro.isOn(true) end
    if not danceMacro.isOn() then danceMacro.isOn(true) end
  else
    treinoIcon.text:setColoredText({
      "Treino\n", "white",
      "OFF", "red"
    })
    if healingmacro.isOn() then healingmacro.setOn(false) end
    if danceMacro.isOn() then danceMacro.isOn(false) end
  end
end)

addSeparator()

UI.Separator()

-- ============================================================
-- LABEL INFORMATIVO DE SEÇÃO
-- ============================================================
local lblInfo = UI.Label("-- [[ AUTO POTIONS ]] --")
lblInfo:setColor("#00e6b8")
addSeparator()

-- ============================================================
-- INICIALIZAÇÃO DAS STORAGES (LIFE & MANA POTION)
-- ============================================================
if type(storage.autoLifePotion) ~= "table" then
  storage.autoLifePotion = {
    on = false,
    potionId = "10712",
    minHealth = "85"
  }
end

if type(storage.autoManaPotion) ~= "table" then
  storage.autoManaPotion = {
    on = false,
    potionId = "11506",
    minMana = "25"
  }
end

-- Variáveis de Cooldown
local lifeCooldown = 1000
local lastLifeUse = 0

local manaCooldown = 1000
local lastManaUse = 0

-- ============================================================
-- 1) MACRO: AUTO LIFE POTION
-- ============================================================
local autoLifeMacro = macro(100, function()
  if not storage.autoLifePotion.on then return end

  local hp = hppercent()
  local targetHp = tonumber(storage.autoLifePotion.minHealth) or 85
  local itemID = tonumber(storage.autoLifePotion.potionId)

  if itemID and hp <= targetHp then
    if now - lastLifeUse >= lifeCooldown then
      useWith(itemID, player)
      lastLifeUse = now
    end
  end
end)

autoLifeMacro.setOn(storage.autoLifePotion.on)

-- ============================================================
-- 2) MACRO: AUTO MANA POTION
-- ============================================================
local autoManaMacro = macro(100, function()
  if not storage.autoManaPotion.on then return end

  local mana = manapercent()
  local targetMana = tonumber(storage.autoManaPotion.minMana) or 25
  local itemID = tonumber(storage.autoManaPotion.potionId)

  if itemID and mana <= targetMana then
    if now - lastManaUse >= manaCooldown then
      useWith(itemID, player)
      lastManaUse = now
    end
  end
end)

autoManaMacro.setOn(storage.autoManaPotion.on)

-- ============================================================
-- 3) PAINEL DE CONFIGURAÇÃO INTEGRADO (480PX + TRANSPARÊNCIA)
-- ============================================================
potionsConfigUI = setupUI([[
MainWindow
  id: potionsConfigWindow
  text: Configuraçoes de Auto Potions
  size: 480 390
  draggable: true
  moveable: true
  opacity: 0.90
  background-color: #0b0e14
  border: 1 #1f293d
  font: verdana-11px-rounded
  padding: 16

  Label
    id: windowHeader
    text: Painel Auto Potions (Life & Mana)
    anchors.top: parent.top
    anchors.horizontalCenter: parent.horizontalCenter
    margin-top: 22
    color: #00e6b8
    font: verdana-11px-rounded

  HorizontalSeparator
    id: topSep
    anchors.top: windowHeader.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 8

  ScrollablePanel
    id: contentPanel
    anchors.top: topSep.bottom
    anchors.left: parent.left
    anchors.right: potionsScrollBar.left
    anchors.bottom: closeBtn.top
    margin-top: 10
    margin-bottom: 12
    margin-right: 6
    vertical-scrollbar: potionsScrollBar
    layout:
      type: verticalBox
      spacing: 8

  VerticalScrollBar
    id: potionsScrollBar
    anchors.top: topSep.bottom
    anchors.bottom: closeBtn.top
    anchors.right: parent.right
    margin-top: 10
    margin-bottom: 12
    step: 20
    pixels-scroll: true
    opacity: 0.70

  Button
    id: closeBtn
    text: Concluir
    font: verdana-11px-rounded
    color: white
    background-color: #1a2332
    anchors.bottom: parent.bottom
    anchors.horizontalCenter: parent.horizontalCenter
    width: 140
    height: 26
]], g_ui.getRootWidget())

potionsConfigUI:hide()

local parentPanel = potionsConfigUI.contentPanel

-- --- SEÇÃO LIFE POTION ---
local lblLifeTitle = UI.Label("-- [[ LIFE POTION ]] --", parentPanel)
lblLifeTitle:setColor("#00e6b8")

UI.Label("Ativar Life Potion:", parentPanel)
local lifeCheckBox = UI.Button(storage.autoLifePotion.on and "Ativado [ON]" or "Desativado [OFF]", function(btn)
  storage.autoLifePotion.on = not storage.autoLifePotion.on
  autoLifeMacro.setOn(storage.autoLifePotion.on)
  btn:setText(storage.autoLifePotion.on and "Ativado [ON]" or "Desativado [OFF]")
  btn:setColor(storage.autoLifePotion.on and "green" or "red")
end, parentPanel)
lifeCheckBox:setColor(storage.autoLifePotion.on and "green" or "red")

UI.Label("Life Potion ID:", parentPanel)
UI.TextEdit(storage.autoLifePotion.potionId, function(widget, text)
  storage.autoLifePotion.potionId = text
end, parentPanel)

UI.Label("Usar com HP % menor/igual a:", parentPanel)
UI.TextEdit(storage.autoLifePotion.minHealth, function(widget, text)
  storage.autoLifePotion.minHealth = text
end, parentPanel)

UI.Separator(parentPanel)

-- --- SEÇÃO MANA POTION ---
local lblManaTitle = UI.Label("-- [[ MANA POTION ]] --", parentPanel)
lblManaTitle:setColor("#00e6b8")

UI.Label("Ativar Mana Potion:", parentPanel)
local manaCheckBox = UI.Button(storage.autoManaPotion.on and "Ativado [ON]" or "Desativado [OFF]", function(btn)
  storage.autoManaPotion.on = not storage.autoManaPotion.on
  autoManaMacro.setOn(storage.autoManaPotion.on)
  btn:setText(storage.autoManaPotion.on and "Ativado [ON]" or "Desativado [OFF]")
  btn:setColor(storage.autoManaPotion.on and "green" or "red")
end, parentPanel)
manaCheckBox:setColor(storage.autoManaPotion.on and "green" or "red")

UI.Label("Mana Potion ID:", parentPanel)
UI.TextEdit(storage.autoManaPotion.potionId, function(widget, text)
  storage.autoManaPotion.potionId = text
end, parentPanel)

UI.Label("Usar com Mana % menor/igual a:", parentPanel)
UI.TextEdit(storage.autoManaPotion.minMana, function(widget, text)
  storage.autoManaPotion.minMana = text
end, parentPanel)

potionsConfigUI.closeBtn.onClick = function()
  potionsConfigUI:hide()
end

-- Botão de Abertura na Aba Lateral (User)
local btnOpenPotions = UI.Button("Configurar Potions", function()
  if potionsConfigUI:isVisible() then
    potionsConfigUI:hide()
  else
    potionsConfigUI:show()
    potionsConfigUI:raise()
    potionsConfigUI:focus()
  end
end)
btnOpenPotions:setColor("#00e6b8")

-- ============================================================
-- 4) ÍCONES FLUTUANTES SEPARADOS (LIFE & MANA)
-- ============================================================
storage.botIconPositions = storage.botIconPositions or {}

-- --- ÍCONE 1: LIFE POTION ---
local lifePotionIcon = addIcon("iconLifePotionOnly", {
  text = "Life Potion",
  switchable = false,
  moveable = true
}, function()
  storage.autoLifePotion.on = not storage.autoLifePotion.on
  autoLifeMacro.setOn(storage.autoLifePotion.on)

  lifeCheckBox:setText(storage.autoLifePotion.on and "Ativado [ON]" or "Desativado [OFF]")
  lifeCheckBox:setColor(storage.autoLifePotion.on and "green" or "red")
end)

lifePotionIcon:setSize({width = 95, height = 40})
lifePotionIcon.text:setFont("verdana-11px-rounded")
lifePotionIcon:setOpacity(1.0)

lifePotionIcon.onMousePress = function(widget, mousePos, button)
  return true
end

lifePotionIcon.onMouseRelease = function(widget, mousePos, button)
  if modules.corelib.g_keyboard.isCtrlPressed() then
    storage.botIconPositions.iconLifePotionOnly = {
      x = widget:getX(),
      y = widget:getY()
    }
  end
  return true
end

-- --- ÍCONE 2: MANA POTION ---
local manaPotionIcon = addIcon("iconManaPotionOnly", {
  text = "Mana Potion",
  switchable = false,
  moveable = true
}, function()
  storage.autoManaPotion.on = not storage.autoManaPotion.on
  autoManaMacro.setOn(storage.autoManaPotion.on)

  manaCheckBox:setText(storage.autoManaPotion.on and "Ativado [ON]" or "Desativado [OFF]")
  manaCheckBox:setColor(storage.autoManaPotion.on and "green" or "red")
end)

manaPotionIcon:setSize({width = 95, height = 40})
manaPotionIcon.text:setFont("verdana-11px-rounded")
manaPotionIcon:setOpacity(1.0)

manaPotionIcon.onMousePress = function(widget, mousePos, button)
  return true
end

manaPotionIcon.onMouseRelease = function(widget, mousePos, button)
  if modules.corelib.g_keyboard.isCtrlPressed() then
    storage.botIconPositions.iconManaPotionOnly = {
      x = widget:getX(),
      y = widget:getY()
    }
  end
  return true
end

-- Restaura ou define as posições padrão dos dois ícones
schedule(10, function()
  local savedLife = storage.botIconPositions.iconLifePotionOnly
  if savedLife then
    lifePotionIcon:setPosition(savedLife)
  else
    lifePotionIcon:setPosition({x = 620, y = 280})
  end

  local savedMana = storage.botIconPositions.iconManaPotionOnly
  if savedMana then
    manaPotionIcon:setPosition(savedMana)
  else
    manaPotionIcon:setPosition({x = 620, y = 330})
  end
end)

-- Atualização visual em tempo real dos ícones
macro(200, function()
  -- Atualiza o ícone de Life Potion
  if storage.autoLifePotion.on then
    lifePotionIcon.text:setColoredText({
      "Life Potion\n", "white",
      "ON", "green"
    })
    if not autoLifeMacro.isOn() then autoLifeMacro.setOn(true) end
  else
    lifePotionIcon.text:setColoredText({
      "Life Potion\n", "white",
      "OFF", "red"
    })
    if autoLifeMacro.isOn() then autoLifeMacro.setOn(false) end
  end

  -- Atualiza o ícone de Mana Potion
  if storage.autoManaPotion.on then
    manaPotionIcon.text:setColoredText({
      "Mana Potion\n", "white",
      "ON", "green"
    })
    if not autoManaMacro.isOn() then autoManaMacro.setOn(true) end
  else
    manaPotionIcon.text:setColoredText({
      "Mana Potion\n", "white",
      "OFF", "red"
    })
    if autoManaMacro.isOn() then autoManaMacro.setOn(false) end
  end
end)

addSeparator()
