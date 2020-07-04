package ceramic;

@:structInit
class FragmentContext {

    /** The assets registry used to load/unload assets in this fragment */
    public var assets:Assets;

    /** Whether the items are edited items or not */
    public var editedItems:Bool = false;

    /**
     * Parent fragment (if any)
     */
    public var parent:Fragment = null;

    function toString() {
        return '' + {
            assets: assets,
            editedItems: editedItems
        };
    }

}
