// Ported from gpui-kit 0.8.1: crates/component/src/avatar/avatar.rs, crates/component/src/avatar/mod.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.avatar;

import gpui.App;
import gpui.Div;
import gpui.Hsla;
import gpui.IntoElement;
import gpui.IntoImageSource;
import gpui.ImageSource;
import gpui.Pixels;
import gpui.RenderOnce;
import gpui.StyleBuilder;
import gpui.StyleRefinement;
import gpui.Styled;
import gpui.Window;
import gpui.base.Avatar.AvatarFallback;
import gpui.base.Avatar.AvatarImage;
import gpui.base.FxHash;
import gpui.component.Icon;
import gpui.component.IconName;
import gpui.component.Sizable;
import gpui.component.Size;
import gpui.component.Size.IntoSize;
import gpui.component.theme.Color;
import gpui.component.theme.Theme;

import gpui.Prelude.*;

using gpui.base.StyledExt;
using gpui.component.ThemeStyled;

/**
 * Background, foreground and border of the initials of a named avatar,
 * picked from its initials' hash among 12 hues.
 */
class IdentityColor {

    public static inline final HUES:Int = 12;
    public static final HUE_STEP:Float = gpui.SpringMath.f32(360. / 12.);

    public final background:Hsla;
    public final foreground:Hsla;
    public final border:Hsla;

    function new(background:Hsla, foreground:Hsla, border:Hsla) {
        this.background = background;
        this.foreground = foreground;
        this.border = border;
    }

    public static function of(shortName:String, cx:App):IdentityColor {
        final hue = gpui.SpringMath.f32(FxHash.modulo(FxHash.hashString(shortName), HUES) * HUE_STEP);
        return fromHue(hue, Theme.global(cx).isDark());
    }

    public static function fromHue(hue:Float, isDark:Bool):IdentityColor {
        // Background and foreground hold WCAG AA against each other, and the
        // border carries the most chroma sRGB has at its lightness for every hue.
        return isDark
            ? new IdentityColor(Color.oklch(0.30, 0.05, hue), Color.oklch(0.82, 0.11, hue), Color.oklch(0.36, 0.06, hue))
            : new IdentityColor(Color.oklch(0.97, 0.032, hue), Color.oklch(0.50, 0.145, hue), Color.oklch(0.89, 0.05, hue));
    }

}

/**
 * Avatar sizes and text sizes (Rust `avatar/mod.rs`).
 */
class AvatarSizing {

    public static function avatarSize(size:Size):Pixels {
        return switch size {
            case Large: 80.;
            case Medium: 48.;
            case Small: 24.;
            case XSmall: 16.;
            case Size(value): value;
        }
    }

    /** Rust `AvatarSized::avatar_text_size`. */
    public static function avatarTextSize<T:Styled>(self:T, size:Size):T {
        final b = new StyleBuilder(self.style());
        switch size {
            case Large: b.text3xl().fontSemibold();
            case Medium: b.textSm();
            case Small: b.textXs();
            case XSmall: b.textSize(rems(0.65));
            case Size(value): b.size(gpui.Prelude.px(gpui.SpringMath.f32(value * 0.5)));
        }
        return self;
    }

}

/**
 * A user avatar: an image, the initials of a name on a color picked from
 * them, or a placeholder icon.
 */
class Avatar implements RenderOnce implements Styled implements Sizable {

    final base:gpui.base.Avatar = new gpui.base.Avatar();

    final avatarStyle:StyleRefinement = new StyleRefinement();

    var srcValue:Null<ImageSource> = null;

    @:allow(tests)
    var nameValue:Null<String> = null;

    @:allow(tests)
    var shortName:String = '';

    var placeholderValue:Icon = new Icon(IconName.User);

    @:allow(tests)
    var size:Size = Medium;

    public function new() {}

    /**
     * Set the image source of the avatar.
     */
    public function src(source:IntoImageSource):Avatar {
        srcValue = source;
        return this;
    }

    /**
     * Set the name of the avatar, shown as its initials without an image.
     */
    public function name(name:String):Avatar {
        nameValue = name;
        shortName = extractTextInitials(name);
        return this;
    }

    /**
     * Set the placeholder icon (default `IconName.User`).
     */
    public function placeholder(icon:IntoIcon):Avatar {
        placeholderValue = icon;
        return this;
    }

    public function withSize(size:IntoSize):Avatar {
        this.size = size;
        return this;
    }

    public inline function style():StyleRefinement {
        return avatarStyle;
    }

    public function render(window:Window, cx:App):IntoElement {
        final theme = Theme.global(cx);
        final innerStyle = new StyleRefinement();
        innerStyle.cornerRadiusTopLeft = avatarStyle.cornerRadiusTopLeft;
        innerStyle.cornerRadiusTopRight = avatarStyle.cornerRadiusTopRight;
        innerStyle.cornerRadiusBottomRight = avatarStyle.cornerRadiusBottomRight;
        innerStyle.cornerRadiusBottomLeft = avatarStyle.cornerRadiusBottomLeft;

        final identity = nameValue != null ? IdentityColor.of(shortName, cx) : null;

        // The tinted outline belongs to the initials. An image, or the anonymous
        // placeholder, keeps the neutral border.
        final borderColor = identity != null && srcValue == null ? identity.border : theme.border;

        final fallback = new AvatarFallback()
            .sizeFull()
            .flex()
            .itemsCenter()
            .justifyCenter()
            .roundedFullStyle(cx)
            .overflowHidden();
        if (identity == null) {
            fallback.textSize(gpui.Prelude.px(gpui.SpringMath.f32(AvatarSizing.avatarSize(size) * 0.6))).child(placeholderValue);
        }
        else {
            fallback.bg(identity.background)
                .textColor(identity.foreground)
                .child(AvatarSizing.avatarTextSize(div(), size).child(shortName));
        }
        fallback.refineStyle(innerStyle);

        base.size(AvatarSizing.avatarSize(size))
            .flexShrink0()
            .roundedFullStyle(cx)
            .overflowHidden()
            .bg(theme.tokens.secondary.background)
            .textColor(theme.background)
            .border1()
            .borderColor(borderColor)
            .fallback(fallback);
        if (srcValue != null) {
            base.image(
                new AvatarImage(srcValue)
                    .sizeFull()
                    .roundedFullStyle(cx)
                    .refineStyle(innerStyle)
            );
        }
        return base.refineStyle(avatarStyle);
    }

    /**
     * The (at most two) initials of a name, upper cased: the first letters
     * of its first two words, or its first two characters when it is one word.
     */
    @:allow(tests)
    static function extractTextInitials(text:String):String {
        final firsts:Array<String> = [];
        for (word in text.split(' ')) {
            if (firsts.length == 2)
                break;
            final first = firstChars(word, 1);
            if (first.length > 0)
                firsts.push(first);
        }
        var result = firsts.join('');
        if (haxe.io.Bytes.ofString(result).length == 1) {
            result = firstChars(text, 2);
        }
        return result.toUpperCase();
    }

    static function firstChars(text:String, count:Int):String {
        final buf = new StringBuf();
        var n = 0;
        for (c in new haxe.iterators.StringIteratorUnicode(text)) {
            if (n == count)
                break;
            buf.addChar(c);
            n++;
        }
        return buf.toString();
    }

}
