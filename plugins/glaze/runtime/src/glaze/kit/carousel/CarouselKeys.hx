// Ported from gpui-kit 0.8.1: crates/component/src/carousel/mod.rs (`init`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.carousel;

import glaze.App;
import glaze.AppContext;
import glaze.KeyBinding;
import glaze.kit.base.Actions.SelectDown;
import glaze.kit.base.Actions.SelectFirst;
import glaze.kit.base.Actions.SelectLast;
import glaze.kit.base.Actions.SelectLeft;
import glaze.kit.base.Actions.SelectRight;
import glaze.kit.base.Actions.SelectUp;

/**
 * The key bindings of `Carousel` (Rust `carousel::init`), in a module of
 * their own so that the kit registers them at startup without loading the
 * carousel.
 */
class CarouselKeys {

    public static inline final CONTEXT:String = 'Carousel';

    /** Rust `carousel::init`: the navigation keys of the `Carousel` context. */
    public static function bindKeys(cx:AppContext):Void {
        (cx : App).bindKeys([
            new KeyBinding('left', new SelectLeft(), CONTEXT),
            new KeyBinding('right', new SelectRight(), CONTEXT),
            new KeyBinding('up', new SelectUp(), CONTEXT),
            new KeyBinding('down', new SelectDown(), CONTEXT),
            new KeyBinding('home', new SelectFirst(), CONTEXT),
            new KeyBinding('end', new SelectLast(), CONTEXT),
        ]);
    }

}
