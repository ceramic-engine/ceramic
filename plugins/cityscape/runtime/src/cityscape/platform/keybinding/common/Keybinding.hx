// Ported from vscode src/vs/platform/keybinding/common/keybinding.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.platform.keybinding.common;

import cityscape.base.common.Event;
import cityscape.base.common.KeyCodes.KeyCode;
import cityscape.base.common.Keybindings;
import cityscape.platform.contextkey.common.ContextKey.IContextKeyService;
import cityscape.platform.keybinding.common.KeybindingResolver.ResolutionResult;

typedef IUserFriendlyKeybinding = {
    var key:String;
    var command:String;
    @:optional var args:Any;
    @:optional var when:String;
}

/**
 * A keyboard event (Monaco's `IKeyboardEvent`, built from a Glaze
 * keystroke by `cityscape.view.KeyboardEvents`).
 */
typedef IKeyboardEvent = {
    final ctrlKey:Bool;
    final shiftKey:Bool;
    final altKey:Bool;
    final metaKey:Bool;
    final altGraphKey:Bool;
    final keyCode:KeyCode;
    final code:String;
}

/**
 * Monaco's `IKeybindingService`. The `target` of the dispatch functions is
 * the context key service whose context the `when` clauses are evaluated in
 * (Monaco finds it from the focused DOM node), the service's own when null.
 */
interface IKeybindingService {
    var inChordMode(get, never):Bool;

    var onDidUpdateKeybindings(get, never):VoidEvent;

    /**
     * Returns none, one or many (depending on keyboard layout)!
     */
    function resolveKeybinding(keybinding:Keybinding):Array<ResolvedKeybinding>;

    function resolveKeyboardEvent(keyboardEvent:IKeyboardEvent):ResolvedKeybinding;

    function resolveUserBinding(userBinding:String):Array<ResolvedKeybinding>;

    /**
     * Resolve and dispatch `keyboardEvent` and invoke the command.
     */
    function dispatchEvent(e:IKeyboardEvent, target:Null<IContextKeyService>):Bool;

    /**
     * Resolve and dispatch `keyboardEvent`, but do not invoke the command or change inner state.
     */
    function softDispatch(keyboardEvent:IKeyboardEvent, target:Null<IContextKeyService>):ResolutionResult;

    function dispatchByUserSettingsLabel(userSettingsLabel:String, target:Null<IContextKeyService>):Void;

    /**
     * Look up keybindings for a command.
     * Use `lookupKeybinding` if you are interested in the preferred keybinding.
     */
    function lookupKeybindings(commandId:String):Array<ResolvedKeybinding>;

    /**
     * Look up the preferred (last defined) keybinding for a command.
     * @returns The preferred keybinding or null if the command is not bound.
     */
    function lookupKeybinding(commandId:String, ?context:IContextKeyService):Null<ResolvedKeybinding>;

    function getDefaultKeybindingsContent():String;

    function getDefaultKeybindings():Array<ResolvedKeybindingItem>;

    function getKeybindings():Array<ResolvedKeybindingItem>;

    function customKeybindingsCount():Int;

    /**
     * Will the given key event produce a character that's rendered on screen, e.g. in a
     * text box. *Note* that the results of this function can be incorrect.
     */
    function mightProducePrintableCharacter(event:IKeyboardEvent):Bool;

    function toggleLogging():Bool;
}
