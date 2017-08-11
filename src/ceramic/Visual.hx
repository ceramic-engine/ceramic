package ceramic;

import backend.Draw.VisualItem;
import ceramic.Point;
import ceramic.Shortcuts.*;

@:allow(ceramic.App)
@:allow(ceramic.Screen)
class Visual extends Entity {

/// Events

    @event function down(info:TouchInfo);
    @event function up(info:TouchInfo);
    @event function over(info:TouchInfo);
    @event function out(info:TouchInfo);

/// Properties

    /** When enabled, this visual will receive as many up/down/click/over/out events as
        there are fingers or mouse pointer interacting with it.
        Default is `false`, ensuring there is never multiple up/down/click/over/out that
        overlap each other. In that case, it triggers `down` when the first finger/pointer hits
        the visual and trigger `up` when the last finger/pointer stops touching it. Behavior is
        similar for `over` and `out` events. */
    public var multiTouch:Bool = false;

    /** Whether this visual is between a `down` and an `up` event or not. */
    public var isDown(get,null):Bool;
    var _numDown:Int = 0;
    inline function get_isDown():Bool { return _numDown > 0; }

    /** Whether this visual is between a `over` and an `out` event or not. */
    public var isOver(get,null):Bool;
    var _numOver:Int = 0;
    inline function get_isOver():Bool { return _numOver > 0; }

    /** Allows the backend to keep data associated with this visual. */
    public var backendItem:VisualItem;

    /** Setting this to true will force the visual to recompute its displayed content */
    public var contentDirty:Bool = true;

    /** Setting this to true will force the visual's matrix to be re-computed */
    public var matrixDirty(default,set):Bool = true;
    inline function set_matrixDirty(matrixDirty:Bool):Bool {
        if (!this.matrixDirty && matrixDirty) {
            this.matrixDirty = true;
            if (children != null) {
                for (child in children) {
                    child.matrixDirty = true;
                }
            }
        }
        return matrixDirty;
    }

    /** Setting this to true will force the visual to compute it's visility in hierarchy */
    public var visibilityDirty:Bool = true;

    /** If set, children will be sort by depth and their computed depth
        will be within range [parent.depth, parent.depth + childrenDepthRange] */
    public var childrenDepthRange:Float = -1;

    public var blending(default,set):Blending = Blending.NORMAL;
    function set_blending(blending:Blending):Blending {
        return this.blending = blending;
    }

    public var visible(default,set):Bool = true;
    function set_visible(visible:Bool):Bool {
        if (this.visible == visible) return visible;
        this.visible = visible;
        visibilityDirty = true;
        return visible;
    }

    public var alpha(default,set):Float = 1;
    function set_alpha(alpha:Float):Float {
        if (this.alpha == alpha) return alpha;
        this.alpha = alpha;
        visibilityDirty = true;
        return alpha;
    }

    public var x(default,set):Float = 0;
    function set_x(x:Float):Float {
        if (this.x == x) return x;
        this.x = x;
        matrixDirty = true;
        return x;
    }

    public var y(default,set):Float = 0;
    function set_y(y:Float):Float {
        if (this.y == y) return y;
        this.y = y;
        matrixDirty = true;
        return y;
    }

    public var depth(default,set):Float = 0;
    function set_depth(depth:Float):Float {
        if (this.depth == depth) return depth;
        this.depth = depth;
        app.hierarchyDirty = true;
        return depth;
    }

    public var rotation(default,set):Float = 0;
    function set_rotation(rotation:Float):Float {
        if (this.rotation == rotation) return rotation;
        this.rotation = rotation;
        matrixDirty = true;
        return rotation;
    }

    public var scaleX(default,set):Float = 1;
    function set_scaleX(scaleX:Float):Float {
        if (this.scaleX == scaleX) return scaleX;
        this.scaleX = scaleX;
        matrixDirty = true;
        return scaleX;
    }

    public var scaleY(default,set):Float = 1;
    function set_scaleY(scaleY:Float):Float {
        if (this.scaleY == scaleY) return scaleY;
        this.scaleY = scaleY;
        matrixDirty = true;
        return scaleY;
    }

    public var skewX(default,set):Float = 0;
    function set_skewX(skewX:Float):Float {
        if (this.skewX == skewX) return skewX;
        this.skewX = skewX;
        matrixDirty = true;
        return skewX;
    }

    public var skewY(default,set):Float = 0;
    function set_skewY(skewY:Float):Float {
        if (this.skewY == skewY) return skewY;
        this.skewY = skewY;
        matrixDirty = true;
        return skewY;
    }

    public var anchorX(default,set):Float = 0;
    function set_anchorX(anchorX:Float):Float {
        if (this.anchorX == anchorX) return anchorX;
        this.anchorX = anchorX;
        matrixDirty = true;
        return anchorX;
    }

    public var anchorY(default,set):Float = 0;
    function set_anchorY(anchorY:Float):Float {
        if (this.anchorY == anchorY) return anchorY;
        this.anchorY = anchorY;
        matrixDirty = true;
        return anchorY;
    }

    var _width:Float = 0;
    public var width(get,set):Float;
    function get_width():Float {
        return _width;
    }
    function set_width(width:Float):Float {
        if (_width == width) return width;
        _width = width;
        matrixDirty = true;
        return width;
    }

    var _height:Float = 0;
    public var height(get,set):Float;
    function get_height():Float {
        return _height;
    }
    function set_height(height:Float):Float {
        if (_height == height) return height;
        _height = height;
        matrixDirty = true;
        return height;
    }

    /** Set additional matrix-based transform to this visual. Default is null. */
    public var transform(default,set):Transform = null;
    function set_transform(transform:Transform):Transform {
        if (this.transform == transform) return transform;

        if (this.transform != null) {
            this.transform.offChange(transformDidChange);
        }

        this.transform = transform;

        if (this.transform != null) {
            this.transform.onChange(this, transformDidChange);
        }

        return transform;
    }

/// Properties (Matrix)

    public var a:Float = 1;

    public var b:Float = 0;

    public var c:Float = 0;

    public var d:Float = 1;

    public var tx:Float = 0;

    public var ty:Float = 0;

/// Properties (Computed)

    public var computedVisible:Bool = true;

    public var computedAlpha:Float = 1;

    public var computedDepth:Float = 0;

/// Properties (Events)

    public var touchable:Bool = true;

/// Properties (Children)

    public var children(default,null):Array<Visual> = null;

    public var parent(default,null):Visual = null;

/// Internal

    static var _matrix:Transform = new Transform();

    static var _degToRad:Float = Math.PI / 180.0;

    static var _point:Point = new Point();

/// Helpers

    inline public function size(width:Float, height:Float):Void {

        this.width = width;
        this.height = height;

    } //size

    inline public function anchor(anchorX:Float, anchorY:Float):Void {

        this.anchorX = anchorX;
        this.anchorY = anchorY;

    } //anchor

    inline public function pos(x:Float, y:Float):Void {

        this.x = x;
        this.y = y;

    } //pos

    inline public function scale(scaleX:Float, scaleY:Float = -1):Void {

        this.scaleX = scaleX;
        this.scaleY = scaleY != -1 ? scaleY : scaleX;

    } //scale

    inline public function skew(skewX:Float, skewY:Float):Void {

        this.skewX = skewX;
        this.skewY = skewY;

    } //skew

/// Advanced helpers

    /** Change the visual's anchor but update its x and y values to make
        it keep its current position. */
    public function anchorKeepPosition(anchorX:Float, anchorY:Float):Void {

        if (this.anchorX == anchorX && this.anchorY == anchorY) return;

        // Get initial pos
        visualToScreen(0, 0, _point);
        if (parent != null) {
            parent.screenToVisual(_point.x, _point.y, _point);
        }
        
        var prevX = _point.x;
        var prevY = _point.y;
        this.anchorX = anchorX;
        this.anchorY = anchorY;

        // Get new pos
        this.visualToScreen(0, 0, _point);
        if (parent != null) {
            parent.screenToVisual(_point.x, _point.y, _point);
        }

        // Move visual accordingly
        this.x += prevX - _point.x;
        this.y += prevY - _point.y;

    } //anchor

/// Lifecycle

    public function new() {

        app.visuals.push(this);
        app.hierarchyDirty = true;

        backendItem = app.backend.draw.getItem(this);

    } //new

    public function destroy() {
        
        app.visuals.remove(this);

        if (transform != null) transform = null;

        clear();

    } //destroy

    public function clear() {

        if (children != null) {
            for (child in children) {
                child.destroy();
            }
            children = null;
        }

    } //clear

/// Matrix

    function transformDidChange() {

        matrixDirty = true;

    } //transformDidChange

    function computeMatrix() {

        if (parent != null && parent.matrixDirty) {
            parent.computeMatrix();
        }

        _matrix.identity();

        doComputeMatrix();

    } //computeMatrix

    inline function doComputeMatrix() {

        var w = width;
        var h = height;

        // Apply local properties (pos, scale, rotation, skew)
        //
        _matrix.translate(-anchorX * w, -anchorY * h);

        if (skewX != 0 || skewY != 0) {
            _matrix.skew(skewX * _degToRad, skewY * _degToRad);
        }

        if (rotation != 0) _matrix.rotate(rotation * _degToRad);
        _matrix.translate(anchorX * w, anchorY * h);
        if (scaleX != 1.0 || scaleY != 1.0) _matrix.scale(scaleX, scaleY);
        _matrix.translate(
            x - (anchorX * w * scaleX),
            y - (anchorY * h * scaleY)
        );

        if (transform != null) {

            // Concat matrix with transform
            //
            var a1 = _matrix.a * transform.a + _matrix.b * transform.c;
            _matrix.b = _matrix.a * transform.b + _matrix.b * transform.d;
            _matrix.a = a1;

            var c1 = _matrix.c * transform.a + _matrix.d * transform.c;
            _matrix.d = _matrix.c * transform.b + _matrix.d * transform.d;

            _matrix.c = c1;

            var tx1 = _matrix.tx * transform.a + _matrix.ty * transform.c + transform.tx;
            _matrix.ty = _matrix.tx * transform.b + _matrix.ty * transform.d + transform.ty;
            _matrix.tx = tx1;

        }

        if (parent != null) {

            // Concat matrix with parent's computed matrix data
            //
            var a1 = _matrix.a * parent.a + _matrix.b * parent.c;
            _matrix.b = _matrix.a * parent.b + _matrix.b * parent.d;
            _matrix.a = a1;

            var c1 = _matrix.c * parent.a + _matrix.d * parent.c;
            _matrix.d = _matrix.c * parent.b + _matrix.d * parent.d;

            _matrix.c = c1;

            var tx1 = _matrix.tx * parent.a + _matrix.ty * parent.c + parent.tx;
            _matrix.ty = _matrix.tx * parent.b + _matrix.ty * parent.d + parent.ty;
            _matrix.tx = tx1;

        } else {

            // Concat matrix with screen transform
            //
            var m = screen.matrix;
            
            var a1 = _matrix.a * m.a + _matrix.b * m.c;
            _matrix.b = _matrix.a * m.b + _matrix.b * m.d;
            _matrix.a = a1;

            var c1 = _matrix.c * m.a + _matrix.d * m.c;
            _matrix.d = _matrix.c * m.b + _matrix.d * m.d;

            _matrix.c = c1;

            var tx1 = _matrix.tx * m.a + _matrix.ty * m.c + m.tx;
            _matrix.ty = _matrix.tx * m.b + _matrix.ty * m.d + m.ty;
            _matrix.tx = tx1;

        }

        // Assign final matrix values to visual
        //
        a = _matrix.a;
        b = _matrix.b;
        c = _matrix.c;
        d = _matrix.d;
        tx = _matrix.tx;
        ty = _matrix.ty;

        // Matrix is up to date
        matrixDirty = false;

    }

/// Hit test

    /** Returns true if (testX,testY) screen coordinates hit/intersect this visual visible bounds */
    public function hits(x:Float, y:Float):Bool {

        if (matrixDirty) {
            computeMatrix();
        }

        _matrix.identity();
        // Apply whole visual transform
        _matrix.setTo(a, b, c, d, tx, ty);
        // But remove screen transform from it
        _matrix.concat(screen.reverseMatrix);
        _matrix.invert();

        var testX0 = _matrix.transformX(x, y);
        var testY0 = _matrix.transformY(x, y);
        var testX1 = _matrix.transformX(x - 1, y - 1);
        var testY1 = _matrix.transformY(x - 1, y - 1);

        return testX0 >= 0
            && testX1 <= width
            && testY0 >= 0
            && testY1 <= height;

    } //hits

/// Screen to visual positions and vice versa

    /** Assign X and Y to given point after converting them from screen coordinates to current visual coordinates. */
    public function screenToVisual(x:Float, y:Float, point:Point):Void {

        if (matrixDirty) {
            computeMatrix();
        }

        _matrix.identity();
        // Apply whole visual transform
        _matrix.setTo(a, b, c, d, tx, ty);
        // But remove screen transform from it
        _matrix.concat(screen.reverseMatrix);
        _matrix.invert();

        point.x = _matrix.transformX(x, y);
        point.y = _matrix.transformY(x, y);

    } //screenToVisual

    /** Assign X and Y to given point after converting them from current visual coordinates to screen coordinates. */
    public function visualToScreen(x:Float, y:Float, point:Point):Void {

        if (matrixDirty) {
            computeMatrix();
        }

        _matrix.identity();
        // Apply whole visual transform
        _matrix.setTo(a, b, c, d, tx, ty);
        // But remove screen transform from it
        _matrix.concat(screen.reverseMatrix);

        point.x = _matrix.transformX(x, y);
        point.y = _matrix.transformY(x, y);

    } //visualToScreen

/// Transform from visual

    /** Assign X and Y to given point after converting them from current visual coordinates to screen coordinates. */
    public function visualToTransform(transform:Transform):Void {

        if (matrixDirty) {
            computeMatrix();
        }

        transform.identity();
        // Apply whole visual transform
        transform.setTo(a, b, c, d, tx, ty);
        // But remove screen transform from it
        transform.concat(screen.reverseMatrix);

    } //visualToTransform

/// Visibility / Alpha

    function computeVisibility() {

        if (parent != null && parent.visibilityDirty) {
            parent.computeVisibility();
        }

        computedVisible = visible;
        computedAlpha = alpha;
        
        if (computedVisible) {

            if (parent != null) {
                if (!parent.computedVisible) {
                    computedVisible = false;
                }
                computedAlpha *= parent.computedAlpha;
            }

            if (computedAlpha == 0) {
                computedVisible = false;
            }
            
        }

        visibilityDirty = false;

    } //computeVisibility

/// Display

    function computeContent() {
        
        contentDirty = false;

    } //computeContent

/// Children

    /** Compute children depth. The result depends on whether
        a parent defines a custom `childrenDepthRange` value or not. */
    function computeChildrenDepth(depthRange:Float = -1) {

        if (children != null && children.length > 0) {

            var minDepth = 999999999.0;
            var maxDepth = -1.0;

            for (child in children) {

                child.computedDepth = child.depth;

                if (child.depth < minDepth) minDepth = child.depth;
                if (child.depth > maxDepth) maxDepth = child.depth;

            }

            var multDepth:Float = -1;

            if (childrenDepthRange != -1) {

                multDepth = childrenDepthRange / (maxDepth - minDepth);

            }

            if (depthRange != -1) {

                if (multDepth == -1) multDepth = 1;

                multDepth *= depthRange / (maxDepth - minDepth);

            }

            if (multDepth != -1) {

                for (child in children) {

                    child.computedDepth = computedDepth + (child.computedDepth - minDepth ) * multDepth;
                    
                    if (child.children != null) {
                        child.computeChildrenDepth((maxDepth - child.depth) * multDepth);
                    }
                }

            } else {

                for (child in children) {
                    
                    if (child.children != null) {
                        child.computeChildrenDepth();
                    }
                }
            }
        }

    } //computeChildrenDepth

    public function add(visual:Visual):Void {

        App.app.hierarchyDirty = true;

        if (visual.parent != null) {
            visual.parent.remove(visual);
        }

        visual.parent = this;
        if (children == null) {
            children = [];
        }
        children.push(visual);

    } //add

    public function remove(visual:Visual):Void {

        App.app.hierarchyDirty = true;

        if (children == null) return;

        children.splice(children.indexOf(visual), 1);
        visual.parent = null;

    } //remove

} //Visual
