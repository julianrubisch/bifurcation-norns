Bifurcation {
	classvar <>grainMakeupDb = 12;

	var modulator_count;
	var logisticModulators;
	var <logisticGroup;
	var delays;

	var modulatedPulses;
	var <pulsesGroup;
	
	var grains;
	var <grainsGroup;
	var <grainInfoBusses;
	var <envBus;
	var trigResponder;
	
	var <fxGroup;
	
	var logisticOutBusses;
	var lagBusses;
	var deltaBusses;
	var integratedDeltaBusses;
	var mixerInBusses;
	var delayBusses;
	var <ampBusses;

	var klankDecaysLower;
	var klankGains;
	var syncSawAtk;

	*initClass {
		StartUp.add {
			var s = Server.default;

			s.waitForBoot {
				s.newBusAllocators;

				SynthDef.new(\logistic, {
					var sig;

					// sig = Logistic.kr(Clip.kr((1 + Lag.kr(\r_dev.kr(0), 0.5)) * \r.kr(2.4), 2.4, 3.99), (1 - dipEnv) * \freq.kr(4), 0.5);
					sig = Logistic.kr(Clip.kr((1 + Lag.kr(\r_dev.kr(0), 0.5)) * Lag.kr(\r.kr(2.4), 3), 2.4, 3.99), \freq.kr(3.55));

					Out.kr(\out.kr(0), sig);
				}).add;

				SynthDef.new(\syncSaw, {
					var sig, env, pitchEnv, filterDecayCoef;

					var klankGains = NamedControl.kr(\klankGains, [0.9, 0.5, 0.8, 0.5]);
					env = EnvGen.ar(Env.perc(\atk.kr(0.01), \rel.kr(0.1)), doneAction: 2);
					pitchEnv = EnvGen.ar(Env.perc(0.002, 0.05));

					sig = SyncSaw.ar(40 * Lag.kr(In.kr(\r.kr(0)), 0.1), 50 + (200 * pitchEnv));

					filterDecayCoef = LinExp.kr(In.kr(\filterDecayCoef.kr(0)), 0, 5, LFNoise0.kr(0.25, mul: 0.2, add: 0.7), Lag.kr(\filterDecayCoefLower.kr(0.0000001), 0.3));
					
					sig = Klank.ar(`[[50, 250, 420, 1100], klankGains, filterDecayCoef!4], sig);
					
					sig = Pan2.ar(sig, In.kr(\pan.kr(0)));

					sig = sig * env;

					sig = sig * \amp.kr(0.5) * 0.67;

					Out.ar(\out.kr(0), sig);
				}).add;

				SynthDef.new(\modulatedPulse, {
					var sig, env, depth;

					env = EnvGen.ar(Env.linen(\atk.kr(0.01), \sustainTime.kr(0), \rel.kr(0.1), curve: -4),
						gate: \t_gate.kr(0),
						doneAction: 0);

					sig = Splay.ar(Pulse.ar(Array.geom(4, \baseFreq.kr(200), \interval.kr(1.75)), Lag.kr(In.kr(\width.kr(0)), 1), 0.5), spread: 0.8, level: 0.67);

					depth = \depth.kr(1) * 7900;
					sig = RLPF.ar(sig, ((1 - env) * depth) + (8000 - depth), 0.05);
					// sig = RLPF.ar(sig, 8000, 0.05);

					sig = sig * 0.67;

					Out.ar(\out.kr(0), sig);
				}).add;
				
				SynthDef.new(\grains, {
				  var sig, trig, bufDur, dur, rate, center, spray, grainStart;

				  bufDur = BufDur.kr(\buf.kr(0));
				  dur = Lag.kr(\dur.kr(0.2), 1); // in secs
				  rate = \rate.kr(1);
				  trig = Dust.kr(\tRate.kr(40));

				  // \pos is the arc's center as a fraction of the file; \spray (seconds) gives each
				  // new grain its own random start around it. Spray 0 starts every grain on the center.
				  center = Lag.kr(\pos.kr(0), 0.1) * bufDur;
				  spray = \spray.kr(0);
				  // sclang has no operator precedence: the product needs its own parentheses
				  grainStart = (center + (TRand.kr(-1, 1, trig) * spray)).fold(0, bufDur);

				  sig = TGrains.ar(
            numChannels: 2,
            trigger: trig,
            bufnum: \buf.kr(0),
            rate: rate,
            // TGrains centers a grain on centerPos; shifting by half a grain makes it start at
            // grainStart and read forward (backward at negative rates), as the arc draws it
            centerPos: grainStart + (dur * rate * 0.5), // in seconds (!)
            dur: dur,
            //dur: LFSaw.kr(\durRate.kr(0.2), mul: 0.3, add: 0.4),
            pan: LFNoise1.kr(0.5, mul: 0.5, add: 0.5),
            amp: 1, // default is 0.1 (!),
            interp: 2
          );

          sig = sig * \amp.kr(1.0);

          Out.ar(\out.kr(0), sig);

          // for the arc to run one playhead per grain: the newest grain's start (fraction of the
          // file), its duration and rate, the spray (fraction), the file length in seconds, and a
          // grain count so a new grain is seen even when it starts where the last one did
          Out.kr(\infoOut.kr, [grainStart / max(bufDur, 0.001), dur, rate, spray / max(bufDur, 0.001), bufDur, PulseCount.kr(trig)]);
				}).add;

				SynthDef.new(\lagPanner, {
					var panSig;

					panSig = In.kr(\in.kr(0));

					panSig = Lag.kr(panSig, \lagTime.kr(0.5));

					// the logistic map is a bit skewed towards higher numbers
					panSig = LinLin.kr(panSig, 0.3, 1.0, -1.0, 1.0);

					Out.kr(\out.kr(0), panSig);
				}).add;

				SynthDef.new(\trigDetector, {
					var sig, delta, trig;

					sig = In.kr(\in.kr(0));

					delta = HPZ1.kr(sig);

					Out.kr(\delta.kr(0), Latch.kr(delta.abs, delta.abs));

					trig = Changed.kr(delta.abs > \thresh.kr(0));

					SendTrig.kr(trig, \index.ir(0), delta.abs);
				}).add;

				SynthDef.new(\deltaIntegrator, {
					var sig;
					
					sig = In.kr(\in.kr(0));

					sig = Integrator.kr(sig, coef: 0.9);

					Out.kr(\out.kr(0), sig);
				}).add;
				
				SynthDef(\delay, {
					var sig, wet, env, buf, ptr, pos;

					// we want to keep this instance, hence doneaction 0
					// TODO make atk, rel, max delay and decay configurable
					env = EnvGen.ar(Env.asr(\atk.kr(3), 1.0, \rel.kr(3)), doneAction: 0, gate: \wet_gate.kr(0));

					sig = In.ar(\in.kr(0), 2);

					wet = CombL.ar(sig, 1,
						\max_delaytime.kr(1) * LinExp.ar(env, 0.0, 1.0, 1.0, 0.05),
						\max_decaytime.kr(5) * LinExp.ar(env, 0.0, 1.0, 0.01, 1.0));

					sig = sig.blend(wet, (env * 0.7));

					Out.ar(\out.kr(0), sig);
				}).add;
			}
		}
	}

	// Per-channel processing before the faders, so the three generator groups sit near the same
	// level (measured pre-fader on 2026-11-18). SyncSaw's Klank resonators ring up to +26 dB
	// peak, and how far depends on each voice's decay floor and map, so a trim alone can't hold
	// them: the limiter catches what the trim leaves. The grains are sparse and peaky; the
	// compressor evens them out, the makeup brings them level with PWM (about -20 dB RMS), and
	// the limiter takes the drip transients the 10 ms attack lets through.
	*channelStrip { |sig, channel|
		^case
		{ channel < 4 } { Limiter.ar(sig * -24.dbamp, -1.dbamp) }
		{ channel >= 8 } { Limiter.ar(Compander.ar(sig, sig, -30.dbamp, 1, 1/3, 0.01, 0.25) * grainMakeupDb.dbamp, -1.dbamp) }
		{ sig };
	}

	*new { |server, baseSamplePath|
		^super.new.init(server, baseSamplePath);
	}

	init { |server, baseSamplePath|
		var s = server;
		
		var waterCaboGiraoBuf = Buffer.read(s, baseSamplePath ++ "bifurcation_water_cabo_girao.wav");
		var waterBoilingBuf = Buffer.read(s, baseSamplePath ++ "bifurcation_water_boiling.wav");
		var waterDrippingBuf = Buffer.read(s, baseSamplePath ++ "bifurcation_water_dripping.wav");

		logisticGroup = Group.new(s);
		pulsesGroup = Group.new(s);
		grainsGroup = Group.new(s);
		fxGroup = Group.new(s);
		

		modulator_count = 4;

		logisticModulators = [nil, nil, nil, nil];
		modulatedPulses = [nil, nil, nil, nil];
		grains = [nil, nil, nil, nil];
		delays = Array.fill(modulator_count * 3, nil);
		klankDecaysLower = Array.fill(4, 0.0000001);
		klankGains = [0, 0, 0, 0];
		syncSawAtk = 0.01;

    // busses
		logisticOutBusses = modulator_count.collect { Bus.control(s, 1) };
		lagBusses =  modulator_count.collect { Bus.control(s, 1) };
		deltaBusses = modulator_count.collect { Bus.control(s, 1) };
		integratedDeltaBusses = modulator_count.collect { Bus.control(s, 1) };
		delayBusses = (3 * modulator_count).collect { Bus.audio(s, 2) };
		mixerInBusses = (3 * modulator_count).collect { Bus.audio(s, 2) };
		ampBusses = Array.fill(14, { arg i; Bus.control(s); });
		grainInfoBusses = 3.collect { Bus.control(s, 6) };
		envBus = Bus.control(s, 1);
    
		[3.1, 3.9, 3.8, 3.4].collect { |r, index|
			logisticModulators[index] = Synth(\logistic, [\r, r, \out, logisticOutBusses[index]], logisticGroup);
		};

		(3 * modulator_count).do { |idx|
			delays[idx] = Synth(\delay, [\in, delayBusses[idx], \out, mixerInBusses[idx]]);
		};

		modulator_count.do { |index|
			Synth(\lagPanner, [\in, logisticOutBusses[index], \out, lagBusses[index]]);
			Synth(\trigDetector, [\in, logisticOutBusses[index], \delta, deltaBusses[index], \index, index]);
			Synth(\deltaIntegrator, [\in, deltaBusses[index], \out, integratedDeltaBusses[index]]);
			
			modulatedPulses[index] = Synth(\modulatedPulse, [\out, delayBusses[index + 4], \width, deltaBusses[index]]);
		};
		
		// \durRate only matters if the LFSaw dur line in \grains is re-enabled
		[waterCaboGiraoBuf, waterBoilingBuf, waterDrippingBuf].do { |buf, i|
			grains[i] = Synth(\grains, [\buf, buf, \out, delayBusses[8 + i], \infoOut, grainInfoBusses[i], \durRate, [0.2, 0.21, 0.23][i]]);
		};

		// the Ndef is global and outlives an engine; start it from scratch so it never plays
		// with the previous engine's busses and fader levels
		Ndef(\mixer).clear;
		Ndef(\mixer, {
			var ins, sum, sumAmp;

			ins = (3 * modulator_count).collect { |i|
				In.ar((\in ++ i).asSymbol.kr(0), 2);
			};
			
			sum = ins.collect { |sig, i|
			  var out;
			  sig = Bifurcation.channelStrip(sig, i);
			  out = sig * Lag3.kr((\gain_++i).asSymbol.kr(0), 2.5);
			  Out.kr((\levelOut++i).asSymbol.kr(18), Amplitude.kr(in: out));
			  out
			}.sum;
			
			sum = sum * Lag3.kr(\masterGain.kr(0), 2.5);
			
			Out.kr(\levelOutL.kr(16), Amplitude.kr(in: sum[0]));
			Out.kr(\levelOutR.kr(17), Amplitude.kr(in: sum[1]));
			// follows what the Microcosm hears, so it sits after the master gain
			Out.kr(\envOut.kr(19), max(
				Amplitude.kr(sum[0], \envAtk.kr(0.01), \envRel.kr(0.3)),
				Amplitude.kr(sum[1], \envAtk.kr(0.01), \envRel.kr(0.3))).ampdb.max(-120));

			Out.ar(0, sum);
		});

		(3 * modulator_count).do { |idx|
			Ndef(\mixer).set(( \in++idx ).asSymbol, mixerInBusses[idx]);
			Ndef(\mixer).set((\levelOut++idx).asSymbol, ampBusses[idx + 2]);
		};
		
		Ndef(\mixer).set(\levelOutL, ampBusses[0]);
		Ndef(\mixer).set(\levelOutR, ampBusses[1]);
		Ndef(\mixer).set(\envOut, envBus);
		
		Ndef(\mixer).play;

		// syncsaw trigger; freed with the engine, or it keeps spawning hits into freed busses
		trigResponder = OSCFunc({ |msg, time|
			// index, delta.abs
			var index = msg[2];
			var delta_abs = msg[3];
			
			Synth(\syncSaw, [\r, logisticOutBusses[index], \out, delayBusses[index], \pan, lagBusses[index], \atk, syncSawAtk, \rel, delta_abs/2, \amp, delta_abs, \filterDecayCoef, integratedDeltaBusses[index], \filterDecayCoefLower, klankDecaysLower[index], \klankGains, klankGains]);

			modulatedPulses[index].set(\t_gate, 1);
			
		}, '/tr', s.addr);
	}

	adjustChannelGain { |channel, db|
		var amp = db.dbamp;

		Ndef(\mixer).set((\gain_++channel).asSymbol, amp);
	}
	
	adjustMasterVolume { |db|
	  var amp = db.dbamp;
	  
	  Ndef(\mixer).set(\masterGain, amp);
	}

	adjustSyncSawEnvelope { |atk, rel|
		syncSawAtk = atk;
	}

	adjustSyncSawKlankDecayLower { |voice, lowerLimit|
		klankDecaysLower[voice] = lowerLimit;
	}

	adjustSyncSawKlankGain { |band, gain|
		klankGains[band] = gain;
	}

	adjustPWMParams { |param, value|
		modulatedPulses.do { |pwm|
			pwm.set(param.asSymbol, value);
		}
	}

	setPWMBaseFreq { |channel, freq|
		modulatedPulses[channel].set(\baseFreq, freq);
	}

	setPWMInterval { |channel, interval|
		modulatedPulses[channel].set(\interval, interval);
	}
	
	// the UI has four grain voices but only three synths exist; the fourth slot stays nil
	setGrain { |channel, key, value|
		if(grains[channel].notNil) { grains[channel].set(key, value) };
	}

	setGrainRate { |channel, rate|
		this.setGrain(channel, \rate, rate);
	}

	setGrainDuration { |channel, dur|
		this.setGrain(channel, \dur, dur);
	}

	setGrainSpray { |channel, seconds|
		this.setGrain(channel, \spray, seconds);
	}

	setGrainPos { |channel, pos|
		this.setGrain(channel, \pos, pos);
	}

	adjustRDev { |channel, amount|
		logisticModulators[channel].set(\r_dev, amount);
	}

	adjustModulatorFreq { |channel, freq|
		logisticModulators[channel].set(\freq, freq);
		// one grain per logistic step on average, so slow maps thin the grains out too
		this.setGrain(channel, \tRate, freq);
	}

	setEnvFollower { |key, value|
		Ndef(\mixer).set(key, value);
	}

	triggerDelay { |channel, gate|
		delays[channel].set(\wet_gate, gate);
	}

	free {
		trigResponder.free;
		Ndef(\mixer).clear;
		logisticGroup.free;
		pulsesGroup.free;
		grainsGroup.free;
		
		logisticOutBusses.do { |bus| bus.free; };
		lagBusses.do { |bus| bus.free; };
		deltaBusses.do { |bus| bus.free; };
		integratedDeltaBusses.do { |bus| bus.free; };
		delayBusses.do { |bus| bus.free; };
		mixerInBusses.do { |bus| bus.free; };
		ampBusses.do { |bus| bus.free; };
		grainInfoBusses.do { |bus| bus.free; };
		envBus.free;
	}
}