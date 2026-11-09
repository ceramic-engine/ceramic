// Ported from gpui-kit 0.8.1: crates/base/src/avatar.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base;

import glaze.AnyElement;
import glaze.App;
import glaze.Component;
import glaze.Div;
import glaze.Img;
import glaze.IntoElement;
import glaze.IntoImageSource;
import glaze.ParentElement;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;

import glaze.Prelude.*;

using glaze.kit.base.StyledExt;

/**
 * An unstyled avatar: shows its image slot, or its fallback when it has no
 * image.
 */
class Avatar extends Component implements Styled {

    /** The element the avatar renders (Rust delegates `InteractiveElement` to it). */
    public final base:Div = div();

    final avatarStyle:StyleRefinement = new StyleRefinement();

    @prop var image:Null<AvatarImage> = null;

    @prop var fallback:Null<AvatarFallback> = null;

    public function new() {
        super();
    }

    public inline function style():StyleRefinement {
        return avatarStyle;
    }

    public function render(window:Window, cx:App):IntoElement {
        if (image != null) {
            base.child(image);
        }
        else if (fallback != null) {
            base.child(fallback);
        }
        return base.refineStyle(avatarStyle);
    }

}

/**
 * The image slot of an `Avatar`.
 */
class AvatarImage extends Component implements Styled {

    /** The image element (Rust delegates `InteractiveElement` to it). */
    public final image:Img;

    final imageStyle:StyleRefinement = new StyleRefinement();

    public function new(source:IntoImageSource) {
        super();
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
class AvatarFallback extends Component implements Styled implements ParentElement {

    final base:Div = div();

    final fallbackStyle:StyleRefinement = new StyleRefinement();

    final childElements:Array<AnyElement> = [];

    public function new() {
        super();
    }

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
