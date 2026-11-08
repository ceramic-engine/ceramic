// Ported from gpui-kit 0.8.1: crates/component/src/input/editor.rs
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
class Editor implements RenderOnce implements Styled implements Sizable {

    /**
     * A code editor takes its rows from the font, so that a smaller or larger
     * font keeps its leading in proportion.
     */
    static inline final EDITOR_LINE_HEIGHT:Float = 1.5;

    final state:Entity<EditorState>;

    final editorStyle:StyleRefinement = new StyleRefinement();

    var size:Size = Medium;

    var height:Null<DefiniteLength> = null;

    var appearanceValue:Bool = true;

    var borderedValue:Bool = true;

    var disabledValue:Bool = false;

    var readonlyValue:Bool = false;

    var tabIndexValue:Int = 0;

    var roleValue:RoleOverride = Implicit;

    var ariaLabelValue:Null<String> = null;

    /**
     * An optional context menu builder to allow a custom context menu.
     *
     * If set, this overrides the built-in context menu.
     */
    var contextMenuBuilder:Null<(NativeMenu, Window, App) -> NativeMenu> = null;

    @:allow(tests)
    var pasteHandler:Null<(ClipboardItem, Window, App) -> Bool> = null;

    public function new(state:Entity<EditorState>) {
        this.state = state;
    }

    public inline function style():StyleRefinement {
        return editorStyle;
    }

    public function h(height:glaze.IntoDefiniteLength):Editor {
        this.height = height;
        return this;
    }

    public function appearance(appearance:Bool):Editor {
        appearanceValue = appearance;
        return this;
    }

    public function bordered(bordered:Bool):Editor {
        borderedValue = bordered;
        return this;
    }

    public function disabled(disabled:Bool):Editor {
        disabledValue = disabled;
        return this;
    }

    /**
     * Set the editor to read-only, default is `false`.
     *
     * Unlike `disabled`, a read-only editor keeps the normal appearance
     * and still can be focused, selected and copied, it only rejects the changes
     * made by the user.
     */
    public function readonly(readonly:Bool):Editor {
        readonlyValue = readonly;
        return this;
    }

    public function tabIndex(index:Int):Editor {
        tabIndexValue = index;
        return this;
    }

    public function role(role:RoleOverride):Editor {
        roleValue = role;
        return this;
    }

    public function ariaLabel(label:String):Editor {
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
    public function contextMenu(f:(NativeMenu, Window, App) -> NativeMenu):Editor {
        contextMenuBuilder = f;
        return this;
    }

    /**
     * Intercept paste payloads (images, files) before the default text insertion.
     *
     * `true` consumes the paste so nothing is inserted, `false` falls through
     * to `clipboard.text()`.
     */
    public function onPaste(handler:(ClipboardItem, Window, App) -> Bool):Editor {
        pasteHandler = handler;
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
            .appearance(appearanceValue)
            .bordered(borderedValue)
            .focusBordered(false)
            .disabled(disabledValue)
            .readonly(readonlyValue)
            .tabIndex(tabIndexValue)
            .role(roleValue);
        if (height != null) input.h(height);
        if (ariaLabelValue != null) input.ariaLabel(ariaLabelValue);
        if (contextMenuBuilder != null) {
            final build = contextMenuBuilder;
            input.contextMenu((menu, window, cx) -> build(menu, window, cx));
        }
        if (pasteHandler != null) {
            final handler = pasteHandler;
            input.onPaste((item, window, cx) -> handler(item, window, cx));
        }
        return input.refineStyle(editorStyle);
    }

}
