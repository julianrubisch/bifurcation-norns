-- One arc ring per grain voice. Turn: where in the file the grains start (the center).
-- Shift (the key) + turn: spray, how far from the center each new grain may start.
-- The display covers -120..+120 degrees around the top: the left end is the file start, the
-- right end its end. It shows the file's ends, the spray's min and max, one moving playhead per
-- sounding grain, and the center brightest.
local GrainArc = {}

local VOICES = 3
local FPS = 30
local SWEEP_DEG = 240
-- turning a ring through the drawn sweep moves the center across the whole file
-- (arc reports 1024 ticks per revolution)
local TICKS_PER_SWEEP = 1024 * SWEEP_DEG / 360
local LED_DEG = 360 / 64
local MAX_SPRAY = 5 -- seconds, matches the param
-- dense, long grains would otherwise light the whole ring
local MAX_PLAYHEADS = 24

local LEVEL = { ends = 3, bounds = 7, playhead = 10, center = 15 }

-- played with the USB port on the right: the device is turned 180° from monome's native
-- orientation, so ring 1 is the rightmost encoder and LED 1 points down. Voice 1 sits on the
-- left; set to false for USB on the left.
local USB_RIGHT = true

local a
local info = {}
local shift = false

local function ring_for(voice)
  return USB_RIGHT and (5 - voice) or voice
end

local function voice_for(ring)
  return USB_RIGHT and (5 - ring) or ring
end

local function led_for(p)
  local deg = (util.clamp(p, 0, 1) - 0.5) * SWEEP_DEG
  local offset = USB_RIGHT and 32 or 0
  return (math.floor(deg / LED_DEG + 0.5) + offset) % 64 + 1
end

local function pos_id(voice) return "grain_"..voice.."_pos" end
local function spray_id(voice) return "grain_"..voice.."_spray" end

-- the engine counts grains, so a changed count means at least one new grain began; only the
-- newest one's start is known, which is enough for the eye
local function grain_started(voice, count)
  local v = info[voice]
  if v.count ~= nil and count ~= v.count and v.file > 0 and v.dur > 0 then
    table.insert(v.playheads, { pos = v.start, vel = v.rate / v.file, life = v.dur })
    if #v.playheads > MAX_PLAYHEADS then table.remove(v.playheads, 1) end
  end
  v.count = count
end

function GrainArc.redraw()
  a:all(0)
  for voice = 1, VOICES do
    local ring, v = ring_for(voice), info[voice]
    local set = params:get(pos_id(voice))
    a:led(ring, led_for(0), LEVEL.ends)
    a:led(ring, led_for(1), LEVEL.ends)
    a:led(ring, led_for(set - v.spray), LEVEL.bounds)
    a:led(ring, led_for(set + v.spray), LEVEL.bounds)
    for i = #v.playheads, 1, -1 do
      local p = v.playheads[i]
      if p.pos >= 0 and p.pos <= 1 then a:led(ring, led_for(p.pos), LEVEL.playhead) end
      p.pos = p.pos + p.vel / FPS
      p.life = p.life - 1 / FPS
      if p.life <= 0 then table.remove(v.playheads, i) end
    end
    a:led(ring, led_for(set), LEVEL.center)
  end
  a:refresh()
end

function GrainArc.init()
  a = arc.connect()

  a.key = function(n, z)
    shift = z == 1
  end

  a.delta = function(n, d)
    local voice = voice_for(n)
    if voice > VOICES then return end
    if shift then
      -- geared so a spray marker follows the hand like the center does
      local file = info[voice].file > 0 and info[voice].file or 10
      params:set(spray_id(voice), util.clamp(params:get(spray_id(voice)) + d / TICKS_PER_SWEEP * file, 0, MAX_SPRAY))
    else
      params:set(pos_id(voice), util.clamp(params:get(pos_id(voice)) + d / TICKS_PER_SWEEP, 0, 1))
    end
  end

  local polls = { start = "grainStart", dur = "grainDur", rate = "grainRate", spray = "grainSpray", file = "grainFile" }
  for voice = 1, VOICES do
    info[voice] = { start = 0, dur = 0, rate = 1, spray = 0, file = 0, count = nil, playheads = {} }
    for key, name in pairs(polls) do
      local p = poll.set(name..voice, function(value) info[voice][key] = value end)
      p.time = 1 / FPS
      p:start()
    end
    local c = poll.set("grainCount"..voice, function(value) grain_started(voice, value) end)
    c.time = 1 / FPS
    c:start()
  end

  clock.run(function()
    while true do
      clock.sleep(1 / FPS)
      GrainArc.redraw()
    end
  end)
end

return GrainArc
