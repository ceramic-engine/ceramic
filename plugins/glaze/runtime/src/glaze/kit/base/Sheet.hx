// Ported from gpui-kit 0.8.1: crates/base/src/sheet.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base;

import glaze.AnyElement;
import glaze.App;
import glaze.AppContext;
import glaze.ClickEvent;
import glaze.Component;
import glaze.Div;
import glaze.FocusHandle;
import glaze.IntoElement;
import glaze.KeyBinding;
import glaze.MouseButton;
import glaze.Pixels;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.base.Actions.Cancel;
import glaze.kit.base.Dialog.DialogKeys;

import glaze.Prelude.*;

using glaze.kit.base.FocusTrap;
using glaze.kit.base.Observe;
using glaze.kit.base.StyledExt;

private typedef CloseHandler = (ClickEvent, Window, App) -> Void;
private typedef CloseRequest = (Window, App) -> Void;

/**
 * An unstyled modal sheet host.
 *
 * Applications provide the overlay and surface. The host owns focus trapping,
 * Escape handling, overlay dismissal, and close callback ordering.
 */
class Sheet extends Component implements Styled {

    static inline final CONTEXT = 'Sheet';

    final base:Div = div();

    final sheetStyle:StyleRefinement = new StyleRefinement();

    /** Hidden in the Rust docs. */
    @prop var focusHandle:FocusHandle;

    /** Hidden in the Rust docs. */
    @prop var overlayInteractive:Bool = true;

    @prop var overlayClosable:Bool = true;

    /** Hidden in the Rust docs. */
    @prop var dismissBeforeY:Null<Pixels> = null;

    var overlayElement:Null<AnyElement> = null;

    var surfaceElement:Null<AnyElement> = null;

    @prop var requestClose:CloseRequest = (_, _) -> {};

    @prop var onClose:CloseHandler = (_, _, _) -> {};

    public static function bindKeys(cx:AppContext):Void {
        (cx:App).bindKeys([new KeyBinding('escape', new Cancel(), CONTEXT)]);
    }

    static function close(request:CloseRequest, notify:CloseHandler, window:Window, cx:App):Void {
        final event = DialogKeys.defaultClickEvent();
        request(window, cx);
        notify(event, window, cx);
    }

    public function new(cx:App) {
        super();
        this.focusHandle = cx.focusHandle();
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

    public function onClose(handler:(ClickEvent, Window, App) -> Void):Sheet {
        this.onClose = handler;
        return this;
    }

    /** Hidden in the Rust docs. */
    public function requestClose(handler:(Window, App) -> Void):Sheet {
        this.requestClose = handler;
        return this;
    }

    public function render(window:Window, _:App):IntoElement {
        final viewport = window.viewportSize();
        final requestClose = this.requestClose;
        final onClose = this.onClose;
        final escapeRequest = requestClose;
        final escapeNotify = onClose;

        final host = base
            .id('sheet-host')
            .testSupport()
            .absolute()
            .top0()
            .left0()
            .w(glaze.Prelude.px(viewport.width))
            .h(glaze.Prelude.px(viewport.height))
            .keyContext(CONTEXT)
            .trackFocus(focusHandle);
        final container = host.focusTrap('sheet', focusHandle);
        // FocusTrapContainer delegates its interactivity to the wrapped Div.
        final trapped = container.base;
        trapped.onAction(Cancel, (_, window, cx) -> {
            cx.propagate();
            close(escapeRequest, escapeNotify, window, cx);
        });
        if (overlayElement != null) {
            final dismissBeforeY = this.dismissBeforeY;
            final overlayInteractive = this.overlayInteractive;
            final overlayClosable = this.overlayClosable;
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

        return anchored().position(point(glaze.Prelude.px(0.), glaze.Prelude.px(0.))).child(container);
    }

}
