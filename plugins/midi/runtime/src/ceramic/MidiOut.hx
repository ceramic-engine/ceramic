package ceramic;

#if (cpp && (mac || windows || linux))
typedef MidiOut = ceramic.impl.MidiOutRtMidi;
#elseif (clay && web && plugin_bridge)
typedef MidiOut = ceramic.impl.MidiOutWebNativeBridge;
#else
typedef MidiOut = ceramic.impl.MidiOutBase;
#end
