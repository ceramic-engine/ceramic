// New code for Cityscape (not a port): the link detector (links.ts) with
// the default link provider and with providers of the test, the Cmd+click
// gesture opening through `Cityscape.openLink`, `command:` links and the
// `links` option. Expected values follow links.ts and getLinks.ts (the
// hover message of `getHoverMessage`, `LinksList._union`).
package tests.contrib.links;

import cityscape.Cityscape;
import cityscape.base.common.Cancellation;
import cityscape.base.common.Platform;
import cityscape.base.common.Uri;
import cityscape.common.Languages;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.contrib.links.view.Links;
import cityscape.view.EditorBrowser;
import testing.TestCase;
import testing.TestCodeEditor;

private class TestLinkProvider implements LinkProvider {

    final links:Array<ILink>;
    public var resolveLink(default, null):Null<(link:ILink, token:CancellationToken, resolve:(link:Null<ILink>) -> Void) -> Void> = null;

    public function new(links:Array<ILink>, ?resolveUrl:String) {
        this.links = links;
        if (resolveUrl != null) {
            resolveLink = (link, token, resolve) -> resolve({range: link.range, url: resolveUrl});
        }
    }

    public function provideLinks(model:ITextModel, token:CancellationToken, resolve:(links:Null<ILinksList>) -> Void):Void {
        resolve({links: links});
    }
}

class LinksTest extends TestCase {

    var context:Cityscape;
    var model:ITextModel;
    final editors:Array<TestCodeEditor> = [];

    override public function setup():Void {
        context = new Cityscape();
        // the contributions and the default link provider of the context
        context.editorExtensions;
    }

    override public function teardown():Void {
        for (editor in editors) {
            editor.dispose();
        }
        editors.resize(0);
        if (model != null) {
            model.dispose();
            model = null;
        }
    }

    function newEditor(text:String, ?options:cityscape.common.config.EditorOptions.IEditorOptions):TestCodeEditor {
        model = context.modelService.createModel(text, 'plaintext', Uri.parse('file:///project/main.txt'));
        final editor = new TestCodeEditor(context, cast model, options != null ? options : {}, context.editorExtensions.getSomeEditorContributions([LinkDetector.ID]));
        editor.getViewModel().setHasFocus(true);
        editors.push(editor);
        LinkDetector.get(editor)._flushComputeLinks();
        return editor;
    }

    static function kb():String {
        // multiCursorModifier 'alt' (the default): the trigger is Cmd or Ctrl
        return Platform.isMacintosh ? 'cmd + click' : 'ctrl + click';
    }

    static function mouse(editor:TestCodeEditor, kind:String, lineNumber:Int, column:Int, withTrigger:Bool):Void {
        final target = new MouseTarget(MouseTargetType.CONTENT_TEXT, new Position(lineNumber, column), column, new Range(lineNumber, column, lineNumber, column));
        // Cmd and Ctrl together: the trigger modifier of every platform
        final data = new EditorMouseEventData(true, false, false, withTrigger, false, false, withTrigger, 1);
        final e = new EditorMouseEvent(data, target);
        switch kind {
            case 'move': @:privateAccess editor._fireMouseMove(e);
            case 'down': @:privateAccess editor._fireMouseDown(e);
            case 'up': @:privateAccess editor._fireMouseUp(e);
            case _:
        }
    }

    function testDefaultLinkComputerDecoratesLinks() {
        final editor = newEditor('see http://foo.bar here\nand (https://example.com/a?b=c).');
        final links = LinkDetector.get(editor).getLinkDecorations();
        assertEquals(2, links.length);
        assertTrue(links[0].range.equalsRange(new Range(1, 5, 1, 19)));
        assertFalse(links[0].active);
        assertEquals('[Follow link](http://foo.bar) (' + kb() + ')', links[0].hoverMessage);
        assertTrue(links[1].range.equalsRange(new Range(2, 6, 2, 31)));
        // the class name of the decorations
        final decorations = model.getDecorationsInRange(new Range(1, 6, 1, 6));
        var found = false;
        for (d in decorations) {
            if (d.options.inlineClassName == 'detected-link') {
                found = true;
            }
        }
        assertTrue(found);
    }

    function testLinksOfAProviderAreMergedWithTheDefaultOnes() {
        context.registerLinkProvider('plaintext', new TestLinkProvider([
            {range: new Range(1, 1, 1, 4), url: Uri.parse('https://example.com/see'), tooltip: 'Open the docs'},
            // overlaps the link of the default computer, which goes away
            {range: new Range(1, 5, 1, 9), url: 'https://example.com/http'}
        ]));
        final editor = newEditor('see http://foo.bar here');
        final links = LinkDetector.get(editor).getLinkDecorations();
        assertEquals(2, links.length);
        assertTrue(links[0].range.equalsRange(new Range(1, 1, 1, 4)));
        assertEquals('[Open the docs](https://example.com/see) (' + kb() + ')', links[0].hoverMessage);
        assertTrue(links[1].range.equalsRange(new Range(1, 5, 1, 9)));
    }

    function testCmdHoverActivatesAndCmdClickOpensThroughTheHook() {
        final opened:Array<{uri:String, fromUserGesture:Bool}> = [];
        context.openLink = (uri, fromUserGesture) -> {
            opened.push({uri: uri.toString(), fromUserGesture: fromUserGesture});
            return true;
        };
        final editor = newEditor('see http://foo.bar here');
        final detector = LinkDetector.get(editor);

        // Cmd hover: the link under the mouse is the active one
        mouse(editor, 'move', 1, 8, true);
        var links = detector.getLinkDecorations();
        assertEquals(1, links.length);
        assertTrue(links[0].active);

        // without Cmd: back to a plain link
        mouse(editor, 'move', 1, 8, false);
        links = detector.getLinkDecorations();
        assertFalse(links[0].active);

        // a click without Cmd opens nothing
        mouse(editor, 'down', 1, 8, false);
        mouse(editor, 'up', 1, 8, false);
        assertEquals(0, opened.length);

        // Cmd+click opens the link through the opener
        mouse(editor, 'move', 1, 8, true);
        mouse(editor, 'down', 1, 8, true);
        mouse(editor, 'up', 1, 8, true);
        assertEquals(1, opened.length);
        assertEquals('http://foo.bar/', opened[0].uri);
        assertTrue(opened[0].fromUserGesture);

        // Cmd+click outside of a link opens nothing
        mouse(editor, 'down', 1, 2, true);
        mouse(editor, 'up', 1, 2, true);
        assertEquals(1, opened.length);
    }

    function testCommandLinksRunTheirCommand() {
        final calls:Array<Array<Any>> = [];
        Cityscape.registerCommand('test.linkCommand', (accessor, args) -> {
            calls.push(args);
        }, context);
        final args = StringTools.urlEncode('["a",2]');
        context.registerLinkProvider('plaintext', new TestLinkProvider([
            {range: new Range(1, 1, 1, 4), url: 'command:test.linkCommand?' + args}
        ]));
        final editor = newEditor('run it');
        final links = LinkDetector.get(editor).getLinkDecorations();
        assertEquals(1, links.length);
        assertTrue(StringTools.startsWith(links[0].hoverMessage, '[Execute command](command:test.linkCommand?'));
        assertTrue(StringTools.endsWith(links[0].hoverMessage, ' "Execute command test.linkCommand") (' + kb() + ')'));
        mouse(editor, 'move', 1, 2, true);
        mouse(editor, 'down', 1, 2, true);
        mouse(editor, 'up', 1, 2, true);
        assertEquals(1, calls.length);
        assertEquals('a', (calls[0][0] : String));
        assertEquals(2, (calls[0][1] : Int));
    }

    function testLinksWithoutUrlAreResolvedByTheProvider() {
        final opened:Array<String> = [];
        context.openLink = (uri, fromUserGesture) -> {
            opened.push(uri.toString());
            return true;
        };
        context.registerLinkProvider('plaintext', new TestLinkProvider([
            {range: new Range(1, 1, 1, 4)}
        ], 'https://example.com/resolved'));
        final editor = newEditor('run it');
        final links = LinkDetector.get(editor).getLinkDecorations();
        assertEquals('Follow&nbsp;link&nbsp;\\(' + StringTools.replace(StringTools.replace(kb(), '+', '\\+'), ' ', '&nbsp;') + '\\)', links[0].hoverMessage);
        editor.setPosition(new Position(1, 2));
        editor.trigger('keyboard', OpenLinkAction.ID, null);
        assertEquals(1, opened.length);
        assertEquals('https://example.com/resolved', opened[0]);
    }

    function testTheLinksOptionTurnsTheDetectionOff() {
        final editor = newEditor('see http://foo.bar here', {links: false});
        assertEquals(0, LinkDetector.get(editor).getLinkDecorations().length);
        editor.updateOptions({links: true});
        LinkDetector.get(editor)._flushComputeLinks();
        assertEquals(1, LinkDetector.get(editor).getLinkDecorations().length);
        editor.updateOptions({links: false});
        assertEquals(0, LinkDetector.get(editor).getLinkDecorations().length);
    }

    function testLinksAreComputedAgainAfterAnEdit() {
        final editor = newEditor('see http://foo.bar here');
        editor.executeEdits('test', [{range: new Range(1, 24, 1, 24), text: ' and https://two.example'}]);
        LinkDetector.get(editor)._flushComputeLinks();
        final links = LinkDetector.get(editor).getLinkDecorations();
        assertEquals(2, links.length);
        assertTrue(links[1].range.equalsRange(new Range(1, 29, 1, 48)));
    }

}
