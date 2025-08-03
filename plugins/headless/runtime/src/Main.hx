package;

import ceramic.Path;

/**
 * Main entry point for the Ceramic headless backend.
 * 
 * The headless backend allows Ceramic applications to run without a display,
 * making it suitable for server-side rendering, automated testing, and other
 * scenarios where visual output is not required.
 * 
 * This class initializes the headless backend, sets up the project environment,
 * and handles the main application loop for JavaScript targets.
 */
class Main {

    /**
     * Reference to the current project instance.
     * This is set during initialization and provides access to the running project.
     */
    public static var project:Project = null;

    /**
     * Stores the timestamp of the last update call (JavaScript only).
     * Used to calculate delta time between updates.
     */
    static var _lastUpdateTime:Float = -1;

    /**
     * Main entry point for the headless backend.
     * 
     * Initializes the Ceramic application with the headless backend,
     * sets up the project directory path, and starts the update loop
     * for JavaScript targets.
     */
    public static function main():Void {

        project = @:privateAccess new Project(ceramic.App.init());

        #if (!ceramic_no_fs && (sys || node || nodejs || hxnodejs))
        // Set project directory to three levels up from current working directory
        // This assumes the standard Ceramic project structure
        ceramic.App.app.projectDir = Path.normalize(Path.join([Sys.getCwd(), '../../..']));
        #end

        #if js
        // For JavaScript targets, set up a timer-based update loop
        _lastUpdateTime = js.Syntax.code('new Date().getTime()');
        js.Syntax.code('setInterval({0}, 100)', update);
        #end

        // Signal that the backend is ready
        ceramic.App.app.backend.emitReady();

    }

    /**
     * Update loop for JavaScript targets.
     * 
     * Calculates delta time since the last update and triggers
     * the application's update and render cycles. This runs
     * every 100 milliseconds when on JavaScript platforms.
     */
    static function update() {

        #if js
        var time:Float = js.Syntax.code('new Date().getTime()');
        var delta = (time - _lastUpdateTime) * 0.001;
        _lastUpdateTime = time;

        // Trigger application update and render cycles
        ceramic.App.app.backend.emitUpdate(delta);
        ceramic.App.app.backend.emitRender();
        #end

    }

}
