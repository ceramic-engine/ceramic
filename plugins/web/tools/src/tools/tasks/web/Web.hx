package tools.tasks.web;

import haxe.Json;
import haxe.io.Path;
import process.Process;
import sys.FileSystem;
import sys.io.File;
import timestamp.Timestamp;
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

        var pluginPath = context.plugins.get('web').path;
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
        var audioFilters = extractArgFlag(args, 'audio-filters');

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
        var audioWorkletsBasePath = Path.join([webProjectPath, 'audio-worklets']);

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
            if (FileSystem.exists('$audioWorkletsBasePath.js')) {
                FileSystem.deleteFile('$audioWorkletsBasePath.js');
            }
            if (FileSystem.exists('$audioWorkletsBasePath.js.map')) {
                FileSystem.deleteFile('$audioWorkletsBasePath.js.map');
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
            if (FileSystem.exists('$audioWorkletsBasePath.min.js')) {
                FileSystem.deleteFile('$audioWorkletsBasePath.min.js');
            }
            if (FileSystem.exists('$audioWorkletsBasePath.min.js.map')) {
                FileSystem.deleteFile('$audioWorkletsBasePath.min.js.map');
            }
        }

        // Save html if it changed
        if (htmlContentChanged) {
            File.saveContent(webProjectFilePath, htmlContent);
        }

        // Stop if not running
        if (!doRun) return;

        // Prevent multiple instances running
        InstanceManager.makeUnique('run ~ ' + context.cwd);

        // Run project through electron/ceramic-runner
        print('Start ceramic runner');
        var webAppFilesPath = Path.join([cwd, 'project/web']);

        var status = 0;

        var cmdArgs = ['--app-files', webAppFilesPath];

        if (context.debug) {
            print('Remote debug enabled (port: 9223)');
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
            proc = new Process(
                Path.join([context.ceramicRunnerPath, 'node_modules\\electron\\dist\\electron.exe']),
                cmdArgs,
                context.ceramicRunnerPath
            );
        }
        else if (Sys.systemName() == 'Mac') {
            proc = new Process(
                Path.join([context.ceramicRunnerPath, 'node_modules/electron/dist/Electron.app/Contents/MacOS/Electron']),
                cmdArgs,
                context.ceramicRunnerPath
            );
        }
        else {
            proc = new Process(
                Path.join([context.ceramicRunnerPath, 'node_modules/electron/dist/electron']),
                cmdArgs.concat(['--no-sandbox']),
                context.ceramicRunnerPath
            );
        }

        if (Sys.systemName() == 'Windows') {
            proc.env.set('CERAMIC_CLI', Path.join([context.ceramicToolsPath, 'ceramic.exe']));
        } else {
            proc.env.set('CERAMIC_CLI', Path.join([context.ceramicToolsPath, 'ceramic']));
        }

        var out = new SplitStream('\n'.code, line -> {
            line = formatLineOutput(outTargetPath, line);
            stdoutWrite(line + "\n");
        });

        var err = new SplitStream('\n'.code, line -> {
            if (electronErrors) {
                line = formatLineOutput(outTargetPath, line);
                stderrWrite(line + "\n");
            }
        });

        proc.read_stdout = data -> {
            out.add(data);
        };

        proc.read_stderr = data -> {
            err.add(data);
        };

        proc.create();

        final time = Timestamp.now();
        final status = proc.tick_until_exit_status(() -> {
            Runner.tick();
            timer.update();
            if (context.shouldExit) {
                proc.kill(false);
                Sys.exit(0);
            }
        });

        if (status != 0 && (Timestamp.now() - time) < 5.0) {
            fail('Failed to start electron: exited with status $status');
        }

    }

}
