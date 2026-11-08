package tests.kit;

import glaze.App;
import glaze.Context;
import glaze.IntoElement;
import glaze.Model;
import glaze.Render;
import glaze.TestDispatcher;
import glaze.Window;
import glaze.kit.I18n;
import glaze.kit.Kit;
import glaze.kit.WindowState;
import glaze.kit.base.Root;
import glaze.kit.base.Root.RootPluginRegistry;
import glaze.kit.button.Button;
import glaze.kit.theme.Theme;
import glaze.kit.theme.ThemeMode;
import testing.TestCase;
import testing.VisualTestContext;

import glaze.Prelude.*;

/**
 * The implicit initialization of the kit (`Kit.ensureInit`): a kit
 * component rendered without anything else gets the theme and the root
 * plugin, a setting made before any render initializes the kit then
 * applies, and the initialization runs once per app.
 */
class KitInitTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    final contexts:Array<VisualTestContext> = [];

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        for (cx in contexts) cx.destroy();
        contexts.resize(0);
        // The locale is a static of the kit, shared by every app and test
        I18n.setLocale('en');
        ceramic.App.app.flushImmediate();
    }

    static function registeredPlugins(app:App):Int {
        final registry = app.tryGlobal(RootPluginRegistry);
        return registry != null ? registry.entries.length : 0;
    }

    function testAComponentRenderedAloneInitializesTheKit() {
        assertFalse(app.hasGlobal(Theme));
        final opened = VisualTestContext.addWindowView(app, dispatcher, (window, cx:Context<ButtonView>) -> new ButtonView(), 400, 300);
        contexts.push(opened.cx);
        opened.cx.runUntilParked();
        assertTrue(app.hasGlobal(Theme));
        assertEquals(ThemeMode.Light, Theme.global(app).mode);
        assertEquals(1, registeredPlugins(app));
    }

    function testARootInitializesTheKitBeforeBuildingItsPlugins() {
        assertFalse(app.hasGlobal(Theme));
        final opened = VisualTestContext.addWindowView(app, dispatcher, (window, rootCx:Context<Root>) -> {
            final content = rootCx.newEntity((c:Context<ButtonView>) -> new ButtonView());
            return new Root(content, window, rootCx);
        }, 400, 300);
        contexts.push(opened.cx);
        opened.cx.runUntilParked();
        assertTrue(app.hasGlobal(Theme));
        // The kit's root plugin was registered before the root built its plugins
        assertTrue(WindowState.tryRead(opened.cx.window) != null);
    }

    function testASettingBeforeTheFirstRenderInitializesThenApplies() {
        app.update(cx -> Theme.change(Dark, null, cx));
        assertTrue(app.hasGlobal(Theme));
        assertEquals(ThemeMode.Dark, Theme.global(app).mode, 'the setting applies after the initialization');
        assertEquals(1, registeredPlugins(app));
    }

    function testALocaleSetBeforeTheFirstRenderTranslatesIt() {
        assertFalse(app.hasGlobal(Theme));
        final english = I18n.t('Dialog.ok');
        Kit.setLocale('zh-CN', app);
        assertTrue(app.hasGlobal(Theme), 'setLocale initializes the kit');
        assertEquals('zh-CN', Kit.locale());
        assertTrue(I18n.t('Dialog.ok') != english, 'the first lookup after the setting is translated');
    }

    function testInitializationRunsOncePerApp() {
        app.update(cx -> {
            Kit.init(cx);
            Kit.init(cx);
            Theme.global(cx);
            Kit.ensureInit(cx);
        });
        assertEquals(1, registeredPlugins(app));

        // Another app gets its own initialization
        final other = new App(new TestDispatcher());
        assertEquals(0, registeredPlugins(other));
        other.update(cx -> Theme.global(cx));
        assertEquals(1, registeredPlugins(other));
        // and the first app is still initialized once
        app.update(cx -> Theme.global(cx));
        assertEquals(1, registeredPlugins(app));
    }

}

private class ButtonView extends Model implements Render {

    public function new() {
        super();
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div().child(Button.component('save').label('Save'));
    }

}
