// Ported from vscode src/vs/base/common/keyCodes.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.base.common;

/**
 * Virtual Key Codes, the value does not hold any inherent meaning.
 * Inspired somewhat from https://msdn.microsoft.com/en-us/library/windows/desktop/dd375731(v=vs.85).aspx
 * But these are "more general", as they should work across browsers & OS`s.
 */
enum abstract KeyCode(Int) from Int to Int {
    var DependsOnKbLayout = -1;
    var Unknown = 0;
    var Backspace = 1;
    var Tab = 2;
    var Enter = 3;
    var Shift = 4;
    var Ctrl = 5;
    var Alt = 6;
    var PauseBreak = 7;
    var CapsLock = 8;
    var Escape = 9;
    var Space = 10;
    var PageUp = 11;
    var PageDown = 12;
    var End = 13;
    var Home = 14;
    var LeftArrow = 15;
    var UpArrow = 16;
    var RightArrow = 17;
    var DownArrow = 18;
    var Insert = 19;
    var Delete = 20;
    var Digit0 = 21;
    var Digit1 = 22;
    var Digit2 = 23;
    var Digit3 = 24;
    var Digit4 = 25;
    var Digit5 = 26;
    var Digit6 = 27;
    var Digit7 = 28;
    var Digit8 = 29;
    var Digit9 = 30;
    var KeyA = 31;
    var KeyB = 32;
    var KeyC = 33;
    var KeyD = 34;
    var KeyE = 35;
    var KeyF = 36;
    var KeyG = 37;
    var KeyH = 38;
    var KeyI = 39;
    var KeyJ = 40;
    var KeyK = 41;
    var KeyL = 42;
    var KeyM = 43;
    var KeyN = 44;
    var KeyO = 45;
    var KeyP = 46;
    var KeyQ = 47;
    var KeyR = 48;
    var KeyS = 49;
    var KeyT = 50;
    var KeyU = 51;
    var KeyV = 52;
    var KeyW = 53;
    var KeyX = 54;
    var KeyY = 55;
    var KeyZ = 56;
    var Meta = 57;
    var ContextMenu = 58;
    var F1 = 59;
    var F2 = 60;
    var F3 = 61;
    var F4 = 62;
    var F5 = 63;
    var F6 = 64;
    var F7 = 65;
    var F8 = 66;
    var F9 = 67;
    var F10 = 68;
    var F11 = 69;
    var F12 = 70;
    var F13 = 71;
    var F14 = 72;
    var F15 = 73;
    var F16 = 74;
    var F17 = 75;
    var F18 = 76;
    var F19 = 77;
    var F20 = 78;
    var F21 = 79;
    var F22 = 80;
    var F23 = 81;
    var F24 = 82;
    var NumLock = 83;
    var ScrollLock = 84;
    var Semicolon = 85;
    var Equal = 86;
    var Comma = 87;
    var Minus = 88;
    var Period = 89;
    var Slash = 90;
    var Backquote = 91;
    var BracketLeft = 92;
    var Backslash = 93;
    var BracketRight = 94;
    var Quote = 95;
    var OEM_8 = 96;
    var IntlBackslash = 97;
    var Numpad0 = 98;
    var Numpad1 = 99;
    var Numpad2 = 100;
    var Numpad3 = 101;
    var Numpad4 = 102;
    var Numpad5 = 103;
    var Numpad6 = 104;
    var Numpad7 = 105;
    var Numpad8 = 106;
    var Numpad9 = 107;
    var NumpadMultiply = 108;
    var NumpadAdd = 109;
    var NUMPAD_SEPARATOR = 110;
    var NumpadSubtract = 111;
    var NumpadDecimal = 112;
    var NumpadDivide = 113;
    var KEY_IN_COMPOSITION = 114;
    var ABNT_C1 = 115;
    var ABNT_C2 = 116;
    var AudioVolumeMute = 117;
    var AudioVolumeUp = 118;
    var AudioVolumeDown = 119;
    var BrowserSearch = 120;
    var BrowserHome = 121;
    var BrowserBack = 122;
    var BrowserForward = 123;
    var MediaTrackNext = 124;
    var MediaTrackPrevious = 125;
    var MediaStop = 126;
    var MediaPlayPause = 127;
    var LaunchMediaPlayer = 128;
    var LaunchMail = 129;
    var LaunchApp2 = 130;
    var Clear = 131;
    var MAX_VALUE = 132;

    @:op(A < B) static function lt(a:KeyCode, b:KeyCode):Bool;
    @:op(A <= B) static function lte(a:KeyCode, b:KeyCode):Bool;
    @:op(A > B) static function gt(a:KeyCode, b:KeyCode):Bool;
    @:op(A >= B) static function gte(a:KeyCode, b:KeyCode):Bool;
    @:op(A - B) static function sub(a:KeyCode, b:KeyCode):Int;
    @:op(A + B) static function addInt(a:KeyCode, b:Int):KeyCode;
    @:op(A - B) static function subInt(a:KeyCode, b:Int):KeyCode;
}

/**
 * keyboardEvent.code
 */
enum abstract ScanCode(Int) from Int to Int {
    var DependsOnKbLayout = -1;
    var None = 0;
    var Hyper = 1;
    var Super = 2;
    var Fn = 3;
    var FnLock = 4;
    var Suspend = 5;
    var Resume = 6;
    var Turbo = 7;
    var Sleep = 8;
    var WakeUp = 9;
    var KeyA = 10;
    var KeyB = 11;
    var KeyC = 12;
    var KeyD = 13;
    var KeyE = 14;
    var KeyF = 15;
    var KeyG = 16;
    var KeyH = 17;
    var KeyI = 18;
    var KeyJ = 19;
    var KeyK = 20;
    var KeyL = 21;
    var KeyM = 22;
    var KeyN = 23;
    var KeyO = 24;
    var KeyP = 25;
    var KeyQ = 26;
    var KeyR = 27;
    var KeyS = 28;
    var KeyT = 29;
    var KeyU = 30;
    var KeyV = 31;
    var KeyW = 32;
    var KeyX = 33;
    var KeyY = 34;
    var KeyZ = 35;
    var Digit1 = 36;
    var Digit2 = 37;
    var Digit3 = 38;
    var Digit4 = 39;
    var Digit5 = 40;
    var Digit6 = 41;
    var Digit7 = 42;
    var Digit8 = 43;
    var Digit9 = 44;
    var Digit0 = 45;
    var Enter = 46;
    var Escape = 47;
    var Backspace = 48;
    var Tab = 49;
    var Space = 50;
    var Minus = 51;
    var Equal = 52;
    var BracketLeft = 53;
    var BracketRight = 54;
    var Backslash = 55;
    var IntlHash = 56;
    var Semicolon = 57;
    var Quote = 58;
    var Backquote = 59;
    var Comma = 60;
    var Period = 61;
    var Slash = 62;
    var CapsLock = 63;
    var F1 = 64;
    var F2 = 65;
    var F3 = 66;
    var F4 = 67;
    var F5 = 68;
    var F6 = 69;
    var F7 = 70;
    var F8 = 71;
    var F9 = 72;
    var F10 = 73;
    var F11 = 74;
    var F12 = 75;
    var PrintScreen = 76;
    var ScrollLock = 77;
    var Pause = 78;
    var Insert = 79;
    var Home = 80;
    var PageUp = 81;
    var Delete = 82;
    var End = 83;
    var PageDown = 84;
    var ArrowRight = 85;
    var ArrowLeft = 86;
    var ArrowDown = 87;
    var ArrowUp = 88;
    var NumLock = 89;
    var NumpadDivide = 90;
    var NumpadMultiply = 91;
    var NumpadSubtract = 92;
    var NumpadAdd = 93;
    var NumpadEnter = 94;
    var Numpad1 = 95;
    var Numpad2 = 96;
    var Numpad3 = 97;
    var Numpad4 = 98;
    var Numpad5 = 99;
    var Numpad6 = 100;
    var Numpad7 = 101;
    var Numpad8 = 102;
    var Numpad9 = 103;
    var Numpad0 = 104;
    var NumpadDecimal = 105;
    var IntlBackslash = 106;
    var ContextMenu = 107;
    var Power = 108;
    var NumpadEqual = 109;
    var F13 = 110;
    var F14 = 111;
    var F15 = 112;
    var F16 = 113;
    var F17 = 114;
    var F18 = 115;
    var F19 = 116;
    var F20 = 117;
    var F21 = 118;
    var F22 = 119;
    var F23 = 120;
    var F24 = 121;
    var Open = 122;
    var Help = 123;
    var Select = 124;
    var Again = 125;
    var Undo = 126;
    var Cut = 127;
    var Copy = 128;
    var Paste = 129;
    var Find = 130;
    var AudioVolumeMute = 131;
    var AudioVolumeUp = 132;
    var AudioVolumeDown = 133;
    var NumpadComma = 134;
    var IntlRo = 135;
    var KanaMode = 136;
    var IntlYen = 137;
    var Convert = 138;
    var NonConvert = 139;
    var Lang1 = 140;
    var Lang2 = 141;
    var Lang3 = 142;
    var Lang4 = 143;
    var Lang5 = 144;
    var Abort = 145;
    var Props = 146;
    var NumpadParenLeft = 147;
    var NumpadParenRight = 148;
    var NumpadBackspace = 149;
    var NumpadMemoryStore = 150;
    var NumpadMemoryRecall = 151;
    var NumpadMemoryClear = 152;
    var NumpadMemoryAdd = 153;
    var NumpadMemorySubtract = 154;
    var NumpadClear = 155;
    var NumpadClearEntry = 156;
    var ControlLeft = 157;
    var ShiftLeft = 158;
    var AltLeft = 159;
    var MetaLeft = 160;
    var ControlRight = 161;
    var ShiftRight = 162;
    var AltRight = 163;
    var MetaRight = 164;
    var BrightnessUp = 165;
    var BrightnessDown = 166;
    var MediaPlay = 167;
    var MediaRecord = 168;
    var MediaFastForward = 169;
    var MediaRewind = 170;
    var MediaTrackNext = 171;
    var MediaTrackPrevious = 172;
    var MediaStop = 173;
    var Eject = 174;
    var MediaPlayPause = 175;
    var MediaSelect = 176;
    var LaunchMail = 177;
    var LaunchApp2 = 178;
    var LaunchApp1 = 179;
    var SelectTask = 180;
    var LaunchScreenSaver = 181;
    var BrowserSearch = 182;
    var BrowserHome = 183;
    var BrowserBack = 184;
    var BrowserForward = 185;
    var BrowserStop = 186;
    var BrowserRefresh = 187;
    var BrowserFavorites = 188;
    var ZoomToggle = 189;
    var MailReply = 190;
    var MailForward = 191;
    var MailSend = 192;
    var MAX_VALUE = 193;

    @:op(A < B) static function lt(a:ScanCode, b:ScanCode):Bool;
    @:op(A <= B) static function lte(a:ScanCode, b:ScanCode):Bool;
    @:op(A > B) static function gt(a:ScanCode, b:ScanCode):Bool;
    @:op(A >= B) static function gte(a:ScanCode, b:ScanCode):Bool;
    @:op(A - B) static function sub(a:ScanCode, b:ScanCode):Int;
    @:op(A + B) static function addInt(a:ScanCode, b:Int):ScanCode;
    @:op(A - B) static function subInt(a:ScanCode, b:Int):ScanCode;
}

enum abstract KeyMod(Int) from Int to Int {
    var CtrlCmd = 1 << 11;
    var Shift = 1 << 10;
    var Alt = 1 << 9;
    var WinCtrl = 1 << 8;
}

private class KeyCodeStrMap {

    public final _keyCodeToStr:Array<Null<String>> = [];
    public final _strToKeyCode:Map<String, KeyCode> = new Map();

    public function new() {}

    public function define(keyCode:KeyCode, str:String):Void {
        this._keyCodeToStr[keyCode] = str;
        this._strToKeyCode.set(str.toLowerCase(), keyCode);
    }

    public function keyCodeToStr(keyCode:KeyCode):Null<String> {
        return keyCode >= 0 && keyCode < this._keyCodeToStr.length ? this._keyCodeToStr[keyCode] : null;
    }

    public function strToKeyCode(str:String):KeyCode {
        final keyCode = this._strToKeyCode.get(str.toLowerCase());
        return keyCode != null ? keyCode : KeyCode.Unknown;
    }

}

/**
 * The tables of keyCodes.ts (built once, immutable), and the module
 * functions: `KeyCodes.KeyChord`, `ScanCodeUtils`, `KeyCodeUtils`.
 */
class KeyCodes {

    static var _initialized = false;
    static final uiMap = new KeyCodeStrMap();
    static final userSettingsUSMap = new KeyCodeStrMap();
    static final userSettingsGeneralMap = new KeyCodeStrMap();
    static final scanCodeIntToStr:Array<Null<String>> = [];
    static final scanCodeStrToInt:Map<String, Int> = new Map();
    static final scanCodeLowerCaseStrToInt:Map<String, Int> = new Map();

    /**
     * -1 if a ScanCode => KeyCode mapping depends on kb layout.
     */
    public static final IMMUTABLE_CODE_TO_KEY_CODE:Array<KeyCode> = [];

    /**
     * -1 if a KeyCode => ScanCode mapping depends on kb layout.
     */
    public static final IMMUTABLE_KEY_CODE_TO_CODE:Array<ScanCode> = [];

    /**
     * The browser's `keyCode` of a keyboard event to a `KeyCode`.
     */
    public static final EVENT_KEY_CODE_MAP:Map<Int, KeyCode> = new Map();

    public static function KeyChord(firstPart:Int, secondPart:Int):Int {
        final chordPart = ((secondPart & 0x0000FFFF) << 16);
        return (firstPart | chordPart);
    }

    // immutable, scanCode, scanCodeStr, keyCode, keyCodeStr, eventKeyCode, vkey, usUserSettingsLabel, generalUserSettingsLabel
    static final MAPPINGS:Array<Array<Any>> = [
        [1, ScanCode.None, 'None', KeyCode.Unknown, 'unknown', 0, 'VK_UNKNOWN', '', ''],
        [1, ScanCode.Hyper, 'Hyper', KeyCode.Unknown, '', 0, '', '', ''],
        [1, ScanCode.Super, 'Super', KeyCode.Unknown, '', 0, '', '', ''],
        [1, ScanCode.Fn, 'Fn', KeyCode.Unknown, '', 0, '', '', ''],
        [1, ScanCode.FnLock, 'FnLock', KeyCode.Unknown, '', 0, '', '', ''],
        [1, ScanCode.Suspend, 'Suspend', KeyCode.Unknown, '', 0, '', '', ''],
        [1, ScanCode.Resume, 'Resume', KeyCode.Unknown, '', 0, '', '', ''],
        [1, ScanCode.Turbo, 'Turbo', KeyCode.Unknown, '', 0, '', '', ''],
        [1, ScanCode.Sleep, 'Sleep', KeyCode.Unknown, '', 0, 'VK_SLEEP', '', ''],
        [1, ScanCode.WakeUp, 'WakeUp', KeyCode.Unknown, '', 0, '', '', ''],
        [0, ScanCode.KeyA, 'KeyA', KeyCode.KeyA, 'A', 65, 'VK_A', '', ''],
        [0, ScanCode.KeyB, 'KeyB', KeyCode.KeyB, 'B', 66, 'VK_B', '', ''],
        [0, ScanCode.KeyC, 'KeyC', KeyCode.KeyC, 'C', 67, 'VK_C', '', ''],
        [0, ScanCode.KeyD, 'KeyD', KeyCode.KeyD, 'D', 68, 'VK_D', '', ''],
        [0, ScanCode.KeyE, 'KeyE', KeyCode.KeyE, 'E', 69, 'VK_E', '', ''],
        [0, ScanCode.KeyF, 'KeyF', KeyCode.KeyF, 'F', 70, 'VK_F', '', ''],
        [0, ScanCode.KeyG, 'KeyG', KeyCode.KeyG, 'G', 71, 'VK_G', '', ''],
        [0, ScanCode.KeyH, 'KeyH', KeyCode.KeyH, 'H', 72, 'VK_H', '', ''],
        [0, ScanCode.KeyI, 'KeyI', KeyCode.KeyI, 'I', 73, 'VK_I', '', ''],
        [0, ScanCode.KeyJ, 'KeyJ', KeyCode.KeyJ, 'J', 74, 'VK_J', '', ''],
        [0, ScanCode.KeyK, 'KeyK', KeyCode.KeyK, 'K', 75, 'VK_K', '', ''],
        [0, ScanCode.KeyL, 'KeyL', KeyCode.KeyL, 'L', 76, 'VK_L', '', ''],
        [0, ScanCode.KeyM, 'KeyM', KeyCode.KeyM, 'M', 77, 'VK_M', '', ''],
        [0, ScanCode.KeyN, 'KeyN', KeyCode.KeyN, 'N', 78, 'VK_N', '', ''],
        [0, ScanCode.KeyO, 'KeyO', KeyCode.KeyO, 'O', 79, 'VK_O', '', ''],
        [0, ScanCode.KeyP, 'KeyP', KeyCode.KeyP, 'P', 80, 'VK_P', '', ''],
        [0, ScanCode.KeyQ, 'KeyQ', KeyCode.KeyQ, 'Q', 81, 'VK_Q', '', ''],
        [0, ScanCode.KeyR, 'KeyR', KeyCode.KeyR, 'R', 82, 'VK_R', '', ''],
        [0, ScanCode.KeyS, 'KeyS', KeyCode.KeyS, 'S', 83, 'VK_S', '', ''],
        [0, ScanCode.KeyT, 'KeyT', KeyCode.KeyT, 'T', 84, 'VK_T', '', ''],
        [0, ScanCode.KeyU, 'KeyU', KeyCode.KeyU, 'U', 85, 'VK_U', '', ''],
        [0, ScanCode.KeyV, 'KeyV', KeyCode.KeyV, 'V', 86, 'VK_V', '', ''],
        [0, ScanCode.KeyW, 'KeyW', KeyCode.KeyW, 'W', 87, 'VK_W', '', ''],
        [0, ScanCode.KeyX, 'KeyX', KeyCode.KeyX, 'X', 88, 'VK_X', '', ''],
        [0, ScanCode.KeyY, 'KeyY', KeyCode.KeyY, 'Y', 89, 'VK_Y', '', ''],
        [0, ScanCode.KeyZ, 'KeyZ', KeyCode.KeyZ, 'Z', 90, 'VK_Z', '', ''],
        [0, ScanCode.Digit1, 'Digit1', KeyCode.Digit1, '1', 49, 'VK_1', '', ''],
        [0, ScanCode.Digit2, 'Digit2', KeyCode.Digit2, '2', 50, 'VK_2', '', ''],
        [0, ScanCode.Digit3, 'Digit3', KeyCode.Digit3, '3', 51, 'VK_3', '', ''],
        [0, ScanCode.Digit4, 'Digit4', KeyCode.Digit4, '4', 52, 'VK_4', '', ''],
        [0, ScanCode.Digit5, 'Digit5', KeyCode.Digit5, '5', 53, 'VK_5', '', ''],
        [0, ScanCode.Digit6, 'Digit6', KeyCode.Digit6, '6', 54, 'VK_6', '', ''],
        [0, ScanCode.Digit7, 'Digit7', KeyCode.Digit7, '7', 55, 'VK_7', '', ''],
        [0, ScanCode.Digit8, 'Digit8', KeyCode.Digit8, '8', 56, 'VK_8', '', ''],
        [0, ScanCode.Digit9, 'Digit9', KeyCode.Digit9, '9', 57, 'VK_9', '', ''],
        [0, ScanCode.Digit0, 'Digit0', KeyCode.Digit0, '0', 48, 'VK_0', '', ''],
        [1, ScanCode.Enter, 'Enter', KeyCode.Enter, 'Enter', 13, 'VK_RETURN', '', ''],
        [1, ScanCode.Escape, 'Escape', KeyCode.Escape, 'Escape', 27, 'VK_ESCAPE', '', ''],
        [1, ScanCode.Backspace, 'Backspace', KeyCode.Backspace, 'Backspace', 8, 'VK_BACK', '', ''],
        [1, ScanCode.Tab, 'Tab', KeyCode.Tab, 'Tab', 9, 'VK_TAB', '', ''],
        [1, ScanCode.Space, 'Space', KeyCode.Space, 'Space', 32, 'VK_SPACE', '', ''],
        [0, ScanCode.Minus, 'Minus', KeyCode.Minus, '-', 189, 'VK_OEM_MINUS', '-', 'OEM_MINUS'],
        [0, ScanCode.Equal, 'Equal', KeyCode.Equal, '=', 187, 'VK_OEM_PLUS', '=', 'OEM_PLUS'],
        [0, ScanCode.BracketLeft, 'BracketLeft', KeyCode.BracketLeft, '[', 219, 'VK_OEM_4', '[', 'OEM_4'],
        [0, ScanCode.BracketRight, 'BracketRight', KeyCode.BracketRight, ']', 221, 'VK_OEM_6', ']', 'OEM_6'],
        [0, ScanCode.Backslash, 'Backslash', KeyCode.Backslash, '\\', 220, 'VK_OEM_5', '\\', 'OEM_5'],
        [0, ScanCode.IntlHash, 'IntlHash', KeyCode.Unknown, '', 0, '', '', ''],
        [0, ScanCode.Semicolon, 'Semicolon', KeyCode.Semicolon, ';', 186, 'VK_OEM_1', ';', 'OEM_1'],
        [0, ScanCode.Quote, 'Quote', KeyCode.Quote, '\'', 222, 'VK_OEM_7', '\'', 'OEM_7'],
        [0, ScanCode.Backquote, 'Backquote', KeyCode.Backquote, '`', 192, 'VK_OEM_3', '`', 'OEM_3'],
        [0, ScanCode.Comma, 'Comma', KeyCode.Comma, ',', 188, 'VK_OEM_COMMA', ',', 'OEM_COMMA'],
        [0, ScanCode.Period, 'Period', KeyCode.Period, '.', 190, 'VK_OEM_PERIOD', '.', 'OEM_PERIOD'],
        [0, ScanCode.Slash, 'Slash', KeyCode.Slash, '/', 191, 'VK_OEM_2', '/', 'OEM_2'],
        [1, ScanCode.CapsLock, 'CapsLock', KeyCode.CapsLock, 'CapsLock', 20, 'VK_CAPITAL', '', ''],
        [1, ScanCode.F1, 'F1', KeyCode.F1, 'F1', 112, 'VK_F1', '', ''],
        [1, ScanCode.F2, 'F2', KeyCode.F2, 'F2', 113, 'VK_F2', '', ''],
        [1, ScanCode.F3, 'F3', KeyCode.F3, 'F3', 114, 'VK_F3', '', ''],
        [1, ScanCode.F4, 'F4', KeyCode.F4, 'F4', 115, 'VK_F4', '', ''],
        [1, ScanCode.F5, 'F5', KeyCode.F5, 'F5', 116, 'VK_F5', '', ''],
        [1, ScanCode.F6, 'F6', KeyCode.F6, 'F6', 117, 'VK_F6', '', ''],
        [1, ScanCode.F7, 'F7', KeyCode.F7, 'F7', 118, 'VK_F7', '', ''],
        [1, ScanCode.F8, 'F8', KeyCode.F8, 'F8', 119, 'VK_F8', '', ''],
        [1, ScanCode.F9, 'F9', KeyCode.F9, 'F9', 120, 'VK_F9', '', ''],
        [1, ScanCode.F10, 'F10', KeyCode.F10, 'F10', 121, 'VK_F10', '', ''],
        [1, ScanCode.F11, 'F11', KeyCode.F11, 'F11', 122, 'VK_F11', '', ''],
        [1, ScanCode.F12, 'F12', KeyCode.F12, 'F12', 123, 'VK_F12', '', ''],
        [1, ScanCode.PrintScreen, 'PrintScreen', KeyCode.Unknown, '', 0, '', '', ''],
        [1, ScanCode.ScrollLock, 'ScrollLock', KeyCode.ScrollLock, 'ScrollLock', 145, 'VK_SCROLL', '', ''],
        [1, ScanCode.Pause, 'Pause', KeyCode.PauseBreak, 'PauseBreak', 19, 'VK_PAUSE', '', ''],
        [1, ScanCode.Insert, 'Insert', KeyCode.Insert, 'Insert', 45, 'VK_INSERT', '', ''],
        [1, ScanCode.Home, 'Home', KeyCode.Home, 'Home', 36, 'VK_HOME', '', ''],
        [1, ScanCode.PageUp, 'PageUp', KeyCode.PageUp, 'PageUp', 33, 'VK_PRIOR', '', ''],
        [1, ScanCode.Delete, 'Delete', KeyCode.Delete, 'Delete', 46, 'VK_DELETE', '', ''],
        [1, ScanCode.End, 'End', KeyCode.End, 'End', 35, 'VK_END', '', ''],
        [1, ScanCode.PageDown, 'PageDown', KeyCode.PageDown, 'PageDown', 34, 'VK_NEXT', '', ''],
        [1, ScanCode.ArrowRight, 'ArrowRight', KeyCode.RightArrow, 'RightArrow', 39, 'VK_RIGHT', 'Right', ''],
        [1, ScanCode.ArrowLeft, 'ArrowLeft', KeyCode.LeftArrow, 'LeftArrow', 37, 'VK_LEFT', 'Left', ''],
        [1, ScanCode.ArrowDown, 'ArrowDown', KeyCode.DownArrow, 'DownArrow', 40, 'VK_DOWN', 'Down', ''],
        [1, ScanCode.ArrowUp, 'ArrowUp', KeyCode.UpArrow, 'UpArrow', 38, 'VK_UP', 'Up', ''],
        [1, ScanCode.NumLock, 'NumLock', KeyCode.NumLock, 'NumLock', 144, 'VK_NUMLOCK', '', ''],
        [1, ScanCode.NumpadDivide, 'NumpadDivide', KeyCode.NumpadDivide, 'NumPad_Divide', 111, 'VK_DIVIDE', '', ''],
        [1, ScanCode.NumpadMultiply, 'NumpadMultiply', KeyCode.NumpadMultiply, 'NumPad_Multiply', 106, 'VK_MULTIPLY', '', ''],
        [1, ScanCode.NumpadSubtract, 'NumpadSubtract', KeyCode.NumpadSubtract, 'NumPad_Subtract', 109, 'VK_SUBTRACT', '', ''],
        [1, ScanCode.NumpadAdd, 'NumpadAdd', KeyCode.NumpadAdd, 'NumPad_Add', 107, 'VK_ADD', '', ''],
        [1, ScanCode.NumpadEnter, 'NumpadEnter', KeyCode.Enter, '', 0, '', '', ''],
        [1, ScanCode.Numpad1, 'Numpad1', KeyCode.Numpad1, 'NumPad1', 97, 'VK_NUMPAD1', '', ''],
        [1, ScanCode.Numpad2, 'Numpad2', KeyCode.Numpad2, 'NumPad2', 98, 'VK_NUMPAD2', '', ''],
        [1, ScanCode.Numpad3, 'Numpad3', KeyCode.Numpad3, 'NumPad3', 99, 'VK_NUMPAD3', '', ''],
        [1, ScanCode.Numpad4, 'Numpad4', KeyCode.Numpad4, 'NumPad4', 100, 'VK_NUMPAD4', '', ''],
        [1, ScanCode.Numpad5, 'Numpad5', KeyCode.Numpad5, 'NumPad5', 101, 'VK_NUMPAD5', '', ''],
        [1, ScanCode.Numpad6, 'Numpad6', KeyCode.Numpad6, 'NumPad6', 102, 'VK_NUMPAD6', '', ''],
        [1, ScanCode.Numpad7, 'Numpad7', KeyCode.Numpad7, 'NumPad7', 103, 'VK_NUMPAD7', '', ''],
        [1, ScanCode.Numpad8, 'Numpad8', KeyCode.Numpad8, 'NumPad8', 104, 'VK_NUMPAD8', '', ''],
        [1, ScanCode.Numpad9, 'Numpad9', KeyCode.Numpad9, 'NumPad9', 105, 'VK_NUMPAD9', '', ''],
        [1, ScanCode.Numpad0, 'Numpad0', KeyCode.Numpad0, 'NumPad0', 96, 'VK_NUMPAD0', '', ''],
        [1, ScanCode.NumpadDecimal, 'NumpadDecimal', KeyCode.NumpadDecimal, 'NumPad_Decimal', 110, 'VK_DECIMAL', '', ''],
        [0, ScanCode.IntlBackslash, 'IntlBackslash', KeyCode.IntlBackslash, 'OEM_102', 226, 'VK_OEM_102', '', ''],
        [1, ScanCode.ContextMenu, 'ContextMenu', KeyCode.ContextMenu, 'ContextMenu', 93, '', '', ''],
        [1, ScanCode.Power, 'Power', KeyCode.Unknown, '', 0, '', '', ''],
        [1, ScanCode.NumpadEqual, 'NumpadEqual', KeyCode.Unknown, '', 0, '', '', ''],
        [1, ScanCode.F13, 'F13', KeyCode.F13, 'F13', 124, 'VK_F13', '', ''],
        [1, ScanCode.F14, 'F14', KeyCode.F14, 'F14', 125, 'VK_F14', '', ''],
        [1, ScanCode.F15, 'F15', KeyCode.F15, 'F15', 126, 'VK_F15', '', ''],
        [1, ScanCode.F16, 'F16', KeyCode.F16, 'F16', 127, 'VK_F16', '', ''],
        [1, ScanCode.F17, 'F17', KeyCode.F17, 'F17', 128, 'VK_F17', '', ''],
        [1, ScanCode.F18, 'F18', KeyCode.F18, 'F18', 129, 'VK_F18', '', ''],
        [1, ScanCode.F19, 'F19', KeyCode.F19, 'F19', 130, 'VK_F19', '', ''],
        [1, ScanCode.F20, 'F20', KeyCode.F20, 'F20', 131, 'VK_F20', '', ''],
        [1, ScanCode.F21, 'F21', KeyCode.F21, 'F21', 132, 'VK_F21', '', ''],
        [1, ScanCode.F22, 'F22', KeyCode.F22, 'F22', 133, 'VK_F22', '', ''],
        [1, ScanCode.F23, 'F23', KeyCode.F23, 'F23', 134, 'VK_F23', '', ''],
        [1, ScanCode.F24, 'F24', KeyCode.F24, 'F24', 135, 'VK_F24', '', ''],
        [1, ScanCode.Open, 'Open', KeyCode.Unknown, '', 0, '', '', ''],
        [1, ScanCode.Help, 'Help', KeyCode.Unknown, '', 0, '', '', ''],
        [1, ScanCode.Select, 'Select', KeyCode.Unknown, '', 0, '', '', ''],
        [1, ScanCode.Again, 'Again', KeyCode.Unknown, '', 0, '', '', ''],
        [1, ScanCode.Undo, 'Undo', KeyCode.Unknown, '', 0, '', '', ''],
        [1, ScanCode.Cut, 'Cut', KeyCode.Unknown, '', 0, '', '', ''],
        [1, ScanCode.Copy, 'Copy', KeyCode.Unknown, '', 0, '', '', ''],
        [1, ScanCode.Paste, 'Paste', KeyCode.Unknown, '', 0, '', '', ''],
        [1, ScanCode.Find, 'Find', KeyCode.Unknown, '', 0, '', '', ''],
        [1, ScanCode.AudioVolumeMute, 'AudioVolumeMute', KeyCode.AudioVolumeMute, 'AudioVolumeMute', 173, 'VK_VOLUME_MUTE', '', ''],
        [1, ScanCode.AudioVolumeUp, 'AudioVolumeUp', KeyCode.AudioVolumeUp, 'AudioVolumeUp', 175, 'VK_VOLUME_UP', '', ''],
        [1, ScanCode.AudioVolumeDown, 'AudioVolumeDown', KeyCode.AudioVolumeDown, 'AudioVolumeDown', 174, 'VK_VOLUME_DOWN', '', ''],
        [1, ScanCode.NumpadComma, 'NumpadComma', KeyCode.NUMPAD_SEPARATOR, 'NumPad_Separator', 108, 'VK_SEPARATOR', '', ''],
        [0, ScanCode.IntlRo, 'IntlRo', KeyCode.ABNT_C1, 'ABNT_C1', 193, 'VK_ABNT_C1', '', ''],
        [1, ScanCode.KanaMode, 'KanaMode', KeyCode.Unknown, '', 0, '', '', ''],
        [0, ScanCode.IntlYen, 'IntlYen', KeyCode.Unknown, '', 0, '', '', ''],
        [1, ScanCode.Convert, 'Convert', KeyCode.Unknown, '', 0, '', '', ''],
        [1, ScanCode.NonConvert, 'NonConvert', KeyCode.Unknown, '', 0, '', '', ''],
        [1, ScanCode.Lang1, 'Lang1', KeyCode.Unknown, '', 0, '', '', ''],
        [1, ScanCode.Lang2, 'Lang2', KeyCode.Unknown, '', 0, '', '', ''],
        [1, ScanCode.Lang3, 'Lang3', KeyCode.Unknown, '', 0, '', '', ''],
        [1, ScanCode.Lang4, 'Lang4', KeyCode.Unknown, '', 0, '', '', ''],
        [1, ScanCode.Lang5, 'Lang5', KeyCode.Unknown, '', 0, '', '', ''],
        [1, ScanCode.Abort, 'Abort', KeyCode.Unknown, '', 0, '', '', ''],
        [1, ScanCode.Props, 'Props', KeyCode.Unknown, '', 0, '', '', ''],
        [1, ScanCode.NumpadParenLeft, 'NumpadParenLeft', KeyCode.Unknown, '', 0, '', '', ''],
        [1, ScanCode.NumpadParenRight, 'NumpadParenRight', KeyCode.Unknown, '', 0, '', '', ''],
        [1, ScanCode.NumpadBackspace, 'NumpadBackspace', KeyCode.Unknown, '', 0, '', '', ''],
        [1, ScanCode.NumpadMemoryStore, 'NumpadMemoryStore', KeyCode.Unknown, '', 0, '', '', ''],
        [1, ScanCode.NumpadMemoryRecall, 'NumpadMemoryRecall', KeyCode.Unknown, '', 0, '', '', ''],
        [1, ScanCode.NumpadMemoryClear, 'NumpadMemoryClear', KeyCode.Unknown, '', 0, '', '', ''],
        [1, ScanCode.NumpadMemoryAdd, 'NumpadMemoryAdd', KeyCode.Unknown, '', 0, '', '', ''],
        [1, ScanCode.NumpadMemorySubtract, 'NumpadMemorySubtract', KeyCode.Unknown, '', 0, '', '', ''],
        [1, ScanCode.NumpadClear, 'NumpadClear', KeyCode.Clear, 'Clear', 12, 'VK_CLEAR', '', ''],
        [1, ScanCode.NumpadClearEntry, 'NumpadClearEntry', KeyCode.Unknown, '', 0, '', '', ''],
        [1, ScanCode.None, '', KeyCode.Ctrl, 'Ctrl', 17, 'VK_CONTROL', '', ''],
        [1, ScanCode.None, '', KeyCode.Shift, 'Shift', 16, 'VK_SHIFT', '', ''],
        [1, ScanCode.None, '', KeyCode.Alt, 'Alt', 18, 'VK_MENU', '', ''],
        [1, ScanCode.None, '', KeyCode.Meta, 'Meta', 91, 'VK_COMMAND', '', ''],
        [1, ScanCode.ControlLeft, 'ControlLeft', KeyCode.Ctrl, '', 0, 'VK_LCONTROL', '', ''],
        [1, ScanCode.ShiftLeft, 'ShiftLeft', KeyCode.Shift, '', 0, 'VK_LSHIFT', '', ''],
        [1, ScanCode.AltLeft, 'AltLeft', KeyCode.Alt, '', 0, 'VK_LMENU', '', ''],
        [1, ScanCode.MetaLeft, 'MetaLeft', KeyCode.Meta, '', 0, 'VK_LWIN', '', ''],
        [1, ScanCode.ControlRight, 'ControlRight', KeyCode.Ctrl, '', 0, 'VK_RCONTROL', '', ''],
        [1, ScanCode.ShiftRight, 'ShiftRight', KeyCode.Shift, '', 0, 'VK_RSHIFT', '', ''],
        [1, ScanCode.AltRight, 'AltRight', KeyCode.Alt, '', 0, 'VK_RMENU', '', ''],
        [1, ScanCode.MetaRight, 'MetaRight', KeyCode.Meta, '', 0, 'VK_RWIN', '', ''],
        [1, ScanCode.BrightnessUp, 'BrightnessUp', KeyCode.Unknown, '', 0, '', '', ''],
        [1, ScanCode.BrightnessDown, 'BrightnessDown', KeyCode.Unknown, '', 0, '', '', ''],
        [1, ScanCode.MediaPlay, 'MediaPlay', KeyCode.Unknown, '', 0, '', '', ''],
        [1, ScanCode.MediaRecord, 'MediaRecord', KeyCode.Unknown, '', 0, '', '', ''],
        [1, ScanCode.MediaFastForward, 'MediaFastForward', KeyCode.Unknown, '', 0, '', '', ''],
        [1, ScanCode.MediaRewind, 'MediaRewind', KeyCode.Unknown, '', 0, '', '', ''],
        [1, ScanCode.MediaTrackNext, 'MediaTrackNext', KeyCode.MediaTrackNext, 'MediaTrackNext', 176, 'VK_MEDIA_NEXT_TRACK', '', ''],
        [1, ScanCode.MediaTrackPrevious, 'MediaTrackPrevious', KeyCode.MediaTrackPrevious, 'MediaTrackPrevious', 177, 'VK_MEDIA_PREV_TRACK', '', ''],
        [1, ScanCode.MediaStop, 'MediaStop', KeyCode.MediaStop, 'MediaStop', 178, 'VK_MEDIA_STOP', '', ''],
        [1, ScanCode.Eject, 'Eject', KeyCode.Unknown, '', 0, '', '', ''],
        [1, ScanCode.MediaPlayPause, 'MediaPlayPause', KeyCode.MediaPlayPause, 'MediaPlayPause', 179, 'VK_MEDIA_PLAY_PAUSE', '', ''],
        [1, ScanCode.MediaSelect, 'MediaSelect', KeyCode.LaunchMediaPlayer, 'LaunchMediaPlayer', 181, 'VK_MEDIA_LAUNCH_MEDIA_SELECT', '', ''],
        [1, ScanCode.LaunchMail, 'LaunchMail', KeyCode.LaunchMail, 'LaunchMail', 180, 'VK_MEDIA_LAUNCH_MAIL', '', ''],
        [1, ScanCode.LaunchApp2, 'LaunchApp2', KeyCode.LaunchApp2, 'LaunchApp2', 183, 'VK_MEDIA_LAUNCH_APP2', '', ''],
        [1, ScanCode.LaunchApp1, 'LaunchApp1', KeyCode.Unknown, '', 0, 'VK_MEDIA_LAUNCH_APP1', '', ''],
        [1, ScanCode.SelectTask, 'SelectTask', KeyCode.Unknown, '', 0, '', '', ''],
        [1, ScanCode.LaunchScreenSaver, 'LaunchScreenSaver', KeyCode.Unknown, '', 0, '', '', ''],
        [1, ScanCode.BrowserSearch, 'BrowserSearch', KeyCode.BrowserSearch, 'BrowserSearch', 170, 'VK_BROWSER_SEARCH', '', ''],
        [1, ScanCode.BrowserHome, 'BrowserHome', KeyCode.BrowserHome, 'BrowserHome', 172, 'VK_BROWSER_HOME', '', ''],
        [1, ScanCode.BrowserBack, 'BrowserBack', KeyCode.BrowserBack, 'BrowserBack', 166, 'VK_BROWSER_BACK', '', ''],
        [1, ScanCode.BrowserForward, 'BrowserForward', KeyCode.BrowserForward, 'BrowserForward', 167, 'VK_BROWSER_FORWARD', '', ''],
        [1, ScanCode.BrowserStop, 'BrowserStop', KeyCode.Unknown, '', 0, 'VK_BROWSER_STOP', '', ''],
        [1, ScanCode.BrowserRefresh, 'BrowserRefresh', KeyCode.Unknown, '', 0, 'VK_BROWSER_REFRESH', '', ''],
        [1, ScanCode.BrowserFavorites, 'BrowserFavorites', KeyCode.Unknown, '', 0, 'VK_BROWSER_FAVORITES', '', ''],
        [1, ScanCode.ZoomToggle, 'ZoomToggle', KeyCode.Unknown, '', 0, '', '', ''],
        [1, ScanCode.MailReply, 'MailReply', KeyCode.Unknown, '', 0, '', '', ''],
        [1, ScanCode.MailForward, 'MailForward', KeyCode.Unknown, '', 0, '', '', ''],
        [1, ScanCode.MailSend, 'MailSend', KeyCode.Unknown, '', 0, '', '', ''],
        [1, ScanCode.None, '', KeyCode.KEY_IN_COMPOSITION, 'KeyInComposition', 229, '', '', ''],
        [1, ScanCode.None, '', KeyCode.ABNT_C2, 'ABNT_C2', 194, 'VK_ABNT_C2', '', ''],
        [1, ScanCode.None, '', KeyCode.OEM_8, 'OEM_8', 223, 'VK_OEM_8', '', ''],
        [1, ScanCode.None, '', KeyCode.Unknown, '', 0, 'VK_KANA', '', ''],
        [1, ScanCode.None, '', KeyCode.Unknown, '', 0, 'VK_HANGUL', '', ''],
        [1, ScanCode.None, '', KeyCode.Unknown, '', 0, 'VK_JUNJA', '', ''],
        [1, ScanCode.None, '', KeyCode.Unknown, '', 0, 'VK_FINAL', '', ''],
        [1, ScanCode.None, '', KeyCode.Unknown, '', 0, 'VK_HANJA', '', ''],
        [1, ScanCode.None, '', KeyCode.Unknown, '', 0, 'VK_KANJI', '', ''],
        [1, ScanCode.None, '', KeyCode.Unknown, '', 0, 'VK_CONVERT', '', ''],
        [1, ScanCode.None, '', KeyCode.Unknown, '', 0, 'VK_NONCONVERT', '', ''],
        [1, ScanCode.None, '', KeyCode.Unknown, '', 0, 'VK_ACCEPT', '', ''],
        [1, ScanCode.None, '', KeyCode.Unknown, '', 0, 'VK_MODECHANGE', '', ''],
        [1, ScanCode.None, '', KeyCode.Unknown, '', 0, 'VK_SELECT', '', ''],
        [1, ScanCode.None, '', KeyCode.Unknown, '', 0, 'VK_PRINT', '', ''],
        [1, ScanCode.None, '', KeyCode.Unknown, '', 0, 'VK_EXECUTE', '', ''],
        [1, ScanCode.None, '', KeyCode.Unknown, '', 0, 'VK_SNAPSHOT', '', ''],
        [1, ScanCode.None, '', KeyCode.Unknown, '', 0, 'VK_HELP', '', ''],
        [1, ScanCode.None, '', KeyCode.Unknown, '', 0, 'VK_APPS', '', ''],
        [1, ScanCode.None, '', KeyCode.Unknown, '', 0, 'VK_PROCESSKEY', '', ''],
        [1, ScanCode.None, '', KeyCode.Unknown, '', 0, 'VK_PACKET', '', ''],
        [1, ScanCode.None, '', KeyCode.Unknown, '', 0, 'VK_DBE_SBCSCHAR', '', ''],
        [1, ScanCode.None, '', KeyCode.Unknown, '', 0, 'VK_DBE_DBCSCHAR', '', ''],
        [1, ScanCode.None, '', KeyCode.Unknown, '', 0, 'VK_ATTN', '', ''],
        [1, ScanCode.None, '', KeyCode.Unknown, '', 0, 'VK_CRSEL', '', ''],
        [1, ScanCode.None, '', KeyCode.Unknown, '', 0, 'VK_EXSEL', '', ''],
        [1, ScanCode.None, '', KeyCode.Unknown, '', 0, 'VK_EREOF', '', ''],
        [1, ScanCode.None, '', KeyCode.Unknown, '', 0, 'VK_PLAY', '', ''],
        [1, ScanCode.None, '', KeyCode.Unknown, '', 0, 'VK_ZOOM', '', ''],
        [1, ScanCode.None, '', KeyCode.Unknown, '', 0, 'VK_NONAME', '', ''],
        [1, ScanCode.None, '', KeyCode.Unknown, '', 0, 'VK_PA1', '', ''],
        [1, ScanCode.None, '', KeyCode.Unknown, '', 0, 'VK_OEM_CLEAR', '', ''],
    ];
    /**
     * Builds the tables (once).
     */
    public static function init():Void {
        if (_initialized) {
            return;
        }
        _initialized = true;
        for (i in 0...(ScanCode.MAX_VALUE + 1)) {
            IMMUTABLE_CODE_TO_KEY_CODE[i] = KeyCode.DependsOnKbLayout;
        }
        for (i in 0...(KeyCode.MAX_VALUE + 1)) {
            IMMUTABLE_KEY_CODE_TO_CODE[i] = ScanCode.DependsOnKbLayout;
        }
        final seenKeyCode:Array<Bool> = [];
        final seenScanCode:Array<Bool> = [];
        for (mapping in MAPPINGS) {
            final immutable:Int = mapping[0];
            final scanCode:Int = mapping[1];
            final scanCodeStr:String = mapping[2];
            final keyCode:Int = mapping[3];
            final keyCodeStr:String = mapping[4];
            final eventKeyCode:Int = mapping[5];
            final usUserSettingsLabel:String = mapping[7];
            final generalUserSettingsLabel:String = mapping[8];
            if (seenScanCode[scanCode] != true) {
                seenScanCode[scanCode] = true;
                scanCodeIntToStr[scanCode] = scanCodeStr;
                scanCodeStrToInt.set(scanCodeStr, scanCode);
                scanCodeLowerCaseStrToInt.set(scanCodeStr.toLowerCase(), scanCode);
                if (immutable == 1) {
                    IMMUTABLE_CODE_TO_KEY_CODE[scanCode] = keyCode;
                    if (
                        (keyCode != KeyCode.Unknown)
                        && (keyCode != KeyCode.Enter)
                        && (keyCode != KeyCode.Ctrl)
                        && (keyCode != KeyCode.Shift)
                        && (keyCode != KeyCode.Alt)
                        && (keyCode != KeyCode.Meta)
                    ) {
                        IMMUTABLE_KEY_CODE_TO_CODE[keyCode] = scanCode;
                    }
                }
            }
            if (seenKeyCode[keyCode] != true) {
                seenKeyCode[keyCode] = true;
                if (keyCodeStr.length == 0) {
                    throw 'String representation missing for key code ' + keyCode + ' around scan code ' + scanCodeStr;
                }
                uiMap.define(keyCode, keyCodeStr);
                userSettingsUSMap.define(keyCode, usUserSettingsLabel.length > 0 ? usUserSettingsLabel : keyCodeStr);
                userSettingsGeneralMap.define(keyCode, generalUserSettingsLabel.length > 0 ? generalUserSettingsLabel : (usUserSettingsLabel.length > 0 ? usUserSettingsLabel : keyCodeStr));
            }
            if (eventKeyCode != 0) {
                EVENT_KEY_CODE_MAP.set(eventKeyCode, keyCode);
            }
        }
        // Manually added due to the exclusion above (due to duplication with NumpadEnter)
        IMMUTABLE_KEY_CODE_TO_CODE[KeyCode.Enter] = ScanCode.Enter;
    }

    @:allow(cityscape.base.common)
    static function _uiMap():KeyCodeStrMap {
        init();
        return uiMap;
    }

    @:allow(cityscape.base.common)
    static function _userSettingsUSMap():KeyCodeStrMap {
        init();
        return userSettingsUSMap;
    }

    @:allow(cityscape.base.common)
    static function _userSettingsGeneralMap():KeyCodeStrMap {
        init();
        return userSettingsGeneralMap;
    }

    @:allow(cityscape.base.common)
    static function _scanCodeLowerCaseToEnum(scanCode:String):ScanCode {
        init();
        final v = scanCodeLowerCaseStrToInt.get(scanCode);
        return v != null ? v : ScanCode.None;
    }

    @:allow(cityscape.base.common)
    static function _scanCodeToEnum(scanCode:String):ScanCode {
        init();
        final v = scanCodeStrToInt.get(scanCode);
        return v != null ? v : ScanCode.None;
    }

    @:allow(cityscape.base.common)
    static function _scanCodeToString(scanCode:ScanCode):String {
        init();
        final v = scanCode >= 0 && scanCode < scanCodeIntToStr.length ? scanCodeIntToStr[scanCode] : null;
        return v != null && v.length > 0 ? v : 'None';
    }

}

class ScanCodeUtils {

    public static function lowerCaseToEnum(scanCode:String):ScanCode {
        return KeyCodes._scanCodeLowerCaseToEnum(scanCode);
    }

    public static function toEnum(scanCode:String):ScanCode {
        return KeyCodes._scanCodeToEnum(scanCode);
    }

    public static function toString(scanCode:ScanCode):String {
        return KeyCodes._scanCodeToString(scanCode);
    }

}

class KeyCodeUtils {

    public static function toString(keyCode:KeyCode):Null<String> {
        return KeyCodes._uiMap().keyCodeToStr(keyCode);
    }

    public static function fromString(key:String):KeyCode {
        return KeyCodes._uiMap().strToKeyCode(key);
    }

    public static function toUserSettingsUS(keyCode:KeyCode):Null<String> {
        return KeyCodes._userSettingsUSMap().keyCodeToStr(keyCode);
    }

    public static function toUserSettingsGeneral(keyCode:KeyCode):Null<String> {
        return KeyCodes._userSettingsGeneralMap().keyCodeToStr(keyCode);
    }

    public static function fromUserSettings(key:String):KeyCode {
        final us = KeyCodes._userSettingsUSMap().strToKeyCode(key);
        return us != KeyCode.Unknown ? us : KeyCodes._userSettingsGeneralMap().strToKeyCode(key);
    }

    public static function toElectronAccelerator(keyCode:KeyCode):Null<String> {
        if (keyCode >= KeyCode.Numpad0 && keyCode <= KeyCode.NumpadDivide) {
            // Electron renders numpad keys like regular keys in menus: custom rendering instead
            return null;
        }

        switch (keyCode) {
            case KeyCode.UpArrow:
                return 'Up';
            case KeyCode.DownArrow:
                return 'Down';
            case KeyCode.LeftArrow:
                return 'Left';
            case KeyCode.RightArrow:
                return 'Right';
            case _:
        }

        return KeyCodes._uiMap().keyCodeToStr(keyCode);
    }

}
