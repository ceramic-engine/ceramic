package ceramic;

#if sys
import haxe.atomic.AtomicBool;
import haxe.atomic.AtomicInt;
#end

/**
 * Internal manager for audio filter worklets across audio buses.
 * 
 * AudioFilters handles the lifecycle and processing of audio filter worklets,
 * which are small processing units that modify audio in real-time. It manages:
 * - Thread-safe registration and removal of worklets
 * - Organizing worklets by audio bus
 * - Synchronizing worklet changes between threads
 * - Processing audio through active worklets
 * 
 * This class is used internally by the audio backend and should not be
 * accessed directly. Use AudioFilter and AudioMixer for public audio
 * filtering functionality.
 * 
 * Thread Safety:
 * - On native platforms (sys), uses mutexes and atomic operations
 * - Ensures safe access from both main thread and audio thread
 * - Batches worklet changes to minimize lock contention
 * 
 * @see AudioFilter
 * @see AudioFilterWorklet
 * @see AudioMixer
 * @see Audio
 */
@:keep
class AudioFilters {

    #if sys
    private static var _workletsDirty:AtomicBool = new AtomicBool(true);
    private static var workletsDirty(get,set):Bool;
    inline static function get_workletsDirty():Bool {
        return _workletsDirty.load();
    }
    inline static function set_workletsDirty(workletsDirty:Bool):Bool {
        _workletsDirty.exchange(workletsDirty);
        return workletsDirty;
    }
    private static final allWorkletsLock = new sys.thread.Mutex();
    private static final accessBusLocks = new ceramic.SpinLock();
    private static final lockByBus:Array<ceramic.SpinLock> = [];
    #else
    private static var workletsDirty:Bool = true;
    #end

    private static final pendingWorklets:Array<AudioFilterWorklet> = [];
    private static final toRemoveWorklets:Array<AudioFilterWorklet> = [];

    private static final workletsByBus:Array<Array<AudioFilterWorklet>> = [];

    #if sys
    /**
     * The lock protecting a given bus, creating it if needed.
     *
     * Grown explicitly: an out of bounds access does not grow the storage
     * in every context this code is compiled for.
     */
    inline private static function busLock(bus:Int):ceramic.SpinLock {
        accessBusLocks.acquire();
        while (lockByBus.length <= bus) {
            lockByBus.push(new ceramic.SpinLock());
        }
        final lock = lockByBus[bus];
        accessBusLocks.release();
        return lock;
    }
    #end

    /**
     * Synchronizes pending worklet changes with the active worklet lists.
     * 
     * This method processes queued additions and removals of worklets,
     * updating the per-bus worklet arrays. Called by the audio backend
     * before processing audio to ensure all worklet changes are applied.
     * 
     * Thread-safe on native platforms using mutex locks.
     */
    @:allow(backend.Audio)
    private static function syncWorklets():Void {
        if (workletsDirty) {
            #if sys
            allWorkletsLock.acquire();
            #end
            while (pendingWorklets.length > 0) {
                final worklet = pendingWorklets.shift();
                final bus = worklet.bus;
                #if sys
                final lock = busLock(bus);
                lock.acquire();
                #end

                // Explicit growth with non-null arrays: haxe arrays grow on
                // out-of-bounds writes but the standalone (reflaxe.CPP)
                // storage does not, and null comparisons on non-nullable
                // types are compiled out there — so no null placeholders
                while (workletsByBus.length <= bus) {
                    workletsByBus.push([]);
                }
                workletsByBus[bus].push(worklet);

                #if sys
                lock.release();
                #end
            }
            while (toRemoveWorklets.length > 0) {
                final worklet = toRemoveWorklets.shift();
                final bus = worklet.bus;
                #if sys
                final lock = busLock(bus);
                lock.acquire();
                #end

                if (bus < workletsByBus.length) {
                    workletsByBus[bus].remove(worklet);
                }

                #if sys
                lock.release();
                #end
            }
            workletsDirty = false;
            #if sys
            allWorkletsLock.release();
            #end
        }
    }

    /**
     * Creates a new audio filter worklet and queues it for addition.
     * 
     * @param bus The audio bus ID where this worklet will process audio
     * @param filterId Unique identifier for the filter
     * @param workletClass The worklet class to instantiate
     * @return The created worklet instance
     */
    #if !reflaxe
    @:allow(backend.Audio)
    private static function createWorklet(bus:Int, filterId:Int, workletClass:Class<AudioFilterWorklet>):AudioFilterWorklet {
        final worklet = Type.createInstance(workletClass, [filterId, bus]);
        addWorklet(worklet);
        return worklet;
    }
    #end
    // (in the standalone reflaxe.CPP context, worklets are created through
    // a generated factory and registered with `addWorklet` — reflection is
    // not available there)

    /**
     * Queues an already-created worklet instance for addition.
     *
     * Used by the standalone (non-hxcpp) audio worklet host, where worklet
     * instances are created by a generated factory (a plain switch of
     * constructor calls) instead of reflection, which is not available
     * there.
     *
     * @param worklet The worklet instance to add
     */
    @:allow(backend.Audio)
    private static function addWorklet(worklet:AudioFilterWorklet):Void {
        #if sys
        allWorkletsLock.acquire();
        #end
        pendingWorklets.push(worklet);
        workletsDirty = true;
        #if sys
        allWorkletsLock.release();
        #end
    }

    /**
     * Destroys an audio filter worklet by queuing it for removal.
     * 
     * Searches for the worklet with the given filterId across all buses
     * and pending additions, then marks it for removal during the next sync.
     * 
     * @param bus The audio bus ID (currently unused but kept for API consistency)
     * @param filterId Unique identifier of the filter to destroy
     */
    @:allow(backend.Audio)
    private static function destroyWorklet(bus:Int, filterId:Int):Void {
        #if sys
        allWorkletsLock.acquire();
        #end
        // Remove a worklet, even if it's addition is pending
        for (i in 0...pendingWorklets.length) {
            final worklet = pendingWorklets[i];
            if (worklet.filterId == filterId) {
                toRemoveWorklets.push(worklet);
                workletsDirty = true;
                break;
            }
        }
        for (i in 0...workletsByBus.length) {
            final worklets = workletsByBus[i];
            if (worklets != null) {
                for (j in 0...worklets.length) {
                    final worklet = worklets[j];
                    if (worklet.filterId == filterId) {
                        toRemoveWorklets.push(worklet);
                        workletsDirty = true;
                        break;
                    }
                }
            }
        }
        #if sys
        allWorkletsLock.release();
        #end
    }

    /**
     * Begins a parameter update operation for a filter worklet.
     * 
     * On native platforms, this acquires the necessary locks to ensure
     * thread-safe parameter updates. Must be paired with endUpdateFilterWorkletParams.
     * 
     * @param bus The audio bus ID
     * @param filterId Unique identifier of the filter being updated
     */
    @:allow(backend.Audio)
    private static function beginUpdateFilterWorkletParams(bus:Int, filterId:Int):Void {
        #if sys
        busLock(bus).acquire();
        #end
    }

    /**
     * Ends a parameter update operation for a filter worklet.
     * 
     * Releases locks acquired by beginUpdateFilterWorkletParams.
     * 
     * @param bus The audio bus ID
     * @param filterId Unique identifier of the filter being updated
     */
    @:allow(backend.Audio)
    private static function endUpdateFilterWorkletParams(bus:Int, filterId:Int):Void {
        #if sys
        busLock(bus).release();
        #end
    }

    /**
     * Processes audio through all active worklets on a specific bus.
     * 
     * Called by the audio backend during audio processing. Applies each
     * worklet's processing in sequence to the provided audio buffer.
     * 
     * @param bus The audio bus ID to process
     * @param buffer The audio buffer containing samples to process
     * @param samples Number of samples per channel in the buffer
     * @param channels Number of audio channels (1 for mono, 2 for stereo)
     * @param sampleRate Sample rate in Hz (e.g., 44100, 48000)
     * @param time Current audio time in seconds
     */
    @:allow(backend.Audio)
    private static function processBusAudioWorklets(bus:Int, buffer:AudioFilterBuffer, samples:Int, channels:Int, sampleRate:Float, time:Float):Void {

        #if sys
        final lock = busLock(bus);
        lock.acquire();
        #end

        if (bus < workletsByBus.length) {
            final worklets = workletsByBus[bus];
            for (i in 0...worklets.length) {
                final worklet = worklets[i];
                worklet.process(buffer, samples, channels, sampleRate, time);
            }
        }

        #if sys
        lock.release();
        #end

    }

}
