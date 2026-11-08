// Ported from gpui-kit 0.8.1: crates/story/src/stories/sheet_story.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.

package story.stories;

import glaze.App;
import glaze.Context;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.IntoElement;
import glaze.Model;
import glaze.Render;
import glaze.Window;
import glaze.Action;
import glaze.ElementId;
import glaze.Task;
import glaze.Unit;
import glaze.WeakEntity;
import glaze.kit.base.Geometry.Placement;
import glaze.kit.base.IndexPath;
import glaze.kit.base.input.InputState;
import glaze.kit.Icon;
import glaze.kit.IconName;
import glaze.kit.button.Button;
import glaze.kit.button.Button.ButtonVariant;
import glaze.kit.input.Input;
import glaze.kit.list.List;
import glaze.kit.list.ListDelegate;
import glaze.kit.list.ListItem;
import glaze.kit.list.ListState;
import glaze.kit.theme.Theme;
import glaze.kit.time.DatePicker;
import glaze.kit.time.DatePicker.DatePickerState;
import story.StoryActions.TestAction;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;
import story.Story;
import story.StoryActions.ChangeStorySize;

import story.Lib.*;

using glaze.kit.base.StyledExt;
using glaze.kit.WindowExt;

/** Rust `ToggleSheetOption::Overlay`. */
@:action(namespace = sheet_story, name = Overlay, noJson) private class ToggleSheetOverlay implements Action {}

/** Rust `ToggleSheetOption::OverlayClosable`. */
@:action(namespace = sheet_story, name = OverlayClosable, noJson) private class ToggleSheetOverlayClosable implements Action {}

/** Rust `ListItemDeletegate` (sic). */
class ListItemDeletegate extends ListDelegateBase {

    final storyView:WeakEntity<SheetStory>;

    var confirmedIndex:Null<Int> = null;

    var selectedIndex:Null<Int> = null;

    final items:Array<String>;

    var matches:Array<String>;

    public function new(storyView:WeakEntity<SheetStory>, items:Array<String>) {
        this.storyView = storyView;
        this.items = items;
        this.matches = items.copy();
    }

    public function itemsCount(_:Int, _:App):Int {
        return matches.length;
    }

    override public function performSearch(query:String, _:Window, cx:Context<ListState<Dynamic>>):Task<Unit> {
        return cx.spawn((this_, acx) -> {
            // Simulate a slow search.
            final sleep = 0.05 + Math.random() * 0.05;
            return acx.backgroundExecutor().timer(sleep).then(_ -> {
                if (!this_.isUpgradable()) return;
                this_.update(acx, (list, cx) -> {
                    final delegate:ListItemDeletegate = cast list.delegateMut();
                    final lower = query.toLowerCase();
                    delegate.matches = [for (item in delegate.items) if (item.toLowerCase().indexOf(lower) >= 0) item];
                    cx.notify();
                });
            });
        });
    }

    public function renderItem(ix:IndexPath, _:Window, _:Context<ListState<Dynamic>>):Null<ListDelegateItem> {
        final confirmed = ix.row == confirmedIndex;
        if (ix.row >= 0 && ix.row < matches.length) {
            final item = matches[ix.row];
            return new ListItem(ElementId.NamedInteger('item', ix.row))
                .checkIcon(IconName.Check)
                .confirmed(confirmed)
                .child(hFlex().itemsCenter().justifyBetween().child(item))
                .suffix((_, _) -> Button.component('like')
                    .tabStop(false)
                    .icon(IconName.Heart)
                    .withVariant(ButtonVariant.Ghost)
                    .size(px(18.))
                    .onClick((_, window, cx) -> {
                        cx.stopPropagation();
                        window.preventDefault();
                        trace('You have clicked like.');
                    }));
        }
        return null;
    }

    override public function renderEmpty(_:Window, cx:Context<ListState<Dynamic>>):IntoElement {
        final theme = Theme.global(cx.app);
        // Rust `Icon::size(px(50.))` is the Styled `size` (the Icon field of the same name hides it here).
        final icon = Icon.component(IconName.Inbox);
        new glaze.StyleBuilder(icon.style()).size(px(50.));
        return vFlex()
            .sizeFull()
            .child(icon.textColor(theme.mutedForeground))
            .child('No matches found')
            .itemsCenter()
            .justifyCenter()
            .p3()
            .bg(theme.muted)
            .textColor(theme.mutedForeground);
    }

    override public function cancel(window:Window, cx:Context<ListState<Dynamic>>):Void {
        if (storyView.isUpgradable()) storyView.update(cx, (this_, cx) -> this_.closeSheet(window, cx));
    }

    override public function confirm(_:Bool, _:Window, cx:Context<ListState<Dynamic>>):Void {
        if (!storyView.isUpgradable()) return;
        storyView.update(cx, (this_, _) -> {
            confirmedIndex = selectedIndex;
            if (confirmedIndex != null && confirmedIndex < matches.length) {
                this_.selectedValue = matches[confirmedIndex];
            }
        });
    }

    public function setSelectedIndex(ix:Null<IndexPath>, _:Window, cx:Context<ListState<Dynamic>>):Void {
        selectedIndex = ix != null ? ix.row : null;
        if (ix != null) {
            cx.notify();
        }
    }

}

class SheetStory extends Model implements Story {

    public static function title():String {
        return 'Sheet';
    }

    public static function description():String {
        return 'Sheet for open a popup in the edge of the window';
    }

    public static function newView(window:Window, cx:App):glaze.AnyView {
        return view(window, cx);
    }

    public static function view(window:Window, cx:App):Entity<SheetStory> {
        return cx.newEntity((c:Context<SheetStory>) -> new SheetStory(window, c));
    }

    final focusHandle_:FocusHandle;

    var placement:Null<Placement> = null;

    @:allow(story.stories)
    @observe var selectedValue:Null<String> = null;

    final list:Entity<ListState<ListItemDeletegate>>;

    final input1:Entity<InputState>;

    final input2:Entity<InputState>;

    final date:Entity<DatePickerState>;

    @observe var overlay:Bool = true;

    @observe var overlayClosable:Bool = true;

    function new(window:Window, cx:Context<SheetStory>) {
        super();
        final items = [
            'Baguette (France)',
            'Baklava (Turkey)',
            'Beef Wellington (UK)',
            'Biryani (India)',
            'Borscht (Ukraine)',
            'Bratwurst (Germany)',
            'Bulgogi (Korea)',
            'Burrito (USA)',
            'Ceviche (Peru)',
            'Chicken Tikka Masala (India)',
            'Churrasco (Brazil)',
            'Couscous (North Africa)',
            'Croissant (France)',
            'Dim Sum (China)',
            'Empanada (Argentina)',
            'Fajitas (Mexico)',
            'Falafel (Middle East)',
            'Feijoada (Brazil)',
            'Fish and Chips (UK)',
            'Fondue (Switzerland)',
            'Goulash (Hungary)',
            'Haggis (Scotland)',
            'Kebab (Middle East)',
            'Kimchi (Korea)',
            'Lasagna (Italy)',
            'Maple Syrup Pancakes (Canada)',
            'Moussaka (Greece)',
            'Pad Thai (Thailand)',
            'Paella (Spain)',
            'Pancakes (USA)',
            'Pasta Carbonara (Italy)',
            'Pavlova (Australia)',
            'Peking Duck (China)',
            'Pho (Vietnam)',
            'Pierogi (Poland)',
            'Pizza (Italy)',
            'Poutine (Canada)',
            'Pretzel (Germany)',
            'Ramen (Japan)',
            'Rendang (Indonesia)',
            'Sashimi (Japan)',
            'Satay (Indonesia)',
            "Shepherd's Pie (Ireland)",
            'Sushi (Japan)',
            'Tacos (Mexico)',
            'Tandoori Chicken (India)',
            'Tortilla (Spain)',
            'Tzatziki (Greece)',
            'Wiener Schnitzel (Austria)',
        ];
        final storyView = cx.weakEntity();
        final delegate = new ListItemDeletegate(storyView, items);
        list = cx.newEntity((cx:Context<ListState<ListItemDeletegate>>) -> new ListState(delegate, window, cx).searchable(true));
        input1 = cx.newEntity((cx:Context<InputState>) -> new InputState(window, cx).withPlaceholder('Your Name'));
        input2 = cx.newEntity((cx:Context<InputState>) -> new InputState(window, cx).withPlaceholder('For test focus back on dialog close.'));
        date = cx.newEntity((cx:Context<DatePickerState>) -> new DatePickerState(window, cx));
        focusHandle_ = cx.focusHandle();
    }

    function openSheetAt(placement:Placement, window:Window, cx:App):Void {
        final list = this.list;
        final drawerH = switch placement {
            case Left | Right: px(400.);
            case Top | Bottom: px(540.);
        }
        final overlay = this.overlay;
        final overlayClosable = this.overlayClosable;
        final input1 = this.input1;
        final date = this.date;
        window.openSheetAt(placement, cx, (this_, _, cx) -> {
            final theme = Theme.global(cx);
            return this_.overlay(overlay)
                .overlayClosable(overlayClosable)
                .size(drawerH)
                .title('Sheet Title')
                .child(vFlex()
                    .sizeFull()
                    .gap3()
                    .child(Input.component(input1))
                    .child(DatePicker.component(date).placeholder('Date of Birth'))
                    .child(Button.component('send-notification')
                        .child('Test Notification')
                        .onClick((_, window, cx) -> window.pushNotification('Hello this is message from Sheet.', cx)))
                    .child(Button.component('confirm-dialog-from-sheet')
                        .child('Open Confirm Dialog')
                        .onClick((_, window, cx) -> {
                            window.openAlertDialog(cx, (dialog, _, _) -> dialog
                                .child('Confirm dialog opened from sheet.')
                                .onOk((_, window, cx) -> {
                                    window.pushNotification('You have pressed ok.', cx);
                                    return true;
                                })
                                .onCancel((_, window, cx) -> {
                                    window.pushNotification('You have pressed cancel.', cx);
                                    return true;
                                }));
                        }))
                    .child(List.component(list)
                        .border1()
                        .borderColor(theme.border)
                        .rounded(theme.radius)))
                .footer(hFlex()
                    .gap6()
                    .itemsCenter()
                    .child(Button.component('confirm').primary().label('Confirm').onClick((_, window, cx) -> window.closeSheet(cx)))
                    .child(Button.component('cancel').label('Cancel').onClick((_, window, cx) -> window.closeSheet(cx))));
        });
    }

    @:allow(story.stories)
    function closeSheet(_:Window, cx:Context<SheetStory>):Void {
        placement = null;
        cx.notify();
    }

    function onActionTestAction(_:TestAction, window:Window, cx:App):Void {
        window.pushNotification('You have clicked the TestAction.', cx);
    }

    public function focusHandle(_:App):FocusHandle {
        return focusHandle_;
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        final overlay = this.overlay;
        final overlayClosable = this.overlayClosable;
        final content = vFlex()
            .gap6()
            .child(storyToolbarGroup().dropdownChild(Button.component('sheet-options').label('Options'), (menu, _, _) -> menu
                .menuWithCheck('Overlay', overlay, new ToggleSheetOverlay())
                .menuWithCheck('Close on overlay click', overlayClosable, new ToggleSheetOverlayClosable())))
            .child(section('Placement')
                .description('Open a sheet from any edge of the window.')
                .child(Button.component('show-sheet-left').outline().label('Left Sheet...').onClick((_, window, cx) -> openSheetAt(Placement.Left, window, cx)))
                .child(Button.component('show-sheet-top').outline().label('Top Sheet...').onClick((_, window, cx) -> openSheetAt(Placement.Top, window, cx)))
                .child(Button.component('show-sheet-right').outline().label('Right Sheet...').onClick((_, window, cx) -> openSheetAt(Placement.Right, window, cx)))
                .child(Button.component('show-sheet-bottom').outline().label('Bottom Sheet...').onClick((_, window, cx) -> openSheetAt(Placement.Bottom, window, cx))))
            .child(section('Scrollable Sheet').w(px(480.)).child(Button.component('show-scrollable-sheet')
                .outline()
                .label('Scrollable Sheet...')
                .onClick((_, window, cx) -> {
                    window.openSheetAt(Placement.Right, cx, (this_, _, _) -> this_
                        .title('Scrollable Sheet')
                        .child([for (_ in 0...150) 'This is a scrollable sheet.\n'].join('')));
                })))
            .child(section('Focus back test')
                .w128()
                .child(Input.component(input2))
                .child(Button.component('test-action')
                    .outline()
                    .label('Test Action')
                    .flexShrink0()
                    .onClick((_, window, cx) -> window.dispatchAction(new TestAction(), cx))
                    .tooltip('This button for test dispatch action, to make sure when Dialog close,\nthis still can handle the action.')));
        if (selectedValue != null) {
            content.child(hFlex().gap1().child('You have selected:').child(div().child(selectedValue).textColor(red())));
        }
        return div()
            .id('sheet-story')
            .trackFocus(focusHandle_)
            .onAction(TestAction, onActionTestAction)
            .onAction(ToggleSheetOverlay, (_, _, _) -> this.overlay = !this.overlay)
            .onAction(ToggleSheetOverlayClosable, (_, _, _) -> this.overlayClosable = !this.overlayClosable)
            .sizeFull()
            .child(content);
    }

}
