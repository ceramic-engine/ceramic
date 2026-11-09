// Ported from vscode src/vs/editor/common/config/editorConfiguration.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.config;

import cityscape.base.common.Event;
import cityscape.common.config.EditorOptions;
import cityscape.common.core.Dimension.IDimension;

/**
 * The configuration of an editor: its options, validated and computed with
 * its environment. Monaco's `contextMenuId` (a `MenuId` of the platform
 * menus) is not ported: menus are the Glaze kit's.
 */
interface IEditorConfiguration {
    /**
     * Is this a simple widget (not a real code editor)?
     */
    final isSimpleWidget:Bool;
    /**
     * Computed editor options.
     */
    var options(default, null):IComputedEditorOptions;
    /**
     * The `options` have changed (quick event)
     */
    final onDidChangeFast:Event<ConfigurationChangedEvent>;
    /**
     * The `options` have changed (slow event)
     */
    final onDidChange:Event<ConfigurationChangedEvent>;
    /**
     * Get the raw options as they were passed in to the editor
     * and merged with all calls to `updateOptions`.
     */
    function getRawOptions():IEditorOptions;
    /**
     * Update the options with new partial options. All previous
     * options will be kept and only present keys will be overwritten.
     */
    function updateOptions(newOptions:IEditorOptions):Void;
    /**
     * Recompute options with new reference element dimensions.
     */
    function observeContainer(?dimension:IDimension):Void;
    /**
     * Set if the current model is dominated by long lines.
     */
    function setIsDominatedByLongLines(isDominatedByLongLines:Bool):Void;
    /**
     * Set the current model line count.
     */
    function setModelLineCount(modelLineCount:Int):Void;
    /**
     * Set the current view model line count.
     */
    function setViewLineCount(viewLineCount:Int):Void;
    /**
     * Set reserved height above.
     */
    function setReservedHeight(reservedHeight:Float):Void;
    /**
     * Set the number of decoration lanes to be rendered in the glyph margin.
     */
    function setGlyphMarginDecorationLaneCount(decorationLaneCount:Int):Void;

    function dispose():Void;
}
