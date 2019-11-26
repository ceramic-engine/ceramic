package ceramic;

import ceramic.Shortcuts.*;
import ceramic.Path;

using StringTools;
using ceramic.Extensions;

class ShaderAsset extends Asset {

    public var shader:Shader = null;

    override public function new(name:String, ?options:AssetOptions #if ceramic_debug_entity_allocs , ?pos:haxe.PosInfos #end) {

        super('shader', name, options #if ceramic_debug_entity_allocs , pos #end);

    } //name

    override public function load() {

        status = LOADING;

        if (path == null) {
            log.warning('Cannot load shader asset if path is undefined.');
            status = BROKEN;
            emitComplete(false);
            return;
        }
        
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
            log.info('Load shader' + (options.vertId != null ? ' ' + options.vertId : '') + (options.fragId != null ? ' ' + options.fragId : ''));
        }
        else {
            log.info('Load shader $path');
        }

        if (options.vertId == null) {
            status = BROKEN;
            log.error('Missing vertId option to load shader at path: $path');
            emitComplete(false);
            return;
        }

        if (options.fragId == null) {
            status = BROKEN;
            log.error('Missing fragId option to load shader at path: $path');
            emitComplete(false);
            return;
        }

        app.backend.texts.load(options.vertId, function(vertSource) {
            app.backend.texts.load(options.fragId, function(fragSource) {

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

                var customAttributes:Array<ShaderAttribute> = null;
                if (options.customAttributes != null) {
                    customAttributes = [];
                    var rawAttributes:Array<Dynamic> = options.customAttributes;
                    for (i in 0...rawAttributes.length) {
                        var rawAttr = rawAttributes.unsafeGet(i);
                        customAttributes.push({
                            size: rawAttr.size,
                            name: rawAttr.name
                        });
                    }
                }

                var backendItem = app.backend.shaders.fromSource(vertSource, fragSource, customAttributes);
                if (backendItem == null) {
                    status = BROKEN;
                    log.error('Failed to create shader from data at path: $path');
                    emitComplete(false);
                    return;
                }

                this.shader = new Shader(backendItem, customAttributes);
                this.shader.asset = this;
                this.shader.id = 'shader:' + path;
                status = READY;
                emitComplete(true);

            });
        });

    } //load

    override function destroy():Void {

        super.destroy();

        if (shader != null) {
            shader.destroy();
            shader = null;
        }

    } //destroy

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

    } //toString

} //ShaderAsset
