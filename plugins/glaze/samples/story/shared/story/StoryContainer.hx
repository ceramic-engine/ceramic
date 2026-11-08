// Ported from gpui-kit 0.8.1: crates/story/src/lib.rs (StoryContainer)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package story;

import glaze.AnyView;
import glaze.App;
import glaze.AppContext;
import glaze.Context;
import glaze.Entity;
import glaze.EventType;
import glaze.FocusHandle;
import glaze.Hsla;
import glaze.IntoElement;
import glaze.Pixels;
import glaze.Window;
import glaze.kit.base.dock.PanelInfo;
import glaze.kit.base.dock.PanelState;
import glaze.kit.IconName;
import glaze.kit.button.Button;
import glaze.kit.dock.PanelBase;
import glaze.kit.dock.PanelControl;
import glaze.kit.dock.TitleStyle;
import glaze.kit.menu.PopupMenu;
import glaze.kit.theme.Theme;
import story.StoryActions;

import glaze.Prelude.*;

using glaze.kit.WindowExt;
using glaze.kit.scroll.Scrollable;

/**
 * Rust `enum ContainerEvent`.
 */
enum ContainerEvent {
    Close;
}

/**
 * The panel showing one story: a scrollable area with paddings around the
 * story view. Used by the gallery and as a dock panel.
 */
class StoryContainer extends PanelBase {


    public var focusHandle_:FocusHandle;

    public var name:String = '';

    public var titleBg:Null<Hsla> = null;

    public var description:String = '';

    var width:Null<Pixels> = null;

    var height:Null<Pixels> = null;

    var storyView:Null<AnyView> = null;

    var storyKlass:Null<String> = null;

    public var closable_:Bool = true;

    public var zoomable_:Null<PanelControl> = PanelControl.defaultValue();

    public var paddings:Pixels = 16.;

    var onActiveFn:Null<(AnyView, Bool, Window, App) -> Void> = null;

    public function new(window:Window, cx:AppContext) {
        super();
        focusHandle_ = cx.focusHandle();
    }

    /**
     * Rust `StoryContainer::panel::<S>`: `StoryContainer.panel(StoryMeta.of(XStory), window, cx)`.
     */
    public static function panel(meta:StoryMeta, window:Window, cx:AppContext):Entity<StoryContainer> {
        final name = meta.title;
        final description = meta.description;
        final story = meta.newView(window, cx);
        final storyKlass = meta.klass;

        final view = cx.newEntity((cx:Context<StoryContainer>) -> {
            final story = new StoryContainer(window, cx).story(story, storyKlass).onActive(meta.onActiveAny);
            story.focusHandle_ = cx.focusHandle();
            story.closable_ = meta.closable;
            story.zoomable_ = meta.zoomable;
            story.name = name;
            story.description = description;
            story.titleBg = meta.titleBg;
            story.paddings = meta.paddings;
            return story;
        });

        return view;
    }

    public function withWidth(width:Pixels):StoryContainer {
        this.width = width;
        return this;
    }

    public function withHeight(height:Pixels):StoryContainer {
        this.height = height;
        return this;
    }

    public function story(story:AnyView, storyKlass:String):StoryContainer {
        this.storyView = story;
        this.storyKlass = storyKlass;
        return this;
    }

    public function onActive(onActive:(AnyView, Bool, Window, App) -> Void):StoryContainer {
        this.onActiveFn = onActive;
        return this;
    }

    /** The story view. */
    public inline function storyViewValue():Null<AnyView> {
        return storyView;
    }

    // BasePanel

    public function panelName():String {
        return 'StoryContainer';
    }

    override public function closable(cx:App):Bool {
        return closable_;
    }

    /**
     * The presentation half decides *where* the control appears; this decides
     * whether zooming is possible at all.
     */
    override public function zoomable(cx:App):Bool {
        return zoomable_ != null;
    }

    override public function visible(cx:App):Bool {
        return AppState.global(cx).invisiblePanels.read(cx).value.indexOf(name) < 0;
    }

    override public function setZoomed(zoomed:Bool, window:Window, cx:Context<Dynamic>):Void {
        trace('panel: $name zoomed: $zoomed');
    }

    override public function setActive(active:Bool, window:Window, cx:Context<Dynamic>):Void {
        trace('panel: $name active: $active');
        if (onActiveFn != null) {
            if (storyView != null) {
                onActiveFn(storyView, active, window, cx.app);
            }
        }
    }

    override public function dump(cx:App):PanelState {
        final state = PanelState.named(panelName());
        final storyState = new StoryState(storyKlass != null ? storyKlass : "");
        state.info = PanelInfo.Panel(storyState.toValue());
        return state;
    }

    // Panel

    override public function title(window:Window, cx:Context<Dynamic>):IntoElement {
        return name;
    }

    override public function titleStyle(cx:App):Null<TitleStyle> {
        if (titleBg != null) {
            return new TitleStyle(titleBg, Theme.global(cx).foreground);
        }
        return null;
    }

    override public function zoomControl(cx:App):Null<PanelControl> {
        return zoomable_;
    }

    override public function dropdownMenu(menu:PopupMenu, window:Window, cx:Context<Dynamic>):PopupMenu {
        return menu.menu('Info', new ShowPanelInfo());
    }

    override public function toolbarButtons(window:Window, cx:Context<Dynamic>):Null<Array<Button>> {
        return [
            Button.component('info').icon(IconName.Info).onClick((_, window, cx) -> {
                window.pushNotification('You have clicked info button', cx);
            }),
            Button.component('search').icon(IconName.Search).onClick((_, window, cx) -> {
                window.pushNotification('You have clicked search button', cx);
            }),
        ];
    }

    public function focusHandle(cx:App):FocusHandle {
        return focusHandle_;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final container = div()
            .id('story-container')
            .sizeFull()
            .overflowYScrollbar()
            .trackFocus(focusHandle_);
        if (storyView != null) {
            container.child(div().sizeFull().p(paddings).child(storyView));
        }
        return container;
    }

}
