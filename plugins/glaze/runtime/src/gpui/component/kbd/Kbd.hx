// Ported from gpui-kit 0.8.1: crates/component/src/kbd.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.kbd;

import gpui.Action;
import gpui.App;
import gpui.FocusHandle;
import gpui.IntoElement;
import gpui.KeyBinding;
import gpui.KeyContext;
import gpui.Keystroke;
import gpui.OperatingSystem;
import gpui.RenderOnce;
import gpui.StyleRefinement;
import gpui.Styled;
import gpui.Window;
import gpui.component.theme.Theme;

import gpui.Prelude.*;

using gpui.base.StyledExt;

/**
 * A tag for displaying a keyboard shortcut.
 */
class Kbd implements RenderOnce implements Styled {

    final kbdStyle:StyleRefinement = new StyleRefinement();

    final stroke:Keystroke;

    var appearanceValue:Bool = true;

    var outlineValue:Bool = false;

    public function new(stroke:Keystroke) {
        this.stroke = stroke;
    }

    public inline function style():StyleRefinement {
        return kbdStyle;
    }

    @:allow(gpui.component)
    function keystroke():Keystroke {
        return stroke;
    }

    /**
     * Set whether to draw the key cap (default true). Without it, the
     * shortcut is plain text.
     */
    public function appearance(appearance:Bool):Kbd {
        appearanceValue = appearance;
        return this;
    }

    /**
     * Use the outline style: a bordered key cap on the background color.
     */
    public function outline():Kbd {
        outlineValue = true;
        return this;
    }

    /**
     * The `Kbd` of the highest precedence binding of `action`, in `context`
     * when given (else in the focused element's context stack), or null.
     */
    public static function bindingForAction(action:Action, context:Null<String>, window:Window):Null<Kbd> {
        var keyContext:Null<KeyContext> = null;
        if (context != null) {
            try {
                keyContext = KeyContext.parse(context);
            }
            catch (_:Dynamic) {}
        }
        final binding = if (keyContext != null) {
            final bindings = window.bindingsForActionInContext(action, keyContext);
            bindings.length > 0 ? bindings[bindings.length - 1] : null;
        }
        else {
            window.highestPrecedenceBindingForAction(action);
        }
        return binding != null ? fromBinding(binding) : null;
    }

    /**
     * Return the first keybinding for the given action and focus handle.
     *
     * GPUI resolves the handle in the previously rendered frame, so this
     * finds nothing for a handle whose element is drawn for the first time
     * in the current frame.
     */
    public static function bindingForActionIn(action:Action, focusHandle:FocusHandle, window:Window):Null<Kbd> {
        final binding = window.highestPrecedenceBindingForActionIn(action, focusHandle);
        return binding != null ? fromBinding(binding) : null;
    }

    /**
     * The `Kbd` of the highest precedence binding of `action` without
     * context, or null.
     */
    public static function globalBindingForAction(action:Action, window:Window):Null<Kbd> {
        final bindings = window.bindingsForActionInContext(action, new KeyContext());
        return bindings.length > 0 ? fromBinding(bindings[bindings.length - 1]) : null;
    }

    static function fromBinding(binding:KeyBinding):Null<Kbd> {
        if (binding.keystrokes.length == 0)
            return null;
        return new Kbd(binding.keystrokes[0].inner());
    }

    /**
     * Return the platform specific keybinding string by a `Keystroke`: macOS
     * symbols (`⌃⌥⇧⌘`) or `Ctrl+Alt+Shift+Win` elsewhere. `os` defaults to
     * the current operating system (Rust decides at compile time).
     */
    public static function format(key:Keystroke, ?os:OperatingSystem):String {
        if (os == null) os = OperatingSystem.current;
        final mac = os == Mac;
        final separator = mac ? '' : '+';

        final parts:Array<String> = [];

        // The key map order in macOS is: ⌃⌥⇧⌘
        // And in Windows is: Ctrl+Alt+Shift+Win

        if (key.modifiers.control) {
            parts.push(mac ? '⌃' : 'Ctrl');
        }
        if (key.modifiers.alt) {
            parts.push(mac ? '⌥' : 'Alt');
        }
        if (key.modifiers.shift) {
            parts.push(mac ? '⇧' : 'Shift');
        }
        if (key.modifiers.platform) {
            parts.push(mac ? '⌘' : 'Win');
        }

        final keyStr = key.key;
        final keys = switch keyStr {
            case 'ctrl': mac ? '⌃' : 'Ctrl';
            case 'alt': mac ? '⌥' : 'Alt';
            case 'shift': mac ? '⇧' : 'Shift';
            case 'cmd': mac ? '⌘' : 'Win';
            case 'space' if (mac): 'Space';
            case 'backspace': mac ? '⌫' : 'Backspace';
            case 'delete': mac ? '⌫' : 'Delete';
            case 'escape': mac ? '⎋' : 'Esc';
            case 'enter': mac ? '⏎' : 'Enter';
            case 'pagedown': 'Page Down';
            case 'pageup': 'Page Up';
            case 'left': mac ? '←' : 'Left';
            case 'right': mac ? '→' : 'Right';
            case 'up': mac ? '↑' : 'Up';
            case 'down': mac ? '↓' : 'Down';
            case _:
                if (haxe.io.Bytes.ofString(keyStr).length == 1) {
                    keyStr.toUpperCase();
                }
                else if (keyStr.length > 0) {
                    capitalizeFirst(keyStr);
                }
                else {
                    keyStr;
                }
        }

        parts.push(keys);
        return parts.join(separator);
    }

    static function capitalizeFirst(text:String):String {
        // First code point upper cased, the rest unchanged
        final codePoint = text.charCodeAt(0);
        final isSurrogate = codePoint >= 0xD800 && codePoint <= 0xDBFF;
        final first = text.substr(0, isSurrogate ? 2 : 1);
        return first.toUpperCase() + text.substr(first.length);
    }

    public function render(window:Window, cx:App):IntoElement {
        if (!appearanceValue) {
            return Kbd.format(stroke);
        }

        final theme = Theme.global(cx);
        final element = div()
            .textColor(theme.mutedForeground)
            .bg(theme.tokens.muted.background);
        if (outlineValue) {
            element.border1().borderColor(theme.border).bg(theme.tokens.background.background);
        }
        return element
            .py0p5()
            .px1()
            .minW5()
            .textCenter()
            .rounded(theme.radius * 0.5)
            .lineHeight(gpui.Prelude.relative(1.))
            .textXs()
            .whitespaceNormal()
            .flexShrink0()
            .refineStyle(kbdStyle)
            .child(Kbd.format(stroke));
    }

}
