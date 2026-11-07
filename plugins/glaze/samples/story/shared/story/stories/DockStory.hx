// Ported from gpui-kit 0.8.1: crates/story/src/stories/dock_story.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package story.stories;

import glaze.AnyView;
import glaze.App;
import glaze.Context;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.IntoElement;
import glaze.Model;
import glaze.Pixels;
import glaze.Window;
import glaze.kit.base.dock.DockArea;
import glaze.kit.base.dock.DockLayout;
import glaze.kit.base.dock.DockPlacement;
import glaze.kit.button.Button;
import glaze.kit.dock.DockSkin;
import glaze.kit.dock.PanelBase;
import glaze.kit.dock.PanelHandle;
import glaze.kit.menu.PopupMenu;
import glaze.kit.theme.Theme;
import story.Story;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;
import story.Lib.*;

/** A plain panel of the dock story. */
class DockStoryDemoPanel extends PanelBase {

    final name:String;

    final titleValue:String;

    final body:String;

    final focus:FocusHandle;

    public var closable_:Bool = true;

    function new(name:String, title:String, body:String, cx:Context<DockStoryDemoPanel>) {
        super();
        this.name = name;
        this.titleValue = title;
        this.body = body;
        this.focus = cx.focusHandle();
    }

    public static function create(name:String, title:String, body:String, cx:App):Entity<DockStoryDemoPanel> {
        return cx.newEntity((cx:Context<DockStoryDemoPanel>) -> new DockStoryDemoPanel(name, title, body, cx));
    }

    public function focusHandle(_:App):FocusHandle {
        return focus;
    }

    public function panelName():String {
        return name;
    }

    override public function closable(_:App):Bool {
        return closable_;
    }

    override public function title(_:Window, _:Context<Dynamic>):IntoElement {
        return titleValue;
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        return div()
            .sizeFull()
            .p4()
            .textColor(Theme.global(cx).foreground)
            .child(body);
    }

}

class DockStory extends Model implements Story {

    final dockArea:Entity<DockArea>;

    final skin:DockSkin;

    var closeButtonVisible:Bool;

    function new(dockArea:Entity<DockArea>, skin:DockSkin) {
        super();
        this.dockArea = dockArea;
        this.skin = skin;
        this.closeButtonVisible = false;
    }

    public static function title():String {
        return 'Dock';
    }

    public static function description():String {
        return 'Drag tabs between groups or towards an edge to split the workspace.';
    }

    public static function paddings():Pixels {
        return px(0.);
    }

    public static function newView(window:Window, cx:App):AnyView {
        final created = DockSkin.dockArea('dock-story', 1, window, cx);
        final dockArea = created.area;
        final skin = created.skin;
        final explorer = DockStoryDemoPanel.create('DockStoryExplorer', 'Explorer', 'Drag this tab into another group.', cx);
        final search = DockStoryDemoPanel.create('DockStorySearch', 'Search', 'Two panels can share one tab group.', cx);
        final editor = DockStoryDemoPanel.create('DockStoryEditor', 'Editor', 'Drop a tab near an edge to split this group.', cx);
        editor.update(cx, (editor, _) -> editor.closable_ = false);
        final terminal = DockStoryDemoPanel.create('DockStoryTerminal', 'Terminal', 'The bottom dock shares the workspace column.', cx);
        final problems = DockStoryDemoPanel.create('DockStoryProblems', 'Problems', 'No problems detected.', cx);

        dockArea.update(cx, (area, acx) -> {
            area.setCenter(DockLayout.hSplit()
                .child(DockLayout.tabs()
                    .panelView(PanelHandle.panelHandle(explorer), cx)
                    .panelView(PanelHandle.panelHandle(search), cx), px(240.))
                .child(DockLayout.tabs().panelView(PanelHandle.panelHandle(editor), cx), null), window, acx);
            area.setDock(DockPlacement.Bottom, DockLayout.tabs()
                .panelView(PanelHandle.panelHandle(terminal), cx)
                .panelView(PanelHandle.panelHandle(problems), cx), window, acx);
            area.setDockSize(DockPlacement.Bottom, px(160.), window, acx);
            area.setDockCollapsible(DockPlacement.Bottom, true, window, acx);
        });
        skin.setToggleButtonVisible(true, cx);

        return cx.newEntity((_:Context<DockStory>) -> new DockStory(dockArea, skin));
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        final self:Context<DockStory> = cast cx;
        final closeButtonVisible = this.closeButtonVisible;
        final story = self.entity();
        return vFlex()
            .sizeFull()
            .child(storyToolbarGroup().p2().dropdownChild(new Button('dock-options').label('Options'), (menu, _, _) -> menu
                .item(PopupMenuItem.create('Tab close buttons')
                    .checked(closeButtonVisible)
                    // Rust `window.listener_for(&story, ...)`
                    .onClick((_, _, cx) -> story.update(cx, (this_, cx) -> {
                        this_.closeButtonVisible = !this_.closeButtonVisible;
                        this_.skin.setCloseButtonVisible(this_.closeButtonVisible, cx.app);
                        cx.notify();
                    })))))
            .child(div()
                .flex1()
                .minH0()
                .borderT1()
                .borderColor(Theme.global(cx).border)
                .child(dockArea));
    }

}
