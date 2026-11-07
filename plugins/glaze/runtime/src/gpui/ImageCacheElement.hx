// Ported from gpui-pre 0.3.10: src/elements/image_cache.rs (ImageCacheElement)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * An image cache element: all its child `img` elements use the cache given
 * by its provider (unless they set their own). Create one with
 * `Prelude.imageCache(provider)`.
 */
class ImageCacheElement extends Element implements Styled implements ParentElement {

    final imageCacheProvider:ImageCacheProvider;

    final styleRefinement:StyleRefinement = new StyleRefinement();

    final childElements:Array<AnyElement> = [];

    public function new(imageCacheProvider:ImageCacheProvider) {
        this.imageCacheProvider = imageCacheProvider;
    }

    public inline function style():StyleRefinement {
        return styleRefinement;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) {
            childElements.push(element);
        }
    }

    /** Add a child element to this element. */
    public function child(child:IntoElement):ImageCacheElement {
        if (child != null) childElements.push(child);
        return this;
    }

    /** Add multiple child elements to this element. */
    public function children(children:Array<IntoElement>):ImageCacheElement {
        for (child in children) {
            if (child != null) childElements.push(child);
        }
        return this;
    }

    public function requestLayout(id:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        final imageCache = imageCacheProvider.provide(window, cx);
        return window.withImageCache(imageCache, window -> {
            final childLayoutIds = [for (child in childElements) child.requestLayout(window, cx)];
            final style = new Style();
            style.refine(styleRefinement);
            return window.requestLayout(style, childLayoutIds, cx);
        });
    }

    public function prepaint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        for (child in childElements) {
            child.prepaint(window, cx);
        }
    }

    public function paint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        final imageCache = imageCacheProvider.provide(window, cx);
        window.withImageCache(imageCache, window -> {
            for (child in childElements) {
                child.paint(window, cx);
            }
            return Unit.unit;
        });
    }

}
