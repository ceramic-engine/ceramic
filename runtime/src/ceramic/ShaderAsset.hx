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

        app.backend.shaders.load(Assets.realAssetPath(path, runtimeAssets), baseAttributes, customAttributes, textureIdAttribute, function(backendItem) {

            if (backendItem == null) {
                status = BROKEN;
                shader.destroy();
                shader = null;
                log.error('Failed to load shader at path: $path');
                emitComplete(false);
                return;
            }

            shader.backendItem = backendItem;

            this.shader = shader;
            this.shader.asset = this;
            this.shader.id = 'shader:' + path;
            status = READY;
            emitComplete(true);

        });

    }

    override function assetFilesDidChange(newFiles:ReadOnlyMap<String, Float>, previousFiles:ReadOnlyMap<String, Float>):Void {

        if (!app.backend.shaders.supportsHotReloadPath())
            return;

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
