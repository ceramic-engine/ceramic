package ceramic;

import ceramic.Shortcuts.*;
import tracker.Autorun;

using ceramic.Extensions;

class View extends Layer {

/// Events

    @event function layout_();

/// Properties

    /**
     * Same as `children` but typed as a list of `View` instances instead of `Visual` (thus only contains children that are of `View` type).
     */
    public var subviews:ReadOnlyArray<View> = null;

    /**
     * ComputedSize after being computed by View layout engine from constraints and `viewWidth`/`viewHeight`
     */
    public var computedSize:ComputedViewSize = null;

    /**
     * Width that will be processed by View layout engine. Can be a numeric value, a percentage (with `ViewSize.percent()`), automatic (with `ViewSize.fill()`) or undefined (with `ViewSize.none()`).
     */
    public var viewWidth(default,set):ViewSize = ViewSize.auto();
    function set_viewWidth(viewWidth:ViewSize):ViewSize {
        if (this.viewWidth == viewWidth) return viewWidth;
        this.viewWidth = viewWidth;
        layoutDirty = true;
        return viewWidth;
    }

    /**
     * Height that will be processed by View layout engine. Can be a numeric value, a percentage (with `ViewSize.percent()`), automatic (with `ViewSize.fill()`) or undefined (with `ViewSize.none()`).
     */
    public var viewHeight(default,set):ViewSize = ViewSize.auto();
    function set_viewHeight(viewHeight:ViewSize):ViewSize {
        if (this.viewHeight == viewHeight) return viewHeight;
        this.viewHeight = viewHeight;
        layoutDirty = true;
        return viewHeight;
    }

    /**
     * Set `viewWidth` and `viewHeight`
     */
    inline public function viewSize(width:ViewSize, height:ViewSize) {
        viewWidth = width;
        viewHeight = height;
    }

    /**
     * Set padding. Order and number of parameters following CSS padding convention.
     * Examples:
     * ```
     * padding(10) // top=10, right=10, bottom=10, left=10
     * padding(3, 5) // top=3, right=5, bottom=3, left=5
     * padding(3, 5, 8, 4) // top=3, right=5, bottom=8, left=4
     * ```
     */
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

    /**
     * Offset this view position by `x` and `y`.
     * This offset is added to the view's resulting position
     * from its default layout. This has only effect when the view is layouted
     * by a layout class that handle offsets: `LinearLayout`, `LayersLayout`
     */
    inline public function offset(x:Float, y:Float):Void {
        offsetX = x;
        offsetY = y;
    }

    /**
     * Offset this view position by `offsetX`.
     * This offset is added to the view's resulting position
     * from its default layout. This has only effect when the view is layouted
     * by a layout class that handle offsets: `LinearLayout`, `LayersLayout`
     */
    public var offsetX(default,set):Float = 0;
    function set_offsetX(offsetX:Float):Float {
        if (this.offsetX == offsetX) return offsetX;
        this.offsetX = offsetX;
        layoutDirty = true;
        return offsetX;
    }

    /**
     * Offset this view position by `offsetY`.
     * This offset is added to the view's resulting position
     * from its default layout. This has only effect when the view is layouted
     * by a layout class that handle offsets: `LinearLayout`, `LayersLayout`
     */
    public var offsetY(default,set):Float = 0;
    function set_offsetY(offsetY:Float):Float {
        if (this.offsetY == offsetY) return offsetY;
        this.offsetY = offsetY;
        layoutDirty = true;
        return offsetY;
    }

    /**
     * A hint to tell how much space this view should take,
     *     relative to the space taken by a whole group of views.
     *     Example:
     *
     *         view1.flex = 1; // Fills 1/3 of available space
     *         view2.flex = 2; // Fills 2/3 of available space
     */
    public var flex(default,set):Int = 1;
    inline function set_flex(flex:Int):Int {
        if (this.flex == flex) return flex;
        this.flex = flex;
        layoutDirty = true;
        return flex;
    }

    /**
     * Setting this to `false` will prevent this view from updating its layout.
     * Default is `true`
     */
    public var canLayout:Bool;

    #if ceramic_debug_layout_dirty
    static var _lastLayoutDirtyFrame:Int = -1;
    public var layoutDirty(default,set):Bool = true;
    function set_layoutDirty(layoutDirty:Bool):Bool {
        if (this.layoutDirty != layoutDirty) {
            this.layoutDirty = layoutDirty;
            if (layoutDirty && ceramic.Shortcuts.app.frame != _lastLayoutDirtyFrame) {
                _lastLayoutDirtyFrame = ceramic.Shortcuts.app.frame;
                ceramic.Utils.printStackTrace();
                ceramic.Shortcuts.log.debug('layoutDirty ($_lastLayoutDirtyFrame)');
            }
        }
        return layoutDirty;
    }
    #else
    public var layoutDirty:Bool = true;
    #end

/// Border

    var border:Border = null;

    public var borderDepth(default,set):Float = 0;
    inline function set_borderDepth(borderDepth:Float):Float {
        if (this.borderDepth == borderDepth) return borderDepth;
        this.borderDepth = borderDepth;
        if (border != null) border.depth = borderDepth;
        return borderDepth;
    }

    public var borderAlpha(default,set):Float = 1;
    inline function set_borderAlpha(borderAlpha:Float):Float {
        if (this.borderAlpha == borderAlpha) return borderAlpha;
        this.borderAlpha = borderAlpha;
        if (border != null) border.alpha = borderAlpha;
        return borderAlpha;
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
            border.alpha = borderAlpha;
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
            if (border != null) {
                border.destroy();
                border = null;
            }
        }

    }

/// Computed size context

    var persistedComputedSizes:Array<ComputedViewSize> = [];

    #if !ceramic_soft_inline inline #end function persistedComputedSizeForContext(parentWidth:Float, parentHeight:Float, parentLayoutMask:ViewLayoutMask):Null<ComputedViewSize> {

        var result = null;

        if (computedSize != null && computedSize.parentWidth == parentWidth && computedSize.parentHeight == parentHeight && computedSize.parentLayoutMask == parentLayoutMask) {
            result = computedSize;
        }
        else {
            for (i in 0...persistedComputedSizes.length) {
                final computedSize = persistedComputedSizes.unsafeGet(i);
                if (computedSize.parentWidth == parentWidth && computedSize.parentHeight == parentHeight && computedSize.parentLayoutMask == parentLayoutMask) {
                    result = computedSize;
                    break;
                }
            }
        }

        return result;

    }

    #if !ceramic_soft_inline inline #end public function persistComputedSize(parentWidth:Float, parentHeight:Float, parentLayoutMask:ViewLayoutMask, computedWidth:Float, computedHeight:Float):ComputedViewSize {

        if (computedWidth != ComputedViewSize.NO_SIZE && computedHeight != ComputedViewSize.NO_SIZE) {
            var computedSize = persistedComputedSizeForContext(parentWidth, parentHeight, parentLayoutMask);
            if (computedSize == null) {
                computedSize = ComputedViewSize.get();
                computedSize.parentWidth = parentWidth;
                computedSize.parentHeight = parentHeight;
                computedSize.parentLayoutMask = parentLayoutMask;
            }
            computedSize.computedWidth = computedWidth;
            computedSize.computedHeight = computedHeight;
            this.computedSize = computedSize;
        }

        var prevComputedSize = this.computedSize;
        if (prevComputedSize.parentWidth == ComputedViewSize.NO_SIZE && prevComputedSize.parentHeight == ComputedViewSize.NO_SIZE) {
            prevComputedSize.recycle();
        }

        return this.computedSize;

    }

    #if !ceramic_soft_inline inline #end public function assignComputedSize(computedWidth:Float, computedHeight:Float):ComputedViewSize {

        var computedSize = this.computedSize;
        if (computedSize == null || computedSize.parentWidth != ComputedViewSize.NO_SIZE && computedSize.parentHeight != ComputedViewSize.NO_SIZE) {
            computedSize = ComputedViewSize.get();
        }

        computedSize.parentWidth = ComputedViewSize.NO_SIZE;
        computedSize.parentHeight = ComputedViewSize.NO_SIZE;
        computedSize.computedWidth = computedWidth;
        computedSize.computedHeight = computedHeight;

        this.computedSize = computedSize;

        return computedSize;

    }

    #if !ceramic_soft_inline inline #end public function hasPersistentComputedSizeWithContext(parentWidth:Float, parentHeight:Float, parentLayoutMask:ViewLayoutMask):Bool {

        var computedSize = persistedComputedSizeForContext(parentWidth, parentHeight, parentLayoutMask);
        return computedSize != null;

    }

    #if !ceramic_soft_inline inline #end public function resetComputedSize(recursive:Bool = false):Void {

        computedSize = null;

        while (persistedComputedSizes.length > 0) {
            persistedComputedSizes.pop().recycle();
        }

        if (recursive) {
            if (subviews != null) {
                for (i in 0...subviews.length) {
                    subviews[i].resetComputedSize(true);
                }
            }
        }

    }

    #if !ceramic_soft_inline inline #end public function shouldResetComputedSize():Bool {

        var shouldReset = false;

        if (layoutDirty) {
            shouldReset = true;
        }
        else {
            var parentView = this.parentView;
            while (parentView != null) {
                if (parentView.layoutDirty) {
                    shouldReset = true;
                    break;
                }
                parentView = parentView.parentView;
            }
        }

        return shouldReset;

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
        if (!sizeDirty) {
            sizeDirty = true;
            app.onceImmediate(emitResizeIfNeeded);
        }
        return width;
    }

    override function set_height(height:Float):Float {
        if (_height == height) return height;
        _height = height;
        layoutDirty = true;
        if (anchorY != 0) matrixDirty = true;
        if (borderSize > 0) updateBorder();
        if (!sizeDirty) {
            sizeDirty = true;
            app.onceImmediate(emitResizeIfNeeded);
        }
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
        if (Std.isOfType(visual,View)) {
            var view:View = cast visual;
            if (subviews == null) {
                subviews = [];
            }
            @:privateAccess subviews.original.push(view);
            view.layoutDirty = true;
        }
        layoutDirty = true;
    }

    override function remove(visual:Visual):Void {
        super.remove(visual);
        if (Std.isOfType(visual,View)) {
            var view:View = cast visual;
            @:privateAccess subviews.original.splice(subviews.indexOf(view), 1);
            view.layoutDirty = true;
        }
        layoutDirty = true;
    }

    /**
     * Creates a new `Autorun` instance with the given callback associated with the current entity.
     * @param run The run callback
     * @return The autorun instance
     */
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

    @:noCompletion
    function _immediateAutorunLayout() {

        app.onceImmediate(_autorunLayout);

    }

    @:noCompletion
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
        if (Std.isOfType(parent, View))
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
            ViewSystem.shared.bind();
        }
        _allViews.push(this);

        // Prevent layout from happening too early
        app.onceImmediate(function() {
            if (destroyed)
                return;
            // We use a 2-level onceImmediate call to ensure this
            // will be executed after "standard" `onceImmediate` calls.
            app.oncePostFlushImmediate(function() {
                if (destroyed)
                    return;
                canLayout = true;
                if (layoutDirty) {
                    View.requestLayout();
                }
            });
        });

    }

    override function destroy() {

        // Remove view from global list
        _allViews.splice(_allViews.indexOf(this), 1);

        // Recycle computed size objects
        if (this.persistedComputedSizes != null) {
            var persistedComputedSizes = this.persistedComputedSizes;
            this.persistedComputedSizes = null;
            for (i in 0...persistedComputedSizes.length) {
                persistedComputedSizes.unsafeGet(i).recycle();
            }
        }

        // Parent destroy
        super.destroy();

        // No layout allowed anymore
        canLayout = false;

        // Clean, if it was not null
        customParentView = null;

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

    /**
     * Auto compute size from constraints and `viewWidth`/`viewHeight`.
     * @param applyComputedSize if `true`, apply the computed size to the view.
     */
    inline public function autoComputeSize(applyComputedSize:Bool = false):Void {

        computeSize(0, 0, ViewLayoutMask.FLEXIBLE, true);
        if (applyComputedSize) this.applyComputedSize();

    }

    /**
     * Auto compute size (if needed) from constraints and `viewWidth`/`viewHeight`.
     * @param applyComputedSize if `true`, apply the computed size to the view.
     */
    inline public function autoComputeSizeIfNeeded(applyComputedSize:Bool = false):Void {

        computeSizeIfNeeded(0, 0, ViewLayoutMask.FLEXIBLE, true);
        if (applyComputedSize) this.applyComputedSize();

    }

    /**
     * Apply the computed size to the view.
     * This is equivalent to `size(computedWidth, computedHeight)`
     */
    inline public function applyComputedSize():Void {

        if (computedSize != null) {
            size(computedSize.computedWidth, computedSize.computedHeight);
        }

    }

    /**
     * Compute size with intrinsic bounds, allowing to scale the bounds to fit current layout constraints.
     * Typically used to compute image size with _scale to fit_ requirements and similar
     */
    public function computeSizeWithIntrinsicBounds(parentWidth:Float, parentHeight:Float, layoutMask:ViewLayoutMask, persist:Bool, intrinsicWidth:Float, intrinsicHeight:Float):Float {

        var computedWidth:Float = ComputedViewSize.NO_SIZE;
        var computedHeight:Float = ComputedViewSize.NO_SIZE;

        if (computedSize != null) {
            computedWidth = computedSize.computedWidth;
            computedHeight = computedSize.computedHeight;
        }

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
            persistComputedSize(parentWidth, parentHeight, layoutMask, computedWidth, computedHeight);
        }
        else {
            assignComputedSize(computedWidth, computedHeight);
        }

        return appliedScale;

    }

    inline public function computeSizeIfNeeded(parentWidth:Float, parentHeight:Float, layoutMask:ViewLayoutMask, persist:Bool):Void {

        computedSize = persistedComputedSizeForContext(parentWidth, parentHeight, layoutMask);
        if (computedSize == null) {
            computeSize(parentWidth, parentHeight, layoutMask, persist);
        }

    }

    public function computeSize(parentWidth:Float, parentHeight:Float, layoutMask:ViewLayoutMask, persist:Bool):Void {

        var computedWidth = ComputedViewSize.NO_SIZE;
        var computedHeight = ComputedViewSize.NO_SIZE;

        // As soon as we compute size, layout gets dirty and should be recomputed again,
        // unless the layout mask is fixed or the view has explicit width or height
        if (layoutMask != ViewLayoutMask.FIXED && (!ViewSize.isStandard(viewWidth) || !ViewSize.isStandard(viewHeight)))
            layoutDirty = true;

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
            persistComputedSize(parentWidth, parentHeight, layoutMask, computedWidth, computedHeight);
        }
        else {
            assignComputedSize(computedWidth, computedHeight);
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

    // This code could be moved into ViewSystem at some point, but not critical

    static var _layoutRequested:Bool = false;

    static var _layouting:Bool = false;

    static var _allViews:Array<View> = null;

    @:allow(ceramic.ViewSystem)
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
                if (view.shouldResetComputedSize()) {
                    view.resetComputedSize();
                }
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

    /**
     * Will set this view size to screen size, and update view size each time screen size changes.
     */
    override public function bindToScreenSize(factor:Float = 1.0):Void {

        // Bind to screen size
        screen.onResize(this, function() {
            size(screen.width * factor, screen.height * factor);
            View.requestLayout();
        });
        size(screen.width * factor, screen.height * factor);
        View.requestLayout();

    }

    /**
     * Will set this visual size to target size (`settings.targetWidth` and `settings.targetHeight`),
     * and update view size each time it changes.
     */
    override public function bindToTargetSize():Void {

        // Bind to screen size
        screen.onResize(this, function() {
            size(settings.targetWidth, settings.targetHeight);
            View.requestLayout();
        });
        size(settings.targetWidth, settings.targetHeight);
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
