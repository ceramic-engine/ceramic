package tools;

import haxe.Json;
import haxe.io.Path;
import process.Process;
import sys.FileSystem;
import sys.io.File;
import tools.Project;
import tools.macros.ToolsMacros;

using StringTools;
using tools.Colors;

class Helpers {

    public static var context:Context;

    public static var timer:Timer = new Timer();

    public static function extractDefines(cwd:String, args:Array<String>):Void {

        // Add backend-specific defines
        var target = null;
        if (context.backend != null) {

            var availableTargets = context.backend.getBuildTargets();
            var targetName = getTargetName(args, availableTargets);

            if (targetName != null) {
                // Find target from name
                //
                for (aTarget in availableTargets) {

                    if (aTarget.name == targetName) {
                        target = aTarget;
                        break;
                    }

                }
            }

            context.defines.set('backend', context.backend.name.toLowerCase().replace(' ', '_'));
            context.defines.set(context.backend.name.toLowerCase().replace(' ', '_'), 'backend');
        }

        // Add generic defines
        context.defines.set('ceramic', context.ceramicVersion);
        context.defines.set('assets_path', Json.stringify(Path.join([cwd, 'assets'])));
        context.defines.set('ceramic_assets_path', Json.stringify(Path.join([context.ceramicToolsPath, 'assets'])));
        context.defines.set('ceramic_root_path', Json.stringify(context.ceramicRootPath));
        context.defines.set('HXCPP_STACK_LINE', '');
        context.defines.set('HXCPP_STACK_TRACE', '');

        if (context.variant != null) {
            context.defines.set('variant', context.variant);
            if (!context.defines.exists(context.variant)) {
                context.defines.set(context.variant, 'variant');
            }
        }

        // Required for crash dumps
        context.defines.set('HXCPP_CHECK_POINTER', '');
        context.defines.set('safeMode', '');

        // To get absolute path in haxe log output
        // Then, we process it to make it more readable, with colors etc...
        if (context.debug) {
            context.defines.set('absolute-path', '');
        }

        // Add target defines
        if (target != null && context.backend != null) {
            var extraDefines = context.backend.getTargetDefines(cwd, args, target, context.variant);
            for (key in extraDefines.keys()) {
                if (!context.defines.exists(key)) {
                    context.defines.set(key, extraDefines.get(key));
                }
            }
        }

        // Add extra assets paths
        var project = loadProject(cwd, args);
        var extraAssetsPaths = [];
        if (project != null && project.app != null) {
            var extraAssets:Array<String> = project.app.assets;
            if (extraAssets != null) {
                for (assetPath in extraAssets) {
                    if (extraAssetsPaths.indexOf(assetPath) == -1) {
                        if (!Path.isAbsolute(assetPath)) {
                            assetPath = Path.join([cwd, assetPath]);
                        }
                        extraAssetsPaths.push(assetPath);
                    }
                }
            }
        }
        context.defines.set('ceramic_extra_assets_paths', Json.stringify(Json.stringify(extraAssetsPaths)));

    }

    public static function extractHaxePaths(cwd:String, args:Array<String>):Void {

        // Add backend-specific paths
        var target = null;
        var rawHxml = null;
        if (context.backend != null) {

            var availableTargets = context.backend.getBuildTargets();
            var targetName = getTargetName(args, availableTargets);

            if (targetName != null) {
                // Find target from name
                //
                for (aTarget in availableTargets) {

                    if (aTarget.name == targetName) {
                        target = aTarget;
                        break;
                    }

                }
            }

            if (target != null) {
                rawHxml = context.backend.getHxml(cwd, args, target, context.variant);
            }
        }

        if (rawHxml != null) {
            // Use HXML to know which haxe paths we link to
            var hxmlOriginalCwd = context.backend.getHxmlCwd(cwd, args, target, context.variant);

            // Let plugins extend HXML
            for (plugin in context.plugins) {
                if (plugin.instance?.extendCompletionHxml != null) {

                    var prevBackend = context.backend;
                    context.backend = plugin.instance.backend;

                    plugin.instance.extendCompletionHxml(rawHxml);

                    context.backend = prevBackend;
                }
            }

            // Walk through HXML data
            var hxmlData = tools.Hxml.parse(rawHxml);
            var haxePaths = [];

            var i = 0;
            while (i < hxmlData.length - 1) {
                var arg = hxmlData[i];
                if (arg == '-cp' || arg == '--class-path') {
                    i++;
                    var path = hxmlData[i];
                    if (!Path.isAbsolute(path)) {
                        path = Path.normalize(Path.join([hxmlOriginalCwd, path]));
                        if (FileSystem.exists(path) && FileSystem.isDirectory(path)) {
                            haxePaths.push(path);
                        }
                    }
                }
                else if (arg == '-lib' || arg == '--library') {
                    i++;
                    var rawLibName = hxmlData[i];
                    var colonIndex = rawLibName.indexOf(':');
                    var libName = rawLibName;
                    var libVersion = null;
                    if (colonIndex != -1) {
                        libName = rawLibName.substring(0, colonIndex);
                        libVersion = rawLibName.substring(colonIndex + 1);
                    }
                    var haxeLibrary = null;
                    for (item in context.haxeLibraries) {
                        if (item.name == libName) {
                            haxeLibrary = item;
                            break;
                        }
                    }
                    if (haxeLibrary != null) {
                        for (path in resolveLibraryHaxePaths(cwd, haxeLibrary, libVersion)) {
                            haxePaths.push(path);
                        }
                    }
                }

                i++;
            }

            context.haxePaths = haxePaths;
        }
        else {
            context.haxePaths = [];
        }

    }

    public static function setVariant(variant:String) {

        var prevVariant = context.variant;

        if (prevVariant != variant) {
            if (context.defines.get(prevVariant) == 'variant') {
                context.defines.remove(prevVariant);
            }
        }

        context.variant = variant;
        context.defines.set('variant', context.variant);
        if (!context.defines.exists(context.variant)) {
            context.defines.set(context.variant, 'variant');
        }

    }

    /**
     * Load plugins from a directory (handles both regular directories and .plugin files)
     * @param pluginsPath Directory to scan for plugins
     * @param source Source identifier for logging ('global' or 'project')
     */
    static function loadPluginsFromDirectory(pluginsPath:String, source:String):Void {

        for (entry in FileSystem.readDirectory(pluginsPath)) {
            final entryPath = Path.join([pluginsPath, entry]);

            if (FileSystem.isDirectory(entryPath)) {
                // Regular plugin directory
                var pluginId = Path.withoutDirectory(entryPath);

                // Skip if already loaded (precedence)
                if (!context.plugins.exists(pluginId)) {
                    loadCustomPlugin(entryPath, null);
                }
            }
            else if (entry.endsWith('.plugin')) {
                // Plugin path reference file
                var pluginId = entry.substring(0, entry.length - '.plugin'.length);

                // Skip if already loaded (precedence)
                if (!context.plugins.exists(pluginId)) {
                    var referencedPath = loadPluginReference(entryPath, pluginId, source);
                    if (referencedPath != null) {
                        loadCustomPlugin(referencedPath, pluginId);
                    }
                }
            }
        }

    }

    /**
     * Loads a plugin path from a .plugin reference file
     * @param referenceFilePath Path to the .plugin file
     * @param pluginId Plugin identifier (for error messages)
     * @param source Source type: 'global' or 'project' (for path resolution)
     * @return Resolved absolute path, or null if invalid
     */
    public static function loadPluginReference(referenceFilePath:String, pluginId:String, source:String):String {

        try {
            // Read the reference file (single line containing path)
            var content = File.getContent(referenceFilePath).trim();

            if (content == '') {
                warning('Plugin reference file is empty: $referenceFilePath');
                return null;
            }

            // Resolve path
            var pluginPath:String;
            if (Path.isAbsolute(content)) {
                // Absolute paths used as-is
                pluginPath = Path.normalize(content);
            } else {
                // Relative paths resolved based on source
                if (source == 'global') {
                    // Global plugins: resolve relative to home directory
                    var homeDir = homedir();
                    pluginPath = Path.normalize(Path.join([homeDir, content]));
                } else {
                    // Project plugins: resolve relative to project root
                    pluginPath = Path.normalize(Path.join([context.cwd, content]));
                }
            }

            // Validate path exists
            if (!FileSystem.exists(pluginPath)) {
                warning('Plugin reference path does not exist: $pluginPath (from $referenceFilePath)');
                return null;
            }

            if (!FileSystem.isDirectory(pluginPath)) {
                warning('Plugin reference path is not a directory: $pluginPath (from $referenceFilePath)');
                return null;
            }

            // Validate ceramic.yml exists
            var ceramicYmlPath = Path.join([pluginPath, 'ceramic.yml']);
            if (!FileSystem.exists(ceramicYmlPath)) {
                warning('Plugin directory missing ceramic.yml: $pluginPath (for plugin: $pluginId)');
                return null;
            }

            return pluginPath;
        }
        catch (e:Dynamic) {
            warning('Error reading plugin reference file $referenceFilePath: $e');
            return null;
        }

    }

    public static function computePlugins() {

        context.plugins = new Map();

        // 1. Load global user plugins from ~/.ceramic/plugins/
        var homeDir = homedir();
        if (homeDir != null) {
            final globalPluginsPath = Path.normalize(Path.join([homeDir, '.ceramic', 'plugins']));
            if (FileSystem.exists(globalPluginsPath) && FileSystem.isDirectory(globalPluginsPath)) {
                loadPluginsFromDirectory(globalPluginsPath, 'global');
            }
        }

        // 2. Load project-specific plugins from {project}/plugins/
        final projectPluginsPath = Path.normalize(Path.join([context.cwd, 'plugins']));

        // Make sure cwd isn't ceramic path itself!
        if (Path.normalize(Path.join([context.ceramicRootPath, 'plugins'])) != projectPluginsPath) {
            if (FileSystem.exists(projectPluginsPath) && FileSystem.isDirectory(projectPluginsPath)) {
                loadPluginsFromDirectory(projectPluginsPath, 'project');
            }
        }

        // 3. Load default/built-in plugins (compile-time macro data)
        final defaultPlugins:Array<Dynamic> = ToolsMacros.pluginDefaults();
        final pluginConstructs:Dynamic = ToolsMacros.pluginConstructs();
        final pluginsPath = Path.join([context.ceramicRootPath, 'plugins']);

        for (info in defaultPlugins) {

            final instance = Reflect.field(pluginConstructs, info.plugin.id);

            if (!context.plugins.exists(info.plugin.id)) {
                context.plugins.set(info.plugin.id, {
                    path: Path.join([pluginsPath, info.plugin.id]),
                    id: info.plugin.id,
                    name: info.plugin.name,
                    runtime: info.plugin.runtime,
                    instance: instance
                });
            }

        }

    }

    public static function loadCustomPlugin(pluginPath:String, ?overrideId:String) {

        #if windows
        final ceramicBinPath = Path.join([context.ceramicToolsPath, 'ceramic.exe']);
        #else
        final ceramicBinPath = Path.join([context.ceramicToolsPath, 'ceramic']);
        #end

        final pluginYmlPath = Path.join([pluginPath, 'ceramic.yml']);
        final pluginBaseName = overrideId != null ? overrideId : Path.withoutDirectory(pluginPath);
        if (FileSystem.exists(pluginYmlPath) && !FileSystem.isDirectory(pluginYmlPath)) {
            final info:Dynamic = Yaml.parse(File.getContent(pluginYmlPath));
            info.plugin.id = pluginBaseName;

            final pluginToolsSrcPath = Path.join([pluginPath, 'tools/src']);
            #if debug_plugins
            print('* ' + pluginBaseName + ' (' + info.plugin.name + ')');
            #end
            if (FileSystem.exists(pluginToolsSrcPath) && FileSystem.isDirectory(pluginToolsSrcPath)) {
                if (info.plugin.tools != null) {
                    var pluginCppiaPath = Path.join([pluginPath, 'plugin.cppia']);
                    if (!Files.haveSameLastModified(ceramicBinPath, pluginCppiaPath)) {
                        var pluginHaxelibPath = Path.join([pluginPath, '.haxelib']);
                        Files.deleteRecursive(pluginHaxelibPath);
                        FileSystem.createDirectory(pluginHaxelibPath);

                        FileSystem.createDirectory(Path.join([pluginHaxelibPath, 'generate']));
                        File.saveContent(
                            Path.join([pluginHaxelibPath, 'generate', '.dev']),
                            Path.join([context.ceramicGitDepsPath, 'generate'])
                        );

                        FileSystem.createDirectory(Path.join([pluginHaxelibPath, 'yaml']));
                        File.saveContent(
                            Path.join([pluginHaxelibPath, 'yaml', '.dev']),
                            Path.join([context.ceramicGitDepsPath, 'yaml', 'src'])
                        );

                        FileSystem.createDirectory(Path.join([pluginHaxelibPath, 'linc_stb']));
                        File.saveContent(
                            Path.join([pluginHaxelibPath, 'linc_stb', '.dev']),
                            Path.join([context.ceramicGitDepsPath, 'linc_stb'])
                        );

                        FileSystem.createDirectory(Path.join([pluginHaxelibPath, 'linc_process']));
                        File.saveContent(
                            Path.join([pluginHaxelibPath, 'linc_process', '.dev']),
                            Path.join([context.ceramicGitDepsPath, 'linc_process'])
                        );

                        FileSystem.createDirectory(Path.join([pluginHaxelibPath, 'linc_timestamp']));
                        File.saveContent(
                            Path.join([pluginHaxelibPath, 'linc_timestamp', '.dev']),
                            Path.join([context.ceramicGitDepsPath, 'linc_timestamp'])
                        );

                        haxe([
                            '-D', 'dll_import=' + Path.join([context.ceramicToolsPath, 'ceramic.info']),
                            '-dce', 'no',
                            '--cpp', 'plugin.cppia',
                            '-cp', Path.join([context.ceramicToolsPath, 'src']),
                            '-cp', 'tools/src',
                            '-D', 'cppia',
                            '--library', 'generate',
                            '--library', 'yaml',
                            '--library', 'linc_stb',
                            '--library', 'linc_process',
                            '--library', 'linc_timestamp',
                            '-D', 'HXCPP_DEBUG_LINK',
                            '-D', 'HXCPP_STACK_LINE',
                            '-D', 'HXCPP_STACK_TRACE',
                            '-D', 'HXCPP_CHECK_POINTER',
                            '-D', 'HXCPP_CPP17',
                            '-D', 'safeMode',
                            '--macro', 'tools.macros.ToolsMacros.loadPluginClass(${Json.stringify(info.plugin.tools)})'
                        ], {
                            cwd: pluginPath
                        });
                        Files.deleteRecursive(pluginHaxelibPath);
                        Files.setToSameLastModified(ceramicBinPath, pluginCppiaPath);
                    }
                    final pluginModule = cpp.cppia.Module.fromData(File.getBytes(pluginCppiaPath).getData());
                    final pluginClass = pluginModule.resolveClass(info.plugin.tools);
                    if (pluginClass != null) {
                        final instance = Type.createInstance(pluginClass, []);
                        if (!context.plugins.exists(info.plugin.id)) {
                            context.plugins.set(info.plugin.id, {
                                path: pluginPath,
                                id: info.plugin.id,
                                name: info.plugin.name,
                                runtime: info.plugin.runtime,
                                instance: instance
                            });
                        }
                    }
                }
            }
        }

    }

    public static function runCeramic(cwd:String, args:Array<String>, mute:Bool = false) {

        if (args == null) {
            args = [];
        }
        var actualArgs = [].concat(args);
        if (!context.colors && actualArgs.indexOf('--no-colors') == -1) {
            actualArgs.push('--no-colors');
        }

        if (Sys.systemName() == 'Windows') {
            return command(Path.join([context.ceramicToolsPath, 'ceramic.exe']), actualArgs, { cwd: cwd, mute: mute });
        } else {
            return command(Path.join([context.ceramicToolsPath, 'ceramic']), actualArgs, { cwd: cwd, mute: mute });
        }

    }

    public static function print(message:String):Void {

        if (context.muted) return;

        var message = '' + message;
        if (context.printSplitLines) {
            var parts = message.split("\n");
            for (part in parts) {
                Sys.sleep(0.001);
                stdoutWrite(part+"\n");
            }
        }
        else {
            stdoutWrite(message+"\n");
        }

    }

    public static function success(message:String):Void {

        if (context.muted) return;

        if (context.colors) {
            stdoutWrite(''+Colors.green(message)+"\n");
        } else {
            stdoutWrite(''+message+"\n");
        }

    }

    public static function error(message:String):Void {

        if (context.muted) return;

        if (context.colors) {
            stderrWrite(''+Colors.red(message)+"\n");
        } else {
            stderrWrite(''+message+"\n");
        }

    }

    public static function warning(message:String):Void {

        if (context.muted) return;

        if (context.colors) {
            stderrWrite(''+Colors.yellow(message)+"\n");
        } else {
            stderrWrite(''+message+"\n");
        }

    }

    public static function stdoutWrite(input:String) {

        Sys.stdout().writeString(input);
        Sys.stdout().flush();

    }

    public static function stderrWrite(input:String) {

        Sys.stderr().writeString(input);
        Sys.stderr().flush();

    }

    public static function fail(message:String):Void {

        error(message);
        Sys.exit(1);

    }

    public static function homedir():String {
        #if windows
        return Sys.getEnv("USERPROFILE");
        #else
        return Sys.getEnv("HOME");
        #end
    }

    public static function runningHaxeServerPort():Int {

        var homedir:String = homedir();
        var infoPath = Path.join([homedir, '.ceramic-haxe-server']);
        var mtime = Files.getLastModified(infoPath);
        var currentTime = Date.now().getTime() / 1000;
        var timeGap = Math.abs(currentTime - mtime);
        if (timeGap < 2.0) {
            return Std.parseInt(StringTools.trim(File.getContent(infoPath)));
        }
        else {
            return -1;
        }

    }

    public static function patch(args:Array<String>, ?options:{ ?cwd:String, ?mute:Bool, ?detached:Bool, ?tick:()->Void, ?env:Dynamic<String> }) {

        var patch = Sys.systemName() == 'Windows' ? Path.join([context.ceramicToolsPath, 'resources', 'patch.bat']) : Path.join([context.ceramicToolsPath, 'resources', 'patch.sh']);
        return command(patch, args, options);

    }

    public static function haxe(args:Array<String>, ?options:{ ?cwd:String, ?mute:Bool, ?detached:Bool, ?tick:()->Void, ?env:Dynamic<String> }) {

        var haxe = Sys.systemName() == 'Windows' ? 'haxe.cmd' : 'haxe';
        return command(Path.join([context.ceramicToolsPath, haxe]), args, options);

    }

    public static function haxeWithChecksAndLogs(args:Array<String>, ?options:{ ?cwd:String, ?logCwd:String, ?tick:()->Void, ?filter:(line:String)->Bool }) {

        var haxe = Sys.systemName() == 'Windows' ? 'haxe.cmd' : 'haxe';
        return commandWithChecksAndLogs(Path.join([context.ceramicToolsPath, haxe]), args, options);

    }

    public static function haxelib(args:Array<String>, ?options:{ ?cwd:String, ?mute:Bool, ?detached:Bool, ?tick:()->Void, ?env:Dynamic<String> }) {

        var haxelib = Sys.systemName() == 'Windows' ? 'haxelib.cmd' : 'haxelib';

        if (options == null) {
            options = {};
        }
        else {
            options = {
                cwd: options.cwd,
                mute: options.mute
            };
        }

        if (args != null) {
            if (args[0] == 'install') {
                options.mute = true;
                print('Install haxe library: ' + args[1]);
            }
            else if (args[0] == 'dev') {
                options.mute = true;
                print('Link haxe library: ' + args[1]);
            }
        }

        return command(Path.join([context.ceramicToolsPath, haxelib]), args, options);

    }

    public static function haxelibGlobal(args:Array<String>, ?options:{ ?cwd:String, ?mute:Bool, ?detached:Bool, ?tick:()->Void, ?env:Dynamic<String> }) {

        return command('haxelib', args, options);

    }

    public static function node(args:Array<String>, ?options:{ ?cwd:String, ?mute:Bool, ?detached:Bool, ?tick:()->Void, ?env:Dynamic<String> }) {

        var node = 'node';
        if (Sys.systemName() == 'Windows')
            node += '.cmd';
        return command(node, args, options);

    }

    /** Checks if a command exists by searching through PATH directories. */
    public static function commandExists(command:String):Bool {

        // Get system PATH
        var path = Sys.getEnv("PATH");
        if (path == null) return false;

        // Split PATH into individual directories
        var variants = [];
        #if windows
        var pathSeparator = ";";
        variants.push('$command.exe');
        variants.push('$command.cmd');
        variants.push('$command.bat');
        #else
        var pathSeparator = ":";
        variants.push(command);
        #end

        var paths = path.split(pathSeparator);

        // Search each directory in PATH
        for (d in 0...paths.length) {
            final dir = paths[d];
            if (dir == "" || !FileSystem.exists(dir) || !FileSystem.isDirectory(dir)) continue;

            for (v in 0...variants.length) {
                final variant = variants[v];
                final fullPath = Path.join([dir, variant]);
                if (FileSystem.exists(fullPath)) {
                    return true;
                }
            }
        }

        return false;

    }

    public static function resolveAvailableHaxeLibraries(cwd:String):Array<HaxeLibrary> {

        var haxelibRepoPath = Path.join([cwd, '.haxelib']);
        var result:Array<HaxeLibrary> = [];

        if (FileSystem.exists(haxelibRepoPath) && FileSystem.isDirectory(haxelibRepoPath)) {
            for (libPath in FileSystem.readDirectory(haxelibRepoPath)) {
                var fullLibPath = Path.join([haxelibRepoPath, libPath]);
                if (FileSystem.isDirectory(fullLibPath)) {
                    var devPath = Path.join([fullLibPath, '.dev']);
                    var currentPath = Path.join([fullLibPath, '.current']);

                    var lib:HaxeLibrary = {
                        name: libPath,
                        dev: FileSystem.exists(devPath) ? File.getContent(devPath).trim() : null,
                        current: FileSystem.exists(currentPath) ? File.getContent(currentPath).trim() : null,
                        versions: []
                    };

                    for (versionPath in FileSystem.readDirectory(fullLibPath)) {
                        if (versionPath != '.dev' && fullLibPath != '.current') {
                            lib.versions.push(versionPath);
                        }
                    }

                    result.push(lib);
                }
            }
        }

        return result;

    }

    public static function resolveLibraryHaxePaths(cwd:String, lib:HaxeLibrary, version:String):Array<String> {

        var result = [];
        var libVersionPath = null;

        if (version == null || version.trim().length == 0) {
            version = lib.current;
            if (version == null && lib.dev != null && lib.dev.trim().length > 0) {
                version = 'dev';
            }
        }

        if (version != null && version.trim().length > 0) {
            if (version == 'dev') {
                libVersionPath = lib.dev;
            }
            else {
                libVersionPath = version;
            }
        }

        if (libVersionPath != null) {
            if (!Path.isAbsolute(libVersionPath)) {
                libVersionPath = Path.join([cwd, '.haxelib', lib.name, libVersionPath.replace('.', ',')]);
            }
            if (fileExists(libVersionPath)) {
                var haxelibJsonPath = Path.join([libVersionPath, 'haxelib.json']);
                if (fileExists(haxelibJsonPath)) {
                    try {
                        var haxelibJson = Json.parse(File.getContent(haxelibJsonPath));
                        if (haxelibJson.classPath != null) {
                            var classPath = Path.join([libVersionPath, haxelibJson.classPath]);
                            if (fileExists(classPath)) {
                                result.push(classPath);
                            }
                            else {
                                result.push(libVersionPath);
                            }
                        }
                    }
                    catch (e:Dynamic) {
                        result.push(libVersionPath);
                    }
                }
                else {
                    result.push(libVersionPath);
                }
            }
        }

        return result;

    }

    public static function ensureHaxelibDevToCeramicHaxelib(libName:String, haxelibVersion:String, cwd:String) {

        var ceramicHaxelibRepoPath = Path.join([context.ceramicRootPath, '.haxelib']);
        var haxelibRepoPath = Path.join([cwd, '.haxelib']);

        var projectLibPath = Path.join([haxelibRepoPath, libName]);
        var devPath = Path.join([projectLibPath, '.dev']);
        var currentPath = Path.join([projectLibPath, '.current']);

        var ceramicHaxelibPath = Path.join([ceramicHaxelibRepoPath, libName, haxelibVersion]);

        if (FileSystem.exists(devPath)) {
            var devContent = File.getContent(devPath).trim();
            if (devContent != ceramicHaxelibPath) {
                File.saveContent(devPath, ceramicHaxelibPath);
            }
        }
        else {
            if (FileSystem.exists(currentPath)) {
                FileSystem.deleteFile(currentPath);
            }
            if (!FileSystem.exists(projectLibPath)) {
                FileSystem.createDirectory(projectLibPath);
            }
            File.saveContent(devPath, ceramicHaxelibPath);
        }

    }

    public static function ensureHaxelibDevToCeramicGit(libName:String, cwd:String, ?intermediateDir:String) {

        var haxelibRepoPath = Path.join([cwd, '.haxelib']);

        var projectLibPath = Path.join([haxelibRepoPath, libName]);
        var devPath = Path.join([projectLibPath, '.dev']);
        var currentPath = Path.join([projectLibPath, '.current']);

        var ceramicHaxelibGitPath = Path.join([context.ceramicGitDepsPath, libName]);

        if (intermediateDir != null)
            ceramicHaxelibGitPath = Path.join([ceramicHaxelibGitPath, intermediateDir]);

        if (FileSystem.exists(devPath)) {
            var devContent = File.getContent(devPath).trim();
            if (devContent != ceramicHaxelibGitPath) {
                File.saveContent(devPath, ceramicHaxelibGitPath);
            }
        }
        else {
            if (FileSystem.exists(currentPath)) {
                FileSystem.deleteFile(currentPath);
            }
            if (!FileSystem.exists(projectLibPath)) {
                FileSystem.createDirectory(projectLibPath);
            }
            File.saveContent(devPath, ceramicHaxelibGitPath);
        }

    }

    public static function checkProjectHaxelibSetup(cwd:String, args:Array<String>) {

        var ceramicHaxelibRepoPath = Path.join([context.ceramicRootPath, '.haxelib']);
        var haxelibRepoPath = Path.join([cwd, '.haxelib']);

        if (!FileSystem.exists(haxelibRepoPath))
            FileSystem.createDirectory(haxelibRepoPath);

        ensureHaxelibDevToCeramicHaxelib('hxcs', '4,2,0', cwd);
        ensureHaxelibDevToCeramicGit('hxcpp', cwd);
        ensureHaxelibDevToCeramicGit('hxnodejs-ws', cwd);
        ensureHaxelibDevToCeramicGit('hscript', cwd);
        ensureHaxelibDevToCeramicGit('bind', cwd);
        ensureHaxelibDevToCeramicGit('hxnodejs', cwd);
        ensureHaxelibDevToCeramicGit('loreline', cwd);
        ensureHaxelibDevToCeramicGit('format', cwd);
        ensureHaxelibDevToCeramicGit('ase', cwd);
        ensureHaxelibDevToCeramicGit('bin-packing', cwd);
        ensureHaxelibDevToCeramicGit('akifox-asynchttp', cwd);
        ensureHaxelibDevToCeramicGit('tracker', cwd);
        ensureHaxelibDevToCeramicGit('arcade', cwd);
        ensureHaxelibDevToCeramicGit('nape', cwd);
        ensureHaxelibDevToCeramicGit('differ', cwd);
        ensureHaxelibDevToCeramicGit('hsluv', cwd, 'haxe');
        ensureHaxelibDevToCeramicGit('spine-hx', cwd);
        ensureHaxelibDevToCeramicGit('clipper', cwd, 'Haxe/src');
        ensureHaxelibDevToCeramicGit('generate', cwd);
        ensureHaxelibDevToCeramicGit('format-tiled', cwd);
        ensureHaxelibDevToCeramicGit('imgui-hx', cwd);
        ensureHaxelibDevToCeramicGit('gif', cwd);
        ensureHaxelibDevToCeramicGit('linc_dialogs', cwd);
        ensureHaxelibDevToCeramicGit('linc_rtmidi', cwd);
        ensureHaxelibDevToCeramicGit('fuzzaldrin', cwd);
        ensureHaxelibDevToCeramicGit('shade', cwd);

    }

    public static function installMissingLibsIfNeeded(cwd:String, args:Array<String>, ?project:Project) {

        if (project == null) {
            project = ensureCeramicProject(cwd, args, App);
        }

        var haxelibRepoPath = Path.join([cwd, '.haxelib']);

        var hasMissingLibs = false;

        var appLibs:Array<Dynamic> = project.app.libs;
        for (lib in appLibs) {
            var libName:String = null;
            var libVersion:String = "*";
            if (Std.isOfType(lib, String)) {
                libName = lib;
            } else {
                for (k in Reflect.fields(lib)) {
                    libName = k;
                    libVersion = Reflect.field(lib, k);
                    break;
                }
            }
            if (libVersion.trim() == '' || libVersion == '*') {
                // Any version
                if (!FileSystem.exists(Path.join([haxelibRepoPath, libName]))) {
                    hasMissingLibs = true;
                }
            }
            else if (libVersion.startsWith('git:')) {
                // Git
                if (!FileSystem.exists(Path.join([haxelibRepoPath, libName, 'git']))) {
                    hasMissingLibs = true;
                }
            }
            else if (libVersion.startsWith('path:')) {
                // Path/Dev
                if (!FileSystem.exists(Path.join([haxelibRepoPath, libName, '.dev']))) {
                    hasMissingLibs = true;
                }
            }
            else {
                // Specific version
                if (!FileSystem.exists(Path.join([haxelibRepoPath, libName, libVersion.trim().replace('.',',')]))) {
                    hasMissingLibs = true;
                }
            }
        }

        if (hasMissingLibs) {
            var taskName = 'libs';
            if (context.backend != null) {
                taskName = context.backend.name + ' ' + taskName;
            }
            runTask('libs');
        }

    }

    /** Like `command()`, but will perform additional checks and log formatting,
        compared to a regular `command()` call. Use it to run compilers and run apps.
        @return status code */
    public static function commandWithChecksAndLogs(name:String, ?args:Array<String>, ?options:{ ?cwd:String, ?logCwd:String, ?tick:()->Void, ?filter:(line:String)->Bool }):Int {

        if (options == null) {
            options = { cwd: null, logCwd: null };
        }
        if (options.cwd == null) options.cwd = context.cwd;
        if (options.logCwd == null) options.logCwd = options.cwd;

        var status = 0;

        var logCwd = options.logCwd;

        // Handle Windows, again...
        if (Sys.systemName() == 'Windows') {
            // npm
            if (name == 'npm' || name == 'node' || name == 'ceramic' || name == 'haxe' || name == 'haxelib' || name == 'neko') {
                name = name + '.cmd';
            }
        }

        final proc = new Process(name, args, options.cwd);

        if (Sys.systemName() == 'Windows') {
            proc.env.set('CERAMIC_CLI', Path.join([context.ceramicToolsPath, 'ceramic.exe']));
        } else {
            proc.env.set('CERAMIC_CLI', Path.join([context.ceramicToolsPath, 'ceramic']));
        }

        proc.inherit_file_descriptors = false;

        var stdout = new SplitStream('\n'.code, line -> {
            line = formatLineOutput(logCwd, line);
            stdoutWrite(line + "\n");
        });

        var stderr = new SplitStream('\n'.code, line -> {
            if (options.filter == null || !options.filter(line)) {
                line = formatLineOutput(logCwd, line);
                stderrWrite(line + "\n");
            }
        });

        proc.read_stdout = data -> {
            stdout.add(data);
        };

        proc.read_stderr = data -> {
            stderr.add(data);
        };

        proc.create();

        final tick = options.tick;
        status = proc.tick_until_exit_status(() -> {
            Runner.tick();
            timer.update();
            if (tick != null) {
                tick();
            }
            if (context.shouldExit) {
                proc.kill(false);
                Sys.exit(0);
            }
        });

        return status;

    }

    public static function command(name:String, ?args:Array<String>, ?options:{ ?cwd:String, ?mute:Bool, ?detached:Bool, ?tick:()->Void, ?env:Dynamic<String> }) {

        if (options == null) {
            options = { cwd: null, mute: false };
        }

        if (context.muted) options.mute = true;

        if (options.cwd == null) options.cwd = context.cwd;

        var result = {
            stdout: null,
            stderr: null,
            status: 0
        };

        // Handle Windows, again...
        if (Sys.systemName() == 'Windows') {
            if (name == 'npm' || name == 'node' || name == 'ceramic' || name == 'haxe' || name == 'haxelib' || name == 'neko') {
                name = name + '.cmd';
            }
        }

        final proc = new Process(name, args, options.cwd);

        if (options.env != null) {
            for (field in Reflect.fields(options.env)) {
                proc.env.set(field, Reflect.field(options.env, field));
            }
        }

        if (Sys.systemName() == 'Windows') {
            proc.env.set('CERAMIC_CLI', Path.join([context.ceramicToolsPath, 'ceramic.exe']));
        } else {
            proc.env.set('CERAMIC_CLI', Path.join([context.ceramicToolsPath, 'ceramic']));
        }

        if (options.detached) {
            proc.detach_process = true;
        }

        var stdout:StringBuf = null;
        var stderr:StringBuf = null;

        if (options.mute) {

            proc.inherit_file_descriptors = false;

            stdout = new StringBuf();
            stderr = new StringBuf();

            proc.read_stdout = data -> {
                stdout.add(data);
            };

            proc.read_stderr = data -> {
                stderr.add(data);
            };

        }
        else {

            proc.inherit_file_descriptors = true;

        }

        proc.create();

        final tick = options.tick;
        result.status = proc.tick_until_exit_status(() -> {
            Runner.tick();
            timer.update();
            if (tick != null) {
                tick();
            }
            if (context.shouldExit) {
                proc.kill(false);
                Sys.exit(0);
            }
        });

        if (stdout != null) {
            result.stdout = stdout.toString();
        }

        if (stderr != null) {
            result.stderr = stderr.toString();
        }

        return result;

    }

    public static function runTask(taskCommand, ?args:Array<String>, addContextArgs:Bool = true, allowMissingTask:Bool = false):Bool {

        var task = context.task(taskCommand);
        if (task == null) {
            var err = 'Cannot run task because `ceramic $taskCommand` command doesn\'t exist.';
            if (allowMissingTask) {
                warning(err);
            }
            else {
                fail(err);
            }
            return false;
        }

        // Run with electron runner
        var taskArgs = [];
        if (args != null) {
            taskArgs = [].concat(args);
        }
        taskArgs.push('--cwd');
        taskArgs.push(context.cwd);
        if (context.debug) {
            taskArgs.push('--debug');
        }
        if (context.variant != 'standard') {
            taskArgs.push('--variant');
            taskArgs.push(context.variant);
        }
        task.run(context.cwd, taskArgs);

        return true;

    }

    public static function extractArgValue(args:Array<String>, name:String, remove:Bool = false):String {

        var index = args.indexOf('--$name');

        if (index == -1) {
            return null;
        }

        if (index + 1 >= args.length) {
            fail('A value is required after --$name argument.');
        }

        var value = args[index + 1];

        if (remove) {
            args.splice(index, 2);
        }

        return value;

    }

    public static function extractArgFlag(args:Array<String>, name:String, remove:Bool = false):Bool {

        var index = args.indexOf('--$name');

        if (index == -1) {
            return false;
        }

        if (remove) {
            args.splice(index, 1);
        }

        return true;

    }

    public static function getRelativePath(absolutePath:String, relativeTo:String):String {

        return Files.getRelativePath(absolutePath, relativeTo);

    }

    public static function getTargetName(args:Array<String>, availableTargets:Array<tools.BuildTarget>):String {

        // Compute target from args
        var targetArgIndex = 1;
        if (args.length > 1) {
            if (context.hasTask(args[0] + ' ' + args[1])) {
                targetArgIndex++;
            }
        }
        var targetArg = args[targetArgIndex];
        var targetName = null;
        if (targetArg != null && !targetArg.startsWith('--')) {
            targetName = targetArg;
        }

        // Special case
        if (targetName == 'default') return targetName;

        // Return it only if available in targets
        for (target in availableTargets) {
            if (targetName == target.name) {
                return targetName;
            }
        }
        targetName = null;

        // Compute target name from current OS
        //
        var os = Sys.systemName();
        if (os == 'Mac') {
            targetName = 'mac';
        }
        else if (os == 'Windows') {
            targetName == 'windows';
        }
        else if (os == 'Linux') {
            targetName == 'linux';
        }

        // Return it only if available in targets
        for (target in availableTargets) {
            if (targetName == target.name) {
                return targetName;
            }
        }

        // Nothing matched
        return null;

    }

    static var RE_STACK_FILE_LINE = ~/Called\s+from\s+([a-zA-Z0-9_:\.]+)\s+(.+?\.hx)\s+line\s+([0-9]+)$/;
    static var RE_STACK_FILE_LINE_BIS = ~/([a-zA-Z0-9_:\.]+)\s+\((.+?\.hx)\s+line\s+([0-9]+)\)$/;
    static var RE_TRACE_FILE_LINE = ~/(.+?\.hx)::?([0-9]+):?\s+/;
    static var RE_HAXE_ERROR = ~/^(.+)::?(\d+):? (?:lines \d+-(\d+)|character(?:s (\d+)-| )(\d+)) : (?:(Warning) : )?(.*)$/;
    static var RE_JS_FILE_LINE = ~/^(?:\[error\] )?at ([a-zA-Z0-9_\.-]+) \((.+)\)$/;

    public static function isErrorOutput(input:String):Bool {

        // We don't want \r char to mess up everything (windows)
        input = input.replace("\r", '');

        if (input.indexOf(': Warning :') != -1) return false; // This is a warning, not an error

        var result = RE_HAXE_ERROR.match(input);

        return result;

    }

    public static function simplifyAbsolutePath(absolutePath:String, ?relativeToPath:String):String {

        if (relativeToPath == null) {
            relativeToPath = context.cwd;
        }

        var result = getRelativePath(absolutePath, relativeToPath);
        if (result.length < absolutePath.length) {
            return result;
        }

        return absolutePath;

    }

    public extern inline overload static function formatFileLink(path:String, line:Int):String {

        return _formatFileLink(path, ''+line);

    }

    public extern inline overload static function formatFileLink(path:String, line:String):String {

        return _formatFileLink(path, line);

    }

    static function _formatFileLink(path:String, line:String):String {

        var cwd = context.cwd;

        if (context.vscode) {
            var absolutePath = Path.isAbsolute(path) ? Path.normalize(path) : Path.normalize(Path.join([cwd, path]));
            var vscodePath = (context.vscodeUriScheme ?? 'vscode') + '://file${absolutePath.startsWith('/') ? absolutePath : '/' + absolutePath}:${line}';
            var normalizedPath = Path.normalize(path);
            var name = Path.withoutDirectory(normalizedPath);
            var basePath = Path.directory(normalizedPath);
            var numSlashes = 1;
            if (context.defines.exists('log_file_subdirectories')) {
                numSlashes = Std.parseInt(context.defines.get('log_file_subdirectories')) ?? 1;
            }
            for (_ in 0...numSlashes) {
                var subdir = Path.withoutDirectory(basePath).replace('/', '').trim();
                if (subdir == basePath.replace('/', '').trim() || subdir == '' || subdir == '..' || subdir == '.') {
                    break;
                }
                basePath = Path.directory(basePath);
                name = subdir + '/' + name;
            }
            if (name.endsWith('.hx')) {
                name = name.substring(0, name.length - 3);
            }
            if (fileExists(absolutePath)) {
                return '\u001b]8;;${vscodePath}\u001b\\${name}:${line}\u001b]8;;\u001b\\';
            }
            else {
                return Colors.gray('${name}:${line}');
            }
        }

        return path + ':' + line;

    }

    public static function fileExists(path:String):Bool {

        static var existCache = new Map<String,Bool>();

        var result = false;

        if (existCache.exists(path)) {
            result = existCache.get(path) == true;
        }
        else {
            result = FileSystem.exists(path);
            existCache.set(path, result);
        }

        return result;

    }

    public static function resolveAbsolutePath(cwd:String, relativePath:String):String {

        if (Path.isAbsolute(relativePath)) {
            return relativePath;
        }

        var resolvedPath = Path.normalize(Path.join([cwd, relativePath]));

        if (!fileExists(resolvedPath)) {
            if (context.haxePaths != null) {
                for (haxePath in context.haxePaths) {
                    var testPath = Path.normalize(Path.join([haxePath, relativePath]));
                    if (fileExists(testPath)) {
                        resolvedPath = testPath;
                        break;
                    }
                }
            }
        }

        return resolvedPath;

    }

    private static final RE_STRIP_ANSI = ~/[\x1B\x9B](?:[@-Z\\-_]|\[[0-?]*[ -\/]*[@-~]|\].*?(?:\x07|\x1B\\))/g;

    /** Strips all ANSI escape sequences from a string including colors, styles,
        operating system commands, and other control sequences. */
    public static function stripAnsi(str:String):String {
        if (str == null) return null;
        if (str.length == 0) return "";
        return RE_STRIP_ANSI.replace(str, "");
    }

    public static function formatLineOutput(cwd:String, input:String):String {

        if (!context.colors) {
            input = stripAnsi(input);
        }

        // We don't want \r char to mess up everything (windows)
        input = input.replace("\r", '').rtrim();

        if (RE_HAXE_ERROR.match(input)) {
            var relativePath = RE_HAXE_ERROR.matched(1);
            var lineNumber = RE_HAXE_ERROR.matched(2);
            var absolutePath = Path.isAbsolute(relativePath) ? relativePath : resolveAbsolutePath(cwd, relativePath);
            var finalPath = simplifyAbsolutePath(absolutePath);
            if (context.vscode) {
                var charsBefore = 'characters ' + RE_HAXE_ERROR.matched(4) + '-' + RE_HAXE_ERROR.matched(5);
                var charsAfter = 'characters ' + (Std.parseInt(RE_HAXE_ERROR.matched(4))#if (haxe_ver < 4) + 1 #end) + '-' + (Std.parseInt(RE_HAXE_ERROR.matched(5))#if (haxe_ver < 4) + 1 #end);
                input = input.replace(charsBefore, charsAfter);
            }
            input = input.replace(relativePath, finalPath);
            if (context.colors) {
                if (input.indexOf(': Warning :') != -1) {
                    input = '${formatFileLink(finalPath, lineNumber)}: '.gray() + input.replace(': Warning :', ':').substr('$finalPath:$lineNumber:'.length + 1).yellow();
                } else {
                    input = '$finalPath:$lineNumber: '.gray() + input.substr('$finalPath:$lineNumber:'.length + 1).red();
                }
            } else {
                input = '$finalPath:$lineNumber: ' + input.substr('$finalPath:$lineNumber:'.length + 1);
            }
        }
        else if (RE_STACK_FILE_LINE.match(input)) {
            var symbol = RE_STACK_FILE_LINE.matched(1);
            var relativePath = RE_STACK_FILE_LINE.matched(2);
            var lineNumber = RE_STACK_FILE_LINE.matched(3);
            var absolutePath = Path.isAbsolute(relativePath) ? relativePath : resolveAbsolutePath(cwd, relativePath);
            var finalPath = simplifyAbsolutePath(absolutePath);
            if (context.colors) {
                input = input.replace(RE_STACK_FILE_LINE.matched(0), '$symbol '.red() + formatFileLink(finalPath, lineNumber).gray());
            } else {
                input = input.replace(RE_STACK_FILE_LINE.matched(0), '$symbol $finalPath:$lineNumber');
            }
        }
        else if (RE_STACK_FILE_LINE_BIS.match(input)) {
            var symbol = RE_STACK_FILE_LINE_BIS.matched(1);
            var relativePath = RE_STACK_FILE_LINE_BIS.matched(2);
            var lineNumber = RE_STACK_FILE_LINE_BIS.matched(3);
            var absolutePath = Path.isAbsolute(relativePath) ? relativePath : resolveAbsolutePath(cwd, relativePath);
            var finalPath = simplifyAbsolutePath(absolutePath);
            if (context.colors) {
                input = input.replace(RE_STACK_FILE_LINE_BIS.matched(0), '$symbol '.red() + formatFileLink(finalPath, lineNumber).gray());
            } else {
                input = input.replace(RE_STACK_FILE_LINE_BIS.matched(0), '$symbol $finalPath:$lineNumber');
            }
        }
        else if (RE_TRACE_FILE_LINE.match(input)) {
            var relativePath = RE_TRACE_FILE_LINE.matched(1);
            var lineNumber = RE_TRACE_FILE_LINE.matched(2);
            var absolutePath = Path.isAbsolute(relativePath) ? relativePath : resolveAbsolutePath(cwd, relativePath);
            var finalPath = simplifyAbsolutePath(absolutePath);
            input = input.replace(RE_TRACE_FILE_LINE.matched(0), '');
            if (context.colors) {
                if (input.startsWith('[info] ')) {
                    input = input.substr(7).cyan();
                } else if (input.startsWith('[debug] ')) {
                    input = input.substr(8).magenta();
                } else if (input.startsWith('[warning] ')) {
                    input = input.substr(10).yellow();
                } else if (input.startsWith('[error] ')) {
                    input = input.substr(8).red();
                } else if (input.startsWith('[success] ')) {
                    input = input.substr(10).green();
                } else if (input.startsWith('characters ')) {
                    input = input.red();
                }
                input += ' ' + formatFileLink(finalPath, lineNumber).gray();
            } else {
                input += ' $finalPath:$lineNumber';
            }
        }
        else if (RE_JS_FILE_LINE.match(input)) {
            var identifier = RE_JS_FILE_LINE.matched(1);
            var absolutePathWithLine = RE_JS_FILE_LINE.matched(2);
            if (context.colors) {
                input = (identifier + ' ').red() + absolutePathWithLine.gray();
            } else {
                input = identifier + ' ' + absolutePathWithLine;
            }
        }
        else if (context.colors && input.startsWith('Error : ')) {
            input = input.red();
        }
        else if (input.startsWith('[error] ')) {
            if (context.colors) {
                input = input.substring('[error] '.length);
                input = input.red();
            }
        }
        else if (input.startsWith('[warning] ')) {
            if (context.colors) {
                input = input.substring('[warning] '.length);
                input = input.yellow();
            }
        }
        else if (input.startsWith('[success] ')) {
            if (context.colors) {
                input = input.substring('[success] '.length);
                input = input.green();
            }
        }
        else if (input.startsWith('[info] ')) {
            if (context.colors) {
                input = input.substring('[info] '.length);
                input = input.cyan();
            }
        }
        else if (input.startsWith('[debug] ')) {
            if (context.colors) {
                input = input.substring('[debug] '.length);
                input = input.magenta();
            }
        }
        else if (input == '[debug]' || input == '[info]' || input == '[success]' || input == '[warning]' || input == '[error]') {
            input = '';
        }
        else if (context.colors && input.startsWith('Called from hxcpp::')) {
            input = input.red();
        }

        return input;

    }

    public static function loadProject(cwd:String, args:Array<String>):Project {

        var projectPath = Path.join([cwd, 'ceramic.yml']);
        if (!FileSystem.exists(projectPath)) return null;
        var kind = getProjectKind(cwd, args);
        if (kind == null) return null;
        switch (kind) {
            case App:
                var project = new Project();
                project.loadAppFile(projectPath);
                return project;

            case Plugin(_):
                var project = new Project();
                project.loadPluginFile(projectPath);
                return project;
        }
        return null;

    }

    public static function getProjectKind(cwd:String, args:Array<String>):ProjectKind {

        return new Project().getKind(Path.join([cwd, 'ceramic.yml']));

    }

    public static function loadIdeInfo(cwd:String, args:Array<String>):Dynamic {

        var ceramicYamlPath = Path.join([cwd, 'ceramic.yml']);
        if (!FileSystem.exists(ceramicYamlPath)) {
            fail('Cannot load IDE info because ceramic.yml does not exist ($ceramicYamlPath)');
        }

        try {
            var yml = File.getContent(ceramicYamlPath);
            yml = yml.replace('{plugin:cwd}', cwd);
            yml = yml.replace('{cwd}', cwd);
            var data = Yaml.parse(yml);
            if (data == null) {
                fail('Invalid IDE data at path: $ceramicYamlPath');
            }
            if (data.ide == null) {
                return {};
            }
            else {
                return data.ide;
            }
        }
        catch (e:Dynamic) {
            fail('Failed to load yaml data at path: $ceramicYamlPath ; $e');
            return null;
        }

    }

    public static function ensureCeramicProject(cwd:String, args:Array<String>, kind:ProjectKind):Project {

        switch (kind) {
            case App:
                var project = new Project();
                project.loadAppFile(Path.join([cwd, 'ceramic.yml']));
                return project;

            case Plugin(_):
                var project = new Project();
                project.loadPluginFile(Path.join([cwd, 'ceramic.yml']));
                return project;
        }

        fail('Failed to ensure this is a ceramic project.');
        return null;

    }

    public static function runHooks(cwd:String, args:Array<String>, hooks:Array<Hook>, when:String):Void {

        if (hooks == null) return;

        for (hook in hooks) {
            if (hook.when == when) {
                print('Run $when hooks');
                break;
            }
        }

        for (hook in hooks) {
            if (hook.when == when) {

                var cmd = hook.command;
                var res;
                if (cmd == 'ceramic') {
                    res = runCeramic(cwd, hook.args != null ? hook.args : []);
                }
                else {
                    res = command(hook.command, hook.args != null ? hook.args : [], { cwd: cwd });
                }

                if (res.status != 0) {
                    if (res.stderr.trim().length > 0) {
                        warning(res.stderr);
                    }
                    fail('Error when running hook: ' + hook.command + (hook.args != null ? ' ' + hook.args.join(' ') : ''));
                }

            }
        }

    }

    static var RE_HXCPP_LINE_MARKER = ~/^(HXLINE|HXDLIN)\([^)]+\)/;

    public static function stripHxcppLineMarkers(cppContent:String):String {

        var cppLines = cppContent.split("\n");

        for (i in 0...cppLines.length) {
            var line = cppLines[i];
            if (RE_HXCPP_LINE_MARKER.match(line.ltrim())) {
                var len = RE_HXCPP_LINE_MARKER.matched(0).length;
                var space = '';
                for (n in 0...len) {
                    space += ' ';
                }
                cppLines[i] = line.replace(RE_HXCPP_LINE_MARKER.matched(0), space);
            }
        }

        return cppLines.join("\n");

    }

    public static function toAssetConstName(input:String):String {

        var res = new StringBuf();
        var len = input.length;
        var i = 0;
        var canAddSpace = false;

        while (i < len) {

            var c = input.charAt(i);
            if (c == '/') {
                res.add('__');
                canAddSpace = false;
            }
            else if (c == '.') {
                res.add('_');
                canAddSpace = false;
            }
            else if (isAsciiChar(c)) {

                var uc = c.toUpperCase();
                var isUpperCase = (c == uc);

                if (canAddSpace && isUpperCase) {
                    res.add('_');
                    canAddSpace = false;
                }

                res.add(uc);
                canAddSpace = !isUpperCase;
            }
            else {
                res.add('_');
                canAddSpace = false;
            }

            i++;
        }

        var str = res.toString();
        if (str.endsWith('_')) str = str.substr(0, str.length - 1);

        return str;

    }

    public static function isAsciiChar(c:String):Bool {

        var code = c.charCodeAt(0);
        return (code >= '0'.code && code <= '9'.code)
            || (code >= 'A'.code && code <= 'Z'.code)
            || (code >= 'a'.code && code <= 'z'.code);

    }

    public static function compareSemVerAscending(a:String, b:String):Int {

        var partsA = a.split('.');
        var partsB = b.split('.');

        var i = 0;
        while (i < partsA.length && i < partsB.length) {
            var partA = Std.parseInt(partsA[i]);
            var partB = Std.parseInt(partsB[i]);

            if (partA > partB) {
                return 1;
            }
            else if (partA < partB) {
                return -1;
            }

            i++;
        }

        if (partsA.length > partsB.length) {
            return 1;
        }
        else if (partsA.length < partsB.length) {
            return -1;
        }

        return 0;

    }

    public static function getWindowsDrives():Array<String> {

        var result = [];
        var hasC = false;

        if (Sys.systemName() == 'Windows') {

            var out = command('wmic', ['logicaldisk', 'get', 'name'], { mute: true }).stdout;
            for (line in ~/[\r\n]+/g.split(out)) {
                line = line.trim();
                if (line.length >= 2 && line.charAt(1) == ':') {
                    var letter = line.charAt(0).toUpperCase();
                    if (letter == 'C') {
                        hasC = true;
                    }
                    else {
                        result.push(letter);
                    }
                }
            }
        }

        if (hasC) {
            result.unshift('C');
        }

        return result;

    }

    static var RE_NORMALIZED_WINDOWS_PATH_PREFIX = ~/^\/[a-zA-Z]:\//;

    public static function fixWindowsArgsPaths(args:Array<String>):Void {

        // Remove absolute path leading slash on windows, if any
        // This let us accept absolute paths that start with `/c:/` instead of `c:/`
        // which could happen after joining/normalizing paths via node.js or vscode extension
        if (Sys.systemName() == 'Windows') {
            var i = 0;
            while (i + 1 < args.length) {
                if (args[i].startsWith('--')) {
                    var value = args[i + 1];
                    if (value != null && value.startsWith('/') && RE_NORMALIZED_WINDOWS_PATH_PREFIX.match(value)) {
                        args[i + 1] = value.substring(1);
                        i++;
                    }
                }
                i++;
            }
        }

    }

}
