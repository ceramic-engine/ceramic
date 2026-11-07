// Ported from gpui-kit 0.8.1: crates/component/src/avatar/avatar_group.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.avatar;

import glaze.App;
import glaze.Div;
import glaze.IntoElement;
import glaze.RenderOnce;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.Sizable;
import glaze.kit.Size;
import glaze.kit.Size.IntoSize;
import glaze.kit.avatar.Avatar.AvatarSizing;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;

using glaze.kit.base.StyledExt;

/**
 * A row of overlapping avatars, at most `limit` (3 by default), with an
 * optional ellipsis avatar when some are hidden.
 */
class AvatarGroup implements RenderOnce implements Styled implements Sizable {

    final base:Div = div();

    final groupStyle:StyleRefinement = new StyleRefinement();

    @:allow(tests)
    final avatars:Array<Avatar> = [];

    @:allow(tests)
    var size:Size = Medium;

    @:allow(tests)
    var limitValue:Int = 3;

    @:allow(tests)
    var ellipsisValue:Bool = false;

    public function new() {}

    public function child(avatar:Avatar):AvatarGroup {
        if (avatar != null) avatars.push(avatar);
        return this;
    }

    public function children(avatars:Array<Avatar>):AvatarGroup {
        for (avatar in avatars) if (avatar != null) this.avatars.push(avatar);
        return this;
    }

    /** Set the maximum number of avatars shown (default 3). */
    public function limit(limit:Int):AvatarGroup {
        limitValue = limit;
        return this;
    }

    /** Show an ellipsis avatar when some avatars are hidden. */
    public function ellipsis():AvatarGroup {
        ellipsisValue = true;
        return this;
    }

    public function withSize(size:IntoSize):AvatarGroup {
        this.size = size;
        return this;
    }

    public inline function style():StyleRefinement {
        return groupStyle;
    }

    public function render(window:Window, cx:App):IntoElement {
        final theme = Theme.global(cx);
        final itemMl:Float = -glaze.SpringMath.f32(AvatarSizing.avatarSize(size) * 0.3);
        final avatarsLen = avatars.length;

        base.hFlex().flexRowReverse().refineStyle(groupStyle);
        if (ellipsisValue && avatarsLen > limitValue) {
            base.child(
                new Avatar()
                    .name('⋯')
                    .bg(theme.tokens.secondary.background)
                    .textColor(theme.mutedForeground)
                    .withSize(size)
                    .ml1()
            );
        }
        final shown = avatars.slice(0, limitValue);
        var ix = shown.length - 1;
        while (ix >= 0) {
            final item = shown[ix].withSize(size);
            if (ix > 0) {
                item.ml(glaze.Prelude.px(itemMl));
            }
            base.child(item);
            ix--;
        }
        return base;
    }

}
