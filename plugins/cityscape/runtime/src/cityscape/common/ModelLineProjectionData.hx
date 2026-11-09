// Ported from vscode src/vs/editor/common/modelLineProjectionData.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common;

import cityscape.common.Model.InjectedTextOptions;
import cityscape.common.TextModelEvents.LineInjectedText;

/**
 * Line break and injected text data of a model line.
 * TODO(step 2): placeholder, ported with the view model.
 */
class ModelLineProjectionData {}

class InjectedText {

    public final options:InjectedTextOptions;

    public function new(options:InjectedTextOptions) {
        this.options = options;
    }

}

interface ILineBreaksComputer {
    /**
     * Pass in `previousLineBreakData` if the only difference is in breaking columns!!!
     */
    function addRequest(lineText:String, injectedText:Null<Array<LineInjectedText>>, previousLineBreakData:Null<ModelLineProjectionData>):Void;
    function finalize():Array<Null<ModelLineProjectionData>>;
}
