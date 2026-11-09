// Ported from gpui-kit 0.8.1: crates/component/src/input/textarea.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.input;

import glaze.App;
import glaze.ClipboardItem;
import glaze.Component;
import glaze.DefiniteLength;
import glaze.Entity;
import glaze.IntoElement;
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
class Textarea extends Component implements Styled implements Sizable {

    var tokenRenderer:Null<InlineTokenRenderer> = null;

    /** Open a reference after a completed, unconsumed token click. */
    @prop var onTokenClick:Null<InlineTokenClickListener> = null;

    /**
     * Report pointer presence over a token so the application can show a
     * tooltip or run custom logic. Hover never selects or edits.
     */
    @:allow(tests)
    @prop var onTokenHover:Null<InlineTokenHoverListener> = null;

    final state:Entity<TextareaState>;

    final textareaStyle:StyleRefinement = new StyleRefinement();

    var size:Size = Medium;

    var height:Null<DefiniteLength> = null;

    @prop var appearance:Bool = true;

    @prop var bordered:Bool = true;

    @prop var disabled:Bool = false;

    /**
     * Set the textarea to read-only, default is `false`.
     *
     * Unlike `disabled`, a read-only textarea keeps the normal appearance
     * and still can be focused, selected and copied, it only rejects the changes
     * made by the user.
     */
    @prop var readonly:Bool = false;

    @prop var tabIndex:Int = 0;

    @prop var role:RoleOverride = Implicit;

    /** Set the developer-assigned accessibility identifier. */
    @prop var accessibilityId:Null<String> = null;

    @prop var ariaLabel:Null<String> = null;

    /**
     * Replace the built-in context menu shown on right-click.
     *
     * The closure receives an empty menu and returns the one to show, so it
     * decides entirely what appears: the default items are not added. It
     * shows only while the state's context menu is enabled, which is the
     * default.
     */
    @prop var contextMenu:Null<(NativeMenu, Window, App) -> NativeMenu> = null;

    /**
     * Intercept paste payloads (images, files) before the default text insertion.
     *
     * `true` consumes the paste so nothing is inserted, `false` falls through
     * to `clipboard.text()`.
     */
    @:allow(tests)
    @prop var onPaste:Null<(ClipboardItem, Window, App) -> Bool> = null;

    public function new(state:Entity<TextareaState>) {
        super();
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

    public function h(height:glaze.IntoDefiniteLength):Textarea {
        this.height = height;
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
        if (onTokenClick != null) input.onTokenClick(onTokenClick);
        if (onTokenHover != null) input.onTokenHover(onTokenHover);
        input.appearance(appearance)
            .bordered(bordered)
            .disabled(disabled)
            .readonly(readonly)
            .tabIndex(tabIndex)
            .role(role)
            .withSize(size);
        if (height != null) input.h(height);
        if (accessibilityId != null) input.accessibilityId(accessibilityId);
        if (ariaLabel != null) input.ariaLabel(ariaLabel);
        if (contextMenu != null) input.contextMenu(contextMenu);
        if (onPaste != null) input.onPaste(onPaste);
        return input.refineStyle(textareaStyle);
    }

    public function render(window:Window, cx:App):IntoElement {
        return intoInput();
    }

}
