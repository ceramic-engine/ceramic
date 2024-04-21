package elements;

import ceramic.Click;
import ceramic.Color;
import ceramic.ColumnLayout;
import ceramic.LayersLayout;
import ceramic.Point;
import ceramic.RowLayout;
import ceramic.Scroller;
import ceramic.Shortcuts.*;
import ceramic.TextView;
import ceramic.Transform;
import ceramic.Transform;
import ceramic.View;
import ceramic.ViewLayoutMask;
import ceramic.Visual;
import elements.Context.context;
import elements.DragDrop;
import tracker.Autorun.reobserve;
import tracker.Autorun.unobserve;
import tracker.Observable;

using StringTools;
using ceramic.VisualTransition;
using elements.Tooltip;

class CellView extends LayersLayout implements Observable {

    static var _notVisibleTransform:Transform = null;

    static var _point:Point = new Point(0, 0);

    @observe public var theme:Theme = null;

/// Public properties

    @observe public var selected:Bool = false;

    @observe public var title:String = null;

    @observe public var subTitle:String = null;

    @observe public var itemIndex(default, set):Int = -1;
    function set_itemIndex(itemIndex:Int):Int {
        if (this.itemIndex != itemIndex) {
            this.itemIndex = itemIndex;
            hover = false;
        }
        return itemIndex;
    }

    @observe public var collectionView:CellCollectionView = null;

    @observe public var inputStyle:Bool = false;

    @observe public var displaysEmptyValue:Bool = false;

    @observe public var locked:Bool = false;

    @observe public var kindIcon:Null<Entypo> = null;

    @observe public var handleTrash:Void->Void = null;

    @observe public var handleLock:Void->Void = null;

    @observe public var handleDuplicate:Void->Void = null;

    @observe public var dragging(default, null):Bool = false;

/// Internal

    var titleTextView:TextView;

    var subTitleTextView:TextView;

    var clearScrollDelay:Void->Void = null;

    var columnLayout:ColumnLayout;

    var iconsView:RowLayout = null;

    var dragTargetTy:Float = 0;

    var dragDrop:DragDrop;

    var dragAutoScroll:Float = 0;

    var dragStartScrollY:Float = 0;

    var draggingCellDragY:Float = 0;

    var draggingCell:CellView = null;

    var dragOnItemIndex:Int = -1;

    @observe var clonedForDragging:Bool = false;

    @observe var hover:Bool = false;

    @observe var appliedHoverItemIndex:Int = -1;

/// Lifecycle

    public function new() {

        super();

        columnLayout = new ColumnLayout();
        columnLayout.align = CENTER;
        columnLayout.itemSpacing = 1;
        columnLayout.viewSize(fill(), auto());
        add(columnLayout);

        borderBottomSize = 1;
        borderPosition = INSIDE;
        borderDepth = 2;
        transparent = false;

        titleTextView = new TextView();
        titleTextView.align = LEFT;
        titleTextView.pointSize = 12;
        titleTextView.preRenderedSize = 20;
        titleTextView.noFitWidth = true;
        titleTextView.viewSize(fill(), auto());
        titleTextView.onLayout(this, layoutTitle);
        columnLayout.add(titleTextView);

        subTitleTextView = new TextView();
        subTitleTextView.align = LEFT;
        subTitleTextView.pointSize = 11;
        subTitleTextView.preRenderedSize = 20;
        subTitleTextView.noFitWidth = true;
        subTitleTextView.paddingLeft = 1;
        subTitleTextView.viewSize(fill(), auto());
        subTitleTextView.text.component('italicText', new ItalicText());
        subTitleTextView.onLayout(this, layoutSubTitle);
        columnLayout.add(subTitleTextView);

        autorun(updateTitle);
        autorun(updateSubTitle);
        autorun(updateStyle);
        autorun(updateIcons);

        onPointerOver(this, function(_) hover = true);
        onPointerOut(this, function(_) hover = false);

    }

    function updateTitle() {

        var title = this.title;
        if (title != null) {
            titleTextView.content = title;
            titleTextView.active = true;
        }
        else {
            titleTextView.content = '';
            titleTextView.active = false;
        }

    }

    function updateSubTitle() {

        var subTitle = this.subTitle;
        if (subTitle != null) {
            subTitleTextView.content = subTitle;
            subTitleTextView.active = true;
        }
        else {
            subTitleTextView.content = '';
            subTitleTextView.active = false;
        }

    }

    function layoutTitle() {

        titleTextView.text.clipText(
            0, 0,
            width - titleTextView.text.x - titleTextView.x,
            999999999
        );

    }

    function layoutSubTitle() {

        subTitleTextView.text.clipText(
            0, 0,
            width - subTitleTextView.text.x - subTitleTextView.x,
            999999999
        );

    }

    function updateIcons() {

        var displayTrash = handleTrash != null;
        var displayLock = handleLock != null;
        var displayDuplicate = handleDuplicate != null;
        var displayKindIcon = kindIcon != null;
        var displayAnyIcon = displayTrash || displayLock || displayKindIcon;

        unobserve();

        if (iconsView != null) {
            iconsView.destroy();
        }

        if (displayAnyIcon) {
            iconsView = new RowLayout();
            iconsView.paddingRight = 8;
            iconsView.viewSize(fill(), fill());
            iconsView.align = RIGHT;
            add(iconsView);

            var w = 21;
            var s = 14;

            if (displayKindIcon) {
                titleTextView.paddingLeft = 22;
                subTitleTextView.paddingLeft = 22;

                var iconView = new EntypoIconView();
                iconView.icon = kindIcon;
                iconView.viewSize(25, fill());
                iconView.pointSize = 20;
                iconView.paddingLeft = 2;
                iconView.autorun(() -> {
                    var theme = this.theme;
                    if (theme == null)
                        theme = context.theme;
                    unobserve();
                    iconView.textColor = theme.iconColor;
                });
                columnLayout.add(iconView);

                iconsView.add(iconView);

                var filler = new View();
                filler.transparent = true;
                filler.viewSize(fill(), fill());
                iconsView.add(filler);
            }
            else {
                titleTextView.paddingLeft = 0;
                subTitleTextView.paddingLeft = 0;
            }

            if (displayDuplicate) {
                var iconView = new ClickableIconView();
                iconView.icon = DOCS;
                iconView.tooltip('Duplicate');
                iconView.viewSize(w, fill());
                iconView.pointSize = s;
                iconView.onClick(this, handleDuplicate);
                iconView.autorun(() -> {
                    var theme = this.theme;
                    if (theme == null)
                        theme = context.theme;
                    unobserve();
                    iconView.theme = theme;
                });
                iconsView.add(iconView);
            }

            if (displayLock) {
                var iconView = new ClickableIconView();
                iconView.autorun(() -> {
                    iconView.icon = locked ? LOCK : LOCK_OPEN;
                    iconView.tooltip(locked ? 'Unlock' : 'Lock');
                });
                iconView.viewSize(w, fill());
                iconView.pointSize = s;
                iconView.onClick(this, handleLock);
                iconView.autorun(() -> {
                    var theme = this.theme;
                    if (theme == null)
                        theme = context.theme;
                    unobserve();
                    iconView.theme = theme;
                });
                iconsView.add(iconView);
            }

            if (displayTrash) {
                var iconView = new ClickableIconView();
                iconView.icon = TRASH;
                iconView.viewSize(w, fill());
                iconView.pointSize = s;
                iconView.tooltip('Delete');
                iconView.onClick(this, handleTrash);
                iconView.autorun(() -> {
                    var theme = this.theme;
                    if (theme == null)
                        theme = context.theme;
                    unobserve();
                    iconView.theme = theme;
                });
                iconsView.add(iconView);
            }
        }
        else {
            titleTextView.paddingLeft = 0;
            subTitleTextView.paddingLeft = 0;
        }

        reobserve();

    }

    function updateStyle() {

        var theme = this.theme;
        if (theme == null)
            theme = context.theme;

        if (inputStyle) {
            columnLayout.padding(6, 6);
        }
        else {
            columnLayout.padding(8, 8);
        }

        var selected = this.selected;
        if (selected) {
            transparent = false;
            alpha = 1;
            if (inputStyle) {
                color = theme.lightBackgroundColor;
                borderLeftSize = 0;
                borderRightSize = 0;
            }
            else {
                color = Color.interpolate(theme.mediumBackgroundColor, theme.selectionBorderColor, 0.1);
                borderLeftColor = theme.selectionBorderColor;
                borderRightColor = theme.selectionBorderColor;
                borderTopColor = theme.selectionBorderColor;
                borderBottomColor = theme.selectionBorderColor;
                borderLeftSize = 1;
                borderRightSize = 1;
                borderTopSize = 1;
            }
        }
        else if (locked && !inputStyle) {
            alpha = 1;
            transparent = false;
            borderLeftSize = 0;
            borderRightSize = 0;
            borderTopSize = 0;

            color = theme.darkBackgroundColor;
        }
        else {
            alpha = 1;
            transparent = false;
            borderLeftSize = 0;
            borderRightSize = 0;
            borderTopSize = 0;

            if (collectionView == null || !collectionView.scrolling) {
                if (hover) {
                    appliedHoverItemIndex = itemIndex;
                    color = theme.lightBackgroundColor;
                } else {
                    appliedHoverItemIndex = -1;
                    if (inputStyle) {
                        color = theme.darkBackgroundColor;
                    }
                    else {
                        color = theme.mediumBackgroundColor;
                    }
                }
            }
            else {
                if (appliedHoverItemIndex != -1 && appliedHoverItemIndex == itemIndex) {
                    color = theme.lightBackgroundColor;
                }
                else {
                    if (inputStyle) {
                        color = theme.darkBackgroundColor;
                    }
                    else {
                        color = theme.mediumBackgroundColor;
                    }
                }
            }
        }

        if (locked) {
            titleTextView.textColor = Color.interpolate(theme.lightTextColor, color, 0.4);
            subTitleTextView.textColor = Color.interpolate(theme.darkTextColor, color, 0.4);
        }
        else {
            titleTextView.textColor = theme.lightTextColor;
            subTitleTextView.textColor = theme.darkTextColor;
        }

        titleTextView.font = theme.mediumFont;
        subTitleTextView.font = theme.mediumFont;

        if (!selected) {
            borderBottomColor = theme.mediumBorderColor;
        }

        if (inputStyle && displaysEmptyValue) {
            titleTextView.text.skewX = 8;
            titleTextView.text.alpha = 0.8;
        }
        else {
            titleTextView.text.skewX = 0;
            titleTextView.text.alpha = 1;
        }

    }

/// Drag & Drop

    public function bindDragDrop(?click:Click, handleDrop:(itemIndex:Int)->Void) {

        if (_notVisibleTransform == null) {
            _notVisibleTransform = new Transform();
            _notVisibleTransform.translate(-99999999, -99999999);
        }

        dragDrop = new DragDrop(click,
            createDraggingVisual,
            releaseDraggingVisual
        );
        this.component('dragDrop', dragDrop);
        dragDrop.onDraggingChange(this, function(dragging:Bool, wasDragging:Bool) {
            if (wasDragging && !dragging) {
                handleDrop(dragOnItemIndex);
            }
            handleDragChange(dragging, wasDragging);
        });
        dragDrop.autorun(updateFromDrag);

    }

    public function unbindDragDrop() {

        if (dragDrop != null) {
            dragDrop.destroy();
            dragDrop = null;
            dragging = false;
        }

    }

    function cloneForDragDrop():CellView {

        var cloned = new CellView();

        cloned.theme = theme;
        cloned.selected = selected;
        cloned.title = title;
        cloned.subTitle = subTitle;
        cloned.itemIndex = itemIndex;
        cloned.inputStyle = inputStyle;
        cloned.displaysEmptyValue = displaysEmptyValue;
        cloned.kindIcon = kindIcon;
        cloned.locked = locked;
        cloned.handleTrash = handleTrash;
        cloned.handleLock = handleLock;
        cloned.handleDuplicate = handleDuplicate;
        cloned.clonedForDragging = true;

        return cloned;

    }

    function createDraggingVisual():Visual {

        var visual = this.cloneForDragDrop();

        visual.touchable = false;
        visual.depth = 9999;
        visual.viewSize(this.width, this.height);
        visual.computeSize(this.width, this.height, ViewLayoutMask.FIXED, true);
        visual.applyComputedSize();
        visual.pos(this.x, this.y);
        this.parent.add(visual);

        return visual;

    }

    function releaseDraggingVisual(visual:Visual) {

        visual.destroy();

    }

    function firstEnabledParentScroller():Scroller {

        var scroller = firstParentWithClass(Scroller);
        while (scroller != null && !scroller.scrollEnabled) {
            scroller = scroller.firstParentWithClass(Scroller);
        }
        return scroller;

    }

    function handleDragChange(dragging:Bool, wasDragging:Bool) {
        if (dragging == wasDragging)
            return;

        this.dragging = dragging;

        if (dragging) {
            dragAutoScroll = 0;
            draggingCellDragY = 0;
            this.transform = _notVisibleTransform;
            var scroller = firstEnabledParentScroller();
            if (scroller != null) {
                dragStartScrollY = scroller.scrollY;
            }

            app.onUpdate(dragDrop, scrollFromDragIfNeeded);
        }
        else {
            dragAutoScroll = 0;
            this.transform = null;
            var parent = this.parent;
            for (child in parent.children) {
                if (child != this && Std.isOfType(child, CellView)) {
                    var otherCell:CellView = cast child;
                    otherCell.transition(0.0, props -> {
                        props.transform = null;
                    });
                }
            }

            app.offUpdate(scrollFromDragIfNeeded);
        }

    }

    function updateFromDrag() {

        var dragging = dragDrop.dragging;
        draggingCellDragY = dragDrop.dragY;

        unobserve();

        if (dragging) {

            // Move other this from drag
            //

            var dragExtra = 0.0;
            var scroller = this.firstEnabledParentScroller();
            if (scroller != null) {
                dragExtra = scroller.scrollY - dragStartScrollY;
            }

            draggingCell = cast dragDrop.draggingVisual;
            draggingCell.pos(this.x, this.y + draggingCellDragY + dragExtra);

            updateOtherCellsFromDrag();

            // Scroll container if reaching bounds with drag
            //
            final scroller = this.firstEnabledParentScroller();
            final container = firstParentWithClass(Scroller) ?? scroller;
            if (scroller != null) {

                if (container != scroller) {
                    // Active scroller is not the container

                    scroller.visualToScreen(0, 0, _point);
                    final scrollerTop = _point.y;
                    scroller.visualToScreen(0, scroller.height, _point);
                    final scrollerBottom = _point.y;

                    draggingCell.visualToScreen(0, 0, _point);
                    final draggingTop = _point.y;
                    draggingCell.visualToScreen(0, draggingCell.height, _point);
                    final draggingBottom = _point.y;

                    if (draggingBottom > scrollerBottom) {
                        dragAutoScroll = draggingBottom - scrollerBottom;
                    }
                    else if (draggingTop < scrollerTop) {
                        dragAutoScroll = draggingTop - scrollerTop;
                    }
                    else {
                        dragAutoScroll = 0;
                    }
                }
                else {
                    // Active scroller is the same as the container
                    if (this.y + this.height + draggingCellDragY + dragExtra > scroller.height + scroller.scrollY) {
                        dragAutoScroll = (this.y + this.height + draggingCellDragY + dragExtra) - (scroller.height + scroller.scrollY);
                    }
                    else if (this.y + draggingCellDragY + dragExtra < scroller.scrollY) {
                        dragAutoScroll = (this.y + draggingCellDragY + dragExtra) - scroller.scrollY;
                    }
                    else {
                        dragAutoScroll = 0;
                    }
                }
            }
        }

        reobserve();

    }

    function updateOtherCellsFromDrag() {

        var thisStep = this.height;
        var transitionDuration = 0.1;

        dragOnItemIndex = this.itemIndex;

        var parent = this.parent;
        for (child in parent.children) {
            if (child != this && Std.isOfType(child, CellView)) {
                var otherCell:CellView = cast child;
                if (otherCell.transform == null) {
                    otherCell.transform = new Transform();
                }
                var prevTargetTy = otherCell.dragTargetTy;
                var dragTargetTy = prevTargetTy;
                if (this.itemIndex > otherCell.itemIndex) {
                    if (draggingCell.y < otherCell.y + otherCell.height * 0.5) {
                        if (dragOnItemIndex > otherCell.itemIndex)
                            dragOnItemIndex = otherCell.itemIndex;
                        dragTargetTy = thisStep;
                    }
                    else {
                        dragTargetTy = 0;
                    }
                }
                else if (this.itemIndex < otherCell.itemIndex) {
                    if (draggingCell.y > otherCell.y - otherCell.height * 0.5) {
                        if (dragOnItemIndex < otherCell.itemIndex)
                            dragOnItemIndex = otherCell.itemIndex;
                        dragTargetTy = -thisStep;
                    }
                    else {
                        dragTargetTy = 0;
                    }
                }
                else {
                    dragTargetTy = 0;
                }
                if (dragTargetTy != prevTargetTy) {
                    otherCell.dragTargetTy = dragTargetTy;
                    otherCell.transition(transitionDuration, props -> {
                        props.transform.ty = dragTargetTy;
                        props.transform.changedDirty = true;
                    });
                }
            }
        }

    }

    function scrollFromDragIfNeeded(delta:Float) {

        if (dragAutoScroll != 0) {
            var scroller = this.firstEnabledParentScroller();
            if (scroller != null) {
                var prevScrollY = scroller.scrollY;
                scroller.scrollY += dragAutoScroll * delta * 10;
                scroller.scrollToBounds();

                if (scroller.scrollY != prevScrollY) {
                    if (draggingCell != null) {
                        var dragExtra = scroller.scrollY - dragStartScrollY;
                        draggingCell.pos(this.x, this.y + draggingCellDragY + dragExtra);
                    }

                    updateOtherCellsFromDrag();
                }
            }
        }

    }

}
