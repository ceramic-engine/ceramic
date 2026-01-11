package backend.tools.tasks;

import haxe.DynamicAccess;
import haxe.Json;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import tools.Equal;
import tools.Files;
import tools.Helpers.*;
import tools.InstanceManager;

using StringTools;
using tools.Colors;

class ClayBuild extends tools.Task {

    /// Properties

    var target:tools.BuildTarget;

    var variant:String;

    var config:tools.BuildTarget.BuildConfig;

    /// Lifecycle

    public function new(target:tools.BuildTarget, variant:String, configIndex:Int) {
        super();

        this.target = target;
        this.variant = variant;
        this.config = target.configs[configIndex];

    }

    override function run(cwd:String, args:Array<String>):Void {

        var backendName = 'clay';
        var outTargetPath = target.outPath(backendName, cwd, context.debug, variant);

        // Get project file
        var project = ensureCeramicProject(cwd, args, App);

        // Ensure flow project exist
        if (!FileSystem.exists(outTargetPath)) {
            fail('Missing clay project file. Did you setup this target? (missing path $outTargetPath / ${context.debug})');
        }

        var ceramicPath = context.ceramicToolsPath;

        var outPath = Path.join([cwd, 'out']);
        var action = null;
        var debug = context.debug;
        var simulator = extractArgFlag(args, 'simulator');
        var noSkip = extractArgFlag(args, 'no-skip') || context.defines.exists('ceramic_no_skip');
        var useNativeBridge = extractArgFlag(args, 'native-bridge') || context.defines.exists('ceramic_native_bridge');
        var archs = extractArgValue(args, 'archs');
        var didSkipCompilation = false;

        switch (config) {
            case Build(displayName):
                action = 'build';
            case Run(displayName):
                action = 'run';
            case Clean(displayName):
                action = 'clean';
        }

        if (action == 'run') {
            // Prevent multiple instances running
            InstanceManager.makeUnique('run ~ ' + cwd);
        }

        if (action == 'clean') {
            // Simply remove all generated file if cleaning
            runHooks(cwd, args, project.app.hooks, 'begin clean');
            tools.Files.deleteRecursive(outTargetPath);
            runHooks(cwd, args, project.app.hooks, 'end clean');
        }

        // Save last modified list callback
        var saveLastModifiedListCallback:Void->Void = null;

        // Forbid skip haxe compilation?
        var forbidSkipHaxeCompilation = false;
        var hotReloadFlag = extractArgFlag(args, 'hot-reload');
        var hotReloadPort = extractArgValue(args, 'hot-reload-port');
        if (target.name == 'web' && hotReloadFlag) {
            // If hot reload is enabled on web, yes, never skip
            forbidSkipHaxeCompilation = true;
        }

        // Check if we could skip haxe compilation
        var skipHaxeCompilation = false;
        if (!forbidSkipHaxeCompilation && (action == 'run' || action == 'build')) {
            var lastModifiedListFile = Path.join([outTargetPath, (debug ? 'lastModifiedList-debug.json' : 'lastModifiedList.json')]);
            var lastModifiedListBefore:DynamicAccess<Float> = null;
            var ceramicYmlPath = Path.join([cwd, 'ceramic.yml']);

            var pathsToScan = [Path.join([cwd, 'src'])];
            var projectPaths:Array<String> = context.project.app.paths;
            for (aPath in projectPaths) {
                if (Path.isAbsolute(aPath) && pathsToScan.indexOf(aPath) == -1) {
                    pathsToScan.push(aPath);
                } else {
                    aPath = Path.join([cwd, aPath]);
                    if (pathsToScan.indexOf(aPath) == -1) {
                        pathsToScan.push(aPath);
                    }
                }
            }
            var lastModifiedListAfter:DynamicAccess<Float> = {};
            for (toScan in pathsToScan) {
                Files.getDirectoryLastModifiedList(toScan, '.hx', lastModifiedListAfter);
            }
            lastModifiedListAfter.set(ceramicYmlPath, Files.getLastModified(ceramicYmlPath));

            // Read previous file
            if (FileSystem.exists(lastModifiedListFile)) {
                lastModifiedListBefore = Json.parse(File.getContent(lastModifiedListFile));
            }

            if (!noSkip && lastModifiedListBefore != null) {
                if (!Files.hasDirectoryChanged(lastModifiedListBefore, lastModifiedListAfter)) {
                    skipHaxeCompilation = true;
                }
            }

            if (!skipHaxeCompilation) {
                saveLastModifiedListCallback = function() {
                    // Save new last modified list
                    File.saveContent(lastModifiedListFile, Json.stringify(lastModifiedListAfter));
                };
            } else {
                print('Skip haxe compilation');
                didSkipCompilation = true;
            }
        }

        // Build haxe
        var status = 0;
        if (!skipHaxeCompilation && (action == 'build' || action == 'run')) {

            runHooks(cwd, args, project.app.hooks, 'begin build');

            // General target build with haxe
            //
            var cmdArgs = ['project.hxml'];

            if (debug) {
                cmdArgs.push('-debug');
            }

            // Detect if a haxe compilation server is running
            var haxeServerPort = runningHaxeServerPort();
            if (haxeServerPort != -1) {
                cmdArgs.push('--connect');
                cmdArgs.push('' + haxeServerPort);
                cmdArgs.push('-D');
                cmdArgs.push('haxe_server=$haxeServerPort');
            }

            // Disable c++ compilation from haxe compiler when targetting these platforms,
            // because we will do it with hxcpp directly
            if (target.name == 'ios' || target.name == 'android' || target.name == 'mac' || target.name == 'windows' || target.name == 'linux') {
                cmdArgs.push('-D');
                cmdArgs.push('no-compilation');
            }

            if (haxeServerPort != -1) {
                print('Run haxe compiler (server on port $haxeServerPort)');
            }
            else {
                print('Run haxe compiler');
            }

            // Hot reload info
            if (target.name == 'web') {
                if (hotReloadFlag) {
                    cmdArgs.push('-D');
                    cmdArgs.push('ceramic_hotreload');
                }
                if (hotReloadPort != null) {
                    cmdArgs.push('-D');
                    cmdArgs.push('ceramic_hotreload_port=' + hotReloadPort);
                }
            }

            // Haxe shaders detection
            cmdArgs.push('--macro');
            cmdArgs.push('shade.macros.ShadeMacro.initRegister(' + Json.stringify(outTargetPath) + ')');

            // Audio filters
            cmdArgs.push('-D');
            cmdArgs.push('ceramic_audio_filters_collect_info');
            cmdArgs.push('--macro');
            cmdArgs.push('ceramic.macros.AudioFiltersMacro.init()');

            // Read previous audio-filters.json
            var prevAudioFilters:Dynamic = null;
            final audioFiltersJsonPath = Path.join([outTargetPath, 'audio-filters', 'info.json']);
            if (FileSystem.exists(audioFiltersJsonPath)) {
                prevAudioFilters = Json.parse(File.getContent(audioFiltersJsonPath));
            }

            status = haxeWithChecksAndLogs(cmdArgs, {cwd: outTargetPath});

            if (status == 0) {
                // Read audio-filters.json
                var audioFilters:Dynamic = null;
                if (FileSystem.exists(audioFiltersJsonPath)) {
                    audioFilters = Json.parse(File.getContent(audioFiltersJsonPath));
                }

                final workletsJsFilePath = Path.join([cwd, 'project', 'web', 'audio-worklets.js']);
                final workletsJsMinifiedFilePath = Path.join([cwd, 'project', 'web', 'audio-worklets.min.js']);

                final workletsCppPath = Path.join([outTargetPath, 'audio-filters', 'cpp']);

                if (audioFilters != null) {
                    // Compare previous and new audio filters json hashes
                    // (and skip if identical)
                    var workletIncludes = [];
                    var shouldSkipStandaloneFilters = true;
                    if (prevAudioFilters == null) {
                        shouldSkipStandaloneFilters = false;
                    }
                    else if (!Equal.equal(prevAudioFilters, audioFilters)) {
                        shouldSkipStandaloneFilters = false;
                    }

                    shouldSkipStandaloneFilters = false;

                    // Prepare audio filters separate worklets project
                    if (!shouldSkipStandaloneFilters) {
                        var hasStandaloneFiltersToProcess = false;
                        final filterReferences:Array<{
                            pack: Array<String>,
                            name: String,
                            filePath: String,
                            hash: String,
                            min: Int,
                            max: Int
                        }> = audioFilters.filters;
                        final workletReferences:Array<{
                            pack: Array<String>,
                            name: String,
                            filePath: String,
                            hash: String,
                            min: Int,
                            max: Int
                        }> = audioFilters.worklets;

                        final copiedFiles:Map<String,Bool> = new Map();
                        final filtersHaxePath = Path.join([outTargetPath, 'audio-filters', 'haxe']);
                        if (FileSystem.exists(filtersHaxePath)) {
                            Files.deleteRecursive(filtersHaxePath);
                        }
                        FileSystem.createDirectory(filtersHaxePath);
                        for (ref in workletReferences) {
                            if (!hasStandaloneFiltersToProcess) {
                                hasStandaloneFiltersToProcess = true;
                                if (target.name == 'web') {
                                    print('Compile web audio worklets');
                                }
                                else {
                                    print('Transpile cpp audio worklets');
                                }
                            }

                            var pack = [].concat(ref.pack ?? []);
                            while (pack.length > 0 && pack[pack.length-1].charAt(0) != pack[pack.length-1].charAt(0).toLowerCase()) {
                                pack.pop();
                            }
                            final destPath = Path.join([filtersHaxePath].concat(pack).concat([ref.name + '.hx']));

                            var toInclude = ref.name;
                            if (pack.length > 0) {
                                toInclude = pack.join('.') + '.' + toInclude;
                            }
                            workletIncludes.push(toInclude);

                            if (!FileSystem.exists(Path.directory(destPath))) {
                                FileSystem.createDirectory(Path.directory(destPath));
                            }

                            var packDecl = '';
                            if (pack.length > 0) {
                                packDecl = 'package ' + pack.join('.') + ';' + #if windows '\r\n' #else '\n' #end;
                            }

                            File.saveContent(
                                destPath,
                                '$packDecl
import ceramic.AudioFilterWorklet;
import ceramic.AudioFilterBuffer;

${File.getContent(ref.filePath).substring(ref.min, ref.max)}
                                '
                            );
                        }
                        if (hasStandaloneFiltersToProcess) {
                            if (!FileSystem.exists(Path.join([filtersHaxePath, 'ceramic']))) {
                                FileSystem.createDirectory(Path.join([filtersHaxePath, 'ceramic']));
                            }
                            if (!FileSystem.exists(Path.join([filtersHaxePath, 'ceramic', 'macros']))) {
                                FileSystem.createDirectory(Path.join([filtersHaxePath, 'ceramic', 'macros']));
                            }
                            File.copy(
                                Path.join([context.ceramicRuntimePath, 'src/ceramic/AudioFilters.hx']),
                                Path.join([filtersHaxePath, 'ceramic/AudioFilters.hx'])
                            );
                            File.copy(
                                Path.join([context.ceramicRuntimePath, 'src/ceramic/AudioFilterWorklet.hx']),
                                Path.join([filtersHaxePath, 'ceramic/AudioFilterWorklet.hx'])
                            );
                            File.copy(
                                Path.join([context.ceramicRuntimePath, 'src/ceramic/AudioFilterBuffer.hx']),
                                Path.join([filtersHaxePath, 'ceramic/AudioFilterBuffer.hx'])
                            );
                            File.copy(
                                Path.join([context.ceramicRuntimePath, 'src/ceramic/macros/AudioFiltersMacro.hx']),
                                Path.join([filtersHaxePath, 'ceramic/macros/AudioFiltersMacro.hx'])
                            );

                            var workletIncludesStr = '';
                            var workletResolveClassCases = '';
                            for (toInclude in workletIncludes) {
                                workletIncludesStr += 'import ' + toInclude + ';' + #if windows '\r\n' #else '\n' #end;
                                workletResolveClassCases += '        case "' + toInclude + '": ' + toInclude + ';' + #if windows '\r\n' #else '\n' #end;
                            }

                            File.saveContent(
                                Path.join([filtersHaxePath, 'Main.hx']),
                                '
$workletIncludesStr
function main() {
    backend.Audio.init(resolveWorkletClass);
}

function resolveWorkletClass(className:String):Class<ceramic.AudioFilterWorklet> {
    return switch className {
$workletResolveClassCases
        case _: ceramic.AudioFilterWorklet;
    }
}
                                '
                            );

                            if (target.name == 'web') {

                                final buildWorkletsStatus = haxeWithChecksAndLogs([
                                    '--class-path', '.',
                                    '--class-path', Path.join([context.plugins.get('clay').path, 'audio/src-web']),
                                    '--main', 'Main',
                                    '--js', workletsJsFilePath
                                ], {cwd: filtersHaxePath});

                                if (buildWorkletsStatus != 0) {
                                    // Worklet buils failed
                                    error('Error when building web audio worklets. (status = $buildWorkletsStatus)');
                                    Sys.exit(buildWorkletsStatus);
                                }

                            }
                            else {

                                var ceramicRoot = context.ceramicRootPath;
                                var reflaxePath = Path.join([ceramicRoot, 'git', 'reflaxe', 'src']);
                                var reflaxeExtraParams = Path.join([ceramicRoot, 'git', 'reflaxe', 'extraParams.hxml']);
                                var reflaxeCppPath = Path.join([ceramicRoot, 'git', 'reflaxe.CPP', 'src']);
                                var reflaxeCppExtraParams = Path.join([ceramicRoot, 'git', 'reflaxe.CPP', 'extraParams.hxml']);
                                final transpileWorkletsStatus = haxeWithChecksAndLogs([
                                    '--class-path', '.',
                                    '--class-path', Path.join([context.plugins.get('clay').path, 'audio/src-cpp']),
                                    '--main', 'Main',
                                    '--class-path', reflaxePath,
                                    reflaxeExtraParams,
                                    '-D', 'reflaxe',
                                    '--class-path', reflaxeCppPath,
                                    reflaxeCppExtraParams,
                                    '-D', 'reflaxe.CPP',
                                    '-D', 'cpp-output=' + workletsCppPath
                                ], {cwd: filtersHaxePath});

                                if (transpileWorkletsStatus != 0) {
                                    // Worklet buils failed
                                    error('Error when transpiling cpp audio worklets. (status = $transpileWorkletsStatus)');
                                    Sys.exit(transpileWorkletsStatus);
                                }

                            }
                        }
                    }
                }
                else {
                    if (FileSystem.exists(workletsJsFilePath)) {
                        FileSystem.deleteFile(workletsJsFilePath);
                    }
                    if (FileSystem.exists(workletsJsMinifiedFilePath)) {
                        FileSystem.deleteFile(workletsJsMinifiedFilePath);
                    }
                }

                // Compile GLSL shaders from Haxe shaders
                final shadersJsonPath = Path.join([outTargetPath, 'shade', 'info.json']);
                final prevShadersJsonPath = Path.join([outTargetPath, 'shade', 'prev-info.json']);

                if (FileSystem.exists(shadersJsonPath)) {
                    var shaders:Dynamic = Json.parse(File.getContent(shadersJsonPath));

                    // Read previous shade/info.json for comparison
                    var prevShaders:Dynamic = null;
                    if (FileSystem.exists(prevShadersJsonPath)) {
                        prevShaders = Json.parse(File.getContent(prevShadersJsonPath));
                    }

                    if (shaders != null && shaders.shaders != null) {
                        final shaderReferences:Array<{
                            pack:Array<String>,
                            name:String,
                            filePath:String,
                            hash:String
                        }> = shaders.shaders;

                        if (shaderReferences.length > 0) {
                            // Check if shaders changed (skip if identical)
                            var shouldSkipShaderCompilation = false;
                            if (prevShaders != null && Equal.equal(prevShaders, shaders, true)) {
                                shouldSkipShaderCompilation = true;
                            }

                            var glslOutputPath = Path.join([outTargetPath, 'shade', 'glsl']);

                            if (!shouldSkipShaderCompilation) {
                                // Collect unique shader files (by hash to avoid duplicates)
                                var uniqueShaders:Map<String, String> = new Map();
                                for (ref in shaderReferences) {
                                    if (!uniqueShaders.exists(ref.hash)) {
                                        uniqueShaders.set(ref.hash, ref.filePath);
                                    }
                                }

                                // Delete existing glsl folder if any
                                if (FileSystem.exists(glslOutputPath)) {
                                    Files.deleteRecursive(glslOutputPath);
                                }

                                // Build args for shade task
                                var shadeArgs:Array<String> = [];
                                for (filePath in uniqueShaders) {
                                    shadeArgs.push('--in');
                                    shadeArgs.push(filePath);
                                }
                                shadeArgs.push('--target');
                                shadeArgs.push('glsl');
                                shadeArgs.push('--out');
                                shadeArgs.push(glslOutputPath);

                                // Run shade task
                                print('Transpile shaders to GLSL');
                                runTask('shade', shadeArgs);

                                // Save current info for next comparison
                                File.saveContent(prevShadersJsonPath, File.getContent(shadersJsonPath));
                            }

                            // Copy shaders to platform assets (directly in assets folder, no subfolder)
                            // This must happen even when skipping compilation, as assets may have been cleaned
                            if (FileSystem.exists(glslOutputPath)) {
                                var dstAssetsPath:String = switch (target.name) {
                                    case 'mac':
                                        Path.join([cwd, 'project', 'mac', project.app.name + '.app', 'Contents', 'Resources', 'assets']);
                                    case 'ios':
                                        Path.join([cwd, 'project', 'ios', 'project', 'assets', 'assets']);
                                    case 'android':
                                        Path.join([cwd, 'project', 'android', 'app', 'src', 'main', 'assets', 'assets']);
                                    case 'windows' | 'linux' | 'web':
                                        Path.join([cwd, 'project', target.name, 'assets']);
                                    default:
                                        null;
                                };

                                if (dstAssetsPath != null) {
                                    // Ensure assets directory exists
                                    if (!FileSystem.exists(dstAssetsPath)) {
                                        FileSystem.createDirectory(dstAssetsPath);
                                    }

                                    // Copy all generated shader files directly to assets folder
                                    for (file in FileSystem.readDirectory(glslOutputPath)) {
                                        Files.copyIfNeeded(
                                            Path.join([glslOutputPath, file]),
                                            Path.join([dstAssetsPath, file])
                                        );
                                    }
                                }
                            }
                        }
                    }
                }

                // We can now save last modified list, as build seems ok
                if (saveLastModifiedListCallback != null) {
                    saveLastModifiedListCallback();
                    saveLastModifiedListCallback = null;
                }
            }
            else {
                // Build failed
                error('Error when running clay $action with target ${target.name}. (status = $status)');
                Sys.exit(status);
            }

            // Strip line markers on a critical file (Renderer.cpp) when targetting cpp
            if (!debug && !context.defines.exists('ceramic_debug_draw') && !context.defines.exists('ceramic_no_strip_markers')) {
                if (target.name == 'ios' || target.name == 'android' || target.name == 'mac' || target.name == 'windows' || target.name == 'linux') {
                    var criticalFilePath = Path.join([outTargetPath, 'cpp', 'src', 'ceramic', 'Renderer.cpp']);
                    if (FileSystem.exists(criticalFilePath)) {
                        var cppContent = File.getContent(criticalFilePath);
                        var newCppContent = stripHxcppLineMarkers(cppContent);
                        if (cppContent != newCppContent) {
                            File.saveContent(criticalFilePath, newCppContent);
                        }
                    }
                }
            }

            runHooks(cwd, args, project.app.hooks, 'end build');
        }

        // Compile c++ for host platform on default architecture (expecting 64bit)
        if (target.name == 'windows') {
            // Could move that to some plugin later, maybe
            var hxcppArgs = ['run', 'hxcpp', 'Build.xml'];
            if (context.defines.exists('HXCPP_M32')) {
                hxcppArgs.push('-DHXCPP_M32');
            }
            else {
                hxcppArgs.push('-DHXCPP_M64');
            }
            if (debug) {
                hxcppArgs.push('-Ddebug');
            }
            if (!context.colors) {
                hxcppArgs.push('-DHXCPP_NO_COLOR');
            }
            hxcppArgs.push('-DHXCPP_CPP17');
            print('Compile C++');

            if (haxelib(hxcppArgs, { cwd: Path.join([outTargetPath, 'cpp']) }).status != 0) {
                fail('Failed to compile C++');
            }
        }

        // Compile c++ for iOS on requested architectures
        if (target.name == 'ios') {
            if (archs != null && archs.trim() != '') {
                var compileArgs = ['--archs', archs.trim()];
                if (simulator)
                    compileArgs.push('--simulator');
                runTask('ios compile', compileArgs);
            }
        }

        // Compile c++ for Android on requested architectures
        if (target.name == 'android') {
            if (archs != null && archs.trim() != '') {
                runTask('android compile', ['--archs', archs.trim()]);
            }
        }

        // Compile c++ for Mac on requested architectures
        if (target.name == 'mac') {
            if (archs == null || archs.trim() == '') {
                #if mac_arm64
                archs = 'arm64';
                #end
                #if mac_x86_64
                archs = 'x86_64';
                #end
            }
            runTask('mac compile', ['--archs', archs.trim()]);
        }

        // Compile c++ for Linux on requested architectures
        if (target.name == 'linux') {
            if (archs == null || archs.trim() == '') {
                #if linux_arm64
                archs = 'arm64';
                #end
                #if linux_x86_64
                archs = 'x86_64';
                #end
            }
            runTask('linux compile', ['--archs', archs.trim()]);
        }

        // Hook
        if (action == 'run') {
            runHooks(cwd, args, project.app.hooks, 'begin run');
        }

        var projectDir = Path.join([cwd, 'project', target.name]);

        // Mac
        if ((action == 'run' || action == 'build') && target.name == 'mac') {
            runTask('mac app', action == 'run' ? ['--run'] : []);
            if (action == 'run') {
                runHooks(cwd, args, project.app.hooks, 'end run');
            }
        }
        // Linux
        else if ((action == 'run' || action == 'build') && target.name == 'linux') {
            runTask('linux app', action == 'run' ? ['--run'] : []);
            if (action == 'run') {
                runHooks(cwd, args, project.app.hooks, 'end run');
            }
        }
        // Windows
        else if ((action == 'run' || action == 'build') && target.name == 'windows') {
            runTask('windows app', action == 'run' ? ['--run'] : []);
            if (action == 'run') {
                runHooks(cwd, args, project.app.hooks, 'end run');
            }
        }
        // iOS
        else if (action == 'run' && target.name == 'ios') {
            runTask('ios xcode', ['--open']);
            runHooks(cwd, args, project.app.hooks, 'end run');
        }
        // Android
        else if (action == 'run' && target.name == 'android') {
            final runApk = extractArgFlag(args, 'run-apk');
            final buildApk = extractArgFlag(args, 'build-apk');
            final openProject = extractArgFlag(args, 'open-project');
            var androidStudioArgs = [];
            if (runApk) androidStudioArgs.push('--run-apk');
            if (buildApk) androidStudioArgs.push('--build-apk');
            if (openProject) androidStudioArgs.push('--open-project');
            runTask('android studio', androidStudioArgs);
            runHooks(cwd, args, project.app.hooks, 'end run');
        }
        // Web
        else if ((action == 'run' || action == 'build') && target.name == 'web') {
            // Needs Web plugin
            var task = context.task('web project');
            if (task == null) {
                warning('Cannot run Web project because `ceramic web project` command doesn\'t exist.');
                warning('Did you enable ceramic\'s web plugin?');
            } else {

                // Run with electron runner
                var electronErrors = extractArgFlag(args, 'electron-errors');
                var taskArgs = ['web', 'project', '--variant', context.variant, '--audio-filters'];
                if (action == 'run')
                    taskArgs.push('--run');
                if (debug)
                    taskArgs.push('--debug');
                if (electronErrors) {
                    taskArgs.push('--electron-errors');
                }
                if (didSkipCompilation) {
                    taskArgs.push('--did-skip-compilation');
                }
                if (context.defines.exists('ceramic_web_minify')) {
                    taskArgs.push('--minify');
                }
                if (hotReloadFlag) {
                    taskArgs.push('--hot-reload');
                }
                if (hotReloadPort != null) {
                    taskArgs.push('--hot-reload-port');
                    taskArgs.push(hotReloadPort);
                }
                if (useNativeBridge) {
                    taskArgs.push('--native-bridge');
                }
                // if (watch) taskArgs.push('--watch');
                task.run(cwd, taskArgs);
            }

            if (action == 'run')
                runHooks(cwd, args, project.app.hooks, 'end run');
        } else if (action == 'run') {
            runHooks(cwd, args, project.app.hooks, 'end run');
        }
    }

} // Setup
