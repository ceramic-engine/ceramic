// Ported from vscode src/vs/editor/contrib/documentSymbols/test/browser/outlineModel.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.contrib.documentSymbols;

import cityscape.base.common.Cancellation;
import cityscape.base.common.Lifecycle.IDisposable;
import cityscape.base.common.Uri;
import cityscape.common.Languages.DocumentSymbol;
import cityscape.common.Languages.DocumentSymbolProvider;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Range;
import cityscape.common.services.LanguageFeaturesService;
import cityscape.common.services.ModelService;
import cityscape.contrib.documentSymbols.view.OutlineModel;
import cityscape.platform.markers.common.Markers.IMarker;
import cityscape.platform.markers.common.Markers.MarkerSeverity;
import testing.TestCase;

/**
 * A document symbol provider calling a function (the object literals of
 * the tests).
 */
private class FnDocumentSymbolProvider implements DocumentSymbolProvider {
    public var displayName(default, null):Null<String> = null;

    final fn:(model:ITextModel, token:CancellationToken, resolve:(symbols:Null<Array<DocumentSymbol>>) -> Void) -> Void;

    public function new(fn:(model:ITextModel, token:CancellationToken, resolve:(symbols:Null<Array<DocumentSymbol>>) -> Void) -> Void) {
        this.fn = fn;
    }

    public function provideDocumentSymbols(model:ITextModel, token:CancellationToken, resolve:(symbols:Null<Array<DocumentSymbol>>) -> Void):Void {
        fn(model, token, resolve);
    }
}

/**
 * vscode's `class extends OutlineModel` of 'OutlineElement -
 * updateMarker/multiple groups'.
 */
private class ReadyForTestingOutlineModel extends OutlineModel {
    public function new() {
        super(null);
    }

    public function readyForTesting():Void {
        this._groups = cast this.children;
    }
}

/**
 * suite('OutlineModel'). The `async` tests run synchronously: the providers
 * answer at once and `Promise` settles at once.
 *
 * Differences with vscode's tests:
 * - the providers are registered with `{pattern: '/fome/path.foo'}`
 *   instead of `{pattern: '**' + '/path.foo'}`: glob patterns of language
 *   selectors are not ported yet (a pattern must be the path itself);
 * - `OutlineModelService` takes no language feature debounce service (not
 *   ported, see its class comment).
 */
class OutlineModelTest extends TestCase {

    final languageFeaturesService = new LanguageFeaturesService();

    function testOutlineModelCreateCached() {

        final modelService = new ModelService();
        final service = new OutlineModelService(languageFeaturesService, modelService);

        final model = tests.TestTextModel.createTextModel('foo', null, null, Uri.file('/fome/path.foo'));
        var count = 0;
        final reg = languageFeaturesService.documentSymbolProvider.register(({pattern: '/fome/path.foo'} : cityscape.common.LanguageSelector.LanguageFilter), new FnDocumentSymbolProvider((model, token, resolve) -> {
            count += 1;
            resolve([]);
        }));

        var done = false;
        service.getOrCreate(model, CancellationTokens.None).done(_ -> done = true);
        assertTrue(done);
        assertEquals(1, count);

        // cached
        done = false;
        service.getOrCreate(model, CancellationTokens.None).done(_ -> done = true);
        assertTrue(done);
        assertEquals(1, count);

        // new version
        model.applyEdits([{text: 'XXX', range: new Range(1, 1, 1, 1)}]);
        done = false;
        service.getOrCreate(model, CancellationTokens.None).done(_ -> done = true);
        assertTrue(done);
        assertEquals(2, count);

        reg.dispose();
        model.dispose();
        service.dispose();
        modelService.dispose();
    }

    function testOutlineModelCreateCachedCancel() {

        final modelService = new ModelService();
        final service = new OutlineModelService(languageFeaturesService, modelService);
        final model = tests.TestTextModel.createTextModel('foo', null, null, Uri.file('/fome/path.foo'));
        var isCancelled = false;

        final reg = languageFeaturesService.documentSymbolProvider.register(({pattern: '/fome/path.foo'} : cityscape.common.LanguageSelector.LanguageFilter), new FnDocumentSymbolProvider((d, token, resolve) -> {
            var l:Null<IDisposable> = null;
            l = token.onCancellationRequested(() -> {
                isCancelled = true;
                resolve(null);
                l.dispose();
            });
        }));

        assertEquals(false, isCancelled);
        final s1 = new CancellationTokenSource();
        service.getOrCreate(model, s1.token);
        final s2 = new CancellationTokenSource();
        service.getOrCreate(model, s2.token);

        s1.cancel();
        assertEquals(false, isCancelled);

        s2.cancel();
        assertEquals(true, isCancelled);

        reg.dispose();
        model.dispose();
        service.dispose();
        modelService.dispose();
    }

    static function fakeSymbolInformation(range:Range, name:String = 'foo'):DocumentSymbol {
        return {
            name: name,
            detail: 'fake',
            kind: cityscape.common.SymbolKind.Boolean,
            tags: [],
            selectionRange: range,
            range: range
        };
    }

    static function fakeMarker(range:Range):IOutlineMarker {
        final marker = new IMarker('ffff', null);
        marker.startLineNumber = range.startLineNumber;
        marker.startColumn = range.startColumn;
        marker.endLineNumber = range.endLineNumber;
        marker.endColumn = range.endColumn;
        marker.message = 'test';
        marker.severity = MarkerSeverity.Error;
        // Monaco passes the IMarker itself
        return {
            startLineNumber: marker.startLineNumber,
            startColumn: marker.startColumn,
            endLineNumber: marker.endLineNumber,
            endColumn: marker.endColumn,
            severity: marker.severity
        };
    }

    static function sortMarkers(data:Array<IOutlineMarker>):Void {
        haxe.ds.ArraySort.sort(data, (a, b) -> Range.compareRangesUsingStarts(a, b));
    }

    function testOutlineElementUpdateMarker() {

        final e0 = new OutlineElement('foo1', null, fakeSymbolInformation(new Range(1, 1, 1, 10)));
        final e1 = new OutlineElement('foo2', null, fakeSymbolInformation(new Range(2, 1, 5, 1)));
        final e2 = new OutlineElement('foo3', null, fakeSymbolInformation(new Range(6, 1, 10, 10)));

        final group = new OutlineGroup('group', null, null, 1);
        group.children.set(e0.id, e0);
        group.children.set(e1.id, e1);
        group.children.set(e2.id, e2);

        final data = [fakeMarker(new Range(6, 1, 6, 7)), fakeMarker(new Range(1, 1, 1, 4)), fakeMarker(new Range(10, 2, 14, 1))];
        sortMarkers(data); // model does this

        group.updateMarker(data);
        assertEquals(0, data.length); // all 'stolen'
        assertEquals(1, e0.marker.count);
        assertEquals(null, e1.marker);
        assertEquals(2, e2.marker.count);

        group.updateMarker([]);
        assertEquals(null, e0.marker);
        assertEquals(null, e1.marker);
        assertEquals(null, e2.marker);
    }

    function testOutlineElementUpdateMarker2() {

        final p = new OutlineElement('A', null, fakeSymbolInformation(new Range(1, 1, 11, 1)));
        final c1 = new OutlineElement('A/B', null, fakeSymbolInformation(new Range(2, 4, 5, 4)));
        final c2 = new OutlineElement('A/C', null, fakeSymbolInformation(new Range(6, 4, 9, 4)));

        final group = new OutlineGroup('group', null, null, 1);
        group.children.set(p.id, p);
        p.children.set(c1.id, c1);
        p.children.set(c2.id, c2);

        var data = [
            fakeMarker(new Range(2, 4, 5, 4))
        ];

        group.updateMarker(data);
        assertEquals(0, p.marker.count);
        assertEquals(1, c1.marker.count);
        assertEquals(null, c2.marker);

        data = [
            fakeMarker(new Range(2, 4, 5, 4)),
            fakeMarker(new Range(2, 6, 2, 8)),
            fakeMarker(new Range(7, 6, 7, 8)),
        ];
        group.updateMarker(data);
        assertEquals(0, p.marker.count);
        assertEquals(2, c1.marker.count);
        assertEquals(1, c2.marker.count);

        data = [
            fakeMarker(new Range(1, 4, 1, 11)),
            fakeMarker(new Range(7, 6, 7, 8)),
        ];
        group.updateMarker(data);
        assertEquals(1, p.marker.count);
        assertEquals(null, c1.marker);
        assertEquals(1, c2.marker.count);
    }

    function testOutlineElementUpdateMarkerMultipleGroups() {

        final model = new ReadyForTestingOutlineModel();
        function group(id:String):OutlineGroup {
            return cast model.children.get(id);
        }
        model.children.set('g1', new OutlineGroup('g1', model, null, 1));
        group('g1').children.set('c1', new OutlineElement('c1', group('g1'), fakeSymbolInformation(new Range(1, 1, 11, 1))));

        model.children.set('g2', new OutlineGroup('g2', model, null, 1));
        group('g2').children.set('c2', new OutlineElement('c2', group('g2'), fakeSymbolInformation(new Range(1, 1, 7, 1))));
        group('g2').children.get('c2').children.set('c2.1', new OutlineElement('c2.1', group('g2').children.get('c2'), fakeSymbolInformation(new Range(1, 3, 2, 19))));
        group('g2').children.get('c2').children.set('c2.2', new OutlineElement('c2.2', group('g2').children.get('c2'), fakeSymbolInformation(new Range(4, 1, 6, 10))));

        model.readyForTesting();

        final data = [
            fakeMarker(new Range(1, 1, 2, 8)),
            fakeMarker(new Range(6, 1, 6, 98)),
        ];

        model.updateMarker(data);

        assertEquals(2, group('g1').children.get('c1').marker.count);
        assertEquals(1, group('g2').children.get('c2').children.get('c2.1').marker.count);
        assertEquals(1, group('g2').children.get('c2').children.get('c2.2').marker.count);
    }

}
