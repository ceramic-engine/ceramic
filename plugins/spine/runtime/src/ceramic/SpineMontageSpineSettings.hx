package ceramic;

@:structInit
class SpineMontageSpineSettings {

    /**
     * A `Spine` instance to use with this montage. `data` is ignored is `instance` is provided.
     */
    public var instance:Null<Spine> = null;

    /**
     * A `SpineData` object used to create a new `Spine` instance. Ignored is `instance` is provided.
     */
    public var data:Null<SpineData> = null;

    /**
     * If set to `true` (default), the provided or created spine instance will be bound to montage lifecycle,
     * meaning destroying montage instance will destroy spine instance and vice versa.
     */
    public var bound:Bool = true;

    /**
     * The skeleton scale of the spine object (sets its `skeletonScale` property).
     */
    public var scale:Float = 1.0;

    /**
     * The spine object depth (default: `0`).
     */
    public var depth:Float = 0.0;

    /**
     * The spine object depthRange (default: `1`).
     */
    public var depthRange:Float = 1.0;

}
