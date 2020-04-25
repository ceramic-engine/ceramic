package ceramic.ui;

import ceramic.Shortcuts.*;
import tracker.Autorun;

using ceramic.Extensions;

class View extends Quad {

/// Events

    @event function layout_();

/// Properties

    /** Same as `children` but typed as a list of `View` instances instead of `Visual` (thus only contains children that are of `View` type). */
    public var subviews:ImmutableArray<View> = null;

    /** Width after being computed by View layout engine from constraints and `viewWidth`/`viewHeight` */
    public var computedWidth:Float = -1;

    /** Height after being computed by View layout engine from constraints and `viewWidth`/`viewHeight` */
    public var computedHeight:Float = -1;

    /** Width that will be processed by View layout engine. Can be a numeric value, a percentage (with `ViewSize.percent()`), automatic (with `ViewSize.fill()`) or undefined (with `ViewSize.none()`). */
    public var viewWidth(default,set):Float = ViewSize.auto();
    function set_viewWidth(viewWidth:Float):Float {
        if (this.viewWidth == viewWidth) return viewWidth;
        this.viewWidth = viewWidth;
        layoutDirty = true;
        return viewWidth;
    }

    /** Height that will be processed by View layout engine. Can be a numeric value, a percentage (with `ViewSize.percent()`), automatic (with `ViewSize.fill()`) or undefined (with `ViewSize.none()`). */
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

    /** Set padding. Order and number of parameters following CSS padding convention.
        Examples:
        ```
        padding(10) // top=10, right=10, bottom=10, left=10
        padding(3, 5) // top=3, right=5, bottom=3, left=5
        padding(3, 5, 8, 4) // top=3, right=5, bottom=8, left=4
        ``` */
    public function padding(top:Float, ?right:Float, ?bottom:Float, ?left:Float):Void {
        if (right == null && bottom == null && left == null) {
            right = top;
            bottom = top;
            left = top;
        }
        else if (bottom == null && left == null) {
            bottom = top;
            left = right;
        }
        else {
            if (right == null) right = top;
            if (bottom == null) bottom = top;
            if (left == null) left = top;
        }
        paddingLeft = left;
        paddingTop = top;
        paddingRight = right;
        paddingBottom = bottom;
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

    /** Offset this view position by `x` and `y`.
        This offset is added to the view's resulting position
        from its default layout. This has only effect when the view is layouted
        by a layout class that handle offsets: `LinearLayout`, `LayersLayout` */
    inline public function offset(x:Float, y:Float):Void {
        offsetX = x;
        offsetY = y;
    }

    /** Offset this view position by `offsetX`.
        This offset is added to the view's resulting position
        from its default layout. This has only effect when the view is layouted
        by a layout class that handle offsets: `LinearLayout`, `LayersLayout` */
    public var offsetX(default,set):Float = 0;
    function set_offsetX(offsetX:Float):Float {
        if (this.offsetX == offsetX) return offsetX;
        this.offsetX = offsetX;
        layoutDirty = true;
        return offsetX;
    }

    /** Offset this view position by `offsetY`.
        This offset is added to the view's resulting position
        from its default layout. This has only effect when the view is layouted
        by a layout class that handle offsets: `LinearLayout`, `LayersLayout` */
    public var offsetY(default,set):Float = 0;
    function set_offsetY(offsetY:Float):Float {
        if (this.offsetY == offsetY) return offsetY;
        this.offsetY = offsetY;
        layoutDirty = true;
        return offsetY;
    }

    /** A hint to tell how much space this view should take,
        relative to the space taken by a whole group of views.
        Example:

            view1.flex = 1; // Fills 1/3 of available space
            view2.flex = 2; // Fills 2/3 of available space
        */
    public var flex(default,set):Int = 1;
    inline function set_flex(flex:Int):Int {
        if (this.flex == flex) return flex;
        this.flex = flex;
        layoutDirty = true;
        return flex;
    }

    /** Setting this to `false` will prevent this view from updating its layout.
        Default is `true` */
    public var canLayout:Bool;

    public var layoutDirty:Bool = true;

/// Border

    var border:Border = null;

    public var borderDepth(default,set):Float = 0;
    inline function set_borderDepth(borderDepth:Float):Float {
        if (this.borderDepth == borderDepth) return borderDepth;
        this.borderDepth = borderDepth;
        if (border != null) border.depth = depth;
        return borderDepth;
    }

    public var borderPosition(default,set):BorderPosition = INSIDE;
    inline function set_borderPosition(borderPosition:BorderPosition):BorderPosition {
        if (this.borderPosition == borderPosition) return borderPosition;
        this.borderPosition = borderPosition;
        if (shouldDisplayBorder()) updateBorder();
        return borderPosition;
    }

    public var borderSize(default,set):Float = 0;
    inline function set_borderSize(borderSize:Float):Float {
        if (this.borderSize == borderSize) return borderSize;
        this.borderSize = borderSize;
        updateBorder();
        return borderSize;
    }

    public var borderTopSize(default,set):Float = -1;
    inline function set_borderTopSize(borderTopSize:Float):Float {
        if (this.borderTopSize == borderTopSize) return borderTopSize;
        this.borderTopSize = borderTopSize;
        updateBorder();
        return borderTopSize;
    }

    public var borderBottomSize(default,set):Float = -1;
    inline function set_borderBottomSize(borderBottomSize:Float):Float {
        if (this.borderBottomSize == borderBottomSize) return borderBottomSize;
        this.borderBottomSize = borderBottomSize;
        updateBorder();
        return borderBottomSize;
    }

    public var borderLeftSize(default,set):Float = -1;
    inline function set_borderLeftSize(borderLeftSize:Float):Float {
        if (this.borderLeftSize == borderLeftSize) return borderLeftSize;
        this.borderLeftSize = borderLeftSize;
        updateBorder();
        return borderLeftSize;
    }

    public var borderRightSize(default,set):Float = -1;
    inline function set_borderRightSize(borderRightSize:Float):Float {
        if (this.borderRightSize == borderRightSize) return borderRightSize;
        this.borderRightSize = borderRightSize;
        updateBorder();
        return borderRightSize;
    }

    public var borderColor(default,set):Color = Color.GRAY;
    inline function set_borderColor(borderColor:Color):Color {
        if (this.borderColor == borderColor) return borderColor;
        this.borderColor = borderColor;
        if (shouldDisplayBorder()) updateBorder();
        return borderColor;
    }

    public var borderTopColor(default,set):Color = Color.NONE;
    inline function set_borderTopColor(borderTopColor:Color):Color {
        if (this.borderTopColor == borderTopColor) return borderTopColor;
        this.borderTopColor = borderTopColor;
        if (borderSize > 0 || borderTopSize > 0) updateBorder();
        return borderTopColor;
    }

    public var borderBottomColor(default,set):Color = Color.NONE;
    inline function set_borderBottomColor(borderBottomColor:Color):Color {
        if (this.borderBottomColor == borderBottomColor) return borderBottomColor;
        this.borderBottomColor = borderBottomColor;
        if (borderSize > 0 || borderBottomSize > 0) updateBorder();
        return borderBottomColor;
    }

    public var borderLeftColor(default,set):Color = Color.NONE;
    inline function set_borderLeftColor(borderLeftColor:Color):Color {
        if (this.borderLeftColor == borderLeftColor) return borderLeftColor;
        this.borderLeftColor = borderLeftColor;
        if (borderSize > 0 || borderLeftSize > 0) updateBorder();
        return borderLeftColor;
    }

    public var borderRightColor(default,set):Color = Color.NONE;
    inline function set_borderRightColor(borderRightColor:Color):Color {
        if (this.borderRightColor == borderRightColor) return borderRightColor;
        this.borderRightColor = borderRightColor;
        if (borderSize > 0 || borderRightSize > 0) updateBorder();
        return borderRightColor;
    }

    inline function shouldDisplayBorder() {

        return borderSize > 0 || borderTopSize > 0 || borderBottomSize > 0 || borderLeftSize > 0 || borderRightSize > 0;

    }

    function initBorder():Void {

        border = new Border();
        add(border);

    }

    function updateBorder():Void {

        if (shouldDisplayBorder()) {
            if (border == null) {
                initBorder();
            }
            border.depth = borderDepth;
            border.autoComputeVertices = false;
            border.autoComputeColors = false;
            border.borderColor = borderColor;
            border.borderTopColor = borderTopColor;
            border.borderBottomColor = borderBottomColor;
            border.borderLeftColor = borderLeftColor;
            border.borderRightColor = borderRightColor;
            border.borderPosition = borderPosition;
            border.borderSize = borderSize;
            border.borderTopSize = borderTopSize;
            border.borderBottomSize = borderBottomSize;
            border.borderLeftSize = borderLeftSize;
            border.borderRightSize = borderRightSize;
            border.size(width, height);
            border.autoComputeVertices = true;
            border.autoComputeColors = true;
            border.anchor(0, 0);
            border.pos(0, 0);
        }
        else {
            if (border != null) border.destroy();
        }

    }

/// Computed size context

    var persistedParentLayoutMask:ViewLayoutMask = ViewLayoutMask.FLEXIBLE;

    var persistedParentWidth:Float = -1;

    var persistedParentHeight:Float = -1;

    var persistedComputedWidth:Float = -1;

    var persistedComputedHeight:Float = -1;

    /*inline public function shouldRecomputeSizeWithContext(parentWidth:Float, parentHeight:Float, parentLayoutMask:ViewLayoutMask):Bool {

        return computedWidth == -1 || persistedComputedWidth || parentWidth != persistedParentWidth || parentHeight != persistedParentHeight;

    } //shouldRecomputeSizeWithContext*/

    inline public function persistComputedSizeWithContext(parentWidth:Float, parentHeight:Float, parentLayoutMask:ViewLayoutMask):Void {

        // Could be improved to persist multiple sizes with different contextes,
        // but for now, this will do OK

        persistedParentWidth = parentWidth;
        persistedParentHeight = parentHeight;
        persistedParentLayoutMask = parentLayoutMask;
        persistedComputedWidth = computedWidth;
        persistedComputedHeight = computedHeight;

    }

    inline public function hasPersistentComputedSizeWithContext(parentWidth:Float, parentHeight:Float, parentLayoutMask:ViewLayoutMask):Bool {

        // Could be improved to persist multiple sizes with different contextes,
        // but for now, this will do OK

        return persistedParentLayoutMask == parentLayoutMask
            && persistedParentWidth == parentWidth
            && persistedParentHeight == parentHeight
            && persistedComputedWidth != -1;

    }

    inline public function resetComputedSize():Void {
        
        computedWidth = -1;
        persistedComputedWidth = -1;

    }

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
    override function autorun(run:Void->Void, ?afterRun:Void->Void #if (ceramic_debug_autorun || ceramic_debug_entity_allocs) , ?pos:haxe.PosInfos #end):Autorun {

        /*
        return super.autorun(function() {
            run();
            app.onceImmediate(_autorunLayout);
        } #if (ceramic_debug_autorun || ceramic_debug_entity_allocs) , pos #end);
        //*/
        //*
        if (afterRun == null) {
            afterRun = _immediateAutorunLayout;
        }
        else {
            var _afterRun = afterRun;
            afterRun = () -> {
                _afterRun();
                _immediateAutorunLayout();
            };
        }
        var _autorun = super.autorun(run, afterRun #if (ceramic_debug_autorun || ceramic_debug_entity_allocs) , pos #end);

        return _autorun;
        //*/

    }

/// Autorun internals

    function _immediateAutorunLayout() {

        app.onceImmediate(_autorunLayout);

    }

    function _autorunLayout() {

        layoutDirty = true;
        requestLayout();

    }

/// Parent view helper

    var customParentView:Null<View> = null;

    public var parentView(get, never):Null<View>;

    function get_parentView():Null<View> {
        if (customParentView != null)
            return customParentView;
        if (Std.is(parent, View))
            return cast parent;
        return null;
    }

/// Lifecycle

    public function new(#if ceramic_debug_entity_allocs ?pos:haxe.PosInfos #end) {

        super(#if ceramic_debug_entity_allocs pos #end);

        depthRange = 1;
        canLayout = false;
        transparent = false;

        // Register view in global list
        if (_allViews == null) {
            _allViews = [];
            app.onPostUpdate(null, _updateViewsLayout);
        }
        _allViews.push(this);

        // Prevent layout from happening too early
        app.onceImmediate(function() {
            // We use a 2-level onceImmediate call to ensure this
            // will be executed after "standard" `onceImmediate` calls.
            app.oncePostFlushImmediate(function() {
                canLayout = true;
                if (layoutDirty) {
                    View.requestLayout();
                }
            });
        });

    }

    override function destroy() {

        super.destroy();

        // Clean, if it was not null
        customParentView = null;

        // Remove view from global list
        _allViews.splice(_allViews.indexOf(this), 1);

    }

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

    }

    /** Auto compute size from constraints and `viewWidth`/`viewHeight`.
        @param applyComputedSize if `true`, apply the computed size to the view. */
    inline public function autoComputeSize(applyComputedSize:Bool = false):Void {

        computeSize(0, 0, ViewLayoutMask.FLEXIBLE, true);
        if (applyComputedSize) this.applyComputedSize();

    }

    /** Auto compute size (if needed) from constraints and `viewWidth`/`viewHeight`.
        @param applyComputedSize if `true`, apply the computed size to the view. */
    inline public function autoComputeSizeIfNeeded(applyComputedSize:Bool = false):Void {

        computeSizeIfNeeded(0, 0, ViewLayoutMask.FLEXIBLE, true);
        if (applyComputedSize) this.applyComputedSize();

    }

    /** Apply the computed size to the view.
        This is equivalent to `size(computedWidth, computedHeight)` */
    inline public function applyComputedSize():Void {

        size(computedWidth, computedHeight);

    }

    /** Compute size with intrinsic bounds, allowing to scale the bounds to fit current layout constraints.
        Typically used to compute image size with _scale to fit_ requirements and similar */
    public function computeSizeWithIntrinsicBounds(parentWidth:Float, parentHeight:Float, layoutMask:ViewLayoutMask, persist:Bool, intrinsicWidth:Float, intrinsicHeight:Float):Float {

        var shouldComputeWidth = false;
        var shouldComputeHeight = false;

        var paddedParentWidth = parentWidth - paddingLeft - paddingRight;
        var paddedParentHeight = parentHeight - paddingTop - paddingBottom;

        var appliedScale = 1.0;
        var hasExplicitWidth = !ViewSize.isAuto(viewWidth);
        var hasExplicitHeight = !ViewSize.isAuto(viewHeight);

        // Force fixed width if not flexible
        if (!hasExplicitWidth) {
            if (!layoutMask.canIncreaseWidth()) {
                if (computedWidth > paddedParentWidth) {
                    computedWidth = paddedParentWidth;
                }
            }
            if (!layoutMask.canDecreaseWidth()) {
                if (computedWidth < paddedParentWidth) {
                    computedWidth = paddedParentWidth;
                }
            }
        }

        // Force fixed height if not flexible
        if (!hasExplicitHeight) {
            if (!layoutMask.canIncreaseHeight()) {
                if (computedHeight > paddedParentHeight) {
                    computedHeight = paddedParentHeight;
                }
            }
            if (!layoutMask.canDecreaseHeight()) {
                if (computedHeight < paddedParentHeight) {
                    computedHeight = paddedParentHeight;
                }
            }
        }

        // Update size from intrinsic bounds
        if (intrinsicWidth > 0 && intrinsicHeight > 0) {

            if (!hasExplicitWidth && !hasExplicitHeight) {
                // Width and heigh are both implicit
                
                var newWidth = computedHeight * intrinsicWidth / intrinsicHeight;
                if (newWidth > computedWidth && layoutMask.canIncreaseWidth()) {
                    computedWidth = newWidth;
                }
                else if (newWidth < computedWidth && layoutMask.canDecreaseWidth()) {
                    computedWidth = newWidth;
                }
            
                var newHeight = computedWidth * intrinsicHeight / intrinsicWidth;
                if (newHeight > computedHeight && layoutMask.canIncreaseHeight()) {
                    computedHeight = newHeight;
                }
                else if (newHeight < computedHeight && layoutMask.canDecreaseHeight()) {
                    computedHeight = newHeight;
                }
            }
            else {
                if (hasExplicitWidth && !hasExplicitHeight) {

                    // Remove padding for calculations
                    computedHeight -= paddingTop + paddingBottom;

                    // Width is explicit, height is implicit
                    var newHeight = computedWidth * intrinsicHeight / intrinsicWidth;
                    if (newHeight > computedHeight && layoutMask.canIncreaseHeight()) {
                        computedHeight = newHeight;
                    }
                    else if (newHeight < computedHeight && layoutMask.canDecreaseHeight()) {
                        computedHeight = newHeight;
                    }
                }
                else if (!hasExplicitWidth && hasExplicitHeight) {

                    // Remove padding for calculations
                    computedWidth -= paddingLeft + paddingRight;

                    // Width is implicit, height is explicit
                    var newWidth = computedHeight * intrinsicWidth / intrinsicHeight;
                    if (newWidth > computedWidth && layoutMask.canIncreaseWidth()) {
                        computedWidth = newWidth;
                    }
                    else if (newWidth < computedWidth && layoutMask.canDecreaseWidth()) {
                        computedWidth = newWidth;
                    }
                }
                else if (hasExplicitWidth && hasExplicitHeight) {

                    // Remove padding for calculations
                    computedWidth -= paddingLeft + paddingRight;
                    computedHeight -= paddingTop + paddingBottom;

                }
            }

            appliedScale = Math.min(computedWidth / intrinsicWidth, computedHeight / intrinsicHeight);

            // Add padding
            computedWidth += paddingLeft + paddingRight;
            computedHeight += paddingTop + paddingBottom;

        }

        if (persist) {
            persistComputedSizeWithContext(parentWidth, parentHeight, layoutMask);
        }

        return appliedScale;

    }

    inline public function computeSizeIfNeeded(parentWidth:Float, parentHeight:Float, layoutMask:ViewLayoutMask, persist:Bool):Void {

        if (hasPersistentComputedSizeWithContext(parentWidth, parentHeight, layoutMask)) {
            computedWidth = persistedComputedWidth;
            computedHeight = persistedComputedHeight;
        }
        else {
            computeSize(parentWidth, parentHeight, layoutMask, persist);
        }

    }

    public function computeSize(parentWidth:Float, parentHeight:Float, layoutMask:ViewLayoutMask, persist:Bool):Void {

        // Compute width
        if (ViewSize.isAuto(viewWidth)) {
            if (layoutMask.canDecreaseWidth()) {
                computedWidth = 0;
            } else {
                computedWidth = parentWidth;
            }
        }
        else if (ViewSize.isFill(viewWidth)) {
            computedWidth = parentWidth;
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

        if (persist) {
            persistComputedSizeWithContext(parentWidth, parentHeight, layoutMask);
        }

    }

    inline function willEmitLayout():Void {

        updateBorder();
        layout();

    }

    function layout():Void {

        // Override in subclasses

    }

/// On-demand explicit layout

    public static function requestLayout():Void {

        if (_layoutRequested) {
            return;
        }

        _layoutRequested = true;

        if (_layouting) {
            return;
        }

        app.oncePostFlushImmediate(function() {
            _updateViewsLayout(0.0);
        });

    }

/// Internal

    static var _layoutRequested:Bool = false;

    static var _layouting:Bool = false;

    static var _allViews:Array<View> = null;

    static function _updateViewsLayout(_):Void {

        _layoutRequested = false;
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

            // Reset computed sizes
            // TODO: only reset computed size of views that match these conditions:
            //  - view width or height depends on a parent size that has its layout dirty
            //  - view's own layout is dirty
            for (i in 0..._allViews.length) {
                var view = _allViews.unsafeGet(i);
                view.resetComputedSize();
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
        if (_layoutRequested) {
            app.oncePostFlushImmediate(function() {
                _updateViewsLayout(0.0);
            });
        }

    }

    inline static function _markParentsAsLayoutDirty(view:View):Void {

        if (view.layoutDirty) {
            var root = view;

            var parentView = root.parentView;
            while (parentView != null) {
                root = parentView;
                root.layoutDirty = true;
                parentView = root.parentView;
            }
        }

    }

    static function _layoutParentThenSelf(view:View):Void {

        var parentView = view.parentView;
        if (parentView != null) {
            _layoutParentThenSelf(parentView);
        }

        if (view.layoutDirty && view.canLayout) {
            view.emitLayout();
            view.layoutDirty = false;
        }

    }

/// Screen size helpers

    /** Will set this view size to screen size, and update view size each time screen size changes. */
    public function bindToScreenSize():Void {

        // Bind to screen size
        screen.onResize(this, function() {
            size(screen.width, screen.height);
            View.requestLayout();
        });
        size(screen.width, screen.height);
        View.requestLayout();

    }

/// View size helpers

    inline public function percent(value:Float):Float {

        return ViewSize.percent(value);

    }

    inline public function percentToFloat(encoded:Float):Float {

        return ViewSize.percentToFloat(encoded);

    }

    inline public function fill():Float {

        return ViewSize.fill();

    }

    inline public function auto():Float {

        return ViewSize.auto();

    }

}
