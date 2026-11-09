// Ported from vscode src/vs/platform/keybinding/common/usLayoutResolvedKeybinding.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.platform.keybinding.common;

import cityscape.base.common.KeyCodes;
import cityscape.base.common.Keybindings;
import cityscape.base.common.Platform.OperatingSystem;
import cityscape.platform.keybinding.common.ResolvedKeybindingItem.ResolvedKeybindingItemUtils;

/**
 * Do not instantiate. Use KeybindingService to get a ResolvedKeybinding seeded with information about the current kb layout.
 */
class USLayoutResolvedKeybinding extends BaseResolvedKeybinding<KeyCodeChord> {

    public function new(chords:Array<KeyCodeChord>, os:OperatingSystem) {
        super(os, chords);
    }

    function _keyCodeToUILabel(keyCode:KeyCode):Null<String> {
        if (this._os == OperatingSystem.Macintosh) {
            switch (keyCode) {
                case KeyCode.LeftArrow:
                    return '←';
                case KeyCode.UpArrow:
                    return '↑';
                case KeyCode.RightArrow:
                    return '→';
                case KeyCode.DownArrow:
                    return '↓';
                case _:
            }
        }
        return KeyCodeUtils.toString(keyCode);
    }

    function _getLabel(chord:KeyCodeChord):Null<String> {
        if (chord.isDuplicateModifierCase()) {
            return '';
        }
        return this._keyCodeToUILabel(chord.keyCode);
    }

    function _getAriaLabel(chord:KeyCodeChord):Null<String> {
        if (chord.isDuplicateModifierCase()) {
            return '';
        }
        return KeyCodeUtils.toString(chord.keyCode);
    }

    function _getElectronAccelerator(chord:KeyCodeChord):Null<String> {
        return KeyCodeUtils.toElectronAccelerator(chord.keyCode);
    }

    function _getUserSettingsLabel(chord:KeyCodeChord):Null<String> {
        if (chord.isDuplicateModifierCase()) {
            return '';
        }
        final result = KeyCodeUtils.toUserSettingsUS(chord.keyCode);
        return (result != null && result.length > 0 ? result.toLowerCase() : result);
    }

    function _isWYSIWYG(chord:KeyCodeChord):Bool {
        return true;
    }

    function _getChordDispatch(chord:KeyCodeChord):Null<String> {
        return USLayoutResolvedKeybinding.getDispatchStr(chord);
    }

    public static function getDispatchStr(chord:KeyCodeChord):Null<String> {
        if (chord.isModifierKey()) {
            return null;
        }
        var result = '';

        if (chord.ctrlKey) {
            result += 'ctrl+';
        }
        if (chord.shiftKey) {
            result += 'shift+';
        }
        if (chord.altKey) {
            result += 'alt+';
        }
        if (chord.metaKey) {
            result += 'meta+';
        }
        result += KeyCodeUtils.toString(chord.keyCode);

        return result;
    }

    function _getSingleModifierChordDispatch(keybinding:KeyCodeChord):Null<SingleModifierChord> {
        if (keybinding.keyCode == KeyCode.Ctrl && !keybinding.shiftKey && !keybinding.altKey && !keybinding.metaKey) {
            return 'ctrl';
        }
        if (keybinding.keyCode == KeyCode.Shift && !keybinding.ctrlKey && !keybinding.altKey && !keybinding.metaKey) {
            return 'shift';
        }
        if (keybinding.keyCode == KeyCode.Alt && !keybinding.ctrlKey && !keybinding.shiftKey && !keybinding.metaKey) {
            return 'alt';
        }
        if (keybinding.keyCode == KeyCode.Meta && !keybinding.ctrlKey && !keybinding.shiftKey && !keybinding.altKey) {
            return 'meta';
        }
        return null;
    }

    /**
     * *NOTE*: Check return value for `KeyCode.Unknown`.
     */
    static function _scanCodeToKeyCode(scanCode:ScanCode):KeyCode {
        KeyCodes.init();
        final immutableKeyCode = KeyCodes.IMMUTABLE_CODE_TO_KEY_CODE[scanCode];
        if (immutableKeyCode != KeyCode.DependsOnKbLayout) {
            return immutableKeyCode;
        }

        return switch (scanCode) {
            case ScanCode.KeyA: KeyCode.KeyA;
            case ScanCode.KeyB: KeyCode.KeyB;
            case ScanCode.KeyC: KeyCode.KeyC;
            case ScanCode.KeyD: KeyCode.KeyD;
            case ScanCode.KeyE: KeyCode.KeyE;
            case ScanCode.KeyF: KeyCode.KeyF;
            case ScanCode.KeyG: KeyCode.KeyG;
            case ScanCode.KeyH: KeyCode.KeyH;
            case ScanCode.KeyI: KeyCode.KeyI;
            case ScanCode.KeyJ: KeyCode.KeyJ;
            case ScanCode.KeyK: KeyCode.KeyK;
            case ScanCode.KeyL: KeyCode.KeyL;
            case ScanCode.KeyM: KeyCode.KeyM;
            case ScanCode.KeyN: KeyCode.KeyN;
            case ScanCode.KeyO: KeyCode.KeyO;
            case ScanCode.KeyP: KeyCode.KeyP;
            case ScanCode.KeyQ: KeyCode.KeyQ;
            case ScanCode.KeyR: KeyCode.KeyR;
            case ScanCode.KeyS: KeyCode.KeyS;
            case ScanCode.KeyT: KeyCode.KeyT;
            case ScanCode.KeyU: KeyCode.KeyU;
            case ScanCode.KeyV: KeyCode.KeyV;
            case ScanCode.KeyW: KeyCode.KeyW;
            case ScanCode.KeyX: KeyCode.KeyX;
            case ScanCode.KeyY: KeyCode.KeyY;
            case ScanCode.KeyZ: KeyCode.KeyZ;
            case ScanCode.Digit1: KeyCode.Digit1;
            case ScanCode.Digit2: KeyCode.Digit2;
            case ScanCode.Digit3: KeyCode.Digit3;
            case ScanCode.Digit4: KeyCode.Digit4;
            case ScanCode.Digit5: KeyCode.Digit5;
            case ScanCode.Digit6: KeyCode.Digit6;
            case ScanCode.Digit7: KeyCode.Digit7;
            case ScanCode.Digit8: KeyCode.Digit8;
            case ScanCode.Digit9: KeyCode.Digit9;
            case ScanCode.Digit0: KeyCode.Digit0;
            case ScanCode.Minus: KeyCode.Minus;
            case ScanCode.Equal: KeyCode.Equal;
            case ScanCode.BracketLeft: KeyCode.BracketLeft;
            case ScanCode.BracketRight: KeyCode.BracketRight;
            case ScanCode.Backslash: KeyCode.Backslash;
            case ScanCode.IntlHash: KeyCode.Unknown; // missing
            case ScanCode.Semicolon: KeyCode.Semicolon;
            case ScanCode.Quote: KeyCode.Quote;
            case ScanCode.Backquote: KeyCode.Backquote;
            case ScanCode.Comma: KeyCode.Comma;
            case ScanCode.Period: KeyCode.Period;
            case ScanCode.Slash: KeyCode.Slash;
            case ScanCode.IntlBackslash: KeyCode.IntlBackslash;
            case _: KeyCode.Unknown;
        };
    }

    static function _toKeyCodeChord(chord:Null<Chord>):Null<KeyCodeChord> {
        if (chord == null) {
            return null;
        }
        final keyCodeChord = Std.downcast(chord, KeyCodeChord);
        if (keyCodeChord != null) {
            return keyCodeChord;
        }
        final scanCodeChord:ScanCodeChord = cast chord;
        final keyCode = _scanCodeToKeyCode(scanCodeChord.scanCode);
        if (keyCode == KeyCode.Unknown) {
            return null;
        }
        return new KeyCodeChord(chord.ctrlKey, chord.shiftKey, chord.altKey, chord.metaKey, keyCode);
    }

    public static function resolveKeybinding(keybinding:Keybinding, os:OperatingSystem):Array<USLayoutResolvedKeybinding> {
        final chords:Array<KeyCodeChord> = ResolvedKeybindingItemUtils.toEmptyArrayIfContainsNull([for (chord in keybinding.chords) _toKeyCodeChord(chord)]);
        if (chords.length > 0) {
            return [new USLayoutResolvedKeybinding(chords, os)];
        }
        return [];
    }

}
