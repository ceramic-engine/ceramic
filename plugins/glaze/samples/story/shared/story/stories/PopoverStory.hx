// Ported from gpui-kit 0.8.1: crates/story/src/stories/popover_story.rs
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
import glaze.Anchor;
import glaze.DismissEvent;
import glaze.KeyBinding;
import glaze.MouseButton;
import glaze.WeakEntity;
import glaze.kit.base.IndexPath;
import glaze.kit.base.input.InputState;
import glaze.kit.button.Button;
import glaze.kit.checkbox.Checkbox;
import glaze.kit.input.Input;
import glaze.kit.list.List;
import glaze.kit.list.ListDelegate;
import glaze.kit.list.ListItem;
import glaze.kit.list.ListState;
import glaze.kit.menu.PopupMenu;
import glaze.kit.popover.Popover;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;
import story.Story;
import story.StoryActions.ChangeStorySize;

import story.Lib.*;

using glaze.kit.base.StyledExt;
using glaze.kit.WindowExt;
using glaze.kit.menu.DropdownMenu;

/** Rust `Info(usize)` (renamed: `Info` clashes with `ButtonVariant.Info`). */
@:action(namespace = popover_story, name = Info, noJson) private class InfoAction implements Action {
    public final value:Int;

    public function new(value:Int) {
        this.value = value;
    }
}

@:action(namespace = popover_story) private class Copy implements Action {}

@:action(namespace = popover_story) private class Paste implements Action {}

@:action(namespace = popover_story) private class Cut implements Action {}

@:action(namespace = popover_story) private class SearchAll implements Action {}

@:action(namespace = popover_story) private class ToggleCheck implements Action {}

private class Form extends Model implements Render {

    final parent:WeakEntity<PopoverStory>;

    final input1:Entity<InputState>;

    function new(parent:WeakEntity<PopoverStory>, window:Window, cx:Context<Form>) {
        super();
        this.parent = parent;
        input1 = cx.newEntity((cx:Context<InputState>) -> new InputState(window, cx));
    }

    public static function create(parent:WeakEntity<PopoverStory>, window:Window, cx:App):Entity<Form> {
        return cx.newEntity((cx:Context<Form>) -> new Form(parent, window, cx));
    }

    public function focusHandle(cx:App):FocusHandle {
        return input1.read(cx).focusHandle;
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        final parent = this.parent;
        return vFlex()
            .gap2()
            .p3()
            .sizeFull()
            .child('This is a form container.')
            .child('Click submit to dismiss the popover.')
            .child(Input.component(input1))
            .child(Button.component('submit')
                .label('Submit')
                .primary()
                .onClick((_, _, cx) -> {
                    parent.update(cx, (this_, _) -> this_.formPopoverOpen = false);
                }));
    }

}

private class DropdownListDelegate extends ListDelegateBase {

    final parent:WeakEntity<PopoverStory>;

    public function new(parent:WeakEntity<PopoverStory>) {
        this.parent = parent;
    }

    public function itemsCount(_:Int, _:App):Int {
        return 10;
    }

    public function renderItem(ix:IndexPath, _:Window, _:Context<ListState<Dynamic>>):Null<ListDelegateItem> {
        return new ListItem(ix.toElementId()).child('Item ${ix.row}');
    }

    public function setSelectedIndex(_:Null<IndexPath>, _:Window, _:Context<ListState<Dynamic>>):Void {}

    override public function confirm(_:Bool, _:Window, cx:Context<ListState<Dynamic>>):Void {
        parent.update(cx, (this_, _) -> this_.listPopoverOpen = false);
    }

    override public function cancel(_:Window, cx:Context<ListState<Dynamic>>):Void {
        parent.update(cx, (this_, _) -> this_.listPopoverOpen = false);
    }

}

class PopoverStory extends Model implements Story {

    static inline final CONTEXT = 'popover-story';

    public static function title():String {
        return 'Popover';
    }

    public static function description():String {
        return 'Show focused content beside a trigger.';
    }

    public static function init(cx:App):Void {
        final mac = isMacos();
        cx.bindKeys([
            new KeyBinding(mac ? 'cmd-c' : 'ctrl-c', new Copy(), CONTEXT),
            new KeyBinding(mac ? 'cmd-v' : 'ctrl-v', new Paste(), CONTEXT),
            new KeyBinding(mac ? 'cmd-x' : 'ctrl-x', new Cut(), CONTEXT),
            new KeyBinding(mac ? 'cmd-shift-f' : 'ctrl-shift-f', new SearchAll(), CONTEXT),
        ]);
    }

    public static function newView(window:Window, cx:App):glaze.AnyView {
        return view(window, cx);
    }

    public static function view(window:Window, cx:App):Entity<PopoverStory> {
        return cx.newEntity((c:Context<PopoverStory>) -> new PopoverStory(window, c));
    }

    final focusHandle_:FocusHandle;

    final form:Entity<Form>;

    final list:Entity<ListState<DropdownListDelegate>>;

    @:allow(story.stories)
    @observe var formPopoverOpen:Bool = false;

    @:allow(story.stories)
    @observe var listPopoverOpen:Bool = false;

    @observe var arrow:Bool = false;

    @observe var checked:Bool = true;

    @observe var message:String = '';

    function new(window:Window, cx:Context<PopoverStory>) {
        super();
        form = Form.create(cx.weakEntity(), window, cx.app);
        final parent = cx.weakEntity();
        list = cx.newEntity((cx:Context<ListState<DropdownListDelegate>>) -> new ListState(new DropdownListDelegate(parent), window, cx).searchable(true));
        // Rust `cx.focus_self(window)`: deferred focus of this view's handle.
        final focusHandle = cx.focusHandle();
        window.defer(cx.app, (window, cx) -> focusHandle.focus(window, cx));
        focusHandle_ = focusHandle;
    }

    function onCopy(_:Copy, _:Window, _:App):Void {
        message = 'You have clicked copy';
    }

    function onCut(_:Cut, _:Window, _:App):Void {
        message = 'You have clicked cut';
    }

    function onPaste(_:Paste, _:Window, _:App):Void {
        message = 'You have clicked paste';
    }

    function onSearchAll(_:SearchAll, _:Window, _:App):Void {
        message = 'You have clicked search all';
    }

    function onActionInfo(info:InfoAction, _:Window, _:App):Void {
        message = 'You have clicked info: ${info.value}';
    }

    function onActionToggleCheck(_:ToggleCheck, _:Window, _:App):Void {
        checked = !checked;
        message = 'You have clicked toggle check: $checked';
    }

    public function focusHandle(_:App):FocusHandle {
        return focusHandle_;
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        final theme = Theme.global(cx.app);
        final form = this.form;
        final arrow = this.arrow;
        return vFlex()
            .keyContext(CONTEXT)
            .trackFocus(focusHandle_)
            .onAction(Copy, onCopy)
            .onAction(Cut, onCut)
            .onAction(Paste, onPaste)
            .onAction(SearchAll, onSearchAll)
            .onAction(InfoAction, onActionInfo)
            .onAction(ToggleCheck, onActionToggleCheck)
            .sizeFull()
            .gap6()
            .child(section('Default')
                .description('Display lightweight contextual content.')
                .child(Popover.component('popover-0')
                    .maxW(px(600.))
                    .trigger(Button.component('btn').outline().label('Popover'))
                    .gap2()
                    .textSm()
                    .w(px(400.))
                    .child('Hello, this is a Popover.')
                    .child(glaze.kit.separator.Separator.horizontal())
                    .child('You can put any content here, including text,buttons, forms, and more.'))
                .child(Popover.component('default-open-popover')
                    .defaultOpen(true)
                    .trigger(Button.component('default-open-btn').label('Default Open').outline())
                    .child('This popover is open by default when first rendered.')))
            .child(section('Form')
                .description('Keep focus and controlled open state around a form.')
                .child(Popover.component('popover-form')
                    .p0()
                    .textSm()
                    .trigger(Button.component('pop').outline().label('Popup Form'))
                    .trackFocus(form.read(cx.app).focusHandle(cx.app))
                    .open(formPopoverOpen)
                    .onOpenChange((open, _, _) -> {
                        trace('Popover form open changed: $open');
                        formPopoverOpen = open;
                    })
                    .child(form)))
            .child(section('List')
                .description('Place a scrollable selection list in the popover.')
                .child(Popover.component('popover-list')
                    .p0()
                    .textSm()
                    .open(listPopoverOpen)
                    .onOpenChange((open, _, _) -> listPopoverOpen = open)
                    .trigger(Button.component('pop').outline().label('Popup List'))
                    .trackFocus(list.read(cx.app).focusHandle(cx.app))
                    .child(List.component(list))
                    .w64()
                    .h(px(200.))))
            .child(section('Right click')
                .description('Open from the secondary mouse button.')
                .child(Popover.component('popover-right-click')
                    .mouseButton(MouseButton.Right)
                    .trigger(Button.component('btn').outline().label('Right Click Popover'))
                    .maxW(px(600.))
                    .content((_, _, cx) -> vFlex()
                        .gap2()
                        .child('Hello, this is a Popover on the Bottom Right.')
                        .child(glaze.kit.separator.Separator.horizontal())
                        .child(Button.component('info1')
                            .primary()
                            .label('Dismiss')
                            .w(px(80.))
                            .onClick(cx.listener((_, _, window, cx) -> {
                                window.pushNotification('You have clicked dismiss via DismissEvent.', cx.app);
                                cx.emit(DismissEvent.instance);
                            }))))))
            .child(section('Custom style')
                .description('Customize appearance, radius, and shadow.')
                .child(Popover.component('popover-1')
                    .trigger(Button.component('btn').outline().label('Style Popover'))
                    .appearance(false)
                    .py1()
                    .px2()
                    .bg(theme.primary)
                    .textColor(theme.primaryForeground)
                    .maxW(px(600.))
                    .rounded(theme.radius / 2)
                    .textSm()
                    .shadow2xl()
                    .child('A styled Popover with custom background and text color.')))
            .child(section('Async submenu')
                .description('Rebuild submenu content after asynchronous loading.')
                .child(Button.component('async-menu')
                    .outline()
                    .label('Async Menu')
                    .dropdownMenu((menu, window, cx) -> {
                        // The submenu is attached as a plain menu value, its
                        // content is loaded asynchronously via `rebuild`.
                        final submenu = PopupMenu.build(window, cx.app, (menu, _, _) -> menu.label('Loading...'));
                        final app = cx.app;
                        app.backgroundExecutor().timer(1.).then(_ -> {
                            if (window.isDestroyed()) return;
                            submenu.update(app, (menu, cx) -> menu.rebuild(window, cx, (menu, _, _) -> {
                                for (ix in 1...4) menu = menu.menu('Loaded Item $ix', new InfoAction(ix));
                                return menu;
                            }));
                        });
                        return menu.menu('Copy', new Copy())
                            .separator()
                            .item(PopupMenuItem.submenu('Async Submenu', submenu));
                    }))
                .child(message))
            .child(section('Anchor')
                .description('Position content from each edge of the trigger.')
                .subTitle(Checkbox.component('anchor-arrow')
                    .label('Arrow')
                    .checked(arrow)
                    .onChange((checked, _, _) -> this.arrow = checked))
                .wFull()
                .minH(rems(14.))
                .vFlex()
                .justifyBetween()
                .children([for (anchors in [
                    [Anchor.TopLeft, Anchor.TopCenter, Anchor.TopRight],
                    [Anchor.LeftCenter, Anchor.RightCenter],
                    [Anchor.BottomLeft, Anchor.BottomCenter, Anchor.BottomRight],
                ]) (hFlex()
                    .wFull()
                    .justifyBetween()
                    .children([for (anchor in anchors) {
                        final label = anchor.toString();
                        (Popover.component('anchor-$label')
                            .anchor(anchor)
                            .arrow(arrow)
                            .trigger(Button.component('trigger').small().outline().label(label))
                            .child('Popover content') : IntoElement);
                    }]) : IntoElement)]));
    }

}
