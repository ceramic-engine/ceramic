// Ported from vscode src/vs/platform/markers/test/common/markerService.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.platform.markers;

import cityscape.base.common.Uri;
import cityscape.platform.markers.common.MarkerService;
import cityscape.platform.markers.common.Markers;
import testing.TestCase;

class MarkerServiceTest extends TestCase {

    static function randomMarkerData(severity:MarkerSeverity = MarkerSeverity.Error):IMarkerData {
        return {
            severity: severity,
            message: StringTools.hex(Std.random(0x7FFFFFFF)),
            startLineNumber: 1,
            startColumn: 1,
            endLineNumber: 1,
            endColumn: 1
        };
    }

    var service:Null<MarkerService> = null;

    override public function teardown():Void {
        if (service != null) {
            service.dispose();
            service = null;
        }
    }

    function testQuery() {

        service = new MarkerService();

        service.changeAll('far', [{
            resource: Uri.parse('file:///c/test/file.cs'),
            marker: randomMarkerData(MarkerSeverity.Error)
        }]);

        assertEquals(1, service.read().length);
        assertEquals(1, service.read({owner: 'far'}).length);
        assertEquals(1, service.read({resource: Uri.parse('file:///c/test/file.cs')}).length);
        assertEquals(1, service.read({owner: 'far', resource: Uri.parse('file:///c/test/file.cs')}).length);

        service.changeAll('boo', [{
            resource: Uri.parse('file:///c/test/file.cs'),
            marker: randomMarkerData(MarkerSeverity.Warning)
        }]);

        assertEquals(2, service.read().length);
        assertEquals(1, service.read({owner: 'far'}).length);
        assertEquals(1, service.read({owner: 'boo'}).length);

        assertEquals(1, service.read({severities: MarkerSeverity.Error}).length);
        assertEquals(1, service.read({severities: MarkerSeverity.Warning}).length);
        assertEquals(0, service.read({severities: MarkerSeverity.Hint}).length);
        assertEquals(2, service.read({severities: (MarkerSeverity.Error : Int) | (MarkerSeverity.Warning : Int)}).length);
    }

    function testChangeOneOverride() {

        service = new MarkerService();
        service.changeOne('far', Uri.parse('file:///path/only.cs'), [randomMarkerData()]);
        assertEquals(1, service.read().length);
        assertEquals(1, service.read({owner: 'far'}).length);

        service.changeOne('boo', Uri.parse('file:///path/only.cs'), [randomMarkerData()]);
        assertEquals(2, service.read().length);
        assertEquals(1, service.read({owner: 'far'}).length);
        assertEquals(1, service.read({owner: 'boo'}).length);

        service.changeOne('far', Uri.parse('file:///path/only.cs'), [randomMarkerData(), randomMarkerData()]);
        assertEquals(2, service.read({owner: 'far'}).length);
        assertEquals(1, service.read({owner: 'boo'}).length);
    }

    function testChangeOneAllClears() {

        service = new MarkerService();
        service.changeOne('far', Uri.parse('file:///path/only.cs'), [randomMarkerData()]);
        service.changeOne('boo', Uri.parse('file:///path/only.cs'), [randomMarkerData()]);
        assertEquals(1, service.read({owner: 'far'}).length);
        assertEquals(1, service.read({owner: 'boo'}).length);
        assertEquals(2, service.read().length);

        service.changeOne('far', Uri.parse('file:///path/only.cs'), []);
        assertEquals(0, service.read({owner: 'far'}).length);
        assertEquals(1, service.read({owner: 'boo'}).length);
        assertEquals(1, service.read().length);

        service.changeAll('boo', []);
        assertEquals(0, service.read({owner: 'far'}).length);
        assertEquals(0, service.read({owner: 'boo'}).length);
        assertEquals(0, service.read().length);
    }

    function testChangeAllSendsEventForCleared() {

        service = new MarkerService();
        service.changeAll('far', [{
            resource: Uri.parse('file:///d/path'),
            marker: randomMarkerData()
        }, {
            resource: Uri.parse('file:///d/path'),
            marker: randomMarkerData()
        }]);

        assertEquals(2, service.read({owner: 'far'}).length);

        var fired = 0;
        final d = service.onMarkerChanged(changedResources -> {
            fired++;
            assertEquals(1, changedResources.length);
            for (u in changedResources) {
                assertEquals('file:///d/path', u.toString());
            }
            assertEquals(0, service.read({owner: 'far'}).length);
        });

        service.changeAll('far', []);

        d.dispose();
        // The listener runs synchronously here (Monaco debounces the event).
        assertEquals(1, fired);
    }

    function testChangeAllMerges() {
        service = new MarkerService();

        service.changeAll('far', [{
            resource: Uri.parse('file:///c/test/file.cs'),
            marker: randomMarkerData()
        }, {
            resource: Uri.parse('file:///c/test/file.cs'),
            marker: randomMarkerData()
        }]);

        assertEquals(2, service.read({owner: 'far'}).length);
    }

    function testChangeAllMustNotBreakIntegrityIssue12635() {
        service = new MarkerService();

        service.changeAll('far', [{
            resource: Uri.parse('scheme:path1'),
            marker: randomMarkerData()
        }, {
            resource: Uri.parse('scheme:path2'),
            marker: randomMarkerData()
        }]);

        service.changeAll('boo', [{
            resource: Uri.parse('scheme:path1'),
            marker: randomMarkerData()
        }]);

        service.changeAll('far', [{
            resource: Uri.parse('scheme:path1'),
            marker: randomMarkerData()
        }, {
            resource: Uri.parse('scheme:path2'),
            marker: randomMarkerData()
        }]);

        assertEquals(2, service.read({owner: 'far'}).length);
        assertEquals(2, service.read({resource: Uri.parse('scheme:path1')}).length);
    }

    function testInvalidMarkerData() {

        final data = randomMarkerData();
        service = new MarkerService();

        data.message = null;
        service.changeOne('far', Uri.parse('some:uri/path'), [data]);
        assertEquals(0, service.read({owner: 'far'}).length);

        data.message = 'null';
        service.changeOne('far', Uri.parse('some:uri/path'), [data]);
        assertEquals(1, service.read({owner: 'far'}).length);
    }

    function testMapMapRemoveReturnsBadValuesIssue13548() {
        service = new MarkerService();

        service.changeOne('o', Uri.parse('some:uri/1'), [randomMarkerData()]);
        service.changeOne('o', Uri.parse('some:uri/2'), []);
        assertTrue(true);
    }

    function testErrorCodeOfZeroInMarkersGetRemovedIssue31275() {
        final data:IMarkerData = {
            code: '0',
            startLineNumber: 1,
            startColumn: 2,
            endLineNumber: 1,
            endColumn: 5,
            message: 'test',
            severity: cast 0,
            source: 'me'
        };
        service = new MarkerService();

        service.changeOne('far', Uri.parse('some:thing'), [data]);
        final marker = service.read({resource: Uri.parse('some:thing')});

        assertEquals(1, marker.length);
        assertEquals('0', (marker[0].code : String));
    }

}
