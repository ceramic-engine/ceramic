// Ported from gpui-kit 0.8.1: crates/base/src/input/base/state.rs (`init`, the key bindings)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

import glaze.App;
import glaze.AppContext;
import glaze.KeyBinding;
import glaze.OperatingSystem;
import glaze.kit.base.Actions.SelectDown;
import glaze.kit.base.Actions.SelectLeft;
import glaze.kit.base.Actions.SelectRight;
import glaze.kit.base.Actions.SelectUp;
import glaze.kit.base.input.InputActions;

/**
 * The key bindings of the text inputs, in the `Input` key context.
 *
 * Rust picks them at compile time (`#[cfg(target_os = ...)]`, and
 * `cx.platform_info().is_mac()` for the secondary Enter); the port reads
 * `OperatingSystem.current` when `init` runs, so the tests and goldens get
 * the macOS keymap of the reference renders.
 */
class InputKeyBindings {

    /** Rust `input::state::init`: binds the input keys. */
    public static function init(cx:AppContext):Void {
        (cx:App).bindKeys(bindings(OperatingSystem.current));
    }

    /** The bindings for an operating system, in the order of the Rust list. */
    public static function bindings(os:OperatingSystem):Array<KeyBinding> {
        final macos = os == Mac;
        final linux = os == Linux;
        final windows = os == Windows;
        final context = InputActions.CONTEXT;
        final list:Array<KeyBinding> = [];
        inline function bind(keystrokes:String, action:glaze.Action):Void {
            list.push(new KeyBinding(keystrokes, action, context));
        }

        bind('backspace', new Backspace());
        bind('shift-backspace', new Backspace());
        if (macos) bind('ctrl-backspace', new Backspace());
        bind('delete', new Delete());
        bind('shift-delete', new Delete());
        if (macos) bind('cmd-backspace', new DeleteToBeginningOfLine());
        if (macos) bind('cmd-delete', new DeleteToEndOfLine());
        if (macos) bind('alt-backspace', new DeleteToPreviousWordStart());
        if (!macos) bind('ctrl-backspace', new DeleteToPreviousWordStart());
        if (macos) bind('alt-delete', new DeleteToNextWordEnd());
        if (!macos) bind('ctrl-delete', new DeleteToNextWordEnd());
        bind('enter', new Enter(false, false));
        bind('shift-enter', new Enter(false, true));
        bind(macos ? 'cmd-enter' : 'ctrl-enter', new Enter(true, false));
        bind('escape', new Escape());
        bind('up', new MoveUp());
        bind('down', new MoveDown());
        bind('left', new MoveLeft());
        bind('right', new MoveRight());
        bind('pageup', new MovePageUp());
        bind('pagedown', new MovePageDown());
        bind('tab', new IndentInline());
        bind('shift-tab', new OutdentInline());
        if (macos) bind('cmd-]', new Indent());
        if (!macos) bind('ctrl-]', new Indent());
        if (macos) bind('cmd-[', new Outdent());
        if (!macos) bind('ctrl-[', new Outdent());
        bind('shift-left', new SelectLeft());
        bind('shift-right', new SelectRight());
        bind('shift-up', new SelectUp());
        bind('shift-down', new SelectDown());
        if (!(macos || linux)) bind('shift-alt-left', new SelectLeft());
        if (!(macos || linux)) bind('shift-alt-right', new SelectRight());
        // Avoid Ctrl+Alt+arrows on Linux, where desktops may reserve them.
        if (macos) bind('cmd-alt-up', new AddCursorAbove());
        if (macos) bind('cmd-alt-down', new AddCursorBelow());
        if (windows) bind('ctrl-alt-up', new AddCursorAbove());
        if (!(macos || windows)) bind('shift-alt-up', new AddCursorAbove());
        if (windows) bind('ctrl-alt-down', new AddCursorBelow());
        if (!(macos || windows)) bind('shift-alt-down', new AddCursorBelow());
        bind('home', new MoveHome());
        bind('end', new MoveEnd());
        if (!macos) bind('ctrl-home', new MoveToStart());
        if (!macos) bind('ctrl-end', new MoveToEnd());
        if (!macos) bind('ctrl-shift-home', new SelectToStart());
        if (!macos) bind('ctrl-shift-end', new SelectToEnd());
        bind('shift-home', new SelectToStartOfLine());
        bind('shift-end', new SelectToEndOfLine());
        if (macos) bind('ctrl-shift-a', new SelectToStartOfLine());
        if (macos) bind('ctrl-shift-e', new SelectToEndOfLine());
        if (macos) bind('shift-cmd-left', new SelectToStartOfLine());
        if (macos) bind('shift-cmd-right', new SelectToEndOfLine());
        if (macos || linux) bind('alt-shift-left', new SelectToPreviousWordStart());
        if (!macos) bind('ctrl-shift-left', new SelectToPreviousWordStart());
        if (macos || linux) bind('alt-shift-right', new SelectToNextWordEnd());
        if (!macos) bind('ctrl-shift-right', new SelectToNextWordEnd());
        if (macos) bind('ctrl-cmd-space', new ShowCharacterPalette());
        if (macos) bind('cmd-a', new SelectAll());
        if (!macos) bind('ctrl-a', new SelectAll());
        if (macos) bind('cmd-c', new Copy());
        if (!macos) bind('ctrl-c', new Copy());
        if (macos) bind('cmd-x', new Cut());
        if (!macos) bind('ctrl-x', new Cut());
        if (macos) bind('cmd-v', new Paste());
        if (!macos) bind('ctrl-v', new Paste());
        if (macos) bind('ctrl-a', new MoveHome());
        if (macos) bind('cmd-left', new MoveHome());
        if (macos) bind('ctrl-e', new MoveEnd());
        if (macos) bind('cmd-right', new MoveEnd());
        if (macos) bind('cmd-z', new Undo());
        if (macos) bind('cmd-shift-z', new Redo());
        if (macos) bind('cmd-up', new MoveToStart());
        if (macos) bind('cmd-down', new MoveToEnd());
        if (macos) bind('alt-left', new MoveToPreviousWord());
        if (macos) bind('alt-right', new MoveToNextWord());
        if (!macos) bind('ctrl-left', new MoveToPreviousWord());
        if (!macos) bind('ctrl-right', new MoveToNextWord());
        if (macos) bind('cmd-shift-up', new SelectToStart());
        if (macos) bind('cmd-shift-down', new SelectToEnd());
        if (!macos) bind('ctrl-z', new Undo());
        if (!macos) bind('ctrl-y', new Redo());
        if (macos) bind('cmd-f', new Search());
        if (!macos) bind('ctrl-f', new Search());
        if (macos) bind('cmd-shift-f', new Replace());
        if (!macos) bind('ctrl-h', new Replace());
        return list;
    }

}
