Engine_BIFURCATION : CroneEngine {
	var kernel;

	*new { arg context, doneCallback;
		^super.new(context, doneCallback);
	}

	alloc { // allocate memory to the following:
		kernel = Bifurcation.new(Crone.server);

		this.addCommand(\channelGain, "ii", { |msg|
			var channel = msg[1].asInteger - 1;
			var db = msg[2].asInteger;

			kernel.adjustChannelGain(channel, db);
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

		this.addCommand(\triggerDelay, "ii", { |msg|
			var channel = msg[1].asInteger - 1;
			var gate = msg[2].asInteger;

			// ("triggering delay for channel " ++ channel ++ " with value " ++ gate).postln;

			kernel.triggerDelay(channel, gate);
		});
	}
	// alloc

	// IMPORTANT
	free {
		kernel.freeAllNotes;
		// groups are lightweight but they are still persistent on the server and nodeIDs are finite,
		//   so they do need to be freed:
		kernel.voiceGroup.free;
		kernel.logisticGroup.free;
	} // free
} // CroneEngine