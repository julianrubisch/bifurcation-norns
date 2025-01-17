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
	
	var logisticOutBusses;
	var lagBusses;
	var deltaBusses;
	var integratedDeltaBusses;
	var mixerInBusses;
	var delayBusses;

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

					sig = sig * \amp.kr(0.5);

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

					// sig = sig * 0.67;

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

	*new {
		^super.new.init;
	}

	init {
		var s = Server.default;

		voiceGroup = Group.new(s);
		globalParams = Dictionary[
			\fb -> 0,
			\amp -> 0.1,
			\attack -> 0.5,
			\pan -> 0,
			\panFreq -> 1,
			\panAmp -> 0,
			\fbFreq -> 1,
			\fbAmp -> 0,
			\filterFreq -> 10000,
			\filterQ -> 1,
			\sustain -> 1,
			\release -> 1,
			\mode -> 0 // 0 == static, 1 == dust, 2 == grid
		];

		singleVoices = Dictionary.new;
		voiceParams = Dictionary.new;

		voiceKeys.do({ |voiceKey|
			singleVoices[voiceKey] = Group.new(voiceGroup);
			voiceParams[voiceKey] = Dictionary.newFrom(globalParams);
		});

		// rework above
		logisticGroup = Group.new(s);
		pulsesGroup = Group.new(s);

		modulator_count = 4;

		logisticModulators = [nil, nil, nil, nil];
		modulatedPulses = [nil, nil, nil, nil];
		delays = Array.fill(modulator_count * 3, nil);
		klankDecaysLower = Array.fill(4, 0.0000001);
		klankGains = [0, 0, 0, 0];
		syncSawAtk = 0.01;


		logisticOutBusses = modulator_count.collect { Bus.control(s, 1) };
		lagBusses =  modulator_count.collect { Bus.control(s, 1) };
		deltaBusses = modulator_count.collect { Bus.control(s, 1) };
		integratedDeltaBusses = modulator_count.collect { Bus.control(s, 1) };
		delayBusses = (3 * modulator_count).collect { Bus.audio(s, 2) };
		mixerInBusses = (3 * modulator_count).collect { Bus.audio(s, 2) };

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

		Ndef(\mixer, {
			var ins, sum;

			ins = (3 * modulator_count).collect { |i|
				In.ar((\in ++ i).asSymbol.kr(0), 2);
			};
			
			sum = ins.collect { |sig, i|
				sig * Lag3.kr((\gain_++i).asSymbol.kr(0), 0.5)
			}.sum;

			Out.ar(0, sum);
		});

		(3 * modulator_count).do { |idx|
			Ndef(\mixer).set(( \in++idx ).asSymbol, mixerInBusses[idx]);
		};
		
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

	adjustRDev { |channel, amount|
		logisticModulators[channel].set(\r_dev, amount);
	}

	adjustModulatorFreq { |channel, freq|
		logisticModulators[channel].set(\freq, freq);
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
	}
}