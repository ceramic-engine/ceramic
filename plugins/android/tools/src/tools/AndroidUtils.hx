package tools;

import process.Process;
import tools.Helpers.*;

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

    static function resolvePaths() {

        if (Sys.getEnv('ANDROID_HOME') != null) {
            _sdkPath = Sys.getEnv('ANDROID_HOME');
        }
        else if (Sys.getEnv('ANDROID_SDK') != null) {
            _sdkPath = Sys.getEnv('ANDROID_SDK');
        }
        else if (Sys.getEnv('ANDROID_SDK_ROOT') != null) {
            _sdkPath = Sys.getEnv('ANDROID_SDK_ROOT');
        }

        if (Sys.getEnv('ANDROID_NDK_HOME') != null) {
            _ndkPath = Sys.getEnv('ANDROID_NDK_HOME');
        }
        else if (Sys.getEnv('ANDROID_NDK') != null) {
            _ndkPath = Sys.getEnv('ANDROID_NDK');
        }
        else if (Sys.getEnv('ANDROID_NDK_ROOT') != null) {
            _ndkPath = Sys.getEnv('ANDROID_NDK_ROOT');
        }

    }

    /** Like `commandWithCheckAndLogs()`, but will expect android logcat output
        that will be cleaned in order to get similar output as when launching a desktop app
        @return status code */
    public static function commandWithLogcatOutput(name:String, ?args:Array<String>, ?options:{ ?cwd:String, ?logCwd:String }):Int {

        if (options == null) {
            options = { cwd: null, logCwd: null };
        }
        if (options.cwd == null) options.cwd = context.cwd;
        if (options.logCwd == null) options.logCwd = options.cwd;

        var status = 0;

        var cwd = options.cwd;
        var logCwd = options.logCwd;

        final proc = new Process(name, args, options.cwd);

        proc.inherit_file_descriptors = false;

        var stdout = new SplitStream('\n'.code, line -> {
            if (line != null && RE_ANDROID_LOG_TRACE.match(line)) {
                line = RE_ANDROID_LOG_TRACE.matched(1);
                line = formatLineOutput(logCwd, line);
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
        });

        return status;

    }

}
