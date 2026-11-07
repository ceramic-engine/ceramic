// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/language_config.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

/**
 * Language indentation patterns.
 *
 * Applied on Enter: increase matches text before the caret; decrease matches text
 * after it. This does not reformat existing lines or indentation on paste.
 *
 * Rust uses the `regex` crate: the port takes Haxe `EReg`s, whose syntax
 * is the target's regular expressions (PCRE on native, JavaScript on web).
 * The common subset (classes, anchors, groups, alternations, quantifiers)
 * matches the same texts.
 */
class IndentationRules {

    public var increaseIndentPattern:Null<EReg>;

    public var decreaseIndentPattern:Null<EReg>;

    public function new(?increase:EReg, ?decrease:EReg) {
        this.increaseIndentPattern = increase;
        this.decreaseIndentPattern = decrease;
    }

}
