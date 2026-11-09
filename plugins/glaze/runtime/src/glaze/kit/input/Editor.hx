// Ported from gpui-kit 0.8.1: crates/component/src/input/editor.rs
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
import glaze.kit.base.input.EditorState;
import glaze.kit.base.input.NativeMenu;
import glaze.kit.Sizable;
import glaze.kit.Size;
import glaze.kit.Size.IntoSize;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;

using glaze.kit.base.StyledExt;

/**
 * A styled source-code editor.
 *
 * Keep the state on your view (`cx.newEntity(c -> new EditorState(window, c).language('json'))`)
 * and render it with `Editor.component(state)`.
 */
class Editor extends Component implements Styled implements Sizable {

    /**
     * A code editor takes its rows from the font, so that a smaller or larger
     * font keeps its leading in proportion.
     */
    static inline final EDITOR_LINE_HEIGHT:Float = 1.5;

    final state:Entity<EditorState>;

    final editorStyle:StyleRefinement = new StyleRefinement();

    var size:Size = Medium;

    var height:Null<DefiniteLength> = null;

    @prop var appearance:Bool = true;

    @prop var bordered:Bool = true;

    @prop var disabled:Bool = false;

    /**
     * Set the editor to read-only, default is `false`.
     *
     * Unlike `disabled`, a read-only editor keeps the normal appearance
     * and still can be focused, selected and copied, it only rejects the changes
     * made by the user.
     */
    @prop var readonly:Bool = false;

    @prop var tabIndex:Int = 0;

    @prop var role:RoleOverride = Implicit;

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

    public function new(state:Entity<EditorState>) {
        super();
        this.state = state;
    }

    public inline function style():StyleRefinement {
        return editorStyle;
    }

    public function h(height:glaze.IntoDefiniteLength):Editor {
        this.height = height;
        return this;
    }

    /**
     * Match the padding and density of Input and Textarea in the same form by
     * applying the same size tier. The editor keeps its independently configured
     * code font size and line height.
     */
    public function withSize(size:IntoSize):Editor {
        this.size = size;
        return this;
    }

    public function render(_:Window, cx:App):IntoElement {
        final theme = Theme.global(cx);
        final input = @:privateAccess Input.fromState((state : EditorState))
            // Source code wants a monospace font at a code size, and rows that
            // follow that size. These come first so that a text style set on
            // this editor refines over them: `.textSm()` and `.fontFamily()`
            // keep working.
            .fontFamily(theme.monoFontFamily)
            .textSize(theme.monoFontSize)
            .lineHeight(glaze.Prelude.relative(EDITOR_LINE_HEIGHT))
            .withSize(size)
            .appearance(appearance)
            .bordered(bordered)
            .focusBordered(false)
            .disabled(disabled)
            .readonly(readonly)
            .tabIndex(tabIndex)
            .role(role);
        if (height != null) input.h(height);
        if (ariaLabel != null) input.ariaLabel(ariaLabel);
        if (contextMenu != null) {
            final build = contextMenu;
            input.contextMenu((menu, window, cx) -> build(menu, window, cx));
        }
        if (onPaste != null) {
            final handler = onPaste;
            input.onPaste((item, window, cx) -> handler(item, window, cx));
        }
        return input.refineStyle(editorStyle);
    }

}
