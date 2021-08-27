package ceramic;

enum abstract AssetsScheduleMethod(Int) {

    /**
     * Assets are all loaded in parallel (if not blocked by their thread)
     */
    var PARALLEL = 1;

    /**
     * Assets are loaded one after another
     */
    var SERIAL = 2;

}
