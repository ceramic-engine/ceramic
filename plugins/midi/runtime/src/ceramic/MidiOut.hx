package ceramic;

#if (cpp && (mac || windows || linux))
typedef MidiOut = ceramic.impl.MidiOutRtMidi;
#elseif (web && ceramic_native_bridge)
typedef MidiOut = ceramic.impl.MidiOutWebNativeBridge;
#else
typedef MidiOut = ceramic.impl.MidiOutBase;
#end
