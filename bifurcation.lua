-- Bifurcation
-- ...


engine.name = 'BIFURCATION'

bifurcation_setup = include 'lib/bifurcation'
Fader = include 'lib/fader'
Crossfader = include 'lib/crossfader'

local MusicUtil = require 'musicutil'
local UI = require 'ui'
local Graph = require 'graph'
local FilterGraph = require 'filtergraph'
local Formatters = require 'formatters'

local tabs = UI.Tabs.new(1, {"Mixer", "Logistic", "SyncSaw", "PWM"})
local dials

local tabLeds = {{1,1}, {2,1}, {3,1}, {4,1}}
local psetLeds = {{9,1}, {10,1}, {11,1}, {12,1}, {13,1}, {14,1}, {15,1}, {16,1}}
local activePset = 0

local mixer = {}
local klankDecayFaders = {}
local klankGainFaders = {}
local modulatorFreqCrossfaders = {}
local rDevCrossfaders = {}
local pwmBaseFreqFaders = {}
local pwmIntervalFaders = {}

local momentaryKeys = {}

g = grid.connect()
m = midi.connect(1)

for i = 1, 12 do
   mixer["channel_"..i.."_amp"] = Fader.new(i, g, 5, 1)
end

for i = 1, 4 do
   klankDecayFaders["syncSaw_"..i.."_klank_decay_lower"] = Fader.new(i, g, 6, 1)
   klankGainFaders["syncSaw_"..i.."_klank_gain"] = Fader.new(i + 5, g, 6, 1)

   rDevCrossfaders["modulator_"..i.."_rdev"] = Crossfader.new(i, g, 5, 3)
   modulatorFreqCrossfaders["modulator_"..i.."_freq"] = Crossfader.new(i, g, 7, 4, 7)

   pwmBaseFreqFaders["pwm_"..i.."_base_freq"] = Fader.new(i, g, 5, 1)
   pwmIntervalFaders["pwm_"..i.."_interval"] = Fader.new(i + 5, g, 6, 1)

end

for x = 1,16 do -- for each x-column (16 on a 128-sized grid)...
   momentaryKeys[x] = {} -- create a table that holds...
   for y = 1,8 do -- each y-row (8 on a 128-sized grid)!
      momentaryKeys[x][y] = 0
   end
end

function init()
   bifurcation_setup.add_params()
   dials = {
      syncSaw_atk = UI.Dial.new(60, 20, 18, params:get("syncSaw_atk"), 0.01, 1.0, 0.01, 0.01, {}, "s"),
      pwm_env_atk = UI.Dial.new(30, 20, 18, params:get("pwm_env_atk"), 0.01, 1, 0.01, 0.01, {}, "s"),
      pwm_env_rel = UI.Dial.new(80, 20, 18, params:get("pwm_env_rel"), 0.01, 1, 0.01, 0.01, {}, "s")
   }

   params.action_read = function(filename, silent, number)
      for id, dial in pairs(dials) do
         dials[id]:set_value(params:get(id))
      end

      for id, fader in pairs(mixer) do
         fader:setValue(params:get(id))
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

      redraw()
   end

   redraw()
end

function key(n, z)
   if n == 2 then
   elseif n == 3 then
      -- engine.free_all_notes()
   end
end

function enc(n, d)
   if n == 1 then
      tabs:set_index_delta(d, false)
   elseif n == 2 then
      --   if tabs.index == 1 then
      --     cluster_size = util.clamp(cluster_size + d, 1, 10)
      --     dials["cluster_size"]:set_value(cluster_size)
      if tabs.index == 2 then
         params:delta("dip_atk", d / 2)
         dials["dip_atk"]:set_value(params:get("dip_atk"))
      elseif tabs.index == 3 then
         params:delta("syncSaw_atk", d / 2)
         dials["syncSaw_atk"]:set_value(params:get("syncSaw_atk"))
      elseif tabs.index == 4 then
         params:delta("pwm_env_atk", d / 2)
         dials["pwm_env_atk"]:set_value(params:get("pwm_env_atk"))
      end
   elseif n == 3 then
            --   if tabs.index == 1 then
            --     cluster_width = util.clamp(cluster_width + d, 1, 6)
            --     dials["cluster_width"]:set_value(cluster_width)
        if tabs.index == 2 then
           params:delta("dip_rel", d / 2)
           dials["dip_rel"]:set_value(params:get("dip_rel"))
        
            --     spread = util.clamp(spread + d / 20, 0, 1)
            --     dials["spread"]:set_value(spread)

            --     for i=1,cluster_size do
            --       voice_pan = util.linlin(1, cluster_size, -1. * spread, 1. * spread, i)
            --       params:set(i .. "_pan", voice_pan)
            --     end
            --   elseif tabs.index == 3 then
            --     pan_mod = util.clamp(pan_mod + d / 10, 0., 1.)
            --     dials["pan_mod"]:set_value(pan_mod)
            
            --     pan_amp_range = params:get_range("all_panAmp")
            --     pan_freq_range = params:get_range("all_panFreq")
            --     params:set("all_panAmp", util.linlin(0., 1., pan_amp_range[1], pan_amp_range[2], pan_mod))
            --     params:set("all_panFreq", util.linlin(0., 1., pan_freq_range[1], pan_freq_range[2], pan_mod))
            --   elseif tabs.index == 4 then
            --     params:delta("all_filterQ", d)
            --     dials["filter_q"]:set_value(params:get("all_filterQ"))
            --     filter_graph:edit("lowpass", 12, params:get("all_filterFreq"), params:get("all_filterQ")/20)
            --   elseif tabs.index == 5 then
            --     transposition = util.clamp(transposition + d, -24, 24)
            --     dials["transposition"]:set_value(transposition)
        elseif tabs.index == 4 then
           params:delta("pwm_env_rel", d / 2)
           dials["pwm_env_rel"]:set_value(params:get("pwm_env_rel"))
        end
   end

   redraw()
end

-- register tab keys
function g.key(x, y, z)
   momentaryKeys[x][y] = z
   
   -- check if the pressed key is in the tabLeds range
   for idx, coord in ipairs(tabLeds) do
      if coord[1] == x and coord[2] == y then
         tabs:set_index(idx)

         break
      end
   end

   -- check if the pressed key is in the tabLeds range
   for idx, coord in ipairs(psetLeds) do
      if coord[1] == x and coord[2] == y then
         local pset = x - 8
         params:read(pset)
         activePset = pset

         break
      end
   end

   -- mixer
   if tabs.index == 1 then
      for id, fader in pairs(mixer) do
         for idx, coords in ipairs(fader:getCoords()) do
            if coords[1] == x and coords[2] == y then
               fader:setValue(9 - coords[2])
               params:set(id, 9 - coords[2])
               
               break
            end
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
   end

   redraw()
end


function redraw()
   screen.clear()
   
   tabs:redraw()
   
   -- mixer
   if tabs.index == 1 then
      -- dials["cluster_size"]:redraw()
      -- dials["cluster_width"]:redraw()
      -- screen.move(19, 24)
      -- screen.text_center(cluster_size)
      -- screen.move(19, 52)
      -- screen.text_center(cluster_width)
      -- logistic
   elseif tabs.index == 2 then
      -- mod
   elseif tabs.index == 3 then
      dials["syncSaw_atk"]:redraw()
      screen.move(69, 60)
      screen.text_center("SyncSaw Attack")
      -- elseif tabs.index == 4 then
      --   dials["filter_freq"]:redraw()
      --   dials["filter_q"]:redraw()
      --   screen.move(64, 24)
      --   screen.text_center(Formatters.format_freq_raw(params:get("all_filterFreq")))
      --   screen.move(19, 52)
      --   screen.text_center(params:get("all_filterQ"))
      -- -- trig
      -- elseif tabs.index == 5 then
      --   trig_mode_list:redraw()
      --   dials["transposition"]:redraw()
      --   screen.move(19, 52)
      --   screen.text_center(transposition)
   elseif tabs.index == 4 then
      dials["pwm_env_atk"]:redraw()
      dials["pwm_env_rel"]:redraw()
      screen.move(39, 60)
      screen.text_center("PWM Atk")
      screen.move(89, 60)
      screen.text_center("PWM Rel")
   end
   screen.update()

   -- grid redraw
   g:all(0)
   
   -- GLOBAL KEYS
   -- set active tab
   g:led(tabLeds[tabs.index][1], tabLeds[tabs.index][2], 15)

   -- set active pset, if any
   if activePset > 0 then
      g:led(psetLeds[activePset][1], psetLeds[activePset][2], 15)
   end 
   
   -- dip modulator frequency
   -- for i=13,16 do
   --    g:led(i, 8, momentaryKeys[i][8] * 15)
   --    engine.dipModulatorFrequency(i-12, momentaryKeys[i][8])
   -- end

   -- send program changes to microcosm
   -- TODO cleanup: move execution of actions up, only redrawing here
   g:led(16, 2, momentaryKeys[16][2] * 15)
   if momentaryKeys[16][2] == 1 then
      -- Interrupt A
      print("trigger Interrupt A")
      m:program_change(5, 1)
   end

   g:led(16, 3, momentaryKeys[16][3] * 15)
   if momentaryKeys[16][3] == 1 then
      -- Interrupt D
      print("trigger Interrupt D")
      m:program_change(8, 1)
   end
   
   -- trigger delay envelope
   for i = 1,12 do
      g:led(i, 2, momentaryKeys[i][2] * 15)
      engine.triggerDelay(i, momentaryKeys[i][2])
   end

   if tabs.index == 1 then
      for id, fader in pairs(mixer) do
         fader:draw()
      end
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
   end
   
   g:refresh()
end
