// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/indent.rs (`TabSize`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

import ropey.RopeSlice;

/**
 * The tab size of an input. Rust's `TabSize` is `Copy`: `copy()` stands for
 * the implicit copy.
 */
class TabSize {

    /** Default is 2 */
    public var tabSize:Int;

    /** Set true to use `\t` as tab indent, default is false */
    public var hardTabs:Bool;

    public function new(tabSize:Int = 2, hardTabs:Bool = false) {
        this.tabSize = tabSize;
        this.hardTabs = hardTabs;
    }

    public static inline function defaultValue():TabSize {
        return new TabSize(2, false);
    }

    public inline function copy():TabSize {
        return new TabSize(tabSize, hardTabs);
    }

    public inline function equals(other:TabSize):Bool {
        return other != null && tabSize == other.tabSize && hardTabs == other.hardTabs;
    }

    /** The text one indent level inserts. */
    public function toString():String {
        return hardTabs ? '\t' : StringTools.lpad('', ' ', tabSize);
    }

    /** Count the indent size of the line in spaces. */
    public function indentCount(line:RopeSlice):Int {
        var count = 0;
        for (ch in line.chars()) {
            if (ch == '\t'.code) {
                if (tabSize > 0)
                    count += tabSize - count % tabSize;
            }
            else if (ch == ' '.code) {
                count += 1;
            }
            else {
                break;
            }
        }
        return count;
    }

}
