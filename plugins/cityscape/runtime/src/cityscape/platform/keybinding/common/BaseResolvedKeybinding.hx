// Ported from vscode src/vs/platform/keybinding/common/baseResolvedKeybinding.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.platform.keybinding.common;

import cityscape.base.common.KeybindingLabels;
import cityscape.base.common.Keybindings;
import cityscape.base.common.Platform.OperatingSystem;

abstract class BaseResolvedKeybinding<T:Chord> extends ResolvedKeybinding {

    final _os:OperatingSystem;
    final _chords:Array<T>;

    public function new(os:OperatingSystem, chords:Array<T>) {
        if (chords.length == 0) {
            throw 'Illegal argument: chords';
        }
        this._os = os;
        this._chords = chords;
    }

    public function getLabel():Null<String> {
        return KeybindingLabels.UILabelProvider.toLabel(this._os, this._chords, (keybinding) -> this._getLabel(keybinding));
    }

    public function getAriaLabel():Null<String> {
        return KeybindingLabels.AriaLabelProvider.toLabel(this._os, this._chords, (keybinding) -> this._getAriaLabel(keybinding));
    }

    public function getElectronAccelerator():Null<String> {
        if (this._chords.length > 1) {
            // [Electron Accelerators] Electron cannot handle chords
            return null;
        }
        if (this._chords[0].isDuplicateModifierCase()) {
            // [Electron Accelerators] Electron cannot handle modifier only keybindings
            // e.g. "shift shift"
            return null;
        }
        return KeybindingLabels.ElectronAcceleratorLabelProvider.toLabel(this._os, this._chords, (keybinding) -> this._getElectronAccelerator(keybinding));
    }

    public function getUserSettingsLabel():Null<String> {
        return KeybindingLabels.UserSettingsLabelProvider.toLabel(this._os, this._chords, (keybinding) -> this._getUserSettingsLabel(keybinding));
    }

    public function isWYSIWYG():Bool {
        for (keybinding in this._chords) {
            if (!this._isWYSIWYG(keybinding)) {
                return false;
            }
        }
        return true;
    }

    public function hasMultipleChords():Bool {
        return (this._chords.length > 1);
    }

    public function getChords():Array<ResolvedChord> {
        return [for (keybinding in this._chords) this._getChord(keybinding)];
    }

    function _getChord(keybinding:T):ResolvedChord {
        return new ResolvedChord(
            keybinding.ctrlKey,
            keybinding.shiftKey,
            keybinding.altKey,
            keybinding.metaKey,
            this._getLabel(keybinding),
            this._getAriaLabel(keybinding)
        );
    }

    public function getDispatchChords():Array<Null<String>> {
        return [for (keybinding in this._chords) this._getChordDispatch(keybinding)];
    }

    public function getSingleModifierDispatchChords():Array<Null<SingleModifierChord>> {
        return [for (keybinding in this._chords) this._getSingleModifierChordDispatch(keybinding)];
    }

    abstract function _getLabel(keybinding:T):Null<String>;
    abstract function _getAriaLabel(keybinding:T):Null<String>;
    abstract function _getElectronAccelerator(keybinding:T):Null<String>;
    abstract function _getUserSettingsLabel(keybinding:T):Null<String>;
    abstract function _isWYSIWYG(keybinding:T):Bool;
    abstract function _getChordDispatch(keybinding:T):Null<String>;
    abstract function _getSingleModifierChordDispatch(keybinding:T):Null<SingleModifierChord>;

}
