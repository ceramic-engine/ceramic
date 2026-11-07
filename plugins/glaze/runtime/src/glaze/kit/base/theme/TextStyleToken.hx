// Ported from gpui-kit 0.8.1: crates/base/src/theme_tokens.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.theme;

import glaze.FontWeight;
import glaze.Pixels;

/**
 * A text style of the typography scale.
 */
class TextStyleToken {

    public var size:Pixels;

    public var lineHeight:Pixels;

    public var weight:FontWeight;

    /**
     * Without arguments, the body text style, matching `TypographyTokens.md`.
     */
    public function new(size:Pixels = 16., lineHeight:Pixels = 24., weight:FontWeight = FontWeight.NORMAL) {

        this.size = size;
        this.lineHeight = lineHeight;
        this.weight = weight;

    }

    public function copy():TextStyleToken {

        return new TextStyleToken(size, lineHeight, weight);

    }

    public function equals(other:TextStyleToken):Bool {

        return other != null && size == other.size && lineHeight == other.lineHeight && weight == other.weight;

    }

}
