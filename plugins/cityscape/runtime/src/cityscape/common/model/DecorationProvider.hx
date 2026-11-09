// Ported from vscode src/vs/editor/common/model/decorationProvider.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.model;

import cityscape.base.common.Event;
import cityscape.common.Model.IModelDecoration;
import cityscape.common.core.Range;

interface DecorationProvider {

    /**
     * Gets all the decorations in a range as an array. Only `startLineNumber` and `endLineNumber` from `range` are used for filtering.
     * So for now it returns all the decorations on the same line as `range`.
     * @param range The range to search in
     * @param ownerId If set, it will ignore decorations belonging to other owners.
     * @param filterOutValidation If set, it will ignore decorations specific to validation (i.e. warnings, errors).
     * @return An array with the decorations
     */
    function getDecorationsInRange(range:Range, ?ownerId:Int, ?filterOutValidation:Bool, ?onlyMinimapDecorations:Bool):Array<IModelDecoration>;

    /**
     * Gets all the decorations as an array.
     * @param ownerId If set, it will ignore decorations belonging to other owners.
     * @param filterOutValidation If set, it will ignore decorations specific to validation (i.e. warnings, errors).
     */
    function getAllDecorations(?ownerId:Int, ?filterOutValidation:Bool, ?onlyMinimapDecorations:Bool):Array<IModelDecoration>;

    var onDidChange(default, null):VoidEvent;

}
