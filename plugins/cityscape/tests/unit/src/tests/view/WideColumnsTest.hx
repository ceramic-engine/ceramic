// New code for Cityscape (not a port): column positions of wide text
// compared with the real Monaco.
package tests.view;

import cityscape.CityscapeEditor;
import cityscape.Cityscape;
import cityscape.common.model.TextModel;
import cityscape.view.CityscapeView;
import glaze.App;
import glaze.Entity;
import glaze.TestDispatcher;
import glaze.Window;
import testing.MonacoTruth;
import testing.TestCase;

import glaze.Prelude.*;

/**
 * The x of every column of lines mixing ASCII, CJK, kana, Hangul, emoji
 * sequences and full width punctuation (JetBrains Mono 14, device pixel
 * ratio 2), compared with the real Monaco: `data/monaco/wide-columns.json`,
 * a copy of glaze-golden `test/cityscape/recorder/truths/d-wide-columns.json`
 * (see `WideColumns`, `tests/shared`). Each glyph keeps the advance of its
 * fallback font, off the character grid, like Monaco's DOM; columns inside a
 * grapheme are at its left edge.
 *
 * Tolerances: `WideColumns.TOLERANCE` (0.25 px) for the x, and
 * `WideColumns.ADVANCE_TOLERANCE` (0.05 px) for each advance.
 *
 * Targets:
 * - Native desktop: the fallback fonts of the system (SystemFontFallback),
 *   so every line is checked, except the known differences below.
 * - Node (headless JavaScript): no canvas, so no fallback font: only the
 *   advances of ASCII characters are checked. The web check, in a browser
 *   with Glaze's Canvas fallback, is the `columns` scene of tests/visual
 *   (`CITYSCAPE_VISUAL_SCENE=columns`, same truth and comparison).
 *
 * Known differences, open: `WideColumns.knownDifferences` (skipped, with
 * their reasons).
 */
class WideColumnsTest extends TestCase {

    var app:App;
    var window:Null<Window> = null;

    override public function setup():Void {
        app = new App(new TestDispatcher());
    }

    override public function teardown():Void {
        if (window != null) {
            window.destroy();
            window = null;
        }
        ceramic.App.app.flushImmediate();
    }

    function testColumnsMatchMonaco() {
        final truth = WideColumns.parse(MonacoTruth.load('wide-columns.json'));
        final context = new Cityscape();
        final model = new TextModel(truth.text, 'plaintext', TextModel.DEFAULT_CREATION_OPTIONS, null, context);
        var view:Null<Entity<CityscapeView>> = null;
        window = Window.open(app, {width: 1000, height: 700, scaleFactor: 2, autoDraw: false, bindInput: false}, OneEditor.component(model, truth, v -> view = v));
        app.update(_ -> window.draw());
        assertNotNull(view);
        if (view == null) {
            return;
        }
        final v:CityscapeView = view;
        // Only lines covered by fallback fonts are checked fully
        final hasFallbackFonts = #if (sys && !glaze_no_system_fonts) true #else false #end;
        final os = ceramic.App.app.backend.info.operatingSystem();
        final known = hasFallbackFonts ? WideColumns.knownDifferences(os, false) : [];
        final report = truth.compare((line, column) -> v.getOffsetForColumn(line, column), known, !hasFallbackFonts);
        for (f in report.failures) {
            final content = truth.lines[f.line - 1].content;
            assertTrue(false, 'line ${f.line} column ${f.column} (${content.substr(0, f.column - 1)}|): ${f.kind} ${f.actual} instead of ${f.expected}');
        }
        log.info('wide columns ($os${hasFallbackFonts ? '' : ', ASCII only'}): ' + report.summary());
        assertTrue(report.count > (hasFallbackFonts ? 150 : 50), report.summary());
        assertTrue(report.failures.length == 0, report.summary());
    }

}

class OneEditor extends glaze.Component {

    final model:TextModel;
    final truth:WideColumns;
    final onView:(view:Entity<CityscapeView>) -> Void;

    public function new(model:TextModel, truth:WideColumns, onView:(view:Entity<CityscapeView>) -> Void) {
        super();
        this.model = model;
        this.truth = truth;
        this.onView = onView;
    }

    public function render(window:Window, cx:App):glaze.IntoElement {
        return div().flex().sizeFull()
            .child(CityscapeEditor.component().model(model).options(truth.editorOptions()).onCreate(e -> onView(e.getView())).flex1());
    }

}
