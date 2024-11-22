local Fader = {}
Fader.__index = Fader

function Fader.new(index, grid, height, value)
    local self = setmetatable({}, Fader)
    self.grid = grid
    self.index = index
    self.value = value and value or 0
    
    self.coords = {}
    -- parameterize height
    for j = 1, height do
        -- TODO: parameterize offset
        table.insert(self.coords, {index, 9 - j})
    end
    return self
end

function Fader:setValue(value)
   self.value = value
end

function Fader:getCoords()
    return self.coords
end

function Fader:contains(x, y)
   for idx, cds in ipairs(self.coords) do
      -- TODO fix this
      if cds[1] == x and cds[2] == y then
         return true
      else
         return false
      end
   end
end

function Fader:draw()
   for i, coords in ipairs(self.coords) do
      -- TODO: parameterize offset
      self.grid:led(coords[1], coords[2], ((9 - coords[2]) > self.value) and 5 or 15)
   end
end

return Fader
