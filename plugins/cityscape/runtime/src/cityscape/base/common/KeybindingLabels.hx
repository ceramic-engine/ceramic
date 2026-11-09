// Ported from vscode src/vs/base/common/keybindingLabels.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.base.common;

import cityscape.base.common.Keybindings.Chord;
import cityscape.base.common.Platform.OperatingSystem;

typedef ModifierLabels = {
    final ctrlKey:String;
    final shiftKey:String;
    final altKey:String;
    final metaKey:String;
    final separator:String;
}

/**
 * The modifier key labels of a platform. The labels Monaco localizes
 * (`Ctrl`, `Shift`...) are kept in English here: they are module level
 * values, and Cityscape's translation tables belong to a context.
 */
class ModifierLabelProvider {

    public final modifierLabels:Array<Null<ModifierLabels>>;

    public function new(mac:ModifierLabels, windows:ModifierLabels, ?linux:ModifierLabels) {
        if (linux == null) {
            linux = windows;
        }
        this.modifierLabels = [null]; // index 0 will never me accessed.
        this.modifierLabels[OperatingSystem.Macintosh] = mac;
        this.modifierLabels[OperatingSystem.Windows] = windows;
        this.modifierLabels[OperatingSystem.Linux] = linux;
    }

    public function toLabel<T:Chord>(OS:OperatingSystem, chords:Array<T>, keyLabelProvider:(keybinding:T) -> Null<String>):Null<String> {
        if (chords.length == 0) {
            return null;
        }

        final result:Array<String> = [];
        for (i in 0...chords.length) {
            final chord = chords[i];
            final keyLabel = keyLabelProvider(chord);
            if (keyLabel == null) {
                // this keybinding cannot be expressed...
                return null;
            }
            result[i] = KeybindingLabels._simpleAsString(chord, keyLabel, this.modifierLabels[OS]);
        }
        return result.join(' ');
    }

}

class KeybindingLabels {

    /**
     * A label provider that prints modifiers in a suitable format for displaying in the UI.
     */
    public static final UILabelProvider = new ModifierLabelProvider(
        {
            ctrlKey: '⌃',
            shiftKey: '⇧',
            altKey: '⌥',
            metaKey: '⌘',
            separator: '',
        },
        {
            ctrlKey: 'Ctrl',
            shiftKey: 'Shift',
            altKey: 'Alt',
            metaKey: 'Windows',
            separator: '+',
        },
        {
            ctrlKey: 'Ctrl',
            shiftKey: 'Shift',
            altKey: 'Alt',
            metaKey: 'Super',
            separator: '+',
        }
    );

    /**
     * A label provider that prints modifiers in a suitable format for ARIA.
     */
    public static final AriaLabelProvider = new ModifierLabelProvider(
        {
            ctrlKey: 'Control',
            shiftKey: 'Shift',
            altKey: 'Option',
            metaKey: 'Command',
            separator: '+',
        },
        {
            ctrlKey: 'Control',
            shiftKey: 'Shift',
            altKey: 'Alt',
            metaKey: 'Windows',
            separator: '+',
        },
        {
            ctrlKey: 'Control',
            shiftKey: 'Shift',
            altKey: 'Alt',
            metaKey: 'Super',
            separator: '+',
        }
    );

    /**
     * A label provider that prints modifiers in a suitable format for Electron Accelerators.
     */
    public static final ElectronAcceleratorLabelProvider = new ModifierLabelProvider(
        {
            ctrlKey: 'Ctrl',
            shiftKey: 'Shift',
            altKey: 'Alt',
            metaKey: 'Cmd',
            separator: '+',
        },
        {
            ctrlKey: 'Ctrl',
            shiftKey: 'Shift',
            altKey: 'Alt',
            metaKey: 'Super',
            separator: '+',
        }
    );

    /**
     * A label provider that prints modifiers in a suitable format for user settings.
     */
    public static final UserSettingsLabelProvider = new ModifierLabelProvider(
        {
            ctrlKey: 'ctrl',
            shiftKey: 'shift',
            altKey: 'alt',
            metaKey: 'cmd',
            separator: '+',
        },
        {
            ctrlKey: 'ctrl',
            shiftKey: 'shift',
            altKey: 'alt',
            metaKey: 'win',
            separator: '+',
        },
        {
            ctrlKey: 'ctrl',
            shiftKey: 'shift',
            altKey: 'alt',
            metaKey: 'meta',
            separator: '+',
        }
    );

    @:allow(cityscape.base.common.ModifierLabelProvider)
    static function _simpleAsString(modifiers:Chord, key:Null<String>, labels:ModifierLabels):String {
        if (key == null) {
            return '';
        }

        final result:Array<String> = [];

        // translate modifier keys: Ctrl-Shift-Alt-Meta
        if (modifiers.ctrlKey) {
            result.push(labels.ctrlKey);
        }

        if (modifiers.shiftKey) {
            result.push(labels.shiftKey);
        }

        if (modifiers.altKey) {
            result.push(labels.altKey);
        }

        if (modifiers.metaKey) {
            result.push(labels.metaKey);
        }

        // the actual key
        if (key != '') {
            result.push(key);
        }

        return result.join(labels.separator);
    }

}
