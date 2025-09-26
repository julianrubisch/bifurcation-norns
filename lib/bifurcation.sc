Bifurcation {
	classvar <voiceKeys;

	var <globalParams;
	var <voiceParams;
	var <voiceGroup;
	var <singleVoices;

	var modulator_count;
	var logisticModulators;
	var <logisticGroup;
	var delays;

	var modulatedPulses;
	var <pulsesGroup;
	
	var grains;
	var <grainsGroup;
	
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
		voiceKeys = Array.fill(10, { arg i; (i+1).asSymbol });

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
				  var sig;
				  
				  sig = TGrains.ar(
            numChannels: 2,
            trigger: Dust.kr(\tRate.kr(40)),
            bufnum: \buf.kr(0),
            rate: \rate.kr(1),
            // centerPos: \pos.kr(0.5), // in seconds (!)
            dur: Lag.kr(\dur.kr(0.2), 1), // in secs
            //dur: LFSaw.kr(\durRate.kr(0.2), mul: 0.3, add: 0.4),
            //dur: In.kr(\dur.kr(0)),
            pan: LFNoise1.kr(0.5, mul: 0.5, add: 0.5),
            //pan: In.kr(\pan.kr(0)),
            amp: 1, // default is 0.1 (!),
            interp: 2
          );

          sig = sig * \amp.kr(1.0);
          
          Out.ar(\out.kr(0), sig);
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

	*new { |server, baseSamplePath|
		^super.new.init(server, baseSamplePath);
	}

	init { |server, baseSamplePath|
		var s = server;
		
		var boomwhackerCBuf = Buffer.read(s, baseSamplePath ++ "bifurcation_boomwhacker_C.wav");
		var plasticBellShortBuf = Buffer.read(s, baseSamplePath ++ "bifurcation_plastic_bell_short.wav");
		var wahTubeSharpBuf = Buffer.read(s, baseSamplePath ++ "bifurcation_wah_tube_sharp.wav");

		voiceGroup = Group.new(s);
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
		
		grains[0] = Synth(\grains, [\buf, boomwhackerCBuf, \out, delayBusses[8], \durRate, 0.2]);
		grains[1] = Synth(\grains, [\buf, plasticBellShortBuf, \out, delayBusses[9], \durRate, 0.21]);
		grains[2] = Synth(\grains, [\buf, wahTubeSharpBuf, \out, delayBusses[10], \durRate, 0.23]);

		Ndef(\mixer, {
			var ins, sum, sumAmp;

			ins = (3 * modulator_count).collect { |i|
				In.ar((\in ++ i).asSymbol.kr(0), 2);
			};
			
			sum = ins.collect { |sig, i|
			  var out = sig * Lag3.kr((\gain_++i).asSymbol.kr(0), 2.5);
			  Out.kr((\levelOut++i).asSymbol.kr(18), Amplitude.kr(in: out));
			  out
			}.sum;
			
			sum = sum * Lag3.kr(\masterGain.kr(0), 2.5);
			
			Out.kr(\levelOutL.kr(16), Amplitude.kr(in: sum[0]));
			Out.kr(\levelOutR.kr(17), Amplitude.kr(in: sum[1]));

			Out.ar(0, sum);
		});

		(3 * modulator_count).do { |idx|
			Ndef(\mixer).set(( \in++idx ).asSymbol, mixerInBusses[idx]);
			Ndef(\mixer).set((\levelOut++idx).asSymbol, ampBusses[idx + 2]);
		};
		
		Ndef(\mixer).set(\levelOutL, ampBusses[0]);
		Ndef(\mixer).set(\levelOutR, ampBusses[1]);
		
		Ndef(\mixer).play;

		// syncsaw trigger
		OSCFunc({ |msg, time|
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
	
	setGrainRate { |channel, rate|
		grains[channel].set(\rate, rate);
	}
	
	setGrainDuration { |channel, dur|
		grains[channel].set(\dur, dur);
	}

	adjustRDev { |channel, amount|
		logisticModulators[channel].set(\r_dev, amount);
	}

	adjustModulatorFreq { |channel, freq|
		logisticModulators[channel].set(\freq, freq);
		grains[channel].set(\tRate, freq.linlin(3, 40, 0.2, 50));
	}

	triggerDelay { |channel, gate|
		delays[channel].set(\wet_gate, gate);
	}

	// IMPORTANT SO OUR SYNTHS DON'T RUN PAST THE SCRIPT'S LIFE
	freeAllNotes {
		voiceGroup.set(\stopGate, -1.05);
	}

	free {
		// IMPORTANT
		voiceGroup.free;
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
	}
}