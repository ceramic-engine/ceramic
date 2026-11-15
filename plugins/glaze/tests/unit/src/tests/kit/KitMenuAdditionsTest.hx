// New tests for the Haxe port of gpui-kit (no gpui-kit origin): the kit additions without upstream
// equivalent (KIT-nnn in docs/DEVIATIONS.md). See NOTICE.md.
package tests.kit;

import glaze.Action;
import glaze.Entity;
import glaze.Menu;
import glaze.Menu.MenuItemTools;
import glaze.kit.button.Button;
import glaze.kit.menu.PopupMenu;
import glaze.platform.CeramicPlatformOperations;
import testing.VisualTestContext;

import glaze.Prelude.*;

using glaze.Menu.MenuItemTools;
using glaze.kit.menu.DropdownMenu;

/**
 * The menu additions without upstream equivalent (KIT-007): the menus of the
 * application (`cx.setMenus`) as the items of a popup menu, and as a
 * dropdown menu behind a button.
 */
class KitMenuAdditionsTest extends KitAdditionsTestCase {

    override function setup() {
        super.setup();
        app.update(cx -> glaze.kit.Kit.init(cx));
        app.setMenus([
            new Menu('File').withItems([
                MenuItemTools.action('New', new NewFile()),
                MenuItemTools.separator(),
                MenuItemTools.action('Export', new ExportStory()).disabled(true),
                MenuItemTools.submenu(new Menu('Recent').withItems([MenuItemTools.action('Clear', new ClearRecent())])),
            ]),
            new Menu('View').withItems([
                MenuItemTools.action('Sidebar', new ToggleSidebar()).checked(true),
            ]),
        ]);
    }

    override function teardown() {
        super.teardown();
        @:privateAccess CeramicPlatformOperations.menuBarOwner = null;
        ceramic.App.app.screen.setMenuBar([]);
        ceramic.App.app.flushImmediate();
    }

    static function describe(menu:Entity<PopupMenu>, app:glaze.App):String {
        return [for (item in @:privateAccess menu.read(app).menuItems) {
            final label = @:privateAccess item.labelValue;
            var text = switch @:privateAccess item.kind {
                case Separator: '-';
                case Submenu: '$label{' + describe(@:privateAccess item.menu, app) + '}';
                case _: label;
            }
            if (@:privateAccess item.disabledValue) text += '(disabled)';
            if (@:privateAccess item.checkedValue) text += '(checked)';
            text;
        }].join(',');
    }

    function testTheAppMenusBecomeSubmenus() {
        final cx = open((_, _) -> div().sizeFull(), 800, 600, true);
        final all = cx.update((window, app) -> PopupMenu.build(window, app, (menu, window, cx) -> menu.withAppMenus(window, cx)));
        assertEquals('File{New,-,Export(disabled),Recent{Clear}},View{Sidebar(checked)}', describe(all, app));
        final some = cx.update((window, app) -> PopupMenu.build(window, app, (menu, window, cx) -> menu.label('Menu').withAppMenus(window, cx, ['View'])));
        assertEquals('Menu,File{New,-,Export(disabled),Recent{Clear}}', describe(some, app));
    }

    function testWithMenuItemsTakesTheItemsOfOneMenu() {
        final cx = open((_, _) -> div().sizeFull(), 800, 600, true);
        final menu = cx.update((window, app) -> PopupMenu.build(window, app, (menu, window, cx) ->
            menu.withMenuItems([for (item in cx.app.getMenus()[0].items) item.clone()], window, cx)));
        assertEquals('New,-,Export(disabled),Recent{Clear}', describe(menu, app));
    }

    function testWithoutAppMenusNothingIsAdded() {
        app.setMenus([]);
        final cx = open((_, _) -> div().sizeFull(), 800, 600, true);
        final menu = cx.update((window, app) -> PopupMenu.build(window, app, (menu, window, cx) -> menu.withAppMenus(window, cx)));
        assertEquals('', describe(menu, app));
    }

    function testAButtonOpensTheAppMenuAndItsItemsDispatchTheirActions() {
        final received:Array<String> = [];
        final cx = open((_, _) -> div()
            .sizeFull()
            .onAction(NewFile, (_, _, _) -> received.push('new'))
            .onAction(ClearRecent, (_, _, _) -> received.push('clear'))
            .child(div().p4().child(probe('hamburger', Button.component('hamburger').label('Menu').appMenu()))), 800, 600, true);
        final button = boundsOf(cx, 'hamburger');
        assertNotNull(button);

        cx.simulateClick(button.center());
        draw(cx);
        draw(cx);
        // File, then into its submenu, whose first item is New.
        cx.simulateKeystrokes('down enter');
        draw(cx);
        cx.simulateKeystrokes('enter');
        cx.runUntilParked();
        draw(cx);
        assertEquals('new', received.join(','));

        // Again, down to Recent (the separator and the disabled Export are
        // skipped) and into it.
        cx.simulateClick(button.center());
        draw(cx);
        draw(cx);
        cx.simulateKeystrokes('down enter');
        draw(cx);
        cx.simulateKeystrokes('down enter');
        draw(cx);
        cx.simulateKeystrokes('enter');
        cx.runUntilParked();
        draw(cx);
        assertEquals('new,clear', received.join(','));
    }

}

@:action(namespace = kit_menu_additions_test) private class NewFile implements Action {}

@:action(namespace = kit_menu_additions_test) private class ExportStory implements Action {}

@:action(namespace = kit_menu_additions_test) private class ClearRecent implements Action {}

@:action(namespace = kit_menu_additions_test) private class ToggleSidebar implements Action {}
