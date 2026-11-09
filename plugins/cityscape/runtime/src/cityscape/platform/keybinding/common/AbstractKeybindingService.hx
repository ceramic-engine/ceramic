// Ported from vscode src/vs/platform/keybinding/common/abstractKeybindingService.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.platform.keybinding.common;

import cityscape.base.common.Event;
import cityscape.base.common.KeyCodes.KeyCode;
import cityscape.base.common.Keybindings;
import cityscape.base.common.Lifecycle;
import cityscape.platform.commands.common.Commands.ICommandService;
import cityscape.platform.contextkey.common.ContextKey.IContextKeyService;
import cityscape.platform.keybinding.common.Keybinding;
import cityscape.platform.keybinding.common.KeybindingResolver;

private typedef CurrentChord = {
    var keypress:String;
    var label:Null<String>;
}

/**
 * The keybinding dispatch of Monaco: chords, `when` clauses, command
 * execution.
 *
 * Differences without the DOM and the workbench: the chord status messages
 * (notification service) and the telemetry are not ported; chord mode ends
 * after 5 seconds without a key, checked at the next key (Monaco checks every
 * 500 ms with a timer, and also when the window loses focus); single modifier
 * chords (`shift shift`) are not dispatched, Glaze has no key up event for a
 * modifier alone.
 */
abstract class AbstractKeybindingService extends Disposable implements IKeybindingService {

    final _onDidUpdateKeybindings:VoidEmitter;

    public var onDidUpdateKeybindings(get, never):VoidEvent;
    function get_onDidUpdateKeybindings():VoidEvent {
        return this._onDidUpdateKeybindings.event;
    }

    /** recently recorded keypresses that can trigger a keybinding;
     *
     * example: say, there's "cmd+k cmd+i" keybinding;
     * the user pressed "cmd+k" (before they press "cmd+i")
     * "cmd+k" would be stored in this array, when on pressing "cmd+i", the service
     * would invoke the command bound by the keybinding
     */
    var _currentChords:Array<CurrentChord>;

    /**
     * When the last chord was pressed (seconds), to leave chord mode after 5 seconds.
     */
    var _chordLastInteractedTime:Float = 0;

    var _currentlyDispatchingCommandId:Null<String>;

    var _logging:Bool;

    public var inChordMode(get, never):Bool;
    function get_inChordMode():Bool {
        return this._currentChords.length > 0;
    }

    final _contextKeyService:IContextKeyService;
    final _commandService:ICommandService;

    public function new(contextKeyService:IContextKeyService, commandService:ICommandService) {
        super();
        this._onDidUpdateKeybindings = this._register(new VoidEmitter());
        this._contextKeyService = contextKeyService;
        this._commandService = commandService;

        this._currentChords = [];
        this._currentlyDispatchingCommandId = null;
        this._logging = false;
    }

    abstract function _getResolver():KeybindingResolver;

    abstract public function resolveKeybinding(keybinding:Keybinding):Array<ResolvedKeybinding>;

    abstract public function resolveKeyboardEvent(keyboardEvent:IKeyboardEvent):ResolvedKeybinding;

    abstract public function resolveUserBinding(userBinding:String):Array<ResolvedKeybinding>;

    public function getDefaultKeybindingsContent():String {
        return '';
    }

    public function toggleLogging():Bool {
        this._logging = !this._logging;
        return this._logging;
    }

    function _log(str:String):Void {
        if (this._logging) {
            haxe.Log.trace('[KeybindingService]: ' + str, null);
        }
    }

    public function getDefaultKeybindings():Array<ResolvedKeybindingItem> {
        return this._getResolver().getDefaultKeybindings();
    }

    public function getKeybindings():Array<ResolvedKeybindingItem> {
        return this._getResolver().getKeybindings();
    }

    public function customKeybindingsCount():Int {
        return 0;
    }

    public function lookupKeybindings(commandId:String):Array<ResolvedKeybinding> {
        final result:Array<ResolvedKeybinding> = [];
        for (item in this._getResolver().lookupKeybindings(commandId)) {
            if (item.resolvedKeybinding != null) {
                result.push(item.resolvedKeybinding);
            }
        }
        return result;
    }

    public function lookupKeybinding(commandId:String, ?context:IContextKeyService):Null<ResolvedKeybinding> {
        final result = this._getResolver().lookupPrimaryKeybinding(commandId, context != null ? context : this._contextKeyService);
        if (result == null) {
            return null;
        }
        return result.resolvedKeybinding;
    }

    public function dispatchEvent(e:IKeyboardEvent, target:Null<IContextKeyService>):Bool {
        return this._dispatch(e, target);
    }

    function _contextOf(target:Null<IContextKeyService>) {
        return (target != null ? target : this._contextKeyService).getContext(null);
    }

    // TODO@ulugbekna: update namings to align with `_doDispatch`
    // TODO@ulugbekna: this fn doesn't seem to take into account single-modifier keybindings, eg `shift shift`
    public function softDispatch(e:IKeyboardEvent, target:Null<IContextKeyService>):ResolutionResult {
        this._log('/ Soft dispatching keyboard event');
        final keybinding = this.resolveKeyboardEvent(e);
        if (keybinding.hasMultipleChords()) {
            haxe.Log.trace('keyboard event should not be mapped to multiple chords', null);
            return ResolutionResult.NoMatchingKb;
        }
        final firstChord = keybinding.getDispatchChords()[0];
        if (firstChord == null) {
            // cannot be dispatched, probably only modifier keys
            this._log('\\ Keyboard event cannot be dispatched');
            return ResolutionResult.NoMatchingKb;
        }

        final contextValue = this._contextOf(target);
        final currentChords = [for (c in this._currentChords) c.keypress];
        return this._getResolver().resolve(contextValue, currentChords, firstChord);
    }

    function _checkLeaveChordMode():Void {
        if (this._currentChords.length > 0 && haxe.Timer.stamp() - this._chordLastInteractedTime > 5) {
            // 5 seconds elapsed => leave chord mode
            this._leaveChordMode();
        }
    }

    function _expectAnotherChord(firstChord:String, keypressLabel:Null<String>):Void {

        this._currentChords.push({keypress: firstChord, label: keypressLabel});
        this._chordLastInteractedTime = haxe.Timer.stamp();

        switch (this._currentChords.length) {
            case 0:
                throw 'Illegal state: impossible';
            case 1:
                this._log('(' + keypressLabel + ') was pressed. Waiting for second key of chord...');
            default:
                final fullKeypressLabel = [for (c in this._currentChords) c.label].join(', ');
                this._log('(' + fullKeypressLabel + ') was pressed. Waiting for next key of chord...');
        }
    }

    function _leaveChordMode():Void {
        this._currentChords = [];
    }

    public function dispatchByUserSettingsLabel(userSettingsLabel:String, target:Null<IContextKeyService>):Void {
        this._log('/ Dispatching keybinding triggered via menu entry accelerator - ' + userSettingsLabel);
        final keybindings = this.resolveUserBinding(userSettingsLabel);
        if (keybindings.length == 0) {
            this._log('\\ Could not resolve - ' + userSettingsLabel);
        }
        else {
            this._doDispatch(keybindings[0], target, /*isSingleModiferChord*/false);
        }
    }

    function _dispatch(e:IKeyboardEvent, target:Null<IContextKeyService>):Bool {
        return this._doDispatch(this.resolveKeyboardEvent(e), target, /*isSingleModiferChord*/false);
    }

    function _doDispatch(userKeypress:ResolvedKeybinding, target:Null<IContextKeyService>, isSingleModiferChord:Bool = false):Bool {
        if (userKeypress.hasMultipleChords()) { // warn - because user can press a single chord at a time
            haxe.Log.trace('Unexpected keyboard event mapped to multiple chords', null);
            return false;
        }

        var userPressedChord:Null<String> = null;
        var currentChords:Null<Array<String>> = null;

        if (isSingleModiferChord) {
            // The keybinding is the second keypress of a single modifier chord, e.g. "shift shift".
            final dispatchKeyname = userKeypress.getSingleModifierDispatchChords()[0];
            userPressedChord = dispatchKeyname;
            currentChords = dispatchKeyname != null ? [dispatchKeyname] : [];
        }
        else {
            userPressedChord = userKeypress.getDispatchChords()[0];
            currentChords = [for (c in this._currentChords) c.keypress];
        }

        if (userPressedChord == null) {
            this._log('\\ Keyboard event cannot be dispatched in keydown phase.');
            // cannot be dispatched, probably only modifier keys
            return false;
        }

        return this.dispatchKeypress(userPressedChord, userKeypress.getLabel(), target);
    }

    /**
     * The dispatch of one chord (Monaco's `_doDispatch` once the pressed
     * chord is known: its dispatch string, like `meta+K`, and its label).
     * Returns whether the key was handled (Monaco's `shouldPreventDefault`).
     */
    public function dispatchKeypress(userPressedChord:String, keypressLabel:Null<String>, target:Null<IContextKeyService>):Bool {
        var shouldPreventDefault = false;

        this._checkLeaveChordMode();
        final currentChords = [for (c in this._currentChords) c.keypress];

        final contextValue = this._contextOf(target);

        final resolveResult = this._getResolver().resolve(contextValue, currentChords, userPressedChord);

        switch (resolveResult.kind) {

            case ResultKind.NoMatchingKb:

                if (this.inChordMode) {
                    final currentChordsLabel = [for (c in this._currentChords) c.label].join(', ');
                    this._log('+ Leaving multi-chord mode: Nothing bound to "' + currentChordsLabel + ', ' + keypressLabel + '".');
                    this._leaveChordMode();

                    shouldPreventDefault = true;
                }
                return shouldPreventDefault;

            case ResultKind.MoreChordsNeeded:

                shouldPreventDefault = true;
                this._expectAnotherChord(userPressedChord, keypressLabel);
                this._log(this._currentChords.length == 1 ? '+ Entering multi-chord mode...' : '+ Continuing multi-chord mode...');
                return shouldPreventDefault;

            case _:

                if (resolveResult.commandId == null || resolveResult.commandId == '') {

                    if (this.inChordMode) {
                        final currentChordsLabel = [for (c in this._currentChords) c.label].join(', ');
                        this._log('+ Leaving chord mode: Nothing bound to "' + currentChordsLabel + ', ' + keypressLabel + '".');
                        this._leaveChordMode();
                        shouldPreventDefault = true;
                    }

                }
                else {
                    if (this.inChordMode) {
                        this._leaveChordMode();
                    }

                    if (!resolveResult.isBubble) {
                        shouldPreventDefault = true;
                    }

                    this._log('+ Invoking command ' + resolveResult.commandId + '.');
                    this._currentlyDispatchingCommandId = resolveResult.commandId;
                    try {
                        if (resolveResult.commandArgs == null) {
                            this._commandService.executeCommand(resolveResult.commandId);
                        }
                        else {
                            this._commandService.executeCommand(resolveResult.commandId, [resolveResult.commandArgs]);
                        }
                    }
                    catch (err:Dynamic) {
                        // Monaco shows a warning notification
                        cityscape.base.common.Errors.onUnexpectedError(err);
                    }
                    this._currentlyDispatchingCommandId = null;
                }

                return shouldPreventDefault;
        }
    }

    public function mightProducePrintableCharacter(event:IKeyboardEvent):Bool {
        if (event.ctrlKey || event.metaKey) {
            // ignore ctrl/cmd-combination but not shift/alt-combinatios
            return false;
        }
        // weak check for certain ranges. this is properly implemented in a subclass
        // with access to the KeyboardMapperFactory.
        if ((event.keyCode >= KeyCode.KeyA && event.keyCode <= KeyCode.KeyZ)
            || (event.keyCode >= KeyCode.Digit0 && event.keyCode <= KeyCode.Digit9)) {
            return true;
        }
        return false;
    }

}
