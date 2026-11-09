// Ported from vscode src/vs/editor/contrib/gotoSymbol/test/browser/referencesModel.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.contrib.gotoSymbol;

import cityscape.base.common.Uri;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.contrib.gotoSymbol.view.ReferencesModel;
import testing.TestCase;

/**
 * suite('references').
 */
class ReferencesModelTest extends TestCase {

    function testNearestReference() {
        final model = new ReferencesModel([{
            uri: Uri.file('/out/obj/can'),
            range: new Range(1, 1, 1, 1)
        }, {
            uri: Uri.file('/out/obj/can2'),
            range: new Range(1, 1, 1, 1)
        }, {
            uri: Uri.file('/src/can'),
            range: new Range(1, 1, 1, 1)
        }], 'FOO');

        var ref = model.nearestReference(Uri.file('/src/can'), new Position(1, 1));
        assertEquals('/src/can', ref.uri.path);

        ref = model.nearestReference(Uri.file('/src/someOtherFileInSrc'), new Position(1, 1));
        assertEquals('/src/can', ref.uri.path);

        ref = model.nearestReference(Uri.file('/out/someOtherFile'), new Position(1, 1));
        assertEquals('/out/obj/can', ref.uri.path);

        ref = model.nearestReference(Uri.file('/out/obj/can2222'), new Position(1, 1));
        assertEquals('/out/obj/can2', ref.uri.path);
        model.dispose();
    }

}
