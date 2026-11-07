// Ported from gpui-pre 0.3.10: src/elements/img.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

import gpui.ImageLoadResult;

/**
 * An image element. Create one with `Prelude.img(source)`.
 *
 * The source is loaded through the image cache of the element
 * (`imageCache()`), else the one of the closest `ImageCacheElement` ancestor,
 * else the app's asset cache. While it loads, the `withLoading` element is
 * shown once `LOADING_DELAY` has passed; if it fails, the `withFallback`
 * element. Without a size, the element takes the size of the image (and
 * keeps its aspect ratio when only one dimension is set).
 *
 * Interactive methods: the common subset of GPUI's `InteractiveElement`
 * (`id`, `hover`, `groupHover`, `active`, `onMouseDown`, `onMouseUp`,
 * `onClick`, `onHover`, `tooltip`, `occlude`); the others are reachable
 * through `interactivity`.
 */
class Img extends Element implements Styled {

    /** The delay before showing the loading state, in seconds. */
    public static inline final LOADING_DELAY:Float = 0.2;

    /** The interactivity of this element */
    public final interactivity:Interactivity = new Interactivity();

    final source:ImageSource;

    final imageStyle:ImageStyle = new ImageStyle();

    var imageCacheValue:Null<AnyImageCache> = null;

    /** Rust `ImgLayoutState` */
    var frameIndex:Int = 0;

    var replacement:Null<AnyElement> = null;

    var hitbox:Null<Hitbox> = null;

    public function new(source:ImageSource #if gpui_inspector , ?pos:haxe.PosInfos #end) {
        this.source = source;
        #if gpui_inspector
        interactivity.sourceLocation = pos;
        #end
    }

    #if gpui_inspector
    override function sourceLocation():Null<haxe.PosInfos> {
        return interactivity.sourceLocation;
    }
    #end

    public inline function style():StyleRefinement {
        return interactivity.baseStyle;
    }

    override function elementId():Null<ElementId> {
        return interactivity.elementId;
    }

    /**
     * A list of all format extensions supported by GPUI's img element (the
     * Ceramic port decodes the ones its backend supports, see `ImageAssetLoader`).
     */
    public static function extensions():Array<String> {
        return [
            "avif", "jpg", "jpeg", "png", "gif", "webp", "tif", "tiff", "tga", "dds", "bmp", "ico",
            "hdr", "exr", "pbm", "pam", "ppm", "pgm", "ff", "farbfeld", "qoi", "svg"
        ];
    }

    /**
     * Sets the image cache for the current node. Without it, the cache of the
     * closest `ImageCacheElement` ancestor is used, else the app's asset cache.
     */
    public function imageCache(imageCache:ImageCache):Img {
        imageCacheValue = new AnyImageCache(imageCache);
        return this;
    }

/// StyledImage

    /** Get the `ImageStyle` of the element. */
    public inline function getImageStyle():ImageStyle {
        return imageStyle;
    }

    /** Set the image to be displayed in grayscale. */
    public function grayscale(grayscale:Bool):Img {
        imageStyle.grayscale = grayscale;
        return this;
    }

    /** Set the object fit for the image. */
    public function objectFit(objectFit:ObjectFit):Img {
        imageStyle.objectFit = objectFit;
        return this;
    }

    /** Set a fallback function that will be invoked to render an error view should the image fail to load. */
    public function withFallback(fallback:() -> AnyElement):Img {
        imageStyle.fallback = fallback;
        return this;
    }

    /** Set a fallback function that will be invoked to render a view while the image is still being loaded. */
    public function withLoading(loading:() -> AnyElement):Img {
        imageStyle.loading = loading;
        return this;
    }

/// InteractiveElement subset

    public function id(id:ElementIdArg):Img {
        interactivity.elementId = id;
        return this;
    }

    public function group(group:String):Img {
        interactivity.group = group;
        return this;
    }

    public function hover(f:(StyleBuilder) -> StyleBuilder):Img {
        interactivity.hoverStyle = StyleBuilder.build(f);
        return this;
    }

    public function groupHover(groupName:String, f:(StyleBuilder) -> StyleBuilder):Img {
        interactivity.groupHoverStyle = new Interactivity.GroupStyle(groupName, StyleBuilder.build(f));
        return this;
    }

    public function active(f:(StyleBuilder) -> StyleBuilder):Img {
        interactivity.activeStyle = StyleBuilder.build(f);
        return this;
    }

    public function onMouseDown(button:MouseButton, listener:(MouseDownEvent, Window, App) -> Void):Img {
        interactivity.onMouseDown(button, listener);
        return this;
    }

    public function onMouseUp(button:MouseButton, listener:(MouseUpEvent, Window, App) -> Void):Img {
        interactivity.onMouseUp(button, listener);
        return this;
    }

    public function onClick(listener:(ClickEvent, Window, App) -> Void):Img {
        interactivity.onClick(listener);
        return this;
    }

    public function onAuxClick(listener:(ClickEvent, Window, App) -> Void):Img {
        interactivity.onAuxClick(listener);
        return this;
    }

    public function onHover(listener:(Bool, Window, App) -> Void):Img {
        interactivity.onHover(listener);
        return this;
    }

    public function tooltip(buildTooltip:(Window, App) -> AnyView):Img {
        interactivity.tooltip(buildTooltip);
        return this;
    }

    public function occlude():Img {
        interactivity.occludeMouse();
        return this;
    }

/// Element

    inline function currentImageCache(window:Window):Null<AnyImageCache> {
        if (imageCacheValue != null)
            return imageCacheValue;
        final stack = window.imageCacheStack;
        return stack.length > 0 ? stack[stack.length - 1] : null;
    }

    public function requestLayout(globalId:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        frameIndex = 0;
        replacement = null;

        return window.withOptionalElementState(globalId, ImgState, (box, window) -> {
            var state:Null<ImgState> = null;
            if (box != null) {
                if (box.value == null)
                    box.value = new ImgState();
                state = box.value;
            }

            var frameIndex = state != null ? state.frameIndex : 0;

            final layoutId = interactivity.requestLayout(globalId, #if gpui_inspector inspectorId, #end window, cx, (style, window, cx) -> {
                var replacementId:Null<LayoutId> = null;

                final data = source.useData(currentImageCache(window), window, cx);
                if (data != null) {
                    switch data {
                        case Loaded(data):
                            final frameCount = data.frameCount();
                            final maxFrameIndex = frameCount > 0 ? frameCount - 1 : 0;

                            if (state != null) {
                                state.frameIndex = state.frameIndex < maxFrameIndex ? state.frameIndex : maxFrameIndex;
                                if (frameCount > 1 && !cx.reduceMotion()) {
                                    if (window.isWindowActive()) {
                                        final currentTime = cx.backgroundExecutor().now();
                                        final lastFrameTime = state.lastFrameTime;
                                        if (lastFrameTime != null) {
                                            final elapsed = currentTime - lastFrameTime;
                                            final frameDuration = data.delay(state.frameIndex);

                                            if (elapsed >= frameDuration) {
                                                state.frameIndex = (state.frameIndex + 1) % frameCount;
                                                state.lastFrameTime = currentTime - (elapsed - frameDuration);
                                            }
                                        }
                                        else {
                                            state.lastFrameTime = currentTime;
                                        }
                                    }
                                    else {
                                        state.lastFrameTime = null;
                                    }
                                }
                                else {
                                    state.lastFrameTime = null;
                                }
                                state.clearLoading();
                                frameIndex = state.frameIndex;
                            }

                            final imageSize = data.renderSize(frameIndex);

                            // This style is changed below (GPUI gets its own copy):
                            // prepaint and paint compute theirs again
                            interactivity.forgetComputedStyle();

                            if (!style.isSome(StyleRefinement.ASPECT_RATIO)) {
                                style.aspectRatio = imageSize.width / imageSize.height;
                                style.optionMask |= StyleRefinement.ASPECT_RATIO;
                            }

                            if (style.sizeWidth == Length.Auto) {
                                style.sizeWidth = switch style.sizeHeight {
                                    case Definite(Absolute(absLength)):
                                        final heightPx:Float = absLength.toPixels(window.remSize());
                                        pixelsLength(imageSize.width * heightPx / imageSize.height);
                                    case _:
                                        pixelsLength(imageSize.width);
                                }
                            }

                            if (style.sizeHeight == Length.Auto) {
                                style.sizeHeight = switch style.sizeWidth {
                                    case Definite(Absolute(absLength)):
                                        final widthPx:Float = absLength.toPixels(window.remSize());
                                        pixelsLength(imageSize.height * widthPx / imageSize.width);
                                    case _:
                                        pixelsLength(imageSize.height);
                                }
                            }

                            if (globalId != null && data.frameCount() > 1 && window.isWindowActive() && !cx.reduceMotion()) {
                                window.requestAnimationFrame();
                            }

                        case Failed(_):
                            if (imageStyle.fallback != null) {
                                final element = imageStyle.fallback();
                                replacementId = element.requestLayout(window, cx);
                                replacement = element;
                            }
                            if (state != null) {
                                state.clearLoading();
                            }
                    }
                }
                else if (state != null) {
                    final startedLoading = state.startedLoading;
                    if (startedLoading != null) {
                        if (cx.backgroundExecutor().now() - startedLoading > LOADING_DELAY && imageStyle.loading != null) {
                            final element = imageStyle.loading();
                            replacementId = element.requestLayout(window, cx);
                            replacement = element;
                        }
                    }
                    else {
                        final currentView = window.currentView();
                        state.startedLoading = cx.backgroundExecutor().now();
                        state.startedLoadingTask = cx.backgroundExecutor().timer(LOADING_DELAY).then(_ -> {
                            cx.update(cx -> cx.notify(currentView));
                        });
                    }
                }

                return window.requestLayout(style, replacementId != null ? [replacementId] : null, cx);
            });

            this.frameIndex = frameIndex;
            return layoutId;
        });
    }

    static inline function pixelsLength(value:Float):Length {
        return Length.Definite(DefiniteLength.Absolute(AbsoluteLength.Pixels(value)));
    }

    public function prepaint(globalId:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        hitbox = interactivity.prepaint(globalId, #if gpui_inspector inspectorId, #end bounds, bounds.size, window, cx, (_, _, hitbox, window, cx) -> {
            if (replacement != null) {
                replacement.prepaint(window, cx);
            }
            return hitbox;
        });
    }

    public function paint(globalId:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        final hitbox = this.hitbox;
        this.hitbox = null;
        interactivity.paint(globalId, #if gpui_inspector inspectorId, #end bounds, hitbox, window, cx, (style, window, cx) -> {
            final data = source.useData(currentImageCache(window), window, cx).okOrNull();
            if (data != null) {
                if (data.frameCount() == 0)
                    return;
                final newBounds = imageStyle.objectFit.getBounds(bounds, data.size(frameIndex));
                final remSize = window.remSize();
                final cornerRadii = new Corners(
                    style.cornerRadiusTopLeft.toPixels(remSize),
                    style.cornerRadiusTopRight.toPixels(remSize),
                    style.cornerRadiusBottomRight.toPixels(remSize),
                    style.cornerRadiusBottomLeft.toPixels(remSize)
                );
                try {
                    window.paintImage(bounds, newBounds, cornerRadii, data, frameIndex, imageStyle.grayscale);
                }
                catch (e:Dynamic) {
                    ceramic.Shortcuts.log.error('Failed to paint image: $e');
                }
            }
            else if (replacement != null) {
                replacement.paint(window, cx);
            }
        });
    }

}

/**
 * The style of an image element.
 */
class ImageStyle {

    public var grayscale:Bool = false;

    public var objectFit:ObjectFit = ObjectFit.Contain;

    public var loading:Null<() -> AnyElement> = null;

    public var fallback:Null<() -> AnyElement> = null;

    public function new() {}

}

/**
 * The image state between frames (element state of an `img` with an id).
 */
class ImgState {

    public var frameIndex:Int = 0;

    /** In seconds (`BackgroundExecutor.now()`) */
    public var lastFrameTime:Null<Float> = null;

    /** In seconds (`BackgroundExecutor.now()`) */
    public var startedLoading:Null<Float> = null;

    public var startedLoadingTask:Null<AnyTask> = null;

    public function new() {}

    /** Rust `started_loading = None` (dropping the timer task cancels it). */
    public function clearLoading():Void {
        if (startedLoadingTask != null) {
            startedLoadingTask.cancel();
            startedLoadingTask = null;
        }
        startedLoading = null;
    }

}
