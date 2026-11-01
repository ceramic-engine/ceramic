// Ported from gpui-kit 0.8.1: crates/base/src/sheet.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base;

import gpui.AnyElement;
import gpui.App;
import gpui.AppContext;
import gpui.ClickEvent;
import gpui.Div;
import gpui.FocusHandle;
import gpui.IntoElement;
import gpui.KeyBinding;
import gpui.MouseButton;
import gpui.Pixels;
import gpui.RenderOnce;
import gpui.StyleRefinement;
import gpui.Styled;
import gpui.Window;
import gpui.base.Actions.Cancel;
import gpui.base.Dialog.DialogKeys;

import gpui.Prelude.*;

using gpui.base.FocusTrap;
using gpui.base.Observe;
using gpui.base.StyledExt;

private typedef CloseHandler = (ClickEvent, Window, App) -> Void;
private typedef CloseRequest = (Window, App) -> Void;

/**
 * An unstyled modal sheet host.
 *
 * Applications provide the overlay and surface. The host owns focus trapping,
 * Escape handling, overlay dismissal, and close callback ordering.
 */
class Sheet implements RenderOnce implements Styled {

    static inline final CONTEXT = 'Sheet';

    final base:Div = div();

    final sheetStyle:StyleRefinement = new StyleRefinement();

    var focus:FocusHandle;

    var overlayInteractiveValue:Bool = true;

    var overlayClosableValue:Bool = true;

    var dismissBeforeYValue:Null<Pixels> = null;

    var overlayElement:Null<AnyElement> = null;

    var surfaceElement:Null<AnyElement> = null;

    var requestCloseHandler:CloseRequest = (_, _) -> {};

    var onCloseHandler:CloseHandler = (_, _, _) -> {};

    public static function init(cx:AppContext):Void {
        (cx:App).bindKeys([new KeyBinding('escape', new Cancel(), CONTEXT)]);
    }

    static function close(request:CloseRequest, notify:CloseHandler, window:Window, cx:App):Void {
        final event = DialogKeys.defaultClickEvent();
        request(window, cx);
        notify(event, window, cx);
    }

    public function new(cx:App) {
        this.focus = cx.focusHandle();
    }

    public inline function style():StyleRefinement {
        return sheetStyle;
    }

    public function overlay(overlay:IntoElement):Sheet {
        overlayElement = overlay;
        return this;
    }

    public function surface(surface:IntoElement):Sheet {
        surfaceElement = surface;
        return this;
    }

    public function overlayClosable(closable:Bool):Sheet {
        overlayClosableValue = closable;
        return this;
    }

    /** Hidden in the Rust docs. */
    public function overlayInteractive(interactive:Bool):Sheet {
        overlayInteractiveValue = interactive;
        return this;
    }

    public function onClose(handler:(ClickEvent, Window, App) -> Void):Sheet {
        onCloseHandler = handler;
        return this;
    }

    /** Hidden in the Rust docs. */
    public function focusHandle(focus:FocusHandle):Sheet {
        this.focus = focus;
        return this;
    }

    /** Hidden in the Rust docs. */
    public function dismissBeforeY(y:Pixels):Sheet {
        dismissBeforeYValue = y;
        return this;
    }

    /** Hidden in the Rust docs. */
    public function requestClose(handler:(Window, App) -> Void):Sheet {
        requestCloseHandler = handler;
        return this;
    }

    public function render(window:Window, _:App):IntoElement {
        final viewport = window.viewportSize();
        final requestClose = requestCloseHandler;
        final onClose = onCloseHandler;
        final escapeRequest = requestClose;
        final escapeNotify = onClose;

        final host = base
            .id('sheet-host')
            .testSupport()
            .absolute()
            .top0()
            .left0()
            .w(gpui.Prelude.px(viewport.width))
            .h(gpui.Prelude.px(viewport.height))
            .keyContext(CONTEXT)
            .trackFocus(focus);
        final container = host.focusTrap('sheet', focus);
        // FocusTrapContainer delegates its interactivity to the wrapped Div.
        final trapped = container.base;
        trapped.onAction(Cancel, (_, window, cx) -> {
            cx.propagate();
            close(escapeRequest, escapeNotify, window, cx);
        });
        if (overlayElement != null) {
            final dismissBeforeY = dismissBeforeYValue;
            final overlayInteractive = overlayInteractiveValue;
            final overlayClosable = overlayClosableValue;
            final shield = div().absolute().inset0();
            if (overlayInteractive) {
                shield.onAnyMouseDown((event, window, cx) -> {
                    if (!overlayInteractive) {
                        return;
                    }
                    if (dismissBeforeY != null && event.position.y < dismissBeforeY) {
                        return;
                    }
                    cx.stopPropagation();
                    if (overlayClosable && event.button == MouseButton.Left) {
                        close(requestClose, onClose, window, cx);
                    }
                });
            }
            trapped.child(overlayElement).child(shield);
        }
        if (surfaceElement != null) {
            trapped.child(surfaceElement);
        }
        trapped.refineStyle(sheetStyle);

        return anchored().position(point(gpui.Prelude.px(0.), gpui.Prelude.px(0.))).child(container);
    }

}
