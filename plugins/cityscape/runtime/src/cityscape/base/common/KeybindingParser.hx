// Ported from vscode src/vs/base/common/keybindingParser.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.base.common;

import cityscape.base.common.KeyCodes.KeyCodeUtils;
import cityscape.base.common.KeyCodes.ScanCodeUtils;
import cityscape.base.common.Keybindings;

private typedef ReadModifiers = {
    var remains:String;
    var ctrl:Bool;
    var shift:Bool;
    var alt:Bool;
    var meta:Bool;
    var key:String;
}

class KeybindingParser {

    static function startsWithModifier(input:String, name:String):Bool {
        if (!StringTools.startsWith(input, name) || input.length <= name.length) {
            return false;
        }
        final c = input.charAt(name.length);
        return c == '+' || c == '-';
    }

    static function _readModifiers(input:String):ReadModifiers {
        input = StringTools.trim(input.toLowerCase());

        var ctrl = false;
        var shift = false;
        var alt = false;
        var meta = false;

        var matchedModifier:Bool;

        do {
            matchedModifier = false;
            if (startsWithModifier(input, 'ctrl')) {
                ctrl = true;
                input = input.substr('ctrl-'.length);
                matchedModifier = true;
            }
            if (startsWithModifier(input, 'shift')) {
                shift = true;
                input = input.substr('shift-'.length);
                matchedModifier = true;
            }
            if (startsWithModifier(input, 'alt')) {
                alt = true;
                input = input.substr('alt-'.length);
                matchedModifier = true;
            }
            if (startsWithModifier(input, 'meta')) {
                meta = true;
                input = input.substr('meta-'.length);
                matchedModifier = true;
            }
            if (startsWithModifier(input, 'win')) {
                meta = true;
                input = input.substr('win-'.length);
                matchedModifier = true;
            }
            if (startsWithModifier(input, 'cmd')) {
                meta = true;
                input = input.substr('cmd-'.length);
                matchedModifier = true;
            }
        } while (matchedModifier);

        var key:String;

        final firstSpaceIdx = input.indexOf(' ');
        if (firstSpaceIdx > 0) {
            key = input.substring(0, firstSpaceIdx);
            input = input.substring(firstSpaceIdx);
        }
        else {
            key = input;
            input = '';
        }

        return {
            remains: input,
            ctrl: ctrl,
            shift: shift,
            alt: alt,
            meta: meta,
            key: key
        };
    }

    static function parseChord(input:String):{chord:Chord, remains:String} {
        final mods = _readModifiers(input);
        final key = mods.key;
        // /^\[([^\]]+)\]$/
        if (key.length > 2 && key.charAt(0) == '[' && key.charAt(key.length - 1) == ']' && key.substring(1, key.length - 1).indexOf(']') < 0) {
            final strScanCode = key.substring(1, key.length - 1);
            final scanCode = ScanCodeUtils.lowerCaseToEnum(strScanCode);
            return {chord: new ScanCodeChord(mods.ctrl, mods.shift, mods.alt, mods.meta, scanCode), remains: mods.remains};
        }
        final keyCode = KeyCodeUtils.fromUserSettings(key);
        return {chord: new KeyCodeChord(mods.ctrl, mods.shift, mods.alt, mods.meta, keyCode), remains: mods.remains};
    }

    public static function parseKeybinding(input:Null<String>):Null<Keybinding> {
        if (input == null || input.length == 0) {
            return null;
        }

        final chords:Array<Chord> = [];

        while (input.length > 0) {
            final r = parseChord(input);
            chords.push(r.chord);
            input = r.remains;
        }
        return (chords.length > 0 ? new Keybinding(chords) : null);
    }

}
