package elements;

import ceramic.Click;
import ceramic.Equal;
import ceramic.Quad;
import ceramic.ReadOnlyArray;
import ceramic.RowLayout;
import ceramic.TextView;
import ceramic.View;
import ceramic.ViewLayoutMask;
import ceramic.ViewSize;
import elements.Context.context;
import tracker.Autorun.reobserve;
import tracker.Autorun.unobserve;
import tracker.Observable;

using ceramic.Extensions;

class TabsLayout extends RowLayout implements Observable {

    public var marginX(default, set):Float = 0;
    function set_marginX(marginX:Float):Float {
        if (this.marginX != marginX) {
            this.marginX = marginX;
            layoutDirty = true;
        }
        return marginX;
    }

    @observe public var selectedIndex:Int = -1;

    @observe public var tabs:ReadOnlyArray<String> = [];

    @observe var tabViews:Array<TextView> = [];

    @observe var hoverIndex:Int = -1;

    var appliedTabs:Array<String> = null;

    var beforeBorder:Quad;

    var afterBorder:Quad;

    public function new() {

        super();

        viewHeight = 27;
        transparent = true;
        itemSpacing = -1;

        beforeBorder = new Quad();
        beforeBorder.transparent = false;
        beforeBorder.active = false;
        beforeBorder.depth = 100;
        add(beforeBorder);

        afterBorder = new Quad();
        afterBorder.transparent = false;
        afterBorder.active = false;
        afterBorder.depth = 100;
        add(afterBorder);

        autorun(updateTabs);
        autorun(updateStyle);

        onSelectedIndexChange(this, (_, _) -> {
            layoutDirty = true;
        });

    }

    function updateTabs() {

        var tabs = this.tabs;

        unobserve();

        var tabViews = this.tabViews;

        // Create or update tab views from tabs array
        var changed = false;
        for (i in 0...tabs.length) {
            var tab = tabs.unsafeGet(i);
            var tabView = tabViews[i];
            if (tabView == null) {
                tabView = new TextView();
                tabView.content = tab;
                tabView.pointSize = 12;
                tabView.preRenderedSize = 20;
                tabView.align = CENTER;
                tabView.verticalAlign = CENTER;
                tabView.viewHeight = fill();
                tabView.padding(0, 10);
                tabView.depth = 1;
                tabViews.push(tabView);
                add(tabView);
                changed = true;
                initTabView(i, tabView);
            }
        }

        // Remove any unused tab view
        while (tabViews.length > tabs.length) {
            changed = true;
            var unusedTabView = tabViews.pop();
            unusedTabView.destroy();
        }

        if (changed) {
            this.tabViews = [].concat(tabViews);
        }

        reobserve();

    }

    function initTabView(index:Int, tabView:TextView) {

        tabView.onPointerOver(this, _ -> {
            hoverIndex = index;
        });

        tabView.onPointerOut(this, _ -> {
            if (hoverIndex == index)
                hoverIndex = -1;
        });

        #if mobile
        var click = new Click();
        tabView.component(click);
        click.onClick(this, () -> {
            selectedIndex = index;
        });
        #else
        tabView.onPointerDown(this, _ -> {
            selectedIndex = index;
        });
        #end

    }

    override function layout() {

        super.layout();

        if (selectedIndex >= 0 && tabViews.length > selectedIndex) {
            var selectedTabView = tabViews.unsafeGet(selectedIndex);
            beforeBorder.active = true;
            beforeBorder.pos(-marginX, height - 1);
            beforeBorder.size(marginX + selectedTabView.x, 1);
        }
        else if (marginX > 0) {
            beforeBorder.active = true;
            beforeBorder.pos(-marginX, height - 1);
            beforeBorder.size(marginX, 1);
        }
        else {
            beforeBorder.active = false;
        }

        if (selectedIndex >= 0 && selectedIndex <= tabViews.length - 1) {
            var selectedTabView = tabViews.unsafeGet(selectedIndex);
            afterBorder.active = true;
            afterBorder.pos(selectedTabView.x + selectedTabView.width, height - 1);
            afterBorder.size(marginX + width - selectedTabView.x - selectedTabView.width, 1);
        }
        else {
            var lastTab = tabViews.length > 0 ? tabViews[tabViews.length - 1] : null;
            var afterX = lastTab != null ? lastTab.x + lastTab.width : 0.0;
            afterBorder.active = true;
            afterBorder.pos(afterX, height - 1);
            afterBorder.size(marginX + width - afterX, 1);
        }

    }

    function updateStyle() {

        var theme = context.theme;

        var selectedIndex = this.selectedIndex;
        var hoverIndex = this.hoverIndex;

        if (tabViews != null) {
            for (i in 0...tabViews.length) {
                var tabView = tabViews.unsafeGet(i);

                tabView.borderLeftSize = 1;
                tabView.borderRightSize = 1;
                tabView.borderTopSize = 1;
                tabView.borderBottomSize = 0;
                tabView.borderPosition = INSIDE;
                tabView.borderColor = theme.tabsBorderColor;

                if (i == selectedIndex) {
                    tabView.textColor = theme.lightTextColor;
                    tabView.transparent = true;
                    tabView.alpha = 1;
                }
                else if (i == hoverIndex) {
                    tabView.textColor = theme.mediumTextColor;
                    tabView.transparent = false;
                    tabView.alpha = theme.tabsHoverBackgroundAlpha;
                    tabView.color = theme.tabsHoverBackgroundColor;
                }
                else {
                    tabView.textColor = theme.darkTextColor;
                    tabView.transparent = false;
                    tabView.alpha = theme.tabsBackgroundAlpha;
                    tabView.color = theme.tabsBackgroundColor;
                }
            }
        }

        beforeBorder.color = theme.tabsBorderColor;
        afterBorder.color = theme.tabsBorderColor;

    }

}
