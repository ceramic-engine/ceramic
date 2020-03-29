package ceramic;

import ceramic.Shortcuts.*;

class ImageAsset extends Asset {

/// Events

    @event function replaceTexture(newTexture:Texture, prevTexture:Texture);

/// Properties

    public var pixels:Pixels = null;

    public var texture:Texture = null;

/// Internal

    @:allow(ceramic.Assets)
    var defaultImageOptions:AssetOptions = null;

/// Lifecycle

    override public function new(name:String, ?options:AssetOptions #if ceramic_debug_entity_allocs , ?pos:haxe.PosInfos #end) {

        super('image', name, options #if ceramic_debug_entity_allocs , pos #end);
        handleTexturesDensityChange = true;

    }

    override public function load() {

        status = LOADING;

        if (path == null) {
            log.warning('Cannot load image asset if path is undefined.');
            status = BROKEN;
            emitComplete(false);
            return;
        }

        var loadOptions:AssetOptions = {};
        if (defaultImageOptions != null) {
            for (key in Reflect.fields(defaultImageOptions)) {
                Reflect.setField(loadOptions, key, Reflect.field(defaultImageOptions, key));
            }
        }
        if (options != null) {
            for (key in Reflect.fields(options)) {
                Reflect.setField(loadOptions, key, Reflect.field(options, key));
            }
        }

        log.info('Load image $path (density=$density)');
        app.backend.textures.load(Assets.realAssetPath(path, runtimeAssets), loadOptions, function(image) {

            if (image != null) {

                var prevTexture = this.texture;
                this.texture = new Texture(image, density);
                this.texture.id = 'texture:' + path;
                
                // Link the texture to this asset so that
                // destroying one will destroy the other
                this.texture.asset = this;

                if (prevTexture != null) {

                    // Use same filter as previous texture
                    this.texture.filter = prevTexture.filter;

                    // When replacing the texture, emit an event to notify about it
                    emitReplaceTexture(this.texture, prevTexture);

                    // Texture was reloaded. Update related visuals
                    for (visual in [].concat(app.visuals)) {
                        if (visual.asQuad != null) {
                            var quad = visual.asQuad;
                            if (quad.texture == prevTexture) {

                                // Update texture but keep same frame
                                //
                                var frameX = quad.frameX;
                                var frameY = quad.frameY;
                                var frameWidth = quad.frameWidth;
                                var frameHeight = quad.frameHeight;

                                quad.texture = this.texture;

                                // Frame was reset by texture assign.
                                // Put it back to what it was.
                                quad.frameX = frameX;
                                quad.frameY = frameY;
                                quad.frameWidth = frameWidth;
                                quad.frameHeight = frameHeight;
                            }
                        }
                        else if (visual.asMesh != null) {
                            var mesh = visual.asMesh;
                            if (mesh.texture == prevTexture) {
                                mesh.texture = this.texture;
                            }
                        }
                    }

                    // Set asset to null because we don't want it
                    // to be destroyed when destroying the texture.
                    prevTexture.asset = null;
                    // Destroy texture
                    prevTexture.destroy();
                }

                status = READY;
                emitComplete(true);
                if (handleTexturesDensityChange) {
                    checkTexturesDensity();
                }
            }
            else {
                status = BROKEN;
                log.error('Failed to load texture at path: $path');
                emitComplete(false);
            }

        });

    }

    override function texturesDensityDidChange(newDensity:Float, prevDensity:Float):Void {

        if (status == READY) {
            // Only check if the asset is already loaded.
            // If it is currently loading, it will check
            // at load end anyway.
            checkTexturesDensity();
        }

    }

    function checkTexturesDensity():Void {

        var prevPath = path;
        computePath();

        if (prevPath != path) {
            log.info('Reload texture ($prevPath -> $path)');
            load();
        }

    }

    override function destroy():Void {

        super.destroy();

        if (texture != null) {
            texture.destroy();
            texture = null;
        }

    }

}
