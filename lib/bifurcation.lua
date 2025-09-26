local BIFURCATION = {}
local ControlSpec = require 'controlspec'
local Formatters = require 'formatters'

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
  local modulatorFrequencies = {3.55, 5.33, 8, 12, 18, 27, 40.5}
  local klankDecayLowerLimits = {0.0000001, 0.000001, 0.0001, 0.001, 0.01, 0.1}
  local klankGains = {0, 0.01, 0.1, 0.5, 0.8, 0.9}
  local rDevs = {-0.05, -0.02, 0, 0.02, 0.05}
  local pwmBaseFreqs = {50, 100, 200, 300, 500}
  local pwmIntervals = {1.111, 1.2, 1.25, 1.333, 1.5, 1.75}
  local grainRates = {-1.0, -0.5, -0.2, 0.2, 0.5, 1.0, 2.0}
  local grainDurations = {0.05, 0.1, 0.2, 0.5, 1.0, 2.0}
  -- local grainCenterPos

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
  
  params:add_option("master_volume", "Master Volume", levels, 1)
  params:set_action("master_volume",
    function(idx)
      local db = levels[idx]
      engine.masterVolume(db)
    end
  )
  
  params:add_separator("Logistic")

  for i = 1,#modulators do
     -- params:add_group("channel_["..channels[i].."]", "channel ["..channels[i].."]", #channels)

    params:add_option("modulator_"..modulators[i].."_freq", "modulator ["..modulators[i].."] frequency", modulatorFrequencies, 3)
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
  end
  
  params:add_separator("MIDI")
  params:add_number("midi_channel", "MIDI channel", 1, 16, 1) 
  
  params:add_number("midi_program_change", "MIDI PC", 0, 127, 0)
  params:set_action("midi_program_change", function(pc)
      m:program_change(pc, params:get("midi_channel"))
    end)
  
  params:bang()
end

return BIFURCATION
