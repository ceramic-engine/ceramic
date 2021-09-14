package elements;

import ceramic.Click;
import ceramic.ColumnLayout;
import ceramic.DoubleClick;
import ceramic.Point;
import ceramic.RowLayout;
import ceramic.Shortcuts.*;
import ceramic.TextView;
import ceramic.TouchInfo;
import ceramic.Triangle;
import ceramic.View;
import elements.Context.context;
import tracker.Observable;

class Window extends ColumnLayout implements Observable {

    static final FONT_PRE_RENDERED_SIZE:Int = 20;

    static final HEADER_HEIGHT:Int = 18;

    static final TITLE_TEXT_SIZE:Int = 12;

    static final DEFAULT_X:Int = 20;

    static final DEFAULT_Y:Int = 20;

    static final DRAG_THRESHOLD:Int = 4;

    static var _point = new Point(0, 0);

    @observe public var contentView:View = null;

    @observe public var title:String = null;

    @event function expandCollapseClick();

    @event function headerDoubleClick();

    var headerView:RowLayout;

    var expandCollapseClick:Click;

    var headerViewDoubleClick:DoubleClick;

    var bodyView:ColumnLayout;

    var titleView:TextView;

    var expandView:View;

    var expandTriangle:Triangle;

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
            expandTriangle = new Triangle();
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
        titleView.content = '';
        headerView.add(titleView);

        bodyView = new ColumnLayout();
        bodyView.transparent = false;
        bodyView.viewSize(percent(100), 0);
        add(bodyView);

        onContentViewChange(this, contentViewChange);
        onTitleChange(this, titleChange);

        autorun(updateStyle);

        onPointerDown(this, _ -> {});
        onPointerOver(this, _ -> {});

    }

    var windowPosStartX:Float = 0;
    var windowPosStartY:Float = 0;
    var dragPointerStartX:Float = 0;
    var dragPointerStartY:Float = 0;
    var dragging:Bool = false;

    function headerDown(info:TouchInfo):Void {

        windowPosStartX = this.x;
        windowPosStartY = this.y;

        context.view.screenToVisual(info.x, info.y, _point);
        dragPointerStartX = _point.x;
        dragPointerStartY = _point.y;

        screen.onPointerMove(this, headerMove);
        screen.oncePointerUp(this, headerUp);

    }

    function headerMove(info:TouchInfo):Void {

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
                windowPosStartX + diffX,
                windowPosStartY + diffY
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
                prevContentView.destroy();
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

    function updateStyle() {

        var theme = context.theme;

        headerView.color = theme.mediumBackgroundColor;

        bodyView.color = theme.windowBackgroundColor;
        bodyView.alpha = theme.windowBackgroundAlpha;

        expandTriangle.color = theme.lightTextColor;
        titleView.textColor = theme.lightTextColor;

        borderColor = theme.windowBorderColor;
        borderAlpha = theme.windowBorderAlpha;

        titleView.font = theme.mediumFont;

    }

}
