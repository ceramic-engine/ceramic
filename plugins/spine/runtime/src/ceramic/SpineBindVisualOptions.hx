package ceramic;

import ceramic.Spine.SlotInfo;

@:allow(ceramic.SpineBindVisual)
class SpineBindVisualOptions {

    /// Public options

    /** Whether the original slot attachment is displayed */
    public var drawDefault:Bool = false;

    /** Offset x position of target visual */
    public var offsetX:Float = 0.0;

    /** Offset y position of target visual */
    public var offsetY:Float = 0.0;

    /** Whether we apply slot transform on the target visual */
    public var bindTransform:Bool = true;

    /** Whether we apply slot color on the target visual */
    public var bindColor:Bool = true;

    /** Whether we apply slot alpha on the target visual */
    public var bindAlpha:Bool = true;

    /** Whether we apply slot depth on the target visual */
    public var bindDepth:Bool = true;

    /** Whether we apply slot blending on the target visual */
    public var bindBlending:Bool = true;

    /** Whether to compensate region attachment rotation on the target visual */
    public var compensateRegionRotation:Bool = false;

    /** When enabled (default), if the bound slot is not active,
        set the visual `active` property to `false`, set it to `true` otherwise. */
    public var manageActiveProperty:Bool = true;

    /** If set to `true` and if the target visual exists but is not visible, no transform, color or alpha will be applied. */
    public var skipIfInvisible:Bool = true;

    /** If set to `true` transform assigned to visual will be set to `identity` on unbind. */
    public var resetTransformOnUnbind:Bool = true;

    /// Managed internally
    public var slotName(default, null):String = null;

    public var spine(default, null):Spine = null;

    public var spineData(default, null):SpineData = null;

    public var visual(default, null):Visual = null;

    public var textVisual(default, null):Text = null;

    var handleUpdateSlot:SlotInfo->Void = null;

    public function new() {}

    public function unbind():Void {

        if (spine != null && !spine.destroyed) {
            if (handleUpdateSlot != null) {
                spine.offUpdateSlotWithName(slotName, handleUpdateSlot);
                spine.offBeginRender(handleBeginRender);
                spine.offEndRender(handleEndRender);
                handleUpdateSlot = null;
                if (resetTransformOnUnbind && visual != null && visual.transform != null) {
                    visual.transform.identity();
                }
            }
        }

    }

    /// Internal

    var didUpdateSlot:Bool = false;

    function handleBeginRender():Void {

        didUpdateSlot = false;

    }

    function handleEndRender():Void {

        if (!didUpdateSlot && manageActiveProperty) {
            visual.active = false;
        }

    }

}
