// Ported from vscode src/vs/platform/label/common/label.ts (`ILabelService`,
// the members the editor uses)
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.platform.label.common;

import cityscape.base.common.Uri;

/**
 * The options of `ILabelService.getUriLabel`.
 */
typedef UriLabelOptions = {
    @:optional var relative:Bool;
    @:optional var noPrefix:Bool;
}

/**
 * The labels of resources (Monaco's `ILabelService`, read by the file
 * variables of snippets). The context's is `Cityscape.labelService`
 * (Monaco's standalone one by default, `StandaloneUriLabelService`).
 */
interface ILabelService {

    /**
     * Gets the human readable label for a uri.
     */
    function getUriLabel(resource:Uri, ?options:UriLabelOptions):String;

    function getUriBasenameLabel(resource:Uri):String;

}
