// Ported from gpui-kit 0.8.1: crates/base/src/dialog.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base;

import gpui.AnyElement;
import gpui.App;
import gpui.AppContext;
import gpui.Bounds;
import gpui.ClickEvent;
import gpui.Div;
import gpui.ElementId;
import gpui.FocusHandle;
import gpui.IntoElement;
import gpui.KeyBinding;
import gpui.KeyboardButton;
import gpui.MouseButton;
import gpui.ParentElement;
import gpui.Pixels;
import gpui.RenderOnce;
import gpui.StyleRefinement;
import gpui.Styled;
import gpui.Window;
import gpui.base.A11y;
import gpui.base.Actions.Cancel;
import gpui.base.Actions.Confirm;

import gpui.Prelude.*;

using gpui.base.FocusTrap;
using gpui.base.Observe;
using gpui.base.StyledExt;

private typedef Decision = (ClickEvent, Window, App) -> Bool;
private typedef Closed = (ClickEvent, Window, App) -> Void;
private typedef CloseRequest = (Bool, Window, App) -> Void;
private typedef OpenRequest = (Window, App) -> Void;
private typedef OpenChange = (Bool, DialogChangeReason, Window, App) -> Void;

/**
 * Why a dialog's open state changed.
 */
enum abstract DialogChangeReason(Int) {
    var TriggerPress = 0;
    var BackdropPress = 1;
    var Cancel = 2;
    var Confirm = 3;
    var Imperative = 4;

    public function toString():String {
        return switch (cast this : DialogChangeReason) {
            case TriggerPress: 'TriggerPress';
            case BackdropPress: 'BackdropPress';
            case Cancel: 'Cancel';
            case Confirm: 'Confirm';
            case Imperative: 'Imperative';
        }
    }
}

/**
 * A shared, controllable open state for a dialog (Rust clones share it
 * through `Rc`: here the handle itself is shared).
 */
class DialogHandle {

    var openValue:Bool;

    @:allow(gpui.base)
    var onOpenChange:Null<OpenChange> = null;

    public function new(open:Bool) {
        this.openValue = open;
    }

    public inline function isOpen():Bool {
        return openValue;
    }

    public function open(window:Window, cx:App):Void {
        setOpen(true, Imperative, window, cx);
    }

    public function close(window:Window, cx:App):Void {
        setOpen(false, Imperative, window, cx);
    }

    @:allow(gpui.base)
    function setOpen(open:Bool, reason:DialogChangeReason, window:Window, cx:App):Void {
        final previous = openValue;
        openValue = open;
        if (previous == open) {
            return;
        }
        final callback = onOpenChange;
        if (callback != null) {
            callback(open, reason, window, cx);
        }
        window.refresh();
    }

}

/**
 * The unstyled modal dialog primitives (Rust module `dialog`): `init` binds
 * the dialog keys.
 */
class DialogKeys {

    @:allow(gpui.base)
    static inline final CONTEXT = 'Dialog';

    public static function init(cx:AppContext):Void {
        (cx:App).bindKeys([
            new KeyBinding('escape', new gpui.base.Actions.Cancel(), CONTEXT),
            new KeyBinding('enter', new gpui.base.Actions.Confirm(false), CONTEXT)
        ]);
    }

    /** Rust `ClickEvent::default()`: a keyboard click (Enter) with empty bounds. */
    @:allow(gpui.base)
    static function defaultClickEvent():ClickEvent {
        return ClickEvent.Keyboard(new gpui.ClickEvent.KeyboardClickEvent(KeyboardButton.Enter, new Bounds()));
    }

    @:allow(gpui.base)
    static function requestOpenChange(handle:Null<DialogHandle>, callback:Null<OpenChange>, open:Bool, reason:DialogChangeReason, window:Window, cx:App):Void {
        if (handle != null) {
            handle.setOpen(open, reason, window, cx);
        }
        else if (callback != null) {
            callback(open, reason, window, cx);
        }
    }

}

/**
 * Unstyled modal host owning focus, keyboard actions, dismissal, and callback ordering.
 *
 * The port has no accessibility tree: the role the host would export is
 * kept in `a11y`.
 */
class Dialog implements RenderOnce implements Styled implements ParentElement {

    final dialogStyle:StyleRefinement = new StyleRefinement();

    var focus:FocusHandle;

    var roleValue:Role = Role.Dialog;

    var layerValue:Int = 0;

    var keyboard:Bool = true;

    var overlayClosable:Bool = true;

    var topmost:Bool = true;

    var dismissBelowYValue:Pixels = 0.;

    var backdropElement:Null<AnyElement> = null;

    var popupElement:Null<AnyElement> = null;

    final childElements:Array<AnyElement> = [];

    var onOkHandler:Decision = (_, _, _) -> true;

    var onCancelHandler:Decision = (_, _, _) -> true;

    var onCloseHandler:Closed = (_, _, _) -> {};

    var requestCloseHandler:CloseRequest = (_, _, _) -> {};

    var handleValue:Null<DialogHandle> = null;

    var openValue:Bool = true;

    var onOpenChangeHandler:Null<OpenChange> = null;

    /** The accessibility properties the host exports. */
    public final a11y:A11y = new A11y();

    public function new(cx:App) {
        this.focus = cx.focusHandle();
    }

    public inline function style():StyleRefinement {
        return dialogStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):Dialog {
        childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):Dialog {
        for (child in children) childElements.push(child);
        return this;
    }

    public function onOk(handler:(ClickEvent, Window, App) -> Bool):Dialog {
        onOkHandler = handler;
        return this;
    }

    public function onCancel(handler:(ClickEvent, Window, App) -> Bool):Dialog {
        onCancelHandler = handler;
        return this;
    }

    public function onClose(handler:(ClickEvent, Window, App) -> Void):Dialog {
        onCloseHandler = handler;
        return this;
    }

    public function open(open:Bool):Dialog {
        openValue = open;
        return this;
    }

    public function handle(handle:DialogHandle):Dialog {
        if (onOpenChangeHandler != null) {
            handle.onOpenChange = onOpenChangeHandler;
        }
        handleValue = handle;
        return this;
    }

    public function onOpenChange(handler:(Bool, DialogChangeReason, Window, App) -> Void):Dialog {
        if (handleValue != null) {
            handleValue.onOpenChange = handler;
        }
        onOpenChangeHandler = handler;
        return this;
    }

    public function backdrop(element:IntoElement):Dialog {
        backdropElement = element;
        return this;
    }

    public function popup(element:IntoElement):Dialog {
        popupElement = element;
        return this;
    }

    public function closeOnEscape(value:Bool):Dialog {
        keyboard = value;
        return this;
    }

    public function closeOnBackdropPress(value:Bool):Dialog {
        overlayClosable = value;
        return this;
    }

    public function dismissBelowY(value:Pixels):Dialog {
        dismissBelowYValue = value;
        return this;
    }

    @:allow(gpui.base)
    function role(role:Role):Dialog {
        roleValue = role;
        return this;
    }

    /** Hidden in the Rust docs: the stack index and whether this layer is the topmost one. */
    public function layer(index:Int, topmost:Bool):Dialog {
        layerValue = index;
        this.topmost = topmost;
        return this;
    }

    /** Hidden in the Rust docs: the focus handle the host tracks and traps. */
    public function focusHandle(value:FocusHandle):Dialog {
        focus = value;
        return this;
    }

    /** Hidden in the Rust docs: called with whether the close is deferred (confirm) or not. */
    public function requestClose(handler:(Bool, Window, App) -> Void):Dialog {
        requestCloseHandler = handler;
        return this;
    }

    public function render(window:Window, _:App):IntoElement {
        final open = handleValue != null ? handleValue.isOpen() : openValue;
        if (!open) {
            return div();
        }
        final requestClose = requestCloseHandler;
        final cancel = onCancelHandler;
        final confirm = onOkHandler;
        final closed = onCloseHandler;
        final overlayClosable = this.overlayClosable && topmost;
        final dismissBelowY = dismissBelowYValue;
        final escapeHandle = handleValue;
        final confirmHandle = handleValue;
        final backdropHandle = handleValue;
        final escapeChange = onOpenChangeHandler;
        final confirmChange = onOpenChangeHandler;
        final backdropChange = onOpenChangeHandler;
        final viewport = window.viewportSize();

        a11y.role = roleValue;
        final host = div()
            .id(ElementId.NamedInteger('dialog-host', layerValue))
            .testSupport()
            .absolute()
            .top0()
            .left0()
            .w(gpui.Prelude.px(viewport.width))
            .h(gpui.Prelude.px(viewport.height))
            // A popup in normal flow lands centered; `refineStyle`
            // below lets the caller lay the host out differently.
            .flex()
            .itemsCenter()
            .justifyCenter()
            // Rust `.role(self.role)`: no accessibility tree in the port (see `a11y`).
            .trackFocus(focus);
        final container = host.focusTrap('dialog-$layerValue', focus);
        // FocusTrapContainer delegates its interactivity to the wrapped Div.
        final trapped = container.base;
        if (keyboard) {
            trapped.keyContext(DialogKeys.CONTEXT);
        }
        final requestCancel = requestClose;
        final requestConfirm = requestClose;
        final closedCancel = closed;
        trapped.onAction(gpui.base.Actions.Cancel, (_, window, cx) -> {
            final event = DialogKeys.defaultClickEvent();
            if (cancel(event, window, cx)) {
                DialogKeys.requestOpenChange(escapeHandle, escapeChange, false, DialogChangeReason.Cancel, window, cx);
                requestCancel(false, window, cx);
                closedCancel(event, window, cx);
            }
        }).onAction(gpui.base.Actions.Confirm, (_, window, cx) -> {
            final event = DialogKeys.defaultClickEvent();
            if (confirm(event, window, cx)) {
                DialogKeys.requestOpenChange(confirmHandle, confirmChange, false, DialogChangeReason.Confirm, window, cx);
                requestConfirm(true, window, cx);
                closed(event, window, cx);
            }
        });
        if (backdropElement != null) {
            final cancel = onCancelHandler;
            final closed = onCloseHandler;
            final requestClose = requestClose;
            trapped.child(div()
                // The backdrop covers the host, so a caller's
                // `absolute()` surface has a box to fill.
                .absolute()
                .inset0()
                .onAnyMouseDown((event, window, cx) -> {
                    if (event.position.y < dismissBelowY) {
                        return;
                    }
                    final button = event.button;
                    cx.stopPropagation();
                    final event = DialogKeys.defaultClickEvent();
                    if (button == MouseButton.Left && overlayClosable && cancel(event, window, cx)) {
                        DialogKeys.requestOpenChange(backdropHandle, backdropChange, false, DialogChangeReason.BackdropPress, window, cx);
                        requestClose(false, window, cx);
                        closed(event, window, cx);
                    }
                })
                .child(backdropElement));
        }
        if (popupElement != null) {
            trapped.child(popupElement);
        }
        trapped.extend(childElements);
        trapped.refineStyle(dialogStyle);

        return deferred(anchored().position(point(gpui.Prelude.px(0.), gpui.Prelude.px(0.))).child(container))
            .withPriority(10 + layerValue);
    }

}

/**
 * Unstyled trigger that owns pointer activation for opening a dialog.
 */
class DialogTrigger implements RenderOnce {

    final trigger:AnyElement;

    var openRequest:OpenRequest = (_, _) -> {};

    var handleValue:Null<DialogHandle> = null;

    public function new(trigger:IntoElement) {
        this.trigger = trigger;
    }

    public function handle(handle:DialogHandle):DialogTrigger {
        handleValue = handle;
        return this;
    }

    public function onOpen(open:(Window, App) -> Void):DialogTrigger {
        openRequest = open;
        return this;
    }

    public function render(_:Window, _:App):IntoElement {
        final handle = handleValue;
        final open = openRequest;
        return div()
            .onMouseDown(Left, (_, window, cx) -> {
                if (handle != null) {
                    handle.setOpen(true, TriggerPress, window, cx);
                }
                open(window, cx);
                cx.stopPropagation();
            })
            .child(trigger);
    }

}

/**
 * The unstyled dialog parts (Rust `dialog_part!`): a `Div` with an id,
 * optionally occluding, with the part's children and style.
 */
@:allow(gpui.base)
abstract class DialogPart implements RenderOnce implements Styled implements ParentElement {

    final partStyle:StyleRefinement = new StyleRefinement();

    final childElements:Array<AnyElement> = [];

    final partId:String;

    final occlude:Bool;

    function new(partId:String, occlude:Bool) {
        this.partId = partId;
        this.occlude = occlude;
    }

    public inline function style():StyleRefinement {
        return partStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function render(_:Window, _:App):IntoElement {
        final element = div().id(partId);
        // The popup sits over the backdrop, whose press dismisses
        // the dialog, so it keeps presses on itself from falling through.
        if (occlude) element.occlude();
        element.extend(childElements);
        return element.refineStyle(partStyle);
    }

}

/**
 * Unstyled backdrop part rendered behind a dialog popup.
 */
class DialogBackdrop extends DialogPart {

    public function new() {
        super('dialog-backdrop', false);
    }

}

/**
 * Unstyled popup part containing dialog content.
 */
class DialogPopup extends DialogPart {

    public function new() {
        super('dialog-popup', true);
    }

}

/**
 * Unstyled title slot for a dialog surface.
 */
class DialogTitle implements RenderOnce implements Styled implements ParentElement {

    final base:Div = div();

    final titleStyle:StyleRefinement = new StyleRefinement();

    final childElements:Array<AnyElement> = [];

    public function new() {}

    public inline function style():StyleRefinement {
        return titleStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function render(_:Window, _:App):IntoElement {
        base.id('dialog-title');
        base.extend(childElements);
        return base.refineStyle(titleStyle);
    }

}

/**
 * Unstyled descriptive-content slot for a dialog surface.
 */
class DialogDescription implements RenderOnce implements Styled implements ParentElement {

    final base:Div = div();

    final descriptionStyle:StyleRefinement = new StyleRefinement();

    final childElements:Array<AnyElement> = [];

    public function new() {}

    public inline function style():StyleRefinement {
        return descriptionStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function render(_:Window, _:App):IntoElement {
        base.id('dialog-description');
        base.extend(childElements);
        return base.refineStyle(descriptionStyle);
    }

}

/**
 * Wrapper that dispatches the dialog cancel action when activated.
 */
class DialogClose implements RenderOnce implements Styled implements ParentElement {

    final closeStyle:StyleRefinement = new StyleRefinement();

    final childElements:Array<AnyElement> = [];

    var triggerElement:Null<AnyElement> = null;

    /**
     * The focus node activation dispatches from, filled at render and read
     * when clicked, so the trigger built earlier reaches it too.
     */
    final anchor:AnchorCell = new AnchorCell();

    public function new() {}

    public inline function style():StyleRefinement {
        return closeStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    /**
     * Styles a button with the accessible name "Close" and cancel activation.
     *
     * The supplied button already supports pointer, keyboard, and accessibility
     * activation. The builder only needs to supply presentation.
     * The wrapper does not also handle clicks when a trigger is supplied.
     */
    public function trigger(build:(gpui.base.Button) -> IntoElement):DialogClose {
        final anchor = this.anchor;
        final button = new gpui.base.Button('close')
            .accessibilityLabel('Close')
            .onClick((_, window, cx) -> activate(anchor, window, cx));
        this.triggerElement = build(button);
        return this;
    }

    /**
     * Dispatches `Cancel` from the control's own focus node, so it reaches
     * the dialog the control sits in whatever holds focus at that moment.
     */
    static function activate(cell:AnchorCell, window:Window, cx:App):Void {
        final anchor = cell.handle;
        if (anchor != null) {
            anchor.dispatchAction(new gpui.base.Actions.Cancel(), window, cx);
        }
        else {
            window.dispatchAction(new gpui.base.Actions.Cancel(), cx);
        }
    }

    public function render(window:Window, cx:App):IntoElement {
        final anchor = window.useKeyedState('dialog-close-anchor', cx, _ -> cx.focusHandle()).read(cx).value;
        this.anchor.handle = anchor;
        final cell = this.anchor;
        final element = div()
            .id('dialog-close')
            // A zero-size, out-of-flow node that tracks the anchor: it is never
            // hovered, so it takes no focus on its own and does not enter the
            // Tab order, but it sits inside this dialog's dispatch path.
            .child(div().absolute().size0().trackFocus(anchor));
        if (triggerElement == null) {
            element.onClick((_, window, cx) -> activate(cell, window, cx));
        }
        if (triggerElement != null) {
            element.child(triggerElement);
        }
        element.extend(childElements);
        return element.refineStyle(closeStyle);
    }

}

/**
 * Rust `Rc<RefCell<Option<FocusHandle>>>`.
 */
private class AnchorCell {

    public var handle:Null<FocusHandle> = null;

    public function new() {}

}
