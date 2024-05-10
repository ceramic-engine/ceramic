package ceramic;

import ceramic.Shortcuts.*;

// Warning: this is just a draft, don't use it!

/**
 * A container used to display a visual that
 * can be zoomed and dragged.
 */
class Zoomer extends Visual {

/// Public properties

    public var content(default,null):Visual = null;

    public var zoomTransform(default,null):Transform = new Transform();

    public var minScale:Float = 1.0;

    public var maxScale:Float = 4.0;

/// Internal

    @component var pinch:Pinch;

    @component var doubleClick:DoubleClick;

    var pinchStartTranslateX:Float = 0;

    var pinchStartTranslateY:Float = 0;

    var pinchStartScale:Float = 1;

    var pinching:Bool = false;

    var dragging:Bool = false;

    var couldDrag:Bool = false;

    var currentTranslateX:Float = 0;

    var currentTranslateY:Float = 0;

    var currentScale:Float = 1;

/// Lifecycle

    public function new(?content:Visual) {

        super();

        if (content == null) {
            content = new Visual();
        }
        this.content = content;
        content.anchor(0, 0);
        content.pos(0, 0);
        content.transform = zoomTransform;
        content.depth = 1;
        add(content);

        onPointerDown(this, handlePointerDown);
        screen.onPointerMove(this, handlePointerMove);
        onPointerUp(this, handlePointerUp);

        pinch = new Pinch();
        pinch.onBeginPinch(this, handleBeginPinch);
        pinch.onPinch(this, handlePinch);
        pinch.onEndPinch(this, handleEndPinch);

        doubleClick = new DoubleClick();
        doubleClick.onDoubleClick(this, handleDoubleClick);

    }

    function handlePointerDown(info:TouchInfo) {

        // TODO

    }

    function handlePointerMove(info:TouchInfo) {

        // TODO

    }

    function handlePointerUp(info:TouchInfo) {

        // TODO

    }

    function handleBeginPinch(originX:Float, originY:Float) {

        if (dragging) {
            return;
        }

        pinching = true;
        couldDrag = false;

        pinchStartTranslateX = currentTranslateX;
        pinchStartTranslateY = currentTranslateY;
        pinchStartScale = currentScale;

    }

    function handlePinch(originX:Float, originY:Float, scale:Float, translateX:Float, translateY:Float, rotation:Float) {

        if (!pinching) {
            return;
        }

        // TODO relative to visual?

        currentScale = Math.min(
            maxScale,
            Math.max(
                minScale,
                pinchStartScale * scale
            )
        );

        if (scale < 1.0 && pinchStartScale > 1.0) {
            var scaleRatio = (currentScale - 1.0) / (pinchStartScale - 1.0);
            currentTranslateX = Utils.lerp(0, pinchStartTranslateX + translateX, scaleRatio);
            currentTranslateY = Utils.lerp(0, pinchStartTranslateY + translateY, scaleRatio);
        }
        else {
            currentTranslateX = pinchStartTranslateX + translateX;
            currentTranslateY = pinchStartTranslateY + translateY;
        }

        zoomTransform.identity();
        zoomTransform.scale(currentScale, currentScale);
        zoomTransform.translate(currentTranslateX, currentTranslateY);

    }

    function handleEndPinch() {

        if (!pinching) {
            return;
        }
        pinching = false;

        // TODO animate end

    }

    function handleDoubleClick() {

        pinching = false;
        couldDrag = false;
        dragging = false;

    }

}
