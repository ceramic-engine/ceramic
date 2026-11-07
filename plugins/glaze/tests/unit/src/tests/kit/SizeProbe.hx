// Ported from gpui-kit 0.8.1: crates/component/src/toolbar.rs (tests: SizeProbe)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.App;
import glaze.IntoElement;
import glaze.RenderOnce;
import glaze.Window;
import glaze.kit.Sizable;
import glaze.kit.Size;

import glaze.Prelude.*;

/**
 * Records the size a toolbar gives it.
 */
class SizeProbe implements RenderOnce implements Sizable {

    final observed:Array<Null<Size>>;

    final index:Int;

    var size:Size = Medium;

    public function new(observed:Array<Null<Size>>, index:Int) {
        this.observed = observed;
        this.index = index;
    }

    public function withSize(size:glaze.kit.Size.IntoSize):SizeProbe {
        this.size = size;
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        observed[index] = size;
        return div();
    }

}
