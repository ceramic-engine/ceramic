// Ported from vscode src/vs/platform/keybinding/common/keybindingResolver.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.platform.keybinding.common;

import cityscape.platform.contextkey.common.ContextKey;

enum abstract ResultKind(Int) from Int to Int {
    /** No keybinding found this sequence of chords */
    var NoMatchingKb = 0;

    /** There're several keybindings that have the given sequence of chords as a prefix */
    var MoreChordsNeeded = 1;

    /** A single keybinding found to be dispatched/invoked */
    var KbFound = 2;
}

/**
 * Monaco's `ResolutionResult` union: `commandId`, `commandArgs` and
 * `isBubble` are set for `KbFound`.
 */
class ResolutionResult {

    public static final NoMatchingKb = new ResolutionResult(ResultKind.NoMatchingKb, null, null, false);
    public static final MoreChordsNeeded = new ResolutionResult(ResultKind.MoreChordsNeeded, null, null, false);

    public final kind:ResultKind;
    public final commandId:Null<String>;
    public final commandArgs:Any;
    public final isBubble:Bool;

    public function new(kind:ResultKind, commandId:Null<String>, commandArgs:Any, isBubble:Bool) {
        this.kind = kind;
        this.commandId = commandId;
        this.commandArgs = commandArgs;
        this.isBubble = isBubble;
    }

    public static function KbFound(commandId:Null<String>, commandArgs:Any, isBubble:Bool):ResolutionResult {
        return new ResolutionResult(ResultKind.KbFound, commandId, commandArgs, isBubble);
    }

}

/**
 * Stores mappings from keybindings to commands and from commands to keybindings.
 * Given a sequence of chords, `resolve`s which keybinding it matches
 */
class KeybindingResolver {

    final _log:(str:String) -> Void;
    final _defaultKeybindings:Array<ResolvedKeybindingItem>;
    final _keybindings:Array<ResolvedKeybindingItem>;
    final _defaultBoundCommands:Map<String, Bool>;
    final _map:Map<String, Array<ResolvedKeybindingItem>>;
    final _lookupMap:Map<String, Array<ResolvedKeybindingItem>>;

    public function new(
        /** built-in and extension-provided keybindings */
        defaultKeybindings:Array<ResolvedKeybindingItem>,
        /** user's keybindings */
        overrides:Array<ResolvedKeybindingItem>,
        log:(str:String) -> Void
    ) {
        this._log = log;
        this._defaultKeybindings = defaultKeybindings;

        this._defaultBoundCommands = new Map<String, Bool>();
        for (defaultKeybinding in defaultKeybindings) {
            final command = defaultKeybinding.command;
            if (command != null && command.length > 0 && command.charAt(0) != '-') {
                this._defaultBoundCommands.set(command, true);
            }
        }

        this._map = new Map<String, Array<ResolvedKeybindingItem>>();
        this._lookupMap = new Map<String, Array<ResolvedKeybindingItem>>();

        this._keybindings = KeybindingResolver.handleRemovals(defaultKeybindings.concat(overrides));
        for (i in 0...this._keybindings.length) {
            final k = this._keybindings[i];
            if (k.chords.length == 0) {
                // unbound
                continue;
            }

            // substitute with constants that are registered after startup - https://github.com/microsoft/vscode/issues/174218#issuecomment-1437972127
            final when = k.when != null ? k.when.substituteConstants() : null;

            if (when != null && when.type == ContextKeyExprType.False) {
                // when condition is false
                continue;
            }

            this._addKeyPress(k.chords[0], k);
        }
    }

    static function _isTargetedForRemoval(defaultKb:ResolvedKeybindingItem, keypress:Null<Array<String>>, when:Null<ContextKeyExpression>):Bool {
        if (keypress != null) {
            for (i in 0...keypress.length) {
                if (keypress[i] != defaultKb.chords[i]) {
                    return false;
                }
            }
        }

        // `true` means always, as does `undefined`
        // so we will treat `true` === `undefined`
        if (when != null && when.type != ContextKeyExprType.True) {
            if (defaultKb.when == null) {
                return false;
            }
            if (!ContextKeyUtils.expressionsAreEqualWithConstantSubstitution(when, defaultKb.when)) {
                return false;
            }
        }
        return true;

    }

    /**
     * Looks for rules containing "-commandId" and removes them.
     */
    public static function handleRemovals(rules:Array<ResolvedKeybindingItem>):Array<ResolvedKeybindingItem> {
        // Do a first pass and construct a hash-map for removals
        final removals = new Map<String, Array<ResolvedKeybindingItem>>();
        var removalCount = 0;
        for (i in 0...rules.length) {
            final rule = rules[i];
            if (rule.command != null && rule.command.length > 0 && rule.command.charAt(0) == '-') {
                final command = rule.command.substring(1);
                if (!removals.exists(command)) {
                    removals.set(command, [rule]);
                    removalCount++;
                }
                else {
                    removals.get(command).push(rule);
                }
            }
        }

        if (removalCount == 0) {
            // There are no removals
            return rules;
        }

        // Do a second pass and keep only non-removed keybindings
        final result:Array<ResolvedKeybindingItem> = [];
        for (i in 0...rules.length) {
            final rule = rules[i];

            if (rule.command == null || rule.command.length == 0) {
                result.push(rule);
                continue;
            }
            if (rule.command.charAt(0) == '-') {
                continue;
            }
            final commandRemovals = removals.get(rule.command);
            if (commandRemovals == null || !rule.isDefault) {
                result.push(rule);
                continue;
            }
            var isRemoved = false;
            for (commandRemoval in commandRemovals) {
                final when = commandRemoval.when;
                // Monaco passes `chords`, an empty array for a removal without a keybinding (it matches any)
                if (KeybindingResolver._isTargetedForRemoval(rule, commandRemoval.chords, when)) {
                    isRemoved = true;
                    break;
                }
            }
            if (!isRemoved) {
                result.push(rule);
                continue;
            }
        }
        return result;
    }

    function _addKeyPress(keypress:String, item:ResolvedKeybindingItem):Void {

        final conflicts = this._map.get(keypress);

        if (conflicts == null) {
            // There is no conflict so far
            this._map.set(keypress, [item]);
            this._addToLookupMap(item);
            return;
        }

        var i = conflicts.length - 1;
        while (i >= 0) {
            final conflict = conflicts[i];
            i--;

            if (conflict.command == item.command) {
                continue;
            }

            // Test if the shorter keybinding is a prefix of the longer one.
            // If the shorter keybinding is a prefix, it effectively will shadow the longer one and is considered a conflict.
            var isShorterKbPrefix = true;
            var j = 1;
            while (j < conflict.chords.length && j < item.chords.length) {
                if (conflict.chords[j] != item.chords[j]) {
                    // The ith step does not conflict
                    isShorterKbPrefix = false;
                    break;
                }
                j++;
            }
            if (!isShorterKbPrefix) {
                continue;
            }

            if (KeybindingResolver.whenIsEntirelyIncluded(conflict.when, item.when)) {
                // `item` completely overwrites `conflict`
                // Remove conflict from the lookupMap
                this._removeFromLookupMap(conflict);
            }
        }

        conflicts.push(item);
        this._addToLookupMap(item);
    }

    function _addToLookupMap(item:ResolvedKeybindingItem):Void {
        if (item.command == null || item.command.length == 0) {
            return;
        }

        var arr = this._lookupMap.get(item.command);
        if (arr == null) {
            arr = [item];
            this._lookupMap.set(item.command, arr);
        }
        else {
            arr.push(item);
        }
    }

    function _removeFromLookupMap(item:ResolvedKeybindingItem):Void {
        if (item.command == null || item.command.length == 0) {
            return;
        }
        final arr = this._lookupMap.get(item.command);
        if (arr == null) {
            return;
        }
        for (i in 0...arr.length) {
            if (arr[i] == item) {
                arr.splice(i, 1);
                return;
            }
        }
    }

    /**
     * Returns true if it is provable `a` implies `b`.
     */
    public static function whenIsEntirelyIncluded(a:Null<ContextKeyExpression>, b:Null<ContextKeyExpression>):Bool {
        if (b == null || b.type == ContextKeyExprType.True) {
            return true;
        }
        if (a == null || a.type == ContextKeyExprType.True) {
            return false;
        }

        return ContextKeyUtils.implies(a, b);
    }

    public function getDefaultBoundCommands():Map<String, Bool> {
        return this._defaultBoundCommands;
    }

    public function getDefaultKeybindings():Array<ResolvedKeybindingItem> {
        return this._defaultKeybindings;
    }

    public function getKeybindings():Array<ResolvedKeybindingItem> {
        return this._keybindings;
    }

    public function lookupKeybindings(commandId:String):Array<ResolvedKeybindingItem> {
        final items = this._lookupMap.get(commandId);
        if (items == null || items.length == 0) {
            return [];
        }

        // Reverse to get the most specific item first
        final result:Array<ResolvedKeybindingItem> = [];
        var i = items.length - 1;
        while (i >= 0) {
            result.push(items[i]);
            i--;
        }
        return result;
    }

    public function lookupPrimaryKeybinding(commandId:String, context:IContextKeyService):Null<ResolvedKeybindingItem> {
        final items = this._lookupMap.get(commandId);
        if (items == null || items.length == 0) {
            return null;
        }
        if (items.length == 1) {
            return items[0];
        }

        var i = items.length - 1;
        while (i >= 0) {
            final item = items[i];
            if (context.contextMatchesRules(item.when)) {
                return item;
            }
            i--;
        }

        return items[items.length - 1];
    }

    /**
     * Looks up a keybinding trigged as a result of pressing a sequence of chords - `[...currentChords, keypress]`
     *
     * Example: resolving 3 chords pressed sequentially - `cmd+k cmd+p cmd+i`:
     * 	`currentChords = [ 'cmd+k' , 'cmd+p' ]` and `keypress = `cmd+i` - last pressed chord
     */
    public function resolve(context:IContext, currentChords:Array<String>, keypress:String):ResolutionResult {

        final pressedChords = currentChords.concat([keypress]);

        this._log('| Resolving ' + pressedChords.join(','));

        final kbCandidates = this._map.get(pressedChords[0]);
        if (kbCandidates == null) {
            // No bindings with such 0-th chord
            this._log('\\ No keybinding entries.');
            return ResolutionResult.NoMatchingKb;
        }

        var lookupMap:Array<ResolvedKeybindingItem> = null;

        if (pressedChords.length < 2) {
            lookupMap = kbCandidates;
        }
        else {
            // Fetch all chord bindings for `currentChords`
            lookupMap = [];
            for (i in 0...kbCandidates.length) {

                final candidate = kbCandidates[i];

                if (pressedChords.length > candidate.chords.length) { // # of pressed chords can't be less than # of chords in a keybinding to invoke
                    continue;
                }

                var prefixMatches = true;
                for (j in 1...pressedChords.length) {
                    if (candidate.chords[j] != pressedChords[j]) {
                        prefixMatches = false;
                        break;
                    }
                }
                if (prefixMatches) {
                    lookupMap.push(candidate);
                }
            }
        }

        // check there's a keybinding with a matching when clause
        final result = this._findCommand(context, lookupMap);
        if (result == null) {
            this._log('\\ From ' + lookupMap.length + ' keybinding entries, no when clauses matched the context.');
            return ResolutionResult.NoMatchingKb;
        }

        // check we got all chords necessary to be sure a particular keybinding needs to be invoked
        if (pressedChords.length < result.chords.length) {
            // The chord sequence is not complete
            this._log('\\ From ' + lookupMap.length + ' keybinding entries, awaiting ' + (result.chords.length - pressedChords.length) + ' more chord(s), when: ' + printWhenExplanation(result.when) + ', source: ' + printSourceExplanation(result) + '.');
            return ResolutionResult.MoreChordsNeeded;
        }

        this._log('\\ From ' + lookupMap.length + ' keybinding entries, matched ' + result.command + ', when: ' + printWhenExplanation(result.when) + ', source: ' + printSourceExplanation(result) + '.');

        return ResolutionResult.KbFound(result.command, result.commandArgs, result.bubble);
    }

    function _findCommand(context:IContext, matches:Array<ResolvedKeybindingItem>):Null<ResolvedKeybindingItem> {
        var i = matches.length - 1;
        while (i >= 0) {
            final k = matches[i];
            i--;

            if (!KeybindingResolver._contextMatchesRules(context, k.when)) {
                continue;
            }

            return k;
        }

        return null;
    }

    static function _contextMatchesRules(context:IContext, rules:Null<ContextKeyExpression>):Bool {
        if (rules == null) {
            return true;
        }
        return rules.evaluate(context);
    }

    static function printWhenExplanation(when:Null<ContextKeyExpression>):String {
        if (when == null) {
            return 'no when condition';
        }
        return when.serialize();
    }

    static function printSourceExplanation(kb:ResolvedKeybindingItem):String {
        return (
            kb.extensionId != null
                ? (kb.isBuiltinExtension ? 'built-in extension ' + kb.extensionId : 'user extension ' + kb.extensionId)
                : (kb.isDefault ? 'built-in' : 'user')
        );
    }

}
