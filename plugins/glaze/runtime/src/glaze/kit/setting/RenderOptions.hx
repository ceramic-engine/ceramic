// Ported from gpui-kit 0.8.1: crates/component/src/setting/settings.rs (RenderOptions)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.setting;

import glaze.Axis;
import glaze.kit.Size;
import glaze.kit.groupbox.GroupBox.GroupBoxVariant;

/**
 * Options for rendering setting item.
 *
 * The fields are private and reached through the methods below, so that a
 * new one can be added without breaking the item renderers. The options are
 * a value (Rust `Copy`): the setters return a narrowed copy, so a nested
 * renderer narrows a copy of its parent options:
 * `item.renderItem(options.withItemIx(itemIx), window, cx)`.
 */
class RenderOptions {

    var pageIxValue:Int = 0;

    var groupIxValue:Int = 0;

    var itemIxValue:Int = 0;

    var sizeValue:Size = Medium;

    var groupVariantValue:GroupBoxVariant = Normal;

    var layoutValue:Axis = Horizontal;

    var disabledValue:Bool = false;

    public function new() {}

    function copy():RenderOptions {
        final result = new RenderOptions();
        result.pageIxValue = pageIxValue;
        result.groupIxValue = groupIxValue;
        result.itemIxValue = itemIxValue;
        result.sizeValue = sizeValue;
        result.groupVariantValue = groupVariantValue;
        result.layoutValue = layoutValue;
        result.disabledValue = disabledValue;
        return result;
    }

    public function withPageIx(pageIx:Int):RenderOptions {
        final result = copy();
        result.pageIxValue = pageIx;
        return result;
    }

    public function withGroupIx(groupIx:Int):RenderOptions {
        final result = copy();
        result.groupIxValue = groupIx;
        return result;
    }

    public function withItemIx(itemIx:Int):RenderOptions {
        final result = copy();
        result.itemIxValue = itemIx;
        return result;
    }

    public function withSize(size:Size):RenderOptions {
        final result = copy();
        result.sizeValue = size;
        return result;
    }

    public function withGroupVariant(groupVariant:GroupBoxVariant):RenderOptions {
        final result = copy();
        result.groupVariantValue = groupVariant;
        return result;
    }

    public function withLayout(layout:Axis):RenderOptions {
        final result = copy();
        result.layoutValue = layout;
        return result;
    }

    public function withDisabled(disabled:Bool):RenderOptions {
        final result = copy();
        result.disabledValue = disabled;
        return result;
    }

    public function pageIx():Int {
        return pageIxValue;
    }

    public function groupIx():Int {
        return groupIxValue;
    }

    public function itemIx():Int {
        return itemIxValue;
    }

    public function size():Size {
        return sizeValue;
    }

    public function groupVariant():GroupBoxVariant {
        return groupVariantValue;
    }

    public function layout():Axis {
        return layoutValue;
    }

    public function isDisabled():Bool {
        return disabledValue;
    }

}
