-- =====================================================================
-- SISTEMA DE VIAGEM AUTOMATIZADO - PAINEL PRINCIPAL TRANSPARENTE
-- =====================================================================

-- Carrega dados salvos ou padrões
local npcList = storage.autoTravelNpcsList or {"Minoru", "Takashi", "Caronte", "Mabui"}
local detectedCities = {}
local activeNpc = nil
local selectedNpcToRemove = nil
local isTraveling = false -- Trava de segurança contra múltiplos cliques e loops

-- Função universal de fala com NPC
local function talkToNpc(text)
  if g_game.getClientVersion() >= 810 then
    g_game.talkChannel(11, 0, text)
  else
    say(text)
  end
end

-- =====================================================================
-- 1) PAINEL PRINCIPAL DE VIAGEM (Fundo Transparente Fosco)
-- =====================================================================
if travelUI then travelUI:destroy() end

travelUI = setupUI([[  
MainWindow
  id: travelMainDynamic
  text: Painel de Viagem
  size: 630 220
  draggable: true
  moveable: true
  background-color: #0d0d0dd0
  opacity: 0.8
  font: verdana-11px-rounded
  padding: 12

  Label
    id: npcNameTitle
    text: "NPC: Aguardando..."
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    margin-left: 5
    color: #00e6b8
    font: verdana-11px-rounded

  HorizontalSeparator
    id: topSeparator
    anchors.top: npcNameTitle.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 8

  UIWidget
    id: cityGridContainer
    anchors.top: topSeparator.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: bottomSeparator.top
    margin-top: 10
    margin-bottom: 10
    margin-left: 10
    margin-right: 10
    layout:
      type: grid
      cell-size: 138 28
      cell-spacing: 12
      flow: true

  HorizontalSeparator
    id: bottomSeparator
    anchors.bottom: closeMainButton.top
    anchors.left: parent.left
    anchors.right: parent.right
    margin-bottom: 10

  Button
    id: closeMainButton
    text: Fechar
    font: verdana-11px-rounded
    color: white
    background-color: #1a2332
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    margin-left: 5
    width: 90
    height: 24

  Button
    id: configButton
    text: Config NPCs
    font: verdana-11px-rounded
    color: white
    background-color: #1a2332
    anchors.bottom: parent.bottom
    anchors.right: parent.right
    margin-right: 5
    width: 100
    height: 24
]], g_ui.getRootWidget())
travelUI:hide()

-- =====================================================================
-- 2) PAINEL DE CONFIGURAÇÃO DE NPCS (MODAL LIMPO E ORGANIZADO)
-- =====================================================================
if travelSettingsUI then travelSettingsUI:destroy() end

travelSettingsUI = setupUI([[  
MainWindow
  id: travelConfigDynamic
  text: Gerenciar NPCs
  size: 340 400
  draggable: true
  moveable: true
  background-color: #0b0e14
  border: 1 #1f293d
  opacity: 0.95
  font: verdana-11px-rounded
  padding: 16

  Label
    id: windowHeader
    text: Gerenciador de NPCs
    anchors.top: parent.top
    anchors.horizontalCenter: parent.horizontalCenter
    margin-top: 20
    color: #00e6b8
    font: verdana-11px-rounded

  HorizontalSeparator
    id: headerSep
    anchors.top: windowHeader.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 8

  Label
    id: listTitle
    text: NPCs Cadastrados:
    anchors.top: headerSep.bottom
    anchors.left: parent.left
    margin-top: 10
    color: white
    font: verdana-11px-rounded

  ScrollablePanel
    id: npcScrollPanel
    anchors.top: listTitle.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 6
    margin-right: 20
    height: 110
    background-color: #121824
    border: 1 #1f293d
    vertical-scrollbar: npcListScrollBar
    layout:
      type: verticalBox
      spacing: 4

  VerticalScrollBar
    id: npcListScrollBar
    anchors.top: npcScrollPanel.top
    anchors.bottom: npcScrollPanel.bottom
    anchors.right: parent.right
    step: 16
    pixels-scroll: true
    opacity: 0.70

  Button
    id: removeNpcButton
    text: Remover NPC Selecionado
    font: verdana-11px-rounded
    color: white
    background-color: #8b0000
    anchors.top: npcScrollPanel.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 8
    height: 24

  HorizontalSeparator
    id: middleSep
    anchors.top: removeNpcButton.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 10

  Label
    id: newNpcLabel
    text: Adicionar Novo NPC:
    anchors.top: middleSep.bottom
    anchors.left: parent.left
    margin-top: 10
    color: white
    font: verdana-11px-rounded

  TextEdit
    id: newNpcField
    text: ""
    font: verdana-11px-rounded
    anchors.top: newNpcLabel.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 4
    height: 24

  Button
    id: addNpcButton
    text: Adicionar NPC
    font: verdana-11px-rounded
    color: white
    background-color: #1a2332
    anchors.top: newNpcField.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    margin-top: 8
    height: 24

  Button
    id: closeSettingsButton
    text: Concluir
    font: verdana-11px-rounded
    color: white
    background-color: #1a2332
    anchors.bottom: parent.bottom
    anchors.horizontalCenter: parent.horizontalCenter
    width: 120
    height: 26
]], g_ui.getRootWidget())
travelSettingsUI:hide()

-- Atualiza a lista de NPCs na interface de configuração com botões interativos
local function refreshNpcList()
  if not travelSettingsUI then return end
  local panel = travelSettingsUI.npcScrollPanel
  if not panel then return end
  
  panel:destroyChildren()
  selectedNpcToRemove = nil

  for _, name in ipairs(npcList) do
    local btn = g_ui.createWidget("Button", panel)
    if btn then
      btn:setText(name)
      btn:setHeight(22)
      btn:setFont("verdana-11px-rounded")
      btn:setColor("#00e6b8")
      btn:setBackgroundColor("#121824")
      btn.onClick = function()
        for _, child in ipairs(panel:getChildren()) do
          child:setColor("#00e6b8")
          child:setBackgroundColor("#121824")
        end
        btn:setColor("#ffffff")
        btn:setBackgroundColor("#1a2332")
        selectedNpcToRemove = name
      end
    end
  end
end

-- Função segura para executar a viagem sem loops infinitos
local function travelToCity(cityName, btnWidget)
  if isTraveling then return end
  isTraveling = true

  local originalPos = pos()

  -- Destaque visual no botão clicado
  if btnWidget then
    local container = travelUI.cityGridContainer
    if container then
      for _, child in ipairs(container:getChildren()) do
        child:setColor("#00e6b8")
        child:setBackgroundColor("#121824")
      end
    end
    btnWidget:setColor("#ffffff")
    btnWidget:setBackgroundColor("#1a2332")
  end

  talkToNpc(cityName)

  schedule(400, function()
    talkToNpc("yes")
    
    local attempts = 0
    local function safeCheckTeleport()
      attempts = attempts + 1
      local currentPos = pos()
      
      if not currentPos or not originalPos then
        isTraveling = false
        return
      end

      if (currentPos.x ~= originalPos.x or currentPos.y ~= originalPos.y or currentPos.z ~= originalPos.z) then
        schedule(300, function()
          talkToNpc("hi")
          isTraveling = false
        end)
      elseif attempts < 30 then
        schedule(500, safeCheckTeleport)
      else
        isTraveling = false
      end
    end

    schedule(500, safeCheckTeleport)
  end)
end

-- Reconstrói a grade de botões de cidades com o novo estilo unificado
local function rebuildCityGrid()
  if not travelUI then return end
  local container = travelUI.cityGridContainer
  if not container then return end
  
  container:destroyChildren()

  for _, city in ipairs(detectedCities) do
    local btn = g_ui.createWidget("Button", container)
    if btn then
      btn:setText(city)
      btn:setHeight(28)
      btn:setFont("verdana-11px-rounded")
      btn:setColor("#00e6b8")
      btn:setBackgroundColor("#121824")
      btn.onClick = function()
        travelToCity(city, btn)
      end
    end
  end

  local rowCount = math.ceil(#detectedCities / 4)
  if rowCount < 1 then rowCount = 1 end
  local newHeight = 120 + (rowCount * 40)
  travelUI:setHeight(newHeight)
end

-- Eventos dos botões principais
travelUI.configButton.onClick = function()
  refreshNpcList()
  travelSettingsUI:show()
end

travelSettingsUI.closeSettingsButton.onClick = function()
  travelSettingsUI:hide()
end

travelUI.closeMainButton.onClick = function()
  travelUI:hide()
end

-- Adicionar NPC
travelSettingsUI.addNpcButton.onClick = function()
  local text = travelSettingsUI.newNpcField:getText():trim()
  if text ~= "" then
    local exists = false
    for _, n in ipairs(npcList) do
      if n:lower() == text:lower() then
        exists = true
        break
      end
    end
    
    if not exists then
      table.insert(npcList, text)
      storage.autoTravelNpcsList = npcList
      refreshNpcList()
      travelSettingsUI.newNpcField:setText("")
    end
  end
end

-- Remover NPC selecionado na lista
travelSettingsUI.removeNpcButton.onClick = function()
  if selectedNpcToRemove then
    for i, n in ipairs(npcList) do
      if n == selectedNpcToRemove then
        table.remove(npcList, i)
        break
      end
    end
    storage.autoTravelNpcsList = npcList
    refreshNpcList()
    detectedCities = {}
    activeNpc = nil
    rebuildCityGrid()
  end
end

-- Atalho Ctrl + F
hotkey("Ctrl+F", function()
  if travelSettingsUI:isVisible() then
    travelSettingsUI:hide()
  else
    refreshNpcList()
    travelSettingsUI:show()
  end
end)

-- Captura segura de mensagens do NPC
onTalk(function(name, level, mode, text, channelId, pos)
  if activeNpc and name and name:lower() == activeNpc:lower() then
    local localPlayer = g_game.getLocalPlayer()
    local localPlayerName = localPlayer and localPlayer:getName() or ""
    
    local ignoredTerms = {
      "ola", "hello", "hi", "para", "onde", "deseja", "ser", "teleportado",
      "free", "vip", "ate", "mais", "ate mais", "ate mais!", "sim", "nao", "yes", "no",
      localPlayerName:lower(), localPlayerName:gsub(" ", ""):lower()
    }

    for braceMatch in text:gmatch("%{([^%}]+)%}") do
      local cleanCity = braceMatch:trim()
      if #cleanCity > 1 then
        local ignore = false
        for _, term in ipairs(ignoredTerms) do
          if term ~= "" and cleanCity:lower() == term then
            ignore = true
            break
          end
        end
        if not ignore then
          local exists = false
          for _, c in ipairs(detectedCities) do
            if c:lower() == cleanCity:lower() then exists = true break end
          end
          if not exists then
            table.insert(detectedCities, cleanCity)
            rebuildCityGrid()
          end
        end
      end
    end
  end
end)

-- Macro Principal de Aproximação
local hasSaidHi = false
macro(300, function()
  if isTraveling then return end

  local foundNearbyNpc = nil

  for _, npcName in ipairs(npcList) do
    local npcObj = getCreatureByName(npcName)
    if npcObj and getDistanceBetween(pos(), npcObj:getPosition()) <= 2 then
      foundNearbyNpc = npcName
      break
    end
  end

  if foundNearbyNpc then
    if activeNpc ~= foundNearbyNpc then
      activeNpc = foundNearbyNpc
      detectedCities = {}
      rebuildCityGrid()
      travelUI.npcNameTitle:setText("NPC: " .. activeNpc)
      hasSaidHi = false
    end

    travelUI:show()

    if not hasSaidHi then
      talkToNpc("hi")
      hasSaidHi = true
    end
  else
    travelUI:hide()
    hasSaidHi = false
    activeNpc = nil
  end
end)

-- Persistência de posição do painel
storage.travelPanelPosGrid = storage.travelPanelPosGrid or {}

schedule(300, function()
  local saved = storage.travelPanelPosGrid
  if saved and saved.x and saved.y then
    travelUI:setPosition({x = tonumber(saved.x), y = tonumber(saved.y)})
  else
    travelUI:setPosition({x = 50, y = 150})
  end
  storage.travelPanelPosReady = true
end)

macro(500, function()
  if not storage.travelPanelPosReady then return end
  local p = travelUI:getPosition()
  if p and p.x and p.y then
    storage.travelPanelPosGrid = { x = p.x, y = p.y }
  end
end)
