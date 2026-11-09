// New code for Cityscape (not a port): Monaco's keyboard events and chords
// from and to Glaze keystrokes, and the Glaze bindings of the editor's
// keybindings (AUDIT B.12, "Mapping Monaco onto Glaze").
package cityscape.view;

import cityscape.Cityscape;
import cityscape.base.common.KeyCodes.KeyCode;
import cityscape.base.common.KeyCodes.KeyCodeUtils;
import cityscape.base.common.Keybindings.KeyCodeChord;
import cityscape.base.common.Platform;
import cityscape.platform.keybinding.common.Keybinding.IKeyboardEvent;
import cityscape.platform.keybinding.common.UsLayoutResolvedKeybinding;
import glaze.App;
import glaze.KeyBinding;
import glaze.Keystroke;

/**
 * The action of a chord of the editor's keybindings: every chord used by a
 * keybinding of a context has one Glaze binding in the `CityscapeEditor`
 * key context to this action, whose `keypress` is Monaco's dispatch string
 * of the chord (`meta+K`). The editor that has the focus handles it with
 * Monaco's keybinding resolution, or lets it propagate.
 */
@:action(namespace = cityscape, noJson)
class RunKeybinding implements glaze.Action {

    /**
     * Monaco's dispatch string of the chord.
     */
    public final keypress:String;

}

/**
 * The Glaze bindings made for the keybindings of the contexts used in an
 * app (an app global): a Glaze binding per distinct chord, added when a
 * context's keybindings change. Glaze appends bindings only, so a chord
 * stays bound once bound (an unbound chord resolves to nothing and the key
 * goes on to the other bindings).
 */
class CityscapeKeyBindings {

    /**
     * The key context of the editors' root element.
     */
    public static inline final KEY_CONTEXT = 'CityscapeEditor';

    final bound = new Map<String, Bool>();
    final versions = new haxe.ds.ObjectMap<Cityscape, Int>();
    final listening = new haxe.ds.ObjectMap<Cityscape, Bool>();

    public function new() {}

    /**
     * Binds the chords of the keybindings of `context` that are not bound
     * yet in `cx`.
     */
    public static function ensure(context:Cityscape, cx:App):Void {
        var global = cx.tryGlobal(CityscapeKeyBindings);
        if (global == null) {
            global = new CityscapeKeyBindings();
            cx.setGlobal(global);
        }
        global.ensureContext(context, cx);
    }

    function ensureContext(context:Cityscape, cx:App):Void {
        // the default keybindings come with the extensions of the context
        context.editorExtensions;
        final service = context.keybindingService;
        if (!listening.exists(context)) {
            // keybindings added later (`addCommand`, `addKeybindingRule`)
            // get their Glaze binding right away, not at the next render
            listening.set(context, true);
            service.onDidUpdateKeybindings(() -> cx.update(c -> ensureContext(context, c)));
        }
        final version = service.version;
        final last = versions.get(context);
        if (last != null && last == version) {
            return;
        }
        versions.set(context, version);
        final bindings:Array<KeyBinding> = [];
        for (chord in service.getAllChords()) {
            final keystroke = KeyboardEvents.glazeKeystrokeOf(chord);
            final keypress = USLayoutResolvedKeybinding.getDispatchStr(chord);
            if (keystroke == null || keypress == null || bound.exists(keystroke)) {
                continue;
            }
            try {
                bindings.push(new KeyBinding(keystroke, new RunKeybinding(keypress), KEY_CONTEXT));
                bound.set(keystroke, true);
            }
            catch (e:Dynamic) {
                // a key Glaze cannot parse: not bound
            }
        }
        if (bindings.length > 0) {
            cx.bindKeys(bindings);
        }
    }

}

/**
 * Glaze keystrokes and Monaco keys: Glaze reports the unshifted US key of a
 * keystroke (`]` for Shift+]), like Monaco's key codes of the US layout.
 */
class KeyboardEvents {

    /**
     * The Glaze key name of a key code, or null for keys Glaze does not
     * report.
     */
    public static function glazeKeyOf(keyCode:KeyCode):Null<String> {
        if (keyCode >= KeyCode.KeyA && keyCode <= KeyCode.KeyZ) {
            return String.fromCharCode('a'.code + (keyCode - KeyCode.KeyA));
        }
        if (keyCode >= KeyCode.Digit0 && keyCode <= KeyCode.Digit9) {
            return String.fromCharCode('0'.code + (keyCode - KeyCode.Digit0));
        }
        if (keyCode >= KeyCode.Numpad0 && keyCode <= KeyCode.Numpad9) {
            return String.fromCharCode('0'.code + (keyCode - KeyCode.Numpad0));
        }
        if (keyCode >= KeyCode.F1 && keyCode <= KeyCode.F24) {
            return 'f' + (keyCode - KeyCode.F1 + 1);
        }
        return switch (keyCode) {
            case KeyCode.Backspace: 'backspace';
            case KeyCode.Tab: 'tab';
            case KeyCode.Enter: 'enter';
            case KeyCode.Escape: 'escape';
            case KeyCode.Space: 'space';
            case KeyCode.PageUp: 'pageup';
            case KeyCode.PageDown: 'pagedown';
            case KeyCode.End: 'end';
            case KeyCode.Home: 'home';
            case KeyCode.LeftArrow: 'left';
            case KeyCode.UpArrow: 'up';
            case KeyCode.RightArrow: 'right';
            case KeyCode.DownArrow: 'down';
            case KeyCode.Insert: 'insert';
            case KeyCode.Delete: 'delete';
            case KeyCode.Semicolon: ';';
            case KeyCode.Equal: '=';
            case KeyCode.Comma: ',';
            case KeyCode.Minus: '-';
            case KeyCode.Period: '.';
            case KeyCode.Slash: '/';
            case KeyCode.Backquote: '`';
            case KeyCode.BracketLeft: '[';
            case KeyCode.Backslash: '\\';
            case KeyCode.BracketRight: ']';
            case KeyCode.Quote: '\'';
            case KeyCode.NumpadMultiply: '*';
            case KeyCode.NumpadAdd: '+';
            case KeyCode.NumpadSubtract: '-';
            case KeyCode.NumpadDecimal: '.';
            case KeyCode.NumpadDivide: '/';
            case _: null;
        };
    }

    /**
     * The key code of a Glaze key name (`KeyCode.Unknown` when it has none).
     */
    public static function keyCodeOf(key:String):KeyCode {
        if (key.length == 1) {
            final c = StringTools.fastCodeAt(key, 0);
            if (c >= 'a'.code && c <= 'z'.code) {
                return KeyCode.KeyA + (c - 'a'.code);
            }
            if (c >= 'A'.code && c <= 'Z'.code) {
                return KeyCode.KeyA + (c - 'A'.code);
            }
            if (c >= '0'.code && c <= '9'.code) {
                return KeyCode.Digit0 + (c - '0'.code);
            }
        }
        if (key.length >= 2 && key.charAt(0) == 'f') {
            final n = Std.parseInt(key.substr(1));
            if (n != null && n >= 1 && n <= 24) {
                return KeyCode.F1 + (n - 1);
            }
        }
        return switch (key) {
            case 'backspace': KeyCode.Backspace;
            case 'tab': KeyCode.Tab;
            case 'enter': KeyCode.Enter;
            case 'escape': KeyCode.Escape;
            case 'space': KeyCode.Space;
            case 'pageup': KeyCode.PageUp;
            case 'pagedown': KeyCode.PageDown;
            case 'end': KeyCode.End;
            case 'home': KeyCode.Home;
            case 'left': KeyCode.LeftArrow;
            case 'up': KeyCode.UpArrow;
            case 'right': KeyCode.RightArrow;
            case 'down': KeyCode.DownArrow;
            case 'insert': KeyCode.Insert;
            case 'delete': KeyCode.Delete;
            case ';': KeyCode.Semicolon;
            case '=': KeyCode.Equal;
            case ',': KeyCode.Comma;
            case '-': KeyCode.Minus;
            case '.': KeyCode.Period;
            case '/': KeyCode.Slash;
            case '`': KeyCode.Backquote;
            case '[': KeyCode.BracketLeft;
            case '\\': KeyCode.Backslash;
            case ']': KeyCode.BracketRight;
            case '\'': KeyCode.Quote;
            case '*': KeyCode.NumpadMultiply;
            case '+': KeyCode.NumpadAdd;
            case 'control': KeyCode.Ctrl;
            case 'shift': KeyCode.Shift;
            case 'alt': KeyCode.Alt;
            case 'platform': KeyCode.Meta;
            case _: KeyCode.Unknown;
        };
    }

    /**
     * The Glaze keystroke (`ctrl-alt-shift-cmd-k`) of a Monaco chord, or null
     * when Glaze has no name for its key. Monaco's `meta` is the command key
     * on macOS and the Windows key elsewhere, Glaze's `platform` modifier.
     */
    public static function glazeKeystrokeOf(chord:KeyCodeChord):Null<String> {
        final key = glazeKeyOf(chord.keyCode);
        if (key == null) {
            return null;
        }
        var result = '';
        if (chord.ctrlKey) {
            result += 'ctrl-';
        }
        if (chord.altKey) {
            result += 'alt-';
        }
        if (chord.shiftKey) {
            result += 'shift-';
        }
        if (chord.metaKey) {
            result += 'cmd-';
        }
        return result + key;
    }

    /**
     * Monaco's chord of a Glaze keystroke.
     */
    public static function chordOf(ks:Keystroke):KeyCodeChord {
        final mods = ks.modifiers;
        return new KeyCodeChord(mods.control, mods.shift, mods.alt, mods.platform, keyCodeOf(ks.key));
    }

    /**
     * Monaco's dispatch string of a Glaze keystroke (null for a modifier
     * alone or an unknown key).
     */
    public static function dispatchStringOf(ks:Keystroke):Null<String> {
        final chord = chordOf(ks);
        if (chord.keyCode == KeyCode.Unknown) {
            return null;
        }
        return USLayoutResolvedKeybinding.getDispatchStr(chord);
    }

    /**
     * Monaco's keyboard event of a Glaze keystroke.
     */
    public static function fromKeystroke(ks:Keystroke):Null<IKeyboardEvent> {
        final chord = chordOf(ks);
        return {
            ctrlKey: chord.ctrlKey,
            shiftKey: chord.shiftKey,
            altKey: chord.altKey,
            metaKey: chord.metaKey,
            altGraphKey: false,
            keyCode: chord.keyCode,
            code: ks.key
        };
    }

    /**
     * The chord of a Monaco dispatch string (`ctrl+shift+alt+meta+Key`).
     */
    public static function chordOfDispatchString(keypress:String):KeyCodeChord {
        var rest = keypress;
        var ctrl = false;
        var shift = false;
        var alt = false;
        var meta = false;
        var matched = true;
        while (matched) {
            matched = false;
            if (StringTools.startsWith(rest, 'ctrl+') && rest.length > 5) {
                ctrl = true;
                rest = rest.substr(5);
                matched = true;
            }
            if (StringTools.startsWith(rest, 'shift+') && rest.length > 6) {
                shift = true;
                rest = rest.substr(6);
                matched = true;
            }
            if (StringTools.startsWith(rest, 'alt+') && rest.length > 4) {
                alt = true;
                rest = rest.substr(4);
                matched = true;
            }
            if (StringTools.startsWith(rest, 'meta+') && rest.length > 5) {
                meta = true;
                rest = rest.substr(5);
                matched = true;
            }
        }
        return new KeyCodeChord(ctrl, shift, alt, meta, KeyCodeUtils.fromString(rest));
    }

    /**
     * Monaco's keyboard event of a chord's dispatch string.
     */
    public static function fromDispatchString(keypress:String):IKeyboardEvent {
        final chord = chordOfDispatchString(keypress);
        return {
            ctrlKey: chord.ctrlKey,
            shiftKey: chord.shiftKey,
            altKey: chord.altKey,
            metaKey: chord.metaKey,
            altGraphKey: false,
            keyCode: chord.keyCode,
            code: KeyCodeUtils.toString(chord.keyCode)
        };
    }

    /**
     * The UI label of a chord (`⌘K`, `Ctrl+K`).
     */
    public static function labelOf(keypress:String):Null<String> {
        return new USLayoutResolvedKeybinding([chordOfDispatchString(keypress)], Platform.OS).getLabel();
    }

}
