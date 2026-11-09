// Ported from vscode src/vs/base/common/keybindings.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.base.common;

import cityscape.base.common.KeyCodes;
import cityscape.base.common.Platform.OperatingSystem;

/**
 * Binary encoding strategy:
 * ```
 *    1111 11
 *    5432 1098 7654 3210
 *    ---- CSAW KKKK KKKK
 *  C = bit 11 = ctrlCmd flag
 *  S = bit 10 = shift flag
 *  A = bit 9 = alt flag
 *  W = bit 8 = winCtrl flag
 *  K = bits 0-7 = key code
 * ```
 */
private enum abstract BinaryKeybindingsMask(Int) to Int {
    var CtrlCmd = 1 << 11;
    var Shift = 1 << 10;
    var Alt = 1 << 9;
    var WinCtrl = 1 << 8;
    /** `KeyCode` in Monaco (renamed: it would hide the `KeyCode` type here) */
    var KeyCodeMask = 0x000000FF;
}

/**
 * A chord: a `KeyCodeChord` or a `ScanCodeChord` (Monaco's `Chord` union).
 */
abstract class Chord {

    public final ctrlKey:Bool;
    public final shiftKey:Bool;
    public final altKey:Bool;
    public final metaKey:Bool;

    function new(ctrlKey:Bool, shiftKey:Bool, altKey:Bool, metaKey:Bool) {
        this.ctrlKey = ctrlKey;
        this.shiftKey = shiftKey;
        this.altKey = altKey;
        this.metaKey = metaKey;
    }

    abstract public function equals(other:Chord):Bool;

    abstract public function getHashCode():String;

    /**
     * Does this keybinding refer to the key code of a modifier and it also has the modifier flag?
     */
    abstract public function isDuplicateModifierCase():Bool;

}

/**
 * Represents a chord which uses the `keyCode` field of keyboard events.
 * A chord is a combination of keys pressed simultaneously.
 */
class KeyCodeChord extends Chord {

    public final keyCode:KeyCode;

    public function new(ctrlKey:Bool, shiftKey:Bool, altKey:Bool, metaKey:Bool, keyCode:KeyCode) {
        super(ctrlKey, shiftKey, altKey, metaKey);
        this.keyCode = keyCode;
    }

    public function equals(other:Chord):Bool {
        final o = Std.downcast(other, KeyCodeChord);
        return (
            o != null
            && this.ctrlKey == o.ctrlKey
            && this.shiftKey == o.shiftKey
            && this.altKey == o.altKey
            && this.metaKey == o.metaKey
            && this.keyCode == o.keyCode
        );
    }

    public function getHashCode():String {
        final ctrl = this.ctrlKey ? '1' : '0';
        final shift = this.shiftKey ? '1' : '0';
        final alt = this.altKey ? '1' : '0';
        final meta = this.metaKey ? '1' : '0';
        return 'K' + ctrl + shift + alt + meta + (this.keyCode : Int);
    }

    public function isModifierKey():Bool {
        return (
            this.keyCode == KeyCode.Unknown
            || this.keyCode == KeyCode.Ctrl
            || this.keyCode == KeyCode.Meta
            || this.keyCode == KeyCode.Alt
            || this.keyCode == KeyCode.Shift
        );
    }

    public function toKeybinding():Keybinding {
        return new Keybinding([this]);
    }

    public function isDuplicateModifierCase():Bool {
        return (
            (this.ctrlKey && this.keyCode == KeyCode.Ctrl)
            || (this.shiftKey && this.keyCode == KeyCode.Shift)
            || (this.altKey && this.keyCode == KeyCode.Alt)
            || (this.metaKey && this.keyCode == KeyCode.Meta)
        );
    }

}

/**
 * Represents a chord which uses the `code` field of keyboard events.
 * A chord is a combination of keys pressed simultaneously.
 */
class ScanCodeChord extends Chord {

    public final scanCode:ScanCode;

    public function new(ctrlKey:Bool, shiftKey:Bool, altKey:Bool, metaKey:Bool, scanCode:ScanCode) {
        super(ctrlKey, shiftKey, altKey, metaKey);
        this.scanCode = scanCode;
    }

    public function equals(other:Chord):Bool {
        final o = Std.downcast(other, ScanCodeChord);
        return (
            o != null
            && this.ctrlKey == o.ctrlKey
            && this.shiftKey == o.shiftKey
            && this.altKey == o.altKey
            && this.metaKey == o.metaKey
            && this.scanCode == o.scanCode
        );
    }

    public function getHashCode():String {
        final ctrl = this.ctrlKey ? '1' : '0';
        final shift = this.shiftKey ? '1' : '0';
        final alt = this.altKey ? '1' : '0';
        final meta = this.metaKey ? '1' : '0';
        return 'S' + ctrl + shift + alt + meta + (this.scanCode : Int);
    }

    public function isDuplicateModifierCase():Bool {
        return (
            (this.ctrlKey && (this.scanCode == ScanCode.ControlLeft || this.scanCode == ScanCode.ControlRight))
            || (this.shiftKey && (this.scanCode == ScanCode.ShiftLeft || this.scanCode == ScanCode.ShiftRight))
            || (this.altKey && (this.scanCode == ScanCode.AltLeft || this.scanCode == ScanCode.AltRight))
            || (this.metaKey && (this.scanCode == ScanCode.MetaLeft || this.scanCode == ScanCode.MetaRight))
        );
    }

}

/**
 * A keybinding is a sequence of chords.
 */
class Keybinding {

    public final chords:Array<Chord>;

    public function new(chords:Array<Chord>) {
        if (chords.length == 0) {
            throw 'Illegal argument: chords';
        }
        this.chords = chords;
    }

    public function getHashCode():String {
        var result = '';
        for (i in 0...this.chords.length) {
            if (i != 0) {
                result += ';';
            }
            result += this.chords[i].getHashCode();
        }
        return result;
    }

    public function equals(other:Null<Keybinding>):Bool {
        if (other == null) {
            return false;
        }
        if (this.chords.length != other.chords.length) {
            return false;
        }
        for (i in 0...this.chords.length) {
            if (!this.chords[i].equals(other.chords[i])) {
                return false;
            }
        }
        return true;
    }

}

class ResolvedChord {

    public final ctrlKey:Bool;
    public final shiftKey:Bool;
    public final altKey:Bool;
    public final metaKey:Bool;
    public final keyLabel:Null<String>;
    public final keyAriaLabel:Null<String>;

    public function new(ctrlKey:Bool, shiftKey:Bool, altKey:Bool, metaKey:Bool, keyLabel:Null<String>, keyAriaLabel:Null<String>) {
        this.ctrlKey = ctrlKey;
        this.shiftKey = shiftKey;
        this.altKey = altKey;
        this.metaKey = metaKey;
        this.keyLabel = keyLabel;
        this.keyAriaLabel = keyAriaLabel;
    }

}

/**
 * `'ctrl' | 'shift' | 'alt' | 'meta'`
 */
typedef SingleModifierChord = String;

/**
 * A resolved keybinding. Consists of one or multiple chords.
 */
abstract class ResolvedKeybinding {

    /**
     * This prints the binding in a format suitable for displaying in the UI.
     */
    abstract public function getLabel():Null<String>;

    /**
     * This prints the binding in a format suitable for ARIA.
     */
    abstract public function getAriaLabel():Null<String>;

    /**
     * This prints the binding in a format suitable for electron's accelerators.
     */
    abstract public function getElectronAccelerator():Null<String>;

    /**
     * This prints the binding in a format suitable for user settings.
     */
    abstract public function getUserSettingsLabel():Null<String>;

    /**
     * Is the user settings label reflecting the label?
     */
    abstract public function isWYSIWYG():Bool;

    /**
     * Does the keybinding consist of more than one chord?
     */
    abstract public function hasMultipleChords():Bool;

    /**
     * Returns the chords that comprise of the keybinding.
     */
    abstract public function getChords():Array<ResolvedChord>;

    /**
     * Returns the chords as strings useful for dispatching.
     * Returns null for modifier only chords.
     * @example keybinding "Shift" -> null
     * @example keybinding ("D" with shift == true) -> "shift+D"
     */
    abstract public function getDispatchChords():Array<Null<String>>;

    /**
     * Returns the modifier only chords as strings useful for dispatching.
     * Returns null for chords that contain more than one modifier or a regular key.
     * @example keybinding "Shift" -> "shift"
     * @example keybinding ("D" with shift == true") -> null
     */
    abstract public function getSingleModifierDispatchChords():Array<Null<SingleModifierChord>>;

}

/**
 * The module functions of keybindings.ts.
 */
class Keybindings {

    /**
     * Decodes a numeric keybinding (`KeyMod.CtrlCmd | KeyCode.KeyZ`, a
     * `KeyChord`), or one number per chord (Monaco's `number | number[]`:
     * pass the array as `chords`).
     */
    public static function decodeKeybinding(keybinding:Int, OS:OperatingSystem):Null<Keybinding> {
        if (keybinding == 0) {
            return null;
        }
        final firstChord = (keybinding & 0x0000FFFF);
        final secondChord = (keybinding >>> 16) & 0x0000FFFF;
        if (secondChord != 0) {
            return new Keybinding([
                createSimpleKeybinding(firstChord, OS),
                createSimpleKeybinding(secondChord, OS)
            ]);
        }
        return new Keybinding([createSimpleKeybinding(firstChord, OS)]);
    }

    /**
     * Monaco's `decodeKeybinding` with an array of numbers (one per chord).
     */
    public static function decodeKeybindingChords(keybinding:Array<Int>, OS:OperatingSystem):Null<Keybinding> {
        final chords:Array<Chord> = [];
        for (i in 0...keybinding.length) {
            chords.push(createSimpleKeybinding(keybinding[i], OS));
        }
        return new Keybinding(chords);
    }

    public static function createSimpleKeybinding(keybinding:Int, OS:OperatingSystem):KeyCodeChord {

        final ctrlCmd = (keybinding & BinaryKeybindingsMask.CtrlCmd) != 0;
        final winCtrl = (keybinding & BinaryKeybindingsMask.WinCtrl) != 0;

        final ctrlKey = (OS == OperatingSystem.Macintosh ? winCtrl : ctrlCmd);
        final shiftKey = (keybinding & BinaryKeybindingsMask.Shift) != 0;
        final altKey = (keybinding & BinaryKeybindingsMask.Alt) != 0;
        final metaKey = (OS == OperatingSystem.Macintosh ? ctrlCmd : winCtrl);
        final keyCode:KeyCode = (keybinding & BinaryKeybindingsMask.KeyCodeMask);

        return new KeyCodeChord(ctrlKey, shiftKey, altKey, metaKey, keyCode);
    }

}
