package ceramic.ui;

import ceramic.Shortcuts.*;

using ceramic.Extensions;

class View extends Quad {

/// Events

    @event function layout_();

/// Properties

    /** Same as `children` but typed as a list of `View` instances instead of `Visual` (thus only contains children that are of `View` type). */
    public var subviews:ImmutableArray<View> = null;

    public var computedWidth:Float = -1;

    public var computedHeight:Float = -1;

    /** Width processed by View layout engine. Can be a numeric value, a percentage (with `ViewSize.percent()`), automatic (with `ViewSize.fill()`) or undefined (with `ViewSize.none()`). */
    public var viewWidth(default,set):Float = ViewSize.auto();
    function set_viewWidth(viewWidth:Float):Float {
        if (this.viewWidth == viewWidth) return viewWidth;
        this.viewWidth = viewWidth;
        layoutDirty = true;
        return viewWidth;
    }

    /** Height processed by View layout engine. Can be a numeric value, a percentage (with `ViewSize.percent()`), automatic (with `ViewSize.fill()`) or undefined (with `ViewSize.none()`). */
    public var viewHeight(default,set):Float = ViewSize.auto();
    function set_viewHeight(viewHeight:Float):Float {
        if (this.viewHeight == viewHeight) return viewHeight;
        this.viewHeight = viewHeight;
        layoutDirty = true;
        return viewHeight;
    }

    /** Set `viewWidth` and `viewHeight` */
    inline public function viewSize(width:Float, height:Float) {
        viewWidth = width;
        viewHeight = height;
    }

    public function padding(left:Float, ?top:Float, ?right:Float, ?bottom:Float):Void {
        paddingLeft = left;
        if (top != null && right != null && bottom != null) {
            paddingTop = top;
            paddingRight = right;
            paddingBottom = bottom;
        } else {
            paddingTop = left;
            paddingRight = left;
            paddingBottom = left;
        }
    }

    public var paddingLeft(default,set):Float = 0;
    function set_paddingLeft(paddingLeft:Float):Float {
        if (this.paddingLeft == paddingLeft) return paddingLeft;
        this.paddingLeft = paddingLeft;
        layoutDirty = true;
        return paddingLeft;
    }

    public var paddingRight(default,set):Float = 0;
    function set_paddingRight(paddingRight:Float):Float {
        if (this.paddingRight == paddingRight) return paddingRight;
        this.paddingRight = paddingRight;
        layoutDirty = true;
        return paddingRight;
    }

    public var paddingTop(default,set):Float = 0;
    function set_paddingTop(paddingTop:Float):Float {
        if (this.paddingTop == paddingTop) return paddingTop;
        this.paddingTop = paddingTop;
        layoutDirty = true;
        return paddingTop;
    }

    public var paddingBottom(default,set):Float = 0;
    function set_paddingBottom(paddingBottom:Float):Float {
        if (this.paddingBottom == paddingBottom) return paddingBottom;
        this.paddingBottom = paddingBottom;
        layoutDirty = true;
        return paddingBottom;
    }

    /** Setting this to `false` will prevent this view from updating its layout.
        Default is `true` */
    public var canLayout:Bool;

    public var layoutDirty:Bool = true;

/// Border

    var border:Border = null;

    public var borderPosition:BorderPosition = MIDDLE;
    inline function set_borderPosition(borderPosition:BorderPosition):BorderPosition {
        if (this.borderPosition == borderPosition) return borderPosition;
        this.borderPosition = borderPosition;
        if (borderSize > 0) updateBorder();
        return borderPosition;
    }

    public var borderSize(default,set):Float = 0;
    inline function set_borderSize(borderSize:Float):Float {
        if (this.borderSize == borderSize) return borderSize;
        this.borderSize = borderSize;
        updateBorder();
        return borderSize;
    }

    public var borderColor(default,set):Color = Color.GRAY;
    inline function set_borderColor(borderColor:Color):Color {
        if (this.borderColor == borderColor) return borderColor;
        this.borderColor = borderColor;
        if (borderSize > 0) updateBorder();
        return borderColor;
    }

    function updateBorder():Void {

        if (borderSize > 0) {
            if (border == null) {
                border = new Border();
                border.depth = depthRange >= 0 ? 0 : depth;
                add(border);
            }
            border.autoComputeVertices = false;
            border.color = borderColor;
            border.borderPosition = borderPosition;
            border.borderSize = borderSize;
            border.size(width, height);
            border.autoComputeVertices = true;
            border.anchor(0, 0);
            border.pos(0, 0);
        }
        else {
            if (border != null) border.destroy();
        }

    } //updateBorder

/// Overrides

    override function set_active(active:Bool):Bool {
        if (this.active == active) return active;
        super.set_active(active);
        layoutDirty = true;
        return active;
    }

    override function set_width(width:Float):Float {
        if (_width == width) return width;
        _width = width;
        layoutDirty = true;
        if (anchorX != 0) matrixDirty = true;
        if (borderSize > 0) updateBorder();
        return width;
    }

    override function set_height(height:Float):Float {
        if (_height == height) return height;
        _height = height;
        layoutDirty = true;
        if (anchorY != 0) matrixDirty = true;
        if (borderSize > 0) updateBorder();
        return height;
    }

    override function set_depth(depth:Float):Float {
        if (this.depth == depth) return depth;
        super.set_depth(depth);
        if (borderSize > 0) updateBorder();
        return depth;
    }

    override function set_depthRange(depthRange:Float):Float {
        if (this.depthRange == depthRange) return depthRange;
        super.set_depthRange(depthRange);
        if (borderSize > 0) updateBorder();
        return depthRange;
    }

    override function add(visual:Visual):Void {
        super.add(visual);
        if (Std.is(visual,View)) {
            var view:View = cast visual;
            if (subviews == null) {
                subviews = [];
            }
            @:privateAccess subviews.mutable.push(view);
            view.layoutDirty = true;
        }
        layoutDirty = true;
    }

    override function remove(visual:Visual):Void {
        super.remove(visual);
        if (Std.is(visual,View)) {
            var view:View = cast visual;
            @:privateAccess subviews.mutable.splice(subviews.indexOf(view), 1);
            view.layoutDirty = true;
        }
        layoutDirty = true;
    }

    /** Creates a new `Autorun` instance with the given callback associated with the current entity.
        @param run The run callback
        @return The autorun instance */
    override function autorun(run:Void->Void #if ceramic_debug_autorun , ?pos:haxe.PosInfos #end):Autorun {

        return super.autorun(function() {
            run();
            app.onceImmediate(_autorunLayout);
        } #if ceramic_debug_autorun , pos #end);

    } //autorun

    function _autorunLayout() {

        layoutDirty = true;
        requestLayout();

    } //_autorunLayout

/// Lifecycle

    public function new() {

        super();

        depthRange = 1;
        canLayout = false;
        transparent = false;

        // Register view in global list
        if (_allViews == null) {
            _allViews = [];
            app.onUpdate(null, _updateViewsLayout);
        }
        _allViews.push(this);

        // Prevent layout from happening too early
        app.onceImmediate(function() {
            // We use a 2-level onceImmediate call to ensure this
            // will be executed after "standard" `onceImmediate` calls.
            app.onceImmediate(function() {
                canLayout = true;
                if (layoutDirty) {
                    View.requestLayout();
                }
            });
        });

    } //new

    override function destroy() {

        // Remove view from global list
        _allViews.splice(_allViews.indexOf(this), 1);

    } //destroy

    public function removeAllViews():Void {

        if (subviews == null) return;
        var len = subviews.length;
        var pool = ArrayPool.pool(len);
        var tmp = pool.get();
        for (i in 0...len) {
            tmp.set(i, subviews.unsafeGet(i));
        }
        for (i in 0...len) {
            var view:View = tmp.get(i);
            remove(view);
        }
        pool.release(tmp);
        subviews = null;

    } //removeAllViews

    public function autoSize():Void {

        computeSize(0, 0, ViewLayoutMask.FLEXIBLE, true);
        size(computedWidth, computedHeight);

    } //autoSize

    public function autoSizeWithFixedHeight(height:Float):Void {

        computeSize(0, height, ViewLayoutMask.FLEXIBLE_WIDTH, true);
        size(computedWidth, computedHeight);

    } //autoSizeWithFixedHeight

    public function autoSizeWithFixedWidth(width:Float):Void {

        computeSize(width, 0, ViewLayoutMask.FLEXIBLE_HEIGHT, true);
        size(computedWidth, computedHeight);

    } //autoSizeWithFixedWidth

    public function computeSize(parentWidth:Float, parentHeight:Float, layoutMask:ViewLayoutMask, persist:Bool):Void {

        // Compute width
        if (ViewSize.isAuto(viewWidth) || ViewSize.isFill(viewWidth)) {
            if (layoutMask.canDecreaseWidth()) {
                computedWidth = 0;
            } else {
                computedWidth = parentWidth;
            }
        }
        else if (ViewSize.isFill(viewWidth)) {
            computedWidth = viewWidth;
        }
        else if (ViewSize.isPercent(viewWidth)) {
            computedWidth = ViewSize.percentToFloat(viewWidth) * parentWidth;
        }
        else {
            computedWidth = viewWidth;
        }

        // Compute height
        if (ViewSize.isAuto(viewHeight)) {
            if (layoutMask.canDecreaseHeight()) {
                computedHeight = 0;
            } else {
                computedHeight = parentHeight;
            }
        }
        else if (ViewSize.isFill(viewHeight)) {
            computedHeight = parentHeight;
        }
        else if (ViewSize.isPercent(viewHeight)) {
            computedHeight = ViewSize.percentToFloat(viewHeight) * parentHeight;
        }
        else {
            computedHeight = viewHeight;
        }

        // Force fixed width if not flexible
        if (!layoutMask.canIncreaseWidth()) {
            if (computedWidth > parentWidth) {
                computedWidth = parentWidth;
            }
        }

        // Force fixed height if not flexible
        if (!layoutMask.canIncreaseHeight()) {
            if (computedHeight > parentHeight) {
                computedHeight = parentHeight;
            }
        }

    } //computeSize

    inline function willEmitLayout():Void {

        updateBorder();
        layout();

    } //willEmitLayout

    function layout():Void {

        // Override in subclasses

    } //layout

/// On-demand explicit layout

    public static function requestLayout():Void {

        if (_layouting || _layoutRequested) return;

        _layoutRequested = true;
        app.onceImmediate(function() {
            _layoutRequested = false;
            _updateViewsLayout(0);
        });

    } //requestLayout

/// Internal

    static var _layoutRequested:Bool = false;

    static var _layouting:Bool = false;

    static var _allViews:Array<View> = null;

    static function _updateViewsLayout(_):Void {

        _layouting = true;

        var hasAnyDirty = false;

        // Gather views to update first
        for (i in 0..._allViews.length) {
            var view = _allViews.unsafeGet(i);
            if (view.layoutDirty) {
                hasAnyDirty = true;
                break;
            }
        }

        // TODO prevent allocation?
        var toUpdate = [].concat(_allViews);

        if (hasAnyDirty) {
            // Mark all parent-of-dirty views as dirty as well
            for (i in 0...toUpdate.length) {
                var view = toUpdate.unsafeGet(i);
                _markParentsAsLayoutDirty(view);
            }
            // Then emit layout event by starting from the top-level views
            for (i in 0...toUpdate.length) {
                var view = toUpdate.unsafeGet(i);
                _layoutParentThenSelf(view);
            }
            for (i in 0...toUpdate.length) {
                var view = toUpdate.unsafeGet(i);
                _layoutParentThenSelf(view);
            }
        }

        _layouting = false;

    } //updateViewLayouts

    inline static function _markParentsAsLayoutDirty(view:View):Void {

        if (view.layoutDirty) {
            var root = view;
            while (root.parent != null && Std.is(root.parent, View)) {
                root = cast root.parent;
                root.layoutDirty = true;
            }
        }

    } //_markParentsAsLayoutDirty

    static function _layoutParentThenSelf(view:View):Void {

        if (view.parent != null && Std.is(view.parent, View)) {
            _layoutParentThenSelf(cast view.parent);
        }

        if (view.layoutDirty && view.canLayout) {
            view.emitLayout();
            view.layoutDirty = false;
        }

    } //layoutParentThenSelf

/// View size helpers

    inline public function percent(value:Float):Float {

        return ViewSize.percent(value);

    } //percent

    inline public function percentToFloat(encoded:Float):Float {

        return ViewSize.percentToFloat(encoded);

    } //percentToFloat

    inline public function fill():Float {

        return ViewSize.fill();

    } //auto

    inline public function auto():Float {

        return ViewSize.auto();

    } //auto

} //View
