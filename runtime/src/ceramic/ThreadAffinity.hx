package ceramic;

/**
 * The kind of CPU cores a thread should run on (see `Runner.setThreadAffinity`), on
 * devices whose cores are not all the same (big.LITTLE, performance and efficiency
 * cores).
 *
 * On Android and Linux, the thread is restricted to these cores. On iOS and macOS, it is
 * given a quality of service class that leads the system to these cores, without
 * restricting it. Elsewhere, it has no effect.
 */
enum abstract ThreadAffinity(Int) from Int to Int {

    /**
     * Any core: undoes a previous choice.
     */
    var ANY = 0;

    /**
     * Only the slowest cores (efficiency cores): work with no hurry that should not take
     * time from the fast cores (loading, saving, decoding). On iOS and macOS, the system
     * also slows down the disk and network accesses of such a thread.
     */
    var SLOW = 1;

    /**
     * Every core but the slowest ones: work that the next frames wait for.
     */
    var FAST = 2;

    /**
     * Only the fastest cores (the "prime" core, when there is one). Same as `FAST` on iOS
     * and macOS.
     */
    var FASTEST = 3;

}
