// New code for the Haxe port of GPUI (no GPUI origin): JSON dump of a finished
// Scene, in the schema of the reference harness (reference/src/dump.rs), so the
// primitives of the port can be compared with those of the original GPUI.
package glaze.scene;

import haxe.Json;

/**
 * Dumps a finished `Scene` (after `finish()`) to JSON, with the same keys and
 * values as the reference harness dump of GPUI's scene: scaled pixels,
 * HSLA colors, primitives sorted by draw order like GPUI.
 *
 * Debugging and testing tool: not meant for hot paths.
 */
class SceneDump {

    static final KINDS = ['shadow', 'quad', 'path', 'underline', 'monochrome_sprite', 'subpixel_sprite', 'polychrome_sprite', 'surface'];

    static final TAG_NAMES = ['solid', 'linear_gradient', 'pattern_slash', 'checkerboard'];

    public static function dump(scene:Scene, deviceWidth:Float, deviceHeight:Float):Dynamic {

        inline function bounds(p:Primitive):Dynamic {
            return {x: p.boundsX, y: p.boundsY, w: p.boundsWidth, h: p.boundsHeight};
        }
        inline function mask(p:Primitive):Dynamic {
            return {x: p.contentMaskX, y: p.contentMaskY, w: p.contentMaskWidth, h: p.contentMaskHeight};
        }
        inline function hsla(h:Float, s:Float, l:Float, a:Float):Dynamic {
            return {h: h, s: s, l: l, a: a};
        }
        inline function corners(tl:Float, tr:Float, br:Float, bl:Float):Dynamic {
            return {top_left: tl, top_right: tr, bottom_right: br, bottom_left: bl};
        }

        final shadows:Array<Dynamic> = [for (s in scene.shadows) {
            order: s.order,
            bounds: bounds(s),
            content_mask: mask(s),
            corner_radii: corners(s.cornerRadiusTopLeft, s.cornerRadiusTopRight, s.cornerRadiusBottomRight, s.cornerRadiusBottomLeft),
            color: hsla(s.colorH, s.colorS, s.colorL, s.colorA),
            blur_radius: s.blurRadius,
            element_bounds: {x: s.elementBoundsX, y: s.elementBoundsY, w: s.elementBoundsWidth, h: s.elementBoundsHeight},
            element_corner_radii: corners(s.elementCornerRadiusTopLeft, s.elementCornerRadiusTopRight, s.elementCornerRadiusBottomRight, s.elementCornerRadiusBottomLeft),
            inset: s.inset
        }];

        final quads:Array<Dynamic> = [for (q in scene.quads) {
            order: q.order,
            bounds: bounds(q),
            content_mask: mask(q),
            background: {
                tag: q.backgroundTag,
                tag_name: TAG_NAMES[q.backgroundTag],
                color_space: q.backgroundColorSpace,
                solid: hsla(q.backgroundSolidH, q.backgroundSolidS, q.backgroundSolidL, q.backgroundSolidA),
                gradient_angle_or_pattern_height: q.backgroundGradientAngleOrPatternHeight,
                colors: [
                    {color: hsla(q.backgroundColor0H, q.backgroundColor0S, q.backgroundColor0L, q.backgroundColor0A), percentage: q.backgroundColor0Percentage},
                    {color: hsla(q.backgroundColor1H, q.backgroundColor1S, q.backgroundColor1L, q.backgroundColor1A), percentage: q.backgroundColor1Percentage}
                ]
            },
            border_color: hsla(q.borderColorH, q.borderColorS, q.borderColorL, q.borderColorA),
            corner_radii: corners(q.cornerRadiusTopLeft, q.cornerRadiusTopRight, q.cornerRadiusBottomRight, q.cornerRadiusBottomLeft),
            border_widths: {top: q.borderWidthTop, right: q.borderWidthRight, bottom: q.borderWidthBottom, left: q.borderWidthLeft},
            border_style: q.borderStyle == Dashed ? 'Dashed' : 'Solid'
        }];

        inline function background(b:Null<glaze.Background>, h:Float, s:Float, l:Float, a:Float):Dynamic {
            if (b == null) {
                return {
                    tag: 0, tag_name: 'solid', color_space: 0, solid: hsla(h, s, l, a), gradient_angle_or_pattern_height: 0,
                    colors: [{color: hsla(0, 0, 0, 0), percentage: 0}, {color: hsla(0, 0, 0, 0), percentage: 0}]
                };
            }
            return {
                tag: (b.tag:Int),
                tag_name: TAG_NAMES[(b.tag:Int)],
                color_space: (b.colorSpace:Int),
                solid: hsla(b.solid.h, b.solid.s, b.solid.l, b.solid.a),
                gradient_angle_or_pattern_height: b.gradientAngleOrPatternHeight,
                colors: [
                    {color: hsla(b.colors0.color.h, b.colors0.color.s, b.colors0.color.l, b.colors0.color.a), percentage: b.colors0.percentage},
                    {color: hsla(b.colors1.color.h, b.colors1.color.s, b.colors1.color.l, b.colors1.color.a), percentage: b.colors1.percentage}
                ]
            };
        }

        final paths:Array<Dynamic> = [for (p in scene.paths) {
            order: p.order,
            bounds: bounds(p),
            content_mask: mask(p),
            color: background(p.background, p.colorH, p.colorS, p.colorL, p.colorA),
            vertex_count: p.vertexCount,
            tile: {texture_index: p.textureIndex, bounds: {x: p.tileX, y: p.tileY, w: p.tileWidth, h: p.tileHeight}}
        }];

        final underlines:Array<Dynamic> = [for (u in scene.underlines) {
            order: u.order,
            bounds: bounds(u),
            content_mask: mask(u),
            color: hsla(u.colorH, u.colorS, u.colorL, u.colorA),
            thickness: u.thickness,
            wavy: u.wavy
        }];

        final monochromeSprites:Array<Dynamic> = [for (s in scene.monochromeSprites) {
            order: s.order,
            bounds: bounds(s),
            content_mask: mask(s),
            color: hsla(s.colorH, s.colorS, s.colorL, s.colorA),
            tile: {texture_index: s.textureIndex, bounds: {x: s.tileX, y: s.tileY, w: s.tileWidth, h: s.tileHeight}}
        }];

        final polychromeSprites:Array<Dynamic> = [for (s in scene.polychromeSprites) {
            order: s.order,
            bounds: bounds(s),
            content_mask: mask(s),
            corner_radii: corners(s.cornerRadiusTopLeft, s.cornerRadiusTopRight, s.cornerRadiusBottomRight, s.cornerRadiusBottomLeft),
            grayscale: s.grayscale,
            opacity: s.opacity,
            tile: {texture_index: s.textureIndex, bounds: {x: s.tileX, y: s.tileY, w: s.tileWidth, h: s.tileHeight}}
        }];

        // Draw sequence: (order, kind) ascending, then index within the kind
        final sequence:Array<Array<Int>> = [];
        inline function addOrders(kind:Int, list:Array<Dynamic>) {
            for (i in 0...list.length) sequence.push([list[i].order, kind, i]);
        }
        addOrders(0, shadows);
        addOrders(1, quads);
        addOrders(2, paths);
        addOrders(3, underlines);
        addOrders(4, monochromeSprites);
        addOrders(6, polychromeSprites);
        sequence.sort((a, b) -> a[0] != b[0] ? a[0] - b[0] : (a[1] != b[1] ? a[1] - b[1] : a[2] - b[2]));

        return {
            device_size: {width: deviceWidth, height: deviceHeight},
            units: 'scaled pixels (device pixels), colors in HSLA with hue in 0..1',
            draw_sequence: [for (entry in sequence) {order: entry[0], kind: KINDS[entry[1]], index: entry[2]}],
            shadows: shadows,
            quads: quads,
            paths: paths,
            underlines: underlines,
            monochrome_sprites: monochromeSprites,
            subpixel_sprites: [],
            polychrome_sprites: polychromeSprites,
            surfaces: []
        };

    }

    public static function toJson(scene:Scene, deviceWidth:Float, deviceHeight:Float):String {
        return Json.stringify(dump(scene, deviceWidth, deviceHeight), null, '  ');
    }

}
