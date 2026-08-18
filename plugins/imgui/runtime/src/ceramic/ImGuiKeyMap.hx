package ceramic;

#if plugin_imgui

import imgui.ImGui;

/**
 * Maps ceramic scan codes (physical keys, SDL scancode values) to `ImGuiKey`
 * values (which are physical-key based since Dear ImGui 1.87).
 */
class ImGuiKeyMap {

    public static function fromScanCode(scanCode:ScanCode):ImGuiKey {

        var sc:Int = scanCode;

        // Letters (SDL: A=4 .. Z=29 / ImGuiKey: A .. Z contiguous)
        if (sc >= 4 && sc <= 29) return (ImGuiKey.A : Int) + (sc - 4);
        // Number row (SDL: 1..9 = 30..38, 0 = 39 / ImGuiKey: _1.._9 contiguous after _0)
        if (sc >= 30 && sc <= 38) return (ImGuiKey._1 : Int) + (sc - 30);
        if (sc == 39) return ImGuiKey._0;
        // Function keys (SDL: F1=58 .. F12=69)
        if (sc >= 58 && sc <= 69) return (ImGuiKey.F1 : Int) + (sc - 58);
        // Keypad numbers (SDL: KP_1=89 .. KP_9=97, KP_0=98)
        if (sc >= 89 && sc <= 97) return (ImGuiKey.Keypad1 : Int) + (sc - 89);
        if (sc == 98) return ImGuiKey.Keypad0;

        return switch sc {
            case 40: ImGuiKey.Enter;
            case 41: ImGuiKey.Escape;
            case 42: ImGuiKey.Backspace;
            case 43: ImGuiKey.Tab;
            case 44: ImGuiKey.Space;
            case 45: ImGuiKey.Minus;
            case 46: ImGuiKey.Equal;
            case 47: ImGuiKey.LeftBracket;
            case 48: ImGuiKey.RightBracket;
            case 49: ImGuiKey.Backslash;
            case 51: ImGuiKey.Semicolon;
            case 52: ImGuiKey.Apostrophe;
            case 53: ImGuiKey.GraveAccent;
            case 54: ImGuiKey.Comma;
            case 55: ImGuiKey.Period;
            case 56: ImGuiKey.Slash;
            case 57: ImGuiKey.CapsLock;
            case 70: ImGuiKey.PrintScreen;
            case 71: ImGuiKey.ScrollLock;
            case 72: ImGuiKey.Pause;
            case 73: ImGuiKey.Insert;
            case 74: ImGuiKey.Home;
            case 75: ImGuiKey.PageUp;
            case 76: ImGuiKey.Delete;
            case 77: ImGuiKey.End;
            case 78: ImGuiKey.PageDown;
            case 79: ImGuiKey.RightArrow;
            case 80: ImGuiKey.LeftArrow;
            case 81: ImGuiKey.DownArrow;
            case 82: ImGuiKey.UpArrow;
            case 83: ImGuiKey.NumLock;
            case 84: ImGuiKey.KeypadDivide;
            case 85: ImGuiKey.KeypadMultiply;
            case 86: ImGuiKey.KeypadSubtract;
            case 87: ImGuiKey.KeypadAdd;
            case 88: ImGuiKey.KeypadEnter;
            case 99: ImGuiKey.KeypadDecimal;
            case 103: ImGuiKey.KeypadEqual;
            case 224: ImGuiKey.LeftCtrl;
            case 225: ImGuiKey.LeftShift;
            case 226: ImGuiKey.LeftAlt;
            case 227: ImGuiKey.LeftSuper;
            case 228: ImGuiKey.RightCtrl;
            case 229: ImGuiKey.RightShift;
            case 230: ImGuiKey.RightAlt;
            case 231: ImGuiKey.RightSuper;
            case _: ImGuiKey.None;
        }

    }

    /** The modifier ImGuiKey (ImGuiMod_*) affected by a scan code, or None. */
    public static function modFromScanCode(scanCode:ScanCode):ImGuiKey {

        return switch (scanCode : Int) {
            case 224 | 228: ImGuiKey.ImGuiMod_Ctrl;
            case 225 | 229: ImGuiKey.ImGuiMod_Shift;
            case 226 | 230: ImGuiKey.ImGuiMod_Alt;
            case 227 | 231: ImGuiKey.ImGuiMod_Super;
            case _: ImGuiKey.None;
        }

    }

}

#end
