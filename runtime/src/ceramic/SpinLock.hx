package ceramic;

#if sys

import haxe.atomic.AtomicBool;

/**
 * Lightweight spin lock implementation for low-contention thread synchronization.
 * 
 * SpinLock provides a busy-wait synchronization primitive that's more efficient
 * than traditional mutexes in scenarios with very low lock contention and short
 * critical sections. Unlike a mutex which puts threads to sleep, a spin lock
 * keeps the thread active while waiting, continuously checking if the lock
 * becomes available.
 * 
 * Key characteristics:
 * - Zero allocation cost (implemented as an abstract over AtomicBool)
 * - Same API as sys.thread.Mutex for easy drop-in replacement
 * - Best for protecting very short critical sections
 * - More CPU-intensive than Mutex when waiting
 * - No fair scheduling - threads may starve under high contention
 * 
 * When to use SpinLock:
 * - Lock is held for very short durations (< 1000 CPU cycles)
 * - Lock contention is expected to be low
 * - Critical section doesn't perform blocking operations
 * - You need minimal overhead for lock/unlock operations
 * 
 * When NOT to use SpinLock:
 * - High lock contention is expected
 * - Critical sections are long or perform I/O
 * - Fair thread scheduling is required
 * - Power consumption is a concern (spinning wastes CPU)
 * 
 * Example usage:
 * ```haxe
 * class Counter {
 *     var lock = new SpinLock();
 *     var value = 0;
 *     
 *     public function increment():Int {
 *         lock.acquire();
 *         var result = ++value;
 *         lock.release();
 *         return result;
 *     }
 *     
 *     public function tryIncrement():Bool {
 *         if (lock.tryAcquire()) {
 *             value++;
 *             lock.release();
 *             return true;
 *         }
 *         return false;
 *     }
 * }
 * ```
 * 
 * Available only on sys targets with threading support.
 * 
 * @see sys.thread.Mutex For traditional mutex with thread sleeping
 */
abstract SpinLock(AtomicBool) {

    /**
     * Creates a new spin lock in the unlocked state.
     */
    public inline function new() {
        this = new AtomicBool(false);
    }

    /**
     * Acquires the lock, blocking until it becomes available.
     * 
     * This method will continuously attempt to acquire the lock in a tight loop
     * (busy-wait) until successful. This is efficient for short wait times but
     * can waste CPU cycles if the lock is held for extended periods.
     * 
     * Warning: There is no timeout mechanism. If the lock is never released,
     * this method will spin forever.
     * 
     * Compatible with Mutex.acquire() API.
     */
    public inline function acquire():Void {
        while (!this.compareExchange(false, true)) {
            // Spin until we can acquire the lock
        }
    }

    /**
     * Attempts to acquire the lock without blocking.
     * 
     * This method makes a single attempt to acquire the lock. If the lock
     * is already held by another thread, it returns immediately rather
     * than waiting.
     * 
     * Use this when you want to:
     * - Avoid blocking if the resource is busy
     * - Implement timeout mechanisms
     * - Try alternative code paths when locked
     * 
     * Compatible with Mutex.tryAcquire() API.
     * 
     * @return true if the lock was successfully acquired, false if already locked
     */
    public inline function tryAcquire():Bool {
        return this.compareExchange(false, true);
    }

    /**
     * Releases the lock, allowing other threads to acquire it.
     * 
     * This method should only be called by the thread that currently
     * holds the lock. Calling release() on an unlocked SpinLock or
     * from a different thread results in undefined behavior.
     * 
     * The release operation is atomic and will immediately make the
     * lock available to other spinning threads.
     * 
     * Compatible with Mutex.release() API.
     */
    public inline function release():Void {
        this.store(false);
    }
}

#end
