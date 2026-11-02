package gpui;

/**
 * A text input painted in a frame, focused or not: its visible bounds
 * (window coordinates, clipped to the content mask) and its input handler.
 * Port addition, see `Window.textInputRegionAt`.
 */
class TextInputRegion {

    public final bounds:Bounds;

    public final handler:InputHandler;

    public function new(bounds:Bounds, handler:InputHandler) {
        this.bounds = bounds;
        this.handler = handler;
    }

}
