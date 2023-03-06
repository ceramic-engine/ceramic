package ceramic;

import ceramic.LdtkData;

/**
 * A default visual implementation to make LDtk entities visible
 */
class LdtkVisual extends Quad {

    public var ldtkEntity(default, null):LdtkEntityInstance;

    public function new(ldtkEntity:LdtkEntityInstance) {

        super();

        this.ldtkEntity = ldtkEntity;

        setup();

    }

    function setup() {

        transparent = true;

        var w = ldtkEntity.width;
        var h = ldtkEntity.height;

        pos(
            ldtkEntity.pxX,
            ldtkEntity.pxY
        );

        size(w, h);

        var def = ldtkEntity.def;

        anchor(
            def.pivotX,
            def.pivotY
        );

        if (ldtkEntity.def != null && ldtkEntity.def.tileset != null && ldtkEntity.def.tileset.ceramicTileset != null) {
            var texture = ldtkEntity.def.tileset.ceramicTileset.texture;
            if (texture != null && w > 0 && h > 0 && def.tileRect.w > 0 && def.tileRect.h > 0) {

                switch def.tileRenderMode {
                    case Cover:
                        var rectScale:Float = Math.max(w / def.tileRect.w, h / def.tileRect.h);
                        var scaledRectW:Float = (def.tileRect.w * rectScale);
                        var scaledRectH:Float = (def.tileRect.h * rectScale);
                        var rectW:Float = def.tileRect.w * w / scaledRectW;
                        var rectH:Float = def.tileRect.h * h / scaledRectH;
                        var rectX:Float = def.tileRect.x + (def.tileRect.w - rectW) * anchorX;
                        var rectY:Float = def.tileRect.y + (def.tileRect.h - rectH) * anchorY;
                        var quad = new Quad();
                        quad.texture = texture;
                        quad.frame(
                            rectX, rectY,
                            rectW, rectH
                        );
                        quad.anchor(anchorX, anchorY);
                        quad.pos(w * anchorX, h * anchorY);
                        quad.size(w, h);
                        add(quad);

                    case FitInside:
                        var quadScale:Float = Math.min(w / def.tileRect.w, h / def.tileRect.h);
                        var quad = new Quad();
                        quad.texture = texture;
                        quad.frame(
                            def.tileRect.x, def.tileRect.y,
                            def.tileRect.w, def.tileRect.h
                        );
                        quad.anchor(anchorX, anchorY);
                        quad.size(def.tileRect.w * quadScale, def.tileRect.h * quadScale);
                        quad.pos(w * anchorX, h * anchorY);
                        add(quad);

                    case Repeat:
                        var repeat = new Repeat();
                        repeat.tile = def.tileRect.ceramicTile;
                        repeat.anchor(anchorX, anchorY);
                        repeat.size(w, h);
                        repeat.pos(w * anchorX, h * anchorY);
                        add(repeat);

                    case Stretch:
                        var quad = new Quad();
                        quad.texture = texture;
                        quad.frame(
                            def.tileRect.x, def.tileRect.y,
                            def.tileRect.w, def.tileRect.h
                        );
                        quad.anchor(anchorX, anchorY);
                        quad.size(w, h);
                        quad.pos(
                            w * anchorX + (w - quad.width) * anchorX,
                            h * anchorY + (h - quad.height) * anchorY
                        );
                        add(quad);

                    case FullSizeCropped:
                        var quad = new Quad();
                        var visibleW = Math.min(def.tileRect.w, w);
                        var visibleH = Math.min(def.tileRect.h, h);
                        quad.texture = texture;
                        quad.frame(
                            def.tileRect.x + (def.tileRect.w - visibleW) * anchorX,
                            def.tileRect.y + (def.tileRect.h - visibleH) * anchorY,
                            visibleW, visibleH
                        );
                        quad.anchor(anchorX, anchorY);
                        quad.size(
                            visibleW,
                            visibleH
                        );
                        quad.pos(
                            w * anchorX + (visibleW - quad.width) * anchorX,
                            h * anchorY + (visibleH - quad.height) * anchorY
                        );
                        add(quad);

                    case FullSizeUncropped:
                        var quad = new Quad();
                        quad.texture = texture;
                        quad.frame(
                            def.tileRect.x, def.tileRect.y,
                            def.tileRect.w, def.tileRect.h
                        );
                        quad.anchor(anchorX, anchorY);
                        quad.size(def.tileRect.w, def.tileRect.h);
                        quad.pos(w * anchorX, h * anchorY);
                        add(quad);

                    case NineSlice:
                        var nineSlice = new NineSlice();
                        nineSlice.rendering(REPEAT);
                        nineSlice.tile = def.tileRect.ceramicTile;
                        nineSlice.slice(
                            def.nineSliceBorders[0],
                            def.nineSliceBorders[1],
                            def.nineSliceBorders[2],
                            def.nineSliceBorders[3]
                        );
                        nineSlice.anchor(anchorX, anchorY);
                        nineSlice.size(w, h);
                        nineSlice.pos(
                            w * anchorX + (w - nineSlice.width) * anchorX,
                            h * anchorY + (h - nineSlice.height) * anchorY
                        );
                        add(nineSlice);
                }
            }
        }

    }

}
