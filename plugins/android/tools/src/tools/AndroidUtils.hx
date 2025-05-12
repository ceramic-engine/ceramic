package tools;

import haxe.io.Path;
import process.Process;
import sys.FileSystem;
import sys.io.File;
import tools.Helpers.*;
import tools.HxcppConfig;
import tools.HxcppConfig;

using StringTools;

class AndroidUtils {

    static var _didTryResolvePaths:Bool = false;

    static var _sdkPath:String = null;

    static var _ndkPath:String = null;

    static final RE_ANDROID_LOG_TRACE = ~/I\s+trace\s*:\s*(.*)$/;

    public static function sdkPath():String {

        if (!_didTryResolvePaths) {
            _didTryResolvePaths = true;
            resolvePaths();
        }

        return _sdkPath;

    }

    public static function ndkPath():String {

        if (!_didTryResolvePaths) {
            _didTryResolvePaths = true;
            resolvePaths();
        }

        return _ndkPath;

    }

    static final RE_SOURCE_PROPERTIES_NDK_VERSION = ~/Pkg\.Revision\s*=\s*(\d+)\.(\d+)\.(\d+)/;

    public static function ndkVersionNumber():Int {

        final ndkPath = AndroidUtils.ndkPath();

        // Return 0 if NDK path is not available
        if (ndkPath == null || ndkPath.length == 0) {
            return 0;
        }

        // Path to source.properties file
        final propertiesPath = Path.join([ndkPath, "source.properties"]);

        // Check if the file exists
        if (!FileSystem.exists(propertiesPath)) {
            return 0;
        }

        try {
            // Read the source.properties file
            final content = File.getContent(propertiesPath);

            // Regular expression to extract the version number
            final versionRegex = RE_SOURCE_PROPERTIES_NDK_VERSION;

            if (versionRegex.match(content)) {
                // Extract the major version as integer
                final major = Std.parseInt(versionRegex.matched(1));

                // Return the major version, or 0 if parsing failed
                return major != null ? major : 0;
            }
        } catch (e:Dynamic) {
            // Log the error but don't crash
            warning('Failed to read NDK version: $e');
        }

        // Return 0 if version extraction failed
        return -1;

    }

    static function resolvePaths() {

        // Gather env and defines
        final env = Sys.environment();
        final localDefines = new Map<String,String>();
        for (key in env.keys()) {
            localDefines.set(key, Sys.getEnv(key));
        }
        for (key in context.defines.keys()) {
            localDefines.set(key, context.defines.get(key));
        }

        // Load .hxcpp_config
        HxcppConfig.readHxcppConfig(localDefines);

        // Resolve final SDK path
        if (localDefines.get('ANDROID_HOME') != null) {
            _sdkPath = localDefines.get('ANDROID_HOME');
        }
        else if (localDefines.get('ANDROID_SDK') != null) {
            _sdkPath = localDefines.get('ANDROID_SDK');
        }
        else if (localDefines.get('ANDROID_SDK_ROOT') != null) {
            _sdkPath = localDefines.get('ANDROID_SDK_ROOT');
        }

        // Resolve final NDK path
        if (localDefines.get('ANDROID_NDK_HOME') != null) {
            _ndkPath = localDefines.get('ANDROID_NDK_HOME');
        }
        else if (localDefines.get('ANDROID_NDK') != null) {
            _ndkPath = localDefines.get('ANDROID_NDK');
        }
        else if (localDefines.get('ANDROID_NDK_ROOT') != null) {
            _ndkPath = localDefines.get('ANDROID_NDK_ROOT');
        }

    }

    /** Like `commandWithCheckAndLogs()`, but will expect android logcat output
        that will be cleaned in order to get similar output as when launching a desktop app
        @return status code */
    public static function commandWithLogcatOutput(name:String, ?args:Array<String>, ?options:{ ?cwd:String, ?logCwd:String, ?debug:Bool }):Int {

        if (options == null) {
            options = { cwd: null, logCwd: null, debug: false };
        }
        if (options.cwd == null) options.cwd = context.cwd;
        if (options.logCwd == null) options.logCwd = options.cwd;
        if (options.debug == null) options.debug = false;

        var status = 0;

        var logCwd = options.logCwd;

        var inLogs = false;

        final proc = new Process(name, args, options.cwd);

        proc.inherit_file_descriptors = false;

        var stdout = new SplitStream('\n'.code, line -> {
            if (!inLogs && line != null && Std.string(line).trim() == '----------- LOGS BEGIN -----------') {
                inLogs = true;
            }
            else if (inLogs && line != null && Std.string(line).trim() == '----------- LOGS END -----------') {
                inLogs = false;
                proc.kill(true);
            }
            else if (line != null && RE_ANDROID_LOG_TRACE.match(line) && (options.debug || inLogs)) {
                line = RE_ANDROID_LOG_TRACE.matched(1);
                line = formatLineOutput(logCwd, line);
                stdoutWrite(line + "\n");
            }
            else if (line != null && (options.debug || !inLogs)) {
                stdoutWrite(line + "\n");
            }
        });

        var stderr = new SplitStream('\n'.code, line -> {
            line = formatLineOutput(logCwd, line);
            stderrWrite(line + "\n");
        });

        proc.read_stdout = data -> {
            stdout.add(data);
        };

        proc.read_stderr = data -> {
            stderr.add(data);
        };

        proc.create();

        final status = proc.tick_until_exit_status(() -> {
            Runner.tick();
            timer.update();
            if (context.shouldExit) {
                proc.kill(false);
                Sys.exit(0);
            }
        });

        return status;

    }

}
