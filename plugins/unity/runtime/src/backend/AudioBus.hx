package backend;

import unityengine.AudioMixerGroup;
import unityengine.AudioSource;

#if !no_backend_docs
/**
 * Unity-specific audio bus representation.
 * 
 * An audio bus groups multiple audio sources together for shared processing
 * and mixing. In Unity, this is implemented using AudioMixerGroup for routing
 * and a pool of AudioSource components for playback.
 * 
 * Each bus can have:
 * - Multiple audio sources playing simultaneously
 * - Shared effects processing via the mixer group
 * - Independent volume/effects settings
 * 
 * The bus system allows for advanced audio routing scenarios like:
 * - Separate music and sound effects buses
 * - Environmental audio with reverb
 * - Voice chat with noise suppression
 * 
 * @see AudioSources The manager that creates and pools audio sources
 * @see backend.Audio The main audio backend that routes to buses
 */
#end
@:structInit
class AudioBus {

    #if !no_backend_docs
    /**
     * Unity AudioMixerGroup for this bus.
     * All audio sources in this bus route through this mixer group,
     * allowing for shared effects processing and volume control.
     */
    #end
    public var mixerGroup:AudioMixerGroup;

    #if !no_backend_docs
    /**
     * The bus index in the audio system.
     * Used to identify this bus when playing sounds or adding filters.
     * Bus 0 is typically the default/master bus.
     */
    #end
    public var busIndex:Int;

    #if !no_backend_docs
    /**
     * Pool of Unity AudioSource components for this bus.
     * These are reused for playback to avoid allocation overhead.
     * Sources are activated when playing and returned to the pool when done.
     */
    #end
    public var audioSources:Array<AudioSource>;

}
