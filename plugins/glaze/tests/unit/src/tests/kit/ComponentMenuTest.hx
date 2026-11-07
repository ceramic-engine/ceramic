// Ported from gpui-kit 0.8.1: crates/component/src/menu/{menu_item,popup_menu,context_menu,app_menu_bar}.rs (tests),
// crates/kit/tests/integration/menu.rs (the menu steps that do not need inputs)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.Action;
import glaze.App;
import glaze.ClickEvent;
import glaze.Context;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.IntoElement;
import glaze.KeyBinding;
import glaze.KeyDownEvent;
import glaze.KeyUpEvent;
import glaze.Keystroke;
import glaze.Model;
import glaze.Modifiers;
import glaze.MouseButton;
import glaze.MouseDownEvent;
import glaze.MouseUpEvent;
import glaze.Point;
import glaze.Render;
import glaze.TestDispatcher;
import glaze.WeakEntity;
import glaze.Window;
import glaze.kit.Component;
import glaze.kit.button.Button;
import glaze.kit.button.Button.ButtonVariant;
import glaze.kit.button.DropdownButton;
import glaze.kit.Size;
import glaze.kit.menu.AppMenuBar;
import glaze.kit.menu.MenuItemElement;
import glaze.kit.menu.PopupMenu;
import tests.kit.ComponentScrollTest.Probe;
import testing.InteractionScript.ScriptView;
import testing.TestCase;
import testing.VisualTestContext;

import glaze.Prelude.*;

using glaze.kit.menu.ContextMenu.ContextMenuExt;
using glaze.kit.menu.DropdownMenu;
using glaze.kit.button.Button.ButtonVariantTools;

/**
 * The `#[cfg(test)]` tests of gpui-component's `menu` module, and the menu
 * steps of gpui-kit's integration tests.
 *
 * Rust queries the rendered UI with `debug_selector` / test support ids;
 * the port probes bounds with `Probe`, captures the `PopupMenu` entities
 * from their builders, and tells whether a menu is shown by whether its
 * view was rendered in the last frame (`isShown`).
 *
 * Not ported: the menu steps
 * of the integration tests that need inputs (`context_menu_preserves_only_its_inputs_selection...`,
 * `right_click_on_unfocused_input_keeps_selection`, `submenu_select_all_uses_the_parent_input_action_target`,
 * `hovering_away_from_a_keyboard_entered_submenu_refocuses_its_parent`: inputs come later).
 */
class ComponentMenuTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    final contexts:Array<VisualTestContext> = [];

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        app.update(cx -> Component.init(cx));
        Probe.bounds.clear();
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        for (cx in contexts) cx.destroy();
        contexts.resize(0);
        Probe.bounds.clear();
        ceramic.App.app.flushImmediate();
    }

    function open<V:Model & Render>(build:(Window, Context<V>) -> V, width:Float = 1920, height:Float = 1080):{view:Entity<V>, cx:VisualTestContext} {
        final opened = VisualTestContext.addWindowView(app, dispatcher, build, width, height);
        contexts.push(opened.cx);
        return opened;
    }

    static function draw(cx:VisualTestContext):Void {
        cx.update((window, _) -> window.draw());
    }

    /**
     * Whether `menu`'s view was rendered in the last frame (Rust: `window.try_find("popup-menu")`).
     */
    static function isShown(cx:VisualTestContext, menu:Null<WeakEntity<PopupMenu>>):Bool {
        if (menu == null)
            return false;
        final entity = menu.upgrade();
        if (entity == null)
            return false;
        return @:privateAccess cx.window.renderedFrame.dispatchTree.viewNodeIds.exists(entity.entityId());
    }

    static function menuOf(menu:Null<WeakEntity<PopupMenu>>):PopupMenu {
        return menu.upgrade();
    }

    /**
     * `press_context_menu_key`: native key down and key up arrive in
     * separate app updates.
     */
    static function pressContextMenuKey(cx:VisualTestContext, key:String):Void {
        final keystroke = Keystroke.parse(key);
        cx.update((window, app) -> window.dispatchEvent(new KeyDownEvent(keystroke, false, false), app));
        // Process the dismissal subscription before key-up can redraw and
        // refocus the menu.
        cx.runUntilParked();
        cx.update((window, app) -> window.dispatchEvent(new KeyUpEvent(keystroke), app));
        cx.runUntilParked();
    }

    /// menu_item.rs

    function testAriaLabelSetsAccessibleName() {
        final item = new MenuItemElement('open').ariaLabel('Open');
        assertEquals('Open', item.ariaLabelValue);
    }

    /// popup_menu.rs

    function testCustomMenuItemPreservesMouseEvent() {
        final events:Array<ClickEvent> = [];
        final opened = open((_, cx:Context<PopupMenu>) -> @:privateAccess new PopupMenu(cx).item(
            PopupMenuItem.element((_, _) -> new Probe('custom-menu-content', div()
                .w(px(100.))
                .h(px(20.))
                .child('Custom')))
                .onClick((event, _, _) -> events.push(event))
        ));
        final cx = opened.cx;
        draw(cx);
        final position = Probe.bounds.get('custom-menu-content').center();
        final modifiers = Modifiers.of(false, false, true);
        cx.simulateMouseDown(position, Left, modifiers);
        cx.simulateEvent(new MouseUpEvent(Left, position, modifiers, 2));
        cx.runUntilParked();
        assertEquals(1, events.length);
        switch events[0] {
            case Mouse(event):
                assertTrue(event.up.position.equals(position));
                assertTrue(event.up.modifiers == modifiers);
                assertEquals(2, event.up.clickCount);
            case _:
                fail('expected the original mouse click');
        }
    }

    function testPopupMenuItemA11yLabelUsesVisibleLabel() {
        final submenu = app.update(cx -> cx.newEntity((cx:Context<PopupMenu>) -> @:privateAccess new PopupMenu(cx)));
        assertEquals('Open', PopupMenuItem.create('Open').a11yLabel());
        assertEquals('Docs', PopupMenuItem.link('Docs', 'https://example.com').a11yLabel());
        assertEquals('Recent files', PopupMenuItem.label('Recent files').a11yLabel());
        assertEquals('More', PopupMenuItem.submenu('More', submenu).a11yLabel());
        assertEquals(null, PopupMenuItem.separator().a11yLabel());
        assertEquals(null, PopupMenuItem.element((_, _) -> div()).a11yLabel());
    }

    /// context_menu.rs

    /**
     * The regression shape: the action handler lives on the trigger's
     * ancestor (like an action bar), which is NOT on the focus path while
     * focus is in the content area.
     */
    function testActionBubblesFromTriggerAndFocusRestoresOnDismiss() {
        var received = false;
        var contentFocus:FocusHandle = null;
        final opened = open((window, cx:Context<ScriptView>) -> {
            contentFocus = cx.focusHandle();
            contentFocus.focus(window, cx.app);
            return new ScriptView((_, _) -> div()
                .sizeFull()
                .child(
                    div()
                        .id('content')
                        .h(px(40.))
                        .trackFocus(contentFocus)
                )
                .child(
                    div()
                        .id('action-bar')
                        .h(px(60.))
                        .onAction(RemoveTab, (_, _, _) -> received = true)
                        .child(
                            div()
                                .id('tab')
                                .sizeFull()
                                .contextMenu((menu, _, _) -> menu.menu('Close', new RemoveTab()))
                        )
                ));
        });
        final cx = opened.cx;
        cx.runUntilParked();
        draw(cx);

        // Right-click inside the tab to open the context menu.
        cx.simulateEvent(new MouseDownEvent(Right, new Point(50., 70.), Modifiers.none(), 1, false));
        // The menu entity is built and focused in a deferred callback, then
        // rendered on the next draw.
        cx.runUntilParked();
        draw(cx);

        // Select "Close" and confirm. Keyboard confirm and mouse click share
        // the same `confirm` path in `PopupMenu`.
        cx.simulateKeystrokes('down enter');
        cx.runUntilParked();

        // The action must reach the handler on the trigger's ancestor chain,
        // even though the action bar was never on the focus path.
        assertTrue(received);
        // And dismiss must restore focus to where it was before the menu
        // opened, keeping the dangling-focus fix (#2614).
        cx.update((window, app) -> assertEquals(contentFocus, window.focused(app)));
    }

    /**
     * The issue shape (#3134): rows rendered from one call site without an
     * `ElementId` share the context menu's element state.
     */
    function testItemClickFiresOnceFromRowsWithoutAnId() {
        var clicked = 0;
        final opened = open((_, _) -> new ScriptView((_, _) -> div().sizeFull().children([for (_ in 0...3) (div()
            .w(px(100.))
            .h(px(30.))
            .contextMenu((menu, _, _) -> menu.item(PopupMenuItem.create('Favorite').onClick((_, _, _) -> clicked++))) : IntoElement)])));
        final cx = opened.cx;
        draw(cx);

        // Right-click the second row; the menu opens at the press position.
        final press = new Point(10., 40.);
        cx.simulateMouseDown(press, Right);
        cx.simulateMouseUp(press, Right);
        cx.runUntilParked();
        draw(cx);

        // Click the first item, which sits inside the menu's content padding.
        final item = new Point(press.x + 30., press.y + 17.);
        cx.simulateMouseMove(item);
        cx.simulateClick(item);
        cx.runUntilParked();

        assertEquals(1, clicked, "the item's on_click must fire exactly once");
    }

    /**
     * The issue shape (#3364): a frame reports one focused accessibility
     * node, claimed in prepaint by whichever focused element comes first.
     * Moving focus to the menu while prepainting it let the previous focus
     * claim the frame first.
     */
    function testMenuTakesFocusBeforeItsFirstFrame() {
        var contentFocusedAtRender = false;
        var contentFocus:FocusHandle = null;
        final opened = open((window, cx:Context<ScriptView>) -> {
            contentFocus = cx.focusHandle();
            contentFocus.focus(window, cx.app);
            return new ScriptView((window, _) -> {
                contentFocusedAtRender = contentFocus.isFocused(window);
                return div()
                    .sizeFull()
                    .child(
                        div()
                            .id('content')
                            .h(px(40.))
                            .trackFocus(contentFocus)
                    )
                    .child(
                        div()
                            .id('tab')
                            .h(px(60.))
                            .contextMenu((menu, _, _) -> menu.menu('Close', new RemoveTab()))
                    );
            });
        });
        final cx = opened.cx;
        cx.update((window, _) -> window.refresh());
        draw(cx);
        assertTrue(contentFocusedAtRender);

        cx.simulateMouseDown(new Point(50., 70.), Right);

        assertFalse(contentFocusedAtRender, 'focus must leave the content before the frame that draws the menu');
        cx.update((window, app) -> {
            final focused = window.focused(app);
            assertTrue(focused != null && focused != contentFocus);
        });
    }

    /**
     * `shortcut_hint_is_painted_on_the_frame_the_menu_opens`. Rust looks the
     * hint up with `debug_bounds("kbd:ctrl-c")`; the port has no debug
     * selectors, so the frame's glyphs are counted against the same scene
     * with a binding the menu cannot resolve.
     */
    function testShortcutHintIsPaintedOnTheFrameTheMenuOpens() {
        final withHint = shortcutHintFrame(CONTEXT);
        final withoutHint = shortcutHintFrame('other_context');
        assertEquals(withoutHint.framesBeforeOpen + 1, withoutHint.framesAfterOpen);
        assertEquals(withHint.framesBeforeOpen + 1, withHint.framesAfterOpen, 'the press must be followed by exactly one frame for this to test the first one');
        assertTrue(withHint.glyphs > withoutHint.glyphs, 'the shortcut hint must be painted on the same frame as its item');
    }

    static inline final CONTEXT = 'context_menu_test';

    function shortcutHintFrame(bindingContext:String):{framesBeforeOpen:Int, framesAfterOpen:Int, glyphs:Int} {
        app.update(cx -> cx.bindKeys([new KeyBinding('ctrl-c', new CopyText(), bindingContext)]));
        var frames = 0;
        final opened = open((_, _) -> new ScriptView((_, _) -> {
            frames++;
            return div()
                .sizeFull()
                .child(
                    div()
                        .keyContext(CONTEXT)
                        .onAction(CopyText, (_, _, _) -> {})
                        .child(
                            div()
                                .id('tab')
                                .w(px(100.))
                                .h(px(30.))
                                .contextMenu((menu, _, _) -> menu.menu('Copy', new CopyText()))
                        )
                )
                .child(div().child('Status'));
        }));
        final cx = opened.cx;
        cx.update((window, app) -> {
            window.refresh();
            window.draw();
            assertNull(window.focused(app));
        });
        final framesBeforeOpen = frames;

        // Right-click inside the tab; the menu is built in a deferred callback
        // and drawn on the frame that follows.
        cx.simulateMouseDown(new Point(10., 10.), Right);

        final framesAfterOpen = frames;
        final glyphs = cx.window.renderedScene().monochromeSprites.length;
        // Clear the bindings for the next window
        app.update(cx -> cx.clearKeyBindings());
        app.update(cx -> Component.init(cx));
        return {framesBeforeOpen: framesBeforeOpen, framesAfterOpen: framesAfterOpen, glyphs: glyphs};
    }

    /// app_menu_bar.rs

    function testPreservesActionContextWhileSwitchingMenus() {
        var firstFocus:FocusHandle = null;
        var secondFocus:FocusHandle = null;
        var menuBar:Entity<AppMenuBar> = null;
        final opened = open((window, cx:Context<ScriptView>) -> {
            firstFocus = cx.focusHandle();
            secondFocus = cx.focusHandle();
            firstFocus.focus(window, cx.app);
            menuBar = cx.newEntity((_:Context<AppMenuBar>) -> @:privateAccess new AppMenuBar());
            return new ScriptView((_, _) -> div()
                .child(div().id('first').trackFocus(firstFocus))
                .child(div().id('second').trackFocus(secondFocus))
                .child(menuBar));
        });
        final cx = opened.cx;
        cx.update((window, app) -> {
            menuBar.update(app, (menuBar, cx) -> {
                menuBar.setSelectedIndex(0, window, cx);
                assertEquals(firstFocus, menuBar.actionContext);

                secondFocus.focus(window, app);
                menuBar.setSelectedIndex(1, window, cx);
                assertEquals(firstFocus, menuBar.actionContext);

                menuBar.setSelectedIndex(null, window, cx);
                assertNull(menuBar.actionContext);
                assertEquals(firstFocus, window.focused(app));

                secondFocus.focus(window, app);
                menuBar.setSelectedIndex(0, window, cx);
                assertEquals(secondFocus, menuBar.actionContext);
            });
        });
    }

    /// dropdown_menu.rs

    /**
     * `shortcut_hint_is_painted_on_the_frame_the_menu_opens` (dropdown
     * version): the glyphs of the first frame are counted against the same
     * scene with a binding the menu cannot resolve (no debug selectors).

     */
    function testDropdownShortcutHintIsPaintedOnTheFrameTheMenuOpens() {
        final withHint = dropdownShortcutHintFrame(DROPDOWN_CONTEXT);
        final withoutHint = dropdownShortcutHintFrame('other_context');
        assertEquals(withoutHint.framesBeforeOpen + 1, withoutHint.framesAfterOpen);
        assertEquals(withHint.framesBeforeOpen + 1, withHint.framesAfterOpen, 'the press must be followed by exactly one frame for this to test the first one');
        assertTrue(withHint.glyphs > withoutHint.glyphs, 'the shortcut hint must be painted on the same frame as its item');
    }

    static inline final DROPDOWN_CONTEXT = 'dropdown_menu_test';

    function dropdownShortcutHintFrame(bindingContext:String):{framesBeforeOpen:Int, framesAfterOpen:Int, glyphs:Int} {
        app.update(cx -> cx.bindKeys([new KeyBinding('ctrl-c', new CopyText(), bindingContext)]));
        var frames = 0;
        final opened = open((_, _) -> new ScriptView((_, _) -> {
            frames++;
            return div()
                .sizeFull()
                .child(
                    div()
                        .keyContext(DROPDOWN_CONTEXT)
                        .onAction(CopyText, (_, _, _) -> {})
                        .child(
                            new Button('trigger')
                                .label('Edit')
                                .w(px(100.))
                                .h(px(30.))
                                .dropdownMenu((menu, _, _) -> menu.menu('Copy', new CopyText()))
                        )
                )
                .child(div().child('Status'));
        }));
        final cx = opened.cx;
        // The popup host captures its trigger bounds on the first frame.
        cx.update((window, _) -> {
            window.refresh();
            window.draw();
        });
        final framesBeforeOpen = frames;

        // The glyphs of the first frame drawn after the press
        final draws0 = cx.window.drawCount;
        var firstFrameGlyphs = -1;
        var firstFrameRenders = -1;
        final drawDirtyWindows = app.onEffectsFlushed;
        app.onEffectsFlushed = app -> {
            drawDirtyWindows(app);
            if (firstFrameGlyphs == -1 && cx.window.drawCount > draws0) {
                firstFrameGlyphs = cx.window.renderedScene().monochromeSprites.length;
                firstFrameRenders = frames;
            }
        };
        cx.simulateMouseDown(new Point(10., 10.), Left);
        app.onEffectsFlushed = drawDirtyWindows;

        final framesAfterOpen = firstFrameRenders;
        final glyphs = firstFrameGlyphs;
        app.update(cx -> cx.clearKeyBindings());
        app.update(cx -> Component.init(cx));
        return {framesBeforeOpen: framesBeforeOpen, framesAfterOpen: framesAfterOpen, glyphs: glyphs};
    }

    /// dropdown_button.rs

    function testDropdownButtonBuilder() {
        final button = new Button('inner').label('Action');
        final dropdown = new DropdownButton('complex-dropdown')
            .button(button)
            .primary()
            .outline()
            .large()
            .disabled(false)
            .selected(false)
            .dropdownMenuWithAnchor(BottomLeft, (menu, _, _) -> menu);

        assertTrue(dropdown.buttonValue != null);
        assertTrue(dropdown.variant.equals(Primary));
        assertTrue(dropdown.outlineValue);
        assertTrue(dropdown.size.equals(Large));
        assertFalse(dropdown.disabledValue);
        assertFalse(dropdown.selectedValue);
        assertTrue(dropdown.menu != null);
        assertEquals(glaze.Anchor.BottomLeft, dropdown.anchor);
    }

    /**
     * An unset variant or size leaves the inner button's own to survive, so a
     * caller can style the halves from either level.
     */
    function testInnerButtonKeepsItsOwnVariantAndSize() {
        final dropdown = new DropdownButton('dropdown')
            .button(new Button('inner').label('Action').danger().small())
            .dropdownMenu((menu, _, _) -> menu);

        assertEquals(null, dropdown.variant);
        assertEquals(null, dropdown.size);
    }

    function testInnerGhostBecomesTheSplitVariant() {
        final dropdown = new DropdownButton('dropdown')
            .button(new Button('inner').label('Action').ghost())
            .dropdownMenu((menu, _, _) -> menu);

        assertTrue(dropdown.effectiveVariant().equals(Ghost));
    }

    function testInnerSizeBecomesTheSplitSize() {
        final dropdown = new DropdownButton('dropdown')
            .button(new Button('inner').label('Action').small())
            .dropdownMenu((menu, _, _) -> menu);

        assertTrue(dropdown.effectiveSize().equals(Small));
    }

    /**
     * `dropdown_button_names_its_menu_trigger` (crates/kit/tests/integration/components.rs).
     * The accessibility label of the caret button is only kept in its `A11y`
     * record while it renders (no accessibility tree), so the names it is
     * built with are checked.
     */
    function testDropdownButtonNamesItsMenuTrigger() {
        final save = new DropdownButton('save')
            .button(new Button('save-action').label('Save'))
            .menuAccessibilityLabel('More save options')
            .dropdownMenu((menu, _, _) -> menu);
        final plain = new DropdownButton('plain')
            .button(new Button('plain-action').label('Run'))
            .dropdownMenu((menu, _, _) -> menu);
        assertEquals('More save options', @:privateAccess save.menuAccessibilityLabelValue);
        assertEquals(null, @:privateAccess plain.menuAccessibilityLabelValue);
        assertEquals('More options', glaze.kit.I18n.t('DropdownButton.more_options'), 'the caret-only trigger needs a name without a caller-provided label');
        final opened = open((_, _) -> new ScriptView((_, _) -> div()
            .child(new DropdownButton('save')
                .button(new Button('save-action').label('Save'))
                .menuAccessibilityLabel('More save options')
                .dropdownMenu((menu, _, _) -> menu))
            .child(new DropdownButton('plain')
                .button(new Button('plain-action').label('Run'))
                .dropdownMenu((menu, _, _) -> menu))));
        draw(opened.cx);
    }

    /// kit/tests/integration/menu.rs

    /**
     * `common::open_window`: a `Root` around the content built by `build`.
     */
    function openRoot<V:Model & Render>(build:(Window, Context<V>) -> V, width:Float, height:Float):{content:Entity<V>, cx:VisualTestContext} {
        var content:Entity<V> = null;
        final opened = VisualTestContext.addWindowView(app, dispatcher, (window, rootCx:Context<glaze.kit.base.Root>) -> {
            content = rootCx.newEntity((cx:Context<V>) -> build(window, cx));
            return new glaze.kit.base.Root(content, window, rootCx);
        }, width, height);
        contexts.push(opened.cx);
        return {content: content, cx: opened.cx};
    }

    /** `window.render_frame(cx)`. */
    static function renderFrame(window:Window):Void {
        window.refresh();
        window.draw();
    }

    static function movePointer(window:Window, cx:App, position:Point):Void {
        window.dispatchEvent(new glaze.MouseMoveEvent(position, null, Modifiers.none()), cx);
        renderFrame(window);
    }

    /** `window.click(...)`: render, move, down, up (each followed by a frame). */
    static function clickAt(window:Window, cx:App, position:Point, button:MouseButton = Left):Void {
        renderFrame(window);
        movePointer(window, cx, position);
        window.dispatchEvent(new MouseDownEvent(button, position, Modifiers.none(), 1, false), cx);
        renderFrame(window);
        window.dispatchEvent(new MouseUpEvent(button, position, Modifiers.none(), 1), cx);
        renderFrame(window);
    }

    /** `window.hover(...)`. */
    static function hoverAt(window:Window, cx:App, position:Point):Void {
        renderFrame(window);
        movePointer(window, cx, position);
    }

    /** `window.press(key)`: key down (a binding only for enter) and key up. */
    static function press(window:Window, cx:App, key:String):Void {
        final keystroke = Keystroke.parse(key);
        renderFrame(window);
        if (key == 'enter' || key == 'tab') {
            window.dispatchEvent(new KeyDownEvent(keystroke, false, false), cx);
        }
        else {
            window.dispatchKeystroke(keystroke, cx);
        }
        window.dispatchEvent(new KeyUpEvent(keystroke), cx);
        renderFrame(window);
    }

    /**
     * The center of row `ix` of a menu whose rows are all 26px tall
     * (the items container has a 4px padding and a 2px gap). Rust finds the
     * row by its element id.
     */
    static function itemCenter(menu:Null<WeakEntity<PopupMenu>>, ix:Int):Point {
        final menu = menuOf(menu);
        if (menu.scrollableValue) {
            // A scrollable menu tracks its rows (which shrink to fit their
            // text in the limited height)
            final row = menu.scrollHandle.boundsForItem(ix);
            return row.center().add(menu.scrollHandle.offset());
        }
        // The bounds come from a child of the items container: in a scrolled
        // menu they move with the rows.
        final bounds = menu.bounds;
        return new Point(bounds.left() + 20., bounds.top() + 4. + ix * 28. + 13.);
    }

    static function isFocused(window:Window, menu:Null<WeakEntity<PopupMenu>>):Bool {
        return menuOf(menu).focusHandle.isFocused(window);
    }

    static function shownCount(cx:VisualTestContext, menus:Array<Null<WeakEntity<PopupMenu>>>):Int {
        var count = 0;
        for (menu in menus) {
            if (isShown(cx, menu)) count++;
        }
        return count;
    }

    /** `cx.wait_for(...)`: run until parked, render a frame, check. */
    static function waitFor(cx:VisualTestContext, predicate:() -> Bool):Void {
        for (_ in 0...10) {
            cx.runUntilParked();
            cx.update((window, _) -> renderFrame(window));
            if (predicate())
                return;
            cx.advanceClock(0.1);
        }
        throw 'timed out waiting';
    }

    function openCommands():{commands:Entity<Commands>, cx:VisualTestContext} {
        final opened = openRoot((window, cx:Context<Commands>) -> {
            final view = new Commands(cx.focusHandle());
            view.focus.focus(window, cx.app);
            return view;
        }, 640, 480);
        return {commands: opened.content, cx: opened.cx};
    }

    function testMenuSkipsDisabledCommandsConfirmsAndRestoresFocus() {
        final opened = openCommands();
        final commands:Commands = opened.commands;
        final cx = opened.cx;
        cx.update((window, app) -> {
            renderFrame(window);
            clickAt(window, app, Probe.bounds.get('commands').center());
            assertTrue(isFocused(window, commands.menu));
            clickAt(window, app, itemCenter(commands.menu, 0));
            assertFalse(commands.saved);
            press(window, app, 'down');
            assertEquals(1, menuOf(commands.menu).selectedIndex);
            press(window, app, 'enter');
        });
        waitFor(cx, () -> !isShown(cx, commands.menu) && commands.saved);
        cx.update((window, app) -> {
            assertTrue(commands.focus.isFocused(window));
            clickAt(window, app, Probe.bounds.get('commands').center());
            press(window, app, 'escape');
        });
        waitFor(cx, () -> !isShown(cx, commands.menu));
    }

    function testActivatingASubmenuEntersItWithoutDismissingItsParent() {
        for (keyboard in [false, true]) {
            final opened = openCommands();
            final commands:Commands = opened.commands;
            final cx = opened.cx;
            cx.update((window, app) -> {
                renderFrame(window);
                clickAt(window, app, Probe.bounds.get('commands').center());
                if (keyboard) {
                    press(window, app, 'down');
                    press(window, app, 'down');
                    assertEquals(2, menuOf(commands.menu).selectedIndex);
                    press(window, app, 'enter');
                }
                else {
                    clickAt(window, app, itemCenter(commands.menu, 2));
                }
                assertTrue(isFocused(window, commands.more));
                assertEquals(0, menuOf(commands.more).selectedIndex);
                assertEquals(2, shownCount(cx, commands.menus()));
                assertFalse(commands.saved);
            });
            pressContextMenuKey(cx, 'enter');
            cx.update((window, app) -> {
                renderFrame(window);
                assertTrue(commands.saved);
                assertEquals(0, shownCount(cx, commands.menus()));
                assertTrue(commands.focus.isFocused(window));

                clickAt(window, app, Probe.bounds.get('commands').center());
                hoverAt(window, app, itemCenter(commands.menu, 3));
                press(window, app, 'enter');
                assertEquals(2, shownCount(cx, commands.menus()));
                assertFalse(isFocused(window, commands.unavailable));
            });
            pressContextMenuKey(cx, 'escape');
            cx.update((window, app) -> {
                renderFrame(window);
                assertEquals(0, shownCount(cx, commands.menus()));
                assertTrue(commands.focus.isFocused(window));
            });
        }
    }

    function testSubmenuActivationSkipsDisabledItems() {
        final opened = openRoot((_, cx:Context<Commands>) -> new Commands(cx.focusHandle()), 640, 480);
        final commands:Commands = opened.content;
        final cx = opened.cx;
        cx.update((window, app) -> {
            renderFrame(window);
            clickAt(window, app, Probe.bounds.get('commands').center());
            // Hover can select a disabled row, but confirmation must not execute it.
            hoverAt(window, app, itemCenter(commands.menu, 0));
            press(window, app, 'enter');
            assertTrue(isShown(cx, commands.menu));
            assertFalse(commands.saved);
            clickAt(window, app, itemCenter(commands.menu, 4));
            assertEquals(1, menuOf(commands.moreCommands).selectedIndex);
            hoverAt(window, app, itemCenter(commands.moreCommands, 0));
            press(window, app, 'enter');
            assertEquals(2, shownCount(cx, commands.menus()));
            assertFalse(commands.saved);
        });
    }

    function testHoveringSubmenuOpensAndClickingItemDismissesTheChain() {
        final opened = openCommands();
        final commands:Commands = opened.commands;
        final cx = opened.cx;
        cx.update((window, app) -> {
            renderFrame(window);
            clickAt(window, app, Probe.bounds.get('commands').center());
            hoverAt(window, app, itemCenter(commands.menu, 2));
            assertEquals(2, menuOf(commands.menu).selectedIndex);
        });
        waitFor(cx, () -> isShown(cx, commands.more));
        cx.update((window, app) -> {
            assertEquals('Save copy', menuOf(commands.more).menuItems[0].labelValue);
            clickAt(window, app, itemCenter(commands.more, 0));
        });
        waitFor(cx, () -> commands.saved);
        cx.update((window, app) -> {
            assertFalse(isShown(cx, commands.more));
            assertFalse(isShown(cx, commands.menu));
        });
    }

    /**
     * The submenu is painted as a deferred draw outside the items container, so
     * the container's `overflowYScroll` clip must not hide it and its items
     * must still be hit-testable.
     */
    function testSubmenuOpensUnclippedFromAScrollableMenu() {
        final opened = openRoot((window, cx:Context<ScrollableCommands>) -> {
            final view = new ScrollableCommands(cx.focusHandle());
            view.focus.focus(window, cx.app);
            return view;
        }, 640, 480);
        final commands:ScrollableCommands = opened.content;
        final cx = opened.cx;
        cx.update((window, app) -> {
            renderFrame(window);
            clickAt(window, app, Probe.bounds.get('commands').center());
            // `up` wraps to the last item and scrolls it into view, where the
            // pointer can reach it.
            press(window, app, 'up');
            final item = itemCenter(commands.menu, 30);
            // Visible: inside the viewport of the scrolled items
            final viewport = menuOf(commands.menu).bounds.sub(menuOf(commands.menu).scrollHandle.offset());
            assertTrue(viewport.contains(item));
            hoverAt(window, app, item);
            assertEquals(30, menuOf(commands.menu).selectedIndex);
        });
        waitFor(cx, () -> isShown(cx, commands.more));
        cx.update((window, app) -> {
            final submenu = menuOf(commands.more).bounds;
            final viewport = new glaze.Bounds(new Point(0., 0.), window.viewportSize());
            assertTrue(viewport.contains(submenu.origin) && viewport.contains(submenu.bottomRight()), 'submenu is outside the window');
            assertEquals('Save copy', menuOf(commands.more).menuItems[0].labelValue);
            clickAt(window, app, itemCenter(commands.more, 0));
        });
        waitFor(cx, () -> !isShown(cx, commands.menu));
    }


    /** `long_press`: a recognized long press, started and ended, a frame after each. */
    static function longPress(window:Window, cx:App, position:Point):Void {
        for (phase in [glaze.TouchPhase.Started, glaze.TouchPhase.Ended]) {
            window.dispatchEvent(new glaze.LongPressEvent(phase, position, position), cx);
            renderFrame(window);
        }
    }

    /** `long_press_menus`: a row, an input and a selectable text, each a context menu trigger. */
    function longPressMenus():{cx:VisualTestContext, view:Entity<LongPressMenus>, rowMenu:Array<WeakEntity<PopupMenu>>} {
        final menus:Array<WeakEntity<PopupMenu>> = [];
        final opened = openRoot((window, cx) -> new LongPressMenus(window, cx, menus), 640, 480);
        return {cx: opened.cx, view: opened.content, rowMenu: menus};
    }

    /** `long_press_opens_the_context_menu`: a finger has no right button, so a long press opens the same menu. */
    function testLongPressOpensTheContextMenu() {
        final opened = longPressMenus();
        final cx = opened.cx;
        cx.update((window, app) -> {
            renderFrame(window);
            longPress(window, app, Probe.bounds.get('row').center());
        });
        cx.runUntilParked();
        draw(cx);
        assertTrue(opened.rowMenu.length > 0 && isShown(cx, opened.rowMenu[opened.rowMenu.length - 1]));
    }

    /** `long_press_on_an_input_in_a_context_menu_trigger_selects`: an input inside the trigger keeps its own long press. */
    function testLongPressOnAnInputInAContextMenuTriggerSelects() {
        final opened = longPressMenus();
        final cx = opened.cx;
        cx.update((window, app) -> {
            renderFrame(window);
            final bounds = Probe.bounds.get('row-input');
            longPress(window, app, new Point(bounds.left() + 24., bounds.center().y));
        });
        cx.runUntilParked();
        draw(cx);
        final input = opened.view.read(app).input;
        final range = input.read(app).selectedRange();
        assertEquals(0, range.start);
        assertEquals(5, range.end);
        assertEquals(0, opened.rowMenu.length);
    }

    /** `long_press_on_text_in_a_context_menu_trigger_selects`: window-level text selection takes priority over the trigger's menu. */
    function testLongPressOnTextInAContextMenuTriggerSelects() {
        final opened = longPressMenus();
        final cx = opened.cx;
        cx.update((window, app) -> {
            renderFrame(window);
            final bounds = Probe.bounds.get('text-row');
            longPress(window, app, new Point(bounds.left() + 24., bounds.top() + 10.));
        });
        cx.runUntilParked();
        draw(cx);
        cx.update((window, app) -> {
            assertEquals('quick', StringTools.trim(glaze.kit.base.TextSelection.selectedText(window, app)));
            assertNotNull(glaze.kit.base.TextSelection.touchSelection(window, app));
        });
        assertEquals(0, opened.rowMenu.length);
    }

    /** `long_press_on_blank_space_in_a_text_trigger_opens_the_menu`: blank space in a selectable text row still opens the object's menu. */
    function testLongPressOnBlankSpaceInATextTriggerOpensTheMenu() {
        final opened = longPressMenus();
        final cx = opened.cx;
        cx.update((window, app) -> {
            renderFrame(window);
            final bounds = Probe.bounds.get('text-row');
            longPress(window, app, new Point(bounds.right() - 12., bounds.bottom() - 12.));
        });
        cx.runUntilParked();
        draw(cx);
        cx.update((window, app) -> assertEquals('', glaze.kit.base.TextSelection.selectedText(window, app)));
        assertTrue(opened.rowMenu.length > 0 && isShown(cx, opened.rowMenu[opened.rowMenu.length - 1]));
    }

    /**
     * `nested_context_menu_uses_the_innermost_right_click_target`.
     */
    function testNestedContextMenuUsesTheInnermostRightClickTarget() {
        var innerChosen = 0;
        var outerChosen = 0;
        var innerMenu:Null<WeakEntity<PopupMenu>> = null;
        var outerMenu:Null<WeakEntity<PopupMenu>> = null;
        final opened = open((_, _) -> new ScriptView((_, _) -> div().sizeFull().p4().child(
            div()
                .id('card')
                .flex()
                .flexCol()
                .gap4()
                .w(px(320.))
                .child(new Probe('card-title', div()
                    .id('card-title')
                    .h(px(40.))
                    .child('Card')))
                .child(new Probe('share', new Button('share')
                    .label('Share')
                    .contextMenu((menu, _, cx) -> {
                        innerMenu = cx.weakEntity();
                        return menu.item(PopupMenuItem.create('Copy link').onClick((_, _, _) -> {
                            innerChosen++;
                        }));
                    })))
                .contextMenu((menu, _, cx) -> {
                    outerMenu = cx.weakEntity();
                    return menu.item(PopupMenuItem.create('Remove card').onClick((_, _, _) -> {
                        outerChosen++;
                    }));
                })
        )), 640, 480);
        final cx = opened.cx;

        draw(cx);
        rightClick(cx, Probe.bounds.get('share').center());
        cx.runUntilParked();
        draw(cx);
        assertTrue(isShown(cx, innerMenu));
        assertFalse(isShown(cx, outerMenu));
        assertEquals('Copy link', menuOf(innerMenu).menuItems[0].labelValue);
        cx.simulateKeystrokes('down');
        assertEquals(0, menuOf(innerMenu).selectedIndex);

        pressContextMenuKey(cx, 'enter');
        draw(cx);
        assertFalse(isShown(cx, innerMenu));
        assertEquals(1, innerChosen);
        assertEquals(0, outerChosen);
        rightClick(cx, Probe.bounds.get('card-title').center());
        cx.runUntilParked();
        draw(cx);
        assertTrue(isShown(cx, outerMenu));
        assertFalse(isShown(cx, innerMenu));
        assertEquals('Remove card', menuOf(outerMenu).menuItems[0].labelValue);

        pressContextMenuKey(cx, 'escape');
        draw(cx);
        assertFalse(isShown(cx, outerMenu));
        assertEquals(1, innerChosen);
        assertEquals(0, outerChosen);
        rightClick(cx, Probe.bounds.get('card-title').center());
        cx.runUntilParked();
        draw(cx);
        cx.simulateKeystrokes('down');
        assertEquals(0, menuOf(outerMenu).selectedIndex);

        pressContextMenuKey(cx, 'enter');
        draw(cx);
        assertFalse(isShown(cx, outerMenu));
        assertEquals(1, innerChosen);
        assertEquals(1, outerChosen);
    }

    static function rightClick(cx:VisualTestContext, position:Point):Void {
        cx.simulateMouseDown(position, Right);
        cx.simulateMouseUp(position, Right);
    }

    /// dropdown_menu.rs

    /**
     * Opening the menu and closing the window without dismissing it must
     * release the `PopupMenu`, and the popover's deferred registration with it.
     */
    function testOpenWithoutDismissReleasesTheMenu() {
        var menu:Null<WeakEntity<PopupMenu>> = null;
        final opened = VisualTestContext.addWindowView(app, dispatcher, (_, _) -> new ScriptView((_, _) -> div().sizeFull().child(
            new Button('trigger')
                .label('Edit')
                .w(px(100.))
                .h(px(30.))
                .dropdownMenu((m, _, cx) -> {
                    menu = cx.weakEntity();
                    return m.menu('Copy', new CopyText());
                })
        )), 1920, 1080);
        final cx = opened.cx;
        draw(cx);

        // Click the trigger; the menu opens and is left open.
        cx.simulateMouseDown(new Point(10., 10.), Left);
        cx.runUntilParked();
        assertTrue(menu != null && menu.upgrade() != null, 'the menu must be open before the window closes');

        // Close the window without dismissing the menu.
        cx.destroy();
        ceramic.App.app.flushImmediate();

        assertTrue(menu.upgrade() == null, 'the PopupMenu must be released with the window');
        assertFalse(glaze.kit.base.GlobalState.isInDeferredContext(app), 'the popover\'s deferred registration must be released with the window');
    }

    /**
     * Rust drops the menu when the dismiss handler clears `DropdownMenuState::menu`
     * (its only strong handle): the next open builds a new one.
     */
    function testDismissedDropdownMenuIsReleased() {
        var menu:Null<WeakEntity<PopupMenu>> = null;
        final opened = open((_, _) -> new ScriptView((_, _) -> div().sizeFull().child(
            new Button('trigger')
                .label('Edit')
                .w(px(100.))
                .h(px(30.))
                .dropdownMenu((m, _, cx) -> {
                    menu = cx.weakEntity();
                    return m.menu('Copy', new CopyText());
                })
        )));
        final cx = opened.cx;
        draw(cx);
        cx.simulateMouseDown(new Point(10., 10.), Left);
        cx.simulateMouseUp(new Point(10., 10.), Left);
        cx.runUntilParked();
        draw(cx);
        final first = menu;
        assertTrue(isShown(cx, first));

        pressContextMenuKey(cx, 'escape');
        draw(cx);
        assertFalse(isShown(cx, first));
        assertTrue(first.upgrade() == null, 'the dismissed menu must be released');
    }

    /**
     * Rust replaces `ContextMenuSharedState::menu_view` (the only strong
     * handle) when a right click opens a new menu: the previous one is dropped.
     */
    function testReplacedContextMenuIsReleased() {
        var menu:Null<WeakEntity<PopupMenu>> = null;
        final opened = open((_, _) -> new ScriptView((_, _) -> div().sizeFull().child(
            div()
                .id('area')
                .size(px(400.))
                .contextMenu((m, _, cx) -> {
                    menu = cx.weakEntity();
                    return m.menu('Copy', new CopyText());
                })
        )), 640, 480);
        final cx = opened.cx;
        draw(cx);
        rightClick(cx, new Point(20., 20.));
        cx.runUntilParked();
        draw(cx);
        final first = menu;
        assertTrue(isShown(cx, first));

        rightClick(cx, new Point(200., 200.));
        cx.runUntilParked();
        draw(cx);
        assertTrue(menu != first && isShown(cx, menu));
        assertTrue(first.upgrade() == null, 'the replaced menu must be released');
    }

}

@:action(namespace = context_menu_test) private class RemoveTab implements Action {}

@:action(namespace = context_menu_test) private class CopyText implements Action {}

@:action(namespace = menu_test) private class Save implements Action {}

@:action(namespace = menu_test) private class Unavailable implements Action {}

/**
 * The `Commands` view of the integration tests, whose menus are captured
 * from their builders.
 */
private class Commands extends Model implements Render {

    @observe public var saved:Bool = false;

    public final focus:FocusHandle;

    public var menu:Null<WeakEntity<PopupMenu>> = null;

    public var more:Null<WeakEntity<PopupMenu>> = null;

    public var unavailable:Null<WeakEntity<PopupMenu>> = null;

    public var moreCommands:Null<WeakEntity<PopupMenu>> = null;

    public function new(focus:FocusHandle) {
        super();
        this.focus = focus;
    }

    public function menus():Array<Null<WeakEntity<PopupMenu>>> {
        return [menu, more, unavailable, moreCommands];
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div()
            .id('workspace')
            .trackFocus(focus)
            .sizeFull()
            .p4()
            .onAction(Save, (_, _, _) -> saved = true)
            .onAction(Unavailable, (_, _, _) -> throw 'disabled command dispatched')
            .child(new Probe('commands', new Button('commands')
                .label('Commands')
                .dropdownMenu((menu, window, cx) -> {
                    this.menu = cx.weakEntity();
                    return menu.menuWithDisabled('Unavailable', new Unavailable(), true)
                        .menu('Save', new Save())
                        .submenu('More', window, cx, (menu, _, cx) -> {
                            more = cx.weakEntity();
                            return menu.menu('Save copy', new Save());
                        })
                        .item(
                            PopupMenuItem.submenu(
                                'Unavailable submenu',
                                PopupMenu.build(window, cx, (menu, _, cx) -> {
                                    unavailable = cx.weakEntity();
                                    return menu.menu('Unavailable', new Unavailable());
                                })
                            )
                                .disabled(true)
                        )
                        .submenu('More commands', window, cx, (menu, _, cx) -> {
                            moreCommands = cx.weakEntity();
                            return menu.menuWithDisabled('Unavailable', new Unavailable(), true)
                                .menu('Save copy', new Save());
                        });
                })))
            .child(div().id('result').child(saved
                ? div().id('saved').child('Saved')
                : div().id('unsaved').child('Unsaved')));
    }

}

/**
 * A scrollable menu whose only submenu item is the last of 31 rows, so it
 * starts scrolled out of the 160px viewport.
 */
private class ScrollableCommands extends Model implements Render {

    public final focus:FocusHandle;

    public var menu:Null<WeakEntity<PopupMenu>> = null;

    public var more:Null<WeakEntity<PopupMenu>> = null;

    public function new(focus:FocusHandle) {
        super();
        this.focus = focus;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div()
            .id('workspace')
            .trackFocus(focus)
            .sizeFull()
            .p4()
            .child(new Probe('commands', new Button('commands')
                .label('Commands')
                .dropdownMenu((menu, window, cx) -> {
                    this.menu = cx.weakEntity();
                    var result = menu.scrollable(true).maxH(px(160.));
                    for (ix in 0...30) {
                        result = result.menu('Item $ix', new Save());
                    }
                    return result.submenu('More', window, cx, (menu, _, cx) -> {
                        more = cx.weakEntity();
                        return menu.menu('Save copy', new Save());
                    });
                })));
    }

}

private class LongPressMenus extends Model implements Render {

    public final input:Entity<glaze.kit.base.input.InputState>;

    public final text:Entity<glaze.kit.base.text.TextViewState>;

    final menus:Array<WeakEntity<PopupMenu>>;

    public function new(window:Window, cx:Context<LongPressMenus>, menus:Array<WeakEntity<PopupMenu>>) {
        super();
        this.menus = menus;
        input = cx.newEntity((c:Context<glaze.kit.base.input.InputState>) -> {
            final state = new glaze.kit.base.input.InputState(window, c);
            state.defaultValue("quick select");
            return state;
        });
        text = cx.newEntity((c:Context<glaze.kit.base.text.TextViewState>) -> glaze.kit.base.text.TextViewState.markdown("quick select", c));
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final menus = this.menus;
        return div()
            .sizeFull()
            .p4()
            .flex()
            .flexCol()
            .gap4()
            .child(new Probe('row', div()
                .id('row')
                .w(px(320.))
                .h(px(40.))
                .child('Long press me')
                .contextMenu((menu, _, cx) -> {
                    menus.push(cx.weakEntity());
                    return menu.menu('Copy', new glaze.kit.base.input.InputActions.Copy());
                })))
            .child(div()
                .w(px(320.))
                .child(new Probe('row-input', new glaze.kit.input.Input(input).id('row-input')))
                .contextMenu((menu, _, cx) -> {
                    menus.push(cx.weakEntity());
                    return menu.menu('Copy', new glaze.kit.base.input.InputActions.Copy());
                }))
            .child(new Probe('text-row', div()
                .id('text-row')
                .w(px(320.))
                .h(px(80.))
                .child(glaze.kit.text.TextView.create(text).selectable(true))
                .contextMenu((menu, _, cx) -> {
                    menus.push(cx.weakEntity());
                    return menu.menu('Copy', new glaze.kit.base.input.InputActions.Copy());
                })));
    }

}
