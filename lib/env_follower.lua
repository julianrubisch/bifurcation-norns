-- Envelope follower for the Microcosm's filter (CC 8). The Monolit's Filter fader sends on
-- channel 16, which the Microcosm ignores, so the norns is the only sender of CC 8: the fader
-- (through microcosm_cc) is the base, the master envelope is added on top.
local EnvFollower = {}
local ControlSpec = require "controlspec"

local FILTER_CC = 8
local RATE = 50 -- Hz; well inside what a DIN cable carries
local CEIL_DB = -6

local base = 127 -- fully open until the fader moves; the norns can't ask where it is
local on = false
local env_db = -120
local last_sent

local function send(value)
  value = util.clamp(math.floor(value + 0.5), 0, 127)
  if value ~= last_sent then
    m:cc(FILTER_CC, value, params:get("midi_channel"))
    last_sent = value
  end
end

local function amount()
  local floor = params:get("env_floor")
  return util.clamp((env_db - floor) / (CEIL_DB - floor), 0, 1)
end

local function update()
  if on then
    send(base + params:get("env_depth") / 100 * 127 * amount())
  end
end

function EnvFollower.set_base(value)
  base = value
  if not on then send(base) end
end

function EnvFollower.add_params()
  params:add_separator("Filter follower")
  params:add_option("env_on", "Follower", {"off", "on"}, 1)
  params:set_action("env_on", function(i)
    on = i == 2
    -- back to the bare fader, or the filter stays wherever the envelope left it
    if not on then send(base) end
  end)
  -- the Monolit button holds the state, so a pset must not flip it
  params:set_save("env_on", false)
  params:add_control("env_depth", "Follower depth",
    ControlSpec.new(-100, 100, 'lin', 1, 50, "%"))
  params:add_control("env_floor", "Follower floor",
    ControlSpec.new(-72, -12, 'lin', 1, -40, "dB"))
  params:add_control("env_attack", "Follower attack",
    ControlSpec.new(0.001, 1, 'exp', 0, 0.01, "s"))
  params:set_action("env_attack", function(s) engine.envAttack(s) end)
  params:add_control("env_release", "Follower release",
    ControlSpec.new(0.01, 4, 'exp', 0, 0.3, "s"))
  params:set_action("env_release", function(s) engine.envRelease(s) end)
end

function EnvFollower.init()
  local p = poll.set("envLevel", function(db)
    env_db = db
    update()
  end)
  -- engine classes compile only when SuperCollider starts, so an engine older than this file
  -- has no poll yet; the script must still come up
  if p == nil then
    print("env_follower: engine has no envLevel poll, restart SuperCollider")
    return
  end
  p.time = 1 / RATE
  p:start()

  -- add_params runs after the startup bang, so the engine gets these directly
  engine.envAttack(params:get("env_attack"))
  engine.envRelease(params:get("env_release"))
end

return EnvFollower
