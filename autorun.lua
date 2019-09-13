local function tableLength(t)
  local count = 0
  for _ in pairs(t) do count = count + 1 end
  return count
end

if tableLength(require("component").list("modem")) == 0 then
  print("Necesitas una Network Card conectada a Sarvanet para ejecutar WireLoader.")
  return
end

do
  -- When autorunning the program, the working directory is set to /, thus require-ing files from the disk doesn't work.
  -- To fix this, we add the disk's path to the list of paths require has to search in for a given file.
  local package = require("package")
  package.path = package.path .. ";/mnt/"..require("filesystem").proxy("WireLoader").fsnode.name.."/?.lua"
end
local palette = require("palette")
local term = require("term")
local modem = require("component").modem
local w, h = term.gpu().getResolution()
local version = "WireLoader v1.0"
local programport = 3200
local reloadstring = "Recargar"
local exitstring = "Salir"

local function drawTitle()
  term.gpu().setForeground(0, false)
  term.gpu().setBackground(palette.monochrome and 0xffffff or palette.colors.title, not palette.monochrome)
  term.clearLine()
  term.setCursor(2, 1)
  term.write(reloadstring)
  term.setCursor(w / 2 - #version / 2, 1)
  term.write(version)
  term.setCursor(w - #exitstring, 1)
  term.write(exitstring)
  term.gpu().setForeground(0xFFFFFF)
  term.gpu().setBackground(0)
end

local function setStatus(status)
  term.gpu().setBackground(palette.monochrome and 0 or palette.colors.status, not palette.monochrome)
  term.gpu().setForeground(0xffffff)
  term.setCursor(1,2)
  term.clearLine()
  term.setCursor(w / 2 - #status/2, 2)
  term.write(status)
end

local programs = {}
local function updateProgramList()
  term.gpu().setBackground(palette.monochrome and 0 or palette.colors.bg, not palette.monochrome)
  term.gpu().setForeground(0xffffff)
  term.gpu().fill(1,3,w,h-2, " ")
  term.setCursor(1,3)
  term.clearLine()
  term.setCursor(1,3)
  print("Nombre")
  term.setCursor(w / 4, 3)
  print("Versión")
  term.setCursor(w / 4 * 2, 3)
  print("Tamaño")
  term.setCursor(w / 4 * 3, 3)
  print("Creador")
  for i, program in ipairs(programs) do
    term.setCursor(1,i+3)
    print(program.name)
    term.setCursor(w/4,i+3)
    if program.version == "_NOBIN" then
      print("Próximamente")
    else
      print(program.version)
    end
    term.setCursor(w/4*2,i+3)
    if program.version ~= "_NOBIN" then
      print(math.floor(program.size).." B")
    end
    
    term.setCursor(w/4*3, i+3)
    print(program.creator)
  end
end

local function requestPrograms()
  modem.broadcast(programport, "retrieve")
end

local function processEvents(name, ...)
  local args = table.pack(...)
  if name == "modem_message" then
    local addr = args[2]
    local payload = {table.unpack(args, 5, #args)}
    if payload[1] == "prg" then
      -- check for duplicates (only accept one)
      -- todo: allow for multiple servers hosting same file (make
      -- program.serveraddr a table)
      for i, program in ipairs(programs) do
        if program.uid == payload[2] then
          setStatus("Saltando "..program.name.." duplicado.")
          return
        end
      end
      local programtoinsert = {}
      programtoinsert.uid = payload[2]
      programtoinsert.name = payload[3]
      programtoinsert.version = payload[4]
      programtoinsert.size = payload[5]
      programtoinsert.creator = payload[6]
      programtoinsert.serveraddr = addr
      table.insert(programs, programtoinsert)
      programtoinsert = nil
      updateProgramList()
      if #programs == 1 then
        setStatus("Se ha encontrado 1 programa")
      else
        setStatus("Se han encontrado "..#programs.." programas")
      end
    end
  end
  if name == "touch" then
    local tx, ty = args[2], args[3]
    if ty == 1 then
      if tx > 1 and tx-1 <= #reloadstring then
        programs = {}
        updateProgramList()
        requestPrograms()
      end
      if tx >= w-#reloadstring then
        term.clear()
        term.gpu().setBackground(0)
        term.gpu().setForeground(0xFFFFFF)
        term.clear()
        require("os").exit()
      end
      return
    end
    local selectedprogram = programs[ty-3] -- -3 to remove headers and titles
    if selectedprogram == null then return end
    local prgmenupath = "/mnt/"..require("filesystem").proxy("WireLoader").fsnode.name.."/prgmenu.lua"

    local prgmenu = nil
    local status, error = pcall(function() prgmenu = dofile(prgmenupath) end)
    if error ~= nil then print(error) end -- will print out errors that are not critical
    prgmenu.show(selectedprogram)
    term.clear()
    drawTitle()
    setStatus("")
    updateProgramList()
  end
end

term.clear()

drawTitle()

setStatus("Conectando al servidor...")
updateProgramList()
local event = require("event")
modem.open(programport)
requestPrograms()

while true do
  processEvents(event.pull(math.huge))
end
