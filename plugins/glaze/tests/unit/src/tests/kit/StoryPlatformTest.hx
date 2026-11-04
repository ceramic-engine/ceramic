// New tests for the Haxe port of gpui-kit's story gallery: the parts that go
// through the platform (gpui-kit 0.8.1 crates/story/src/themes.rs `State` and
// `save_state`, crates/story/src/stories/data_table_story.rs `dump_csv` and
// `write_csv`, Longbridge, Apache-2.0). See NOTICE.md.
package tests.kit;

import gpui.App;
import gpui.Context;
import gpui.IntoElement;
import gpui.Model;
import gpui.Render;
import gpui.TestDispatcher;
import gpui.TestPlatformOperations;
import gpui.Window;
import gpui.base.theme.ScrollbarMode;
import gpui.component.Component;
import story.Themes;
import story.stories.DataTableStory;
import testing.TestCase;
import testing.VisualTestContext;

import gpui.Prelude.*;

/**
 * The gallery's settings (Rust `State` as `serde_json` reads and writes it)
 * and the CSV export of the data table story: the new path prompt in the
 * download folder, then the file written with Ceramic's `Files` the way the
 * `csv` crate writes it.
 */
@:access(story.stories.DataTableStory)
class StoryPlatformTest extends TestCase {

    function testThemeStateRoundTrip() {
        final state = new story.Themes.StoryThemeState();
        state.theme = 'Catppuccin Mocha';
        state.radius = 6;
        state.scrollbarMode = Hover;
        state.showFpsMonitor = true;
        final json = Themes.stateJson(state);
        assertEquals('{\n  "theme": "Catppuccin Mocha",\n  "radius": 6.0,\n  "scrollbar_mode": "Hover",\n  "show_fps_monitor": true\n}', json);

        final parsed = Themes.parseState(json);
        assertEquals('Catppuccin Mocha', parsed.theme);
        assertEquals(6., parsed.radius);
        assertEquals(Hover, parsed.scrollbarMode);
        assertEquals(true, parsed.showFpsMonitor);
    }

    function testThemeStateDefaultsLikeSerde() {
        // Missing optional fields stay unset; `scrollbar_show` is an alias
        final minimal = Themes.parseState('{"theme": "Default Dark", "scrollbar_show": "Always"}');
        assertEquals('Default Dark', minimal.theme);
        assertNull(minimal.radius);
        assertEquals(Always, minimal.scrollbarMode);
        assertNull(minimal.showFpsMonitor);

        // `unwrap_or_default()`: anything that does not parse gives the default state
        for (json in [null, '', 'not json', '{}', '{"theme": 3}', '{"theme": "X", "scrollbar_mode": "Never"}', '{"theme": "X", "radius": "big"}']) {
            final state = Themes.parseState(json);
            assertEquals('Default Light', state.theme);
            assertNull(state.radius);
            assertNull(state.scrollbarMode);
        }

        final unset = new story.Themes.StoryThemeState();
        assertEquals('{\n  "theme": "Default Light",\n  "radius": null,\n  "scrollbar_mode": null,\n  "show_fps_monitor": null\n}', Themes.stateJson(unset));
    }

    /**
     * Unity draws the app inside a Unity view, with no system title bar and
     * no system menu bar: the title bar renders like the web (no room for
     * the macOS traffic lights) and the gallery shows its in-window menu bar,
     * while the shortcuts stay the ones of the system.
     */
    function testWindowChromeOnUnity() {
        final app = new App(new TestDispatcher());
        story.AppState.init(app);
        #if unity
        assertTrue(gpui.component.TitleBar.isWeb);
        assertTrue(story.AppState.global(app).showAppMenuBar);
        assertEquals(gpui.OperatingSystem.current == Mac, story.Lib.isMacos());
        #else
        assertEquals(!story.Lib.isMacos(), story.AppState.global(app).showAppMenuBar);
        #end
    }

    function testCsvRecordsQuoteLikeTheCsvCrate() {
        final out = new StringBuf();
        DataTableStory.writeCsvRecord(out, ['plain', 'a,b', 'say "hi"', 'two\nlines', 'cr\r', '']);
        DataTableStory.writeCsvRecord(out, ['']);
        DataTableStory.writeCsvRecord(out, ['', '']);
        assertEquals('plain,"a,b","say ""hi""","two\nlines","cr\r",\n""\n,\n', out.toString());
    }

    #if (!web || ceramic_use_electron)
    function testCsvExportPromptsInTheDownloadFolderAndWritesTheTable() {
        final dispatcher = new TestDispatcher();
        final app = new App(dispatcher);
        final platform = new TestPlatformOperations();
        app.platformOperations = platform;
        app.update(cx -> Component.init(cx));
        final opened = VisualTestContext.addWindowView(app, dispatcher, (window, cx:Context<Blank>) -> new Blank(), 400, 300, 1);
        final window = opened.cx.window;
        try {
            final story = app.update(cx -> DataTableStory.view(window, cx));

            // Cancelled: nothing written
            story.update(app, (this_, cx) -> @:privateAccess this_.dumpCsv(null, window, cx));
            assertTrue(platform.didPromptForNewPath());
            var promptedDirectory:Null<String> = null;
            platform.simulateNewPathSelection((directory, name) -> {
                promptedDirectory = directory;
                assertEquals('export.csv', name);
                return null;
            });
            assertTrue(StringTools.endsWith(promptedDirectory, 'Downloads'));

            final dir = haxe.io.Path.join([testing.TestPaths.unitOutDir(), 'story-platform-test']);
            ceramic.Files.createDirectory(dir);
            final path = haxe.io.Path.join([dir, 'export.csv']);
            if (ceramic.Files.exists(path)) ceramic.Files.deleteFile(path);

            story.update(app, (this_, cx) -> @:privateAccess this_.dumpCsv(null, window, cx));
            platform.simulateNewPathSelection((_, _) -> path);
            final csv = ceramic.Files.getContent(path);
            assertNotNull(csv);
            final lines = csv.split('\n');
            final table = story.read(app).table.read(app);
            final rowsCount = table.delegate().rowsCount(app);
            // Header, the rows, then the empty piece after the last line end
            assertEquals(rowsCount + 2, lines.length);
            assertEquals('', lines[lines.length - 1]);
            final expectedHeader = new StringBuf();
            DataTableStory.writeCsvRecord(expectedHeader, table.headers(app));
            assertEquals(expectedHeader.toString(), lines[0] + '\n');
            final firstRow = new StringBuf();
            DataTableStory.writeCsvRecord(firstRow, table.dumpRange(new gpui.Range(0, 1), app).rows[0]);
            assertEquals(firstRow.toString(), lines[1] + '\n');
            ceramic.Files.deleteFile(path);
        } catch (e:haxe.Exception) {
            opened.cx.destroy();
            throw e;
        }
        opened.cx.destroy();
    }
    #end

}

private class Blank extends Model implements Render {

    public function new() {
        super();
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div();
    }

}
