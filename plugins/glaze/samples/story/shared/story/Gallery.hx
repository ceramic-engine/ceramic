// Ported from gpui-kit 0.8.1: crates/story/src/gallery.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package story;

import glaze.App;
import glaze.AppContext;
import glaze.ClickEvent;
import glaze.Context;
import glaze.Entity;
import glaze.IntoElement;
import glaze.Model;
import glaze.Render;
import glaze.Subscription;
import glaze.Window;
import glaze.kit.base.IndexPath;
import glaze.kit.base.input.InputEvent;
import glaze.kit.base.input.InputState;
import glaze.kit.Icon;
import glaze.kit.IconName;
import glaze.kit.button.Button;
import glaze.kit.command.CommandItem;
import glaze.kit.input.Input;
import glaze.kit.separator.Separator;
import glaze.kit.sidebar.Sidebar;
import glaze.kit.sidebar.SidebarHeader;
import glaze.kit.sidebar.SidebarMenu;
import glaze.kit.statusbar.StatusBar;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;

using glaze.kit.ThemeStyled;
using glaze.kit.base.StyledExt;

/**
 * The gallery window: a sidebar listing every story (with a search field),
 * the active story with its title and description, and a status bar.
 */
class Gallery extends Model implements Render {

    /** Rust `env!("CARGO_PKG_VERSION")` of the story crate. */
    public static inline final VERSION:String = '0.8.1';

    final stories:Array<{name:String, stories:Array<Entity<StoryContainer>>}>;

    var activeGroupIndex:Null<Int>;

    var activeIndex:Null<Int>;

    var collapsed:Bool;

    final embedded:Bool;

    final searchInput:Entity<InputState>;

    final subscriptions:Array<Subscription>;

    static function componentCommand(name:String):CommandEntry {
        return Item(new CommandItem().label(name));
    }

    /**
     * Rust `find_story_index`: the group and story indices of the story
     * named `name` (ASCII case-insensitive).
     */
    public static function findStoryIndex(groups:Array<Array<String>>, name:String):Null<{group:Int, story:Int}> {
        for (groupIx in 0...groups.length) {
            final group = groups[groupIx];
            for (storyIx in 0...group.length) {
                if (eqIgnoreAsciiCase(group[storyIx], name)) return {group: groupIx, story: storyIx};
            }
        }
        return null;
    }

    static function eqIgnoreAsciiCase(a:String, b:String):Bool {
        return asciiLower(a) == asciiLower(b);
    }

    /** Rust `to_lowercase` on the (ASCII) story names and queries. */
    static function asciiLower(s:String):String {
        return s.toLowerCase();
    }

    public function new(initStory:Null<String>, window:Window, cx:Context<Gallery>, embedded:Bool = false) {
        super();
        final searchInput = cx.newEntity((cx:Context<InputState>) -> new InputState(window, cx).withPlaceholder('Search…'));
        this.subscriptions = [cx.subscribe(searchInput, InputEvent, (this_:Gallery, _, e:InputEvent, cx:Context<Gallery>) -> {
            switch e {
                case Change:
                    this_.activeGroupIndex = 0;
                    this_.activeIndex = 0;
                    cx.notify();
                case _:
            }
        })];

        final panels:Array<Entity<StoryContainer>> = [];
        inline function add(meta:Null<StoryMeta>) {
            // The stories the port does not have (yet) are left out
            if (meta != null) panels.push(StoryContainer.panel(meta, window, cx));
        }
        add(StoryMeta.optional(story.stories.WelcomeStory));
        add(StoryMeta.optional(story.stories.AccordionStory));
        add(StoryMeta.optional(story.stories.AlertStory));
        add(StoryMeta.optional(story.stories.AlertDialogStory));
        add(StoryMeta.optional(story.stories.AttachmentStory));
        add(StoryMeta.optional(story.stories.AvatarStory));
        add(StoryMeta.optional(story.stories.BadgeStory));
        add(StoryMeta.optional(story.stories.BreadcrumbStory));
        add(StoryMeta.optional(story.stories.BubbleStory));
        add(StoryMeta.optional(story.stories.ButtonStory));
        add(StoryMeta.optional(story.stories.CalendarStory));
        add(StoryMeta.optional(story.stories.CarouselStory));
        add(StoryMeta.optional(story.stories.ChartStory));
        add(StoryMeta.optional(story.stories.CheckboxStory));
        add(StoryMeta.optional(story.stories.ClipboardStory));
        add(StoryMeta.optional(story.stories.CollapsibleStory));
        add(StoryMeta.optional(story.stories.ColorPickerStory));
        add(StoryMeta.optional(story.stories.ComboboxStory));
        add(StoryMeta.optional(story.stories.CommandStory));
        add(StoryMeta.optional(story.stories.DataTableStory));
        add(StoryMeta.optional(story.stories.DatePickerStory));
        add(StoryMeta.optional(story.stories.DescriptionListStory));
        add(StoryMeta.optional(story.stories.DialogStory));
        add(StoryMeta.optional(story.stories.DiffStory));
        add(StoryMeta.optional(story.stories.DockStory));
        add(StoryMeta.optional(story.stories.DropdownButtonStory));
        // Cityscape, Glaze's code editor (plugin `cityscape`, listed by the
        // story app); a placeholder page without the plugin
        add(StoryMeta.optional(story.stories.EditorStory));
        add(StoryMeta.optional(story.stories.EmptyStory));
        add(StoryMeta.optional(story.stories.FormStory));
        add(StoryMeta.optional(story.stories.GroupBoxStory));
        add(StoryMeta.optional(story.stories.HoverCardStory));
        add(StoryMeta.optional(story.stories.IconStory));
        add(StoryMeta.optional(story.stories.ImageStory));
        add(StoryMeta.optional(story.stories.InputStory));
        add(StoryMeta.optional(story.stories.InputGroupStory));
        add(StoryMeta.optional(story.stories.KbdStory));
        add(StoryMeta.optional(story.stories.LabelStory));
        add(StoryMeta.optional(story.stories.ListStory));
        add(StoryMeta.optional(story.stories.MenuStory));
        add(StoryMeta.optional(story.stories.MarkerStory));
        add(StoryMeta.optional(story.stories.MessageStory));
        add(StoryMeta.optional(story.stories.MessageScrollerStory));
        add(StoryMeta.optional(story.stories.NativeMenuStory));
        add(StoryMeta.optional(story.stories.NotificationStory));
        add(StoryMeta.optional(story.stories.NumberInputStory));
        add(StoryMeta.optional(story.stories.OtpInputStory));
        add(StoryMeta.optional(story.stories.PaginationStory));
        add(StoryMeta.optional(story.stories.PopoverStory));
        add(StoryMeta.optional(story.stories.ProgressStory));
        add(StoryMeta.optional(story.stories.QuestionnaireStory));
        add(StoryMeta.optional(story.stories.RadioStory));
        add(StoryMeta.optional(story.stories.RatingStory));
        add(StoryMeta.optional(story.stories.ResizableStory));
        add(StoryMeta.optional(story.stories.ScrollbarStory));
        add(StoryMeta.optional(story.stories.SelectStory));
        add(StoryMeta.optional(story.stories.SeparatorStory));
        add(StoryMeta.optional(story.stories.SettingsStory));
        // Rust: not on the web (`cfg(not(target_family = "wasm"))`)
        add(StoryMeta.optional(story.stories.ShellStory));
        add(StoryMeta.optional(story.stories.SheetStory));
        add(StoryMeta.optional(story.stories.ShimmerStory));
        add(StoryMeta.optional(story.stories.SidebarStory));
        add(StoryMeta.optional(story.stories.SkeletonStory));
        add(StoryMeta.optional(story.stories.SliderStory));
        add(StoryMeta.optional(story.stories.SpeechStory));
        add(StoryMeta.optional(story.stories.SpinnerStory));
        add(StoryMeta.optional(story.stories.StatusBarStory));
        add(StoryMeta.optional(story.stories.StepperStory));
        add(StoryMeta.optional(story.stories.SwitchStory));
        add(StoryMeta.optional(story.stories.TableStory));
        add(StoryMeta.optional(story.stories.TabsStory));
        add(StoryMeta.optional(story.stories.TagStory));
        add(StoryMeta.optional(story.stories.TextareaStory));
        add(StoryMeta.optional(story.stories.ThemeColorsStory));
        add(StoryMeta.optional(story.stories.TimeFieldStory));
        add(StoryMeta.optional(story.stories.ToggleStory));
        add(StoryMeta.optional(story.stories.ToolbarStory));
        add(StoryMeta.optional(story.stories.TooltipStory));
        add(StoryMeta.optional(story.stories.TreeStory));
        add(StoryMeta.optional(story.stories.VirtualListStory));

        this.searchInput = searchInput;
        this.stories = [{name: '', stories: panels}];
        this.activeGroupIndex = 0;
        this.activeIndex = 0;
        this.collapsed = false;
        this.embedded = embedded;

        if (initStory != null) {
            setActiveStory(initStory, window, cx);
        }
    }

    function setActiveStory(name:String, window:Window, cx:AppContext):Void {
        final name = StringTools.trim(name);
        final lower = asciiLower(name);
        var exactIndex:Null<Int> = null;
        var position = 0;
        for (group in stories) {
            for (story in group.stories) {
                final storyName = story.read(cx).name;
                if (asciiLower(storyName).indexOf(lower) < 0) continue;
                if (exactIndex == null && eqIgnoreAsciiCase(storyName, name)) exactIndex = position;
                position++;
            }
        }
        searchInput.update(cx, (input, cx) -> {
            input.setValue(name, window, cast cx);
        });
        activeGroupIndex = 0;
        activeIndex = exactIndex != null ? exactIndex : 0;
    }

    public function commandEntries(cx:AppContext):Array<CommandEntry> {
        return [for (group in stories) for (story in group.stories) componentCommand(story.read(cx).name)];
    }

    public function selectStory(name:String, window:Window, cx:Context<Gallery>):Bool {
        final names = [for (group in stories) [for (story in group.stories) story.read(cx).name]];
        final found = findStoryIndex(names, name);
        if (found == null) {
            return false;
        }

        searchInput.update(cx, (input, cx) -> input.setValue('', window, cast cx));
        activeGroupIndex = found.group;
        activeIndex = found.story;
        cx.notify();
        return true;
    }

    public function selectStoryIndex(index:IndexPath, window:Window, cx:Context<Gallery>):Bool {
        if (index.section != 0) {
            return false;
        }
        final all = [for (group in stories) for (story in group.stories) story];
        if (index.row >= all.length) {
            return false;
        }
        final name = all[index.row].read(cx).name;
        return selectStory(name, window, cx);
    }

    public static function view(initStory:Null<String>, window:Window, cx:AppContext):Entity<Gallery> {
        return cx.newEntity((cx:Context<Gallery>) -> new Gallery(initStory, window, cx));
    }

    public static function embeddedView(story:String, window:Window, cx:AppContext):Entity<Gallery> {
        return cx.newEntity((cx:Context<Gallery>) -> new Gallery(story, window, cx, true));
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final self:Context<Gallery> = cast cx;
        final theme = Theme.global(cx);
        final query = asciiLower(StringTools.trim(searchInput.read(cx).value()));

        final filtered:Array<{name:String, stories:Array<Entity<StoryContainer>>}> = [];
        for (group in stories) {
            final filteredItems = [for (story in group.stories) if (asciiLower(story.read(cx).name).indexOf(query) >= 0) story];
            if (filteredItems.length > 0) {
                filtered.push({name: group.name, stories: filteredItems});
            }
        }

        final activeGroup = activeGroupIndex != null && activeGroupIndex < filtered.length ? filtered[activeGroupIndex] : null;
        final activeStory = activeIndex != null && activeGroup != null && activeIndex < activeGroup.stories.length ? activeGroup.stories[activeIndex] : null;
        final storyName = activeStory != null ? activeStory.read(cx).name : '';
        final description = activeStory != null ? activeStory.read(cx).description : '';

        final currentStory = storyName;
        var totalComponents = 0;
        for (group in stories) totalComponents += group.stories.length;

        if (embedded) {
            final element = div().id('embedded-story').sizeFull();
            if (activeStory != null) element.child(activeStory);
            return element;
        }

        final storyArea = div().id('story').flex1().overflowYScroll();
        if (activeStory != null) storyArea.child(activeStory);

        final content = vFlex()
            .flex1()
            .hFull()
            .overflowXHidden()
            .child(hFlex()
                .id('header')
                .p4()
                .borderB1()
                .borderColor(theme.border)
                .justifyBetween()
                .itemsStart()
                .child(vFlex()
                    .gap1()
                    .child(div().text2xl().fontSemibold().child(storyName))
                    .child(div().textColor(theme.mutedForeground).child(description))))
            .child(storyArea);

        final menus:Array<SidebarMenu> = [];
        for (groupIx in 0...filtered.length) {
            final subStories = filtered[groupIx].stories;
            menus.push(new SidebarMenu().children([for (ix in 0...subStories.length) {
                new SidebarMenuItem(subStories[ix].read(cx).name)
                    .active(activeGroupIndex == groupIx && activeIndex == ix)
                    .onClick(self.listener((this_:Gallery, _:ClickEvent, _, cx:Context<Gallery>) -> {
                        this_.activeGroupIndex = groupIx;
                        this_.activeIndex = ix;
                        cx.notify();
                    }));
            }]));
        }

        // The sidebar slides out of the layout when collapsed and back when the
        // toggle in the status bar reopens it.
        final body = hFlex()
            .sizeFull()
            .child(Sidebar.component('gallery-sidebar')
                .w(px(255.))
                .collapsible(Offcanvas)
                .collapsed(collapsed)
                .header(vFlex()
                    .wFull()
                    .gap4()
                    .child(SidebarHeader.component()
                        .wFull()
                        .child(div()
                            .flex()
                            .itemsCenter()
                            .justifyCenter()
                            .rounded(theme.radiusLg)
                            .bg(theme.primary)
                            .textColor(theme.primaryForeground)
                            .size8()
                            .flexShrink0()
                            .child(glaze.kit.Icon.component(IconName.GalleryVerticalEnd)))
                        .child(vFlex()
                            .gap0()
                            .textSm()
                            .flex1()
                            .lineHeight(relative(1.25))
                            .overflowHidden()
                            .textEllipsis()
                            .child('GPUI Component')
                            .child(div()
                                .textColor(theme.mutedForeground)
                                .child('Component showcase')
                                .textXs())))
                    .child(div()
                        .bg(theme.sidebarAccent)
                        .roundedFullStyle(cx.app)
                        .px1()
                        .flex1()
                        .mx1()
                        .child(Input.component(searchInput)
                            .appearance(false)
                            .cleanable(true))))
                .children(menus))
            .child(content);

        final statusBar = StatusBar.component()
            .child(Button.component('toggle-sidebar')
                .ghost()
                .xsmall()
                .icon(collapsed ? IconName.PanelLeftOpen : IconName.PanelLeftClose)
                .tooltip(collapsed ? 'Show sidebar' : 'Hide sidebar')
                .onClick(self.listener((this_:Gallery, _:ClickEvent, _, cx:Context<Gallery>) -> {
                    this_.collapsed = !this_.collapsed;
                    cx.notify();
                })))
            .child(glaze.kit.Icon.component(IconName.GalleryVerticalEnd).xsmall())
            .child('$totalComponents components')
            .child(glaze.kit.separator.Separator.vertical());
        if (currentStory != '') {
            statusBar.child(currentStory);
        }
        statusBar
            .right(theme.themeName())
            .right('v$VERSION')
            .right(Button.component('assistant')
                .ghost()
                .xsmall()
                .icon(IconName.Github)
                .tooltip('GPUI Component GitHub repository')
                .onClick((_, _, cx) -> cx.openUrl('https://github.com/longbridge/gpui-kit')));

        return vFlex()
            .sizeFull()
            .child(div().flex1().minH0().child(body))
            .child(statusBar);
    }

}
