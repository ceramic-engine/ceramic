// Ported from vscode src/vs/editor/test/common/services/modelService.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.services;

import cityscape.Cityscape;
import cityscape.CityscapeEditor;
import cityscape.base.common.Uri;
import cityscape.common.Model.DefaultEndOfLine;
import cityscape.common.services.ModelService;
import cityscape.standalone.StandaloneConfiguration;
import glaze.App;
import glaze.TestDispatcher;
import glaze.Window;
import testing.TestCase;

import glaze.Prelude.*;

/**
 * One editor with `tabSize: 2` on a model.
 */
class ModelServiceTestHost extends glaze.Component {

    final context:Cityscape;
    final model:cityscape.common.Model.ITextModel;

    public function new(context:Cityscape, model:cityscape.common.Model.ITextModel) {
        super();
        this.context = context;
        this.model = model;
    }

    public function render(window:Window, cx:App):glaze.IntoElement {
        return div().flex().sizeFull().child(CityscapeEditor.component().context(context).model(model).tabSize(2).flex1());
    }

}

/**
 * suite('ModelService'), the creation options read from the configuration.
 *
 * Ported: 'EOL setting respected depending on root', without the folder
 * override (`files.eol` set for `/myroot` only): the standalone
 * configuration has no resource overrides, so the global value is checked.
 * The `_computeEdits`, `generated*`, `does *` and undo tests are not ported
 * yet (the model service does not keep the undo stacks of disposed models).
 *
 * New tests for Cityscape (not ports) check the behaviour of Monaco's code
 * that has no vscode test: the editor options written to the configuration
 * (`updateConfigurationService`) reach the models created afterwards, the
 * existing models are updated (`_updateModelOptions`), and indentation is
 * detected from the text with the configured defaults.
 */
class ModelServiceTest extends TestCase {

    var context:Cityscape;

    override public function setup():Void {
        context = new Cityscape();
    }

    override public function teardown():Void {
        for (model in context.modelService.getModels()) {
            model.dispose();
        }
    }

    function testEOLSettingRespected() {
        context.configurationService.updateValues([{key: 'files.eol', value: '\r\n'}]);
        final model1 = context.modelService.createModel('farboo', null);
        final model2 = context.modelService.createModel('farboo', null, Uri.file('/myroot/myfile.txt'));
        assertEquals(DefaultEndOfLine.CRLF, model1.getOptions().defaultEOL);
        assertEquals(DefaultEndOfLine.CRLF, model2.getOptions().defaultEOL);
        context.configurationService.updateValues([{key: 'files.eol', value: '\n'}]);
        final model3 = context.modelService.createModel('farboo', null, Uri.file('/other/myfile.txt'));
        assertEquals(DefaultEndOfLine.LF, model3.getOptions().defaultEOL);
    }

    function testDefaultsWithoutConfiguration() {
        final model = context.modelService.createModel('a\n\tb', null);
        // EDITOR_MODEL_DEFAULTS: tabSize 4, insertSpaces true, detected
        // from the text (a tab indented line: tabs)
        assertEquals(4, model.getOptions().tabSize);
        assertFalse(model.getOptions().insertSpaces);
    }

    function testEditorOptionsReachNewModels() {
        StandaloneConfiguration.updateConfigurationService(context.configurationService, {tabSize: 2, fontSize: 17, model: null}, false);
        assertEquals(2, (context.configurationService.getValue('editor.tabSize') : Int));
        assertEquals(17, (context.configurationService.getValue('editor.fontSize') : Int));
        // not an editor setting
        assertEquals(null, context.configurationService.getValue('editor.model'));
        // no indentation in the text: the configured defaults
        final plain = context.modelService.createModel('hello\nworld', null);
        assertEquals(2, plain.getOptions().tabSize);
        assertTrue(plain.getOptions().insertSpaces);
        // indentation of 4 spaces detected (detectIndentation is on by default)
        final four = context.modelService.createModel('if\n    a\n    b\nend\n    c', null);
        assertEquals(4, four.getOptions().tabSize);
        assertTrue(four.getOptions().insertSpaces);
    }

    function testDetectIndentationOff() {
        StandaloneConfiguration.updateConfigurationService(context.configurationService, {tabSize: 3, insertSpaces: false, detectIndentation: false}, false);
        final model = context.modelService.createModel('if\n    a\n    b\nend', null);
        assertEquals(3, model.getOptions().tabSize);
        assertFalse(model.getOptions().insertSpaces);
    }

    function testConfigurationChangeUpdatesExistingModels() {
        final model = context.modelService.createModel('hello\nworld', null, Uri.parse('inmemory://test/a.txt'));
        assertEquals(4, model.getOptions().tabSize);
        var events = 0;
        model.onDidChangeOptions(_ -> events++);
        StandaloneConfiguration.updateConfigurationService(context.configurationService, {tabSize: 2}, false);
        assertEquals(2, model.getOptions().tabSize);
        assertEquals(1, events);
        // the same value again: no change event from the configuration
        StandaloneConfiguration.updateConfigurationService(context.configurationService, {tabSize: 2}, false);
        assertEquals(1, events);
        // a setting that is not about models leaves them alone
        StandaloneConfiguration.updateConfigurationService(context.configurationService, {fontSize: 20}, false);
        assertEquals(1, events);
    }

    function testReadModelOptions() {
        final options = ModelService._readModelOptions({editor: {tabSize: '0', insertSpaces: 'false', indentSize: 'tabSize', detectIndentation: 0}, eol: '\r\n'}, false);
        assertEquals(1, options.tabSize);
        assertFalse(options.insertSpaces);
        assertEquals('tabSize', (options.indentSize : String));
        assertFalse(options.detectIndentation);
        assertEquals(DefaultEndOfLine.CRLF, options.defaultEOL);
    }

    function testEditorWritesItsOptions() {
        final app = new App(new TestDispatcher());
        final before = context.modelService.createModel('x\ny', null, Uri.parse('inmemory://test/before.txt'));
        final window = Window.open(app, {width: 400, height: 300, scaleFactor: 2, autoDraw: false, bindInput: false},
            ModelServiceTestHost.component(context, before));
        app.update(_ -> window.draw());
        // the editor's options went to the configuration of its context
        assertEquals(2, (context.configurationService.getValue('editor.tabSize') : Int));
        // the model that existed before was updated, a new one takes them
        assertEquals(2, before.getOptions().tabSize);
        final after = context.modelService.createModel('a\nb', null);
        assertEquals(2, after.getOptions().tabSize);
        window.destroy();
        ceramic.App.app.flushImmediate();
    }

}
