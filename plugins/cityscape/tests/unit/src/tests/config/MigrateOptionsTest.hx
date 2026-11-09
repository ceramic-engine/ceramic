// Ported from vscode src/vs/editor/test/browser/config/editorConfiguration.test.ts (suite 'migrateOptions')
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.config;

import cityscape.view.config.MigrateOptions;
import testing.TestCase;

/**
 * suite('migrateOptions'). Monaco writes `undefined` where a migration
 * removes a value; Cityscape writes null (the expected objects below have
 * null there).
 */
class MigrateOptionsTest extends TestCase {

    function migrate(options:Any):Any {
        MigrateOptions.migrateOptions(options);
        return options;
    }

    function testWordWrap() {
        assertDeepEquals(migrate({wordWrap: true}), {wordWrap: 'on'});
        assertDeepEquals(migrate({wordWrap: false}), {wordWrap: 'off'});
    }

    function testLineNumbers() {
        assertDeepEquals(migrate({lineNumbers: true}), {lineNumbers: 'on'});
        assertDeepEquals(migrate({lineNumbers: false}), {lineNumbers: 'off'});
    }

    function testAutoClosingBrackets() {
        assertDeepEquals(migrate({autoClosingBrackets: false}), {autoClosingBrackets: 'never', autoClosingQuotes: 'never', autoSurround: 'never'});
    }

    function testCursorBlinking() {
        assertDeepEquals(migrate({cursorBlinking: 'visible'}), {cursorBlinking: 'solid'});
    }

    function testRenderWhitespace() {
        assertDeepEquals(migrate({renderWhitespace: true}), {renderWhitespace: 'boundary'});
        assertDeepEquals(migrate({renderWhitespace: false}), {renderWhitespace: 'none'});
    }

    function testRenderLineHighlight() {
        assertDeepEquals(migrate({renderLineHighlight: true}), {renderLineHighlight: 'line'});
        assertDeepEquals(migrate({renderLineHighlight: false}), {renderLineHighlight: 'none'});
    }

    function testAcceptSuggestionOnEnter() {
        assertDeepEquals(migrate({acceptSuggestionOnEnter: true}), {acceptSuggestionOnEnter: 'on'});
        assertDeepEquals(migrate({acceptSuggestionOnEnter: false}), {acceptSuggestionOnEnter: 'off'});
    }

    function testTabCompletion() {
        assertDeepEquals(migrate({tabCompletion: true}), {tabCompletion: 'onlySnippets'});
        assertDeepEquals(migrate({tabCompletion: false}), {tabCompletion: 'off'});
    }

    function testSuggestFilteredTypes() {
        assertDeepEquals(
            migrate({
                suggest: {
                    filteredTypes: {
                        method: false,
                        "function": false,
                        constructor: false,
                        deprecated: false,
                        field: false,
                        variable: false,
                        "class": false,
                        struct: false,
                        "interface": false,
                        module: false,
                        property: false,
                        event: false,
                        "operator": false,
                        unit: false,
                        value: false,
                        constant: false,
                        "enum": false,
                        enumMember: false,
                        keyword: false,
                        text: false,
                        color: false,
                        file: false,
                        reference: false,
                        folder: false,
                        typeParameter: false,
                        snippet: false,
                    }
                }
            }), {
            suggest: {
                filteredTypes: null,
                showMethods: false,
                showFunctions: false,
                showConstructors: false,
                showDeprecated: false,
                showFields: false,
                showVariables: false,
                showClasses: false,
                showStructs: false,
                showInterfaces: false,
                showModules: false,
                showProperties: false,
                showEvents: false,
                showOperators: false,
                showUnits: false,
                showValues: false,
                showConstants: false,
                showEnums: false,
                showEnumMembers: false,
                showKeywords: false,
                showWords: false,
                showColors: false,
                showFiles: false,
                showReferences: false,
                showFolders: false,
                showTypeParameters: false,
                showSnippets: false,
            }
        });
    }

    function testQuickSuggestions() {
        assertDeepEquals(migrate({quickSuggestions: true}), {quickSuggestions: {comments: 'on', strings: 'on', other: 'on'}});
        assertDeepEquals(migrate({quickSuggestions: false}), {quickSuggestions: {comments: 'off', strings: 'off', other: 'off'}});
        assertDeepEquals(migrate({quickSuggestions: {comments: 'on', strings: 'off'}}), {quickSuggestions: {comments: 'on', strings: 'off'}});
    }

    function testHover() {
        assertDeepEquals(migrate({hover: true}), {hover: {enabled: true}});
        assertDeepEquals(migrate({hover: false}), {hover: {enabled: false}});
    }

    function testParameterHints() {
        assertDeepEquals(migrate({parameterHints: true}), {parameterHints: {enabled: true}});
        assertDeepEquals(migrate({parameterHints: false}), {parameterHints: {enabled: false}});
    }

    function testAutoIndent() {
        assertDeepEquals(migrate({autoIndent: true}), {autoIndent: 'full'});
        assertDeepEquals(migrate({autoIndent: false}), {autoIndent: 'advanced'});
    }

    function testMatchBrackets() {
        assertDeepEquals(migrate({matchBrackets: true}), {matchBrackets: 'always'});
        assertDeepEquals(migrate({matchBrackets: false}), {matchBrackets: 'never'});
    }

    function testRenderIndentGuidesHighlightActiveIndentGuide() {
        assertDeepEquals(migrate({renderIndentGuides: true}), {renderIndentGuides: null, guides: {indentation: true}});
        assertDeepEquals(migrate({renderIndentGuides: false}), {renderIndentGuides: null, guides: {indentation: false}});
        assertDeepEquals(migrate({highlightActiveIndentGuide: true}), {highlightActiveIndentGuide: null, guides: {highlightActiveIndentation: true}});
        assertDeepEquals(migrate({highlightActiveIndentGuide: false}), {highlightActiveIndentGuide: null, guides: {highlightActiveIndentation: false}});
    }

    function testMigrationDoesNotOverwriteNewSetting() {
        assertDeepEquals(migrate({renderIndentGuides: true, guides: {indentation: false}}), {renderIndentGuides: null, guides: {indentation: false}});
        assertDeepEquals(migrate({highlightActiveIndentGuide: true, guides: {highlightActiveIndentation: false}}), {highlightActiveIndentGuide: null, guides: {highlightActiveIndentation: false}});
    }

}
