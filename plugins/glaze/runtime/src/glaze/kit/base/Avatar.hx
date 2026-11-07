// Ported from gpui-kit 0.8.1: crates/base/src/avatar.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base;

import glaze.AnyElement;
import glaze.App;
import glaze.Div;
import glaze.Img;
import glaze.IntoElement;
import glaze.IntoImageSource;
import glaze.ParentElement;
import glaze.RenderOnce;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;

import glaze.Prelude.*;

using glaze.kit.base.StyledExt;

/**
 * An unstyled avatar: shows its image slot, or its fallback when it has no
 * image.
 */
class Avatar implements RenderOnce implements Styled {

    /** The element the avatar renders (Rust delegates `InteractiveElement` to it). */
    public final base:Div = div();

    final avatarStyle:StyleRefinement = new StyleRefinement();

    var imageValue:Null<AvatarImage> = null;

    var fallbackValue:Null<AvatarFallback> = null;

    public function new() {}

    public function image(image:AvatarImage):Avatar {
        imageValue = image;
        return this;
    }

    public function fallback(fallback:AvatarFallback):Avatar {
        fallbackValue = fallback;
        return this;
    }

    public inline function style():StyleRefinement {
        return avatarStyle;
    }

    public function render(window:Window, cx:App):IntoElement {
        if (imageValue != null) {
            base.child(imageValue);
        }
        else if (fallbackValue != null) {
            base.child(fallbackValue);
        }
        return base.refineStyle(avatarStyle);
    }

}

/**
 * The image slot of an `Avatar`.
 */
class AvatarImage implements RenderOnce implements Styled {

    /** The image element (Rust delegates `InteractiveElement` to it). */
    public final image:Img;

    final imageStyle:StyleRefinement = new StyleRefinement();

    public function new(source:IntoImageSource) {
        image = img(source);
    }

    public inline function style():StyleRefinement {
        return imageStyle;
    }

    public function render(window:Window, cx:App):IntoElement {
        return image.refineStyle(imageStyle);
    }

}

/**
 * The fallback slot of an `Avatar`, shown without an image.
 */
class AvatarFallback implements RenderOnce implements Styled implements ParentElement {

    final base:Div = div();

    final fallbackStyle:StyleRefinement = new StyleRefinement();

    final childElements:Array<AnyElement> = [];

    public function new() {}

    public inline function style():StyleRefinement {
        return fallbackStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):AvatarFallback {
        if (child != null) childElements.push(child);
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        base.extend(childElements);
        return base.refineStyle(fallbackStyle);
    }

}
