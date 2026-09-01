package ceramic;

import ceramic.Path;
import ceramic.Shortcuts.*;

using StringTools;
using ceramic.Extensions;

/**
 * Asset type for loading GPU shader programs.
 *
 * Supports loading:
 * - Combined shader files containing both vertex and fragment shaders
 * - Separate vertex (.vert) and fragment (.frag) shader files
 * - Backend-specific shader formats
 *
 * Features:
 * - Custom shader attributes support
 * - Hot reload for shader development
 * - Automatic pairing of vertex and fragment shaders
 * - Default vertex shader fallback
 *
 * ```haxe
 * var assets = new Assets();
 * // Load combined shader
 * assets.addShader('blur');
 *
 * // Load with custom attributes
 * assets.addShader('particle', null, {
 *     customAttributes: [
 *         {name: 'aVelocity', size: 2},
 *         {name: 'aLifetime', size: 1}
 *     ]
 * });
 *
 * assets.load();
 * var shader = assets.shader('blur');
 * quad.shader = shader;
 * ```
 */
class ShaderAsset extends Asset {

    /**
     * The loaded Shader instance.
     * Observable property that updates when the shader is loaded or reloaded.
     * Null until the asset is successfully loaded.
     */
    @observe public var shader:Shader = null;

    /**
     * Specialized shader class, if applicable
     */
    public var shaderClass:Class<shade.Shader> = null;

    /**
     * When set, shader files are read from this directory instead of the regular
     * assets directory. Used when a `shade` shader has been re-transpiled on the fly
     * from its Haxe source while the app is running.
     */
    var transformedPath:String = null;

    /**
     * Create a new shader asset.
     * @param name Shader file name (with or without extension)
     * @param variant Optional variant suffix
     * @param options Loading options including:
     *                - customAttributes: Array of custom vertex attributes
     *                - vertId: Specific vertex shader path (for separate files)
     *                - fragId: Specific fragment shader path (for separate files)
     */
    override public function new(name:String, ?variant:String, ?options:AssetOptions #if ceramic_debug_entity_allocs , ?pos:haxe.PosInfos #end) {

        super('shader', name, variant, options #if ceramic_debug_entity_allocs , pos #end);

    }

    /**
     * Load the shader program.
     * Handles both combined and separate vertex/fragment shader files.
     * Uses default textured vertex shader if none specified.
     * Emits complete event when finished.
     */
    override public function load() {

        status = LOADING;

        if (path == null) {
            log.warning('Cannot load shader asset if path is undefined.');
            status = BROKEN;
            emitComplete(false);
            return;
        }

        var shader:Shader = null;
        var baseAttributes:Array<ShaderAttribute> = null;
        var customAttributes:Array<ShaderAttribute> = null;
        var textureIdAttribute:ShaderAttribute = null;

        if (shaderClass == null) {

            baseAttributes = [
                { size: 3, name: 'vertexPosition' },
                { size: 2, name: 'vertexTCoord' },
                { size: 4, name: 'vertexColor' }
            ];

            textureIdAttribute = {
                size: 1, name: 'vertexTextureId'
            };

            if (options.customAttributes != null) {
                customAttributes = [];
                var rawAttributes:Array<Any> = options.customAttributes;
                for (i in 0...rawAttributes.length) {
                    var rawAttr:Dynamic = rawAttributes.unsafeGet(i);
                    customAttributes.push({
                        size: rawAttr.size,
                        name: rawAttr.name
                    });
                }
            }

            var loadOptions:AssetOptions = {};
            if (owner != null) {
                loadOptions.immediate = owner.immediate;
                loadOptions.loadMethod = owner.loadMethod;
            }

            shader = new Shader(baseAttributes, customAttributes, textureIdAttribute);
        }
        else {

            shader = Type.createInstance(shaderClass, []);
            baseAttributes = shader.baseAttributes;
            customAttributes = shader.customAttributes;
            textureIdAttribute = shader.textureIdAttribute;
        }

        var logName = path;
        if (logName.startsWith('shaders_')) {
            logName = logName.substr('shaders_'.length);
        }
        if (textureIdAttribute != null) {
            log.info('Load shader $logName (multi-texture)');
        }
        else {
            log.info('Load shader $logName');
        }

        // Shaders coming from a `shade` class are generated at build time into the
        // platform assets directory, so they must not be resolved against the watched
        // source assets directory that `watchDirectory()` installs as `runtimeAssets`.
        var shaderPath = transformedPath != null ?
            Path.join([transformedPath, path])
        :
            Assets.realAssetPath(path, shaderClass != null ? null : runtimeAssets);

        app.backend.shaders.load(shaderPath, baseAttributes, customAttributes, textureIdAttribute, function(backendItem) {

            if (backendItem == null) {
                status = BROKEN;
                if (shader != null) {
                    shader.destroy();
                    shader = null;
                }
                log.error('Failed to load shader at path: $path');
                emitComplete(false);
                return;
            }

            shader.backendItem = backendItem;

            var prevShader = this.shader;

            this.shader = shader;
            this.shader.asset = this;
            this.shader.id = 'shader:' + path;
            status = READY;
            emitComplete(true);

            if (prevShader != null) {
                prevShader.asset = null;
                prevShader.destroy();
            }

        });

    }

    override function assetFilesDidChange(newFiles:ReadOnlyMap<String, Float>, previousFiles:ReadOnlyMap<String, Float>):Void {

        if (!app.backend.shaders.supportsHotReloadPath())
            return;

        // Shaders built from a `shade` class have no source in the watched assets
        // directory: they are watched through their Haxe source instead,
        // see `Assets.watchShadeShaders()`.
        if (shaderClass != null)
            return;

        var basePath = Path.withoutExtension(path);

        for (extension in ['.vert', '.frag']) {
            var filePath = basePath + extension;

            var previousTime:Float = -1;
            if (previousFiles.exists(filePath)) {
                previousTime = previousFiles.get(filePath);
            }
            var newTime:Float = -1;
            if (newFiles.exists(filePath)) {
                newTime = newFiles.get(filePath);
            }

            if (newTime != previousTime) {
                log.info('Reload shader (file has changed)');
                load();
                return;
            }
        }

    }

    /**
     * Reload this shader from files that were just re-generated into `transformedDir`.
     * Used by `Assets.watchShadeShaders()` when a `shade` Haxe source changed.
     * @param transformedDir Directory holding the freshly transpiled `.vert`/`.frag`
     */
    @:noCompletion public function reloadFromTransformedDir(transformedDir:String):Void {

        transformedPath = transformedDir;
        log.info('Reload shader (shade source has changed)');
        load();

    }

    override function destroy():Void {

        super.destroy();

        if (shader != null) {
            shader.destroy();
            shader = null;
        }

    }

/// Print

    override function toString():String {

        var className = 'ShaderAsset';

        if (options.vertId != null || options.fragId != null) {
            var vertId = options.vertId != null ? options.vertId : 'default';
            var fragId = options.fragId != null ? options.fragId : 'default';
            return '$className($name $vertId $fragId)';
        }
        else if (path != null && path.trim() != '') {
            return '$className($name $path)';
        } else {
            return '$className($name)';
        }

    }

}
