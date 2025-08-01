package ceramic;

/**
 * Centralized logging system for Ceramic applications that provides colored, categorized output.
 *
 * The Logger class extends Entity to provide event-based logging with different severity levels.
 * It handles platform-specific output formatting (Unity, Web, Native) and thread-safe logging
 * from background threads. All log messages can be observed through events for custom handling.
 *
 * The logger supports five severity levels:
 * - `debug`: Development and diagnostic information (magenta in Unity, [debug] prefix)
 * - `info`: General informational messages (cyan in Unity, [info] prefix)
 * - `success`: Success confirmations (lime in Unity, [success] prefix)
 * - `warning`: Warning messages (yellow in Unity, uses console.warn on web)
 * - `error`: Error messages (red in Unity, uses console.error on web)
 *
 * Example usage:
 * ```haxe
 * // Basic logging (accessible via `log` in Ceramic project)
 * log.info("Game started");
 * log.debug("Player position: " + player.x + ", " + player.y);
 * log.warning("Low memory detected");
 * log.error("Failed to load save file");
 *
 * // Hierarchical logging with indentation
 * log.info("Loading assets...");
 * log.pushIndent();
 * log.info("Loading textures...");
 * log.info("Loading sounds...");
 * log.popIndent();
 * log.success("Assets loaded!");
 *
 * // Listen to log events
 * log.onInfo(this, (value, pos) -> {
 *     // Custom handling of info messages
 *     saveToLogFile(value, pos);
 * });
 * ```
 *
 * Compile-time flags:
 * - `ceramic_mute_logs`: Disables all console output (events still fire)
 * - `ceramic_no_log`: Completely removes logging code (no output, no events)
 * - `ceramic_unity_no_log`: Disables Unity-specific console output
 */
@:allow(ceramic.App)
class Logger extends Entity {

/// Events

    /**
     * Emitted when an info message is logged.
     * @param value The logged value (converted to string for display)
     * @param pos Source code position information
     */
    @event function _info(value:Dynamic, ?pos:haxe.PosInfos);

    /**
     * Emitted when a debug message is logged.
     * @param value The logged value (converted to string for display)
     * @param pos Source code position information
     */
    @event function _debug(value:Dynamic, ?pos:haxe.PosInfos);

    /**
     * Emitted when a success message is logged.
     * @param value The logged value (converted to string for display)
     * @param pos Source code position information
     */
    @event function _success(value:Dynamic, ?pos:haxe.PosInfos);

    /**
     * Emitted when a warning message is logged.
     * @param value The logged value (converted to string for display)
     * @param pos Source code position information
     */
    @event function _warning(value:Dynamic, ?pos:haxe.PosInfos);

    /**
     * Emitted when an error message is logged.
     * @param value The logged value (converted to string for display)
     * @param pos Source code position information
     */
    @event function _error(value:Dynamic, ?pos:haxe.PosInfos);

/// Internal

#if web
    private static var _hasElectronRunner:Bool = false;
#end

    /**
     * Current indentation prefix for hierarchical logging.
     * Each level adds 4 spaces to create visual hierarchy in log output.
     */
    var indentPrefix:String = '';

    static var didInitOnce:Bool = false;

    /**
     * Creates a new Logger instance.
     * Configures platform-specific trace handlers on first initialization.
     */
    public function new() {

        super();

        if (!didInitOnce) {
            didInitOnce = true;
#if ceramic_mute_logs
            haxe.Log.trace = function(v:Dynamic, ?pos:haxe.PosInfos):Void {
                // Logs disabled
            };
#else
#if unity
            haxe.Log.trace = function(v:Dynamic, ?pos:haxe.PosInfos):Void {
                #if !ceramic_unity_no_log
                untyped __cs__('UnityEngine.Debug.Log({0}+{1}+{2}+":"+{3})', v, '\n', pos.fileName, pos.lineNumber);
                #end
            };
#end
#end
        }
    }

/// Public API

#if (!completion && ceramic_no_log)
    inline public function debug(value:Dynamic, ?pos:haxe.PosInfos):Void {}
    inline public function info(value:Dynamic, ?pos:haxe.PosInfos):Void {}
    inline public function success(value:Dynamic, ?pos:haxe.PosInfos):Void {}
    inline public function warning(value:Dynamic, ?pos:haxe.PosInfos):Void {}
    inline public function error(value:Dynamic, ?pos:haxe.PosInfos):Void {}
#else
    /**
     * Logs a debug message with magenta/[debug] formatting.
     *
     * Debug messages are intended for development and diagnostic information
     * that helps understand program flow and state during development.
     * These messages are typically filtered out in production builds.
     *
     * Thread-safe: Can be called from background threads.
     *
     * @param value The value to log (will be converted to string)
     * @param pos Source position information (automatically provided)
     */
    public function debug(value:Dynamic, ?pos:haxe.PosInfos):Void {

        if (!Runner.currentIsMainThread()) {
            if (listensDebug()) {
                Runner.runInMain(function() {
                    emitDebug(value, pos);
                });
            }
        }
        else {
            emitDebug(value, pos);
        }

#if !ceramic_mute_logs
#if unity
#if !ceramic_unity_no_log
        untyped __cs__('UnityEngine.Debug.Log("<color=magenta>"+{0}+"</color>"+{1}+{2}+":"+{3})', value, '\n', pos.fileName, pos.lineNumber);
#end
#else
        haxe.Log.trace(prefixLines('[debug] ', value), pos);
#end
#end

    }

    /**
     * Logs an informational message with cyan/[info] formatting.
     *
     * Info messages communicate general application state and progress.
     * Use for non-critical information that helps understand what the
     * application is doing during normal operation.
     *
     * Thread-safe: Can be called from background threads.
     *
     * @param value The value to log (will be converted to string)
     * @param pos Source position information (automatically provided)
     */
    public function info(value:Dynamic, ?pos:haxe.PosInfos):Void {

        if (!Runner.currentIsMainThread()) {
            if (listensInfo()) {
                Runner.runInMain(function() {
                    emitInfo(value, pos);
                });
            }
        }
        else {
            emitInfo(value, pos);
        }

#if !ceramic_mute_logs
#if unity
#if !ceramic_unity_no_log
        untyped __cs__('UnityEngine.Debug.Log("<color=cyan>"+{0}+"</color>"+{1}+{2}+":"+{3})', value, '\n', pos.fileName, pos.lineNumber);
#end
#else
        haxe.Log.trace(prefixLines('[info] ', value), pos);
#end
#end

    }

    /**
     * Logs a success message with lime/[success] formatting.
     *
     * Success messages indicate successful completion of operations.
     * Use to confirm that important actions completed without errors,
     * such as asset loading, save operations, or network requests.
     *
     * Thread-safe: Can be called from background threads.
     *
     * @param value The value to log (will be converted to string)
     * @param pos Source position information (automatically provided)
     */
    public function success(value:Dynamic, ?pos:haxe.PosInfos):Void {

        if (!Runner.currentIsMainThread()) {
            if (listensSuccess()) {
                Runner.runInMain(function() {
                    emitSuccess(value, pos);
                });
            }
        }
        else {
            emitSuccess(value, pos);
        }

#if !ceramic_mute_logs
#if unity
#if !ceramic_unity_no_log
        untyped __cs__('UnityEngine.Debug.Log("<color=lime>"+{0}+"</color>"+{1}+{2}+":"+{3})', value, '\n', pos.fileName, pos.lineNumber);
#end
#else
        haxe.Log.trace(prefixLines('[success] ', value), pos);
#end
#end

    }

    /**
     * Logs a warning message with yellow/[warning] formatting.
     *
     * Warning messages indicate potential issues that don't prevent
     * operation but may cause problems. Uses native console.warn()
     * on web platforms for proper browser dev tools integration.
     *
     * Thread-safe: Can be called from background threads.
     *
     * @param value The value to log (will be converted to string)
     * @param pos Source position information (automatically provided)
     */
    public function warning(value:Dynamic, ?pos:haxe.PosInfos):Void {

        if (!Runner.currentIsMainThread()) {
            if (listensWarning()) {
                Runner.runInMain(function() {
                    emitWarning(value, pos);
                });
            }
        }
        else {
            emitWarning(value, pos);
        }

#if !ceramic_mute_logs
#if unity
#if !ceramic_unity_no_log
        untyped __cs__('UnityEngine.Debug.LogWarning("<color=yellow>"+{0}+"</color>"+{1}+{2}+":"+{3})', value, '\n', pos.fileName, pos.lineNumber);
#end
#elseif web
        if (_hasElectronRunner) {
            haxe.Log.trace(prefixLines('[warning] ', value), pos);
        } else {
            untyped console.warn(value);
        }
#else
        haxe.Log.trace(prefixLines('[warning] ', value), pos);
#end
#end

    }

    /**
     * Logs an error message with red/[error] formatting.
     *
     * Error messages indicate failures that may affect application behavior.
     * Uses native console.error() on web platforms for proper browser
     * dev tools integration with stack traces.
     *
     * Thread-safe: Can be called from background threads.
     *
     * @param value The value to log (will be converted to string)
     * @param pos Source position information (automatically provided)
     */
    public function error(value:Dynamic, ?pos:haxe.PosInfos):Void {

        if (!Runner.currentIsMainThread()) {
            if (listensError()) {
                Runner.runInMain(function() {
                    emitError(value, pos);
                });
            }
        }
        else {
            emitError(value, pos);
        }

#if !ceramic_mute_logs
#if unity
#if !ceramic_unity_no_log
        untyped __cs__('UnityEngine.Debug.LogError("<color=red>"+{0}+"</color>"+{1}+{2}+":"+{3})', value, '\n', pos.fileName, pos.lineNumber);
#end
#elseif web
        if (_hasElectronRunner) {
            haxe.Log.trace(prefixLines('[error] ', value), pos);
        } else {
            untyped console.error(value);
        }
#else
        haxe.Log.trace(prefixLines('[error] ', value), pos);
#end
#end

    }
#end

    /**
     * Increases the indentation level for subsequent log messages.
     *
     * Each call adds 4 spaces to the beginning of log messages,
     * creating a visual hierarchy in the output. Useful for logging
     * nested operations or sub-tasks.
     *
     * Must be balanced with popIndent() calls.
     *
     * Example:
     * ```haxe
     * logger.info("Processing items...");
     * logger.pushIndent();
     * for (item in items) {
     *     logger.info("Processing: " + item.name);
     * }
     * logger.popIndent();
     * logger.success("Done!");
     * ```
     */
    inline public function pushIndent() {

        indentPrefix += '    ';

    }

    /**
     * Decreases the indentation level for subsequent log messages.
     *
     * Removes 4 spaces from the indentation prefix. Should be called
     * to balance each pushIndent() call.
     *
     * @see pushIndent
     */
    inline public function popIndent() {

        indentPrefix = indentPrefix.substring(0, indentPrefix.length - 4);

    }

/// Internal

    /**
     * Adds prefix and indentation to each line of the input.
     * Used internally to format multi-line log messages with proper
     * category prefixes and indentation.
     *
     * @param prefix The category prefix like "[info] "
     * @param input The value to format (converted to string)
     * @return The formatted string with prefix on each line
     */
    function prefixLines(prefix:String, input:Dynamic):String {

        var result = [];
        for (line in Std.string(input).split("\n")) {
            result.push(prefix + indentPrefix + line);
        }
        return result.join("\n");

    }

}