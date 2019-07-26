package ceramic.ui;

/** A view to display and layout images. */
class ImageView extends View implements Observable {

/// Public properties

    /** Image scale (ignored unless `scaling` is `CUSTOM`) */
    @observe public var imageScale:Float = 1.0;

    /** How the image is scaled depending on its constraints */
    @observe public var scaling:ImageViewScaling = ImageViewScaling.FIT;

    /** The actual image (as asset id or string) to display */
    @observe public var image:AssetId<String> = null;

/// Internal

    var imageQuad:Quad = null;

    var computedImageScale:Float = 1.0;

    var loadedTexture:Texture = null;

/// Lifecycle

    public function new() {

        super();

        transparent = true;

        imageQuad = new Quad();
        imageQuad.anchor(0.5, 0.5);
        imageQuad.transparent = false;
        imageQuad.color = Color.RED;
        imageQuad.depth = 1;
        add(imageQuad);

        autorun(updateImage);
        autorun(updateImageScale);

    } //new

    function updateImageScale() {

        var isAutoScaling = (this.scaling != ImageViewScaling.CUSTOM);
        var imageScale = this.imageScale;

        var scale = switch (this.scaling) {
            case CUSTOM: imageScale;
            case FIT: computedImageScale;
            case FILL: 1.0;
        }

        imageQuad.scale(scale);

    } //updateImageScale

    function updateImage() {

        var image = this.image;

        Autorun.unobserve();

        if (image != null) {
            var assets = new Assets();
            assets.addImage(image);
            
            assets.onceComplete(function(isSuccess:Bool) {
                
                if (!isSuccess || image != this.image) {
                    assets.destroy();
                    assets = null;
                    return;
                }

                var texture = assets.texture(image);
                texture.onDestroy(assets, function() {
                    assets.destroy();
                    assets = null;
                });

                setImageTexture(texture);
                loadedTexture = texture;

            });

            assets.load();
        }
        else {
            setImageTexture(null);
        }

        Autorun.reobserve();

    } //updateImage

    public function setImageTexture(texture:Texture):Void {

        if (imageQuad.texture == texture) return;

        if (loadedTexture != null && loadedTexture != texture) {
            loadedTexture.destroy();
            loadedTexture = null;
        }

        imageQuad.texture = texture;
        layoutDirty = true;

    } //setImageTexture

    override function destroy() {

        if (imageQuad.texture != null && imageQuad.texture == loadedTexture) {
            imageQuad.texture.destroy();
            imageQuad.texture = null;
        }
        loadedTexture = null;

    } //destroy

/// Layout

    override function computeSize(parentWidth:Float, parentHeight:Float, layoutMask:ViewLayoutMask, persist:Bool) {

        super.computeSize(parentWidth, parentHeight, layoutMask, persist);

        var texture = imageQuad.texture;

        if (texture != null) {
            computedImageScale = computeSizeWithIntrinsicBounds(
                parentWidth, parentHeight, layoutMask, persist, texture.width, texture.height
            );
        }
        else {
            computedImageScale = 1.0;
        }

        updateImageScale();

    } //computeSize

    override function layout() {

        var availableWidth = width - paddingLeft - paddingRight;
        var availableHeight = height - paddingTop - paddingBottom;

        imageQuad.pos(
            paddingLeft + availableWidth * 0.5,
            paddingTop + availableHeight * 0.5
        );

        if (imageQuad.texture != null) {
            switch (scaling) {
                case FILL:
                    var fillScale = Math.max(
                        availableWidth / imageQuad.texture.width,
                        availableHeight / imageQuad.texture.height
                    );
                    var textureScaledWidth = imageQuad.texture.width * fillScale;
                    var textureScaledHeight = imageQuad.texture.height * fillScale;
                    var hiddenLeft = (textureScaledWidth - availableWidth) * 0.5;
                    var hiddenTop = (textureScaledHeight - availableHeight) * 0.5;

                    imageQuad.size(
                        availableWidth,
                        availableHeight
                    );
                    imageQuad.frame(
                        hiddenLeft / fillScale,
                        hiddenTop / fillScale,
                        availableWidth / fillScale,
                        availableHeight / fillScale
                    );

                default:
                    imageQuad.size(
                        imageQuad.texture.width,
                        imageQuad.texture.height
                    );
                    imageQuad.frame(
                        0, 0,
                        imageQuad.texture.width,
                        imageQuad.texture.height
                    );
            }
        }

    } //layout

} //ImageView
