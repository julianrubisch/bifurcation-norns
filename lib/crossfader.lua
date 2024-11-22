local Crossfader = {}
Crossfader.__index = Crossfader

function Crossfader.new(index, grid, width, value, left)
    local self = setmetatable({}, Crossfader)
    self.grid = grid
    self.index = index
    self.value = value and value or 0
    self.left = left and left or 0
    
    self.coords = {}
    -- parameterize width
    for j = 1, width do
        -- TODO: parameterize offset
        table.insert(self.coords, {j + self.left, index + 2})
    end
    return self
end

function Crossfader:setValue(value)
   self.value = value
end

function Crossfader:getCoords()
    return self.coords
end

function Crossfader:draw()
   for i, coords in ipairs(self.coords) do
      self.grid:led(coords[1], coords[2], ((coords[1]) == (self.value + self.left)) and 15 or 5)
   end
end

return Crossfader
