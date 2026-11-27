-- Bifurcation
-- ...


engine.name = 'BIFURCATION'

g = grid.connect()
-- the Microcosm and the Monolit; the port params pick both by name in add_params
m = midi.connect(1)
monolit = midi.connect(1)

bifurcation_setup = include 'lib/bifurcation'
Fader = include 'lib/fader'
Crossfader = include 'lib/crossfader'
local GrainArc = include 'lib/grain_arc'
local EnvFollower = include 'lib/env_follower'
local MicrocosmCC = include 'lib/microcosm_cc'

local UI = require 'ui'

local tabs = UI.Tabs.new(1, {"Mixer", "Log", "SyncSaw", "PWM", "Grain"})
local dials

local tabLeds = {{1,1}, {2,1}, {3,1}, {4,1}, {5,1}}
local psetLeds = {{9,1}, {10,1}, {11,1}, {12,1}, {13,1}, {14,1}, {15,1}, {16,1}}
local activePset = 0

local mixer = {}
local klankDecayFaders = {}
local klankGainFaders = {}
local modulatorFreqCrossfaders = {}
local rDevCrossfaders = {}
local pwmBaseFreqFaders = {}
local pwmIntervalFaders = {}
local grainRateFaders = {}
local grainDurationFaders = {}

local momentaryKeys = {}

local screen_dirty = false

for i = 1, 12 do
   mixer["channel_"..i.."_amp"] = Fader.new(i, g, 5, 1)
end

local masterVolumeFader = Fader.new(16, g, 5, 1)

-- the five mixer keys (off + four steps) map onto the six level options, so psets keep their
-- meaning: off, -24, -12, -6, 0 dB; -36 is menu-only and shows as off
local MIXER_KEY_OPTIONS = {1, 3, 4, 5, 6}

local function mixer_key_height(option)
   local height = 1
   for h, o in ipairs(MIXER_KEY_OPTIONS) do
      if o <= option then height = h end
   end
   return height
end

-- Saved levels of the channels still sitting at off since a grid load, by param id. A save
-- writes these instead of the off, so saving before playing up to the score keeps the score.
local score_targets = {}

-- A pset from the grid leaves the master alone and starts every channel at off, its saved
-- level lit as a target on the fader, so the piece is played up towards it instead of jumping in.
function read_pset_as_score(n)
   local master = params:get("master_volume")
   local ids = { "master_volume" }
   for id in pairs(mixer) do table.insert(ids, id) end
   local actions = {}
   for _, id in ipairs(ids) do
      local p = params:lookup_param(id)
      actions[id] = p.action
      p.action = function() end
   end
   params:read(n)
   for _, id in ipairs(ids) do params:lookup_param(id).action = actions[id] end

   -- the read left master at the slot's value with its action muted; the engine never moved
   params:set("master_volume", master, true)
   masterVolumeFader:setValue(mixer_key_height(master))
   -- the read ran action_read, which cleared these
   for id, fader in pairs(mixer) do
      local saved = params:get(id)
      if saved > 1 then score_targets[id] = saved end
      fader:setTarget(mixer_key_height(saved))
      fader:setValue(1)
      params:set(id, 1, true)
      -- the silent set skips the action, and the engine still plays the previous pset's level
      params:lookup_param(id):bang()
   end
end

for i = 1, 4 do
   klankDecayFaders["syncSaw_"..i.."_klank_decay_lower"] = Fader.new(i, g, 6, 1)
   klankGainFaders["syncSaw_"..i.."_klank_gain"] = Fader.new(i + 5, g, 6, 1)

   rDevCrossfaders["modulator_"..i.."_rdev"] = Crossfader.new(i, g, 5, 3)
   modulatorFreqCrossfaders["modulator_"..i.."_freq"] = Crossfader.new(i, g, 7, 4, 7)

   pwmBaseFreqFaders["pwm_"..i.."_base_freq"] = Fader.new(i, g, 5, 1)
   pwmIntervalFaders["pwm_"..i.."_interval"] = Fader.new(i + 5, g, 6, 1)

   grainRateFaders["grain_"..i.."_rate"] = Crossfader.new(i, g, 7, 6)
   grainDurationFaders["grain_"..i.."_dur"] = Crossfader.new(i, g, 6, 3, 8)
end

for x = 1,16 do -- for each x-column (16 on a 128-sized grid)...
   momentaryKeys[x] = {} -- create a table that holds...
   for y = 1,8 do -- each y-row (8 on a 128-sized grid)!
      momentaryKeys[x][y] = 0
   end
end

function init()
   bifurcation_setup.add_params()
   EnvFollower.add_params()
   MicrocosmCC.add_params()
   GrainArc.init()
   EnvFollower.init()
   MicrocosmCC.init(EnvFollower)
   masterVolumeFader:setValue(mixer_key_height(params:get("master_volume")))
   dials = {
      syncSaw_atk = UI.Dial.new(60, 16, 18, params:get("syncSaw_atk"), 0.01, 1.0, 0.01, 0.01, {}, "s"),
      pwm_env_atk = UI.Dial.new(30, 16, 18, params:get("pwm_env_atk"), 0.01, 1, 0.01, 0.01, {}, "s"),
      pwm_env_rel = UI.Dial.new(80, 16, 18, params:get("pwm_env_rel"), 0.01, 1, 0.01, 0.01, {}, "s")
   }

   params.action_read = function(filename, silent, number)
      score_targets = {}

      for id, dial in pairs(dials) do
         dials[id]:set_value(params:get(id))
      end

      for id, fader in pairs(mixer) do
         fader:setValue(mixer_key_height(params:get(id)))
      end

      for id, fader in pairs(klankDecayFaders) do
         fader:setValue(params:get(id))
      end

      for id, fader in pairs(klankGainFaders) do
         fader:setValue(params:get(id))
      end

      for id, fader in pairs(rDevCrossfaders) do
         fader:setValue(params:get(id))
      end

      for id, fader in pairs(modulatorFreqCrossfaders) do
         fader:setValue(params:get(id))
      end

      for id, fader in pairs(pwmBaseFreqFaders) do
         fader:setValue(params:get(id))
      end

      for id, fader in pairs(pwmIntervalFaders) do
         fader:setValue(params:get(id))
      end
      
      for id, fader in pairs(grainRateFaders) do
        fader:setValue(params:get(id))
      end
      
      for id, fader in pairs(grainDurationFaders) do
        fader:setValue(params:get(id))
      end

      masterVolumeFader:setValue(mixer_key_height(params:get("master_volume")))

      MicrocosmCC.recall(filename)

      screen_dirty = true
   end

   -- norns has already written the file. A channel moved from the menu counts as played too,
   -- hence the check for off.
   params.action_write = function(filename, name, number)
      if next(score_targets) == nil then return end
      local lines = {}
      for line in io.lines(filename) do
         local id = line:match('^"(channel_%d+_amp)": ')
         if id and score_targets[id] and params:get(id) == 1 then
            line = string.format('"%s": %d', id, score_targets[id])
         end
         table.insert(lines, line)
      end
      local f = io.open(filename, "w")
      f:write(table.concat(lines, "\n") .. "\n")
      f:close()
   end

   screen_dirty = true
   
   last_cpu_peak = 0
   last_cpu_avg = 0
   last_amp_out_l = 0
   last_amp_out_r = 0

   cpu_peak_tracker = poll.set("cpu_peak")
   cpu_peak_tracker.callback = function(x)
     if x > 0 then
        last_cpu_peak = x
        screen_dirty = true
     end
   end
   
   cpu_avg_tracker = poll.set("cpu_avg")
   cpu_avg_tracker.callback = function(x)
     if x > 0 then
        last_cpu_avg = x
        screen_dirty = true
     end
   end
   
   amp_out_l_tracker = poll.set("outputAmpL")
   amp_out_l_tracker.callback = function(x)
        last_amp_out_l = x
        screen_dirty = true
   end
   
   amp_out_r_tracker = poll.set("outputAmpR")
   amp_out_r_tracker.callback = function(x)
        last_amp_out_r = x
        screen_dirty = true
   end
   
   screen_timer = clock.run(
    function()
      while true do
        clock.sleep(1/15)
        
        cpu_peak_tracker:update()
        cpu_avg_tracker:update()
        amp_out_l_tracker:update()
        amp_out_r_tracker:update()
        
        if screen_dirty then
          redraw()
          screen_dirty = false
        end
        
        -- every frame, not on change: a grid replugged after a static hit comes back by itself
        grid_redraw()
      end
    end
   )
end

function enc(n, d)
   if n == 1 then
      tabs:set_index_delta(d, false)
   elseif n == 2 then
      if tabs.index == 3 then
         params:delta("syncSaw_atk", d / 2)
         dials["syncSaw_atk"]:set_value(params:get("syncSaw_atk"))
      elseif tabs.index == 4 then
         params:delta("pwm_env_atk", d / 2)
         dials["pwm_env_atk"]:set_value(params:get("pwm_env_atk"))
      end
   elseif n == 3 then
      if tabs.index == 4 then
         params:delta("pwm_env_rel", d / 2)
         dials["pwm_env_rel"]:set_value(params:get("pwm_env_rel"))
      end
   end

   screen_dirty = true
end

-- register tab keys
function g.key(x, y, z)
   momentaryKeys[x][y] = z
   if y == 2 and x <= 12 then engine.triggerDelay(x, z) end
   
   -- check if the pressed key is in the tabLeds range
   for idx, coord in ipairs(tabLeds) do
      if coord[1] == x and coord[2] == y then
         tabs:set_index(idx)

         break
      end
   end

   -- check if the pressed key is in the presets range
   for idx, coord in ipairs(psetLeds) do
      -- on press only; the release would read the pset a second time
      if coord[1] == x and coord[2] == y and z == 1 then
         local pset = x - 8
         read_pset_as_score(pset)
         activePset = pset

         break
      end
   end

   -- mixer
   if tabs.index == 1 then
      for id, fader in pairs(mixer) do
         for idx, coords in ipairs(fader:getCoords()) do
            if coords[1] == x and coords[2] == y then
               score_targets[id] = nil
               fader:setValue(9 - coords[2])
               params:set(id, MIXER_KEY_OPTIONS[9 - coords[2]])

               break
            end
         end
      end

      for idx, coords in ipairs(masterVolumeFader:getCoords()) do
         if coords[1] == x and coords[2] == y then
            masterVolumeFader:setValue(9 - coords[2])
            params:set("master_volume", MIXER_KEY_OPTIONS[9 - coords[2]])
               
            break
         end
      end
   -- logistic
   elseif tabs.index == 2 then
      for id, crossfader in pairs(rDevCrossfaders) do
         for idx, coords in ipairs(crossfader:getCoords()) do
            if coords[1] == x and coords[2] == y then
               crossfader:setValue(coords[1])
               params:set(id, coords[1])
               
               break
            end
         end
      end

      for id, crossfader in pairs(modulatorFreqCrossfaders) do
         for idx, coords in ipairs(crossfader:getCoords()) do
            if coords[1] == x and coords[2] == y then
               crossfader:setValue(coords[1] - 7)
               params:set(id, coords[1] - 7)
               
               break
            end
         end
      end
      -- syncsaw
   elseif tabs.index == 3 then
      for id, fader in pairs(klankDecayFaders) do
         for idx, coords in ipairs(fader:getCoords()) do
            if coords[1] == x and coords[2] == y then
               fader:setValue(9 - coords[2])
               params:set(id, 9 - coords[2])
               
               break
            end
         end
      end
      for id, fader in pairs(klankGainFaders) do
         for idx, coords in ipairs(fader:getCoords()) do
            if coords[1] == x and coords[2] == y then
               fader:setValue(9 - coords[2])
               params:set(id, 9 - coords[2])
               
               break
            end
         end
      end
      -- pwm
   elseif tabs.index == 4 then
      for id, fader in pairs(pwmBaseFreqFaders) do
         for idx, coords in ipairs(fader:getCoords()) do
            if coords[1] == x and coords[2] == y then
               fader:setValue(9 - coords[2])
               params:set(id, 9 - coords[2])
               
               break
            end
         end
      end
      for id, fader in pairs(pwmIntervalFaders) do
         for idx, coords in ipairs(fader:getCoords()) do
            if coords[1] == x and coords[2] == y then
               fader:setValue(9 - coords[2])
               params:set(id, 9 - coords[2])
               
               break
            end
         end
      end
     -- grain
   elseif tabs.index == 5 then
      for id, crossfader in pairs(grainRateFaders) do
         for idx, coords in ipairs(crossfader:getCoords()) do
            if coords[1] == x and coords[2] == y then
               crossfader:setValue(coords[1])
               params:set(id, coords[1])
               
               break
            end
         end
      end

      for id, crossfader in pairs(grainDurationFaders) do
         for idx, coords in ipairs(crossfader:getCoords()) do
            if coords[1] == x and coords[2] == y then
               crossfader:setValue(coords[1] - 8)
               params:set(id, coords[1] - 8)
               
               break
            end
         end
      end
   end

   screen_dirty = true
end


function redraw()
   screen.clear()
   
   tabs:redraw()
   
   -- mixer
   if tabs.index == 1 then

      -- logistic
   elseif tabs.index == 2 then
      -- mod
   elseif tabs.index == 3 then
      dials["syncSaw_atk"]:redraw()
      screen.move(69, 50)
      screen.text_center("SyncSaw Attack")
   elseif tabs.index == 4 then
      dials["pwm_env_atk"]:redraw()
      dials["pwm_env_rel"]:redraw()
      screen.move(39, 50)
      screen.text_center("PWM Atk")
      screen.move(89, 50)
      screen.text_center("PWM Rel")
   end
   
   draw_status_line()

   screen.update()
end

-- status line geometry (bottom 8 px), matching susurrus; L over R
local STATUS_RULE_Y = 55.5
local STATUS_TEXT_Y = 63
local METER_X, METER_W, METER_H = 20, 30, 2
local METER_Y = { 57, 60 }
local FLOOR_DB = -60

-- amps are linear; a linear width would leave a healthy -20 dBFS signal at 10% of the bar
local function meter_frac(amp)
   if amp <= 0 then return 0 end
   return util.clamp(util.linlin(FLOOR_DB, 0, 0, 1, 20 * math.log(amp, 10)), 0, 1)
end

function draw_status_line()
   screen.level(1)
   screen.move(0, STATUS_RULE_Y)
   screen.line(128, STATUS_RULE_Y)
   screen.stroke()

   screen.level(3)
   screen.move(0, STATUS_TEXT_Y)
   screen.text("out")

   for i, amp in ipairs({ last_amp_out_l, last_amp_out_r }) do
      local y = METER_Y[i]
      screen.level(2)
      screen.rect(METER_X + 0.5, y + 0.5, METER_W, METER_H)
      screen.stroke()

      local frac = meter_frac(amp)
      if frac > 0 then
         screen.level(15)
         screen.rect(METER_X + 0.5, y + 0.5, math.max(1, frac * METER_W), METER_H)
         screen.fill()
      end

      -- clip pip: a dB bar is already mostly full for a healthy signal, so clipping needs its own mark
      if amp >= 0.99 then
         screen.level(15)
         screen.rect(METER_X + METER_W + 2, y + 0.5, 1, METER_H)
         screen.fill()
      end
   end

   screen.level(3)
   screen.move(128, STATUS_TEXT_Y)
   -- %.0f, not %d: the cpu polls are floats and lua 5.3's %d rejects non-integers
   screen.text_right(string.format("cpu %.0f%% pk %.0f%%", last_cpu_avg, last_cpu_peak))
end

function grid_redraw()
   g:all(0)
   
   -- GLOBAL KEYS
   -- set active tab
   g:led(tabLeds[tabs.index][1], tabLeds[tabs.index][2], 15)

   -- set active pset, if any
   if activePset > 0 then
      g:led(psetLeds[activePset][1], psetLeds[activePset][2], 15)
   end 
   
   -- trigger delay envelope
   for i = 1,12 do
      g:led(i, 2, momentaryKeys[i][2] * 15)
   end

   if tabs.index == 1 then
      for id, fader in pairs(mixer) do
         fader:draw()
      end
      
      masterVolumeFader:draw()
   elseif tabs.index == 2 then
      for id, crossfader in pairs(rDevCrossfaders) do
         crossfader:draw()
      end

      for id, crossfader in pairs(modulatorFreqCrossfaders) do
         crossfader:draw()
      end
   elseif tabs.index == 3 then
      for id, fader in pairs(klankDecayFaders) do
         fader:draw()
      end

      for id, fader in pairs(klankGainFaders) do
         fader:draw()
      end
   elseif tabs.index == 4 then
      for id, fader in pairs(pwmBaseFreqFaders) do
         fader:draw()
      end

      for id, fader in pairs(pwmIntervalFaders) do
         fader:draw()
      end
   elseif tabs.index == 5 then
      for id, crossfader in pairs(grainRateFaders) do
         crossfader:draw()
      end

      for id, crossfader in pairs(grainDurationFaders) do
         crossfader:draw()
      end
   end
   
   g:refresh()
end
