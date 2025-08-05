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

        var customAttributes:Array<ShaderAttribute> = null;
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

#if ceramic_shader_vert_frag
        // Compute vertex and fragment shader paths
        if (path != null && (path.toLowerCase().endsWith('.frag') || path.toLowerCase().endsWith('.vert'))) {
            var paths = Assets.allByName.get(name);
            if (options.fragId == null) {
                for (i in 0...paths.length) {
                    var path = paths.unsafeGet(i);
                    if (path.toLowerCase().endsWith('.frag')) {
                        options.fragId = path;
                        break;
                    }
                }
            }
            if (options.vertId == null) {
                for (i in 0...paths.length) {
                    var path = paths.unsafeGet(i);
                    if (path.toLowerCase().endsWith('.vert')) {
                        options.vertId = path;
                        break;
                    }
                }
            }
            // If no vertex shader is provided, use default (textured one)
            log.info('Load shader' + (options.vertId != null ? ' ' + options.vertId : '') + (options.fragId != null ? ' ' + options.fragId : ''));
        }
        else {
            log.info('Load shader $path');
        }

        if (options.vertId == null) {
            options.vertId = 'textured.vert';
        }

        if (options.fragId == null) {
            status = BROKEN;
            log.error('Missing fragId option to load shader at path: $path');
            emitComplete(false);
            return;
        }

        // Add reload count if any
        var vertPath = options.vertId;
        if (options.vertId != 'textured.vert') {
            vertPath = Assets.realAssetPath(options.vertId, runtimeAssets);
            var assetReloadedCount = Assets.getReloadCount(vertPath);
            if (app.backend.shaders.supportsHotReloadPath() && assetReloadedCount > 0) {
                vertPath += '?hot=' + assetReloadedCount;
            }
        }
        else {
            vertPath = Assets.realAssetPath(options.vertId, null);
        }
        var fragPath = Assets.realAssetPath(options.fragId, runtimeAssets);
        var assetReloadedCount = Assets.getReloadCount(fragPath);
        if (app.backend.shaders.supportsHotReloadPath() && assetReloadedCount > 0) {
            fragPath += '?hot=' + assetReloadedCount;
        }

        app.backend.texts.load(vertPath, loadOptions, function(vertSource) {
            app.backend.texts.load(fragPath, loadOptions, function(fragSource) {

                if (vertSource == null) {
                    status = BROKEN;
                    log.error('Failed to load ' + options.vertId + ' for shader at path: $path');
                    emitComplete(false);
                    return;
                }

                if (fragSource == null) {
                    status = BROKEN;
                    log.error('Failed to load ' + options.fragId + ' for shader at path: $path');
                    emitComplete(false);
                    return;
                }

                var backendItem = null;
                try {
                    backendItem = app.backend.shaders.fromSource(vertSource, fragSource, customAttributes);
                }
                catch (e:Dynamic) {
                    log.error('Error when creating shader from source: ' + e);
                }

                if (backendItem == null) {
                    status = BROKEN;
                    log.error('Failed to create shader from data at path: $path');
                    emitComplete(false);
                    return;
                }

                var shader = new Shader(backendItem, customAttributes);
                shader.asset = this;
                shader.id = 'shader:' + path;

                var prevShader = this.shader;

                this.shader = shader;
                status = READY;
                emitComplete(true);

                if (prevShader != null) {
                    prevShader.asset = null;
                    prevShader.destroy();
                    prevShader = null;
                }
            });
        });
#else
        app.backend.shaders.load(Assets.realAssetPath(path, runtimeAssets), customAttributes, function(backendItem) {

            if (backendItem == null) {
                status = BROKEN;
                log.error('Failed to load shader at path: $path');
                emitComplete(false);
                return;
            }

            this.shader = new Shader(backendItem, customAttributes);
            this.shader.asset = this;
            this.shader.id = 'shader:' + path;
            status = READY;
            emitComplete(true);

        });
#end

    }

    override function assetFilesDidChange(newFiles:ReadOnlyMap<String, Float>, previousFiles:ReadOnlyMap<String, Float>):Void {

        if (!app.backend.shaders.supportsHotReloadPath())
            return;

        #if ceramic_shader_vert_frag
        if (options != null) {
            if (options.fragId != null) {
                var path = options.fragId;
                var previousTime:Float = -1;
                if (previousFiles.exists(path)) {
                    previousTime = previousFiles.get(path);
                }
                var newTime:Float = -1;
                if (newFiles.exists(path)) {
                    newTime = newFiles.get(path);
                }

                if (newTime != previousTime) {
                    log.info('Reload shader (fragment shader has changed)');
                    load();
                }
            }
            else if (options.vertId != null) {
                var path = options.vertId;
                var previousTime:Float = -1;
                if (previousFiles.exists(path)) {
                    previousTime = previousFiles.get(path);
                }
                var newTime:Float = -1;
                if (newFiles.exists(path)) {
                    newTime = newFiles.get(path);
                }

                if (newTime != previousTime) {
                    log.info('Reload shader (vertex shader has changed)');
                    load();
                }
            }
        }
        #end

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
