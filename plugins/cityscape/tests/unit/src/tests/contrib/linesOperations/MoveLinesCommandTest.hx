// Ported from vscode src/vs/editor/contrib/linesOperations/test/browser/moveLinesCommand.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.contrib.linesOperations;

import cityscape.Cityscape;
import cityscape.base.common.Lifecycle;
import cityscape.base.common.RegExp;
import cityscape.common.config.EditorOptions.EditorAutoIndentStrategy;
import cityscape.common.core.Selection;
import cityscape.common.languages.LanguageConfiguration.IndentationRule;
import cityscape.common.languages.LanguageConfigurationRegistry.ILanguageConfigurationService;
import cityscape.common.services.LanguageService;
import cityscape.contrib.linesOperations.view.MoveLinesCommand;
import testing.TestCase;
import testing.TestCommand;
import testing.TestLanguageConfigurationService;

enum abstract MoveLinesDirection(Int) {
    var Up;
    var Down;
}

/**
 * The helpers of moveLinesCommand.test.ts.
 */
private class MoveLinesTestHelper {

    public static function testMoveLinesUpOrDownCommand(test:TestCase, direction:MoveLinesDirection, lines:Array<String>, selection:Selection, expectedLines:Array<String>, expectedSelection:Selection, ?languageConfigurationService:ILanguageConfigurationService, ?pos:haxe.PosInfos):Void {
        final disposables = new DisposableStore();
        if (languageConfigurationService == null) {
            languageConfigurationService = disposables.add(new TestLanguageConfigurationService());
        }
        final service = languageConfigurationService;
        TestCommand.testCommand(test, lines, null, selection, (accessor, sel) -> new MoveLinesCommand(sel, direction == MoveLinesDirection.Up ? false : true, EditorAutoIndentStrategy.Advanced, service), expectedLines, expectedSelection, null, null, pos);
        disposables.dispose();
    }

    public static function testMoveLinesUpOrDownWithIndentCommand(test:TestCase, direction:MoveLinesDirection, languageId:Null<String>, lines:Array<String>, selection:Selection, expectedLines:Array<String>, expectedSelection:Selection, ?languageConfigurationService:ILanguageConfigurationService, ?pos:haxe.PosInfos):Void {
        final disposables = new DisposableStore();
        if (languageConfigurationService == null) {
            languageConfigurationService = disposables.add(new TestLanguageConfigurationService());
        }
        final service = languageConfigurationService;
        // vscode's `languageService.registerLanguage` goes to the global
        // `ModesRegistry`, so the language of the modes below is also known
        // to the language service of the test editor; the registries are per
        // context here (DEVIATIONS.md, "Registries per context"): register it
        // in the context of the test editor too.
        final prepare = languageId == null ? null : (accessor:Cityscape, disposables:DisposableStore) -> {
            disposables.add(accessor.languageService.registerLanguage({id: languageId}));
        };
        TestCommand.testCommand(test, lines, languageId, selection, (accessor, sel) -> new MoveLinesCommand(sel, direction == MoveLinesDirection.Up ? false : true, EditorAutoIndentStrategy.Full, service), expectedLines, expectedSelection, null, prepare, pos);
        disposables.dispose();
    }

}

/**
 * The test helpers of the move lines suites (vscode's module functions).
 */
abstract class MoveLinesTestCase extends TestCase {

    function doTestMoveLinesDownCommand(lines:Array<String>, selection:Selection, expectedLines:Array<String>, expectedSelection:Selection, ?languageConfigurationService:ILanguageConfigurationService, ?pos:haxe.PosInfos):Void {
        MoveLinesTestHelper.testMoveLinesUpOrDownCommand(this, MoveLinesDirection.Down, lines, selection, expectedLines, expectedSelection, languageConfigurationService, pos);
    }

    function doTestMoveLinesUpCommand(lines:Array<String>, selection:Selection, expectedLines:Array<String>, expectedSelection:Selection, ?languageConfigurationService:ILanguageConfigurationService, ?pos:haxe.PosInfos):Void {
        MoveLinesTestHelper.testMoveLinesUpOrDownCommand(this, MoveLinesDirection.Up, lines, selection, expectedLines, expectedSelection, languageConfigurationService, pos);
    }

    function doTestMoveLinesDownWithIndentCommand(languageId:Null<String>, lines:Array<String>, selection:Selection, expectedLines:Array<String>, expectedSelection:Selection, ?languageConfigurationService:ILanguageConfigurationService, ?pos:haxe.PosInfos):Void {
        MoveLinesTestHelper.testMoveLinesUpOrDownWithIndentCommand(this, MoveLinesDirection.Down, languageId, lines, selection, expectedLines, expectedSelection, languageConfigurationService, pos);
    }

    function doTestMoveLinesUpWithIndentCommand(languageId:Null<String>, lines:Array<String>, selection:Selection, expectedLines:Array<String>, expectedSelection:Selection, ?languageConfigurationService:ILanguageConfigurationService, ?pos:haxe.PosInfos):Void {
        MoveLinesTestHelper.testMoveLinesUpOrDownWithIndentCommand(this, MoveLinesDirection.Up, languageId, lines, selection, expectedLines, expectedSelection, languageConfigurationService, pos);
    }

}

/**
 * suite('Editor Contrib - Move Lines Command')
 */
class MoveLinesCommandTest extends MoveLinesTestCase {

    /**
     * test('move first up / last down disabled')
     */
    function testMoveFirstUpLastDownDisabled() {
        doTestMoveLinesUpCommand(
            [
                'first',
                'second line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(1, 1, 1, 1),
            [
                'first',
                'second line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(1, 1, 1, 1)
        );

        doTestMoveLinesDownCommand(
            [
                'first',
                'second line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(5, 1, 5, 1),
            [
                'first',
                'second line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(5, 1, 5, 1)
        );
    }

    /**
     * test('move first line down')
     */
    function testMoveFirstLineDown() {
        doTestMoveLinesDownCommand(
            [
                'first',
                'second line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(1, 4, 1, 1),
            [
                'second line',
                'first',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(2, 4, 2, 1)
        );
    }

    /**
     * test('move 2nd line up')
     */
    function testMove2ndLineUp() {
        doTestMoveLinesUpCommand(
            [
                'first',
                'second line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(2, 1, 2, 1),
            [
                'second line',
                'first',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(1, 1, 1, 1)
        );
    }

    /**
     * test('issue #1322a: move 2nd line up')
     */
    function testIssue1322aMove2ndLineUp() {
        doTestMoveLinesUpCommand(
            [
                'first',
                'second line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(2, 12, 2, 12),
            [
                'second line',
                'first',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(1, 12, 1, 12)
        );
    }

    /**
     * test('issue #1322b: move last line up')
     */
    function testIssue1322bMoveLastLineUp() {
        doTestMoveLinesUpCommand(
            [
                'first',
                'second line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(5, 6, 5, 6),
            [
                'first',
                'second line',
                'third line',
                'fifth',
                'fourth line'
            ],
            new Selection(4, 6, 4, 6)
        );
    }

    /**
     * test('issue #1322c: move last line selected up')
     */
    function testIssue1322cMoveLastLineSelectedUp() {
        doTestMoveLinesUpCommand(
            [
                'first',
                'second line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(5, 6, 5, 1),
            [
                'first',
                'second line',
                'third line',
                'fifth',
                'fourth line'
            ],
            new Selection(4, 6, 4, 1)
        );
    }

    /**
     * test('move last line up')
     */
    function testMoveLastLineUp() {
        doTestMoveLinesUpCommand(
            [
                'first',
                'second line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(5, 1, 5, 1),
            [
                'first',
                'second line',
                'third line',
                'fifth',
                'fourth line'
            ],
            new Selection(4, 1, 4, 1)
        );
    }

    /**
     * test('move 4th line down')
     */
    function testMove4thLineDown() {
        doTestMoveLinesDownCommand(
            [
                'first',
                'second line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(4, 1, 4, 1),
            [
                'first',
                'second line',
                'third line',
                'fifth',
                'fourth line'
            ],
            new Selection(5, 1, 5, 1)
        );
    }

    /**
     * test('move multiple lines down')
     */
    function testMoveMultipleLinesDown() {
        doTestMoveLinesDownCommand(
            [
                'first',
                'second line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(4, 4, 2, 2),
            [
                'first',
                'fifth',
                'second line',
                'third line',
                'fourth line'
            ],
            new Selection(5, 4, 3, 2)
        );
    }

    /**
     * test('invisible selection is ignored')
     */
    function testInvisibleSelectionIsIgnored() {
        doTestMoveLinesDownCommand(
            [
                'first',
                'second line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(2, 1, 1, 1),
            [
                'second line',
                'first',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(3, 1, 2, 1)
        );
    }

}

class IndentRulesMode extends Disposable {

    public final languageId = 'moveLinesIndentMode';

    public function new(indentationRules:IndentationRule, languageService:LanguageService, languageConfigurationService:ILanguageConfigurationService) {
        super();
        this._register(languageService.registerLanguage({id: this.languageId}));
        this._register(languageConfigurationService.register(this.languageId, {
            indentationRules: indentationRules
        }));
    }

}

/**
 * suite('Editor contrib - Move Lines Command honors Indentation Rules')
 */
class EditorContribMoveLinesCommandHonorsIndentationRulesTest extends MoveLinesTestCase {

    final indentRules:IndentationRule = {
        decreaseIndentPattern: new RegExp("^\\s*((?!\\S.*\\/[*]).*[*]\\/\\s*)?[})\\]]|^\\s*(case\\b.*|default):\\s*(\\/\\/.*|\\/[*].*[*]\\/\\s*)?$"),
        increaseIndentPattern: new RegExp("(\\{[^}\"'`]*|\\([^)\"']*|\\[[^\\]\"']*|^\\s*(\\{\\}|\\(\\)|\\[\\]|(case\\b.*|default):))\\s*(\\/\\/.*|\\/[*].*[*]\\/\\s*)?$"),
        indentNextLinePattern: new RegExp("^\\s*(for|while|if|else)\\b(?!.*[;{}]\\s*(\\/\\/.*|\\/[*].*[*]\\/\\s*)?$)"),
        unIndentedLinePattern: new RegExp("^(?!.*([;{}]|\\S:)\\s*(\\/\\/.*|\\/[*].*[*]\\/\\s*)?$)(?!.*(\\{[^}\"']*|\\([^)\"']*|\\[[^\\]\"']*|^\\s*(\\{\\}|\\(\\)|\\[\\]|(case\\b.*|default):))\\s*(\\/\\/.*|\\/[*].*[*]\\/\\s*)?$)(?!^\\s*((?!\\S.*\\/[*]).*[*]\\/\\s*)?[})\\]]|^\\s*(case\\b.*|default):\\s*(\\/\\/.*|\\/[*].*[*]\\/\\s*)?$)(?!^\\s*(for|while|if|else)\\b(?!.*[;{}]\\s*(\\/\\/.*|\\/[*].*[*]\\/\\s*)?$))")
    };

    /**
     * test('first line indentation adjust to 0')
     */
    function testFirstLineIndentationAdjustTo0() {
        final languageService = new LanguageService();
        final languageConfigurationService = new TestLanguageConfigurationService();
        final mode = new IndentRulesMode(indentRules, languageService, languageConfigurationService);

        doTestMoveLinesUpWithIndentCommand(
            mode.languageId,
            [
                'class X {',
                '\tz = 2',
                '}'
            ],
            new Selection(2, 1, 2, 1),
            [
                'z = 2',
                'class X {',
                '}'
            ],
            new Selection(1, 1, 1, 1),
            languageConfigurationService
        );

        mode.dispose();
        languageService.dispose();
        languageConfigurationService.dispose();
    }

    /**
     * test('move lines across block')
     */
    function testMoveLinesAcrossBlock() {
        final languageService = new LanguageService();
        final languageConfigurationService = new TestLanguageConfigurationService();
        final mode = new IndentRulesMode(indentRules, languageService, languageConfigurationService);

        doTestMoveLinesDownWithIndentCommand(
            mode.languageId,
            [
                'const value = 2;',
                'const standardLanguageDescriptions = [',
                '    {',
                '        diagnosticSource: \'js\',',
                '    }',
                '];'
            ],
            new Selection(1, 1, 1, 1),
            [
                'const standardLanguageDescriptions = [',
                '    const value = 2;',
                '    {',
                '        diagnosticSource: \'js\',',
                '    }',
                '];'
            ],
            new Selection(2, 5, 2, 5),
            languageConfigurationService
        );

        mode.dispose();
        languageService.dispose();
        languageConfigurationService.dispose();
    }

    /**
     * test('move line should still work as before if there is no indentation rules')
     */
    function testMoveLineShouldStillWorkAsBeforeIfThereIsNoIndentationRules() {
        doTestMoveLinesUpWithIndentCommand(
            null,
            [
                'if (true) {',
                '    var task = new Task(() => {',
                '        var work = 1234;',
                '    });',
                '}'
            ],
            new Selection(3, 1, 3, 1),
            [
                'if (true) {',
                '        var work = 1234;',
                '    var task = new Task(() => {',
                '    });',
                '}'
            ],
            new Selection(2, 1, 2, 1)
        );
    }

}

class EnterRulesMode extends Disposable {

    public final languageId = 'moveLinesEnterMode';

    public function new(languageService:LanguageService, languageConfigurationService:ILanguageConfigurationService) {
        super();
        this._register(languageService.registerLanguage({id: this.languageId}));
        this._register(languageConfigurationService.register(this.languageId, {
            indentationRules: {
                decreaseIndentPattern: new RegExp("^\\s*\\[$"),
                increaseIndentPattern: new RegExp("^\\s*\\]$"),
            },
            brackets: [
                ['{', '}']
            ]
        }));
    }

}

/**
 * suite('Editor - contrib - Move Lines Command honors onEnter Rules')
 */
class EditorContribMoveLinesCommandHonorsOnEnterRulesTest extends MoveLinesTestCase {

    /**
     * test('issue #54829. move block across block')
     */
    function testIssue54829MoveBlockAcrossBlock() {
        final languageService = new LanguageService();
        final languageConfigurationService = new TestLanguageConfigurationService();
        final mode = new EnterRulesMode(languageService, languageConfigurationService);

        doTestMoveLinesDownWithIndentCommand(
            mode.languageId,

            [
                'if (true) {',
                '    if (false) {',
                '        if (1) {',
                '            console.log(\'b\');',
                '        }',
                '        console.log(\'a\');',
                '    }',
                '}'
            ],
            new Selection(3, 9, 5, 10),
            [
                'if (true) {',
                '    if (false) {',
                '        console.log(\'a\');',
                '        if (1) {',
                '            console.log(\'b\');',
                '        }',
                '    }',
                '}'
            ],
            new Selection(4, 9, 6, 10),
            languageConfigurationService
        );

        mode.dispose();
        languageService.dispose();
        languageConfigurationService.dispose();
    }

}
