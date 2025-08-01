package ceramic;

/**
 * Defines how multiple assets are scheduled for loading.
 * 
 * This setting controls whether assets load simultaneously or sequentially,
 * affecting loading performance and resource usage.
 * 
 * @see Assets.scheduleMethod
 */
enum abstract AssetsScheduleMethod(Int) {

    /**
     * Assets are all loaded in parallel (if not blocked by thread constraints).
     * 
     * Benefits:
     * - Faster overall loading time
     * - Better utilization of network/disk bandwidth
     * - Optimal for modern multi-core systems
     * 
     * Drawbacks:
     * - Higher memory usage during loading
     * - May overwhelm slower systems or connections
     * 
     * Use `Assets.delayBetweenXAssets` to throttle parallel loading if needed.
     */
    var PARALLEL = 1;

    /**
     * Assets are loaded one after another in sequence.
     * 
     * Benefits:
     * - Lower memory footprint during loading
     * - More predictable resource usage
     * - Better for memory-constrained devices
     * - Easier to debug loading issues
     * 
     * Drawbacks:
     * - Slower total loading time
     * - Doesn't utilize available parallelism
     */
    var SERIAL = 2;

}
