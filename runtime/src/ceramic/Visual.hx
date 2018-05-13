package ceramic;

#if ceramic_luxe_legacy
import backend.VisualItem;
#end

import ceramic.Point;

@:allow(ceramic.App)
@:allow(ceramic.Screen)
class Visual extends Entity {

/// Events

    @event function pointerDown(info:TouchInfo);
    @event function pointerUp(info:TouchInfo);
    @event function pointerOver(info:TouchInfo);
    @event function pointerOut(info:TouchInfo);

    @event function focus();
    @event function blur();

/// Access as specific types

    /** Get this visual typed as `Quad` or null if it isn't a `Quad` */
    public var quad:Quad = null;

    /** Get this visual typed as `Mesh` or null if it isn't a `Mesh` */
    public var mesh:Mesh = null;

/// Properties

    /** When enabled, this visual will receive as many up/down/click/over/out events as
        there are fingers or mouse pointer interacting with it.
        Default is `false`, ensuring there is never multiple up/down/click/over/out that
        overlap each other. In that case, it triggers `pointer down` when the first finger/pointer hits
        the visual and trigger `pointer up` when the last finger/pointer stops touching it. Behavior is
        similar for `pointer over` and `pointer out` events. */
    public var multiTouch:Bool = false;

    /** Whether this visual is between a `pointer down` and an `pointer up` event or not. */
    public var isPointerDown(get,null):Bool;
    var _numPointerDown:Int = 0;
    inline function get_isPointerDown():Bool { return _numPointerDown > 0; }

    /** Whether this visual is between a `pointer over` and an `pointer out` event or not. */
    public var isPointerOver(get,null):Bool;
    var _numPointerOver:Int = 0;
    inline function get_isPointerOver():Bool { return _numPointerOver > 0; }

    /** Use the given visual's bounds as clipping area. */
    public var clip(default,set):Visual = null;
    inline function set_clip(clip:Visual):Visual {
        if (this.clip == clip) return clip;
        this.clip = clip;
        clipDirty = true;
        return clip;
    }

    /** Whether this visual should inherit its parent alpha state or not. **/
    public var inheritAlpha(default,set):Bool = false;
    inline function set_inheritAlpha(inheritAlpha:Bool):Bool {
        if (this.inheritAlpha == inheritAlpha) return inheritAlpha;
        this.inheritAlpha = inheritAlpha;
        visibilityDirty = true;
        return inheritAlpha;
    }

#if ceramic_luxe_legacy

    /** Allows the backend to keep data associated with this visual. */
    public var backendItem:VisualItem;

#end

    /** Computed flag that tells whether this visual is only translated,
        thus not rotated, skewed nor scaled.
        When this is `true`, matrix computation may be a bit faster as it
        will skip some unneeded matrix computation. */
    public var translatesOnly:Bool = true;

    /** Whether we should re-check if this visual is only translating or having a more complex transform */
    public var translatesOnlyDirty:Bool = false;

    /** Setting this to true will force the visual to recompute its displayed content */
    public var contentDirty:Bool = true;

    /** Setting this to true will force the visual's matrix to be re-computed */
    public var matrixDirty(default,set):Bool = true;
    inline function set_matrixDirty(matrixDirty:Bool):Bool {
        this.matrixDirty = matrixDirty;
        if (matrixDirty) {
            if (children != null) {
                for (child in children) {
                    child.matrixDirty = true;
                }
            }
        }
        return matrixDirty;
    }

    /** Setting this to true will force the visual's computed render target to be re-computed */
    public var renderTargetDirty(default,set):Bool = true;
    inline function set_renderTargetDirty(renderTargetDirty:Bool):Bool {
        this.renderTargetDirty = renderTargetDirty;
        if (renderTargetDirty) {
            if (children != null) {
                for (child in children) {
                    child.renderTargetDirty = true;
                }
            }
        }
        return renderTargetDirty;
    }

    /** Setting this to true will force the visual to compute it's visility in hierarchy */
    public var visibilityDirty(default,set):Bool = true;
    inline function set_visibilityDirty(visibilityDirty:Bool):Bool {
        this.visibilityDirty = visibilityDirty;
        if (visibilityDirty) {
            if (children != null) {
                for (child in children) {
                    child.visibilityDirty = true;
                }
            }
        }
        return visibilityDirty;
    }

    /** Setting this to true will force the visual to compute it's touchability in hierarchy */
    public var touchableDirty(default,set):Bool = true;
    inline function set_touchableDirty(touchableDirty:Bool):Bool {
        this.touchableDirty = touchableDirty;
        if (touchableDirty) {
            if (children != null) {
                for (child in children) {
                    child.touchableDirty = true;
                }
            }
        }
        return touchableDirty;
    }

    /** Setting this to true will force the visual to compute it's clipping state in hierarchy */
    public var clipDirty(default,set):Bool = true;
    inline function set_clipDirty(clipDirty:Bool):Bool {
        this.clipDirty = clipDirty;
        if (clipDirty) {
            if (children != null) {
                for (child in children) {
                    child.clipDirty = true;
                }
            }
        }
        return clipDirty;
    }

    /** If set, children will be sort by depth and their computed depth
        will be within range [parent.depth, parent.depth + depthRange] */
    @editable
    public var depthRange(default,set):Float = -1;
    inline function set_depthRange(depthRange:Float):Float {
        if (this.depthRange == depthRange) return depthRange;
        this.depthRange = depthRange;
        ceramic.App.app.hierarchyDirty = true;
        return depthRange;
    }

    /** If set, the visual will be rendered into this target RenderTexture instance
        instead of being drawn onto screen directly. */
    public var renderTarget(default,set):RenderTexture = null;
    function set_renderTarget(renderTarget:RenderTexture):RenderTexture {
        if (this.renderTarget == renderTarget) return renderTarget;
        this.renderTarget = renderTarget;
        matrixDirty = true;
        return renderTarget;
    }

    public var blending(default,set):Blending = Blending.NORMAL;
    function set_blending(blending:Blending):Blending {
        return this.blending = blending;
    }

    @editable
    public var visible(default,set):Bool = true;
    function set_visible(visible:Bool):Bool {
        if (this.visible == visible) return visible;
        this.visible = visible;
        visibilityDirty = true;
        return visible;
    }

    @editable
    public var touchable(default,set):Bool = true;
    function set_touchable(touchable:Bool):Bool {
        if (this.touchable == touchable) return touchable;
        this.touchable = touchable;
        touchableDirty = true;
        return touchable;
    }

    @editable
    public var alpha(default,set):Float = 1;
    function set_alpha(alpha:Float):Float {
        if (this.alpha == alpha) return alpha;
        this.alpha = alpha;
        visibilityDirty = true;
        return alpha;
    }

    @editable
    public var x(default,set):Float = 0;
    function set_x(x:Float):Float {
        if (this.x == x) return x;
        this.x = x;
        matrixDirty = true;
        return x;
    }

    @editable
    public var y(default,set):Float = 0;
    function set_y(y:Float):Float {
        if (this.y == y) return y;
        this.y = y;
        matrixDirty = true;
        return y;
    }

    @editable
    public var depth(default,set):Float = 0;
    function set_depth(depth:Float):Float {
        if (this.depth == depth) return depth;
        this.depth = depth;
        ceramic.App.app.hierarchyDirty = true;
        return depth;
    }

    @editable
    public var rotation(default,set):Float = 0;
    function set_rotation(rotation:Float):Float {
        if (this.rotation == rotation) return rotation;
        this.rotation = rotation;
        matrixDirty = true;
        translatesOnlyDirty = true;
        return rotation;
    }

    @editable
    public var scaleX(default,set):Float = 1;
    function set_scaleX(scaleX:Float):Float {
        if (this.scaleX == scaleX) return scaleX;
        this.scaleX = scaleX;
        matrixDirty = true;
        translatesOnlyDirty = true;
        return scaleX;
    }

    @editable
    public var scaleY(default,set):Float = 1;
    function set_scaleY(scaleY:Float):Float {
        if (this.scaleY == scaleY) return scaleY;
        this.scaleY = scaleY;
        matrixDirty = true;
        translatesOnlyDirty = true;
        return scaleY;
    }

    @editable
    public var skewX(default,set):Float = 0;
    function set_skewX(skewX:Float):Float {
        if (this.skewX == skewX) return skewX;
        this.skewX = skewX;
        matrixDirty = true;
        translatesOnlyDirty = true;
        return skewX;
    }

    @editable
    public var skewY(default,set):Float = 0;
    function set_skewY(skewY:Float):Float {
        if (this.skewY == skewY) return skewY;
        this.skewY = skewY;
        matrixDirty = true;
        translatesOnlyDirty = true;
        return skewY;
    }

    @editable
    public var anchorX(default,set):Float = 0;
    function set_anchorX(anchorX:Float):Float {
        if (this.anchorX == anchorX) return anchorX;
        this.anchorX = anchorX;
        matrixDirty = true;
        return anchorX;
    }

    @editable
    public var anchorY(default,set):Float = 0;
    function set_anchorY(anchorY:Float):Float {
        if (this.anchorY == anchorY) return anchorY;
        this.anchorY = anchorY;
        matrixDirty = true;
        return anchorY;
    }

    @editable
    public var width(get,set):Float;
    var _width:Float = 0;
    function get_width():Float {
        return _width;
    }
    function set_width(width:Float):Float {
        if (_width == width) return width;
        _width = width;
        return width;
    }

    @editable
    public var height(get,set):Float;
    var _height:Float = 0;
    function get_height():Float {
        return _height;
    }
    function set_height(height:Float):Float {
        if (_height == height) return height;
        _height = height;
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

    /** Assign a shader to this visual. */
    public var shader:Shader = null;

/// Flags

    /** Just a way to store some flags. **/
    var flags:Flags = new Flags();

    /** Whether this visual is `active`. Default is **true**. When setting it to **false**,
        the visual won't be `visible` nor `touchable` anymore (these get set to **false**).
        When restoring `active` to **true**, `visible` and `touchable` will also get back
        their previous state. **/
    public var active(get,set):Bool;
    inline function get_active():Bool {
        return !flags.bool(0);
    }
    inline function set_active(active:Bool):Bool {
        if (active == !flags.bool(0)) return active;
        flags.setBool(0, !active);
        if (active) {
            visible = flags.bool(1);
            touchable = flags.bool(2);
        }
        else {
            flags.setBool(1, visible);
            flags.setBool(2, touchable);
            visible = false;
            touchable = false;
        }
        return active;
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

    public var computedRenderTarget:RenderTexture = null;

    public var computedTouchable:Bool = true;

    public var computedClip:Bool = false;

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

        ceramic.App.app.visuals.push(this);
        ceramic.App.app.hierarchyDirty = true;

#if ceramic_luxe_legacy
        backendItem = ceramic.App.app.backend.draw.getItem(this);
#end

    } //new

    public function destroy() {

        if (ceramic.App.app.screen.focusedVisual == this) {
            ceramic.App.app.screen.focusedVisual = null;
        }
        
        ceramic.App.app.visuals.remove(this);
        ceramic.App.app.hierarchyDirty = true;

        if (parent != null) parent.remove(this);
        if (transform != null) transform = null;

        clear();

    } //destroy

    public function clear() {

        if (children != null) {
            for (child in [].concat(children)) {
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

    inline function computeTranslatesOnly() {

        translatesOnly = (rotation == 0 && scaleX == 1 && scaleY == 1 && skewX == 0 && skewY == 0);

    } //computeTranslatesOnly

    inline function doComputeMatrix() {

        if (translatesOnlyDirty) {
            computeTranslatesOnly();
        }

        var w = width;
        var h = height;

        // Apply local properties (pos, scale, rotation, skew)
        //

        if (translatesOnly) {
            _matrix.tx += x - anchorX * w;
            _matrix.ty += y - anchorY * h;
        }
        else {
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
        }

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
            if (translatesOnly && transform == null) {

                _matrix.a = parent.a;
                _matrix.b = parent.b;
                _matrix.c = parent.c;
                _matrix.d = parent.d;

                var tx1 = _matrix.tx * parent.a + _matrix.ty * parent.c + parent.tx;
                _matrix.ty = _matrix.tx * parent.b + _matrix.ty * parent.d + parent.ty;
                _matrix.tx = tx1;

            }
            else {

                var a1 = _matrix.a * parent.a + _matrix.b * parent.c;
                _matrix.b = _matrix.a * parent.b + _matrix.b * parent.d;
                _matrix.a = a1;

                var c1 = _matrix.c * parent.a + _matrix.d * parent.c;
                _matrix.d = _matrix.c * parent.b + _matrix.d * parent.d;

                _matrix.c = c1;

                var tx1 = _matrix.tx * parent.a + _matrix.ty * parent.c + parent.tx;
                _matrix.ty = _matrix.tx * parent.b + _matrix.ty * parent.d + parent.ty;
                _matrix.tx = tx1;
            }

        } else {

            if (renderTargetDirty) computeRenderTarget();

            if (computedRenderTarget == null) {

                // Concat matrix with screen transform
                //
                var m = ceramic.App.app.screen.matrix;
                
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
        _matrix.concat(ceramic.App.app.screen.reverseMatrix);
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
        // But remove screen transform from it if needed
        if (renderTargetDirty) computeRenderTarget();
        if (computedRenderTarget == null) {
            _matrix.concat(ceramic.App.app.screen.reverseMatrix);
        }
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
        // But remove screen transform from it if needed
        if (renderTargetDirty) computeRenderTarget();
        if (computedRenderTarget == null) {
            _matrix.concat(ceramic.App.app.screen.reverseMatrix);
        }

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
        transform.concat(ceramic.App.app.screen.reverseMatrix);

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
                if (inheritAlpha) computedAlpha *= parent.computedAlpha;
            }

            if (computedAlpha == 0) {
                computedVisible = false;
            }
            
        }

        visibilityDirty = false;

    } //computeVisibility

/// Clipping

    function computeClip() {

        if (parent != null && parent.clipDirty) {
            parent.computeClip();
        }

        computedClip = false;
        if (parent != null) {
            if (parent.computedClip || parent.clip != null) {
                computedClip = true;
            }
        }

        clipDirty = false;

    } //computeClip

/// Touchable

    function computeTouchable() {

        if (parent != null && parent.touchableDirty) {
            parent.computeTouchable();
        }

        computedTouchable = touchable;
        
        if (computedTouchable) {

            if (parent != null) {
                if (!parent.computedTouchable) {
                    computedTouchable = false;
                }
            }
            
        }

        touchableDirty = false;

    } //computedTouchable

/// RenderTarget (computed)

    function computeRenderTarget() {

        if (parent != null && parent.renderTargetDirty) {
            parent.computeRenderTarget();
        }

        computedRenderTarget = renderTarget;
        if (computedRenderTarget == null && parent != null && parent.computedRenderTarget != null) {
            computedRenderTarget = parent.computedRenderTarget;
        }
        
        renderTargetDirty = false;

    } //computeRenderTarget

/// Display

    function computeContent() {
        
        contentDirty = false;

    } //computeContent

/// Children

    static var _minDepth:Float = 0;

    static var _maxDepth:Float = 0;

    /** Compute children depth. The result depends on whether
        a parent defines a custom `depthRange` value or not. */
    function computeChildrenDepth():Void {

        if (children != null) {

            // Compute deepest in hierarchy first
            for (child in children) {
                child.computedDepth = child.depth;
                child.computeChildrenDepth();
            }

            // Apply depth range if any
            if (depthRange != -1) {

                _minDepth = 9999999999;
                _maxDepth = -9999999999;

                // Compute min/max depth
                for (child in children) {
                    child.computeMinMaxDepths();
                }

                // Multiply depth
                for (child in children) {
                    child.multiplyDepths(computedDepth + Math.min(0.00001, depthRange), Math.max(0, depthRange - 0.00001));
                }
            }
        }

    } //computeChildrenDepth

    function computeMinMaxDepths():Void {

        if (_minDepth > computedDepth) _minDepth = computedDepth;
        if (_maxDepth < computedDepth) _maxDepth = computedDepth;

        if (children != null) {

            for (child in children) {
                child.computeMinMaxDepths();
            }
        }

    } //computeMinMaxDepths

    function multiplyDepths(startDepth:Float, targetRange:Float):Void {

        if (_maxDepth == _minDepth) {
            computedDepth = startDepth + 0.5 * targetRange;
        } else {
            computedDepth = startDepth + ((computedDepth - _minDepth) / (_maxDepth - _minDepth)) * targetRange;
        }

        // Multiply recursively
        if (children != null) {

            for (child in children) {
                child.multiplyDepths(startDepth, targetRange);
            }
        }

    } //multiplyDepths

    public function add(visual:Visual):Void {

        App.app.hierarchyDirty = true;

        if (visual.parent != null) {
            visual.parent.remove(visual);
        }

        visual.parent = this;
        visual.visibilityDirty = true;
        visual.matrixDirty = true;
        visual.renderTargetDirty = true;
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
        visual.visibilityDirty = true;
        visual.matrixDirty = true;
        visual.renderTargetDirty = true;

    } //remove

    /** Returns `true` if the current visual contains this child.
        When `recursive` option is `true`, will return `true` if
        the current visual contains this child or one of
        its direct or indirect children does. */
    public function contains(child:Visual, recursive:Bool = false):Bool {

        var parent = child.parent;

        while (parent != null) {

            if (parent == this) return true;
            parent = parent.parent;

            if (!recursive) break;
        }

        return false;

    } //contains

/// Size helpers

    /** Compute bounds from children this visual contains.
        This overwrites width, height, anchorX and anchorY properties accordingly.
        Warning: this may be an expensive operation. */
    function computeBounds():Void {

        if (children == null) {
            _width = 0;
            _height = 0;
        }
        else {
            var minX = 999999999.0;
            var minY = 999999999.0;
            var maxX = -999999999.9;
            var maxY = -999999999.9;
            var point = new Point();
            for (child in children) {

                if (child.visible) {

                    // Mesh is a specific case.
                    // For now we handle it in Visual class directly.
                    // We might move this into Mesh class later.
                    if (child.mesh != null) {
                        var mesh:Mesh = child.mesh;
                        var vertices = mesh.vertices;
                        var i = 0;
                        var len = vertices.length;
                        var x = 0.0;
                        var y = 0.0;

                        while (i < len) {
                            x = vertices[i];
                            y = vertices[i + 1];

                            child.visualToScreen(x, y, point);
                            if (point.x > maxX) maxX = point.x;
                            if (point.y > maxY) maxY = point.y;
                            if (point.x < minX) minX = point.x;
                            if (point.y < minY) minY = point.y;

                            i += 2;
                        }

                    }
                    else {
                        child.visualToScreen(0, 0, point);
                        if (point.x > maxX) maxX = point.x;
                        if (point.y > maxY) maxY = point.y;
                        if (point.x < minX) minX = point.x;
                        if (point.y < minY) minY = point.y;

                        child.visualToScreen(child.width, 0, point);
                        if (point.x > maxX) maxX = point.x;
                        if (point.y > maxY) maxY = point.y;
                        if (point.x < minX) minX = point.x;
                        if (point.y < minY) minY = point.y;

                        child.visualToScreen(0, child.height, point);
                        if (point.x > maxX) maxX = point.x;
                        if (point.y > maxY) maxY = point.y;
                        if (point.x < minX) minX = point.x;
                        if (point.y < minY) minY = point.y;

                        child.visualToScreen(child.width, child.height, point);
                        if (point.x > maxX) maxX = point.x;
                        if (point.y > maxY) maxY = point.y;
                        if (point.x < minX) minX = point.x;
                        if (point.y < minY) minY = point.y;
                    }
                }
            }

            // Keep absolute position to restore it after we update anchor
            visualToScreen(0, 0, point);
            var origX = point.x;
            var origY = point.y;

            screenToVisual(minX, minY, point);
            minX = point.x;
            minY = point.y;

            screenToVisual(maxX, maxY, point);
            maxX = point.x;
            maxY = point.y;

            _width = maxX - minX;
            _height = maxY - minY;

            anchorX = _width != 0 ? -minX / _width : 0;
            anchorY = _height != 0 ? -minY / _height : 0;

            // Restore position
            screenToVisual(origX, origY, point);
            this.x = point.x - _width * anchorX;
            this.y = point.y - _height * anchorY;

            matrixDirty = true;
        }

    } //computeIntrinsicSize

} //Visual
