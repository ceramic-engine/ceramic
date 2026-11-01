// Ported from gpui-kit 0.8.1: crates/component/src/sheet.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.sheet;

import gpui.AbsoluteLength;
import gpui.Animation;
import gpui.AnyElement;
import gpui.App;
import gpui.AppContext;
import gpui.ClickEvent;
import gpui.DefiniteLength;
import gpui.DefiniteLengthTools;
import gpui.Edges;
import gpui.FocusHandle;
import gpui.IntoDefiniteLength;
import gpui.IntoElement;
import gpui.ParentElement;
import gpui.Pixels;
import gpui.RenderOnce;
import gpui.SpringMath.f32;
import gpui.StyleRefinement;
import gpui.Styled;
import gpui.Window;
import gpui.base.Actions.Cancel;
import gpui.base.Geometry.Placement;
import gpui.component.IconName;
import gpui.component.TitleBar;
import gpui.component.WindowBorder;
import gpui.component.button.Button;
import gpui.component.dialog.Dialog;
import gpui.component.theme.Theme;

import gpui.Prelude.*;
import gpui.base.Prelude.*;

using gpui.base.Observe;
using gpui.base.StyledExt;
using gpui.component.WindowExt;
using gpui.component.scroll.Scrollable;

/**
 * The settings for sheets (the theme's `sheet`).
 */
class SheetSettings {

    /** The margin top for the sheet, default is `TitleBar.TITLE_BAR_HEIGHT`. */
    public var marginTop:Pixels = TitleBar.TITLE_BAR_HEIGHT;

    public function new() {}

    public function copy():SheetSettings {
        final settings = new SheetSettings();
        settings.marginTop = marginTop;
        return settings;
    }

}

/**
 * Sheet component that slides in from the side of the window.
 *
 * Rust's `EventEmitter<DismissEvent>` declaration is kept as a comment: a
 * `Sheet` is a `RenderOnce`, not an entity, so it never emits.
 */
@:allow(gpui.component, tests)
class Sheet implements RenderOnce implements Styled implements ParentElement {

    var focusHandle:FocusHandle;

    var placement:Placement = Right;

    var sizeValue:DefiniteLength = DefiniteLength.Absolute(AbsoluteLength.Pixels(350.));

    var selectionScope:gpui.base.TextSelectionScopeId = gpui.base.TextSelectionScopeId.DEFAULT;

    var resizableValue:Bool = true;

    var onCloseHandler:(ClickEvent, Window, App) -> Void = (_, _, _) -> {};

    var titleElement:Null<AnyElement> = null;

    var footerElement:Null<AnyElement> = null;

    final sheetStyle:StyleRefinement = new StyleRefinement();

    final childElements:Array<AnyElement> = [];

    var overlayValue:Bool = true;

    var overlayClosableValue:Bool = true;

    /** Rust `init` registers nothing. */
    public static function init(_:AppContext):Void {}

    /**
     * Creates a new Sheet.
     */
    public function new(_:Window, cx:App) {
        focusHandle = cx.focusHandle();
    }

    public inline function style():StyleRefinement {
        return sheetStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):Sheet {
        childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):Sheet {
        for (child in children) childElements.push(child);
        return this;
    }

    /** Sets the title of the sheet. */
    public function title(title:IntoElement):Sheet {
        titleElement = title;
        return this;
    }

    /** Set the footer of the sheet. */
    public function footer(footer:IntoElement):Sheet {
        footerElement = footer;
        return this;
    }

    /**
     * Sets the size of the sheet, default is 350px (shadows `Styled.size`,
     * like Rust).
     */
    public function size(size:IntoDefiniteLength):Sheet {
        this.sizeValue = size;
        return this;
    }

    /** Sets whether the sheet is resizable, default is `true`. */
    public function resizable(resizable:Bool):Sheet {
        resizableValue = resizable;
        return this;
    }

    /** Set whether the sheet should have an overlay, default is `true`. */
    public function overlay(overlay:Bool):Sheet {
        overlayValue = overlay;
        return this;
    }

    /** Set whether the sheet should be closable by clicking the overlay, default is `true`. */
    public function overlayClosable(overlayClosable:Bool):Sheet {
        overlayClosableValue = overlayClosable;
        return this;
    }

    /** Listen to the close event of the sheet. */
    public function onClose(onClose:(ClickEvent, Window, App) -> Void):Sheet {
        onCloseHandler = onClose;
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        final placement = this.placement;
        final theme = Theme.global(cx);
        final contentInsets = WindowBorder.windowContentInsets(window);
        final safeInsets = WindowBorder.windowSafeInsets(window);
        final frameTop = Math.max(contentInsets.top, safeInsets.top);
        final frameRight = Math.max(contentInsets.right, safeInsets.right);
        final frameBottom = Math.max(contentInsets.bottom, safeInsets.bottom);
        final frameLeft = Math.max(contentInsets.left, safeInsets.left);
        final viewport = window.viewportSize();
        final sizeWidth:Float = viewport.width - (frameLeft + frameRight);
        final sizeHeight:Float = viewport.height - (frameTop + frameBottom);
        final top = theme.sheet.marginTop;
        final baseSize = window.textStyle().fontSize;
        final remSize = window.remSize();
        var paddingLeft:Float = 16.;
        var paddingRight:Float = 16.;
        if (sheetStyle.paddingLeft != null) {
            paddingLeft = DefiniteLengthTools.toPixels(sheetStyle.paddingLeft, baseSize, remSize);
        }
        if (sheetStyle.paddingRight != null) {
            paddingRight = DefiniteLengthTools.toPixels(sheetStyle.paddingRight, baseSize, remSize);
        }
        // Rust also resolves the top and bottom paddings, which it does not use.

        final overlay = div()
            .occlude()
            .w(gpui.Prelude.px(sizeWidth))
            .h(gpui.Prelude.px(sizeHeight))
            .bg(@:privateAccess Dialog.overlayColor(overlayValue, cx));

        final surface = vFlex()
            .id('sheet-content')
            .testSupport()
            .absolute()
            .occlude()
            .bg(theme.tokens.background.background)
            .borderColor(theme.border)
            .shadowXl()
            .refineStyle(sheetStyle);
        // Set the size of the sheet.
        if (placement.isHorizontal()) {
            surface.w(sizeValue);
        }
        else {
            surface.h(sizeValue);
        }
        switch placement {
            case Top: surface.top(top).left0().right0().borderB1();
            case Right: surface.top(top).right0().bottom0().borderL1();
            case Bottom: surface.bottom0().left0().right0().borderT1();
            case Left: surface.top(top).left0().bottom0().borderR1();
        }
        // Body
        final body = vFlex()
            .sizeFull()
            .overflowYScrollbar()
            .pl(gpui.Prelude.px(paddingLeft))
            .pr(gpui.Prelude.px(paddingRight));
        body.extend(childElements);
        surface
            .child(
                // TitleBar
                hFlex()
                    .justifyBetween()
                    .pl4()
                    .pr3()
                    .py2()
                    .wFull()
                    .fontSemibold()
                    .child(titleElement != null ? titleElement : div())
                    .child(new Button('close')
                        .small()
                        .ghost()
                        .icon(IconName.Close)
                        .onClick((_, window, cx) -> window.dispatchAction(new Cancel(), cx)))
            )
            .child(div().flex1().overflowHidden().child(body));
        if (footerElement != null) {
            // Footer
            surface.child(hFlex()
                .justifyBetween()
                .px4()
                .py3()
                .wFull()
                .child(footerElement));
        }
        final animated = surface.withAnimation('slide', new Animation(0.15), (element, delta) -> {
            final y = f32(-100. + f32(delta * 100.));
            return switch placement {
                case Top: element.top(gpui.Prelude.px(f32(top + y)));
                case Right: element.right(gpui.Prelude.px(y));
                case Bottom: element.bottom(gpui.Prelude.px(y));
                case Left: element.left(gpui.Prelude.px(y));
            }
        });
        final scopedSurface = gpui.base.TextSelection.textSelectionScope(selectionScope, animated);

        final onClose = onCloseHandler;
        return new gpui.base.Sheet(cx)
            .top(gpui.Prelude.px(frameTop))
            .left(gpui.Prelude.px(frameLeft))
            .w(gpui.Prelude.px(sizeWidth))
            .h(gpui.Prelude.px(sizeHeight))
            .focusHandle(focusHandle)
            .overlayInteractive(overlayValue)
            .overlayClosable(overlayValue && overlayClosableValue)
            .requestClose((window, cx) -> window.closeSheet(cx))
            .onClose((event, window, cx) -> onClose(event, window, cx))
            .overlay(overlay)
            .surface(scopedSurface);
    }

}
