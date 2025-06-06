package ceramic;

#if sys

import haxe.atomic.AtomicBool;

/**
 * Zero-cost spin lock abstract with the same API as sys.thread.Mutex
 * Can be used as a drop-in replacement for Mutex in low-contention scenarios
 */
abstract SpinLock(AtomicBool) {

    public inline function new() {
        this = new AtomicBool(false);
    }

    /**
     * Acquire the lock. Blocks (spins) until the lock is available.
     * Same API as Mutex.acquire()
     */
    public inline function acquire():Void {
        while (!this.compareExchange(false, true)) {
            // Spin until we can acquire the lock
        }
    }

    /**
     * Try to acquire the lock without blocking.
     * Returns true if lock was acquired, false if already locked.
     * Same API as Mutex.tryAcquire()
     */
    public inline function tryAcquire():Bool {
        return this.compareExchange(false, true);
    }

    /**
     * Release the lock.
     * Same API as Mutex.release()
     */
    public inline function release():Void {
        this.store(false);
    }
}

#end
