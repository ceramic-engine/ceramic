package ceramic;

/**
 * The kind of CPU cores a thread should run on (see `Runner.setThreadCores`), on devices
 * whose cores are not all the same (big.LITTLE): the clusters are told apart by their
 * maximum frequency, read from the device.
 */
enum abstract ThreadCores(Int) from Int to Int {

    /**
     * Any core the app is allowed to use: undoes a previous choice.
     */
    var ANY = 0;

    /**
     * Only the slowest cores (the cluster with the lowest maximum frequency): work with
     * no hurry that should not take time from the fast cores (loading, saving, decoding).
     */
    var SLOW = 1;

    /**
     * Every core but the slowest ones: work that the next frames wait for.
     */
    var FAST = 2;

    /**
     * Only the cores with the highest maximum frequency (the "prime" core, when there is
     * one).
     */
    var FASTEST = 3;

}
