// Original code (not a port): sample of the Ceramic vector plugin.
package;

import ceramic.Color;
import ceramic.Platform;
import ceramic.Quad;
import ceramic.Scene;
import ceramic.SvgQuad;
import ceramic.Text;
import ceramic.VectorCanvas;
import plutovg.Canvas;
import plutovg.Paint.GradientStop;

/**
 * SVG and vector graphics with the vector plugin:
 *
 * - Lucide icons (`SvgQuad`), tinted by changing the `color` attribute
 *   of each document at runtime, and the same icon at several sizes;
 * - files of the resvg test suite (radial gradient, nested clip paths, mask);
 * - a path drawn from code with plutovg (`VectorCanvas`).
 *
 * Capture mode (`VECTOR_SAMPLE_CAPTURE=1`, under the Electron runner with
 * `--screenshot-on-signal`): after a few frames, the exact pixels are written
 * to `VECTOR_SAMPLE_OUT` with `screen.toPng()`, then the runner window
 * screenshot is triggered, which makes the runner quit.
 */
class MainScene extends Scene {

    static final ICONS = ['heart', 'star', 'settings', 'sun', 'bell', 'rocket'];

    static final PALETTE = [
        Color.fromRGB(239, 68, 68),
        Color.fromRGB(250, 204, 21),
        Color.fromRGB(148, 163, 184),
        Color.fromRGB(251, 146, 60),
        Color.fromRGB(96, 165, 250),
        Color.fromRGB(167, 139, 250)
    ];

    /**
     * Color of the reference icon (on a black square, so that the captured
     * pixels are its premultiplied RGB values).
     */
    public static final REFERENCE_COLOR = Color.fromRGB(255, 136, 0);

    static inline var SETTLE_FRAMES = 60;

    var icons:Array<SvgQuad> = [];

    var colorShift:Int = 0;

    var capture:Bool = false;

    var frames:Int = 0;

    var captured:Bool = false;

    override function preload() {

        for (name in ICONS) {
            assets.add('svg:icons/' + name);
        }
        assets.add('svg:resvg/radial-gradient-reflect');
        assets.add('svg:resvg/nested-clip-path');
        assets.add('svg:resvg/mask-on-self');

    }

    override function create() {

        capture = Platform.getEnv('VECTOR_SAMPLE_CAPTURE') == '1';

        var light = Color.fromRGB(230, 232, 236);

        addLabel('Lucide icons (SvgQuad, 48px), tinted with the color attribute at runtime', 24, 16);

        // One SvgQuad per icon, each one with its own copy of the document
        for (i in 0...ICONS.length) {
            var icon = new SvgQuad();
            icon.asset = assets.svgAsset('icons/' + ICONS[i]);
            icon.size(48, 48);
            icon.pos(24 + i * 72, 40);
            add(icon);
            icons.push(icon);
        }
        applyColors();

        // Change the colors every second (once in capture mode)
        if (!capture) {
            ceramic.Timer.interval(this, 1.0, () -> {
                colorShift++;
                applyColors();
            });
        }

        // Same icon at several sizes: rasterized at each size, always sharp
        addLabel('Rasterized at the quad size (16, 24, 32, 64, 96)', 24, 112);
        var x = 24.0;
        for (s in [16, 24, 32, 64, 96]) {
            var icon = new SvgQuad();
            icon.asset = assets.svgAsset('icons/settings');
            icon.size(s, s);
            icon.pos(x, 136 + (96 - s) * 0.5);
            icon.setCurrentColor(light);
            add(icon);
            x += s + 24;
        }

        // Reference icon for the pixel comparison: heart, 24x24 at (480, 40),
        // on a black square, through the cached texture of the asset
        var black = new Quad();
        black.color = Color.BLACK;
        black.pos(472, 32);
        black.size(40, 40);
        add(black);

        var heartAsset = assets.svgAsset('icons/heart');
        var reference = new SvgQuad();
        reference.document = heartAsset.createDocument();
        reference.size(24, 24);
        reference.pos(480, 40);
        reference.setCurrentColor(REFERENCE_COLOR);
        add(reference);

        // Plain Quad with a cached texture from the asset. The asset document is
        // shared: changing it requires `updateTextures()` on the asset (SvgQuads
        // above are not affected, they have their own copy)
        var starAsset = assets.svgAsset('icons/star');
        starAsset.document.documentElement().setAttribute('color', light.toWebString());
        starAsset.updateTextures();
        var cached = new Quad();
        cached.texture = assets.svgTexture('icons/star', 32, 32);
        cached.pos(528, 36);
        add(cached);

        // resvg test suite files
        addLabel('resvg test files: radialGradient reflect, nested clipPath, mask', 24, 252);
        var names = ['radial-gradient-reflect', 'nested-clip-path', 'mask-on-self'];
        for (i in 0...names.length) {
            var card = new Quad();
            card.color = Color.WHITE;
            card.pos(24 + i * 184, 276);
            card.size(160, 160);
            add(card);

            var svg = new SvgQuad();
            svg.asset = assets.svgAsset('resvg/' + names[i]);
            svg.size(160, 160);
            svg.pos(24 + i * 184, 276);
            add(svg);
        }

        // Path drawn from code with plutovg
        addLabel('VectorCanvas (plutovg from code)', 600, 252);
        var vector = new VectorCanvas(300, 200, drawShape);
        vector.quad.pos(600, 276);
        add(vector.quad);

        log.success('vector sample ready (texturesDensity=${screen.texturesDensity})');

    }

    function drawShape(canvas:Canvas):Void {

        // Rounded background with a linear gradient
        canvas.roundRect(0, 0, 300, 200, 16, 16);
        canvas.setLinearGradient(0, 0, 300, 200, Pad, [
            GradientStop.rgba(0, 0.15, 0.18, 0.28, 1),
            GradientStop.rgba(1, 0.08, 0.09, 0.14, 1)
        ]);
        canvas.fill();

        // A five pointed star, filled with a radial gradient (even-odd rule)
        var cx = 90.0;
        var cy = 100.0;
        for (i in 0...5) {
            var a = -Math.PI / 2 + i * 4 * Math.PI / 5;
            var px = cx + Math.cos(a) * 70;
            var py = cy + Math.sin(a) * 70;
            if (i == 0) canvas.moveTo(px, py); else canvas.lineTo(px, py);
        }
        canvas.closePath();
        canvas.setRadialGradient(cx, cy, 70, cx, cy, 0, Pad, [
            GradientStop.rgba(0, 1, 0.85, 0.3, 1),
            GradientStop.rgba(1, 0.95, 0.3, 0.2, 1)
        ]);
        canvas.setFillRule(EvenOdd);
        canvas.fillPreserve();
        canvas.setRgba(1, 1, 1, 0.9);
        canvas.setLineWidth(2);
        canvas.setLineJoin(Round);
        canvas.stroke();

        // A dashed cubic curve
        canvas.moveTo(180, 170);
        canvas.cubicTo(200, 20, 260, 180, 285, 30);
        canvas.setRgb(0.38, 0.65, 0.98);
        canvas.setLineWidth(5);
        canvas.setLineCap(Round);
        canvas.setDash(0, [12, 10]);
        canvas.stroke();

    }

    function applyColors():Void {

        for (i in 0...icons.length) {
            icons[i].setCurrentColor(PALETTE[(i + colorShift) % PALETTE.length]);
        }

    }

    function addLabel(content:String, x:Float, y:Float):Void {

        var text = new Text();
        text.content = content;
        text.pointSize = 14;
        text.color = Color.fromRGB(150, 156, 168);
        text.pos(x, y);
        add(text);

    }

    override function update(delta:Float) {

        if (!capture || captured)
            return;

        frames++;

        // Change the icon colors at runtime once, before the capture
        if (frames == 10) {
            colorShift = 1;
            applyColors();
        }

        if (frames < SETTLE_FRAMES)
            return;

        captured = true;

        var out = Platform.getEnv('VECTOR_SAMPLE_OUT');
        if (out == null || out == '') {
            triggerWindowScreenshot();
            return;
        }

        screen.toPng(out, () -> {
            log.info('Captured $out');
            triggerWindowScreenshot();
        });

    }

    function triggerWindowScreenshot():Void {

        #if web
        final runner = backend.ElectronRunner.electronRunner;
        if (runner != null && runner.takeScreenshot != null) {
            runner.takeScreenshot();
        }
        else {
            log.warning('No electron runner takeScreenshot(): is the app running under the runner?');
        }
        #end

    }

}
