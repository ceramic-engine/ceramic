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
    private static final accessChannelLocks = new ceramic.SpinLock();
    private static final lockByChannel:Array<ceramic.SpinLock> = [];
    #else
    private static var workletsDirty:Bool = true;
    #end

    private static final pendingWorklets:Array<AudioFilterWorklet> = [];
    private static final toRemoveWorklets:Array<AudioFilterWorklet> = [];

    private static final workletsByChannel:Array<Array<AudioFilterWorklet>> = [];

    @:allow(backend.Audio)
    private static function syncWorklets():Void {
        if (workletsDirty) {
            #if sys
            allWorkletsLock.acquire();
            #end
            while (pendingWorklets.length > 0) {
                final worklet = pendingWorklets.shift();
                final channel = worklet.channel;
                #if sys
                accessChannelLocks.acquire();
                var channelLock = lockByChannel[channel];
                if (channelLock == null) {
                    channelLock = new ceramic.SpinLock();
                    lockByChannel[channel] = channelLock;
                }
                channelLock.acquire();
                accessChannelLocks.release();
                #end

                var worklets = workletsByChannel[channel];
                if (worklets == null) {
                    worklets = [];
                    workletsByChannel[channel] = worklets;
                }
                worklets.push(worklet);

                #if sys
                channelLock.release();
                #end
            }
            while (toRemoveWorklets.length > 0) {
                final worklet = toRemoveWorklets.shift();
                final channel = worklet.channel;
                #if sys
                accessChannelLocks.acquire();
                var channelLock = lockByChannel[channel];
                if (channelLock == null) {
                    channelLock = new ceramic.SpinLock();
                    lockByChannel[channel] = channelLock;
                }
                channelLock.acquire();
                accessChannelLocks.release();
                #end

                var worklets = workletsByChannel[channel];
                if (worklets != null) {
                    worklets.remove(worklet);
                }

                #if sys
                channelLock.release();
                #end
            }
            workletsDirty = false;
            #if sys
            allWorkletsLock.release();
            #end
        }
    }

    @:allow(backend.Audio)
    private static function createWorklet(channel:Int, filterId:Int, workletClass:Class<AudioFilterWorklet>):AudioFilterWorklet {
        final worklet = Type.createInstance(workletClass, [filterId, channel]);
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
    private static function destroyWorklet(channel:Int, filterId:Int):Void {
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
        for (i in 0...workletsByChannel.length) {
            final worklets = workletsByChannel[i];
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
    private static function beginUpdateFilterWorkletParams(channel:Int, filterId:Int):Void {
        #if sys
        accessChannelLocks.acquire();
        final channelLock = lockByChannel[channel];
        if (channelLock != null) {
            channelLock.release();
        }
        accessChannelLocks.release();
        #end
    }

    @:allow(backend.Audio)
    private static function endUpdateFilterWorkletParams(channel:Int, filterId:Int):Void {
        #if sys
        accessChannelLocks.acquire();
        final channelLock = lockByChannel[channel];
        if (channelLock != null) {
            channelLock.release();
        }
        accessChannelLocks.release();
        #end
    }

    @:allow(backend.Audio)
    private static function processChannelAudioWorklets(channel:Int, buffer:AudioFilterBuffer, samples:Int, bufferChannels:Int, sampleRate:Float, time:Float):Void {

        #if sys
        accessChannelLocks.acquire();
        final channelLock = lockByChannel[channel];
        if (channelLock != null) {
            channelLock.acquire();
            accessChannelLocks.release();
        #end

            final worklets = workletsByChannel[channel];
            if (worklets != null) {
                for (i in 0...worklets.length) {
                    final worklet = worklets[i];
                    worklet.process(buffer, samples, bufferChannels, sampleRate, time);
                }
            }

        #if sys
            channelLock.release();
        }
        else {
            accessChannelLocks.release();
        }
        #end

    }

}
