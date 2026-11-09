package tests.config;

import cityscape.common.config.EditorOptions;
import cityscape.view.config.EditorConfiguration;
import testing.DeepEquals;
import testing.MonacoTruth;
import testing.TestCase;

/**
 * Compares the validation of the ported editor options with the real Monaco
 * 0.52.2: `data/monaco/editor-options.json`, written by glaze-golden's
 * `reference/cityscape/editor-options-truth.mjs` from loreline-monaco's
 * vendored build (on macOS).
 */
class EditorOptionsTruthTest extends TestCase {

    static var truth:Null<Any> = null;

    static function data():Any {
        if (truth == null) {
            truth = haxe.Json.parse(MonacoTruth.load('editor-options.json'));
        }
        return truth;
    }

    function option(name:String):IEditorOption<Any> {
        for (o in EditorOptions.editorOptionsRegistry) {
            if (o != null && o.name == name)
                return o;
        }
        return null;
    }

    function assertJsonEquals(json:Any, actual:Any, message:String, ?pos:haxe.PosInfos) {
        assertions++;
        final d = DeepEquals.diffJson(json, actual, message);
        if (d != null) {
            fail('expected ${haxe.Json.stringify(json)} but got ${haxe.Json.stringify(actual)} ($d)', pos);
        }
    }

    function testIds() {
        final ids:Any = Reflect.field(data(), 'ids');
        var max = -1;
        for (name in Reflect.fields(ids)) {
            final id:Int = Reflect.field(ids, name);
            if (id > max)
                max = id;
            final o = option(name);
            if (o != null) {
                assertEquals(id, o.id, name);
            }
        }
        assertEquals(max + 1, EditorOption.COUNT);
        // 60 options of step 0, 19 of the view (EditorViewOptions), 11 of the cursor (EditorCursorOptions),
        // 4 of the folding contribution (foldingHighlight, foldingImportsByDefault, foldingMaximumRegions,
        // unfoldOnClickAfterEndOfLine), 1 of the find contribution (find, EditorFindOptions), 2 of the
        // bracket pair colorization and guides (bracketPairColorization, guides), 1 of the comment
        // contribution (comments, EditorCommentsOptions), 6 of the language features
        // (EditorLanguageFeatureOptions: acceptSuggestionOnCommitCharacter, lightbulb,
        // snippetSuggestions, suggestFontSize, suggestLineHeight, suggestSelection), and the 10 of step 7:
        // peekWidgetDefaultFocus (peek view), colorDecoratorsActivatedOn, colorDecoratorsLimit,
        // defaultColorDecorators (EditorColorDecoratorsOptions), codeLens, codeLensFontFamily,
        // codeLensFontSize, inlayHints (EditorInlayHintsCodeLensOptions), parameterHints
        // (EditorParameterHintsOptions), inlineSuggest (EditorInlineSuggestOptions)
        assertEquals(114, [for (o in EditorOptions.editorOptionsRegistry) if (o != null) o].length);
    }

    function testDefaults() {
        final defaults:Any = Reflect.field(data(), 'defaults');
        for (name in Reflect.fields(defaults)) {
            final o = option(name);
            assertNotNull(o, name);
            if (o != null) {
                assertJsonEquals(Reflect.field(defaults, name), o.defaultValue, name);
            }
        }
    }

    function testValidate() {
        final cases:Array<Any> = Reflect.field(data(), 'cases');
        var failed = 0;
        for (c in cases) {
            final name:String = Reflect.field(c, 'option');
            final id:Int = Reflect.field(c, 'id');
            final o = EditorOptions.editorOptionsRegistry[id];
            assertNotNull(o, name);
            if (o == null)
                continue;
            final input:Any = Reflect.field(c, 'input');
            final expected:Any = Reflect.field(c, 'output');
            #if !js
            // Without `Intl`, well formed locale tags are kept even when ICU
            // does not know them ('true', 'false'): DEVIATIONS.md, "Word
            // segmentation without Intl"
            if (name == 'wordSegmenterLocales' && Std.isOfType(input, String) && ((input : String) == 'true' || (input : String) == 'false')) {
                continue;
            }
            #end
            final actual = o.validate(input);
            final d = DeepEquals.diffJson(expected, actual, name);
            assertions++;
            if (d != null && failed < 30) {
                failed++;
                fail('$name.validate(${haxe.Json.stringify(input)}): expected ${haxe.Json.stringify(expected)} but got ${haxe.Json.stringify(actual)} ($d)');
            }
        }
        assertTrue(cases.length > 1000);
    }

    /**
     * A full set of options as a host application gives them (fonts,
     * wrapping, suggestions, scrollbar, goto location).
     */
    function testHostOptionSet() {
        final hostOptionSet:Any = Reflect.field(data(), 'hostOptionSet');
        final options:IEditorOptions = Reflect.field(hostOptionSet, 'options');
        final expected:Any = Reflect.field(hostOptionSet, 'validated');
        final validated = EditorOptionsUtil.validateOptions(options);
        for (name in Reflect.fields(expected)) {
            final o = option(name);
            assertNotNull(o, name);
            if (o != null) {
                assertJsonEquals(Reflect.field(expected, name), validated.get(cast o.id), name);
            }
        }
    }

}
