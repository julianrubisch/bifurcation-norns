-- The Monolit's Microcosm sliders as params, so a pset recalls them. The norns hears every
-- slider over USB and keeps its last value; on a pset load it sends the values to the
-- Microcosm and to the Monolit, which shows them on its sliders (EXT CC).
local MicrocosmCC = {}

local EnvFollower

-- Time is left out: its slider runs an LFO. Filter comes in on channel 16 and reaches the
-- Microcosm through the follower, which adds its envelope on top.
local CONTROLS = {
  { id = "mc_mix", name = "Mix", cc = 9 },
  { id = "mc_loop_level", name = "Loop level", cc = 13 },
  { id = "mc_space", name = "Space", cc = 12 },
  { id = "mc_filter", name = "Filter", cc = 8, ch = 16 },
  { id = "mc_resonance", name = "Resonance", cc = 15 },
  { id = "mc_repeats", name = "Repeats", cc = 11 },
  { id = "mc_activity", name = "Activity", cc = 6 },
}
local FOLLOWER_CH, FOLLOWER_TOGGLE_CC = 16, 3
-- a program change makes the Microcosm load its preset's own knob values; land after that
local AFTER_PC = 0.2

local function channel(c) return c.ch or params:get("midi_channel") end

local function find(ch, cc)
  for _, c in ipairs(CONTROLS) do
    if c.cc == cc and channel(c) == ch then return c end
  end
end

local function send(c, value)
  monolit:cc(c.cc, value, channel(c))
  -- the filter reaches the Microcosm through the follower, on the Microcosm's channel
  if c.id == "mc_filter" then EnvFollower.set_base(value) else m:cc(c.cc, value, channel(c)) end
end

local function midi_event(data)
  local msg = midi.to_msg(data)
  if msg.type ~= "cc" then return end
  if msg.ch == FOLLOWER_CH and msg.cc == FOLLOWER_TOGGLE_CC then
    params:set("env_on", msg.val > 63 and 2 or 1)
    return
  end
  -- if the Monolit echoes what the norns sends it, recalls come back here as the value the
  -- param already holds
  local c = find(msg.ch, msg.cc)
  if c == nil then return end
  params:set_save(c.id, true)
  params:set(c.id, msg.val, true)
  if c.id == "mc_filter" then EnvFollower.set_base(msg.val) end
end

function MicrocosmCC.add_params()
  params:add_separator("Microcosm (Monolit)")
  for _, c in ipairs(CONTROLS) do
    params:add_number(c.id, c.name, 0, 127, 0)
    params:set_action(c.id, function(value)
      params:set_save(c.id, true)
      send(c, value)
    end)
    -- unknown until its slider moves or a pset brings it: saving the default 0 would make a
    -- later load pull Mix or Repeats to zero
    params:set_save(c.id, false)
  end
end

function MicrocosmCC.init(env_follower)
  EnvFollower = env_follower
  monolit.event = midi_event
  -- a new port needs the handler too; this replaces the port param's own action
  params:set_action("monolit_port", function(i)
    monolit = midi.connect(i)
    monolit.event = midi_event
  end)
end

-- called from params.action_read. A value equal to the one held fires no action during the
-- read, so the file itself says which sliders this pset knows.
function MicrocosmCC.recall(filename)
  local ids = {}
  for _, c in ipairs(CONTROLS) do ids[c.id] = true end
  for line in io.lines(filename) do
    local id = line:match('^"(.-)"')
    if id and ids[id] then params:set_save(id, true) end
  end
  clock.run(function()
    clock.sleep(AFTER_PC)
    for _, c in ipairs(CONTROLS) do
      if params:lookup_param(c.id).save then send(c, params:get(c.id)) end
    end
  end)
end

return MicrocosmCC
