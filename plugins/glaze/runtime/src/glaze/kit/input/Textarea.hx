// Ported from gpui-kit 0.8.1: crates/component/src/input/textarea.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.input;

import glaze.App;
import glaze.ClipboardItem;
import glaze.DefiniteLength;
import glaze.Entity;
import glaze.IntoElement;
import glaze.RenderOnce;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.base.A11y;
import glaze.kit.base.input.InlineTokenClickListener;
import glaze.kit.base.input.InlineTokenContext;
import glaze.kit.base.input.InlineTokenHoverListener;
import glaze.kit.base.input.InlineTokenRenderer;
import glaze.kit.base.input.NativeMenu;
import glaze.kit.base.input.TextareaState;
import glaze.kit.Sizable;
import glaze.kit.Size;
import glaze.kit.Size.IntoSize;

using glaze.kit.base.StyledExt;

/**
 * A styled ordinary multi-line text field.
 */
class Textarea implements RenderOnce implements Styled implements Sizable {

    var tokenRenderer:Null<InlineTokenRenderer> = null;

    var tokenClickListener:Null<InlineTokenClickListener> = null;

    @:allow(tests)
    var tokenHoverListener:Null<InlineTokenHoverListener> = null;

    final state:Entity<TextareaState>;

    final textareaStyle:StyleRefinement = new StyleRefinement();

    var size:Size = Medium;

    var height:Null<DefiniteLength> = null;

    var appearanceValue:Bool = true;

    var borderedValue:Bool = true;

    var disabledValue:Bool = false;

    var readonlyValue:Bool = false;

    var tabIndexValue:Int = 0;

    var roleValue:RoleOverride = Implicit;

    var accessibilityIdValue:Null<String> = null;

    var ariaLabelValue:Null<String> = null;

    /**
     * An optional context menu builder to allow a custom context menu.
     *
     * If set, this overrides the built-in context menu.
     */
    var contextMenuBuilder:Null<(NativeMenu, Window, App) -> NativeMenu> = null;

    @:allow(tests)
    var pasteHandler:Null<(ClipboardItem, Window, App) -> Bool> = null;

    public function new(state:Entity<TextareaState>) {
        this.state = state;
    }

    public inline function style():StyleRefinement {
        return textareaStyle;
    }

    /**
     * The element each atomic inline token renders as, in place of the default
     * `InputToken`; editing and history stay with the input.
     */
    public function token(render:(InlineTokenContext, Window, App) -> IntoElement):Textarea {
        tokenRenderer = (token, window, cx) -> (render(token, window, cx) : glaze.AnyElement);
        return this;
    }

    /** Open a reference after a completed, unconsumed token click. */
    public function onTokenClick(listener:InlineTokenClickListener):Textarea {
        tokenClickListener = listener;
        return this;
    }

    /**
     * Report pointer presence over a token so the application can show a
     * tooltip or run custom logic. Hover never selects or edits.
     */
    public function onTokenHover(listener:InlineTokenHoverListener):Textarea {
        tokenHoverListener = listener;
        return this;
    }

    public function h(height:glaze.IntoDefiniteLength):Textarea {
        this.height = height;
        return this;
    }

    public function appearance(appearance:Bool):Textarea {
        appearanceValue = appearance;
        return this;
    }

    public function bordered(bordered:Bool):Textarea {
        borderedValue = bordered;
        return this;
    }

    public function disabled(disabled:Bool):Textarea {
        disabledValue = disabled;
        return this;
    }

    /**
     * Set the textarea to read-only, default is `false`.
     *
     * Unlike `disabled`, a read-only textarea keeps the normal appearance
     * and still can be focused, selected and copied, it only rejects the changes
     * made by the user.
     */
    public function readonly(readonly:Bool):Textarea {
        readonlyValue = readonly;
        return this;
    }

    public function tabIndex(index:Int):Textarea {
        tabIndexValue = index;
        return this;
    }

    public function role(role:RoleOverride):Textarea {
        roleValue = role;
        return this;
    }

    /** Set the developer-assigned accessibility identifier. */
    public function accessibilityId(id:String):Textarea {
        accessibilityIdValue = id;
        return this;
    }

    public function ariaLabel(label:String):Textarea {
        ariaLabelValue = label;
        return this;
    }

    /**
     * Replace the built-in context menu shown on right-click.
     *
     * The closure receives an empty menu and returns the one to show, so it
     * decides entirely what appears: the default items are not added. It
     * shows only while the state's context menu is enabled, which is the
     * default.
     */
    public function contextMenu(f:(NativeMenu, Window, App) -> NativeMenu):Textarea {
        contextMenuBuilder = f;
        return this;
    }

    /**
     * Intercept paste payloads (images, files) before the default text insertion.
     *
     * `true` consumes the paste so nothing is inserted, `false` falls through
     * to `clipboard.text()`.
     */
    public function onPaste(handler:(ClipboardItem, Window, App) -> Bool):Textarea {
        pasteHandler = handler;
        return this;
    }

    public function withSize(size:IntoSize):Textarea {
        this.size = size;
        return this;
    }

    /** The `Input` this textarea renders, for a compound control that frames it. */
    @:allow(glaze.kit)
    function intoInput():Input {
        final input = @:privateAccess Input.fromState((state : TextareaState));
        if (tokenRenderer != null) {
            final render = tokenRenderer;
            input.token((token, window, cx) -> render(token, window, cx));
        }
        if (tokenClickListener != null) input.onTokenClick(tokenClickListener);
        if (tokenHoverListener != null) input.onTokenHover(tokenHoverListener);
        input.appearance(appearanceValue)
            .bordered(borderedValue)
            .disabled(disabledValue)
            .readonly(readonlyValue)
            .tabIndex(tabIndexValue)
            .role(roleValue)
            .withSize(size);
        if (height != null) input.h(height);
        if (accessibilityIdValue != null) input.accessibilityId(accessibilityIdValue);
        if (ariaLabelValue != null) input.ariaLabel(ariaLabelValue);
        if (contextMenuBuilder != null) input.contextMenu(contextMenuBuilder);
        if (pasteHandler != null) input.onPaste(pasteHandler);
        return input.refineStyle(textareaStyle);
    }

    public function render(window:Window, cx:App):IntoElement {
        return intoInput();
    }

}
