package ceramic;

import ceramic.Shortcuts.*;

class ImageAsset extends Asset {

/// Properties

    public var pixels:Pixels = null;

    public var texture:Texture = null;

/// Lifecycle

    override public function new(name:String, ?options:AssetOptions) {

        super('image', name, options);
        handleTexturesDensityChange = true;

    } //name

    override public function load() {

        status = LOADING;

        if (path == null) {
            warning('Cannot load image asset if path is undefined.');
            status = BROKEN;
            emitComplete(false);
            return;
        }

        log('Load image $path');
        app.backend.images.load(path, {
        }, function(image) {

            if (image != null) {

                var prevTexture = this.texture;
                this.texture = new Texture(image, density);
                this.texture.id = 'texture:' + path;
                
                // Link the texture to this asset so that
                // destroying one will destroy the other
                this.texture.asset = this;

                if (prevTexture != null) {
                    // Texture was reloaded. Update related visuals
                    for (visual in [].concat(app.visuals)) {
                        if (visual.quad != null) {
                            var quad = visual.quad;
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
                        else if (visual.mesh != null) {
                            var mesh = visual.mesh;
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
                error('Failed to load texture at path: $path');
                emitComplete(false);
            }

        });

    } //load

    override function texturesDensityDidChange(newDensity:Float, prevDensity:Float):Void {

        if (status == READY) {
            // Only check if the asset is already loaded.
            // If it is currently loading, it will check
            // at load end anyway.
            checkTexturesDensity();
        }

    } //texturesDensityDidChange

    function checkTexturesDensity():Void {

        var prevPath = path;
        computePath();

        if (prevPath != path) {
            log('Reload texture ($prevPath -> $path)');
            load();
        }

    } //checkTexturesDensity

    function destroy():Void {

        if (texture != null) {
            texture.destroy();
            texture = null;
        }

    } //destroy

} //ImageAsset
