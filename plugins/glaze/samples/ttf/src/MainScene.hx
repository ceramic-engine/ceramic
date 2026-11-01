package;

import ceramic.Color;
import ceramic.DynamicBitmapFont;
import ceramic.Platform;
import ceramic.Quad;
import ceramic.Scene;
import ceramic.Text;
import ceramic.TtfFontAsset;
import ceramic.TtfGlyphAtlas;
import ceramic.TtfText;

/**
 * Runtime TrueType / OpenType fonts with the ttf plugin:
 *
 * - `ceramic.Text` with Inter at several sizes, through `DynamicBitmapFont`
 *   (glyphs rasterized on demand, kerning pairs from GPOS);
 * - shaped text with `TtfText` (kerning, ligatures and contextual alternates,
 *   font fallback);
 * - a debug view of the glyph atlas pages.
 *
 * Fonts come from a font collection (`assets/fonts/InterJetBrainsMono.ttc`:
 * face 0 is Inter, face 1 is JetBrains Mono).
 *
 * Run with `TTF_SAMPLE_CAPTURE=1` under the Electron runner with
 * `--screenshot-on-signal` to take a screenshot after a few frames.
 */
class MainScene extends Scene {

    static inline var FONTS = 'fonts/InterJetBrainsMono';

    static inline var SETTLE_FRAMES = 60;

    var frames:Int = 0;

    var captured:Bool = false;

    var capture:Bool = false;

    var font48:DynamicBitmapFont = null;

    override function preload() {

        assets.add('ttf:' + FONTS);

    }

    override function create() {

        capture = Platform.getEnv('TTF_SAMPLE_CAPTURE') == '1';

        var asset = assets.ttfAsset(FONTS);
        var inter = asset.face(0);
        var mono = asset.face(1);

        var light = Color.fromRGB(230, 232, 236);
        var muted = Color.fromRGB(150, 156, 168);
        var accent = Color.fromRGB(120, 180, 255);

        var x = 24.0;
        var y = 20.0;

        // ceramic.Text with Inter at several sizes (DynamicBitmapFont)
        for (size in [12, 16, 24, 36, 48]) {
            var text = new Text();
            text.font = asset.bitmapFont(size);
            text.pointSize = size;
            text.color = light;
            text.content = size >= 36 ? 'Inter ' + size + 'px: Sphinx of quartz' : 'Inter ' + size + 'px: Sphinx of black quartz, judge my vow';
            text.pos(x, y);
            add(text);
            y += text.height + 6;
        }

        // A paragraph with kerning (ceramic.Text wraps it with fitWidth)
        var paragraph = new Text();
        paragraph.font = asset.bitmapFont(16);
        paragraph.pointSize = 16;
        paragraph.color = muted;
        paragraph.fitWidth = 600;
        paragraph.content = 'Kerning pairs come from the GPOS table of the font: AVATAR, Tokyo, WAVE, '
            + 'Yo-yo, Ta Te To. The quick brown fox jumps over the lazy dog. '
            + 'Glyphs are rasterized on demand with plutovg, without any precomputed bitmap font.';
        paragraph.pos(x, y + 8);
        add(paragraph);
        y += paragraph.height + 24;

        // Shaped text (TtfText): ligatures, contextual alternates, kerning, fallback
        var code = new TtfText();
        code.font = mono;
        code.fontSize = 17;
        code.color = accent;
        code.content = 'JetBrains Mono ligatures: -> => != === <= >= |> <!-- -->';
        code.pos(x, y);
        add(code);
        y += code.height + 8;

        var noLigatures = new TtfText();
        noLigatures.font = mono;
        noLigatures.fontSize = 17;
        noLigatures.color = muted;
        noLigatures.features = ttf.shape.Features.DEFAULT.with('calt', false).with('liga', false);
        noLigatures.content = 'Without ligatures:        -> => != === <= >= |> <!-- -->';
        noLigatures.pos(x, y);
        add(noLigatures);
        y += noLigatures.height + 8;

        var shaped = new TtfText();
        shaped.font = inter;
        shaped.fallbacks = [mono];
        shaped.fontSize = 20;
        shaped.color = light;
        shaped.content = 'TtfText: AVATAR Tokyo, x ∈ ℝ (fallback), café Αβγ Жит';
        shaped.pos(x, y);
        add(shaped);
        y += shaped.height + 8;

        // Atlas pages debug view
        var label = new Text();
        label.font = asset.bitmapFont(12);
        label.pointSize = 12;
        label.color = muted;
        label.content = 'Atlas pages (48px font, TtfText)';
        label.pos(684, 20);
        add(label);

        font48 = asset.bitmapFont(48);
        addAtlasView(font48.glyphAtlas.textures[0], 684, 44, 256);
        addAtlasView(TtfGlyphAtlas.shared.textures[0], 684, 316, 256);

        log.success('ttf sample ready');

    }

    function addAtlasView(texture:ceramic.Texture, x:Float, y:Float, size:Float):Void {

        var bg = new Quad();
        bg.color = Color.fromRGB(48, 52, 60);
        bg.pos(x - 2, y - 2);
        bg.size(size + 4, size + 4);
        add(bg);

        var page = new Quad();
        page.texture = texture;
        page.pos(x, y);
        page.size(size, size);
        add(page);

    }

    /**
     * Reads the first atlas page back from the GPU and compares it with the
     * CPU copy, to check partial texture uploads.
     */
    function checkAtlasUpload():Void {

        var texture = font48.glyphAtlas.textures[0];
        if (!app.backend.textures.supportsFetchTexturePixels())
            return;
        var pixels = texture.fetchPixels();
        var page = font48.glyphAtlas.atlas.pages[0];
        var mismatches = 0;
        var covered = 0;
        for (i in 0...page.width * page.height) {
            var expected = page.data.get(i);
            if (expected > 0) covered++;
            if (pixels[i * 4 + 3] != expected) mismatches++;
        }
        if (mismatches == 0)
            log.success('Atlas upload check: GPU page matches the CPU page ($covered covered pixels)');
        else
            log.error('Atlas upload check: $mismatches pixels differ ($covered covered pixels)');

    }

    override function update(delta:Float) {

        if (!capture || captured)
            return;

        frames++;
        if (frames < SETTLE_FRAMES)
            return;

        captured = true;
        checkAtlasUpload();
        #if web
        final runner = backend.ElectronRunner.electronRunner;
        if (runner != null && runner.takeScreenshot != null) {
            log.info('Taking screenshot');
            runner.takeScreenshot();
        }
        else {
            log.warning('No electron runner takeScreenshot(): is the app running under the runner?');
        }
        #end

    }

}
