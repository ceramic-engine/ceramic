package ceramic;

import backend.Draw.DrawKind;

@:allow(ceramic.App)
class Visual extends Entity {

/// Events

    @event function down();

    @event function up();

    @event function click();

    @event function over();

    @event function out();

/// Properties

    /** Defines how this visual should be drawn. Depends on the backend. */
    public var drawKind:DrawKind;

    /** Setting this to true will force the visual's matrix to be re-computed */
    public var matrixDirty:Bool = true;

    /** Setting this to true will force the visual to compute it's visility in hierarchy */
    public var visibilityDirty:Bool = true;

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

    public var z(default,set):Float = 0;
    function set_z(z:Float):Float {
        if (this.z == z) return z;
        this.z = z;
        app.hierarchyDirty = true;
        return z;
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

    private var realWidth:Float = -1;
    public var width(get,set):Float;
    function get_width():Float {
        return realWidth == -1 ? 0 : realWidth * scaleX;
    }
    function set_width(width:Float):Float {
        if (this.width == width) return width;
        realWidth = width / scaleX;
        matrixDirty = true;
        return width;
    }

    private var realHeight:Float = -1;
    public var height(get,set):Float;
    function get_height():Float {
        return realHeight == -1 ? 0 : realHeight * scaleY;
    }
    function set_height(height:Float):Float {
        if (this.height == height) return height;
        realHeight = height / scaleY;
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
            this.transform.onChange(transformDidChange);
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

/// Properties (Children)

	public var children(default,null):Array<Visual> = null;

    public var parent(default,null):Visual = null;

/// Internal

    static var _matrix = new Transform();

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

        this.x = Math.round(x);
        this.y = Math.round(y);

    } //pos

    inline public function scale(scaleX:Float, scaleY:Float = -1):Void {

        this.scaleX = scaleX;
        this.scaleY = scaleY != -1 ? scaleY : scaleX;

    } //scale

    inline public function skew(skewX:Float, skewY:Float):Void {

        this.skewX = skewX;
        this.skewY = skewY;

    } //skew

/// Lifecycle

    public function new() {

        app.visuals.push(this);
        app.hierarchyDirty = true;

        drawKind = app.backend.draw.drawKind(this);

    } //new

    public function destroy() {
        
        app.visuals.remove(this);

    } //destroy

/// Matrix

    function transformDidChange() {

        matrixDirty = true;

    } //transformDidChange

    function computeMatrix() {

        if (parent != null && parent.matrixDirty) {
            parent.computeMatrix();
        }

        var w = width;
        var h = height;

        _matrix.identity();

        // Apply local properties (pos, scale, rotation, )
        //
        _matrix.translate(-anchorX * w / scaleX, -anchorY * h / scaleY);
		if (skewX != 0) _matrix.c = skewX * Math.PI / 180.0;
		if (skewY != 0) _matrix.b = skewY * Math.PI / 180.0;
        if (rotation != 0) _matrix.rotate(rotation * Math.PI / 180.0);
        _matrix.translate(anchorX * w / scaleX, anchorY * h / scaleY);
        if (scaleX != 1.0 || scaleY != 1.0) _matrix.scale(scaleX, scaleY);
        _matrix.translate(
            x - (anchorX * w),
            y - (anchorY * h)
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

    } //computeMatrix

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

/// Children

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
