package ceramic;

import ceramic.Assets;
import ceramic.EntityData;
import ceramic.Files;
import ceramic.Path;
import ceramic.Platform;
import ceramic.ShaderAsset;
import ceramic.Shortcuts.*;
import ceramic.WatchDirectory;

/**
 * Runtime integration of `shade` shaders with the asset system.
 *
 * Meant to be used as a static extension:
 *
 * ```haxe
 * using ceramic.ShadePlugin;
 *
 * assets.watchDirectory();
 * assets.watchShadeShaders();
 * ```
 */
class ShadePlugin {

    /**
     * Watch the Haxe sources of `shade` shaders and re-transpile them on the fly when
     * they change, so shader edits show up without rebuilding the whole app.
     *
     * The list of shaders and their source paths is read from the `shade/info.json`
     * emitted next to the build output, so this only works on a machine that still has
     * the project sources, and needs the `ceramic` CLI to be reachable (it is when the
     * app was started through it).
     *
     * Only the body of a shader function can be reloaded this way: adding or removing a
     * `@param`, `@in` or `@out` also changes generated code that lives in the app binary,
     * and still requires a full rebuild.
     *
     * @param assets The assets instance owning the shaders, already watching a directory
     * @return The `WatchDirectory` used internally, or `null` if watching is unavailable
     */
    public static function watchShadeShaders(assets:Assets):WatchDirectory {

        // This walks the file system and spawns a CLI process, none of which should
        // ever be able to take the whole app down on startup
        try {
            return _watchShadeShaders(assets);
        }
        catch (e:Dynamic) {
            log.warning('Failed to watch shade shaders: $e');
            return null;
        }

    }

    static function _watchShadeShaders(assets:Assets):WatchDirectory {

        if (assets.runtimeAssets == null) {
            log.warning('Cannot watch shade shaders before watchDirectory() has been called');
            return null;
        }

        var targetPath:String = ceramic.macros.DefinesMacro.getJsonDefine('target_path');
        if (targetPath == null) {
            log.warning('Cannot watch shade shaders without a target path');
            return null;
        }

        var infoPath = Path.join([targetPath, 'shade', 'info.json']);
        var rawInfo = Files.getContent(infoPath);
        if (rawInfo == null) {
            log.warning('Cannot watch shade shaders, missing file: $infoPath');
            return null;
        }

        var shaders:Array<Dynamic> = null;
        try {
            var info:Dynamic = haxe.Json.parse(rawInfo);
            shaders = info.shaders;
        }
        catch (e:Dynamic) {
            log.warning('Cannot watch shade shaders, invalid file $infoPath: $e');
            return null;
        }

        if (shaders == null) {
            return null;
        }

        var sources = new Map<String,String>();
        var directories:Array<String> = [];

        for (i in 0...shaders.length) {
            var entry:Dynamic = shaders[i];
            var filePath:String = entry.filePath;
            if (filePath == null || !Files.exists(filePath))
                continue;

            sources.set(Path.normalize(filePath), assetNameFromShaderInfo(entry));

            var directory = Path.directory(filePath);
            if (directories.indexOf(directory) == -1)
                directories.push(directory);
        }

        if (directories.length == 0) {
            return null;
        }

        EntityData.data(assets).shadeShaderSources = sources;

        var watch = new WatchDirectory();
        for (i in 0...directories.length) {
            watch.watchDirectory(directories[i]);
        }

        watch.onDirectoryChange(assets, (directory, newFiles, previousFiles) -> {
            for (name => newTime in newFiles) {
                var previousTime:Float = -1;
                if (previousFiles.exists(name)) {
                    previousTime = previousFiles.get(name);
                }
                if (newTime == previousTime)
                    continue;

                var filePath = Path.normalize(Path.join([directory, name]));
                if (sources.exists(filePath)) {
                    transpileShadeShader(assets, filePath, sources.get(filePath));
                }
            }
        });

        assets.onDestroy(watch, _ -> {
            watch.destroy();
        });

        return watch;

    }

    /**
     * Derive the asset name a shader class produces, matching the naming used by
     * `Assets.add(Class<shade.Shader>)`: package parts joined with `_`, then the class
     * name with a lowercase first char.
     */
    static function assetNameFromShaderInfo(entry:Dynamic):String {

        var name:String = entry.name;
        var pack:Array<String> = entry.pack;
        var baseName = name.charAt(0).toLowerCase() + name.substr(1);

        return (pack != null && pack.length > 0) ? pack.join('_') + '_' + baseName : baseName;

    }

    static function transpileShadeShader(assets:Assets, filePath:String, assetName:String):Void {

        assets.runtimeAssets.requestTransformedDir(transformedDir -> {

            Platform.runCeramic([
                'shade',
                '--in', filePath,
                '--out', transformedDir,
                '--target', 'glsl'
            ], (code, out, err) -> {

                if (code != 0) {
                    log.error('Failed to transpile shade shader $filePath: $err');
                    return;
                }

                var asset:ShaderAsset = assets.shaderAsset(assetName);
                if (asset != null) {
                    asset.reloadFromTransformedDir(transformedDir);
                }
                else {
                    log.debug('No loaded shader asset named $assetName to reload');
                }

            });

        });

    }

}
