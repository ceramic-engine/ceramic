// Ported from vscode src/vs/editor/contrib/codeAction/test/browser/codeActionKeybindingResolver.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.contrib.codeAction;

import cityscape.base.common.KeyCodes.KeyCode;
import cityscape.base.common.Keybindings.KeyCodeChord;
import cityscape.base.common.Platform.OperatingSystem;
import cityscape.contrib.codeAction.common.CodeActionTypes;
import cityscape.contrib.codeAction.view.CodeAction.CodeActionCommandIds;
import cityscape.contrib.codeAction.view.CodeActionKeybindingResolver;
import cityscape.platform.keybinding.common.ResolvedKeybindingItem;
import cityscape.platform.keybinding.common.UsLayoutResolvedKeybinding.USLayoutResolvedKeybinding;
import testing.TestCase;

/**
 * suite('CodeActionKeybindingResolver'). vscode's mock keybinding service
 * is the function giving the keybindings.
 */
class CodeActionKeybindingResolverTest extends TestCase {

    static function createCodeActionKeybinding(keycode:KeyCode, command:String, commandArgs:Any):ResolvedKeybindingItem {
        return new ResolvedKeybindingItem(
            new USLayoutResolvedKeybinding(
                [new KeyCodeChord(false, true, false, false, keycode)],
                OperatingSystem.Linux),
            command,
            commandArgs,
            null,
            false,
            null,
            false);
    }

    final refactorKeybinding = createCodeActionKeybinding(
        KeyCode.KeyA,
        CodeActionCommandIds.refactorCommandId,
        {kind: CodeActionKind.Refactor.value});

    final refactorExtractKeybinding = createCodeActionKeybinding(
        KeyCode.KeyB,
        CodeActionCommandIds.refactorCommandId,
        {kind: CodeActionKind.Refactor.append('extract').value});

    final organizeImportsKeybinding = createCodeActionKeybinding(
        KeyCode.KeyC,
        CodeActionCommandIds.organizeImportsCommandId,
        null);

    function testShouldMatchRefactorKeybindings() {
        final resolver = new CodeActionKeybindingResolver(() -> [refactorKeybinding]).getResolver();

        assertEquals(null, resolver({title: ''}));

        assertTrue(resolver({title: '', kind: CodeActionKind.Refactor.value}) == refactorKeybinding.resolvedKeybinding);

        assertTrue(resolver({title: '', kind: CodeActionKind.Refactor.append('extract').value}) == refactorKeybinding.resolvedKeybinding);

        assertEquals(null, resolver({title: '', kind: CodeActionKind.QuickFix.value}));
    }

    function testShouldPreferMostSpecificKeybinding() {
        final resolver = new CodeActionKeybindingResolver(() -> [refactorKeybinding, refactorExtractKeybinding, organizeImportsKeybinding]).getResolver();

        assertTrue(resolver({title: '', kind: CodeActionKind.Refactor.value}) == refactorKeybinding.resolvedKeybinding);

        assertTrue(resolver({title: '', kind: CodeActionKind.Refactor.append('extract').value}) == refactorExtractKeybinding.resolvedKeybinding);
    }

    function testOrganizeImportsShouldStillReturnAKeybindingEvenThoughItDoesNotHaveArgs() {
        final resolver = new CodeActionKeybindingResolver(() -> [refactorKeybinding, refactorExtractKeybinding, organizeImportsKeybinding]).getResolver();

        assertTrue(resolver({title: '', kind: CodeActionKind.SourceOrganizeImports.value}) == organizeImportsKeybinding.resolvedKeybinding);
    }

}
