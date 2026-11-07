// Ported from gpui-kit 0.8.1: crates/base/src/observe.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base;

import glaze.Element;

/**
 * Registers an existing element for UI queries (`using glaze.kit.base.Observe;`).
 *
 * gpui-kit's `test-support` observation layer (UI queries by id, native
 * accessibility state) is not ported: `testSupport()` returns the element
 * unchanged, with its exact type, like a normal Rust build.
 */
class Observe {

    public static inline function testSupport<E:Element>(self:E):E {
        return self;
    }

}
