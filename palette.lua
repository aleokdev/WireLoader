local palette = {}
local term = require("term")
palette.monochrome = term.gpu().getDepth() == 1

if not palette.monochrome then
  -- Set the palette colors
  palette.colors = {title=1,status=2,download=3, bg=4, winbg=5}
  local palettecolors = {0xffffff,0x339200,0x0092ff, 0x0f0f0f,0x1e1e1e}

  for name, value in pairs(palette.colors) do
    term.gpu().setPaletteColor(value, palettecolors[value])
  end
end

return palette
