// Ported from gpui-kit 0.8.1: crates/component/src/table/loading.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.table;

import glaze.App;
import glaze.IntoElement;
import glaze.RenderOnce;
import glaze.Window;
import glaze.kit.Size;
import glaze.kit.skeleton.Skeleton;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;

using glaze.kit.Size.SizeTools;

/** The built-in skeleton loading view of a table. */
class Loading implements RenderOnce {

    var sizeValue:Size = Medium;

    public function new() {}

    public function size(size:Size):Loading {
        sizeValue = size;
        return this;
    }

    public function render(_:Window, _:App):IntoElement {
        return vFlex()
            .gap0()
            .child(LoadingRow.header().size(sizeValue))
            .child(LoadingRow.row().size(sizeValue))
            .child(LoadingRow.row().size(sizeValue))
            .child(LoadingRow.row().size(sizeValue))
            .child(LoadingRow.row().size(sizeValue));
    }

}

private class LoadingRow implements RenderOnce {

    final isHeader:Bool;

    var sizeValue:Size = Medium;

    function new(header:Bool) {
        this.isHeader = header;
    }

    public static function header():LoadingRow {
        return new LoadingRow(true);
    }

    public static function row():LoadingRow {
        return new LoadingRow(false);
    }

    public function size(size:Size):LoadingRow {
        sizeValue = size;
        return this;
    }

    function skeleton(height:Float, width:(Skeleton) -> Skeleton):Skeleton {
        final skeleton = new Skeleton();
        if (isHeader) skeleton.secondary();
        return width(skeleton.h(px(height)));
    }

    public function render(_:Window, cx:App):IntoElement {
        final theme = Theme.global(cx);
        final paddings = sizeValue.tableCellPadding();
        final height:Float = sizeValue.tableRowHeight() * 0.5;

        final row = hFlex()
            .gap3()
            .h(px(sizeValue.tableRowHeight()))
            .overflowHidden()
            .pt(px(paddings.top))
            .pb(px(paddings.bottom))
            .pl(px(paddings.left))
            .pr(px(paddings.right))
            .itemsCenter()
            .justifyBetween()
            .overflowHidden();
        if (isHeader) row.bg(theme.tokens.tableHead.background);
        if (!isHeader) row.borderT1().borderColor(theme.tableRowBorder);
        return row
            .child(hFlex()
                .gap3()
                .flex1()
                .child(skeleton(height, s -> s.w24()))
                .child(skeleton(height, s -> s.w48()))
                .child(skeleton(height, s -> s.w16())))
            .child(skeleton(height, s -> s.w24()));
    }

}
