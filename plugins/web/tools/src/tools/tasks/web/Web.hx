package tools.tasks.web;

import tools.Helpers.*;
import tools.Project;
import tools.Colors;
import tools.Files;
import haxe.io.Path;
import haxe.Json;
import sys.FileSystem;
import sys.io.File;

import js.node.Os;
import js.node.ChildProcess;

import npm.StreamSplitter;
import npm.Fiber;
import npm.Chokidar;

import hotml.server.Main as HotReloadServer;

using StringTools;

class Web extends tools.Task {

    override public function info(cwd:String):String {

        return "Generate or update Web/HTML5 project to run or debug it";

    }

    override function run(cwd:String, args:Array<String>):Void {

        var project = ensureCeramicProject(cwd, args, App);

        var webProjectPath = Path.join([cwd, 'project/web']);
        var webProjectFilePath = Path.join([webProjectPath, 'index.html']);

        var doRun = extractArgFlag(args, 'run');
        var doWatch = extractArgFlag(args, 'watch');
        var doHotReload = extractArgFlag(args, 'hot-reload');
        var electronErrors = extractArgFlag(args, 'electron-errors');

        // Create web project if needed
        WebProject.createWebProjectIfNeeded(cwd, project);

        // Copy built files and assets
        var outTargetPath = BuildTargetExtensions.outPathWithName('luxe', 'web', cwd, context.debug, context.variant);
        //var flowWebHtmlPath = Path.join([outTargetPath, 'bin/web']);

        // Copy assets
        //Files.copyDirectory(Path.join([flowWebHtmlPath, 'assets']), Path.join([cwd, 'project/web/assets']));

        // Copy javascript files
        var jsName = project.app.name;
        /*
        if (FileSystem.exists(Path.join([flowWebHtmlPath, jsName + '.js.map']))) {
            File.copy(Path.join([flowWebHtmlPath, jsName + '.js.map']), Path.join([cwd, 'project/web', jsName + '.js.map']));
        }
        File.copy(Path.join([flowWebHtmlPath, jsName + '.js']), Path.join([cwd, 'project/web', jsName + '.js']));*/

        // Stop if not running
        if (!doRun) return;

        // Run project through electron/ceramic-runner
        print('Start ceramic runner');
        var webAppFilesPath = Path.join([cwd, 'project/web']);

        var status = 0;

        Sync.run(function(done) {

            var cmdArgs = ['--app-files', webAppFilesPath];

            if (context.debug) {
                cmdArgs = ['--remote-debugging-port=9223'].concat(cmdArgs);
            }

            if (doWatch) {
                cmdArgs.push('--watch');
                cmdArgs.push(jsName + '.js');
            }

            cmdArgs = ['.', '--scripts-prepend-node-path'].concat(cmdArgs);

            var proc = null;
            
            if (Sys.systemName() == 'Windows') {
                proc = ChildProcess.spawn(
                    Path.join([context.ceramicRunnerPath, 'electron.cmd']),
                    cmdArgs,
                    {
                        cwd: context.ceramicRunnerPath/*,
                        env: {
                            ELECTRON_ENABLE_LOGGING: '1'
                        }*/
                    }
                );
            } else {
                proc = ChildProcess.spawn(
                    Path.join([context.ceramicToolsPath, 'node']),
                    ['node_modules/.bin/' + 'electron'].concat(cmdArgs),
                    {
                        cwd: context.ceramicRunnerPath/*,
                        env: {
                            ELECTRON_ENABLE_LOGGING: '1'
                        }*/
                    }
                );
            }

            var out = StreamSplitter.splitter("\n");
            proc.stdout.pipe(untyped out);
            proc.on('close', function(code:Int) {
                status = code;
            });
            out.encoding = 'utf8';
            out.on('token', function(token) {
                token = formatLineOutput(outTargetPath, token);
                stdoutWrite(token + "\n");
            });
            out.on('done', function() {
                if (done != null) {
                    done();
                    done = null;
                }
            });
            out.on('error', function(err) {
                warning(''+err);
            });

            var err = StreamSplitter.splitter("\n");
            proc.stderr.pipe(untyped err);
            err.encoding = 'utf8';
            err.on('token', function(token) {
                if (electronErrors) {
                    token = formatLineOutput(outTargetPath, token);
                    stderrWrite(token + "\n");
                }
            });
            err.on('error', function(err) {
                warning(''+err);
            });

            if (doHotReload) {
                // JS hot reload server
    
                var argPort = extractArgValue(args, 'hot-reload-port');
                var port = argPort != null ? Std.parseInt(argPort) : 3220;
                if (port < 1024) {
                    fail('Invalid port $argPort');
                }
    
                var server = new HotReloadServer(
                    webProjectPath,
                    project.app.name + '.js',
                    port
                );
    
                var watcher = Chokidar.watch([
                    Path.join([cwd, 'src/**/*.hx']),
                    Path.join([webProjectPath, project.app.name + '.js'])
                ], {
                    ignoreInitial: true,
                    cwd: cwd
                });
    
                var scheduledDelay:js.Node.TimeoutObject = null;
                var building = false;
    
                function doBuild() {

                    if (building) {
                        js.Node.setTimeout(doBuild, 500);
                        return;
                    }
    
                    scheduledDelay = null;
    
                    var buildArgs = ['build', 'web', '--variant', context.variant];
                    if (context.debug)
                        buildArgs.push('--debug');
                    Fiber.fiber(function() {
                        building = true;
                        runTask('luxe build', buildArgs);
                        building = false;
                    }).run();
    
                }
    
                function scheduleBuild() {
    
                    if (scheduledDelay != null)
                        js.Node.clearTimeout(scheduledDelay);
                    
                    scheduledDelay = js.Node.setTimeout(doBuild, 500);
    
                }
    
                watcher.on('add', (path, stats) -> {
                    print('Added: $path');
                    if (path.endsWith('.hx')) {
                        scheduleBuild();
                    }
                });
                watcher.on('change', (path, stats) -> {
                    print('Changed: $path');
                    if (path.endsWith('.hx')) {
                        scheduleBuild();
                    }
                    else if (path.endsWith('.js')) {
                        print('reload server');
                        server.reload();
                    }
                });
            }

        });

    }

}
