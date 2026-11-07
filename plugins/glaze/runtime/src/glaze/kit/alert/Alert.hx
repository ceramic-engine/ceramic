// Ported from gpui-kit 0.8.1: crates/component/src/alert.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.alert;

import glaze.App;
import glaze.ClickEvent;
import glaze.ElementId;
import glaze.ElementIdArg;
import glaze.Hsla;
import glaze.IntoElement;
import glaze.Pixels;
import glaze.RenderOnce;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.base.A11y;
import glaze.kit.Icon;
import glaze.kit.IconName;
import glaze.kit.Sizable;
import glaze.kit.Size;
import glaze.kit.Size.IntoSize;
import glaze.kit.text.Text;
import glaze.kit.text.TextViewStyle;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;

using glaze.kit.base.StyledExt;
using glaze.kit.Size.SizeTools;
using glaze.kit.theme.Colorize;

/**
 * The color scheme of an `Alert`.
 */
enum abstract AlertVariant(Int) {

    var Default;
    var Info;
    var Success;
    var Warning;
    var Error;

    public function fg(cx:App):Hsla {
        final theme = Theme.global(cx);
        return switch (cast this : AlertVariant) {
            case Default: theme.foreground;
            case Info: theme.info;
            case Success: theme.success;
            case Warning: theme.warning;
            case Error: theme.danger;
        }
    }

    public function bg(cx:App):Hsla {
        final theme = Theme.global(cx);
        return switch (cast this : AlertVariant) {
            case Default: theme.background;
            case Info: theme.info.mixOklab(transparentWhite(), 0.04);
            case Success: theme.success.mixOklab(transparentWhite(), 0.04);
            case Warning: theme.warning.mixOklab(transparentWhite(), 0.04);
            case Error: theme.danger.mixOklab(transparentWhite(), 0.04);
        }
    }

    public function borderColor(cx:App):Hsla {
        final theme = Theme.global(cx);
        return switch (cast this : AlertVariant) {
            case Default: theme.border;
            case Info: theme.info.mixOklab(transparentWhite(), 0.3);
            case Success: theme.success.mixOklab(transparentWhite(), 0.3);
            case Warning: theme.warning.mixOklab(transparentWhite(), 0.3);
            case Error: theme.danger.mixOklab(transparentWhite(), 0.3);
        }
    }

}

/**
 * An alert: an icon, an optional title and a message, in a color variant,
 * optionally closable.
 */
class Alert implements RenderOnce implements Styled implements Sizable {

    final id:ElementId;

    final alertStyle:StyleRefinement = new StyleRefinement();

    var variant:AlertVariant = Default;

    var iconValue:Icon = new Icon(IconName.Info);

    var titleValue:Null<String> = null;

    final message:Text;

    var size:Size = Medium;

    var bannerValue:Bool = false;

    var onCloseHandler:Null<(ClickEvent, Window, App) -> Void> = null;

    var visibleValue:Bool = true;

    /** The accessibility properties the alert exports. */
    public final a11y:A11y = new A11y(Role.Alert);

    public function new(id:ElementIdArg, message:IntoText) {
        this.id = id;
        this.message = message;
    }

    public static function info(id:ElementIdArg, message:IntoText):Alert {
        return new Alert(id, message).withVariant(Info).icon(IconName.Info);
    }

    public static function success(id:ElementIdArg, message:IntoText):Alert {
        return new Alert(id, message).withVariant(Success).icon(IconName.CircleCheck);
    }

    public static function warning(id:ElementIdArg, message:IntoText):Alert {
        return new Alert(id, message).withVariant(Warning).icon(IconName.TriangleAlert);
    }

    public static function error(id:ElementIdArg, message:IntoText):Alert {
        return new Alert(id, message).withVariant(Error).icon(IconName.CircleX);
    }

    public function withVariant(variant:AlertVariant):Alert {
        this.variant = variant;
        return this;
    }

    public function icon(icon:IntoIcon):Alert {
        iconValue = icon;
        return this;
    }

    public function title(title:String):Alert {
        titleValue = title;
        return this;
    }

    /** Use the banner style: full width, no rounded corners, centered row. */
    public function banner():Alert {
        bannerValue = true;
        return this;
    }

    public function visible(visible:Bool):Alert {
        visibleValue = visible;
        return this;
    }

    /** Show a close button calling `onClose`. */
    public function onClose(onClose:(ClickEvent, Window, App) -> Void):Alert {
        onCloseHandler = onClose;
        return this;
    }

    public function withSize(size:IntoSize):Alert {
        this.size = size;
        return this;
    }

    public inline function style():StyleRefinement {
        return alertStyle;
    }

    public function render(window:Window, cx:App):IntoElement {
        if (!visibleValue) {
            return new glaze.Empty();
        }

        final theme = Theme.global(cx);
        final metrics:Array<Pixels> = switch size {
            case XSmall: [theme.radius, 12., 6., 6.];
            case Small: [theme.radius, 12., 8., 6.];
            case Large: [theme.radiusLg, 20., 14., 12.];
            case _: [theme.radius, 16., 10., 12.];
        };
        final radius = metrics[0];
        final paddingX = metrics[1];
        final paddingY = metrics[2];
        final gap = metrics[3];

        final bg = variant.bg(cx);
        final fg = variant.fg(cx);
        final borderColor = variant.borderColor(cx);
        final banner = bannerValue;

        final iconSlot = div();
        if (!banner) iconSlot.mt(glaze.Prelude.px(5.));
        iconSlot.child(iconValue);

        final body = div().flex1().overflowHidden().gap3();
        if (!banner && titleValue != null) {
            body.child(div().wFull().truncate().fontSemibold().child(titleValue));
        }
        body.child(message.style(TextViewStyle.defaultValue().withParagraphGap(0.2)).intoAnyElement());

        final content = div().flex().flex1();
        if (banner) content.itemsCenter();
        content.overflowHidden().gap(glaze.Prelude.px(gap)).child(iconSlot).child(body);

        final element = glaze.kit.base.Prelude.hFlex()
            .id(id)
            .wFull()
            .textColor(fg)
            .bg(bg)
            .px(glaze.Prelude.px(paddingX))
            .py(glaze.Prelude.px(paddingY))
            .gap(glaze.Prelude.px(gap))
            .justifyBetween()
            .textSm()
            .border1()
            .borderColor(borderColor);
        if (!banner) {
            element.rounded(radius).itemsStart();
        }
        element.refineStyle(alertStyle).child(content);

        if (onCloseHandler != null) {
            final onClose = onCloseHandler;
            element.child(
                div()
                    .id('close')
                    .p0p5()
                    .rounded(theme.radius)
                    .hover(s -> s.bg(bg.opacity(0.8)))
                    .active(s -> s.bg(bg.opacity(0.9)))
                    .onClick((ev, window, cx) -> onClose(ev, window, cx))
                    .child(new Icon(IconName.Close).withSize(size.max(Medium)).flexShrink0())
            );
        }
        return element;
    }

}
