// Ported from vscode src/vs/editor/contrib/linesOperations/test/browser/linesOperations.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.contrib.linesOperations;

import cityscape.common.EditorCommon.Handler;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Position;
import cityscape.common.core.Selection;
import cityscape.common.viewModel.ViewModelImpl;
import cityscape.contrib.linesOperations.view.LinesOperations;
import cityscape.view.CoreCommands;
import cityscape.view.EditorBrowser.ICodeEditor;
import cityscape.view.EditorExtensions.EditorAction;
import haxe.extern.EitherType;
import testing.TestCase;
import testing.TestCodeEditor;
import tests.TestTextModel;

/**
 * The helpers of linesOperations.test.ts.
 */
private class LinesOperationsTestHelper {

    public static function assertSelection(test:TestCase, editor:ICodeEditor, expected:EitherType<Selection, Array<Selection>>, ?pos:haxe.PosInfos):Void {
        final expectedArray:Array<Selection> = Std.isOfType(expected, Array) ? cast expected : [cast expected];
        @:privateAccess test.assertDeepEquals(expectedArray, editor.getSelections(), null, pos);
    }

    public static function executeAction(action:EditorAction, editor:ICodeEditor):Void {
        action.run(null, editor, null);
    }

}

/**
 * suite('Editor Contrib - Line Operations')
 */
class LinesOperationsTest extends TestCase {

    inline function assertSelection(editor:ICodeEditor, expected:EitherType<Selection, Array<Selection>>, ?pos:haxe.PosInfos):Void {
        LinesOperationsTestHelper.assertSelection(this, editor, expected, pos);
    }

    inline function executeAction(action:EditorAction, editor:ICodeEditor):Void {
        LinesOperationsTestHelper.executeAction(action, editor);
    }

    function doTestDeleteLinesCommand(initialText:Array<String>, _initialSelections:EitherType<Selection, Array<Selection>>, resultingText:Array<String>, _resultingSelections:EitherType<Selection, Array<Selection>>, ?pos:haxe.PosInfos):Void {
        final initialSelections:Array<Selection> = Std.isOfType(_initialSelections, Array) ? cast _initialSelections : [cast _initialSelections];
        final resultingSelections:Array<Selection> = Std.isOfType(_resultingSelections, Array) ? cast _resultingSelections : [cast _resultingSelections];
        TestCodeEditor.withTestCodeEditor(initialText, {}, (editor, _) -> {
            editor.setSelections(cast initialSelections);
            final deleteLinesAction = new DeleteLinesAction();
            executeAction(deleteLinesAction, editor);

            assertEquals(resultingText.join('\n'), editor.getValue(), null, pos);
            assertDeepEquals(resultingSelections, editor.getSelections(), null, pos);
        });
    }

    /**
     * test('transpose')
     */
    function testTranspose() {
        TestCodeEditor.withTestCodeEditor(
            [
                'hello world',
                '',
                '',
                '   ',
            ], {}, (editor, viewModel) -> {
                final model = editor.getModel();
                final transposeAction = new TransposeAction();

                editor.setSelection(new Selection(1, 1, 1, 1));
                executeAction(transposeAction, editor);
                assertEquals(model.getLineContent(1), 'hello world');
                assertSelection(editor, new Selection(1, 2, 1, 2));

                editor.setSelection(new Selection(1, 6, 1, 6));
                executeAction(transposeAction, editor);
                assertEquals(model.getLineContent(1), 'hell oworld');
                assertSelection(editor, new Selection(1, 7, 1, 7));

                editor.setSelection(new Selection(1, 12, 1, 12));
                executeAction(transposeAction, editor);
                assertEquals(model.getLineContent(1), 'hell oworl');
                assertSelection(editor, new Selection(2, 2, 2, 2));

                editor.setSelection(new Selection(3, 1, 3, 1));
                executeAction(transposeAction, editor);
                assertEquals(model.getLineContent(3), '');
                assertSelection(editor, new Selection(4, 1, 4, 1));

                editor.setSelection(new Selection(4, 2, 4, 2));
                executeAction(transposeAction, editor);
                assertEquals(model.getLineContent(4), '   ');
                assertSelection(editor, new Selection(4, 3, 4, 3));
            }
        );

        // fix #16633
        TestCodeEditor.withTestCodeEditor(
            [
                '',
                '',
                'hello',
                'world',
                '',
                'hello world',
                '',
                'hello world'
            ], {}, (editor, viewModel) -> {
                final model = editor.getModel();
                final transposeAction = new TransposeAction();

                editor.setSelection(new Selection(1, 1, 1, 1));
                executeAction(transposeAction, editor);
                assertEquals(model.getLineContent(2), '');
                assertSelection(editor, new Selection(2, 1, 2, 1));

                editor.setSelection(new Selection(3, 6, 3, 6));
                executeAction(transposeAction, editor);
                assertEquals(model.getLineContent(4), 'oworld');
                assertSelection(editor, new Selection(4, 2, 4, 2));

                editor.setSelection(new Selection(6, 12, 6, 12));
                executeAction(transposeAction, editor);
                assertEquals(model.getLineContent(7), 'd');
                assertSelection(editor, new Selection(7, 2, 7, 2));

                editor.setSelection(new Selection(8, 12, 8, 12));
                executeAction(transposeAction, editor);
                assertEquals(model.getLineContent(8), 'hello world');
                assertSelection(editor, new Selection(8, 12, 8, 12));
            }
        );
    }

    /**
     * test('toggle case')
     */
    function testToggleCase() {
        TestCodeEditor.withTestCodeEditor(
            [
                'hello world',
                'öçşğü',
                'parseHTMLString',
                'getElementById',
                'insertHTML',
                'PascalCase',
                'CSSSelectorsList',
                'iD',
                'tEST',
                'öçşÖÇŞğüĞÜ',
                'audioConverter.convertM4AToMP3();',
                'snake_case',
                'Capital_Snake_Case',
                // `function helloWorld() {...}`.replace(/^\s+/gm, '')
                'function helloWorld() {\n'
                + 'return someGlobalObject.printHelloWorld("en", "utf-8");\n'
                + '}\n'
                + 'helloWorld();',
                "'JavaScript'",
                'parseHTML4String',
                '_accessor: ServicesAccessor'
            ], {}, (editor, viewModel) -> {
                final model = editor.getModel();
                final uppercaseAction = new UpperCaseAction();
                final lowercaseAction = new LowerCaseAction();
                final titlecaseAction = new TitleCaseAction();
                final snakecaseAction = new SnakeCaseAction();

                editor.setSelection(new Selection(1, 1, 1, 12));
                executeAction(uppercaseAction, editor);
                assertEquals(model.getLineContent(1), 'HELLO WORLD');
                assertSelection(editor, new Selection(1, 1, 1, 12));

                editor.setSelection(new Selection(1, 1, 1, 12));
                executeAction(lowercaseAction, editor);
                assertEquals(model.getLineContent(1), 'hello world');
                assertSelection(editor, new Selection(1, 1, 1, 12));

                editor.setSelection(new Selection(1, 3, 1, 3));
                executeAction(uppercaseAction, editor);
                assertEquals(model.getLineContent(1), 'HELLO world');
                assertSelection(editor, new Selection(1, 3, 1, 3));

                editor.setSelection(new Selection(1, 4, 1, 4));
                executeAction(lowercaseAction, editor);
                assertEquals(model.getLineContent(1), 'hello world');
                assertSelection(editor, new Selection(1, 4, 1, 4));

                editor.setSelection(new Selection(1, 1, 1, 12));
                executeAction(titlecaseAction, editor);
                assertEquals(model.getLineContent(1), 'Hello World');
                assertSelection(editor, new Selection(1, 1, 1, 12));

                editor.setSelection(new Selection(2, 1, 2, 6));
                executeAction(uppercaseAction, editor);
                assertEquals(model.getLineContent(2), 'ÖÇŞĞÜ');
                assertSelection(editor, new Selection(2, 1, 2, 6));

                editor.setSelection(new Selection(2, 1, 2, 6));
                executeAction(lowercaseAction, editor);
                assertEquals(model.getLineContent(2), 'öçşğü');
                assertSelection(editor, new Selection(2, 1, 2, 6));

                editor.setSelection(new Selection(2, 1, 2, 6));
                executeAction(titlecaseAction, editor);
                assertEquals(model.getLineContent(2), 'Öçşğü');
                assertSelection(editor, new Selection(2, 1, 2, 6));

                editor.setSelection(new Selection(3, 1, 3, 16));
                executeAction(snakecaseAction, editor);
                assertEquals(model.getLineContent(3), 'parse_html_string');
                assertSelection(editor, new Selection(3, 1, 3, 18));

                editor.setSelection(new Selection(4, 1, 4, 15));
                executeAction(snakecaseAction, editor);
                assertEquals(model.getLineContent(4), 'get_element_by_id');
                assertSelection(editor, new Selection(4, 1, 4, 18));

                editor.setSelection(new Selection(5, 1, 5, 11));
                executeAction(snakecaseAction, editor);
                assertEquals(model.getLineContent(5), 'insert_html');
                assertSelection(editor, new Selection(5, 1, 5, 12));

                editor.setSelection(new Selection(6, 1, 6, 11));
                executeAction(snakecaseAction, editor);
                assertEquals(model.getLineContent(6), 'pascal_case');
                assertSelection(editor, new Selection(6, 1, 6, 12));

                editor.setSelection(new Selection(7, 1, 7, 17));
                executeAction(snakecaseAction, editor);
                assertEquals(model.getLineContent(7), 'css_selectors_list');
                assertSelection(editor, new Selection(7, 1, 7, 19));

                editor.setSelection(new Selection(8, 1, 8, 3));
                executeAction(snakecaseAction, editor);
                assertEquals(model.getLineContent(8), 'i_d');
                assertSelection(editor, new Selection(8, 1, 8, 4));

                editor.setSelection(new Selection(9, 1, 9, 5));
                executeAction(snakecaseAction, editor);
                assertEquals(model.getLineContent(9), 't_est');
                assertSelection(editor, new Selection(9, 1, 9, 6));

                editor.setSelection(new Selection(10, 1, 10, 11));
                executeAction(snakecaseAction, editor);
                assertEquals(model.getLineContent(10), 'öçş_öç_şğü_ğü');
                assertSelection(editor, new Selection(10, 1, 10, 14));

                editor.setSelection(new Selection(11, 1, 11, 34));
                executeAction(snakecaseAction, editor);
                assertEquals(model.getLineContent(11), 'audio_converter.convert_m4a_to_mp3();');
                assertSelection(editor, new Selection(11, 1, 11, 38));

                editor.setSelection(new Selection(12, 1, 12, 11));
                executeAction(snakecaseAction, editor);
                assertEquals(model.getLineContent(12), 'snake_case');
                assertSelection(editor, new Selection(12, 1, 12, 11));

                editor.setSelection(new Selection(13, 1, 13, 19));
                executeAction(snakecaseAction, editor);
                assertEquals(model.getLineContent(13), 'capital_snake_case');
                assertSelection(editor, new Selection(13, 1, 13, 19));

                editor.setSelection(new Selection(14, 1, 17, 14));
                executeAction(snakecaseAction, editor);
                // `function hello_world() {...}`.replace(/^\s+/gm, '')
                assertEquals(model.getValueInRange(new Selection(14, 1, 17, 15)), 'function hello_world() {\n'
                    + 'return some_global_object.print_hello_world("en", "utf-8");\n'
                    + '}\n'
                    + 'hello_world();');
                assertSelection(editor, new Selection(14, 1, 17, 15));

                editor.setSelection(new Selection(18, 1, 18, 13));
                executeAction(snakecaseAction, editor);
                assertEquals(model.getLineContent(18), "'java_script'");
                assertSelection(editor, new Selection(18, 1, 18, 14));

                editor.setSelection(new Selection(19, 1, 19, 17));
                executeAction(snakecaseAction, editor);
                assertEquals(model.getLineContent(19), 'parse_html4_string');
                assertSelection(editor, new Selection(19, 1, 19, 19));

                editor.setSelection(new Selection(20, 1, 20, 28));
                executeAction(snakecaseAction, editor);
                assertEquals(model.getLineContent(20), '_accessor: services_accessor');
                assertSelection(editor, new Selection(20, 1, 20, 29));
            }
        );

        TestCodeEditor.withTestCodeEditor(
            [
                'foO baR BaZ',
                'foO\'baR\'BaZ',
                'foO[baR]BaZ',
                'foO`baR~BaZ',
                'foO^baR%BaZ',
                "foO$baR!BaZ",
                '\'physician\'s assistant\''
            ], {}, (editor, viewModel) -> {
                final model = editor.getModel();
                final titlecaseAction = new TitleCaseAction();

                editor.setSelection(new Selection(1, 1, 1, 12));
                executeAction(titlecaseAction, editor);
                assertEquals(model.getLineContent(1), 'Foo Bar Baz');

                editor.setSelection(new Selection(2, 1, 2, 12));
                executeAction(titlecaseAction, editor);
                assertEquals(model.getLineContent(2), 'Foo\'bar\'baz');

                editor.setSelection(new Selection(3, 1, 3, 12));
                executeAction(titlecaseAction, editor);
                assertEquals(model.getLineContent(3), 'Foo[Bar]Baz');

                editor.setSelection(new Selection(4, 1, 4, 12));
                executeAction(titlecaseAction, editor);
                assertEquals(model.getLineContent(4), 'Foo`Bar~Baz');

                editor.setSelection(new Selection(5, 1, 5, 12));
                executeAction(titlecaseAction, editor);
                assertEquals(model.getLineContent(5), 'Foo^Bar%Baz');

                editor.setSelection(new Selection(6, 1, 6, 12));
                executeAction(titlecaseAction, editor);
                assertEquals(model.getLineContent(6), "Foo$Bar!Baz");

                editor.setSelection(new Selection(7, 1, 7, 23));
                executeAction(titlecaseAction, editor);
                assertEquals(model.getLineContent(7), '\'Physician\'s Assistant\'');
            }
        );

        TestCodeEditor.withTestCodeEditor(
            [
                'camel from words',
                'from_snake_case',
                'from-kebab-case',
                'alreadyCamel',
                'ReTain_any_CAPitalization',
                'my_var.test_function()',
                'öçş_öç_şğü_ğü'
            ], {}, (editor, viewModel) -> {
                final model = editor.getModel();
                final camelcaseAction = new CamelCaseAction();

                editor.setSelection(new Selection(1, 1, 1, 18));
                executeAction(camelcaseAction, editor);
                assertEquals(model.getLineContent(1), 'camelFromWords');

                editor.setSelection(new Selection(2, 1, 2, 15));
                executeAction(camelcaseAction, editor);
                assertEquals(model.getLineContent(2), 'fromSnakeCase');

                editor.setSelection(new Selection(3, 1, 3, 15));
                executeAction(camelcaseAction, editor);
                assertEquals(model.getLineContent(3), 'fromKebabCase');

                editor.setSelection(new Selection(4, 1, 4, 12));
                executeAction(camelcaseAction, editor);
                assertEquals(model.getLineContent(4), 'alreadyCamel');

                editor.setSelection(new Selection(5, 1, 5, 26));
                executeAction(camelcaseAction, editor);
                assertEquals(model.getLineContent(5), 'ReTainAnyCAPitalization');

                editor.setSelection(new Selection(6, 1, 6, 23));
                executeAction(camelcaseAction, editor);
                assertEquals(model.getLineContent(6), 'myVar.testFunction()');

                editor.setSelection(new Selection(7, 1, 7, 14));
                executeAction(camelcaseAction, editor);
                assertEquals(model.getLineContent(7), 'öçşÖçŞğüĞü');
            }
        );

        TestCodeEditor.withTestCodeEditor(
            [
                '',
                '   '
            ], {}, (editor, viewModel) -> {
                final model = editor.getModel();
                final uppercaseAction = new UpperCaseAction();
                final lowercaseAction = new LowerCaseAction();

                editor.setSelection(new Selection(1, 1, 1, 1));
                executeAction(uppercaseAction, editor);
                assertEquals(model.getLineContent(1), '');
                assertSelection(editor, new Selection(1, 1, 1, 1));

                editor.setSelection(new Selection(1, 1, 1, 1));
                executeAction(lowercaseAction, editor);
                assertEquals(model.getLineContent(1), '');
                assertSelection(editor, new Selection(1, 1, 1, 1));

                editor.setSelection(new Selection(2, 2, 2, 2));
                executeAction(uppercaseAction, editor);
                assertEquals(model.getLineContent(2), '   ');
                assertSelection(editor, new Selection(2, 2, 2, 2));

                editor.setSelection(new Selection(2, 2, 2, 2));
                executeAction(lowercaseAction, editor);
                assertEquals(model.getLineContent(2), '   ');
                assertSelection(editor, new Selection(2, 2, 2, 2));
            }
        );

        TestCodeEditor.withTestCodeEditor(
            [
                'hello world',
                'öçşğü',
                'parseHTMLString',
                'getElementById',
                'PascalCase',
                'öçşÖÇŞğüĞÜ',
                'audioConverter.convertM4AToMP3();',
                'Capital_Snake_Case',
                'parseHTML4String',
                '_accessor: ServicesAccessor',
                'Kebab-Case',
            ], {}, (editor, viewModel) -> {
                final model = editor.getModel();
                final kebabCaseAction = new KebabCaseAction();

                editor.setSelection(new Selection(1, 1, 1, 12));
                executeAction(kebabCaseAction, editor);
                assertEquals(model.getLineContent(1), 'hello world');
                assertSelection(editor, new Selection(1, 1, 1, 12));

                editor.setSelection(new Selection(2, 1, 2, 6));
                executeAction(kebabCaseAction, editor);
                assertEquals(model.getLineContent(2), 'öçşğü');
                assertSelection(editor, new Selection(2, 1, 2, 6));

                editor.setSelection(new Selection(3, 1, 3, 16));
                executeAction(kebabCaseAction, editor);
                assertEquals(model.getLineContent(3), 'parse-html-string');
                assertSelection(editor, new Selection(3, 1, 3, 18));

                editor.setSelection(new Selection(4, 1, 4, 15));
                executeAction(kebabCaseAction, editor);
                assertEquals(model.getLineContent(4), 'get-element-by-id');
                assertSelection(editor, new Selection(4, 1, 4, 18));

                editor.setSelection(new Selection(5, 1, 5, 11));
                executeAction(kebabCaseAction, editor);
                assertEquals(model.getLineContent(5), 'pascal-case');
                assertSelection(editor, new Selection(5, 1, 5, 12));

                editor.setSelection(new Selection(6, 1, 6, 11));
                executeAction(kebabCaseAction, editor);
                assertEquals(model.getLineContent(6), 'öçş-öç-şğü-ğü');
                assertSelection(editor, new Selection(6, 1, 6, 14));

                editor.setSelection(new Selection(7, 1, 7, 34));
                executeAction(kebabCaseAction, editor);
                assertEquals(model.getLineContent(7), 'audio-converter.convert-m4a-to-mp3();');
                assertSelection(editor, new Selection(7, 1, 7, 38));

                editor.setSelection(new Selection(8, 1, 8, 19));
                executeAction(kebabCaseAction, editor);
                assertEquals(model.getLineContent(8), 'capital-snake-case');
                assertSelection(editor, new Selection(8, 1, 8, 19));

                editor.setSelection(new Selection(9, 1, 9, 17));
                executeAction(kebabCaseAction, editor);
                assertEquals(model.getLineContent(9), 'parse-html4-string');
                assertSelection(editor, new Selection(9, 1, 9, 19));

                editor.setSelection(new Selection(10, 1, 10, 28));
                executeAction(kebabCaseAction, editor);
                assertEquals(model.getLineContent(10), '_accessor: services-accessor');
                assertSelection(editor, new Selection(10, 1, 10, 29));

                editor.setSelection(new Selection(11, 1, 11, 11));
                executeAction(kebabCaseAction, editor);
                assertEquals(model.getLineContent(11), 'kebab-case');
                assertSelection(editor, new Selection(11, 1, 11, 11));
            }
        );

        TestCodeEditor.withTestCodeEditor(
            [
                'hello world',
                'öçşğü',
                'parseHTMLString',
                'getElementById',
                'PascalCase',
                'öçşÖÇŞğüĞÜ',
                'audioConverter.convertM4AToMP3();',
                'Capital_Snake_Case',
                'parseHTML4String',
                'Kebab-Case',
            ], {}, (editor, viewModel) -> {
                final model = editor.getModel();
                final pascalCaseAction = new PascalCaseAction();

                editor.setSelection(new Selection(1, 1, 1, 12));
                executeAction(pascalCaseAction, editor);
                assertEquals(model.getLineContent(1), 'HelloWorld');
                assertSelection(editor, new Selection(1, 1, 1, 11));

                editor.setSelection(new Selection(2, 1, 2, 6));
                executeAction(pascalCaseAction, editor);
                assertEquals(model.getLineContent(2), 'Öçşğü');
                assertSelection(editor, new Selection(2, 1, 2, 6));

                editor.setSelection(new Selection(3, 1, 3, 16));
                executeAction(pascalCaseAction, editor);
                assertEquals(model.getLineContent(3), 'ParseHTMLString');
                assertSelection(editor, new Selection(3, 1, 3, 16));

                editor.setSelection(new Selection(4, 1, 4, 15));
                executeAction(pascalCaseAction, editor);
                assertEquals(model.getLineContent(4), 'GetElementById');
                assertSelection(editor, new Selection(4, 1, 4, 15));

                editor.setSelection(new Selection(5, 1, 5, 11));
                executeAction(pascalCaseAction, editor);
                assertEquals(model.getLineContent(5), 'PascalCase');
                assertSelection(editor, new Selection(5, 1, 5, 11));

                editor.setSelection(new Selection(6, 1, 6, 11));
                executeAction(pascalCaseAction, editor);
                assertEquals(model.getLineContent(6), 'ÖçşÖÇŞğüĞÜ');
                assertSelection(editor, new Selection(6, 1, 6, 11));

                editor.setSelection(new Selection(7, 1, 7, 34));
                executeAction(pascalCaseAction, editor);
                assertEquals(model.getLineContent(7), 'AudioConverter.ConvertM4AToMP3();');
                assertSelection(editor, new Selection(7, 1, 7, 34));

                editor.setSelection(new Selection(8, 1, 8, 19));
                executeAction(pascalCaseAction, editor);
                assertEquals(model.getLineContent(8), 'CapitalSnakeCase');
                assertSelection(editor, new Selection(8, 1, 8, 17));

                editor.setSelection(new Selection(9, 1, 9, 17));
                executeAction(pascalCaseAction, editor);
                assertEquals(model.getLineContent(9), 'ParseHTML4String');
                assertSelection(editor, new Selection(9, 1, 9, 17));

                editor.setSelection(new Selection(10, 1, 10, 11));
                executeAction(pascalCaseAction, editor);
                assertEquals(model.getLineContent(10), 'KebabCase');
                assertSelection(editor, new Selection(10, 1, 10, 10));
            }
        );
    }

    /**
     * test('InsertLineBeforeAction')
     */
    function testInsertLineBeforeAction() {
        function doTestInsertLineBefore(lineNumber:Int, column:Int, callback:(model:ITextModel, viewModel:ViewModel) -> Void):Void {
            final TEXT = [
                'First line',
                'Second line',
                'Third line'
            ];
            TestCodeEditor.withTestCodeEditor(TEXT, {}, (editor, viewModel) -> {
                editor.setPosition(new Position(lineNumber, column));
                final insertLineBeforeAction = new InsertLineBeforeAction();

                executeAction(insertLineBeforeAction, editor);
                callback(editor.getModel(), viewModel);
            });
        }

        doTestInsertLineBefore(1, 3, (model, viewModel) -> {
            assertDeepEquals(viewModel.getSelection(), new Selection(1, 1, 1, 1));
            assertEquals(model.getLineContent(1), '');
            assertEquals(model.getLineContent(2), 'First line');
            assertEquals(model.getLineContent(3), 'Second line');
            assertEquals(model.getLineContent(4), 'Third line');
        });

        doTestInsertLineBefore(2, 3, (model, viewModel) -> {
            assertDeepEquals(viewModel.getSelection(), new Selection(2, 1, 2, 1));
            assertEquals(model.getLineContent(1), 'First line');
            assertEquals(model.getLineContent(2), '');
            assertEquals(model.getLineContent(3), 'Second line');
            assertEquals(model.getLineContent(4), 'Third line');
        });

        doTestInsertLineBefore(3, 3, (model, viewModel) -> {
            assertDeepEquals(viewModel.getSelection(), new Selection(3, 1, 3, 1));
            assertEquals(model.getLineContent(1), 'First line');
            assertEquals(model.getLineContent(2), 'Second line');
            assertEquals(model.getLineContent(3), '');
            assertEquals(model.getLineContent(4), 'Third line');
        });
    }

    /**
     * test('InsertLineAfterAction')
     */
    function testInsertLineAfterAction() {
        function doTestInsertLineAfter(lineNumber:Int, column:Int, callback:(model:ITextModel, viewModel:ViewModel) -> Void):Void {
            final TEXT = [
                'First line',
                'Second line',
                'Third line'
            ];
            TestCodeEditor.withTestCodeEditor(TEXT, {}, (editor, viewModel) -> {
                editor.setPosition(new Position(lineNumber, column));
                final insertLineAfterAction = new InsertLineAfterAction();

                executeAction(insertLineAfterAction, editor);
                callback(editor.getModel(), viewModel);
            });
        }

        doTestInsertLineAfter(1, 3, (model, viewModel) -> {
            assertDeepEquals(viewModel.getSelection(), new Selection(2, 1, 2, 1));
            assertEquals(model.getLineContent(1), 'First line');
            assertEquals(model.getLineContent(2), '');
            assertEquals(model.getLineContent(3), 'Second line');
            assertEquals(model.getLineContent(4), 'Third line');
        });

        doTestInsertLineAfter(2, 3, (model, viewModel) -> {
            assertDeepEquals(viewModel.getSelection(), new Selection(3, 1, 3, 1));
            assertEquals(model.getLineContent(1), 'First line');
            assertEquals(model.getLineContent(2), 'Second line');
            assertEquals(model.getLineContent(3), '');
            assertEquals(model.getLineContent(4), 'Third line');
        });

        doTestInsertLineAfter(3, 3, (model, viewModel) -> {
            assertDeepEquals(viewModel.getSelection(), new Selection(4, 1, 4, 1));
            assertEquals(model.getLineContent(1), 'First line');
            assertEquals(model.getLineContent(2), 'Second line');
            assertEquals(model.getLineContent(3), 'Third line');
            assertEquals(model.getLineContent(4), '');
        });
    }

    /**
     * test('Bug 18276:[editor] Indentation broken when selection is empty')
     */
    function testBug18276EditorIndentationBrokenWhenSelectionIsEmpty() {

        final model = TestTextModel.createTextModel(
            [
                'function baz() {'
            ].join('\n'),
            null,
            {
                insertSpaces: false,
            }
        );

        TestCodeEditor.withTestCodeEditor(model, {}, (editor, viewModel) -> {
            final indentLinesAction = new IndentLinesAction();
            editor.setPosition(new Position(1, 2));

            executeAction(indentLinesAction, editor);
            assertEquals(model.getLineContent(1), '\tfunction baz() {');
            assertDeepEquals(editor.getSelection(), new Selection(1, 3, 1, 3));

            CoreEditingCommands.Tab.runEditorCommand(null, editor, null);
            assertEquals(model.getLineContent(1), '\tf\tunction baz() {');
        });

        model.dispose();
    }

    /**
     * test('issue #80736: Indenting while the cursor is at the start of a line of text causes the added spaces or tab to be selected')
     */
    function testIssue80736IndentingWhileTheCursorIsAtTheStartOfALineOfTextCausesTheAddedSpacesOrTabToBeSelected() {
        final model = TestTextModel.createTextModel(
            [
                'Some text'
            ].join('\n'),
            null,
            {
                insertSpaces: false,
            }
        );

        TestCodeEditor.withTestCodeEditor(model, {}, (editor, viewModel) -> {
            final indentLinesAction = new IndentLinesAction();
            editor.setPosition(new Position(1, 1));

            executeAction(indentLinesAction, editor);
            assertEquals(model.getLineContent(1), '\tSome text');
            assertDeepEquals(editor.getSelection(), new Selection(1, 2, 1, 2));
        });

        model.dispose();
    }

    /**
     * test('Indenting on empty line should move cursor')
     */
    function testIndentingOnEmptyLineShouldMoveCursor() {
        final model = TestTextModel.createTextModel(
            [
                ''
            ].join('\n')
        );

        TestCodeEditor.withTestCodeEditor(model, { useTabStops: false }, (editor, viewModel) -> {
            final indentLinesAction = new IndentLinesAction();
            editor.setPosition(new Position(1, 1));

            executeAction(indentLinesAction, editor);
            assertEquals(model.getLineContent(1), '    ');
            assertDeepEquals(editor.getSelection(), new Selection(1, 5, 1, 5));
        });

        model.dispose();
    }

    /**
     * test('issue #62112: Delete line does not work properly when multiple cursors are on line')
     */
    function testIssue62112DeleteLineDoesNotWorkProperlyWhenMultipleCursorsAreOnLine() {
        final TEXT = [
            'a',
            'foo boo',
            'too',
            'c',
        ];
        TestCodeEditor.withTestCodeEditor(TEXT, {}, (editor, viewModel) -> {
            editor.setSelections([
                new Selection(2, 4, 2, 4),
                new Selection(2, 8, 2, 8),
                new Selection(3, 4, 3, 4),
            ]);
            final deleteLinesAction = new DeleteLinesAction();
            executeAction(deleteLinesAction, editor);

            assertEquals(editor.getValue(), 'a\nc');
        });
    }

    /**
     * test('empty selection in middle of lines')
     */
    function testEmptySelectionInMiddleOfLines() {
        doTestDeleteLinesCommand(
            [
                'first',
                'second line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(2, 3, 2, 3),
            [
                'first',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(2, 3, 2, 3)
        );
    }

    /**
     * test('empty selection at top of lines')
     */
    function testEmptySelectionAtTopOfLines() {
        doTestDeleteLinesCommand(
            [
                'first',
                'second line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(1, 5, 1, 5),
            [
                'second line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(1, 5, 1, 5)
        );
    }

    /**
     * test('empty selection at end of lines')
     */
    function testEmptySelectionAtEndOfLines() {
        doTestDeleteLinesCommand(
            [
                'first',
                'second line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(5, 2, 5, 2),
            [
                'first',
                'second line',
                'third line',
                'fourth line'
            ],
            new Selection(4, 2, 4, 2)
        );
    }

    /**
     * test('with selection in middle of lines')
     */
    function testWithSelectionInMiddleOfLines() {
        doTestDeleteLinesCommand(
            [
                'first',
                'second line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(3, 3, 2, 2),
            [
                'first',
                'fourth line',
                'fifth'
            ],
            new Selection(2, 2, 2, 2)
        );
    }

    /**
     * test('with selection at top of lines')
     */
    function testWithSelectionAtTopOfLines() {
        doTestDeleteLinesCommand(
            [
                'first',
                'second line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(1, 4, 1, 5),
            [
                'second line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(1, 5, 1, 5)
        );
    }

    /**
     * test('with selection at end of lines')
     */
    function testWithSelectionAtEndOfLines() {
        doTestDeleteLinesCommand(
            [
                'first',
                'second line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(5, 1, 5, 2),
            [
                'first',
                'second line',
                'third line',
                'fourth line'
            ],
            new Selection(4, 2, 4, 2)
        );
    }

    /**
     * test('with full line selection in middle of lines')
     */
    function testWithFullLineSelectionInMiddleOfLines() {
        doTestDeleteLinesCommand(
            [
                'first',
                'second line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(4, 1, 2, 1),
            [
                'first',
                'fourth line',
                'fifth'
            ],
            new Selection(2, 1, 2, 1)
        );
    }

    /**
     * test('with full line selection at top of lines')
     */
    function testWithFullLineSelectionAtTopOfLines() {
        doTestDeleteLinesCommand(
            [
                'first',
                'second line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(2, 1, 1, 5),
            [
                'second line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(1, 5, 1, 5)
        );
    }

    /**
     * test('with full line selection at end of lines')
     */
    function testWithFullLineSelectionAtEndOfLines() {
        doTestDeleteLinesCommand(
            [
                'first',
                'second line',
                'third line',
                'fourth line',
                'fifth'
            ],
            new Selection(4, 1, 5, 2),
            [
                'first',
                'second line',
                'third line'
            ],
            new Selection(3, 2, 3, 2)
        );
    }

    /**
     * test('multicursor 1')
     */
    function testMulticursor1() {
        doTestDeleteLinesCommand(
            [
                'class P {',
                '',
                '    getA() {',
                '        if (true) {',
                '            return "a";',
                '        }',
                '    }',
                '',
                '    getB() {',
                '        if (true) {',
                '            return "b";',
                '        }',
                '    }',
                '',
                '    getC() {',
                '        if (true) {',
                '            return "c";',
                '        }',
                '    }',
                '}',
            ],
            [
                new Selection(4, 1, 5, 1),
                new Selection(10, 1, 11, 1),
                new Selection(16, 1, 17, 1),
            ],
            [
                'class P {',
                '',
                '    getA() {',
                '            return "a";',
                '        }',
                '    }',
                '',
                '    getB() {',
                '            return "b";',
                '        }',
                '    }',
                '',
                '    getC() {',
                '            return "c";',
                '        }',
                '    }',
                '}',
            ],
            [
                new Selection(4, 1, 4, 1),
                new Selection(9, 1, 9, 1),
                new Selection(14, 1, 14, 1),
            ]
        );
    }
}

/**
 * suite('Editor Contrib - Line Operations / SortLinesAscendingAction')
 */
class SortLinesAscendingActionTest extends TestCase {

    inline function assertSelection(editor:ICodeEditor, expected:EitherType<Selection, Array<Selection>>, ?pos:haxe.PosInfos):Void {
        LinesOperationsTestHelper.assertSelection(this, editor, expected, pos);
    }

    inline function executeAction(action:EditorAction, editor:ICodeEditor):Void {
        LinesOperationsTestHelper.executeAction(action, editor);
    }

    /**
     * test('should sort selected lines in ascending order')
     */
    function testShouldSortSelectedLinesInAscendingOrder() {
        TestCodeEditor.withTestCodeEditor(
            [
                'omicron',
                'beta',
                'alpha'
            ], {}, (editor, viewModel) -> {
                final model = editor.getModel();
                final sortLinesAscendingAction = new SortLinesAscendingAction();

                editor.setSelection(new Selection(1, 1, 3, 5));
                executeAction(sortLinesAscendingAction, editor);
                assertDeepEquals(model.getLinesContent(), [
                    'alpha',
                    'beta',
                    'omicron'
                ]);
                assertSelection(editor, new Selection(1, 1, 3, 7));
            });
    }

    /**
     * test('should sort lines in ascending order')
     */
    function testShouldSortLinesInAscendingOrder() {
        TestCodeEditor.withTestCodeEditor(
            [
                'omicron',
                'beta',
                'alpha'
            ], {}, (editor, viewModel) -> {
                final model = editor.getModel();
                final sortLinesAscendingAction = new SortLinesAscendingAction();

                executeAction(sortLinesAscendingAction, editor);
                assertDeepEquals(model.getLinesContent(), [
                    'alpha',
                    'beta',
                    'omicron'
                ]);
            });
    }

    /**
     * test('should sort multiple selections in ascending order')
     */
    function testShouldSortMultipleSelectionsInAscendingOrder() {
        TestCodeEditor.withTestCodeEditor(
            [
                'omicron',
                'beta',
                'alpha',
                '',
                'omicron',
                'beta',
                'alpha'
            ], {}, (editor, viewModel) -> {
                final model = editor.getModel();
                final sortLinesAscendingAction = new SortLinesAscendingAction();

                editor.setSelections([new Selection(1, 1, 3, 5), new Selection(5, 1, 7, 5)]);
                executeAction(sortLinesAscendingAction, editor);
                assertDeepEquals(model.getLinesContent(), [
                    'alpha',
                    'beta',
                    'omicron',
                    '',
                    'alpha',
                    'beta',
                    'omicron'
                ]);
                final expectedSelections = [
                    new Selection(1, 1, 3, 7),
                    new Selection(5, 1, 7, 7)
                ];
                final actualSelections = editor.getSelections();
                for (index in 0...actualSelections.length) {
                    final actualSelection = actualSelections[index];
                    assertDeepEquals(expectedSelections[index].toString(), actualSelection.toString());
                }
            });
    }
}

/**
 * suite('Editor Contrib - Line Operations / SortLinesDescendingAction')
 */
class SortLinesDescendingActionTest extends TestCase {

    inline function assertSelection(editor:ICodeEditor, expected:EitherType<Selection, Array<Selection>>, ?pos:haxe.PosInfos):Void {
        LinesOperationsTestHelper.assertSelection(this, editor, expected, pos);
    }

    inline function executeAction(action:EditorAction, editor:ICodeEditor):Void {
        LinesOperationsTestHelper.executeAction(action, editor);
    }

    /**
     * test('should sort selected lines in descending order')
     */
    function testShouldSortSelectedLinesInDescendingOrder() {
        TestCodeEditor.withTestCodeEditor(
            [
                'alpha',
                'beta',
                'omicron'
            ], {}, (editor, viewModel) -> {
                final model = editor.getModel();
                final sortLinesDescendingAction = new SortLinesDescendingAction();

                editor.setSelection(new Selection(1, 1, 3, 7));
                executeAction(sortLinesDescendingAction, editor);
                assertDeepEquals(model.getLinesContent(), [
                    'omicron',
                    'beta',
                    'alpha'
                ]);
                assertSelection(editor, new Selection(1, 1, 3, 5));
            });
    }

    /**
     * test('should sort multiple selections in descending order')
     */
    function testShouldSortMultipleSelectionsInDescendingOrder() {
        TestCodeEditor.withTestCodeEditor(
            [
                'alpha',
                'beta',
                'omicron',
                '',
                'alpha',
                'beta',
                'omicron'
            ], {}, (editor, viewModel) -> {
                final model = editor.getModel();
                final sortLinesDescendingAction = new SortLinesDescendingAction();

                editor.setSelections([new Selection(1, 1, 3, 7), new Selection(5, 1, 7, 7)]);
                executeAction(sortLinesDescendingAction, editor);
                assertDeepEquals(model.getLinesContent(), [
                    'omicron',
                    'beta',
                    'alpha',
                    '',
                    'omicron',
                    'beta',
                    'alpha'
                ]);
                final expectedSelections = [
                    new Selection(1, 1, 3, 5),
                    new Selection(5, 1, 7, 5)
                ];
                final actualSelections = editor.getSelections();
                for (index in 0...actualSelections.length) {
                    final actualSelection = actualSelections[index];
                    assertDeepEquals(expectedSelections[index].toString(), actualSelection.toString());
                }
            });
    }
}

/**
 * suite('Editor Contrib - Line Operations / DeleteDuplicateLinesAction')
 */
class DeleteDuplicateLinesActionTest extends TestCase {

    inline function assertSelection(editor:ICodeEditor, expected:EitherType<Selection, Array<Selection>>, ?pos:haxe.PosInfos):Void {
        LinesOperationsTestHelper.assertSelection(this, editor, expected, pos);
    }

    inline function executeAction(action:EditorAction, editor:ICodeEditor):Void {
        LinesOperationsTestHelper.executeAction(action, editor);
    }

    /**
     * test('should remove duplicate lines within selection')
     */
    function testShouldRemoveDuplicateLinesWithinSelection() {
        TestCodeEditor.withTestCodeEditor(
            [
                'alpha',
                'beta',
                'beta',
                'beta',
                'alpha',
                'omicron',
            ], {}, (editor, viewModel) -> {
                final model = editor.getModel();
                final deleteDuplicateLinesAction = new DeleteDuplicateLinesAction();

                editor.setSelection(new Selection(1, 3, 6, 4));
                executeAction(deleteDuplicateLinesAction, editor);
                assertDeepEquals(model.getLinesContent(), [
                    'alpha',
                    'beta',
                    'omicron',
                ]);
                assertSelection(editor, new Selection(1, 1, 3, 7));
            });
    }

    /**
     * test('should remove duplicate lines')
     */
    function testShouldRemoveDuplicateLines() {
        TestCodeEditor.withTestCodeEditor(
            [
                'alpha',
                'beta',
                'beta',
                'beta',
                'alpha',
                'omicron',
            ], {}, (editor, viewModel) -> {
                final model = editor.getModel();
                final deleteDuplicateLinesAction = new DeleteDuplicateLinesAction();

                executeAction(deleteDuplicateLinesAction, editor);
                assertDeepEquals(model.getLinesContent(), [
                    'alpha',
                    'beta',
                    'omicron',
                ]);
                assertTrue(editor.getSelection().isEmpty());
            });
    }

    /**
     * test('should remove duplicate lines in multiple selections')
     */
    function testShouldRemoveDuplicateLinesInMultipleSelections() {
        TestCodeEditor.withTestCodeEditor(
            [
                'alpha',
                'beta',
                'beta',
                'omicron',
                '',
                'alpha',
                'alpha',
                'beta'
            ], {}, (editor, viewModel) -> {
                final model = editor.getModel();
                final deleteDuplicateLinesAction = new DeleteDuplicateLinesAction();

                editor.setSelections([new Selection(1, 2, 4, 3), new Selection(6, 2, 8, 3)]);
                executeAction(deleteDuplicateLinesAction, editor);
                assertDeepEquals(model.getLinesContent(), [
                    'alpha',
                    'beta',
                    'omicron',
                    '',
                    'alpha',
                    'beta'
                ]);
                final expectedSelections = [
                    new Selection(1, 1, 3, 7),
                    new Selection(5, 1, 6, 4)
                ];
                final actualSelections = editor.getSelections();
                for (index in 0...actualSelections.length) {
                    final actualSelection = actualSelections[index];
                    assertDeepEquals(expectedSelections[index].toString(), actualSelection.toString());
                }
            });
    }
}

/**
 * suite('Editor Contrib - Line Operations / DeleteAllLeftAction')
 */
class DeleteAllLeftActionTest extends TestCase {

    inline function assertSelection(editor:ICodeEditor, expected:EitherType<Selection, Array<Selection>>, ?pos:haxe.PosInfos):Void {
        LinesOperationsTestHelper.assertSelection(this, editor, expected, pos);
    }

    inline function executeAction(action:EditorAction, editor:ICodeEditor):Void {
        LinesOperationsTestHelper.executeAction(action, editor);
    }

    /**
     * test('should delete to the left of the cursor')
     */
    function testShouldDeleteToTheLeftOfTheCursor() {
        TestCodeEditor.withTestCodeEditor(
            [
                'one',
                'two',
                'three'
            ], {}, (editor, viewModel) -> {
                final model = editor.getModel();
                final deleteAllLeftAction = new DeleteAllLeftAction();

                editor.setSelection(new Selection(1, 2, 1, 2));
                executeAction(deleteAllLeftAction, editor);
                assertEquals(model.getLineContent(1), 'ne');

                editor.setSelections([new Selection(2, 2, 2, 2), new Selection(3, 2, 3, 2)]);
                executeAction(deleteAllLeftAction, editor);
                assertEquals(model.getLineContent(2), 'wo');
                assertEquals(model.getLineContent(3), 'hree');
            });
    }

    /**
     * test('should jump to the previous line when on first column')
     */
    function testShouldJumpToThePreviousLineWhenOnFirstColumn() {
        TestCodeEditor.withTestCodeEditor(
            [
                'one',
                'two',
                'three'
            ], {}, (editor, viewModel) -> {
                final model = editor.getModel();
                final deleteAllLeftAction = new DeleteAllLeftAction();

                editor.setSelection(new Selection(2, 1, 2, 1));
                executeAction(deleteAllLeftAction, editor);
                assertEquals(model.getLineContent(1), 'onetwo');

                editor.setSelections([new Selection(1, 1, 1, 1), new Selection(2, 1, 2, 1)]);
                executeAction(deleteAllLeftAction, editor);
                assertEquals(model.getLinesContent()[0], 'onetwothree');
                assertEquals(model.getLinesContent().length, 1);

                editor.setSelection(new Selection(1, 1, 1, 1));
                executeAction(deleteAllLeftAction, editor);
                assertEquals(model.getLinesContent()[0], 'onetwothree');
            });
    }

    /**
     * test('should keep deleting lines in multi cursor mode')
     */
    function testShouldKeepDeletingLinesInMultiCursorMode() {
        TestCodeEditor.withTestCodeEditor(
            [
                'hi my name is Carlos Matos',
                'BCC',
                'waso waso waso',
                'my wife doesnt believe in me',
                'nonononono',
                'bitconneeeect'
            ], {}, (editor, viewModel) -> {
                final model = editor.getModel();
                final deleteAllLeftAction = new DeleteAllLeftAction();

                final beforeSecondWasoSelection = new Selection(3, 5, 3, 5);
                final endOfBCCSelection = new Selection(2, 4, 2, 4);
                final endOfNonono = new Selection(5, 11, 5, 11);

                editor.setSelections([beforeSecondWasoSelection, endOfBCCSelection, endOfNonono]);

                executeAction(deleteAllLeftAction, editor);
                var selections = editor.getSelections();

                assertEquals(model.getLineContent(2), '');
                assertEquals(model.getLineContent(3), ' waso waso');
                assertEquals(model.getLineContent(5), '');

                assertDeepEquals([
                    selections[0].startLineNumber,
                    selections[0].startColumn,
                    selections[0].endLineNumber,
                    selections[0].endColumn
                ], [3, 1, 3, 1]);

                assertDeepEquals([
                    selections[1].startLineNumber,
                    selections[1].startColumn,
                    selections[1].endLineNumber,
                    selections[1].endColumn
                ], [2, 1, 2, 1]);

                assertDeepEquals([
                    selections[2].startLineNumber,
                    selections[2].startColumn,
                    selections[2].endLineNumber,
                    selections[2].endColumn
                ], [5, 1, 5, 1]);

                executeAction(deleteAllLeftAction, editor);
                selections = editor.getSelections();

                assertEquals(model.getLineContent(1), 'hi my name is Carlos Matos waso waso');
                assertEquals(selections.length, 2);

                assertDeepEquals([
                    selections[0].startLineNumber,
                    selections[0].startColumn,
                    selections[0].endLineNumber,
                    selections[0].endColumn
                ], [1, 27, 1, 27]);

                assertDeepEquals([
                    selections[1].startLineNumber,
                    selections[1].startColumn,
                    selections[1].endLineNumber,
                    selections[1].endColumn
                ], [2, 29, 2, 29]);
            });
    }

    /**
     * test('should work in multi cursor mode')
     */
    function testShouldWorkInMultiCursorMode() {
        TestCodeEditor.withTestCodeEditor(
            [
                'hello',
                'world',
                'hello world',
                'hello',
                'bonjour',
                'hola',
                'world',
                'hello world',
            ], {}, (editor, viewModel) -> {
                final model = editor.getModel();
                final deleteAllLeftAction = new DeleteAllLeftAction();

                editor.setSelections([new Selection(1, 2, 1, 2), new Selection(1, 4, 1, 4)]);
                executeAction(deleteAllLeftAction, editor);
                assertEquals(model.getLineContent(1), 'lo');

                editor.setSelections([new Selection(2, 2, 2, 2), new Selection(2, 4, 2, 5)]);
                executeAction(deleteAllLeftAction, editor);
                assertEquals(model.getLineContent(2), 'd');

                editor.setSelections([new Selection(3, 2, 3, 5), new Selection(3, 7, 3, 7)]);
                executeAction(deleteAllLeftAction, editor);
                assertEquals(model.getLineContent(3), 'world');

                editor.setSelections([new Selection(4, 3, 4, 3), new Selection(4, 5, 5, 4)]);
                executeAction(deleteAllLeftAction, editor);
                assertEquals(model.getLineContent(4), 'jour');

                editor.setSelections([new Selection(5, 3, 6, 3), new Selection(6, 5, 7, 5), new Selection(7, 7, 7, 7)]);
                executeAction(deleteAllLeftAction, editor);
                assertEquals(model.getLineContent(5), 'world');
            });
    }

    /**
     * test('issue #36234: should push undo stop')
     */
    function testIssue36234ShouldPushUndoStop() {
        TestCodeEditor.withTestCodeEditor(
            [
                'one',
                'two',
                'three'
            ], {}, (editor, viewModel) -> {
                final model = editor.getModel();
                final deleteAllLeftAction = new DeleteAllLeftAction();

                editor.setSelection(new Selection(1, 1, 1, 1));

                editor.trigger('keyboard', Handler.Type, { text: 'Typing some text here on line ' });
                assertEquals(model.getLineContent(1), 'Typing some text here on line one');
                assertDeepEquals(editor.getSelection(), new Selection(1, 31, 1, 31));

                executeAction(deleteAllLeftAction, editor);
                assertEquals(model.getLineContent(1), 'one');
                assertDeepEquals(editor.getSelection(), new Selection(1, 1, 1, 1));

                CoreEditingCommands.Undo.runEditorCommand(null, editor, null);
                assertEquals(model.getLineContent(1), 'Typing some text here on line one');
                assertDeepEquals(editor.getSelection(), new Selection(1, 31, 1, 31));
            });
    }
}

/**
 * suite('Editor Contrib - Line Operations / JoinLinesAction')
 */
class JoinLinesActionTest extends TestCase {

    inline function assertSelection(editor:ICodeEditor, expected:EitherType<Selection, Array<Selection>>, ?pos:haxe.PosInfos):Void {
        LinesOperationsTestHelper.assertSelection(this, editor, expected, pos);
    }

    inline function executeAction(action:EditorAction, editor:ICodeEditor):Void {
        LinesOperationsTestHelper.executeAction(action, editor);
    }

    /**
     * test('should join lines and insert space if necessary')
     */
    function testShouldJoinLinesAndInsertSpaceIfNecessary() {
        TestCodeEditor.withTestCodeEditor(
            [
                'hello',
                'world',
                'hello ',
                'world',
                'hello		',
                '	world',
                'hello   ',
                '	world',
                '',
                '',
                'hello world'
            ], {}, (editor, viewModel) -> {
                final model = editor.getModel();
                final joinLinesAction = new JoinLinesAction();

                editor.setSelection(new Selection(1, 2, 1, 2));
                executeAction(joinLinesAction, editor);
                assertEquals(model.getLineContent(1), 'hello world');
                assertSelection(editor, new Selection(1, 6, 1, 6));

                editor.setSelection(new Selection(2, 2, 2, 2));
                executeAction(joinLinesAction, editor);
                assertEquals(model.getLineContent(2), 'hello world');
                assertSelection(editor, new Selection(2, 7, 2, 7));

                editor.setSelection(new Selection(3, 2, 3, 2));
                executeAction(joinLinesAction, editor);
                assertEquals(model.getLineContent(3), 'hello world');
                assertSelection(editor, new Selection(3, 7, 3, 7));

                editor.setSelection(new Selection(4, 2, 5, 3));
                executeAction(joinLinesAction, editor);
                assertEquals(model.getLineContent(4), 'hello world');
                assertSelection(editor, new Selection(4, 2, 4, 8));

                editor.setSelection(new Selection(5, 1, 7, 3));
                executeAction(joinLinesAction, editor);
                assertEquals(model.getLineContent(5), 'hello world');
                assertSelection(editor, new Selection(5, 1, 5, 3));
            });
    }

    /**
     * test('#50471 Join lines at the end of document')
     */
    function test50471JoinLinesAtTheEndOfDocument() {
        TestCodeEditor.withTestCodeEditor(
            [
                'hello',
                'world'
            ], {}, (editor, viewModel) -> {
                final model = editor.getModel();
                final joinLinesAction = new JoinLinesAction();

                editor.setSelection(new Selection(2, 1, 2, 1));
                executeAction(joinLinesAction, editor);
                assertEquals(model.getLineContent(1), 'hello');
                assertEquals(model.getLineContent(2), 'world');
                assertSelection(editor, new Selection(2, 6, 2, 6));
            });
    }

    /**
     * test('should work in multi cursor mode')
     */
    function testShouldWorkInMultiCursorMode() {
        TestCodeEditor.withTestCodeEditor(
            [
                'hello',
                'world',
                'hello ',
                'world',
                'hello		',
                '	world',
                'hello   ',
                '	world',
                '',
                '',
                'hello world'
            ], {}, (editor, viewModel) -> {
                final model = editor.getModel();
                final joinLinesAction = new JoinLinesAction();

                editor.setSelections([
                    /** primary cursor */
                    new Selection(5, 2, 5, 2),
                    new Selection(1, 2, 1, 2),
                    new Selection(3, 2, 4, 2),
                    new Selection(5, 4, 6, 3),
                    new Selection(7, 5, 8, 4),
                    new Selection(10, 1, 10, 1)
                ]);

                executeAction(joinLinesAction, editor);
                assertEquals(model.getLinesContent().join('\n'), 'hello world\nhello world\nhello world\nhello world\n\nhello world');
                assertSelection(editor, [
                    /** primary cursor */
                    new Selection(3, 4, 3, 8),
                    new Selection(1, 6, 1, 6),
                    new Selection(2, 2, 2, 8),
                    new Selection(4, 5, 4, 9),
                    new Selection(6, 1, 6, 1)
                ]);
            });
    }

    /**
     * test('should push undo stop')
     */
    function testShouldPushUndoStop() {
        TestCodeEditor.withTestCodeEditor(
            [
                'hello',
                'world'
            ], {}, (editor, viewModel) -> {
                final model = editor.getModel();
                final joinLinesAction = new JoinLinesAction();

                editor.setSelection(new Selection(1, 6, 1, 6));

                editor.trigger('keyboard', Handler.Type, { text: ' my dear' });
                assertEquals(model.getLineContent(1), 'hello my dear');
                assertDeepEquals(editor.getSelection(), new Selection(1, 14, 1, 14));

                executeAction(joinLinesAction, editor);
                assertEquals(model.getLineContent(1), 'hello my dear world');
                assertDeepEquals(editor.getSelection(), new Selection(1, 14, 1, 14));

                CoreEditingCommands.Undo.runEditorCommand(null, editor, null);
                assertEquals(model.getLineContent(1), 'hello my dear');
                assertDeepEquals(editor.getSelection(), new Selection(1, 14, 1, 14));
            });
    }
}

/**
 * suite('Editor Contrib - Line Operations / DeleteAllRightAction')
 */
class DeleteAllRightActionTest extends TestCase {

    inline function assertSelection(editor:ICodeEditor, expected:EitherType<Selection, Array<Selection>>, ?pos:haxe.PosInfos):Void {
        LinesOperationsTestHelper.assertSelection(this, editor, expected, pos);
    }

    inline function executeAction(action:EditorAction, editor:ICodeEditor):Void {
        LinesOperationsTestHelper.executeAction(action, editor);
    }

    /**
     * test('should be noop on empty')
     */
    function testShouldBeNoopOnEmpty() {
        TestCodeEditor.withTestCodeEditor([''], {}, (editor, viewModel) -> {
            final model = editor.getModel();
            final action = new DeleteAllRightAction();

            executeAction(action, editor);
            assertDeepEquals(model.getLinesContent(), ['']);
            assertDeepEquals(editor.getSelections(), [new Selection(1, 1, 1, 1)]);

            editor.setSelection(new Selection(1, 1, 1, 1));
            executeAction(action, editor);
            assertDeepEquals(model.getLinesContent(), ['']);
            assertDeepEquals(editor.getSelections(), [new Selection(1, 1, 1, 1)]);

            editor.setSelections([new Selection(1, 1, 1, 1), new Selection(1, 1, 1, 1), new Selection(1, 1, 1, 1)]);
            executeAction(action, editor);
            assertDeepEquals(model.getLinesContent(), ['']);
            assertDeepEquals(editor.getSelections(), [new Selection(1, 1, 1, 1)]);
        });
    }

    /**
     * test('should delete selected range')
     */
    function testShouldDeleteSelectedRange() {
        TestCodeEditor.withTestCodeEditor([
            'hello',
            'world'
        ], {}, (editor, viewModel) -> {
            final model = editor.getModel();
            final action = new DeleteAllRightAction();

            editor.setSelection(new Selection(1, 2, 1, 5));
            executeAction(action, editor);
            assertDeepEquals(model.getLinesContent(), ['ho', 'world']);
            assertDeepEquals(editor.getSelections(), [new Selection(1, 2, 1, 2)]);

            editor.setSelection(new Selection(1, 1, 2, 4));
            executeAction(action, editor);
            assertDeepEquals(model.getLinesContent(), ['ld']);
            assertDeepEquals(editor.getSelections(), [new Selection(1, 1, 1, 1)]);

            editor.setSelection(new Selection(1, 1, 1, 3));
            executeAction(action, editor);
            assertDeepEquals(model.getLinesContent(), ['']);
            assertDeepEquals(editor.getSelections(), [new Selection(1, 1, 1, 1)]);
        });
    }

    /**
     * test('should delete to the right of the cursor')
     */
    function testShouldDeleteToTheRightOfTheCursor() {
        TestCodeEditor.withTestCodeEditor([
            'hello',
            'world'
        ], {}, (editor, viewModel) -> {
            final model = editor.getModel();
            final action = new DeleteAllRightAction();

            editor.setSelection(new Selection(1, 3, 1, 3));
            executeAction(action, editor);
            assertDeepEquals(model.getLinesContent(), ['he', 'world']);
            assertDeepEquals(editor.getSelections(), [new Selection(1, 3, 1, 3)]);

            editor.setSelection(new Selection(2, 1, 2, 1));
            executeAction(action, editor);
            assertDeepEquals(model.getLinesContent(), ['he', '']);
            assertDeepEquals(editor.getSelections(), [new Selection(2, 1, 2, 1)]);
        });
    }

    /**
     * test('should join two lines, if at the end of the line')
     */
    function testShouldJoinTwoLinesIfAtTheEndOfTheLine() {
        TestCodeEditor.withTestCodeEditor([
            'hello',
            'world'
        ], {}, (editor, viewModel) -> {
            final model = editor.getModel();
            final action = new DeleteAllRightAction();

            editor.setSelection(new Selection(1, 6, 1, 6));
            executeAction(action, editor);
            assertDeepEquals(model.getLinesContent(), ['helloworld']);
            assertDeepEquals(editor.getSelections(), [new Selection(1, 6, 1, 6)]);

            editor.setSelection(new Selection(1, 6, 1, 6));
            executeAction(action, editor);
            assertDeepEquals(model.getLinesContent(), ['hello']);
            assertDeepEquals(editor.getSelections(), [new Selection(1, 6, 1, 6)]);

            editor.setSelection(new Selection(1, 6, 1, 6));
            executeAction(action, editor);
            assertDeepEquals(model.getLinesContent(), ['hello']);
            assertDeepEquals(editor.getSelections(), [new Selection(1, 6, 1, 6)]);
        });
    }

    /**
     * test('should work with multiple cursors')
     */
    function testShouldWorkWithMultipleCursors() {
        TestCodeEditor.withTestCodeEditor([
            'hello',
            'there',
            'world'
        ], {}, (editor, viewModel) -> {
            final model = editor.getModel();
            final action = new DeleteAllRightAction();

            editor.setSelections([
                new Selection(1, 3, 1, 3),
                new Selection(1, 6, 1, 6),
                new Selection(3, 4, 3, 4),
            ]);
            executeAction(action, editor);
            assertDeepEquals(model.getLinesContent(), ['hethere', 'wor']);
            assertDeepEquals(editor.getSelections(), [
                new Selection(1, 3, 1, 3),
                new Selection(2, 4, 2, 4)
            ]);

            executeAction(action, editor);
            assertDeepEquals(model.getLinesContent(), ['he', 'wor']);
            assertDeepEquals(editor.getSelections(), [
                new Selection(1, 3, 1, 3),
                new Selection(2, 4, 2, 4)
            ]);

            executeAction(action, editor);
            assertDeepEquals(model.getLinesContent(), ['hewor']);
            assertDeepEquals(editor.getSelections(), [
                new Selection(1, 3, 1, 3),
                new Selection(1, 6, 1, 6)
            ]);

            executeAction(action, editor);
            assertDeepEquals(model.getLinesContent(), ['he']);
            assertDeepEquals(editor.getSelections(), [
                new Selection(1, 3, 1, 3)
            ]);

            executeAction(action, editor);
            assertDeepEquals(model.getLinesContent(), ['he']);
            assertDeepEquals(editor.getSelections(), [
                new Selection(1, 3, 1, 3)
            ]);
        });
    }

    /**
     * test('should work with undo/redo')
     */
    function testShouldWorkWithUndoRedo() {
        TestCodeEditor.withTestCodeEditor([
            'hello',
            'there',
            'world'
        ], {}, (editor, viewModel) -> {
            final model = editor.getModel();
            final action = new DeleteAllRightAction();

            editor.setSelections([
                new Selection(1, 3, 1, 3),
                new Selection(1, 6, 1, 6),
                new Selection(3, 4, 3, 4),
            ]);
            executeAction(action, editor);
            assertDeepEquals(model.getLinesContent(), ['hethere', 'wor']);
            assertDeepEquals(editor.getSelections(), [
                new Selection(1, 3, 1, 3),
                new Selection(2, 4, 2, 4)
            ]);

            CoreEditingCommands.Undo.runEditorCommand(null, editor, null);
            assertDeepEquals(editor.getSelections(), [
                new Selection(1, 3, 1, 3),
                new Selection(1, 6, 1, 6),
                new Selection(3, 4, 3, 4)
            ]);
            CoreEditingCommands.Redo.runEditorCommand(null, editor, null);
            assertDeepEquals(editor.getSelections(), [
                new Selection(1, 3, 1, 3),
                new Selection(2, 4, 2, 4)
            ]);
        });
    }
}
