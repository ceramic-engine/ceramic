package backend.tools.tasks;

import haxe.Json;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import tools.Equal;
import tools.Files;
import tools.Helpers.*;
import tools.InstanceManager;

using StringTools;

class UnityBuild extends tools.Task {

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

        var hxmlProjectPath = target.outPath('unity', cwd, context.debug, variant);

        // Load project file
        var project = new tools.Project();
        var projectPath = Path.join([cwd, 'ceramic.yml']);
        project.loadAppFile(projectPath);

        // Ensure hxml project exist
        if (!FileSystem.exists(hxmlProjectPath)) {
            fail('Missing hxml/unity project file. Did you setup this target?');
        }

        var action = null;

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
            runHooks(cwd, args, project.app.hooks, 'begin clean');

            // Remove generated assets on this target if cleaning
            //
            var targetAssetsPath = Path.join([hxmlProjectPath, 'assets']);
            if (FileSystem.exists(targetAssetsPath)) {
                print('Remove generated assets.');
                tools.Files.deleteRecursive(targetAssetsPath);
            }
        }
        else if (action == 'build' || action == 'run') {
            runHooks(cwd, args, project.app.hooks, 'begin build');
        }

        // Build
        //
        var cmdArgs = ['build.hxml'];
        var debug = extractArgFlag(args, 'debug');
        if (debug) cmdArgs.push('-debug');

        // Only generate C# files. No DLL compilation
        cmdArgs.push('-D');
        cmdArgs.push('no-compilation');

        // Detect if a haxe compilation server is running
        var haxeServerPort = runningHaxeServerPort();
        if (haxeServerPort != -1) {
            cmdArgs.push('--connect');
            cmdArgs.push('' + haxeServerPort);
            cmdArgs.push('-D');
            cmdArgs.push('haxe_server=$haxeServerPort');
        }

        // Haxe shaders detection
        cmdArgs.push('--macro');
        cmdArgs.push('shade.macros.ShadeMacro.initRegister(' + Json.stringify(hxmlProjectPath) + ')');

        if (haxeServerPort != -1) {
            print('Run haxe compiler (server on port $haxeServerPort)');
        }
        else {
            print('Run haxe compiler');
        }

        var status = 0;

        status = haxeWithChecksAndLogs(cmdArgs, {cwd: hxmlProjectPath});

        if (status != 0) {
            fail('Error when running unity $action.');
        }
        else {
            if (action == 'run' || action == 'build') {
                // Compile Unity shaders from Haxe shaders
                final shadersJsonPath = Path.join([hxmlProjectPath, 'shade', 'info.json']);
                final prevShadersJsonPath = Path.join([hxmlProjectPath, 'shade', 'prev-info.json']);

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

                            // Build shade task arguments for Unity target
                            var unityOutputPath = Path.join([hxmlProjectPath, 'shade', 'unity']);

                            if (!shouldSkipShaderCompilation) {
                                // Collect unique shader files (by hash to avoid duplicates)
                                var uniqueShaders:Map<String, String> = new Map();
                                for (ref in shaderReferences) {
                                    if (!uniqueShaders.exists(ref.hash)) {
                                        uniqueShaders.set(ref.hash, ref.filePath);
                                    }
                                }

                                // Delete existing unity shader folder if any
                                if (FileSystem.exists(unityOutputPath)) {
                                    Files.deleteRecursive(unityOutputPath);
                                }

                                // Build args for shade task
                                var shadeArgs:Array<String> = [];
                                for (filePath in uniqueShaders) {
                                    shadeArgs.push('--in');
                                    shadeArgs.push(filePath);
                                }
                                shadeArgs.push('--target');
                                shadeArgs.push('unity');
                                shadeArgs.push('--out');
                                shadeArgs.push(unityOutputPath);

                                // Run shade task
                                print('Transpile shaders to Unity ShaderLab');
                                runTask('shade', shadeArgs);

                                // Save current info for next comparison
                                File.saveContent(prevShadersJsonPath, File.getContent(shadersJsonPath));
                            }

                            // Copy shaders to Unity project
                            // This must happen even when skipping compilation, as assets may have been cleaned
                            copyGeneratedShadersToUnity(cwd, unityOutputPath, project);
                        }
                    }
                }

                runHooks(cwd, args, project.app.hooks, 'end build');
            }
            else if (action == 'clean') {
                runHooks(cwd, args, project.app.hooks, 'end clean');
            }
        }

        if (action == 'run') {
            runHooks(cwd, args, project.app.hooks, 'begin run');
        }

        // Update unity project
        runTask('unity project', action == 'run' ? ['--run'] : []);

    }

    /**
     * Copies generated Unity ShaderLab files to the Unity project assets folder.
     * @param cwd Current working directory
     * @param sourcePath Path to generated shader files
     * @param project Ceramic project configuration
     */
    function copyGeneratedShadersToUnity(cwd:String, sourcePath:String, project:tools.Project):Void {
        if (!FileSystem.exists(sourcePath)) return;

        // Unity shaders go to same assets folder as other ceramic assets
        var dstAssetsPath = Path.join([cwd, 'project', 'unity', project.app.name, 'Assets', 'Ceramic', 'Resources', 'assets']);

        // Ensure assets directory exists
        if (!FileSystem.exists(dstAssetsPath)) {
            FileSystem.createDirectory(dstAssetsPath);
        }

        // Copy all .shader files
        for (file in FileSystem.readDirectory(sourcePath)) {
            if (file.endsWith('.shader')) {
                File.copy(
                    Path.join([sourcePath, file]),
                    Path.join([dstAssetsPath, file])
                );
            }
        }
    }

}
