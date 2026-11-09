// Ported from vscode src/vs/platform/keybinding/test/common/keybindingResolver.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.platform.keybinding;

import cityscape.base.common.JsValues;
import cityscape.base.common.KeyCodes;
import cityscape.base.common.Keybindings;
import cityscape.base.common.Platform;
import cityscape.platform.contextkey.common.ContextKey;
import cityscape.platform.keybinding.common.KeybindingResolver;
import cityscape.platform.keybinding.common.ResolvedKeybindingItem;
import cityscape.platform.keybinding.common.UsLayoutResolvedKeybinding;
import haxe.extern.EitherType;
import testing.TestCase;

private class TestContext implements IContext {
    final ctx:Dynamic;

    public function new(ctx:Dynamic) {
        this.ctx = ctx;
    }

    public function getValue(key:String):Any {
        return Reflect.field(ctx, key);
    }
}

/**
 * vscode's test helpers (keybindingsTestUtils.ts).
 */
class KeybindingsTestUtils {

    /**
     * `encodedKeybinding` is a number (a chord or `KeyChord`) or an array of
     * numbers (one per chord); 0 gives null.
     */
    public static function createUSLayoutResolvedKeybinding(encodedKeybinding:EitherType<Int, Array<Int>>, OS:OperatingSystem):Null<USLayoutResolvedKeybinding> {
        if (encodedKeybinding == null || (JsValues.isNumber(encodedKeybinding) && (encodedKeybinding : Int) == 0)) {
            return null;
        }
        final keybinding = JsValues.isArray(encodedKeybinding) ? Keybindings.decodeKeybindingChords(cast encodedKeybinding, OS) : Keybindings.decodeKeybinding(cast encodedKeybinding, OS);
        if (keybinding == null) {
            return null;
        }
        final result = USLayoutResolvedKeybinding.resolveKeybinding(keybinding, OS);
        if (result.length > 0) {
            return result[0];
        }
        return null;
    }

}

/**
 * vscode's 'KeybindingResolver' tests. `assert.deepStrictEqual` on the
 * resolved keybinding items compares their chords, command, arguments,
 * `when` and default flag.
 */
class KeybindingResolverTest extends TestCase {

    static function createContext(ctx:Dynamic):IContext {
        return new TestContext(ctx);
    }

    static function kbItem(keybinding:EitherType<Int, Array<Int>>, command:String, commandArgs:Any, when:Null<ContextKeyExpression>, isDefault:Bool):ResolvedKeybindingItem {
        final resolvedKeybinding = KeybindingsTestUtils.createUSLayoutResolvedKeybinding(keybinding, Platform.OS);
        return new ResolvedKeybindingItem(
            resolvedKeybinding,
            command,
            commandArgs,
            when,
            isDefault,
            null,
            false
        );
    }

    static function getDispatchStr(chord:KeyCodeChord):String {
        return USLayoutResolvedKeybinding.getDispatchStr(chord);
    }

    static function itemsStr(items:Array<ResolvedKeybindingItem>):String {
        return [for (item in items) '[' + item.chords.join(' ') + '] ' + item.command + (item.bubble ? ' (bubble)' : '') + ' ' + (item.commandArgs == null ? 'null' : haxe.Json.stringify(item.commandArgs)) + ' when ' + (item.when == null ? 'undefined' : item.when.serialize()) + ' ' + item.isDefault].join('\n');
    }

    function assertItems(expected:Array<ResolvedKeybindingItem>, actual:Array<ResolvedKeybindingItem>, ?pos:haxe.PosInfos):Void {
        assertEquals(itemsStr(expected), itemsStr(actual), null, pos);
    }

    function testResolveKey() {
        final keybinding = KeyMod.CtrlCmd | KeyMod.Shift | KeyCode.KeyZ;
        final runtimeKeybinding = Keybindings.createSimpleKeybinding(keybinding, Platform.OS);
        final contextRules = ContextKeyExpr.equals('bar', 'baz');
        final keybindingItem = kbItem(keybinding, 'yes', null, contextRules, true);

        assertEquals(true, contextRules.evaluate(createContext({bar: 'baz'})));
        assertEquals(false, contextRules.evaluate(createContext({bar: 'bz'})));

        final resolver = new KeybindingResolver([keybindingItem], [], (_) -> {});

        final r1 = resolver.resolve(createContext({bar: 'baz'}), [], getDispatchStr(runtimeKeybinding));
        assertTrue(r1.kind == ResultKind.KbFound);
        assertEquals('yes', r1.commandId);

        final r2 = resolver.resolve(createContext({bar: 'bz'}), [], getDispatchStr(runtimeKeybinding));
        assertEquals(ResultKind.NoMatchingKb, r2.kind);
    }

    function testResolveKeyWithArguments() {
        final commandArgs = {text: 'no'};
        final keybinding = KeyMod.CtrlCmd | KeyMod.Shift | KeyCode.KeyZ;
        final runtimeKeybinding = Keybindings.createSimpleKeybinding(keybinding, Platform.OS);
        final contextRules = ContextKeyExpr.equals('bar', 'baz');
        final keybindingItem = kbItem(keybinding, 'yes', commandArgs, contextRules, true);

        final resolver = new KeybindingResolver([keybindingItem], [], (_) -> {});

        final r = resolver.resolve(createContext({bar: 'baz'}), [], getDispatchStr(runtimeKeybinding));
        assertTrue(r.kind == ResultKind.KbFound);
        assertTrue(r.commandArgs == commandArgs);
    }

    // suite 'handle keybinding removals'

    function testSimple1() {
        final defaults = [
            kbItem(KeyCode.KeyA, 'yes1', null, ContextKeyExpr.equals('1', 'a'), true)
        ];
        final overrides = [
            kbItem(KeyCode.KeyB, 'yes2', null, ContextKeyExpr.equals('2', 'b'), false)
        ];
        final actual = KeybindingResolver.handleRemovals(defaults.concat(overrides));
        assertItems([
            kbItem(KeyCode.KeyA, 'yes1', null, ContextKeyExpr.equals('1', 'a'), true),
            kbItem(KeyCode.KeyB, 'yes2', null, ContextKeyExpr.equals('2', 'b'), false),
        ], actual);
    }

    function testSimple2() {
        final defaults = [
            kbItem(KeyCode.KeyA, 'yes1', null, ContextKeyExpr.equals('1', 'a'), true),
            kbItem(KeyCode.KeyB, 'yes2', null, ContextKeyExpr.equals('2', 'b'), true)
        ];
        final overrides = [
            kbItem(KeyCode.KeyC, 'yes3', null, ContextKeyExpr.equals('3', 'c'), false)
        ];
        final actual = KeybindingResolver.handleRemovals(defaults.concat(overrides));
        assertItems([
            kbItem(KeyCode.KeyA, 'yes1', null, ContextKeyExpr.equals('1', 'a'), true),
            kbItem(KeyCode.KeyB, 'yes2', null, ContextKeyExpr.equals('2', 'b'), true),
            kbItem(KeyCode.KeyC, 'yes3', null, ContextKeyExpr.equals('3', 'c'), false),
        ], actual);
    }

    function testRemovalWithNotMatchingWhen() {
        final defaults = [
            kbItem(KeyCode.KeyA, 'yes1', null, ContextKeyExpr.equals('1', 'a'), true),
            kbItem(KeyCode.KeyB, 'yes2', null, ContextKeyExpr.equals('2', 'b'), true)
        ];
        final overrides = [
            kbItem(KeyCode.KeyA, '-yes1', null, ContextKeyExpr.equals('1', 'b'), false)
        ];
        final actual = KeybindingResolver.handleRemovals(defaults.concat(overrides));
        assertItems([
            kbItem(KeyCode.KeyA, 'yes1', null, ContextKeyExpr.equals('1', 'a'), true),
            kbItem(KeyCode.KeyB, 'yes2', null, ContextKeyExpr.equals('2', 'b'), true)
        ], actual);
    }

    function testRemovalWithNotMatchingKeybinding() {
        final defaults = [
            kbItem(KeyCode.KeyA, 'yes1', null, ContextKeyExpr.equals('1', 'a'), true),
            kbItem(KeyCode.KeyB, 'yes2', null, ContextKeyExpr.equals('2', 'b'), true)
        ];
        final overrides = [
            kbItem(KeyCode.KeyB, '-yes1', null, ContextKeyExpr.equals('1', 'a'), false)
        ];
        final actual = KeybindingResolver.handleRemovals(defaults.concat(overrides));
        assertItems([
            kbItem(KeyCode.KeyA, 'yes1', null, ContextKeyExpr.equals('1', 'a'), true),
            kbItem(KeyCode.KeyB, 'yes2', null, ContextKeyExpr.equals('2', 'b'), true)
        ], actual);
    }

    function testRemovalWithMatchingKeybindingAndWhen() {
        final defaults = [
            kbItem(KeyCode.KeyA, 'yes1', null, ContextKeyExpr.equals('1', 'a'), true),
            kbItem(KeyCode.KeyB, 'yes2', null, ContextKeyExpr.equals('2', 'b'), true)
        ];
        final overrides = [
            kbItem(KeyCode.KeyA, '-yes1', null, ContextKeyExpr.equals('1', 'a'), false)
        ];
        final actual = KeybindingResolver.handleRemovals(defaults.concat(overrides));
        assertItems([
            kbItem(KeyCode.KeyB, 'yes2', null, ContextKeyExpr.equals('2', 'b'), true)
        ], actual);
    }

    function testRemovalWithUnspecifiedKeybinding() {
        final defaults = [
            kbItem(KeyCode.KeyA, 'yes1', null, ContextKeyExpr.equals('1', 'a'), true),
            kbItem(KeyCode.KeyB, 'yes2', null, ContextKeyExpr.equals('2', 'b'), true)
        ];
        final overrides = [
            kbItem(0, '-yes1', null, ContextKeyExpr.equals('1', 'a'), false)
        ];
        final actual = KeybindingResolver.handleRemovals(defaults.concat(overrides));
        assertItems([
            kbItem(KeyCode.KeyB, 'yes2', null, ContextKeyExpr.equals('2', 'b'), true)
        ], actual);
    }

    function testRemovalWithUnspecifiedWhen() {
        final defaults = [
            kbItem(KeyCode.KeyA, 'yes1', null, ContextKeyExpr.equals('1', 'a'), true),
            kbItem(KeyCode.KeyB, 'yes2', null, ContextKeyExpr.equals('2', 'b'), true)
        ];
        final overrides = [
            kbItem(KeyCode.KeyA, '-yes1', null, null, false)
        ];
        final actual = KeybindingResolver.handleRemovals(defaults.concat(overrides));
        assertItems([
            kbItem(KeyCode.KeyB, 'yes2', null, ContextKeyExpr.equals('2', 'b'), true)
        ], actual);
    }

    function testRemovalWithUnspecifiedWhenAndUnspecifiedKeybinding() {
        final defaults = [
            kbItem(KeyCode.KeyA, 'yes1', null, ContextKeyExpr.equals('1', 'a'), true),
            kbItem(KeyCode.KeyB, 'yes2', null, ContextKeyExpr.equals('2', 'b'), true)
        ];
        final overrides = [
            kbItem(0, '-yes1', null, null, false)
        ];
        final actual = KeybindingResolver.handleRemovals(defaults.concat(overrides));
        assertItems([
            kbItem(KeyCode.KeyB, 'yes2', null, ContextKeyExpr.equals('2', 'b'), true)
        ], actual);
    }

    function testIssue138997RemovalInDefaultList() {
        final defaults = [
            kbItem(KeyCode.KeyA, 'yes1', null, null, true),
            kbItem(KeyCode.KeyB, 'yes2', null, null, true),
            kbItem(0, '-yes1', null, null, false)
        ];
        final overrides:Array<ResolvedKeybindingItem> = [];
        final actual = KeybindingResolver.handleRemovals(defaults.concat(overrides));
        assertItems([
            kbItem(KeyCode.KeyB, 'yes2', null, null, true)
        ], actual);
    }

    function testIssue612CannotRemoveKeybindingsForCommandsWithCaret() {
        final defaults = [
            kbItem(KeyCode.KeyA, '^yes1', null, ContextKeyExpr.equals('1', 'a'), true),
            kbItem(KeyCode.KeyB, 'yes2', null, ContextKeyExpr.equals('2', 'b'), true)
        ];
        final overrides = [
            kbItem(KeyCode.KeyA, '-yes1', null, null, false)
        ];
        final actual = KeybindingResolver.handleRemovals(defaults.concat(overrides));
        assertItems([
            kbItem(KeyCode.KeyB, 'yes2', null, ContextKeyExpr.equals('2', 'b'), true)
        ], actual);
    }

    function testIssue140884UnableToReassignF1AsKeybindingForShowAllCommands() {
        final defaults = [
            kbItem(KeyCode.KeyA, 'command1', null, null, true),
        ];
        final overrides = [
            kbItem(KeyCode.KeyA, '-command1', null, null, false),
            kbItem(KeyCode.KeyA, 'command1', null, null, false),
        ];
        final actual = KeybindingResolver.handleRemovals(defaults.concat(overrides));
        assertItems([
            kbItem(KeyCode.KeyA, 'command1', null, null, false)
        ], actual);
    }

    function testIssue141638ChangeWhenExpressionMightActuallyRemoveKeybinding() {
        final defaults = [
            kbItem(KeyCode.KeyA, 'command1', null, null, true),
        ];
        final overrides = [
            kbItem(KeyCode.KeyA, 'command1', null, ContextKeyExpr.equals('a', '1'), false),
            kbItem(KeyCode.KeyA, '-command1', null, null, false),
        ];
        final actual = KeybindingResolver.handleRemovals(defaults.concat(overrides));
        assertItems([
            kbItem(KeyCode.KeyA, 'command1', null, ContextKeyExpr.equals('a', '1'), false)
        ], actual);
    }

    function testIssue157751AutoQuotingOfContextKeysPreventsRemovalOfKeybindingsViaUI() {
        final defaults = [
            kbItem(KeyCode.KeyA, 'command1', null, ContextKeyExpr.deserialize('editorTextFocus && activeEditor != workbench.editor.notebook && editorLangId in julia.supportedLanguageIds'), true),
        ];
        final overrides = [
            kbItem(KeyCode.KeyA, '-command1', null, ContextKeyExpr.deserialize('editorTextFocus && activeEditor != \'workbench.editor.notebook\' && editorLangId in \'julia.supportedLanguageIds\''), false),
        ];
        final actual = KeybindingResolver.handleRemovals(defaults.concat(overrides));
        assertItems([], actual);
    }

    function testIssue160604RemoveKeybindingsWithWhenClauseDoesNotWork() {
        final defaults = [
            kbItem(KeyCode.KeyA, 'command1', null, null, true),
        ];
        final overrides = [
            kbItem(KeyCode.KeyA, '-command1', null, ContextKeyExpr.trueExpr(), false),
        ];
        final actual = KeybindingResolver.handleRemovals(defaults.concat(overrides));
        assertItems([], actual);
    }

    function testContextIsEntirelyIncluded() {
        final toContextKeyExpression = (expr:Any) -> {
            if (expr == null || JsValues.isString(expr)) {
                return ContextKeyExpr.deserialize(expr);
            }
            return (expr : ContextKeyExpression);
        };
        final assertIsIncluded = (a:Any, b:Any) -> {
            assertEquals(true, KeybindingResolver.whenIsEntirelyIncluded(toContextKeyExpression(a), toContextKeyExpression(b)), a + ' / ' + b);
        };
        final assertIsNotIncluded = (a:Any, b:Any) -> {
            assertEquals(false, KeybindingResolver.whenIsEntirelyIncluded(toContextKeyExpression(a), toContextKeyExpression(b)), a + ' / ' + b);
        };

        assertIsIncluded(null, null);
        assertIsIncluded(null, ContextKeyExpr.trueExpr());
        assertIsIncluded(ContextKeyExpr.trueExpr(), null);
        assertIsIncluded(ContextKeyExpr.trueExpr(), ContextKeyExpr.trueExpr());
        assertIsIncluded('key1', null);
        assertIsIncluded('key1', '');
        assertIsIncluded('key1', 'key1');
        assertIsIncluded('key1', ContextKeyExpr.trueExpr());
        assertIsIncluded('!key1', '');
        assertIsIncluded('!key1', '!key1');
        assertIsIncluded('key2', '');
        assertIsIncluded('key2', 'key2');
        assertIsIncluded('key1 && key1 && key2 && key2', 'key2');
        assertIsIncluded('key1 && key2', 'key2');
        assertIsIncluded('key1 && key2', 'key1');
        assertIsIncluded('key1 && key2', '');
        assertIsIncluded('key1', 'key1 || key2');
        assertIsIncluded('key1 || !key1', 'key2 || !key2');
        assertIsIncluded('key1', 'key1 || key2 && key3');

        assertIsNotIncluded('key1', '!key1');
        assertIsNotIncluded('!key1', 'key1');
        assertIsNotIncluded('key1 && key2', 'key3');
        assertIsNotIncluded('key1 && key2', 'key4');
        assertIsNotIncluded('key1', 'key2');
        assertIsNotIncluded('key1 || key2', 'key2');
        assertIsNotIncluded('', 'key2');
        assertIsNotIncluded(null, 'key2');
    }

    // suite 'resolve command'

    static function _kbItem(keybinding:EitherType<Int, Array<Int>>, command:String, when:Null<ContextKeyExpression>):ResolvedKeybindingItem {
        return kbItem(keybinding, command, null, when, true);
    }

    var resolver:Null<KeybindingResolver> = null;

    override public function setup():Void {
        final items = [
            // This one will never match because its "when" is always overwritten by another one
            _kbItem(
                KeyCode.KeyX,
                'first',
                ContextKeyExpr.and(
                    ContextKeyExpr.equals('key1', true),
                    ContextKeyExpr.notEquals('key2', false)
                )
            ),
            // This one always overwrites first
            _kbItem(
                KeyCode.KeyX,
                'second',
                ContextKeyExpr.equals('key2', true)
            ),
            // This one is a secondary mapping for `second`
            _kbItem(
                KeyCode.KeyZ,
                'second',
                null
            ),
            // This one sometimes overwrites first
            _kbItem(
                KeyCode.KeyX,
                'third',
                ContextKeyExpr.equals('key3', true)
            ),
            // This one is always overwritten by another one
            _kbItem(
                KeyMod.CtrlCmd | KeyCode.KeyY,
                'fourth',
                ContextKeyExpr.equals('key4', true)
            ),
            // This one overwrites with a chord the previous one
            _kbItem(
                KeyCodes.KeyChord(KeyMod.CtrlCmd | KeyCode.KeyY, KeyCode.KeyZ),
                'fifth',
                null
            ),
            // This one has no keybinding
            _kbItem(
                0,
                'sixth',
                null
            ),
            _kbItem(
                KeyCodes.KeyChord(KeyMod.CtrlCmd | KeyCode.KeyK, KeyMod.CtrlCmd | KeyCode.KeyU),
                'seventh',
                null
            ),
            _kbItem(
                KeyCodes.KeyChord(KeyMod.CtrlCmd | KeyCode.KeyK, KeyMod.CtrlCmd | KeyCode.KeyK),
                'seventh',
                null
            ),
            _kbItem(
                KeyCodes.KeyChord(KeyMod.CtrlCmd | KeyCode.KeyK, KeyMod.CtrlCmd | KeyCode.KeyU),
                'uncomment lines',
                null
            ),
            _kbItem(
                KeyCodes.KeyChord(KeyMod.CtrlCmd | KeyCode.KeyK, KeyMod.CtrlCmd | KeyCode.KeyC), // cmd+k cmd+c
                'comment lines',
                null
            ),
            _kbItem(
                KeyCodes.KeyChord(KeyMod.CtrlCmd | KeyCode.KeyG, KeyMod.CtrlCmd | KeyCode.KeyC), // cmd+g cmd+c
                'unreachablechord',
                null
            ),
            _kbItem(
                KeyMod.CtrlCmd | KeyCode.KeyG, // cmd+g
                'eleven',
                null
            ),
            _kbItem(
                [KeyMod.CtrlCmd | KeyCode.KeyK, KeyCode.KeyA, KeyCode.KeyB], // cmd+k a b
                'long multi chord',
                null
            ),
            _kbItem(
                [KeyMod.CtrlCmd | KeyCode.KeyB, KeyMod.CtrlCmd | KeyCode.KeyC], // cmd+b cmd+c
                'shadowed by long-multi-chord-2',
                null
            ),
            _kbItem(
                [KeyMod.CtrlCmd | KeyCode.KeyB, KeyMod.CtrlCmd | KeyCode.KeyC, KeyCode.KeyI], // cmd+b cmd+c i
                'long-multi-chord-2',
                null
            )
        ];

        resolver = new KeybindingResolver(items, [], (_) -> {});
    }

    function checkKbLookupByCommand(commandId:String, expectedKeys:Array<EitherType<Int, Array<Int>>>, ?pos:haxe.PosInfos):Void {
        // Test lookup
        final lookupResult = resolver.lookupKeybindings(commandId);
        assertEquals(expectedKeys.length, lookupResult.length, 'Length mismatch @ commandId ' + commandId, pos);
        for (i in 0...lookupResult.length) {
            final expected = KeybindingsTestUtils.createUSLayoutResolvedKeybinding(expectedKeys[i], Platform.OS);

            assertEquals(expected.getUserSettingsLabel(), lookupResult[i].resolvedKeybinding.getUserSettingsLabel(), 'value mismatch @ commandId ' + commandId, pos);
        }
    }

    function checkResolve(ctx:IContext, _expectedKey:EitherType<Int, Array<Int>>, commandId:String, ?pos:haxe.PosInfos):Void {
        final expectedKeybinding = JsValues.isArray(_expectedKey) ? Keybindings.decodeKeybindingChords(cast _expectedKey, Platform.OS) : Keybindings.decodeKeybinding(cast _expectedKey, Platform.OS);

        final previousChord:Array<String> = [];

        final len = expectedKeybinding.chords.length;
        for (i in 0...len) {

            final chord = getDispatchStr(cast expectedKeybinding.chords[i]);

            final result = resolver.resolve(ctx, previousChord, chord);

            if (i == len - 1) {
                // if it's the final chord, then we should find a valid command,
                // and there should not be a chord.
                assertTrue(result.kind == ResultKind.KbFound, 'Enters multi chord for ' + commandId + ' at chord ' + i, pos);
                assertEquals(commandId, result.commandId, 'Enters multi chord for ' + commandId + ' at chord ' + i, pos);
            }
            else if (i > 0) {
                // if this is an intermediate chord, we should not find a valid command,
                // and there should be an open chord we continue.
                assertTrue(result.kind == ResultKind.MoreChordsNeeded, 'Continues multi chord for ' + commandId + ' at chord ' + i, pos);
            }
            else {
                // if it's not the final chord and not an intermediate, then we should not
                // find a valid command, and we should enter a chord.
                assertTrue(result.kind == ResultKind.MoreChordsNeeded, 'Enters multi chord for ' + commandId + ' at chord ' + i, pos);
            }
            previousChord.push(chord);
        }
    }

    function testResolveCommand1() {
        checkKbLookupByCommand('first', []);
    }

    function testResolveCommand2() {
        checkKbLookupByCommand('second', [KeyCode.KeyZ, KeyCode.KeyX]);
        checkResolve(createContext({key2: true}), KeyCode.KeyX, 'second');
        checkResolve(createContext({}), KeyCode.KeyZ, 'second');
    }

    function testResolveCommand3() {
        checkKbLookupByCommand('third', [KeyCode.KeyX]);
        checkResolve(createContext({key3: true}), KeyCode.KeyX, 'third');
    }

    function testResolveCommand4() {
        checkKbLookupByCommand('fourth', []);
    }

    function testResolveCommand5() {
        checkKbLookupByCommand('fifth', [KeyCodes.KeyChord(KeyMod.CtrlCmd | KeyCode.KeyY, KeyCode.KeyZ)]);
        checkResolve(createContext({}), KeyCodes.KeyChord(KeyMod.CtrlCmd | KeyCode.KeyY, KeyCode.KeyZ), 'fifth');
    }

    function testResolveCommand6() {
        checkKbLookupByCommand('seventh', [KeyCodes.KeyChord(KeyMod.CtrlCmd | KeyCode.KeyK, KeyMod.CtrlCmd | KeyCode.KeyK)]);
        checkResolve(createContext({}), KeyCodes.KeyChord(KeyMod.CtrlCmd | KeyCode.KeyK, KeyMod.CtrlCmd | KeyCode.KeyK), 'seventh');
    }

    function testResolveCommand7() {
        checkKbLookupByCommand('uncomment lines', [KeyCodes.KeyChord(KeyMod.CtrlCmd | KeyCode.KeyK, KeyMod.CtrlCmd | KeyCode.KeyU)]);
        checkResolve(createContext({}), KeyCodes.KeyChord(KeyMod.CtrlCmd | KeyCode.KeyK, KeyMod.CtrlCmd | KeyCode.KeyU), 'uncomment lines');
    }

    function testResolveCommand8() {
        checkKbLookupByCommand('comment lines', [KeyCodes.KeyChord(KeyMod.CtrlCmd | KeyCode.KeyK, KeyMod.CtrlCmd | KeyCode.KeyC)]);
        checkResolve(createContext({}), KeyCodes.KeyChord(KeyMod.CtrlCmd | KeyCode.KeyK, KeyMod.CtrlCmd | KeyCode.KeyC), 'comment lines');
    }

    function testResolveCommand9() {
        checkKbLookupByCommand('unreachablechord', []);
    }

    function testResolveCommand10() {
        checkKbLookupByCommand('eleven', [KeyMod.CtrlCmd | KeyCode.KeyG]);
        checkResolve(createContext({}), KeyMod.CtrlCmd | KeyCode.KeyG, 'eleven');
    }

    function testResolveCommand11() {
        checkKbLookupByCommand('sixth', []);
    }

    function testResolveCommand12() {
        checkKbLookupByCommand('long multi chord', [[KeyMod.CtrlCmd | KeyCode.KeyK, KeyCode.KeyA, KeyCode.KeyB]]);
        checkResolve(createContext({}), [KeyMod.CtrlCmd | KeyCode.KeyK, KeyCode.KeyA, KeyCode.KeyB], 'long multi chord');
    }

    function testKBsHavingCommonPrefixTheOneDefinedLaterIsReturned() {
        checkResolve(createContext({}), [KeyMod.CtrlCmd | KeyCode.KeyB, KeyMod.CtrlCmd | KeyCode.KeyC, KeyCode.KeyI], 'long-multi-chord-2');
    }

}
