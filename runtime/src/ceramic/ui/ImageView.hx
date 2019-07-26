package ceramic.ui;

/** A view to display and layout images. */
class ImageView extends View implements Observable {

/// Public properties

    /** Image scale (ignored if `scaleToFit` is `true`) */
    @observe public var imageScale:Float = 1.0;

    /** If set to `true`, image will be scaled to fit the `ImageView` (and its paddings) */
    @observe public var scaleToFit:Bool = false;

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

        var scaleToFit = this.scaleToFit;
        var imageScale = this.imageScale;

        imageQuad.scale(scaleToFit ? computedImageScale : imageScale);

    } //updateImageScale

    function updateImage() {

        var image = this.image;

        unobserve();

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

        reobserve();

    } //updateImage

    public function setImageTexture(texture:Texture):Void {

        if (imageQuad.texture == texture) return;

        if (loadedTexture != null && loadedTexture != texture) {
            loadedTexture.destroy();
            loadedTexture = null;
        }

        imageQuad.texture = texture;
        layoutDirty = true;
        app.onceUpdate(this, function(_) {
            layoutDirty = true;
        });

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

        imageQuad.alpha = 0.5;

        trace(' - layout $width $height scale=${imageQuad.scaleX},${imageQuad.scaleY} size=${imageQuad.width},${imageQuad.height} pos=${imageQuad.x},${imageQuad.y}');

    } //layout

} //ImageView
