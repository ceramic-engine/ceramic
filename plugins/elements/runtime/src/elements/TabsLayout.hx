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

    @observe public var theme:Theme = null;

    public var marginX(default, set):Float = 0;
    function set_marginX(marginX:Float):Float {
        if (this.marginX != marginX) {
            this.marginX = marginX;
            layoutDirty = true;
        }
        return marginX;
    }

    public var marginY(default, set):Float = 0;
    function set_marginY(marginY:Float):Float {
        if (this.marginY != marginY) {
            this.marginY = marginY;
            layoutDirty = true;
        }
        return marginY;
    }

    /**
     * If this field is managed by a WindowItem, this is the WindowItem.
     */
    public var windowItem:WindowItem = null;

    @observe public var selectedIndex:Int = -1;

    @observe public var tabs:ReadOnlyArray<String> = [];

    @observe public var tabStates:ReadOnlyArray<TabState> = [];

    @observe public var tabThemes:ReadOnlyArray<Theme> = [];

    @observe var tabViews:Array<TextView> = [];

    @observe var hoverIndex:Int = -1;

    var appliedTabs:Array<String> = null;

    var beforeBorder:Quad;

    var afterBorder:Quad;

    var beforeSelectedBackground:Quad = null;

    var afterSelectedBackground:Quad = null;

    var topBackground:Quad = null;

    var bottomBackground:Quad = null;

    public function new() {

        super();

        viewHeight = 27;
        transparent = true;
        itemSpacing = -1;
        childrenDepth = CUSTOM;

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

    @:keep
    function renderWindowBackground():Bool {

        return true;

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

        tabView.autorun(() -> {
            tabView.touchable = (tabStates[index] != DISABLED);
        });

    }

    override function layout() {

        super.layout();

        if (selectedIndex >= 0 && tabViews != null && tabViews.length > 0) {
            var selectedTabView = tabViews.unsafeGet(selectedIndex);
            selectedTabView.depth = tabViews.length;
            var i = selectedIndex - 1;
            var d = selectedTabView.depth - 1;
            while (i >= 0) {
                tabViews.unsafeGet(i).depth = d;
                i--;
                d--;
            }
            i = selectedIndex + 1;
            var d = selectedTabView.depth - 1;
            while (i < tabViews.length) {
                tabViews.unsafeGet(i).depth = d;
                i++;
                d--;
            }
        }
        else if (tabViews != null && tabViews.length > 0) {
            var i = tabViews.length - 1;
            var d = 1;
            while (i >= 0) {
                tabViews.unsafeGet(i).depth = d;
                i--;
                d++;
            }
        }

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

        if (selectedIndex >= 0 && tabViews != null && tabViews.length > 0) {
            var selectedTabView = tabViews.unsafeGet(selectedIndex);
            if (beforeSelectedBackground != null) {
                beforeSelectedBackground.pos(-marginX, 0);
                beforeSelectedBackground.size(marginX + selectedTabView.x, height);
            }
            if (afterSelectedBackground != null) {
                afterSelectedBackground.pos(selectedTabView.x + selectedTabView.width, 0);
                afterSelectedBackground.size(marginX + width - selectedTabView.x - selectedTabView.width, height);
            }
        }
        else {
            if (beforeSelectedBackground != null) {
                beforeSelectedBackground.pos(-marginX, 0);
                beforeSelectedBackground.size(marginX * 2 + width, height);
            }
            if (afterSelectedBackground != null) {
                afterSelectedBackground.pos(0, 0);
                afterSelectedBackground.size(0, 0);
            }
        }

        if (topBackground != null) {
            topBackground.pos(-marginX, -marginY);
            topBackground.size(marginX * 2 + width, marginY);
        }
        if (bottomBackground != null) {
            bottomBackground.pos(-marginX, height);
            bottomBackground.size(marginX * 2 + width, marginY);
        }

    }

    function updateStyle() {

        var theme = this.theme;
        if (theme == null)
            theme = context.theme;
        var selectedTheme = theme;

        var selectedIndex = this.selectedIndex;
        var hoverIndex = this.hoverIndex;

        var backgroundInFormLayout = theme.backgroundInFormLayout;

        if (tabViews != null) {
            for (i in 0...tabViews.length) {
                var tabView = tabViews.unsafeGet(i);

                var tabTheme = tabThemes[i];
                if (tabTheme == null)
                    tabTheme = theme;

                var tabDisabled = (tabStates[i] == DISABLED);

                tabView.borderLeftSize = 1;
                tabView.borderRightSize = 1;
                tabView.borderTopSize = 1;
                tabView.borderBottomSize = 0;
                tabView.borderPosition = INSIDE;
                tabView.borderColor = tabTheme.tabsBorderColor;

                if (i == selectedIndex) {
                    tabView.textColor = tabTheme.lightTextColor;
                    tabView.textAlpha = 1;
                    tabView.borderAlpha = 1;
                    if (theme.backgroundInFormLayout) {
                        tabView.transparent = false;
                        tabView.alpha = tabTheme.windowBackgroundAlpha;
                        tabView.color = tabTheme.windowBackgroundColor;
                    }
                    else {
                        tabView.transparent = true;
                        tabView.alpha = 1;
                    }
                    selectedTheme = tabTheme;
                }
                else if (!tabDisabled && i == hoverIndex) {
                    tabView.textColor = tabTheme.mediumTextColor;
                    tabView.textAlpha = 1;
                    tabView.borderAlpha = 1;
                    tabView.transparent = false;
                    tabView.alpha = tabTheme.tabsHoverBackgroundAlpha;
                    tabView.color = tabTheme.tabsHoverBackgroundColor;
                }
                else if (tabDisabled) {
                    tabView.textColor = tabTheme.darkTextColor;
                    tabView.textAlpha = tabTheme.disabledTabTextAlpha;
                    tabView.borderAlpha = tabTheme.disabledTabBorderAlpha;
                    tabView.transparent = false;
                    tabView.alpha = tabTheme.tabsBackgroundAlpha;
                    tabView.color = tabTheme.tabsBackgroundColor;
                }
                else {
                    tabView.textColor = tabTheme.darkTextColor;
                    tabView.textAlpha = 1;
                    tabView.borderAlpha = 1;
                    tabView.transparent = false;
                    tabView.alpha = tabTheme.tabsBackgroundAlpha;
                    tabView.color = tabTheme.tabsBackgroundColor;
                }
            }
        }

        beforeBorder.color = selectedTheme.tabsBorderColor;
        afterBorder.color = selectedTheme.tabsBorderColor;

        if (backgroundInFormLayout) {
            unobserve();
            if (beforeSelectedBackground == null) {
                beforeSelectedBackground = new Quad();
                beforeSelectedBackground.depth = 0.5;
                add(beforeSelectedBackground);
            }
            if (afterSelectedBackground == null) {
                afterSelectedBackground = new Quad();
                afterSelectedBackground.depth = 0.5;
                add(afterSelectedBackground);
            }
            if (topBackground == null) {
                topBackground = new Quad();
                topBackground.depth = 0.5;
                add(topBackground);
            }
            if (bottomBackground == null) {
                bottomBackground = new Quad();
                bottomBackground.depth = 0.5;
                add(bottomBackground);
            }
            reobserve();
            beforeSelectedBackground.alpha = theme.windowBackgroundAlpha;
            beforeSelectedBackground.color = theme.windowBackgroundColor;
            afterSelectedBackground.alpha = theme.windowBackgroundAlpha;
            afterSelectedBackground.color = theme.windowBackgroundColor;
            topBackground.alpha = theme.windowBackgroundAlpha;
            topBackground.color = theme.windowBackgroundColor;
            bottomBackground.alpha = selectedTheme.windowBackgroundAlpha;
            bottomBackground.color = selectedTheme.windowBackgroundColor;
        }
        else {
            unobserve();
            if (beforeSelectedBackground != null) {
                beforeSelectedBackground.destroy();
                beforeSelectedBackground = null;
            }
            if (afterSelectedBackground != null) {
                afterSelectedBackground.destroy();
                afterSelectedBackground = null;
            }
            if (topBackground != null) {
                topBackground.destroy();
                topBackground = null;
            }
            if (bottomBackground != null) {
                bottomBackground.destroy();
                bottomBackground = null;
            }
            reobserve();
        }

    }

}
