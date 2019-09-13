local dlmenu = {}

local term = require("term")
local palette = require("palette")
local fs = require("filesystem")
local event = require("event")
local w, h = term.gpu().getResolution()
local xoffset = math.floor(w/8)
local yoffset = math.floor(h/8)
-- actual window width & height
local ww, wh = math.floor(w-xoffset-w/8), math.floor(h-yoffset-h/8)
local program = {}
local version = nil
local dlstring = "Descargar a: "
local installstring = "Instalar"
local defaultdlpath = "" -- set on dlmenu.show

local exit = false

local function setToNormalColors()
  term.gpu().setBackground(palette.monochrome and 0 or palette.colors.winbg, not palette.monochrome)
  term.gpu().setForeground(0xffffff)
end
local function setToTitleColors()
  term.gpu().setBackground(palette.monochrome and 0xffffff or palette.colors.title, not palette.monochrome)
  term.gpu().setForeground(0)
end
local function setToInputColors()
  term.gpu().setBackground(palette.monochrome and 0 or palette.colors.bg, not palette.monochrome)
  term.gpu().setForeground(0xffffff)
end
local function setToProgressColors()
  term.gpu().setBackground(palette.monochrome and 0xffffff or palette.colors.status, not palette.monochrome)
  term.gpu().setForeground(palette.monochrome and 0 or 0xffffff)
end


local function drawTitle()
  setToNormalColors()
  term.gpu().fill(xoffset, yoffset, ww, wh, " ")
  setToTitleColors()
  term.gpu().fill(xoffset, yoffset, ww, 1, " ")
  local title = "Descargar "..program.name
  term.setCursor(w/2-#title/2, yoffset)
  term.write(title)
  term.setCursor(xoffset,yoffset)
  term.write("X")
end

-- Inputboxes have x, y, w, value and scroll
local inputboxes = {}
local inputboxselected = nil
local function createInputBoxes()
  inputboxes = {}
  table.insert(inputboxes, {x=xoffset+2+#dlstring, y=yoffset+2, w=ww-(#dlstring+4), value = defaultdlpath, scroll = 1})
end

local function redrawInputBox(inputbox)
  setToInputColors()
  term.gpu().fill(inputbox.x, inputbox.y, inputbox.w, 1, " ")
  term.setCursor(inputbox.x, inputbox.y)
  term.write(inputbox.value:sub(inputbox.scroll, inputbox.scroll + inputbox.w))
  if inputbox == inputboxselected then
    term.setCursor(inputbox.x + #inputbox.value, inputbox.y)
    term.write("_")
  end
end

-- Draws a progress bar on the bottom of the window.
-- Progress must be out of 100.
local function drawProgressBar(progress)
  local barwidth = ww - 2
  setToProgressColors()
  term.gpu().fill(xoffset+1, yoffset+wh-2, math.floor(progress/100*barwidth), 1, " ")
  setToInputColors()
  term.gpu().fill(math.floor(xoffset+1+progress/100*barwidth), yoffset+wh-2, math.floor((100-progress)/100)*barwidth, 1, " ")
end

local function installButton_press()
  local dlprogram = require("dlprogram")
  local currentFileBytes = 0
  for state, arg in dlprogram.download(program.serveraddr, program.uid, version.name, inputboxes[1].value) do
    setToNormalColors()
    term.setCursor(xoffset+1, yoffset+wh-3)
    if state == dlprogram.states.sentfirstpacket then
      term.write("Esperando al servidor...")
    elseif state == dlprogram.states.newfile then
      term.write("Descargando "..arg.."...")
      currentFileBytes = 0
    elseif state == dlprogram.states.dlfile then
      currentFileBytes = currentFileBytes + arg
      term.write("Descargando "..dlprogram.currentfile.."... ("..currentFileBytes.."B)")
    elseif state == dlprogram.states.iderror then
      term.write("ERROR! Parando descarga...")
      break
    elseif state == dlprogram.states.fileerror then
      term.write("Error de archivo!")
      break
    else
      term.write(state)
    end
    drawProgressBar(dlprogram.downloadedbytes/version.size*100)   
  end
  term.setCursor(xoffset+1,yoffset+wh-2)
  setToProgressColors()
  term.write("Terminado!")
  require("os").sleep(3)
  exit = true
end

-- buttons have x, y, content, callback
local buttons = {}
local function createButtons()
  buttons = {}
  table.insert(buttons, {x=xoffset+ww-#installstring-1, y=yoffset+wh-2, content=installstring, callback=installButton_press})
end

local function drawContents()
  setToNormalColors()
  term.setCursor(xoffset + 2, yoffset + 2)
  term.write(dlstring)
  setToInputColors()
  for i, inputbox in ipairs(inputboxes) do
    redrawInputBox(inputbox)
  end
  setToTitleColors()
  for i, button in ipairs(buttons) do
    term.setCursor(button.x, button.y)
    term.write(button.content)
  end
end

local function processEvents(name, ...)
  local args = table.pack(...)
  if name == "touch" then
    local x, y = math.floor(args[2]), math.floor(args[3])
    if x == xoffset and y == yoffset then -- Exit button
      return true
    end
    for i, button in ipairs(buttons) do
      if x >= button.x and x-button.x < #button.content and y == button.y then
        button.callback()
      end
    end
    for i, inputbox in ipairs(inputboxes) do
      if x >= inputbox.x and x-inputbox.x < inputbox.w and y == inputbox.y then
        inputboxselected = inputbox
        term.setCursor(inputbox.x + #inputbox.value, inputbox.y)
        -- term.setCursorBlink(true) doesn't work... let's do our own variation
        setToInputColors()
        term.write("_") -- Done!
        return
      end
    end
    if inputboxselected ~= nil then
      inputboxselected.value = fs.canonical(inputboxselected.value).."/"
      do
        local lastselection = inputboxselected
        inputboxselected = nil -- Reset inputboxselected if clicked away
        redrawInputBox(lastselection)
      end
    end
  elseif name == "key_down" then
    if inputboxselected == nil then return end
    local code, char = args[3], string.char(args[2])
    if args[2] == 0 or char == "\n" or char == "\t" or char == "\r" then return end -- Do not allow special characters (Shift, control, etc)
    -- The `char` argument actually returns characters already uppercased or shifted when neccesary, so we don't have
    -- to check for any special keys!
    if args[2] == 8 then -- Backspace
      inputboxselected.value = inputboxselected.value:sub(1, -2)
    else
      inputboxselected.value = inputboxselected.value .. char
    end
    redrawInputBox(inputboxselected)
  end
end

function dlmenu.show(prg, ver)
  program = prg
  version = ver
  defaultdlpath = "/prg/"..prg.uid.."/"
  createInputBoxes()
  createButtons()
  drawTitle()
  drawContents()
  while true do
    if processEvents(event.pull()) == true or exit then return end
  end
end

return dlmenu
