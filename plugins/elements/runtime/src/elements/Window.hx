package elements;

import ceramic.AntialiasedTriangle;
import ceramic.Click;
import ceramic.ColumnLayout;
import ceramic.DoubleClick;
import ceramic.Point;
import ceramic.Quad;
import ceramic.RowLayout;
import ceramic.ScrollView;
import ceramic.Shortcuts.*;
import ceramic.TextAlign;
import ceramic.TextView;
import ceramic.TouchInfo;
import ceramic.View;
import elements.Context.context;
import tracker.Observable;

/**
 * A draggable window container for UI elements.
 * 
 * Provides a standard window interface with:
 * - Draggable header bar
 * - Optional title text
 * - Expand/collapse functionality
 * - Close button support
 * - Automatic state persistence (position, size, collapsed state)
 * - Theme customization
 * - Content scrolling support
 * 
 * Windows automatically save their state to the Context's user data
 * and restore it when recreated with the same ID.
 * 
 * @see Context
 * @see WindowData
 * @see ColumnLayout
 */
class Window extends ColumnLayout implements Observable {

    /** Height of the window header bar in pixels */
    public static final HEADER_HEIGHT:Int = 18;

    /** Pre-rendered font size for title text */
    static final FONT_PRE_RENDERED_SIZE:Int = 20;

    /** Display size for title text */
    static final TITLE_TEXT_SIZE:Int = 12;

    /** Default X position for new windows */
    static final DEFAULT_X:Int = 20;

    /** Default Y position for new windows */
    static final DEFAULT_Y:Int = 20;

    /** Minimum drag distance to start window movement */
    static final DRAG_THRESHOLD:Int = 4;

    /** Shared point instance for coordinate calculations */
    static var _point = new Point(0, 0);

    /** Custom theme override for this window */
    @observe public var theme:Theme = null;

    /** The main content view displayed in the window body */
    @observe public var contentView:View = null;

    /** Title text displayed in the window header */
    @observe public var title:String = null;

    /** Whether the window shows a close button */
    @observe public var closable:Bool = false;

    /** Whether the window can be collapsed/expanded */
    @observe public var collapsible:Bool = true;

    /** Whether to show the window header bar */
    @observe public var header:Bool = true;

    /** Alignment of the title text in the header */
    @observe public var titleAlign:TextAlign = LEFT;

    /**
     * Computed property that returns true if the content view is scrollable.
     * 
     * @return True if contentView is a ScrollView
     */
    @compute public function scrolls():Bool {
        var contentView = this.contentView;
        return (contentView != null && contentView is ScrollView);
    }

    /** Whether the window can be dragged by its header */
    public var movable:Bool = true;

    /** Optional overlay quad for modal behavior */
    public var overlay:Quad = null;

    /** Emitted when the expand/collapse button is clicked */
    @event function expandCollapseClick();

    /** Emitted when the header is double-clicked */
    @event function headerDoubleClick();

    /** Emitted when the close button is clicked */
    @event function close();

    var headerView:RowLayout;

    var expandCollapseClick:Click;

    var headerViewDoubleClick:DoubleClick;

    var closeClick:Click;

    var bodyView:ColumnLayout;

    var titleView:TextView;

    var expandView:View;

    var expandTriangle:AntialiasedTriangle;

    var closeView:View;

    var closeCross:CrossX;

    /**
     * Creates a new Window with default styling and behavior.
     * Sets up the header, body, and interaction handlers.
     */
    public function new() {

        super();

        borderDepth = 10;
        borderPosition = INSIDE;
        borderSize = 1;

        pos(DEFAULT_X, DEFAULT_Y);

        headerView = new RowLayout();
        headerView.transparent = false;
        headerView.viewSize(percent(100), HEADER_HEIGHT);
        headerView.onPointerDown(this, headerDown);
        headerViewDoubleClick = new DoubleClick();
        headerViewDoubleClick.onDoubleClick(this, emitHeaderDoubleClick);
        headerView.component('doubleClick', headerViewDoubleClick);
        add(headerView);

        expandView = new View();
        expandView.transparent = true;
        {
            var triangleW = HEADER_HEIGHT * 0.5;
            var triangleH = HEADER_HEIGHT * 0.4;
            expandTriangle = new AntialiasedTriangle();
            expandTriangle.anchor(0.5, 0.5);
            expandTriangle.size(triangleW, triangleH);
            expandTriangle.pos(HEADER_HEIGHT * 0.5, HEADER_HEIGHT * 0.5);
            expandTriangle.rotation = 90;
            expandView.add(expandTriangle);
        }
        expandView.viewSize(HEADER_HEIGHT, HEADER_HEIGHT);
        expandCollapseClick = new Click();
        expandCollapseClick.onClick(this, emitExpandCollapseClick);
        expandView.component('click', expandCollapseClick);
        headerView.add(expandView);

        titleView = new TextView();
        titleView.verticalAlign = CENTER;
        titleView.pointSize = TITLE_TEXT_SIZE;
        titleView.preRenderedSize = FONT_PRE_RENDERED_SIZE;
        titleView.viewSize(fill(), fill());
        titleView.align = titleAlign;
        titleView.content = '';
        titleView.paddingLeft = 5;
        headerView.add(titleView);

        closeView = new View();
        closeView.transparent = true;
        {
            var crossW = 14;
            var crossH = 14;
            closeCross = new CrossX();
            closeCross.anchor(0.5, 0.5);
            closeCross.size(crossW, crossH);
            closeCross.pos(HEADER_HEIGHT * 0.5, HEADER_HEIGHT * 0.5);
            closeView.add(closeCross);
        }
        closeView.viewSize(HEADER_HEIGHT, HEADER_HEIGHT);
        closeClick = new Click();
        closeClick.onClick(this, emitClose);
        closeView.component('click', closeClick);
        closeView.active = closable;
        headerView.add(closeView);

        bodyView = new ColumnLayout();
        bodyView.viewSize(percent(100), 0);
        add(bodyView);

        onContentViewChange(this, contentViewChange);
        onTitleChange(this, titleChange);
        onTitleAlignChange(this, titleAlignChange);
        onClosableChange(this, closableChange);
        onCollapsibleChange(this, collapsibleChange);
        onHeaderChange(this, headerChange);

        autorun(updateStyle);

        onPointerDown(this, _ -> {});
        onPointerOver(this, _ -> {});

    }

    override function destroy() {

        if (overlay != null) {
            overlay.destroy();
            overlay = null;
        }

        super.destroy();

    }

    var windowPosStartX:Float = 0;
    var windowPosStartY:Float = 0;
    var dragPointerStartX:Float = 0;
    var dragPointerStartY:Float = 0;
    var dragging:Bool = false;

    function headerDown(info:TouchInfo):Void {

        if (!movable)
            return;

        windowPosStartX = this.x;
        windowPosStartY = this.y;

        context.view.screenToVisual(info.x, info.y, _point);
        dragPointerStartX = _point.x;
        dragPointerStartY = _point.y;

        screen.onPointerMove(this, headerMove);
        screen.oncePointerUp(this, headerUp);

    }

    function headerMove(info:TouchInfo):Void {

        if (!movable) {
            if (dragging)
                dragging = false;
            return;
        }

        context.view.screenToVisual(info.x, info.y, _point);
        var diffX = _point.x - dragPointerStartX;
        var diffY = _point.y - dragPointerStartY;

        if (!dragging) {
            if (diffX > DRAG_THRESHOLD || -diffX > DRAG_THRESHOLD || diffY > DRAG_THRESHOLD || -diffY > DRAG_THRESHOLD) {
                dragging = true;
                headerViewDoubleClick.cancel();
                expandCollapseClick.cancel();
            }
        }

        if (dragging) {
            pos(
                Math.round(windowPosStartX + diffX),
                Math.round(windowPosStartY + diffY)
            );
        }

    }

    function headerUp(info:TouchInfo):Void {

        dragging = false;
        screen.offPointerMove(headerMove);

    }

    function contentViewChange(contentView:View, prevContentView:View):Void {

        if (prevContentView != contentView) {
            if (prevContentView != null) {
                if (contentView == null || !prevContentView.hasIndirectParent(contentView)) {
                    // We don't destroy previous content view if it's still
                    // a child of the newly assigned content view.
                    prevContentView.destroy();
                }
            }
            prevContentView = contentView;

            if (contentView != null) {
                bodyView.add(contentView);
                expandTriangle.rotation = 180;
            }
            else {
                expandTriangle.rotation = 90;
            }
        }

    }

    function titleChange(title:String, prevTitle:String):Void {

        if (title != prevTitle) {
            if (title != null) {
                titleView.content = title;
            }
            else {
                titleView.content = '';
            }
        }

    }

    function titleAlignChange(titleAlign:TextAlign, prevTitleAlign:TextAlign):Void {

        titleView.align = titleAlign;

        if (closable) {
            titleView.paddingRight = titleAlign == CENTER ? -closeView.viewWidth.toFloat() * 0.5 : 0;
        }
        else {
            titleView.paddingRight = titleAlign == RIGHT ? 5 : 0;
        }

        if (collapsible) {
            titleView.paddingLeft = titleAlign == CENTER ? -expandView.viewWidth.toFloat() * 0.5 : 0;
        }
        else {
            titleView.paddingLeft = titleAlign == LEFT ? 5 : 0;
        }

    }

    function closableChange(closable:Bool, prevClosable:Bool):Void {

        if (closable) {
            closeView.active = true;
            titleView.paddingRight = titleAlign == CENTER ? -closeView.viewWidth.toFloat() * 0.5 : 0;
        }
        else {
            closeView.active = false;
            titleView.paddingRight = titleAlign == RIGHT ? 5 : 0;
        }

    }

    function collapsibleChange(collapsible:Bool, prevCollapsible:Bool):Void {

        if (collapsible) {
            expandView.active = true;
            titleView.paddingLeft = titleAlign == CENTER ? -expandView.viewWidth.toFloat() * 0.5 : 0;
        }
        else {
            expandView.active = false;
            titleView.paddingLeft = titleAlign == LEFT ? 5 : 0;
        }

    }

    function headerChange(header:Bool, prevHeader:Bool):Void {

        if (header != prevHeader) {
            if (headerView != null) {
                headerView.active = header;
            }
        }

    }

    function updateStyle() {

        var theme = this.theme;
        if (theme == null)
            theme = context.theme;

        headerView.color = theme.mediumBackgroundColor;

        if (theme.backgroundInFormLayout) {
            bodyView.transparent = true;
            bodyView.alpha = 1;
        }
        else {
            bodyView.transparent = false;
            bodyView.color = theme.windowBackgroundColor;
            bodyView.alpha = theme.windowBackgroundAlpha;
        }

        expandTriangle.color = theme.lightTextColor;
        titleView.textColor = theme.lightTextColor;

        borderColor = theme.windowBorderColor;
        borderAlpha = theme.windowBorderAlpha;

        titleView.font = theme.mediumFont;

    }

}
