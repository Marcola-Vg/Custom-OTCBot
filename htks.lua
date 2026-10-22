setDefaultTab("HTKS")

UI.Separator()

macro(500,"Battle Bot", function()
  local currentPlayers = {}

  for _, spec in ipairs(getSpectators()) do
      if spec:isPlayer() and not spec:isLocalPlayer() then
          if not switchState or (switchState and not (isFriend(spec:getName()) or spec:getEmblem() == 1)) then
              currentPlayers[spec:getName()] = spec
          end
      end
  end

  for name, btn in pairs(Maker.buttons) do
      if not currentPlayers[name] then
          if not Maker.pendingRemoval[name] then
              Maker.pendingRemoval[name] = true
              schedule(2000, function()
                  if not currentPlayers[name] then
                      if Maker.buttons[name] then
                          Maker.buttons[name]:destroy()
                          Maker.buttons[name] = nil
                          Maker.pendingRemoval[name] = nil
                      end
                  end
              end)
          end
      else
          Maker.pendingRemoval[name] = nil
      end
  end

  local index, buttonWidth, buttonHeight, spacing, rowLength = 0, 80, 30, 10, 4
  local startX, startY = 100, 120

  for name, spec in pairs(currentPlayers) do
      if not Maker.buttons[name] then
          local x = startX + (index % rowLength) * (buttonWidth + spacing)
          local y = startY + math.floor(index / rowLength) * (buttonHeight + spacing)

          setDefaultTab("main") -- Garante que os botões sejam criados na tab correta

          local newButton = addButton("", { switchable = false, moveable = true }, function()
              HOLDER.setOff()
              Maker.target = 0
              modules.game_battle.autoAtaqueTarget = nil
              g_game.cancelAttackAndFollow()
              fakeHoverChange(spec)
              modules.game_battle.updateTarget(spec)
              modules.game_battle.tryAtaque(spec)
              Maker.target = spec:getId()
              foco = spec
              fakeHoverChange(spec)
              schedule(100, function() HOLDER.setOn() end)
          end)

          newButton:setSize({ width = buttonWidth, height = buttonHeight })
          newButton:setPosition({ x = x, y = y })
          newButton:setFont("verdana-11px-rounded")
          newButton:setText(name)
          newButton:setImageSource()
          newButton:setBackgroundColor("black")

          Maker.buttons[name] = newButton
      end

      Maker.buttons[name]:setColor(Maker.target and spec:getId() == Maker.target and "#FF0000" or "#FFFFFF")
      index = index + 1
  end
end)



addSwitch("exampleSwitch", "Filter Friends Battle Bot OFF", function(widget)
  switchState = not switchState
  widget:setText(switchState and "Filter Friends Battle Bot ON!" or "Filter Friends Battle Bot OFF")
end)

hotkey("TAB", "Refresh List", function()
  currentPlayers = {} -- Limpa a lista de jogadores

  -- Remove todos os botões existentes manualmente
  for name, btn in pairs(Maker.buttons) do
      btn:destroy()
  end
  Maker.buttons = {}
  Maker.pendingRemoval = {}

end)


macro(100, "NO Attack Friend", function()
  for _, spec in ipairs(getSpectators()) do
      if spec:isPlayer() and not spec:isLocalPlayer() then
          if g_game.isAttacking() and target():isPlayer() then
              if (target():getShield() ~= 1 and target():isPartyMember()) or target():getEmblem() == 1 or isFriend(spec:getName()) then
                  g_game.cancelAttackAndFollow()
                  Maker.target = 0
              end
          end
      end
  end
end)


UI.Separator()

-- ======================================================
-- MACRO AUTO SUMMON + AUTO KAI (CUSTOM OTC / VBOT)
-- ======================================================

-- Configurações Globais no Storage
storage.summonName = storage.summonName or ""
storage.summonSpell = storage.summonSpell or ""
storage.summonMax = storage.summonMax or 4

storage.autoSummonEnabled = storage.autoSummonEnabled or false
storage.autoKaiParado = storage.autoKaiParado or false
storage.botIconPositions = storage.botIconPositions or {}

-- ------------------------------------------------------
-- INTERFACE NA CUSTOM OTC
-- ------------------------------------------------------
UI.Label("--- SUMMONS & AUTO KAI ---")

UI.Label("Nome do Summon:")
UI.TextEdit(storage.summonName, function(widget, text)
  storage.summonName = text
end)

UI.Label("Jutsu / Feitiço:")
UI.TextEdit(storage.summonSpell, function(widget, text)
  storage.summonSpell = text
end)

UI.Label("Quantidade Máxima:")
UI.TextEdit(tostring(storage.summonMax), function(widget, text)
  local amount = tonumber(text)
  if amount and amount >= 1 then
    storage.summonMax = math.floor(amount)
  end
end)

UI.Separator()

-- ------------------------------------------------------
-- ÍCONES FLUTUANTES
-- ------------------------------------------------------

-- 1. Ícone Auto Summon
local summonIcon = addIcon("iconAutoSummon", {
  text = "Auto Summon",
  switchable = false,
  moveable = true
}, function()
  storage.autoSummonEnabled = not storage.autoSummonEnabled
end)

summonIcon:setSize({width = 90, height = 40})
summonIcon.text:setFont("verdana-11px-rounded")
summonIcon:setOpacity(1.0)

summonIcon.onMouseRelease = function(widget, mousePos, button)
  if modules.corelib.g_keyboard.isCtrlPressed() then
    storage.botIconPositions.iconAutoSummon = {
      x = widget:getX(),
      y = widget:getY()
    }
  end
  return true
end

-- 2. Ícone Auto Kai
local kaiIcon = addIcon("iconAutoKai", {
  text = "Auto Kai",
  switchable = false,
  moveable = true
}, function()
  storage.autoKaiParado = not storage.autoKaiParado
end)

kaiIcon:setSize({width = 80, height = 40})
kaiIcon.text:setFont("verdana-11px-rounded")
kaiIcon:setOpacity(1.0)

kaiIcon.onMouseRelease = function(widget, mousePos, button)
  if modules.corelib.g_keyboard.isCtrlPressed() then
    storage.botIconPositions.iconAutoKai = {
      x = widget:getX(),
      y = widget:getY()
    }
  end
  return true
end

-- Posicionamento Inicial / Salvo dos Ícones
schedule(10, function()
  if storage.botIconPositions.iconAutoSummon then
    summonIcon:setPosition(storage.botIconPositions.iconAutoSummon)
  else
    summonIcon:setPosition({x = 520, y = 310})
  end

  if storage.botIconPositions.iconAutoKai then
    kaiIcon:setPosition(storage.botIconPositions.iconAutoKai)
  else
    kaiIcon:setPosition({x = 620, y = 310})
  end
end)

-- Update do Visual dos Ícones (ON/OFF)
macro(200, function()
  if storage.autoSummonEnabled then
    summonIcon.text:setColoredText({"Auto Summon\n", "white", "ON", "green"})
  else
    summonIcon.text:setColoredText({"Auto Summon\n", "white", "OFF", "red"})
  end

  if storage.autoKaiParado then
    kaiIcon.text:setColoredText({"Auto Kai\n", "white", "ON", "green"})
  else
    kaiIcon.text:setColoredText({"Auto Kai\n", "white", "OFF", "red"})
  end
end)

-- ------------------------------------------------------
-- FUNÇÃO AUXILIAR: CONTAR SUMMONS
-- ------------------------------------------------------
local function countSummonsOnScreen()
  local count = 0
  local summonName = (storage.summonName or ""):lower()

  if summonName == "" then return 0 end

  for _, spec in ipairs(getSpectators()) do
    if spec and not spec:isPlayer() and not spec:isNpc() then
      local name = spec:getName()
      if name and name:lower() == summonName then
        count = count + 1
      end
    end
  end

  return count
end

-- ------------------------------------------------------
-- MACRO 1: AUTO SUMMON
-- ------------------------------------------------------
local lastSummonCast = 0

macro(50, function()
  if not storage.autoSummonEnabled then return end

  local summonName = (storage.summonName or ""):lower()
  local spell = storage.summonSpell or ""
  local maxSummons = tonumber(storage.summonMax) or 4

  if summonName == "" or spell == "" or maxSummons < 1 then return end

  if countSummonsOnScreen() >= maxSummons then return end

  if now - lastSummonCast >= 300 then
    say(spell)
    lastSummonCast = now
  end
end)

-- ------------------------------------------------------
-- MACRO 2: AUTO KAI PARADO (10 SEGUNDOS)
-- ------------------------------------------------------
macro(100, function()
  if not storage.autoKaiParado then return end

  local p = pos()
  if not p then return end

  local tempoAtual = now
  local alvo = g_game.getAttackingCreature()

  -- Se tiver atacando ou se mover, reseta a contagem
  if alvo or storage.kaiX ~= p.x or storage.kaiY ~= p.y or storage.kaiZ ~= p.z then
    storage.kaiX = p.x
    storage.kaiY = p.y
    storage.kaiZ = p.z
    storage.kaiParadoDesde = tempoAtual
    return
  end

  if storage.kaiParadoDesde == nil then
    storage.kaiParadoDesde = tempoAtual
    return
  end

  -- Se passar de 10 segundos sem mover nem atacar, solta 'kai'
  if tempoAtual - storage.kaiParadoDesde >= 10000 then
    say("kai")
    storage.kaiParadoDesde = tempoAtual
  end
end)

UI.Separator()

-- ============================================================
-- PvP ON/OFF - ÍCONE SINCRONIZADO COM COMANDO E INVENTÁRIO
-- ============================================================

storage.pvpIconEnabled = storage.pvpIconEnabled or false
storage.botIconPositions = storage.botIconPositions or {}

-- Função avançada para buscar e clicar no botão PvP do Inventário
local function clickPvpInventoryButton()
  local root = g_ui.getRootWidget()
  if not root then return end

  -- Array de IDs conhecidos para o botão de PvP do inventário
  local possibleIds = {"pvpButton", "pvp", "pvpBox", "pvpIcon", "buttonPvP"}

  for _, id in ipairs(possibleIds) do
    local widget = root:recursiveGetChildById(id)
    if widget and widget.onClick then
      widget:onClick()
      return true
    end
  end

  -- Busca por classe/estilo de botões dentro da janela do inventário
  local invWindow = root:recursiveGetChildById('inventoryWindow') or root:recursiveGetChildById('inventoryPanel')
  if invWindow then
    for _, child in ipairs(invWindow:getChildren()) do
      if child:getId():lower():find("pvp") then
        if child.onClick then
          child:onClick()
          return true
        end
      end
    end
  end

  return false
end

-- Ícone Flutuante
local pvpIcon = addIcon("iconPvP", {
  text = "PvP",
  switchable = false,
  moveable = true
}, function()
  if not g_game.isOnline() then return end

  storage.pvpIconEnabled = not storage.pvpIconEnabled

  -- 1) Envia o comando no chat
  if storage.pvpIconEnabled then
    say("!pvp on")
  else
    say("!pvp off")
  end

  -- 2) Executa o clique no botão visual do inventário
  clickPvpInventoryButton()
end)

pvpIcon:setSize({width = 80, height = 40})
pvpIcon.text:setFont("verdana-11px-rounded")
pvpIcon:setOpacity(1.0)

pvpIcon.onMousePress = function(widget, mousePos, button)
  return true
end

-- Salvar posição ao arrastar segurando Ctrl
pvpIcon.onMouseRelease = function(widget, mousePos, button)
  if modules.corelib.g_keyboard.isCtrlPressed() then
    storage.botIconPositions.iconPvP = {
      x = widget:getX(),
      y = widget:getY()
    }
  end
  return true
end

-- Carregar posição salva
schedule(10, function()
  local savedPvPPosition = storage.botIconPositions.iconPvP
  if savedPvPPosition then
    pvpIcon:setPosition(savedPvPPosition)
  else
    pvpIcon:setPosition({x = 620, y = 510})
  end
end)

-- Atualização visual do ícone flutuante
macro(200, function()
  if storage.pvpIconEnabled then
    pvpIcon.text:setColoredText({
      "PvP\n", "white",
      "ON", "green"
    })
  else
    pvpIcon.text:setColoredText({
      "PvP\n", "white",
      "OFF", "red"
    })
  end
end)

addSeparator()

UI.Separator()

button = UI.Button("Ingame Scripts", function(newText)
	UI.MultilineEditorWindow(storage.ingame_hotkeys or "", {title="Scripts editor", description="You can add your custom scripts here"}, function(text)
		storage.ingame_hotkeys = text
		reload()
	end)
end)
button:setFont("verdana-11px-rounded")
button:setColor("orange")

for _, scripts in pairs({storage.ingame_hotkeys}) do
    if type(scripts) == "string" and scripts:len() > 3 then
      local status, result = pcall(function()
      assert(load(scripts, "ingame_editor"))()
    end)
    if not status then 
      error("Ingame edior error:\n" .. result)
    end
  end
end
