local BIFURCATION = {}
local ControlSpec = require 'controlspec'

function round_form(param,quant,form)
  return(util.round(param,quant)..form)
end

function BIFURCATION.add_params()
  params:add_separator("BIFURCATION")
  local channels = {1,2,3,4,5,6,7,8,9,10,11,12}
  local levels = {-90, -36, -24, -12, -6, 0}
  local syncSawVoices = {1,2,3,4}
  local pwmVoices = {1,2,3,4}
  local modulators = {1,2,3,4}
  local grainVoices = {1,2,3,4}
  local modulatorFrequencies = {0.25, 1, 2, 4, 8, 16, 32}
  local klankDecayLowerLimits = {0.0000001, 0.000001, 0.0001, 0.001, 0.01, 0.1}
  local klankGains = {0, 0.01, 0.1, 0.5, 0.8, 0.9}
  local rDevs = {-0.05, -0.02, 0, 0.02, 0.05}
  local pwmBaseFreqs = {50, 100, 200, 300, 500}
  local pwmIntervals = {1.111, 1.2, 1.25, 1.333, 1.5, 1.75}
  local grainRates = {-1.0, -0.5, -0.2, 0.2, 0.5, 1.0, 2.0}
  local grainDurations = {0.05, 0.1, 0.2, 0.5, 1.0, 2.0}

  params:add_separator("Mixer")
  for i = 1,#channels do
     -- params:add_group("channel_["..channels[i].."]", "channel ["..channels[i].."]", #channels)

    params:add_option("channel_"..channels[i].."_amp", "channel ["..channels[i].."] amplitude", levels, 1)
    params:set_action("channel_"..channels[i].."_amp", 
      function(idx)
        local db = levels[idx]
        engine.channelGain(i, db)
      end
    )
  end
  
  -- open from the start: grid psets leave the master alone, the channels set the level
  params:add_option("master_volume", "Master Volume", levels, #levels)
  params:set_action("master_volume",
    function(idx)
      local db = levels[idx]
      engine.masterVolume(db)
    end
  )
  
  params:add_separator("Logistic")

  for i = 1,#modulators do
     -- params:add_group("channel_["..channels[i].."]", "channel ["..channels[i].."]", #channels)

    params:add_option("modulator_"..modulators[i].."_freq", "modulator ["..modulators[i].."] frequency", modulatorFrequencies, 5)
    params:set_action("modulator_"..modulators[i].."_freq", 
      function(idx)
        local freq = modulatorFrequencies[idx]
        engine.adjustModulatorFreq(i, freq)
      end
    )

    params:add_option("modulator_"..modulators[i].."_rdev", "modulator ["..modulators[i].."] r deviation", rDevs, 3)
    params:set_action("modulator_"..modulators[i].."_rdev", 
      function(idx)
        local amount = rDevs[idx]
        engine.adjustRDev(i, amount)
      end
    )
  end

  params:add_separator("SyncSaw")
  params:add_control(
     "syncSaw_atk",
     "SyncSaw Attack",
     ControlSpec.new(0.01, 1.0, 'exp', 0, 0.01),
     function(param) return (round_form(param:get(),0.01," s")) end
  )
  params:set_action("syncSaw_atk",
                    function(atk)
                       engine.syncSawEnvelope(atk, 0.1)
                    end
  )

  for i = 1,#syncSawVoices do
     -- params:add_group("channel_["..channels[i].."]", "channel ["..channels[i].."]", #channels)
     params:add_option("syncSaw_"..syncSawVoices[i].."_klank_decay_lower", "SyncSaw ["..syncSawVoices[i].."] Klank dec low", klankDecayLowerLimits, 1)
     params:set_action("syncSaw_"..syncSawVoices[i].."_klank_decay_lower", 
                       function(idx)
                          local decayLower = klankDecayLowerLimits[idx]
                          engine.syncSawKlankDecayLower(i, decayLower)
                       end
     )

     params:add_option("syncSaw_"..syncSawVoices[i].."_klank_gain", "SyncSaw ["..syncSawVoices[i].."] Klank gain", klankGains, 1)
     params:set_action("syncSaw_"..syncSawVoices[i].."_klank_gain", 
                       function(idx)
                          local klankGain = klankGains[idx]
                          engine.syncSawKlankGain(i, klankGain)
                       end
     )
  end

  params:add_separator("PWM")
  params:add_control(
    "pwm_env_atk",
    "PWM Env Atk",
    ControlSpec.new(0.01, 1.0, 'exp', 0, 0.01),
    function(param) return (round_form(param:get(),0.01," s")) end
  )
  params:set_action("pwm_env_atk",
                   function(atk)
                      engine.adjustPWMParams("atk", atk)
                   end
  )

  params:add_control(
    "pwm_env_sus",
    "PWM Env Sus",
    ControlSpec.new(0, 1.0, 'lin', 0, 0),
    function(param) return (round_form(param:get(),0.01," s")) end
  )
  params:set_action("pwm_env_sus",
                   function(sus)
                      engine.adjustPWMParams("sustainTime", sus)
                   end
  )

  params:add_control(
    "pwm_env_rel",
    "PWM Env Rel",
    ControlSpec.new(0.01, 1.0, 'exp', 0, 0.1),
    function(param) return (round_form(param:get(),0.01," s")) end
  )
  params:set_action("pwm_env_rel",
                   function(rel)
                      engine.adjustPWMParams("rel", rel)
                   end
  )

  for i = 1,#pwmVoices do
     params:add_option("pwm_"..pwmVoices[i].."_base_freq", "PWM ["..pwmVoices[i].."] base freq", pwmBaseFreqs, 1)
     params:set_action("pwm_"..pwmVoices[i].."_base_freq", 
                       function(idx)
                          local baseFreq = pwmBaseFreqs[idx]
                          engine.setPWMBaseFreq(i, baseFreq)
                       end
     )

     params:add_option("pwm_"..pwmVoices[i].."_interval", "PWM ["..pwmVoices[i].."] interval", pwmIntervals, 6)
     params:set_action("pwm_"..pwmVoices[i].."_interval", 
                       function(idx)
                          local baseFreq = pwmIntervals[idx]
                          engine.setPWMInterval(i, baseFreq)
                       end
     )
  end
  
  params:add_separator("Grains")
  for i = 1,#grainVoices do
     params:add_option("grain_"..grainVoices[i].."_rate", "Grain ["..grainVoices[i].."] rate", grainRates, 6)
     params:set_action("grain_"..grainVoices[i].."_rate", 
                       function(idx)
                          local rate = grainRates[idx]
                          engine.setGrainRate(i, rate)
                       end
     )
     
     params:add_option("grain_"..grainVoices[i].."_dur", "Grain ["..grainVoices[i].."] dur", grainDurations, 3)
     params:set_action("grain_"..grainVoices[i].."_dur", 
                       function(idx)
                          local dur = grainDurations[idx]
                          engine.setGrainDuration(i, dur)
                       end
     )

     -- random offset of each new grain around the center, in seconds like the grain duration;
     -- the arc sets it with shift + ring
     params:add_control(
        "grain_"..grainVoices[i].."_spray",
        "Grain ["..grainVoices[i].."] spray",
        ControlSpec.new(0, 5, 'lin', 0, 0, "s"),
        function(param) return "± "..util.round(param:get(), 0.01).." s" end
     )
     params:set_action("grain_"..grainVoices[i].."_spray",
                       function(seconds)
                          engine.setGrainSpray(i, seconds)
                       end
     )

     -- the arc's ring i drives this; step 0 so slow turns aren't quantised away
     params:add_control(
        "grain_"..grainVoices[i].."_pos",
        "Grain ["..grainVoices[i].."] pos",
        ControlSpec.new(0, 1, 'lin', 0, 0),
        function(param) return util.round(param:get() * 100, 1).." %" end
     )
     params:set_action("grain_"..grainVoices[i].."_pos",
                       function(pos)
                          engine.setGrainPos(i, pos)
                       end
     )
  end
  
  params:add_separator("MIDI")
  -- The Microcosm sits on the MIDIMATE's first out, where the passthrough mod also forwards the
  -- Monolit's sliders. The Monolit gets only what its slider displays should show (EXT CC);
  -- relaying through it relied on the Monolit echoing input, which a reset can switch off.
  -- Both are picked by name because norns hands out port numbers in plug-in order.
  local port_names = {}
  local function port_named(pattern)
    for i = 1, #midi.vports do
      if (midi.vports[i].name or ""):match(pattern) then return i end
    end
    return 1
  end
  for i = 1, #midi.vports do port_names[i] = i..": "..(midi.vports[i].name or "none") end
  params:add_option("midi_port", "Microcosm port", port_names, port_named("MIDIMATE eX 1"))
  params:set_action("midi_port", function(i) m = midi.connect(i) end)
  params:add_option("monolit_port", "Monolit port", port_names, port_named("Monolit"))
  params:set_action("monolit_port", function(i) monolit = midi.connect(i) end)
  -- a port number saved in a pset would bring the plug-in-order problem back on load
  params:set_save("midi_port", false)
  params:set_save("monolit_port", false)
  params:add_number("midi_channel", "MIDI channel", 1, 16, 1)
  
  -- the startup bang must not send: it would switch the Microcosm to program 0 mid-sound on
  -- every script load. Pset loads and menu changes still send.
  local sending_program_changes = false
  params:add_number("midi_program_change", "MIDI PC", 0, 127, 0)
  params:set_action("midi_program_change", function(pc)
      if sending_program_changes then
        m:program_change(pc, params:get("midi_channel"))
      end
    end)

  params:bang()
  sending_program_changes = true
end

return BIFURCATION
