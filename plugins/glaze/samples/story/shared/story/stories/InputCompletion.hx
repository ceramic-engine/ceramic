// Ported from gpui-kit 0.8.1: crates/story/src/stories/input_completion.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package story.stories;

import glaze.App;
import glaze.Context;
import glaze.Entity;
import glaze.IntoElement;
import glaze.Model;
import glaze.Render;
import glaze.Subscription;
import glaze.Window;
import glaze.kit.base.input.InputActions.Escape;
import glaze.kit.base.input.InputActions.IndentInline;
import glaze.kit.base.input.InputActions.MoveDown;
import glaze.kit.base.input.InputActions.MoveUp;
import glaze.kit.base.input.InputEvent;
import glaze.kit.base.input.InputState;
import glaze.kit.input.Input;
import glaze.kit.list.ListItem;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;

using glaze.kit.base.StyledExt;
using glaze.kit.ThemeStyled;

/**
 * An application-owned completion menu around a single-line `Input`.
 *
 * Typing `$` opens a menu of shell-style variables; typing filters it, the
 * keyboard drives it, and accepting replaces the typed `$prefix` with the
 * completed `$NAME `. `InputState` carries no completion state: candidates,
 * filtering, ranking, the popup, keyboard ownership and the accepted edit all
 * live here, composed from the input's public API.
 *
 * - `InputEvent.Change` rescans the trigger under the caret. Caret movement
 *   emits no event, so `render` repeats the rescan against the live caret,
 *   and every captured key revalidates before acting: a stale menu dismisses
 *   instead of owning the keyboard or swallowing an Enter.
 * - `captureAction` on the input's wrapper owns `MoveUp` / `MoveDown` /
 *   `Escape` / `IndentInline` before the input sees them while the menu is
 *   open.
 * - `InputEvent.PressEnter` lets the application decide between accepting a
 *   candidate and submitting.
 * - `setSelectedRange` + `replace` swap the typed `$prefix` in one undo
 *   step.
 *
 * The menu anchors to the input region; applications that need caret
 * anchoring can resolve it with `cursorLayout()` / `rangeToBounds()`.
 */
class InputCompletion {

    /**
     * The candidate table. A real application fetches or computes candidates
     * per context; the input never knows they exist.
     */
    public static final VARIABLES:Array<{name:String, description:String}> = [
        {name: 'EDITOR', description: 'default editor'},
        {name: 'HOME', description: 'user home directory'},
        {name: 'LANG', description: 'locale identifier'},
        {name: 'PATH', description: 'executable search path'},
        {name: 'PWD', description: 'working directory'},
        {name: 'SHELL', description: 'login shell'},
        {name: 'TERM', description: 'terminal type'},
        {name: 'USER', description: 'current user name'},
    ];

    static inline function isAsciiAlphanumeric(c:Int):Bool {
        return (c >= '0'.code && c <= '9'.code) || (c >= 'a'.code && c <= 'z'.code) || (c >= 'A'.code && c <= 'Z'.code);
    }

    /** Rust `u8::is_ascii_whitespace`. */
    static inline function isAsciiWhitespace(c:Int):Bool {
        return c == ' '.code || c == '\t'.code || c == '\n'.code || c == 0x0C || c == '\r'.code;
    }

    /**
     * Find the `$`-token the caret sits in.
     *
     * Returns `(tokenStart, query)` (UTF-8 byte offset of the `$`). The `$`
     * must open the token, at the start of the text or after whitespace, so
     * `a$b` never triggers. `null` means the caret is outside any token and
     * the menu dismisses.
     */
    public static function activeVariableQuery(text:String, cursor:Int):Null<{tokenStart:Int, query:String}> {
        final bytes = haxe.io.Bytes.ofString(text);
        final cursor = cursor < bytes.length ? cursor : bytes.length;
        var start = cursor;
        while (start > 0 && (isAsciiAlphanumeric(bytes.get(start - 1)) || bytes.get(start - 1) == '_'.code)) {
            start -= 1;
        }
        if (start == 0 || bytes.get(start - 1) != '$'.code) {
            return null;
        }
        if (start >= 2 && !isAsciiWhitespace(bytes.get(start - 2))) {
            return null;
        }
        return {tokenStart: start - 1, query: bytes.getString(start, cursor - start)};
    }

    /**
     * Prefix matches first, then substring matches, each alphabetical. Empty
     * when nothing matches, which dismisses the menu quietly.
     */
    public static function rankedVariables(query:String):Array<String> {
        final query = asciiLower(query);
        final prefixed:Array<String> = [];
        final contained:Array<String> = [];
        for (variable in VARIABLES) {
            final name = variable.name;
            final lower = asciiLower(name);
            if (lower.indexOf(query) < 0) continue;
            if (StringTools.startsWith(lower, query)) prefixed.push(name) else contained.push(name);
        }
        prefixed.sort(compareStrings);
        contained.sort(compareStrings);
        return prefixed.concat(contained);
    }

    static function compareStrings(a:String, b:String):Int {
        return a < b ? -1 : (a > b ? 1 : 0);
    }

    static function asciiLower(s:String):String {
        final buf = new StringBuf();
        for (i in 0...s.length) {
            final c = StringTools.fastCodeAt(s, i);
            buf.addChar(c >= 'A'.code && c <= 'Z'.code ? c + 32 : c);
        }
        return buf.toString();
    }

    public static function description(name:String):String {
        for (variable in VARIABLES) {
            if (variable.name == name) return variable.description;
        }
        return '';
    }

}

/**
 * An open menu. `tokenStart` is the byte offset of the `$` that opened it,
 * the unit `cursor()` and `setSelectedRange()` speak.
 */
private class Menu {

    public final tokenStart:Int;

    /** Filtered candidate names, in display order. */
    public final items:Array<String>;

    public var selected:Int;

    public function new(tokenStart:Int, items:Array<String>, selected:Int) {
        this.tokenStart = tokenStart;
        this.items = items;
        this.selected = selected;
    }

    public function selectedName():Null<String> {
        return selected >= 0 && selected < items.length ? items[selected] : null;
    }

}

class CompletionExample extends Model implements Render {

    @:allow(story.stories)
    @:allow(tests)
    final input:Entity<InputState>;

    /** Non null while the menu is open. */
    var menu:Null<Menu> = null;

    /** The last accepted completion or submission. */
    var status:String;

    final subscription:Subscription;

    /** Rust `CompletionExample::new`. */
    public static function create(window:Window, cx:App):Entity<CompletionExample> {
        return cx.newEntity((cx:Context<CompletionExample>) -> new CompletionExample(window, cx));
    }

    function new(window:Window, cx:Context<CompletionExample>) {
        super();
        input = cx.newEntity((cx:Context<InputState>) -> new InputState(window, cx).withPlaceholder('Type $$ to complete a variable'));
        subscription = cx.subscribeIn(input, InputEvent, window, (this_:CompletionExample, _, event, window, cx) -> this_.onInputEvent(event, window, cx));
        status = 'Enter submits when no menu is open.';
    }

    /** For the tests: the items of the open menu. */
    @:allow(tests)
    function menuItems():Null<Array<String>> {
        return menu != null ? menu.items.copy() : null;
    }

    /** For the tests: the status line. */
    @:allow(tests)
    function statusText():String {
        return status;
    }

    function onInputEvent(event:InputEvent, window:Window, cx:Context<CompletionExample>):Void {
        switch event {
            case Change:
                if (rescan(cx.app)) {
                    cx.notify();
                }
            // A current menu takes Enter; otherwise Enter submits.
            case PressEnter(false, _):
                if (menuIsCurrent(cx.app)) {
                    accept(window, cx);
                } else {
                    menu = null;
                    submit(cx);
                }
            case Blur:
                menu = null;
            case _:
        }
    }

    /**
     * Open, update or dismiss the menu from the buffer and caret as they are
     * now. Returns whether the menu changed.
     */
    function rescan(cx:App):Bool {
        final state = input.read(cx);
        final trigger = InputCompletion.activeVariableQuery(state.value(), state.cursor());
        if (trigger == null) {
            final had = menu != null;
            menu = null;
            return had;
        }
        final items = InputCompletion.rankedVariables(trigger.query);
        if (items.length == 0) {
            final had = menu != null;
            menu = null;
            return had;
        }

        // Keep the highlighted row while the filter narrows.
        final selected = menu == null ? 0 : (menu.selected < items.length - 1 ? menu.selected : items.length - 1);
        final changed = menu == null || menu.tokenStart != trigger.tokenStart || menu.items.join('\n') != items.join('\n')
            || menu.items.length != items.length || menu.selected != selected;
        menu = new Menu(trigger.tokenStart, items, selected);
        return changed;
    }

    /** Whether the open menu still belongs to the token under the caret. */
    function menuIsCurrent(cx:App):Bool {
        final state = input.read(cx);
        final trigger = InputCompletion.activeVariableQuery(state.value(), state.cursor());
        return menu != null && trigger != null && menu.tokenStart == trigger.tokenStart;
    }

    /**
     * Take a captured key while the menu is current. A stale menu dismisses
     * and leaves the key to the input.
     */
    function ownKey(cx:Context<CompletionExample>):Bool {
        if (menu == null) {
            return false;
        }
        if (!menuIsCurrent(cx.app)) {
            menu = null;
            cx.notify();
            return false;
        }
        cx.stopPropagation();
        return true;
    }

    function select(delta:Int, cx:Context<CompletionExample>):Void {
        if (!ownKey(cx)) {
            return;
        }
        if (menu != null) {
            // Rust `saturating_add_signed(delta).min(len - 1)`.
            var next = menu.selected + delta;
            if (next < 0) next = 0;
            if (next > menu.items.length - 1) next = menu.items.length - 1;
            menu.selected = next;
        }
        cx.notify();
    }

    /** Replace the typed `$prefix` with `$NAME ` in one undo step. */
    function accept(window:Window, cx:Context<CompletionExample>):Void {
        final menu = this.menu;
        this.menu = null;
        if (menu == null) {
            return;
        }
        cx.notify();
        final name = menu.selectedName();
        if (name == null) {
            return;
        }

        // The buffer may have changed since the menu opened; edit only the
        // token that is under the caret now.
        final state = input.read(cx.app);
        final text = state.value();
        final cursor = state.cursor();
        final trigger = InputCompletion.activeVariableQuery(text, cursor);
        if (trigger == null || trigger.tokenStart != menu.tokenStart) {
            return;
        }

        input.update(cx, (input, cx) -> {
            input.setSelectedRange(new glaze.Range(menu.tokenStart, cursor), cast cx);
            input.replace('$$' + name + ' ', window, cast cx);
            input.focus(window, cast cx);
        });
        status = 'Completed $$' + name;
    }

    function submit(cx:Context<CompletionExample>):Void {
        status = 'Submitted ' + debugString(input.read(cx.app).value());
        cx.notify();
    }

    /** Rust `{:?}` of a string (the values here are plain text). */
    static function debugString(value:String):String {
        final buf = new StringBuf();
        buf.add('"');
        for (c in new haxe.iterators.StringIteratorUnicode(value)) {
            switch c {
                case '"'.code: buf.add('\\"');
                case '\\'.code: buf.add('\\\\');
                case '\n'.code: buf.add('\\n');
                case '\r'.code: buf.add('\\r');
                case '\t'.code: buf.add('\\t');
                case _: buf.addChar(c);
            }
        }
        buf.add('"');
        return buf.toString();
    }

    function renderMenu(menu:Menu, cx:Context<CompletionExample>):IntoElement {
        final theme = Theme.global(cx.app);
        return vFlex()
            .id('completion-menu')
            .w72()
            .maxH64()
            .overflowYScroll()
            .p1()
            .gapY0p5()
            .popoverStyle(cx.app)
            .children([for (ix in 0...menu.items.length) {
                final name = menu.items[ix];
                new ListItem(ix)
                    .selected(ix == menu.selected)
                    .rounded(theme.radius)
                    .onClick(cx.listener((this_:CompletionExample, _, window, cx) -> {
                        if (this_.menu != null) {
                            this_.menu.selected = ix;
                        }
                        this_.accept(window, cx);
                    }))
                    .child(div().flex().gap2().textSm().child(name).child(div()
                        .textColor(theme.mutedForeground)
                        .child(InputCompletion.description(name))));
            }]);
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        final self:Context<CompletionExample> = cast cx;
        final theme = Theme.global(cx.app);
        // Caret movement emits no event; rescan against the caret as it stands
        // so a menu whose token the caret left is gone in this frame.
        rescan(cx.app);

        final field = div()
            .relative()
            .wFull()
            // Tab accepts: `IndentInline` is what the input binds tab to.
            .captureAction(MoveUp, self.listener((this_:CompletionExample, _:MoveUp, _, cx) -> this_.select(-1, cx)))
            .captureAction(MoveDown, self.listener((this_:CompletionExample, _:MoveDown, _, cx) -> this_.select(1, cx)))
            .captureAction(Escape, self.listener((this_:CompletionExample, _:Escape, _, cx) -> {
                if (this_.ownKey(cx)) {
                    this_.menu = null;
                    cx.notify();
                }
            }))
            .captureAction(IndentInline, self.listener((this_:CompletionExample, _:IndentInline, window, cx) -> {
                if (this_.ownKey(cx)) {
                    this_.accept(window, cx);
                }
            }))
            .child(new Input(input));
        if (menu != null) {
            field.child(deferred(div()
                .absolute()
                .left0()
                .top(relative(1.))
                .pt1()
                .child(renderMenu(menu, self))));
        }

        return vFlex()
            .wFull()
            .gap2()
            .child(field)
            .child(div()
                .textSm()
                .textColor(theme.mutedForeground)
                .child(status));
    }

}
