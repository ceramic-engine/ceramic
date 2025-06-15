package ceramic;

#if sys
import haxe.atomic.AtomicBool;
import haxe.atomic.AtomicInt;
#end

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
                accessBusLocks.acquire();
                var busLock = lockByBus[bus];
                if (busLock == null) {
                    busLock = new ceramic.SpinLock();
                    lockByBus[bus] = busLock;
                }
                busLock.acquire();
                accessBusLocks.release();
                #end

                var worklets = workletsByBus[bus];
                if (worklets == null) {
                    worklets = [];
                    workletsByBus[bus] = worklets;
                }
                worklets.push(worklet);

                #if sys
                busLock.release();
                #end
            }
            while (toRemoveWorklets.length > 0) {
                final worklet = toRemoveWorklets.shift();
                final bus = worklet.bus;
                #if sys
                accessBusLocks.acquire();
                var busLock = lockByBus[bus];
                if (busLock == null) {
                    busLock = new ceramic.SpinLock();
                    lockByBus[bus] = busLock;
                }
                busLock.acquire();
                accessBusLocks.release();
                #end

                var worklets = workletsByBus[bus];
                if (worklets != null) {
                    worklets.remove(worklet);
                }

                #if sys
                busLock.release();
                #end
            }
            workletsDirty = false;
            #if sys
            allWorkletsLock.release();
            #end
        }
    }

    @:allow(backend.Audio)
    private static function createWorklet(bus:Int, filterId:Int, workletClass:Class<AudioFilterWorklet>):AudioFilterWorklet {
        final worklet = Type.createInstance(workletClass, [filterId, bus]);
        #if sys
        allWorkletsLock.acquire();
        #end
        pendingWorklets.push(worklet);
        workletsDirty = true;
        #if sys
        allWorkletsLock.release();
        #end
        return worklet;
    }

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

    @:allow(backend.Audio)
    private static function beginUpdateFilterWorkletParams(bus:Int, filterId:Int):Void {
        #if sys
        accessBusLocks.acquire();
        final busLock = lockByBus[bus];
        if (busLock != null) {
            busLock.release();
        }
        accessBusLocks.release();
        #end
    }

    @:allow(backend.Audio)
    private static function endUpdateFilterWorkletParams(bus:Int, filterId:Int):Void {
        #if sys
        accessBusLocks.acquire();
        final busLock = lockByBus[bus];
        if (busLock != null) {
            busLock.release();
        }
        accessBusLocks.release();
        #end
    }

    @:allow(backend.Audio)
    private static function processBusAudioWorklets(bus:Int, buffer:AudioFilterBuffer, samples:Int, channels:Int, sampleRate:Float, time:Float):Void {

        #if sys
        accessBusLocks.acquire();
        final busLock = lockByBus[bus];
        if (busLock != null) {
            busLock.acquire();
            accessBusLocks.release();
        #end

            final worklets = workletsByBus[bus];
            if (worklets != null) {
                for (i in 0...worklets.length) {
                    final worklet = worklets[i];
                    worklet.process(buffer, samples, channels, sampleRate, time);
                }
            }

        #if sys
            busLock.release();
        }
        else {
            accessBusLocks.release();
        }
        #end

    }

}
