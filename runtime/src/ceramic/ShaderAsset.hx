package ceramic;

import ceramic.Shortcuts.*;

import haxe.io.Path;

using StringTools;

class ShaderAsset extends Asset {

    public var shader:Shader = null;

    override public function new(name:String, ?options:AssetOptions) {

        super('shader', name, options);

    } //name

    override public function load() {

        status = LOADING;

        if (path == null) {
            warning('Cannot load shader asset if path is undefined.');
            status = BROKEN;
            emitComplete(false);
            return;
        }
        
        // Compute vertex and fragment shader paths
        if (path != null && (path.toLowerCase().endsWith('.frag') || path.toLowerCase().endsWith('.vert'))) {
            var paths = Assets.allByName.get(name);
            if (options.fragId == null) {
                for (path in paths) {
                    if (path.toLowerCase().endsWith('.frag')) {
                        options.fragId = path;
                        break;
                    }
                }
            }
            if (options.vertId == null) {
                for (path in paths) {
                    if (path.toLowerCase().endsWith('.vert')) {
                        options.vertId = path;
                        break;
                    }
                }
            }

            if (options.fragId != null || options.vertId != null) {
                path = Path.directory(path);
            }

            log('Load shader' + (options.vertId != null ? ' ' + options.vertId : '') + (options.fragId != null ? ' ' + options.fragId : ''));
        }
        else {
            log('Load shader $path');
        }

        app.backend.shaders.load(path, {
            fragId: options.fragId,
            vertId: options.vertId,
            noDefaultUniforms: options.noDefaultUniforms
        }, function(shader) {

            if (shader != null) {
                this.shader = new Shader(shader);
                this.shader.asset = this;
                status = READY;
                emitComplete(true);
            }
            else {
                status = BROKEN;
                error('Failed to load shader at path: $path');
                emitComplete(false);
            }

        });

    } //load

    function destroy():Void {

        if (shader != null) {
            shader.destroy();
            shader = null;
        }

    } //destroy

/// Print

    function toString():String {

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
