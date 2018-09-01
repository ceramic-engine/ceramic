package ceramic.ui;

import ceramic.Shortcuts.*;

class View extends Quad {

/// Events

    @event function layout_();

/// Properties

    public var layoutMask:ViewLayoutMask = ViewLayoutMask.FIXED;

    /** Setting this to `false` will prevent this view from updating its layout.
        Default is `true` */
    public var canLayout:Bool;

    public var layoutDirty(default,set):Bool = true;
    function set_layoutDirty(layoutDirty:Bool):Bool {
        this.layoutDirty = layoutDirty;
        if (layoutDirty) {
            if (children != null) {
                for (child in children) {
                    if (Std.is(child, View)) {
                        var view:View = cast child;
                        view.layoutDirty = true;
                    }
                }
            }
        }
        return layoutDirty;
    }

/// Overrides

    override function set_width(width:Float):Float {
        if (_width == width) return width;
        _width = width;
        layoutDirty = true;
        return width;
    }

    override function set_height(height:Float):Float {
        if (_height == height) return height;
        _height = height;
        layoutDirty = true;
        return height;
    }

    override function add(visual:Visual):Void {
        super.add(visual);
        if (Std.is(visual,View)) {
            var view:View = cast visual;
            view.layoutDirty = true;
        }
        layoutDirty = true;
    }

    override function remove(visual:Visual):Void {
        super.remove(visual);
        if (Std.is(visual,View)) {
            var view:View = cast visual;
            view.layoutDirty = true;
        }
        layoutDirty = true;
    }

    /** Creates a new `Autorun` instance with the given callback associated with the current entity.
        @param run The run callback
        @return The autorun instance */
    override function autorun(run:Void->Void):Autorun {

        return super.autorun(function() {
            run();
            layoutDirty = true;
            requestLayout();
        });

    } //autorun

/// Lifecycle

    public function new() {

        super();

        depthRange = 1;
        canLayout = false;

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

    inline function willEmitLayout():Void {

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

        var toUpdate:Array<View> = null;

        // Gather views to update first
        for (view in _allViews) {
            if (view.layoutDirty) {
                // TODO avoid allocation of array?
                if (toUpdate == null) toUpdate = [];
                toUpdate.push(view);
            }
        }

        // Then emit layout event by starting from the top-level views
        if (toUpdate != null) {
            for (view in toUpdate) {
                _layoutParentThenSelf(view);
            }
        }

        _layouting = false;

    } //updateViewLayouts

    static function _layoutParentThenSelf(view:View):Void {

        if (view.parent != null && Std.is(view.parent, View)) {
            _layoutParentThenSelf(cast view.parent);
        }

        if (view.layoutDirty && view.canLayout) {
            view.emitLayout();
            view.layoutDirty = false;
        }

    } //layoutParentThenSelf

} //View
