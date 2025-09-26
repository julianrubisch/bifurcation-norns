Engine_BIFURCATION : CroneEngine {
	var kernel;
  classvar <>samplePath = "/home/we/dust/audio/bifurcation/";

	*new { arg context, doneCallback;
		^super.new(context, doneCallback);
	}

	alloc { // allocate memory to the following:
		kernel = Bifurcation.new(Crone.server, samplePath);

		this.addCommand(\channelGain, "ii", { |msg|
			var channel = msg[1].asInteger - 1;
			var db = msg[2].asInteger;

			kernel.adjustChannelGain(channel, db);
		});
		
		this.addCommand(\masterVolume, "i", { |msg|
		  var db = msg[1].asInteger;
		  kernel.adjustMasterVolume(db);
		});

		this.addCommand(\syncSawEnvelope, "ff", { |msg|
			var atk = msg[1].asFloat;
			var rel = msg[2].asFloat;

			kernel.adjustSyncSawEnvelope(atk, rel);
		});

		this.addCommand(\syncSawKlankDecayLower, "if", { |msg|
			var voice = msg[1].asInteger - 1;
			var decay = msg[2].asFloat;

			kernel.adjustSyncSawKlankDecayLower(voice, decay);
		});

		this.addCommand(\syncSawKlankGain, "if", { |msg|
			var band = msg[1].asInteger - 1;
			var gain = msg[2].asFloat;

			kernel.adjustSyncSawKlankGain(band, gain);
		});

		this.addCommand(\adjustRDev, "if", { |msg|
			var channel = msg[1].asInteger - 1;
			var amount = msg[2].asFloat;

			kernel.adjustRDev(channel, amount);
		});

		this.addCommand(\adjustModulatorFreq, "if", { |msg|
			var channel = msg[1].asInteger - 1;
			var freq = msg[2].asFloat;

			kernel.adjustModulatorFreq(channel, freq);
		});

		this.addCommand(\adjustPWMParams, "sf", { |msg|
			var param = msg[1];
			var value = msg[2].asFloat;

			kernel.adjustPWMParams(param, value);
		});

		this.addCommand(\setPWMBaseFreq, "if", { |msg|
			var channel = msg[1].asInteger - 1;
			var freq = msg[2].asFloat;

			kernel.setPWMBaseFreq(channel, freq);
		});

		this.addCommand(\setPWMInterval, "if", { |msg|
			var channel = msg[1].asInteger - 1;
			var interval = msg[2].asFloat;

			kernel.setPWMInterval(channel, interval);
		});
		
		this.addCommand(\setGrainRate, "if", { |msg|
		  var channel = msg[1].asInteger - 1;
			var rate = msg[2].asFloat;
			
			kernel.setGrainRate(channel, rate);
		});
		
		this.addCommand(\setGrainDuration, "if", { |msg|
		  var channel = msg[1].asInteger - 1;
			var dur = msg[2].asFloat;
			
			kernel.setGrainDuration(channel, dur);
		});

		this.addCommand(\triggerDelay, "ii", { |msg|
			var channel = msg[1].asInteger - 1;
			var gate = msg[2].asInteger;

			// ("triggering delay for channel " ++ channel ++ " with value " ++ gate).postln;

			kernel.triggerDelay(channel, gate);
		});
		
		this.addPoll(\outputAmpL, {
	    var ampL = kernel.ampBusses[0].getSynchronous;
	    ampL
    });
    
    this.addPoll(\outputAmpR, {
	    var ampR = kernel.ampBusses[1].getSynchronous;
	    ampR
    });
    
    12.do { |idx|
      this.addPoll((\outputAmp++idx).asSymbol, {
        var amp = kernel.ampBusses[idx + 2].getSynchronous;
        amp
      });
    };
	}
	// alloc

	// IMPORTANT
	free {
		kernel.freeAllNotes;
		
		// TODO let's clean this up
		Crone.server.freeAll;
		kernel.free;
		
		//kernel.voiceGroup.free;
		//kernel.logisticGroup.free;
		//kernel.pulsesGroup.free;
		//kernel.grainsGroup.free;
	} // free
} // CroneEngine