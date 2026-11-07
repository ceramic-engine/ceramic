// Ported from gpui-kit 0.8.1: crates/story/src/lib.rs (init, create_new_window, section, story_toolbar, with_command_entries)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package story;

import glaze.AnyView;
import glaze.App;
import glaze.Context;
import glaze.KeyBinding;
import glaze.OperatingSystem;
import glaze.Window;
import glaze.kit.base.Root;
import glaze.kit.Component;
import glaze.kit.I18n;
import glaze.kit.Size;
import glaze.kit.TitleBar;
import glaze.kit.button.Button;
import glaze.kit.command.Command;
import glaze.kit.command.CommandItem.CommandEntry;
import glaze.kit.dock.PanelInfo;
import glaze.kit.dock.PanelRegistry;
import glaze.kit.text.TextView;
import story.StoryActions;
import story.Themes.SelectTheme;

import glaze.kit.base.Prelude.*;

using glaze.kit.WindowExt;

/**
 * The free functions of the story crate's root (`lib.rs`). Stories use
 * `import story.Lib.*;` for `section`, `storyToolbar` and
 * `storyToolbarGroup`.
 */
class Lib {

    public static inline final PANEL_NAME:String = 'StoryContainer';

    /**
     * Rust `cfg!(target_os = "macos")`: true on macOS, but not on the web
     * (true on Unity in macOS).
     */
    public static function isMacos():Bool {
        #if unity
        // Unity renders its title bar like the web (`TitleBar.isWeb`), but
        // the keys are the ones of the system
        return OperatingSystem.current == Mac;
        #else
        return !TitleBar.isWeb && OperatingSystem.current == Mac;
        #end
    }

    /**
     * Opens a window showing `crateViewFn`'s view under a `StoryRoot` (with
     * the app title bar), inside the window `Root`. The caller adds
     * `window.renderable` to its scene.
     */
    public static function createNewWindow(title:String, crateViewFn:(Window, App) -> AnyView, cx:App, ?width:Float, ?height:Float):Window {
        return createNewWindowWithSize(title, width, height, crateViewFn, cx);
    }

    /**
     * Rust `create_new_window_with_size`. The window takes the given size
     * (the Ceramic screen size of the app); Rust centers a 1600 x 1200
     * window, at most 85% of the display.
     */
    public static function createNewWindowWithSize(title:String, width:Null<Float>, height:Null<Float>, crateViewFn:(Window, App) -> AnyView,
            cx:App):Window {
        final options:glaze.Window.WindowOptions = {};
        if (width != null) options.width = width;
        if (height != null) options.height = height;

        // Rust `gpui_kit::open_window`: the view under the window Root
        final window = Window.open(cx, options, (window, cx) -> {
            final view = crateViewFn(window, cx);
            final storyRoot = cx.newEntity((rootCx:Context<StoryRoot>) -> new StoryRoot(title, view, window, rootCx));

            // Set focus to the StoryRoot to enable it's actions.
            final focusHandle = storyRoot.read(cx).focusHandle;
            window.defer(cx, (window, cx) -> {
                if (window.focused(cx) == null) {
                    focusHandle.focus(window, cx);
                }
            });

            return cx.newEntity((rootCx:Context<Root>) -> new Root(storyRoot, window, rootCx));
        });
        window.activateWindow();
        // TODO: `window.set_window_title(title)`: the app sets Ceramic's
        // `settings.title` instead.
        return window;
    }

    /**
     * Layers the story locales over the component ones (Rust
     * `rust_i18n::extend!(gpui_component)` with the story's
     * `locales/ui.yml`).
     */
    public static function extendComponentTranslations():Void {
        final json:haxe.DynamicAccess<haxe.DynamicAccess<String>> = haxe.Json.parse(StoryLocales.json());
        for (locale => texts in json) {
            final backend = @:privateAccess I18n.backend();
            var table = backend.get(locale);
            if (table == null) {
                table = new Map();
                backend.set(locale, table);
            }
            for (key => value in texts) {
                table.set(key, value);
            }
        }
    }

    public static function init(cx:App):Void {
        // Rust initializes a tracing subscriber here (no equivalent).

        extendComponentTranslations();
        Component.init(cx);
        AppState.init(cx);
        Themes.init(cx);
        story.stories.Stories.init(cx);

        #if (plugin_http && !web)
        cx.setHttpClient(glaze.CeramicHttpClient.withUserAgent('gpui-component/story'));
        #end

        cx.bindKeys([
            new KeyBinding('/', new ToggleSearch(), null),
            new KeyBinding('ctrl-shift-p', new OpenCommandPalette(), null),
            isMacos() ? new KeyBinding('cmd-o', new Open(), null) : new KeyBinding('ctrl-o', new Open(), null),
            isMacos() ? new KeyBinding('cmd-q', new Quit(), null) : new KeyBinding('alt-f4', new Quit(), null),
            isMacos() ? new KeyBinding('cmd-k', new SelectTheme(), null) : new KeyBinding('ctrl-k', new SelectTheme(), null),
        ]);

        cx.onAction(Quit, (_, cx) -> {
            cx.quit();
        });

        cx.onAction(About, (_, cx) -> {
            // Rust `cx.active_window()`
            var window:Null<Window> = null;
            for (candidate in Window.windows) if (window == null && @:privateAccess candidate._active) window = candidate;
            if (window != null) {
                cx.defer(cx -> {
                    window.defer(cx, (window, cx) -> {
                        window.openAlertDialog(cx, (alert, _, _) -> alert
                            .title('About')
                            .description(TextView.markdownAt('GPUI Component Storybook\n\nVersion 0.1.0\n\nhttps://gpui-kit.com')));
                    });
                });
            }
        });

        PanelRegistry.registerPanel(cx, PANEL_NAME, (context, window, cx) -> {
            final storyState = switch context.info() {
                case Panel(value): StoryState.fromValue(value);
                case info: throw 'Invalid PanelInfo: $info';
            }

            final view = cx.newEntity((cx:Context<StoryContainer>) -> {
                final meta = storyState.toStory(window, cx);
                final container = new StoryContainer(window, cx).story(meta.newView(window, cx.app), storyState.storyKlass).onActive(meta.onActiveAny);

                cx.onFocusIn(container.focusHandle_, window, (this_:StoryContainer, _, _) -> {
                    trace('StoryContainer focus in: ${this_.name}');
                }).detach();

                container.name = meta.title;
                container.description = meta.description;
                container.closable_ = meta.closable;
                container.zoomable_ = meta.zoomable;
                return container;
            });
            return glaze.kit.dock.PanelHandle.panelHandle(view);
        });

        cx.activate(true);
    }

    /**
     * A titled section of a story (Rust `section`).
     */
    public static function section(title:String):StorySection {
        return new StorySection(title, hFlex()
            .wFull()
            .flexWrap()
            .justifyCenter()
            .itemsCenter()
            .gap4());
    }

    /**
     * Rust `story_toolbar_group`.
     */
    public static function storyToolbarGroup():StoryToolbar {
        return new StoryToolbar(hFlex().wFull().justifyEnd());
    }

    /**
     * Rust `story_toolbar`: a "Size" menu dispatching `ChangeStorySize`.
     */
    public static function storyToolbar(size:Size):StoryToolbar {
        final label = switch size {
            case XSmall: 'XSmall';
            case Small: 'Small';
            case Medium: 'Medium';
            case Large: 'Large';
            case Size(_): 'Custom';
        }

        return storyToolbarGroup().dropdownChild(new Button('story-size').label('Size: $label'), (menu, _, _) -> menu
            .menuWithCheck('XSmall', size.equals(XSmall), new ChangeStorySize(XSmall))
            .menuWithCheck('Small', size.equals(Small), new ChangeStorySize(Small))
            .menuWithCheck('Medium', size.equals(Medium), new ChangeStorySize(Medium))
            .menuWithCheck('Large', size.equals(Large), new ChangeStorySize(Large)));
    }

    /**
     * Rust `with_command_entries`.
     */
    public static function withCommandEntries(command:Command, entries:Iterable<CommandEntry>):Command {
        for (entry in entries) {
            switch entry {
                case Item(item): command.item(item);
                case Group(group): command.group(group);
                case Separator: command.separator();
            }
        }
        return command;
    }

}
