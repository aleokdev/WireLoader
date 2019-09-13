local palette = require("palette")

local term = require("term")
local modem = require("component").modem
local event = require("event")
local prgmenu = {}
local programport = 3200
local program = {}
local w,h = term.gpu().getResolution()
local downloadtext = "Descargar"

local function setToTitleColors()
  term.gpu().setBackground(palette.monochrome and 0xffffff or palette.colors.title, not palette.monochrome)
  term.gpu().setForeground(0, false)
end
local function setToSubtitleColors()
  term.gpu().setBackground(palette.monochrome and 0xffffff or palette.colors.status, not palette.monochrome)
  term.gpu().setForeground(palette.monochrome and 0 or 0xffffff)
end
local function setToNormalColors()
  term.gpu().setBackground(palette.monochrome and 0 or palette.colors.bg, not palette.monochrome)
  term.gpu().setForeground(0xffffff)
end
local function setToDownloadColors()
  term.gpu().setBackground(palette.monochrome and 0 or palette.colors.bg, not palette.monochrome)
  term.gpu().setForeground(palette.monochrome and 0xffffff or palette.colors.download, not palette.monochrome)
end

local scrollval = 0
local downloadbuttons = {}
local function draw()
  setToNormalColors()
  term.clear()
  local offset = scrollval+1
  term.setCursor(1,offset)
  setToTitleColors()
  term.clearLine()
  local title = program.name
  term.setCursor(w/2-#title/2, offset)
  print(title)
  term.setCursor(1,1)
  print("<-")
  offset = offset + 1
  term.setCursor(1,offset)
  setToSubtitleColors()
  term.clearLine()
  term.write("Descripción")
  offset = offset + 1
  setToNormalColors()
  term.setCursor(1, offset)
  if program.description == nil then
    term.write("Cargando descripción...")
    offset = offset + 2
  else
    term.write(program.description)
    offset = offset + math.ceil(#program.description / w) + 1
  end
  setToSubtitleColors()
  term.setCursor(1, offset)
  term.clearLine()
  term.write("Versiones")
  setToNormalColors()
  offset = offset + 1
  term.setCursor(1, offset)
  if program.version == "_NOBIN" then
    term.write("No hay versiones disponibles para descarga.")
  elseif program.versions == nil then
    term.write("Cargando versiones...")
  else
    downloadbuttons = {}
    for i, version in ipairs(program.versions) do
      term.setCursor(1, offset)
      setToNormalColors()
      print(version.name)
      term.setCursor(w/5, offset)
      setToDownloadColors()
      print(downloadtext)
      table.insert(downloadbuttons, {ver=version, x=w/5, y=offset})
      offset = offset + 1
    end
  end
end

local function processEvents(name, ...)
  local args = table.pack(...)
  if name == "scroll" then
    scrollval = scrollval + args[4] -- add scrollDir
    if scrollval > 0 then
      scrollval = 0
    end
    draw()
  elseif name == "modem_message" then
    local payload = {table.unpack(args, 5, #args)}
    if payload[1] == "prgdesc" then
      local uid = payload[2]
      local desc = payload[3]
      if uid == program.uid then
        program.description = desc
        draw()
      end
    end
    if payload[1] == "prgver" then
      if program.versions == nil then program.versions = {} end
      table.insert(program.versions, {name=payload[2], size=payload[3]})
      draw()
    end
  elseif name == "touch" then
    local x, y = args[2], args[3]
    if (x == 1 or x == 2) and y == 1 then
      return true
    end
    -- downloadbuttons is array of {ver, x, y}
    for i, button in ipairs(downloadbuttons) do
      if x >= button.x and x < (button.x + #downloadtext) then
        if y == button.y then -- Button was hit
          local dlmenupath = "/mnt/"..require("filesystem").proxy("WireLoader").fsnode.name.."/dlmenu.lua"
          dofile(dlmenupath).show(program, button.ver)
          draw()
        end
      end
    end
  end
end

function prgmenu.show(prg)
  program = prg
  -- Reset info values
  program.description = nil
  program.versions = nil
  program.requirements = nil
  -- Get program description
  modem.send(program.serveraddr, programport, "prgdesc", prg.uid)
  -- Get program versions (If there are any)
  if program.version ~= "_NOBIN" then
    modem.send(program.serveraddr, programport, "prgvers", prg.uid)
  end
  -- Get program requirements
  modem.send(program.serveraddr, programport, "prgreqs", prg.uid)
  term.gpu().setBackground(0)
  term.clear()
  draw()
  while true do
    if processEvents(event.pull()) then return end
  end
end

return prgmenu
