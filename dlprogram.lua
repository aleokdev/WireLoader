-- protocol ops:
-- c->s prgdl <uid> <version>
-- s->c prgfile <uid> <path>
-- s->c prgdata <uid> <bin data>
-- Check protocol.txt for more info

local dlprogram = {}
local fs = require("filesystem")
local term = require("term")
local modem = require("component").modem
local event = require("event")
local programport = 3200
dlprogram.states = {
  sentfirstpacket=10, -- Sent prgdl packet to server.
  newfile=11, -- Got a prgfile packet, and will download that file. This is returned along with the name of the file to receive.
  dlfile=12, -- Got a prgdata packet. This is returned along with the number of bytes downloaded.
  error=99, -- Anything after this is an error.
  iderror=100, -- Program being received isn't the one specified. This is returned along with the UID of the program being received.
  fileerror=101 -- Could not create a file. Returned along the file that couldn't be created.
}

function dlprogram.download(_serveraddr, _uid, _version, _path)
  local pathCreated = false
  local hasStarted = false
  dlprogram.downloadedbytes = 0 -- this may generate errors in the future: managing global vars here?
  dlprogram.currentfile = nil
  local serveraddr, uid, version, path = _serveraddr, _uid, _version, _path
  -- Iterator that downloads an entire program. Yields progress.
  return function()
    if not hasStarted then
      modem.send(serveraddr, programport, "prgdl", uid, version)
      hasStarted = true
      return dlprogram.states.sentfirstpacket
    end
  
    -- encase everything in a while loop, in case event.pull pulls another event that is not modem_message.
    while true do

    local name, _, address, _p, _d, arg1, arg2, arg3 = event.pull()
    if name == "modem_message" then
      if address ~= serveraddr then goto continue end
      if arg1 ~= "prgfile" and arg1 ~= "prgdata" and arg1~="prgdend" then goto continue end

      if arg2 ~= uid then
        return dlprogram.states.iderror, arg2
      end
      if arg1 == "prgfile" then
        dlprogram.currentfile = arg3
        return dlprogram.states.newfile, arg3
      elseif arg1 == "prgdata" then
        local writepath = path .. dlprogram.currentfile
        if not fs.exists(writepath) then
          if not fs.exists(fs.path(writepath)) then
            fs.makeDirectory(fs.path(writepath)) -- Create parent dirs if neccesary
          end
          local f = fs.open(writepath, "w")
          if f == nil then
            return dlprogram.states.fileerror, writepath
          end
          f:close()
        end
        dlprogram.downloadedbytes = dlprogram.downloadedbytes + #arg3
        local handle = require("io").open(writepath, "ab")
        handle:write(arg3)
        handle:flush()
        handle:close()
        return dlprogram.states.dlfile, #arg3
      elseif arg1 == "prgdend" then
        return nil
      end
    end
    ::continue::

    end
  end
end

return dlprogram
