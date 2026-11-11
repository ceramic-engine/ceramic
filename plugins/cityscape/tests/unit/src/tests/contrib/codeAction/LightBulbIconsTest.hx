// New code for Cityscape (not a port): the codicons of the lightbulb and of
// the rows of the code action menu, and their colors. Expected values from
// Monaco 0.52.2: lightBulbWidget.ts `_updateLightBulbTitleAndIcon`,
// lightBulbWidget.css, actionList.ts `ActionItemRenderer`, actionWidget.css
// and codeActionMenu.ts, checked on the real Monaco (glaze-golden scratchpad
// cs-polish-probe, s4-lightbulb.js and s5-menu.js: 16 px icons, light-bulb
// rgb(255, 204, 0) and lightbulb-autofix rgb(117, 190, 255) in vs-dark, the
// menu's lightbulbs in editorLightBulb.foreground, its wrench and sparkle in
// the row's color).
package tests.contrib.codeAction;

import cityscape.Cityscape;
import cityscape.base.common.Lifecycle;
import cityscape.base.common.Uri;
import cityscape.common.Languages.CodeAction;
import cityscape.common.Model.ITextModel;
import cityscape.contrib.codeAction.common.CodeActionTypes;
import cityscape.contrib.codeAction.view.CodeAction.ManagedCodeActionSet;
import cityscape.contrib.codeAction.view.CodeActionMenu;
import cityscape.contrib.codeAction.view.LightBulbWidget;
import cityscape.view.CodiconOutlines;
import cityscape.view.Codicons;
import testing.TestCase;
import testing.TestCodeEditor;

class LightBulbIconsTest extends TestCase {

    var context:Cityscape;
    var model:ITextModel;
    var editor:Null<TestCodeEditor> = null;

    override public function setup():Void {
        context = new Cityscape();
        model = context.modelService.createModel('foo\n', null, Uri.parse('file:///lightbulb.txt'));
    }

    override public function teardown():Void {
        if (editor != null) {
            editor.dispose();
            editor = null;
        }
        model.dispose();
    }

    static function item(title:String, ?kind:String, preferred:Bool = false, ai:Bool = false):CodeActionItem {
        final action:CodeAction = {title: title, kind: kind, isPreferred: preferred, isAI: ai};
        return new CodeActionItem(action, null);
    }

    static function set(items:Array<CodeActionItem>):ManagedCodeActionSet {
        return new ManagedCodeActionSet(items, [], new DisposableStore());
    }

    static function hex(c:glaze.Hsla):String {
        final rgba = c.toRgb();
        inline function h(v:Float):String {
            return StringTools.hex(Math.round(v * 255), 2);
        }
        return '#' + h(rgba.r) + h(rgba.g) + h(rgba.b);
    }

    /** `_updateLightBulbTitleAndIcon` */
    function testLightbulbIcon() {
        assertEquals('light-bulb', LightBulbWidget.iconOf(set([item('a', 'quickfix'), item('b', 'refactor')])));
        assertEquals('lightbulb-autofix', LightBulbWidget.iconOf(set([item('a', 'quickfix', true), item('b', 'quickfix')])));
        assertEquals('lightbulb-sparkle', LightBulbWidget.iconOf(set([item('a', 'quickfix'), item('b', 'quickfix', false, true)])));
        assertEquals('lightbulb-sparkle-autofix', LightBulbWidget.iconOf(set([item('a', 'quickfix', true), item('b', 'quickfix', false, true)])));
        assertEquals('sparkle-filled', LightBulbWidget.iconOf(set([item('b', 'quickfix', false, true)])));
        // a preferred action that is not a quick fix is no auto fix
        assertEquals('light-bulb', LightBulbWidget.iconOf(set([item('a', 'refactor', true)])));
        for (id in ['light-bulb', 'lightbulb-autofix', 'lightbulb-sparkle', 'lightbulb-sparkle-autofix', 'sparkle-filled', 'wrench', 'surround-with', 'symbol-file', 'sparkle', 'arrow-right', 'discard']) {
            assertNotNull(CodiconOutlines.pathOf(id), id);
            assertNotNull(Codicons.svg(id), id);
        }
        assertEquals(16.0, LightBulbWidget.ICON_SIZE);
    }

    /** lightBulbWidget.css, with the registered defaults of vs-dark and vs */
    function testLightbulbColors() {
        editor = new TestCodeEditor(context, cast model, {}, []);
        context.themeService.setTheme('vs-dark');
        assertEquals('#FFCC00', hex(LightBulbWidget.colorOf(editor, 'light-bulb')));
        assertEquals('#FFCC00', hex(LightBulbWidget.colorOf(editor, 'lightbulb-sparkle')));
        assertEquals('#75BEFF', hex(LightBulbWidget.colorOf(editor, 'lightbulb-autofix')));
        assertEquals('#75BEFF', hex(LightBulbWidget.colorOf(editor, 'lightbulb-sparkle-autofix')));
        // editorLightBulbAi.foreground defaults to editorLightBulb.foreground
        assertEquals('#FFCC00', hex(LightBulbWidget.colorOf(editor, 'sparkle-filled')));
        context.themeService.setTheme('vs');
        assertEquals('#DDB100', hex(LightBulbWidget.colorOf(editor, 'light-bulb')));
        assertEquals('#007ACC', hex(LightBulbWidget.colorOf(editor, 'lightbulb-autofix')));
        context.themeService.defineTheme('mine', {base: 'vs-dark', inherit: true, rules: [], colors: {'editorLightBulbAutoFix.foreground': '#ff0000'}});
        context.themeService.setTheme('mine');
        assertEquals('#FF0000', hex(LightBulbWidget.colorOf(editor, 'lightbulb-autofix')));
    }

    /**
     * The menu rows: their group's codicon in the row's color (wrench for
     * the refactorings, surround-with, symbol-file for source actions,
     * sparkle for AI actions), else the lightbulb in
     * `editorLightBulb.foreground` (quick fixes, preferred or not, and the
     * actions of no group).
     */
    function testMenuIcons() {
        editor = new TestCodeEditor(context, cast model, {}, []);
        context.themeService.setTheme('vs-dark');
        final items = CodeActionMenu.toMenuItems([
            item('Fix', 'quickfix'),
            item('Preferred', 'quickfix', true),
            item('AI', 'quickfix', false, true),
            item('Extract', 'refactor.extract'),
            item('Rewrite', 'refactor.rewrite'),
            item('Surround', 'refactor.surround'),
            item('Plain surround', 'surround'),
            item('Organize', 'source.organizeImports'),
            item('Other', 'custom')
        ], true, _ -> null);
        final rows = [for (i in items) if (i.kind == ActionListItemKind.Action) i];
        final icons = [for (r in rows) r.label + ':' + CodeActionWidget.iconOf(r)];
        assertEquals('Fix:light-bulb,Preferred:light-bulb,AI:sparkle,Extract:wrench,Rewrite:wrench,Surround:surround-with,Organize:symbol-file,Plain surround:light-bulb,Other:light-bulb', icons.join(','));
        final colors = [for (r in rows) {final c = CodeActionWidget.iconColorOf(editor, r); c == null ? 'row' : hex(c);}];
        assertEquals('#FFCC00,#FFCC00,row,row,row,row,row,#FFCC00,#FFCC00', colors.join(','));
        assertEquals(16.0, CodeActionWidget.ICON_SIZE);
    }

}
