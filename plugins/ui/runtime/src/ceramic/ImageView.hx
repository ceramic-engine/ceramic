package ceramic;

import tracker.Autorun;
import tracker.Observable;

/**
 * A view component for displaying and laying out images with flexible scaling options.
 * 
 * ImageView provides automatic image loading from asset IDs and supports multiple
 * scaling modes to fit images within their container. It handles texture management
 * and cleanup automatically.
 * 
 * Features:
 * - Automatic asset loading from image paths or asset IDs
 * - Multiple scaling modes (FIT, FILL, CUSTOM)
 * - Proper texture lifecycle management
 * - Reactive updates when image or scaling properties change
 * 
 * ```haxe
 * var imageView = new ImageView();
 * imageView.size(200, 150);
 * imageView.image = "hero.png";
 * imageView.scaling = FIT; // Scale to fit within bounds
 * 
 * // Or use FILL to cover the entire area
 * imageView.scaling = FILL;
 * 
 * // Or use custom scaling
 * imageView.scaling = CUSTOM;
 * imageView.imageScale = 2.0;
 * ```
 * 
 * @see ImageViewScaling
 * @see View
 */
class ImageView extends View implements Observable {

/// Public properties

    /**
     * Custom scale factor for the image.
     * Only applied when scaling mode is set to CUSTOM.
     * Default is 1.0 (original size).
     */
    @observe public var imageScale:Float = 1.0;

    /**
     * Determines how the image is scaled within the view bounds.
     * - FIT: Scale to fit within bounds while maintaining aspect ratio
     * - FILL: Scale to fill the entire bounds, cropping if necessary
     * - CUSTOM: Use the imageScale value
     * Default is FIT.
     */
    @observe public var scaling:ImageViewScaling = ImageViewScaling.FIT;

    /**
     * The image to display, specified as an asset ID or path.
     * Setting this will automatically load the image texture.
     * Set to null to clear the image.
     */
    @observe public var image:AssetId<String> = null;

    /**
     * Whether the internal image quad inherits the view's alpha value.
     * When true, the image opacity is multiplied by the view's alpha.
     * Default follows the quad's inheritAlpha setting.
     */
    public var imageQuadInheritsAlpha(get, set):Bool;
    inline function get_imageQuadInheritsAlpha():Bool return imageQuad.inheritAlpha;
    inline function set_imageQuadInheritsAlpha(imageQuadInheritsAlpha:Bool):Bool {
        return imageQuad.inheritAlpha = imageQuadInheritsAlpha;
    }

/// Internal

    /**
     * The internal quad used to render the image texture.
     */
    var imageQuad:Quad = null;

    /**
     * The computed scale factor based on FIT scaling mode.
     */
    var computedImageScale:Float = 1.0;

    /**
     * Reference to the currently loaded texture for lifecycle management.
     */
    var loadedTexture:Texture = null;

/// Lifecycle

    /**
     * Creates a new ImageView with default settings.
     * The view is transparent by default and contains a centered image quad.
     */
    public function new() {

        super();

        transparent = true;

        imageQuad = new Quad();
        imageQuad.anchor(0.5, 0.5);
        imageQuad.depth = 1;
        add(imageQuad);

        autorun(updateImage);
        autorun(updateImageScale);

    }

    /**
     * Updates the image quad scale based on the current scaling mode.
     * Called automatically when scaling or imageScale properties change.
     */
    function updateImageScale() {

        var scaling = this.scaling;
        var imageScale = this.imageScale;

        var scale = switch (this.scaling) {
            case CUSTOM: imageScale;
            case FIT: computedImageScale;
            case FILL: 1.0;
        }

        Autorun.unobserve();

        imageQuad.scale(scale);

        Autorun.reobserve();

    }

    /**
     * Loads and sets the image texture based on the current image property.
     * Handles asset loading, texture management, and cleanup of previous textures.
     */
    function updateImage() {

        var image = this.image;

        Autorun.unobserve();

        if (image != null) {
            var assets = new Assets();
            assets.addImage(image);

            assets.onceComplete(this, function(isSuccess:Bool) {

                if (!isSuccess || image != this.image) {
                    assets.destroy();
                    assets = null;
                    return;
                }

                var texture = assets.texture(image);
                texture.onDestroy(assets, function(_) {
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

    }

    /**
     * Directly sets the image texture without going through asset loading.
     * Useful when you already have a texture reference.
     * Handles cleanup of previously loaded textures.
     * 
     * @param texture The texture to display, or null to clear
     */
    public function setImageTexture(texture:Texture):Void {

        if (imageQuad.texture == texture) return;

        if (loadedTexture != null && loadedTexture != texture) {
            loadedTexture.destroy();
            loadedTexture = null;
        }

        imageQuad.texture = texture;
        layoutDirty = true;

    }

    override function destroy() {

        super.destroy();

        if (imageQuad.texture != null && imageQuad.texture == loadedTexture) {
            imageQuad.texture.destroy();
            imageQuad.texture = null;
        }
        loadedTexture = null;

    }

/// Layout

    /**
     * Computes the view size based on the image dimensions and constraints.
     * Calculates the appropriate scale factor for FIT mode.
     */
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

    }

    /**
     * Positions and sizes the image quad within the view bounds.
     * Handles different scaling modes including cropping for FILL mode.
     */
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

    }

}
