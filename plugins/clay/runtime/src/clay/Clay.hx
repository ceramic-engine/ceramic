package clay;

/**
 * Clay app
 */
class Clay {

    /**
     * Get Clay instance from anywhere with `Clay.app`
     */
    public static var app(default, null):Clay;

    /**
     * Clay config
     */
    public var events(default, null):Config;

    /**
     * Clay events handler
     */
    public var config(default, null):Events;

    /**
     * Clay io
     * (implementation varies depending on the target)
     */
    public var io(default, null):IO;

    /**
     * Clay runtime
     * (implementation varies depending on the target)
     */
    public var runtime(default, null):Runtime;

    /**
     * Create a new Clay app
     * @param config Configuration to setup Clay app
     * @param events Events handler to get feedback from Clay
     */
    function new(config:Config, events:Events) {

        Clay.app = this;
        this.config = config;
        this.events = events;

        @:privateAccess io = new IO();
        Immediate.flush();

        @:privateAccess runtime = new Runtime();
        Immediate.flush();

        init();

    }

    function init() {

        Log.debug('Clay / init');

        io.init();
        Immediate.flush();

        runtime.init();
        Immediate.flush();

        Log.debug('Clay / ready');
        runtime.handleReady();

    }

}
