package tools.tasks.web;

import haxe.Json;
import haxe.io.Path;
import js.node.ChildProcess;
import js.node.Os;
import npm.Chokidar;
import npm.Fiber;
import npm.StreamSplitter;
import sys.FileSystem;
import sys.io.File;
import tools.Colors;
import tools.Files;
import tools.Helpers.*;
import tools.Project;

using StringTools;

class Web extends tools.Task {

    override public function info(cwd:String):String {

        return "Generate or update Web/HTML5 project to run or debug it";

    }

    override function run(cwd:String, args:Array<String>):Void {

        var project = ensureCeramicProject(cwd, args, App);

        var pluginPath = context.plugins.get('Web').path;
        var tplProjectPath = Path.join([pluginPath, 'tpl/project/web']);

        var webProjectPath = Path.join([cwd, 'project/web']);
        var webProjectFilePath = Path.join([webProjectPath, 'index.html']);

        var doRun = extractArgFlag(args, 'run');
        var doWatch = extractArgFlag(args, 'watch');
        var doMinify = extractArgFlag(args, 'minify');
        var doHotReload = extractArgFlag(args, 'hot-reload');
        var electronErrors = extractArgFlag(args, 'electron-errors');
        var useNativeBridge = extractArgFlag(args, 'native-bridge');
        var didSkipCompilation = extractArgFlag(args, 'did-skip-compilation');
        var screenshotPath = extractArgValue(args, 'screenshot');
        var screenshotDelay = extractArgValue(args, 'screenshot-delay');
        var screenshotThenQuit = extractArgFlag(args, 'screenshot-then-quit');

        // Check that project didn't change name
        var htmlContent = null;
        var htmlContentChanged = false;
        var jsName:String = project.app.name;
        if (FileSystem.exists(webProjectFilePath)) {
            htmlContent = File.getContent(webProjectFilePath);
            if (htmlContent.indexOf('<script type="text/javascript" src="./$jsName.js"></script>') == -1) {
                if (htmlContent.indexOf('<script type="text/javascript" src="./$jsName.min.js"></script>') == -1) {

                    // Resolve previous file name
                    var lines = htmlContent.split('\n');
                    var inCeramicApp = false;
                    var jsTag = '<script type="text/javascript" src="./';
                    var prevJsName = null;
                    var prevJsNameFull = null;
                    for (line in lines) {
                        if (inCeramicApp) {
                            var index = line.indexOf(jsTag);
                            if (index != -1) {
                                var value = line.substr(index + jsTag.length);
                                value = value.substr(0, value.indexOf('"'));
                                prevJsNameFull = value;
                                if (value.endsWith('.min.js')) {
                                    value = value.substr(0, value.length - 7);
                                }
                                else if (value.endsWith('.js')) {
                                    value = value.substr(0, value.length - 3);
                                }
                                if (value != 'sourceMapSupport') {
                                    prevJsName = value;
                                    break;
                                }
                            }
                        }
                        else if (line.indexOf('<div id="ceramic-app">') != -1) {
                            inCeramicApp = true;
                        }
                    }

                    if (prevJsName != null && prevJsName != jsName) {
                        if (FileSystem.exists(Path.join([webProjectPath, prevJsName + '.js']))) {
                            FileSystem.deleteFile(Path.join([webProjectPath, prevJsName + '.js']));
                        }
                        if (FileSystem.exists(Path.join([webProjectPath, prevJsName + '.min.js']))) {
                            FileSystem.deleteFile(Path.join([webProjectPath, prevJsName + '.min.js']));
                        }

                        htmlContent = htmlContent.replace(jsTag + prevJsNameFull + '"', jsTag + jsName + '.js"');
                        htmlContentChanged = true;
                        success('Renamed web project from "$prevJsName" to "$jsName"');
                    }
                }
            }
        }

        // Create web project if needed
        WebProject.createWebProjectIfNeeded(cwd, project);

        // Resolve paths and assets
        var backendName = context.backend != null ? context.backend.name : 'clay';
        var outTargetPath = BuildTargetExtensions.outPathWithName(backendName, 'web', cwd, context.debug, context.variant);
        var jsBasePath = Path.join([webProjectPath, jsName]);

        // Patch index.html if needed
        if (htmlContent == null)
            htmlContent = File.getContent(webProjectFilePath);
        var sourceMapPath = Path.join([webProjectPath, '$jsName.js.map']);
        var sourceMapSupportPath = Path.join([webProjectPath, 'sourceMapSupport.js']);
        var tplSourceMapSupportPath = Path.join([tplProjectPath, 'sourceMapSupport.js']);
        if (FileSystem.exists(sourceMapPath)) {
            if (htmlContent.indexOf('"./sourceMapSupport.js"') == -1) {
                htmlContentChanged = true;
                htmlContent = htmlContent.replace(
                    '<div id="ceramic-app">',
                    '<div id="ceramic-app">
            <script type="text/javascript" src="./sourceMapSupport.js"></script>
            <script type="text/javascript">sourceMapSupport.install();</script>'
                );
            }
            // Copy sourceMapSupport.js if needed
            if (!FileSystem.exists(sourceMapSupportPath)) {
                File.copy(tplSourceMapSupportPath, sourceMapSupportPath);
            }
        }
        else {
            if (htmlContent.indexOf('"./sourceMapSupport.js"') != -1) {
                htmlContentChanged = true;
                var lines = htmlContent.split('\n');
                var newLines = [];
                for (line in lines) {
                    if (line.indexOf('<script type="text/javascript" src="./sourceMapSupport.js"></script>') == -1) {
                        if (line.indexOf('<script type="text/javascript">sourceMapSupport.install();</script>') == -1) {
                            newLines.push(line);
                        }
                    }
                }
                htmlContent = newLines.join('\n');
            }
            // Remove sourceMapSupport.js if needed
            if (FileSystem.exists(sourceMapSupportPath)) {
                FileSystem.deleteFile(sourceMapSupportPath);
            }
        }

        // Minify?
        if (doMinify && !didSkipCompilation) {
            runTask('web minify');
        }

        // Ensure html content points to correct js file
        if (doMinify) {
            if (htmlContent.indexOf('<script type="text/javascript" src="./$jsName.js"></script>') != -1) {
                htmlContentChanged = true;
                htmlContent = htmlContent.replace(
                    '<script type="text/javascript" src="./$jsName.js"></script>',
                    '<script type="text/javascript" src="./$jsName.min.js"></script>'
                );
            }
            // Cleanup unused files
            if (FileSystem.exists('$jsBasePath.js')) {
                FileSystem.deleteFile('$jsBasePath.js');
            }
            if (FileSystem.exists('$jsBasePath.js.map')) {
                FileSystem.deleteFile('$jsBasePath.js.map');
            }
        }
        else {
            if (htmlContent.indexOf('<script type="text/javascript" src="./$jsName.min.js"></script>') != -1) {
                htmlContentChanged = true;
                htmlContent = htmlContent.replace(
                    '<script type="text/javascript" src="./$jsName.min.js"></script>',
                    '<script type="text/javascript" src="./$jsName.js"></script>'
                );
            }
            // Cleanup unused files
            if (FileSystem.exists('$jsBasePath.min.js')) {
                FileSystem.deleteFile('$jsBasePath.min.js');
            }
            if (FileSystem.exists('$jsBasePath.min.js.map')) {
                FileSystem.deleteFile('$jsBasePath.min.js.map');
            }
        }

        // Save html if it changed
        if (htmlContentChanged) {
            File.saveContent(webProjectFilePath, htmlContent);
        }

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

            if (useNativeBridge) {
                cmdArgs.push('--native-bridge');
            }

            if (screenshotPath != null) {
                if (!Path.isAbsolute(screenshotPath)) {
                    screenshotPath = Path.join([cwd, screenshotPath]);
                }
                cmdArgs.push('--screenshot');
                cmdArgs.push(screenshotPath);

                if (screenshotDelay != null) {
                    cmdArgs.push('--screenshot-delay');
                    cmdArgs.push(screenshotDelay);
                }

                if (screenshotThenQuit) {
                    cmdArgs.push('--screenshot-then-quit');
                }
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

            // if (doHotReload) {
            //     // JS hot reload server

            //     var argPort = extractArgValue(args, 'hot-reload-port');
            //     var port = argPort != null ? Std.parseInt(argPort) : 3220;
            //     if (port < 1024) {
            //         fail('Invalid port $argPort');
            //     }

            //     var server = new HotReloadServer(
            //         webProjectPath,
            //         project.app.name + '.js',
            //         port
            //     );

            //     var watcher = Chokidar.watch([
            //         Path.join([cwd, 'src/**/*.hx']),
            //         Path.join([webProjectPath, project.app.name + '.js'])
            //     ], {
            //         ignoreInitial: true,
            //         cwd: cwd
            //     });

            //     var scheduledDelay:Dynamic = null;
            //     var building = false;

            //     function doBuild() {

            //         if (building) {
            //             js.Node.setTimeout(doBuild, 500);
            //             return;
            //         }

            //         scheduledDelay = null;

            //         var buildArgs = ['build', 'web', '--variant', context.variant];
            //         if (context.debug)
            //             buildArgs.push('--debug');
            //         Fiber.fiber(function() {
            //             building = true;
            //             runTask('luxe build', buildArgs);
            //             building = false;
            //         }).run();

            //     }

            //     function scheduleBuild() {

            //         if (scheduledDelay != null)
            //             js.Node.clearTimeout(scheduledDelay);

            //         scheduledDelay = js.Node.setTimeout(doBuild, 500);

            //     }

            //     watcher.on('add', (path, stats) -> {
            //         print('Added: $path');
            //         if (path.endsWith('.hx')) {
            //             scheduleBuild();
            //         }
            //     });
            //     watcher.on('change', (path, stats) -> {
            //         print('Changed: $path');
            //         if (path.endsWith('.hx')) {
            //             scheduleBuild();
            //         }
            //         else if (path.endsWith('.js')) {
            //             print('reload server');
            //             server.reload();
            //         }
            //     });
            // }

        });

    }

}
