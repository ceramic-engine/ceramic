// Ported from vscode src/vs/editor/test/browser/config/editorConfiguration.test.ts (suite 'Common Editor Config')
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.config;

import cityscape.common.config.EditorOptions;
import cityscape.view.config.EditorConfiguration;
import testing.TestCase;

/**
 * The tests of suite('Common Editor Config') that only need option
 * validation. The configuration is replaced by `ValidatingConfiguration`,
 * which keeps the raw options and validates them like Monaco's
 * `EditorConfiguration` (`updateOptions` merges with
 * `EditorOptionsUtil.applyUpdate`); the computed options it would add read
 * the environment, which comes with the view.
 *
 * Not ported yet: 'Zoom Level' (EditorZoom), the 'wordWrap ...' tests (they
 * read `wrappingInfo`, computed from `layoutInfo` in step 2) and 'issue
 * #151926' (`unicodeHighlight` is not ported yet).
 */
class EditorConfigurationTest extends TestCase {

    function testIssue53152CannotAssignToReadOnlyPropertyEnabledOfObject() {
        // Monaco makes `enabled` read only with Object.defineProperty; Haxe
        // has no such thing, the update must still apply
        final hoverOptions:IEditorHoverOptions = {enabled: true};
        final config = new ValidatingConfiguration({hover: hoverOptions});

        assertEquals(config.get(EditorOption.hover).enabled, true);
        config.updateOptions({hover: {enabled: false}});
        assertEquals(config.get(EditorOption.hover).enabled, false);
    }

    function testDoesNotEmitEventWhenNothingChanges() {
        final config = new ValidatingConfiguration({glyphMargin: true, roundedSelection: false});
        assertEquals(config.get(EditorOption.glyphMargin), true);

        assertEquals(config.updateOptions({glyphMargin: true}), false);
        assertEquals(config.updateOptions({roundedSelection: false}), false);
    }

    function testIssue94931UnableToOpenSourceFile() {
        final config = new ValidatingConfiguration({quickSuggestions: null});
        final actual = config.get(EditorOption.quickSuggestions);
        assertDeepEquals({
            other: 'on',
            comments: 'off',
            strings: 'off'
        }, actual);
    }

    function testIssue102920CantSnapOrSplitViewWithJSONFiles() {
        final config = new ValidatingConfiguration({quickSuggestions: null});
        config.updateOptions({quickSuggestions: {strings: true}});
        final actual = config.get(EditorOption.quickSuggestions);
        assertDeepEquals({
            other: 'on',
            comments: 'off',
            strings: 'on'
        }, actual);
    }

}

/**
 * The raw options and their validation, as in Monaco's
 * `EditorConfiguration` (constructor and `updateOptions`).
 */
private class ValidatingConfiguration {

    final _rawOptions:IEditorOptions;

    var _validatedOptions:ValidatedEditorOptions;

    public function new(options:IEditorOptions) {
        this._rawOptions = EditorConfigurationUtils.deepCloneAndMigrateOptions(options);
        this._validatedOptions = EditorOptionsUtil.validateOptions(this._rawOptions);
    }

    public function get<V>(id:EditorOption<V>):V {
        return this._validatedOptions.get(id);
    }

    /**
     * Returns whether something changed (Monaco fires `onDidChange` then).
     */
    public function updateOptions(_newOptions:IEditorOptions):Bool {
        final newOptions = EditorConfigurationUtils.deepCloneAndMigrateOptions(_newOptions);
        final didChange = EditorOptionsUtil.applyUpdate(this._rawOptions, newOptions);
        if (!didChange) {
            return false;
        }
        this._validatedOptions = EditorOptionsUtil.validateOptions(this._rawOptions);
        return true;
    }

}
