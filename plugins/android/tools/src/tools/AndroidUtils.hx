package tools;

import js.node.ChildProcess;
import npm.StreamSplitter;
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

        final env:Dynamic = js.Syntax.code('process.env');

        if (env.ANDROID_HOME != null) {
            _sdkPath = env.ANDROID_HOME;
        }
        else if (env.ANDROID_SDK != null) {
            _sdkPath = env.ANDROID_SDK;
        }
        else if (env.ANDROID_SDK_ROOT != null) {
            _sdkPath = env.ANDROID_SDK_ROOT;
        }

        if (env.ANDROID_NDK_HOME != null) {
            _ndkPath = env.ANDROID_NDK_HOME;
        }
        else if (env.ANDROID_NDK != null) {
            _ndkPath = env.ANDROID_NDK;
        }
        else if (env.ANDROID_NDK_ROOT != null) {
            _ndkPath = env.ANDROID_NDK_ROOT;
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

        Sync.run(function(done) {

            var proc = null;
            if (args == null) {
                proc = ChildProcess.spawn(name, { cwd: cwd });
            } else {
                proc = ChildProcess.spawn(name, args, { cwd: cwd });
            }

            var out = StreamSplitter.splitter("\n");
            proc.stdout.on('data', function(data:Dynamic) {
                out.write(data);
            });
            proc.on('exit', function(code:Int) {
                status = code;
                if (done != null) {
                    var _done = done;
                    done = null;
                    _done();
                }
            });
            proc.on('close', function(code:Int) {
                status = code;
                if (done != null) {
                    var _done = done;
                    done = null;
                    _done();
                }
            });
            out.encoding = 'utf8';
            out.on('token', function(token:String) {
                if (token != null && RE_ANDROID_LOG_TRACE.match(token)) {
                    token = RE_ANDROID_LOG_TRACE.matched(1);
                    token = formatLineOutput(logCwd, token);
                    stdoutWrite(token + "\n");
                }
            });
            out.on('done', function() {
            });
            out.on('error', function(err) {
            });

            var err = StreamSplitter.splitter("\n");
            proc.stderr.on('data', function(data:Dynamic) {
                err.write(data);
            });
            err.encoding = 'utf8';
            err.on('token', function(token:String) {
                token = formatLineOutput(logCwd, token);
                stderrWrite(token + "\n");
            });
            err.on('error', function(err) {
            });

        });

        return status;

    }

}
