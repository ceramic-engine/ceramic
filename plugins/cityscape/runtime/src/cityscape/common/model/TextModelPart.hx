// Ported from vscode src/vs/editor/common/model/textModelPart.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.model;

import cityscape.base.common.Lifecycle.Disposable;

class TextModelPart extends Disposable {

    var _isDisposed:Bool = false;

    public function new() {
        super();
    }

    override public function dispose():Void {
        super.dispose();
        this._isDisposed = true;
    }

    function assertNotDisposed():Void {
        if (this._isDisposed) {
            throw 'TextModelPart is disposed!';
        }
    }

}
