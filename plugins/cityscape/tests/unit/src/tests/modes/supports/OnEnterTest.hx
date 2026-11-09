// Ported from vscode src/vs/editor/test/common/modes/supports/onEnter.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.modes.supports;

import cityscape.base.common.RegExp;
import cityscape.common.config.EditorOptions.EditorAutoIndentStrategy;
import cityscape.common.languages.LanguageConfiguration;
import cityscape.common.languages.supports.OnEnter;
import haxe.PosInfos;
import testing.TestCase;

/**
 * suite('OnEnter')
 */
class OnEnterTest extends TestCase {

    function testUsesBrackets() {
        final brackets:Array<CharacterPair> = [
            ['(', ')'],
            ['begin', 'end']
        ];
        final support = new OnEnterSupport({
            brackets: brackets
        });
        function testIndentAction(beforeText:String, afterText:String, expected:IndentAction, ?pos:PosInfos):Void {
            final actual = support.onEnter(EditorAutoIndentStrategy.Advanced, '', beforeText, afterText);
            if (expected == IndentAction.None) {
                assertEquals(actual, null, null, pos);
            }
            else {
                assertEquals(actual.indentAction, expected, null, pos);
            }
        }

        testIndentAction('a', '', IndentAction.None);
        testIndentAction('', 'b', IndentAction.None);
        testIndentAction('(', 'b', IndentAction.Indent);
        testIndentAction('a', ')', IndentAction.None);
        testIndentAction('begin', 'ending', IndentAction.Indent);
        testIndentAction('abegin', 'end', IndentAction.None);
        testIndentAction('begin', ')', IndentAction.Indent);
        testIndentAction('begin', 'end', IndentAction.IndentOutdent);
        testIndentAction('begin ', ' end', IndentAction.IndentOutdent);
        testIndentAction(' begin', 'end//as', IndentAction.IndentOutdent);
        testIndentAction('(', ')', IndentAction.IndentOutdent);
        testIndentAction('( ', ')', IndentAction.IndentOutdent);
        testIndentAction('a(', ')b', IndentAction.IndentOutdent);

        testIndentAction('(', '', IndentAction.Indent);
        testIndentAction('(', 'foo', IndentAction.Indent);
        testIndentAction('begin', 'foo', IndentAction.Indent);
        testIndentAction('begin', '', IndentAction.Indent);
    }

    function checkIndentAction(support:OnEnterSupport, previousLineText:String, beforeText:String, afterText:String, expectedIndentAction:Null<IndentAction>, expectedAppendText:Null<String>, removeText:Int = 0, ?pos:PosInfos):Void {
        final actual = support.onEnter(EditorAutoIndentStrategy.Advanced, previousLineText, beforeText, afterText);
        if (expectedIndentAction == null) {
            assertEquals(actual, null, 'isNull:' + beforeText, pos);
        }
        else {
            assertEquals(actual != null, true, 'isNotNull:' + beforeText, pos);
            if (actual == null) {
                return;
            }
            assertEquals(actual.indentAction, expectedIndentAction, 'indentAction:' + beforeText, pos);
            if (expectedAppendText != null) {
                assertEquals(actual.appendText, expectedAppendText, 'appendText:' + beforeText, pos);
            }
            if (removeText != 0) {
                assertEquals(actual.removeText, removeText, 'removeText:' + beforeText, pos);
            }
        }
    }

    function testIssue121125OnEnterRulesWithGlobalModifier() {
        final support = new OnEnterSupport({
            onEnterRules: [
                {
                    action: {
                        appendText: '/// ',
                        indentAction: IndentAction.Outdent
                    },
                    beforeText: new RegExp("^\\s*\\/{3}.*$", "gm")
                }
            ]
        });

        function testIndentAction(previousLineText:String, beforeText:String, afterText:String, expectedIndentAction:Null<IndentAction>, expectedAppendText:Null<String>, removeText:Int = 0, ?pos:PosInfos):Void {
            checkIndentAction(support, previousLineText, beforeText, afterText, expectedIndentAction, expectedAppendText, removeText, pos);
        }

        testIndentAction('/// line', '/// line', '', IndentAction.Outdent, '/// ');
        testIndentAction('/// line', '/// line', '', IndentAction.Outdent, '/// ');
    }

    function testUsesRegExpRules() {
        final support = new OnEnterSupport({
            onEnterRules: OnEnterRules.javascriptOnEnterRules
        });
        function testIndentAction(previousLineText:String, beforeText:String, afterText:String, expectedIndentAction:Null<IndentAction>, expectedAppendText:Null<String>, removeText:Int = 0, ?pos:PosInfos):Void {
            checkIndentAction(support, previousLineText, beforeText, afterText, expectedIndentAction, expectedAppendText, removeText, pos);
        }

        testIndentAction('', '\t/**', ' */', IndentAction.IndentOutdent, ' * ');
        testIndentAction('', '\t/**', '', IndentAction.None, ' * ');
        testIndentAction('', '\t/** * / * / * /', '', IndentAction.None, ' * ');
        testIndentAction('', '\t/** /*', '', IndentAction.None, ' * ');
        testIndentAction('', '/**', '', IndentAction.None, ' * ');
        testIndentAction('', '\t/**/', '', null, null);
        testIndentAction('', '\t/***/', '', null, null);
        testIndentAction('', '\t/*******/', '', null, null);
        testIndentAction('', '\t/** * * * * */', '', null, null);
        testIndentAction('', '\t/** */', '', null, null);
        testIndentAction('', '\t/** asdfg */', '', null, null);
        testIndentAction('', '\t/* asdfg */', '', null, null);
        testIndentAction('', '\t/* asdfg */', '', null, null);
        testIndentAction('', '\t/** asdfg */', '', null, null);
        testIndentAction('', '*/', '', null, null);
        testIndentAction('', '\t/*', '', null, null);
        testIndentAction('', '\t*', '', null, null);

        testIndentAction('\t/**', '\t *', '', IndentAction.None, '* ');
        testIndentAction('\t * something', '\t *', '', IndentAction.None, '* ');
        testIndentAction('\t *', '\t *', '', IndentAction.None, '* ');

        testIndentAction('', '\t */', '', IndentAction.None, null, 1);
        testIndentAction('', '\t * */', '', IndentAction.None, null, 1);
        testIndentAction('', '\t * * / * / * / */', '', null, null);

        testIndentAction('\t/**', '\t * ', '', IndentAction.None, '* ');
        testIndentAction('\t * something', '\t * ', '', IndentAction.None, '* ');
        testIndentAction('\t *', '\t * ', '', IndentAction.None, '* ');

        testIndentAction('/**', ' * ', '', IndentAction.None, '* ');
        testIndentAction(' * something', ' * ', '', IndentAction.None, '* ');
        testIndentAction(' *', ' * asdfsfagadfg', '', IndentAction.None, '* ');

        testIndentAction('/**', ' * asdfsfagadfg * * * ', '', IndentAction.None, '* ');
        testIndentAction(' * something', ' * asdfsfagadfg * * * ', '', IndentAction.None, '* ');
        testIndentAction(' *', ' * asdfsfagadfg * * * ', '', IndentAction.None, '* ');

        testIndentAction('/**', ' * /*', '', IndentAction.None, '* ');
        testIndentAction(' * something', ' * /*', '', IndentAction.None, '* ');
        testIndentAction(' *', ' * /*', '', IndentAction.None, '* ');

        testIndentAction('/**', ' * asdfsfagadfg * / * / * /', '', IndentAction.None, '* ');
        testIndentAction(' * something', ' * asdfsfagadfg * / * / * /', '', IndentAction.None, '* ');
        testIndentAction(' *', ' * asdfsfagadfg * / * / * /', '', IndentAction.None, '* ');

        testIndentAction('/**', ' * asdfsfagadfg * / * / * /*', '', IndentAction.None, '* ');
        testIndentAction(' * something', ' * asdfsfagadfg * / * / * /*', '', IndentAction.None, '* ');
        testIndentAction(' *', ' * asdfsfagadfg * / * / * /*', '', IndentAction.None, '* ');

        testIndentAction('', ' */', '', IndentAction.None, null, 1);
        testIndentAction(' */', ' * test() {', '', IndentAction.Indent, null, 0);
        testIndentAction('', '\t */', '', IndentAction.None, null, 1);
        testIndentAction('', '\t\t */', '', IndentAction.None, null, 1);
        testIndentAction('', '   */', '', IndentAction.None, null, 1);
        testIndentAction('', '     */', '', IndentAction.None, null, 1);
        testIndentAction('', '\t     */', '', IndentAction.None, null, 1);
        testIndentAction('', ' *--------------------------------------------------------------------------------------------*/', '', IndentAction.None, null, 1);

        // issue #43469
        testIndentAction('class A {', '    * test() {', '', IndentAction.Indent, null, 0);
        testIndentAction('', '    * test() {', '', IndentAction.Indent, null, 0);
        testIndentAction('    ', '    * test() {', '', IndentAction.Indent, null, 0);
        testIndentAction('class A {', '  * test() {', '', IndentAction.Indent, null, 0);
        testIndentAction('', '  * test() {', '', IndentAction.Indent, null, 0);
        testIndentAction('  ', '  * test() {', '', IndentAction.Indent, null, 0);
    }

    function testIssue141816() {
        final support = new OnEnterSupport({
            onEnterRules: OnEnterRules.javascriptOnEnterRules
        });
        function testIndentAction(beforeText:String, afterText:String, expected:IndentAction, ?pos:PosInfos):Void {
            final actual = support.onEnter(EditorAutoIndentStrategy.Advanced, '', beforeText, afterText);
            if (expected == IndentAction.None) {
                assertEquals(actual, null, null, pos);
            }
            else {
                assertEquals(actual.indentAction, expected, null, pos);
            }
        }

        testIndentAction('const r = /{/;', '', IndentAction.None);
        testIndentAction('const r = /{[0-9]/;', '', IndentAction.None);
        testIndentAction('const r = /[a-zA-Z]{/;', '', IndentAction.None);
    }

    /**
     * Types the data files of the tests that need a text model (auto
     * indentation tests of later steps), so that they keep compiling.
     */
    static function _typeDataFiles():Array<Any> {
        return [
            BracketRules.latexBracketRules,
            BracketRules.typescriptBracketRules,
            IndentationRules.javascriptIndentationRules,
            AutoClosingPairsRules.javascriptAutoClosingPairsRules,
            AutoClosingPairsRules.latexAutoClosingPairsRules,
            OnEnterRules.htmlOnEnterRules,
        ];
    }

}
