package backend;

import ceramic.Path;

using StringTools;

#if !no_backend_docs
/**
 * Audio system implementation for the headless backend.
 * 
 * This class provides a mock audio implementation that maintains
 * the same interface as other Ceramic backends but doesn't actually
 * play any audio. This is suitable for:
 * - Automated testing
 * - Server-side applications
 * - CI/CD environments
 * - Any scenario where audio output is not needed
 * 
 * All audio operations return valid handles and maintain state
 * but produce no actual sound output.
 */
#end
class Audio implements spec.Audio {

/// Lifecycle

    #if !no_backend_docs
    /**
     * Creates a new headless audio system instance.
     */
    #end
    public function new() {}

/// Public API

    #if !no_backend_docs
    /**
     * Loads an audio resource from the specified path.
     * 
     * In headless mode, this creates a mock audio resource without
     * actually loading any audio data.
     * 
     * @param path Path to the audio file (ignored in headless mode)
     * @param options Optional loading parameters (ignored in headless mode)
     * @param _done Callback function called with the loaded audio resource
     */
    #end
    public function load(path:String, ?options:LoadAudioOptions, _done:AudioResource->Void):Void {

        var done = function(resource:AudioResource) {
            ceramic.App.app.onceImmediate(function() {
                _done(resource);
                _done = null;
            });
        };

        done(new AudioResourceImpl());

    }

    #if !no_backend_docs
    /**
     * Creates an audio resource from a samples buffer.
     * 
     * In headless mode, this creates a mock audio resource without
     * processing the provided audio data.
     * 
     * @param buffer Audio sample data (ignored in headless mode)
     * @param samples Number of samples in the buffer
     * @param channels Number of audio channels
     * @param sampleRate Sample rate in Hz
     * @param interleaved Whether the samples are interleaved
     * @return A mock audio resource
     */
    #end
    public function createFromSamplesBuffer(buffer:Float32Array, samples:Int, channels:Int, sampleRate:Float, interleaved:Bool):AudioResource {

        return new AudioResourceImpl();

    }

    #if !no_backend_docs
    /**
     * Indicates whether this backend supports hot reloading of audio assets.
     * 
     * @return Always false for the headless backend
     */
    #end
    inline public function supportsHotReloadPath():Bool {

        return false;

    }

    #if !no_backend_docs
    /**
     * Gets the duration of an audio resource in seconds.
     * 
     * @param audio The audio resource to query
     * @return Always 0 in headless mode since no actual audio is loaded
     */
    #end
    inline public function getDuration(audio:AudioResource):Float {

        return 0;

    }

    #if !no_backend_docs
    /**
     * Resumes the audio context (typically after user interaction).
     * 
     * In headless mode, this immediately reports success since
     * there's no actual audio context to resume.
     * 
     * @param done Callback function called with the result (always true)
     */
    #end
    inline public function resumeAudioContext(done:Bool->Void):Void {

        done(true);

    }

    #if !no_backend_docs
    /**
     * Destroys an audio resource and frees its memory.
     * 
     * In headless mode, this is a no-op since no actual
     * audio resources are allocated.
     * 
     * @param audio The audio resource to destroy
     */
    #end
    inline public function destroy(audio:AudioResource):Void {

        //

    }

    #if !no_backend_docs
    /**
     * Creates a muted audio handle for the given resource.
     * 
     * @param audio The audio resource to mute
     * @return Always null in headless mode
     */
    #end
    inline public function mute(audio:AudioResource):AudioHandle {

        return null;

    }

    #if !no_backend_docs
    /**
     * Plays an audio resource with the specified parameters.
     * 
     * In headless mode, this creates a mock audio handle that
     * maintains the specified audio properties but produces no sound.
     * 
     * @param audio The audio resource to play
     * @param volume Playback volume (0.0 to 1.0)
     * @param pan Stereo pan (-1.0 left to 1.0 right)
     * @param pitch Playback pitch (1.0 = normal speed)
     * @param position Starting position in seconds
     * @param loop Whether to loop the audio
     * @param channel Audio channel to use
     * @return A mock audio handle with the specified properties
     */
    #end
    public function play(audio:AudioResource, volume:Float = 0.5, pan:Float = 0, pitch:Float = 1, position:Float = 0, loop:Bool = false, channel:Int = 0):AudioHandle {

        var handle = new AudioHandleImpl();
        handle.volume = volume;
        handle.pan = pan;
        handle.pitch = pitch;
        handle.position = position;

        return handle;

    }

    #if !no_backend_docs
    /**
     * Pauses audio playback for the given handle.
     * 
     * @param handle The audio handle to pause
     */
    #end
    public function pause(handle:AudioHandle):Void {

        //

    }

    #if !no_backend_docs
    /**
     * Resumes audio playback for the given handle.
     * 
     * @param handle The audio handle to resume
     */
    #end
    public function resume(handle:AudioHandle):Void {

        //

    }

    #if !no_backend_docs
    /**
     * Stops audio playback for the given handle.
     * 
     * @param handle The audio handle to stop
     */
    #end
    public function stop(handle:AudioHandle):Void {

        //

    }

    #if !no_backend_docs
    /**
     * Gets the current volume of an audio handle.
     * 
     * @param handle The audio handle to query
     * @return The current volume (0.0 to 1.0)
     */
    #end
    public function getVolume(handle:AudioHandle):Float {

        return (handle:AudioHandleImpl).volume;

    }

    #if !no_backend_docs
    /**
     * Sets the volume of an audio handle.
     * 
     * @param handle The audio handle to modify
     * @param volume The new volume (0.0 to 1.0)
     */
    #end
    public function setVolume(handle:AudioHandle, volume:Float):Void {

        (handle:AudioHandleImpl).volume = volume;

    }

    #if !no_backend_docs
    /**
     * Gets the current stereo pan of an audio handle.
     * 
     * @param handle The audio handle to query
     * @return The current pan (-1.0 left to 1.0 right)
     */
    #end
    public function getPan(handle:AudioHandle):Float {

        return (handle:AudioHandleImpl).pan;

    }

    #if !no_backend_docs
    /**
     * Sets the stereo pan of an audio handle.
     * 
     * @param handle The audio handle to modify
     * @param pan The new pan (-1.0 left to 1.0 right)
     */
    #end
    public function setPan(handle:AudioHandle, pan:Float):Void {

        (handle:AudioHandleImpl).pan = pan;

    }

    #if !no_backend_docs
    /**
     * Gets the current pitch of an audio handle.
     * 
     * @param handle The audio handle to query
     * @return The current pitch (1.0 = normal speed)
     */
    #end
    public function getPitch(handle:AudioHandle):Float {

        return (handle:AudioHandleImpl).pitch;

    }

    #if !no_backend_docs
    /**
     * Sets the pitch of an audio handle.
     * 
     * @param handle The audio handle to modify
     * @param pitch The new pitch (1.0 = normal speed)
     */
    #end
    public function setPitch(handle:AudioHandle, pitch:Float):Void {

        (handle:AudioHandleImpl).pitch = pitch;

    }

    #if !no_backend_docs
    /**
     * Gets the current playback position of an audio handle.
     * 
     * @param handle The audio handle to query
     * @return The current position in seconds
     */
    #end
    public function getPosition(handle:AudioHandle):Float {

        return (handle:AudioHandleImpl).position;

    }

    #if !no_backend_docs
    /**
     * Sets the playback position of an audio handle.
     * 
     * @param handle The audio handle to modify
     * @param position The new position in seconds
     */
    #end
    public function setPosition(handle:AudioHandle, position:Float):Void {

        (handle:AudioHandleImpl).position = position;

    }

    #if !no_backend_docs
    /**
     * Adds an audio filter to the specified bus.
     * 
     * In headless mode, this is a no-op since no actual audio processing occurs.
     * 
     * @param bus The audio bus to add the filter to
     * @param filter The audio filter to add
     * @param onReady Callback called when the filter is ready
     */
    #end
    public function addFilter(bus:Int, filter:ceramic.AudioFilter, onReady:(bus:Int)->Void):Void {}

    #if !no_backend_docs
    /**
     * Removes an audio filter from the specified channel.
     * 
     * @param channel The audio channel to remove the filter from
     * @param filterId The ID of the filter to remove
     */
    #end
    public function removeFilter(channel:Int, filterId:Int):Void {}

    #if !no_backend_docs
    /**
     * Notifies that audio filter parameters have changed.
     * 
     * @param channel The audio channel with changed filter parameters
     * @param filterId The ID of the filter with changed parameters
     */
    #end
    public function filterParamsChanged(channel:Int, filterId:Int):Void {}

}