package ceramic;

import ceramic.LdtkData;

/**
 * A default visual implementation to make LDtk entities visible
 */
class LdtkVisual extends Visual {

    public var ldtkEntity(default, null):LdtkEntityInstance;

    public var quad(default, null):Quad = null;

    public function new(ldtkEntity:LdtkEntityInstance) {

        super();

        this.ldtkEntity = ldtkEntity;

        setup();

    }

    function setup() {

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
            if (texture != null && ldtkEntity.def.tileset != null && w > 0 && h > 0 && def.tileRect.w > 0 && def.tileRect.h > 0) {

                switch def.tileRenderMode {
                    case Cover:
                        var rectScale:Float = Math.max(def.tileRect.w / w, def.tileRect.h / h);
                        var rectW:Float = def.tileRect.w * rectScale;
                        var rectH:Float = def.tileRect.h * rectScale;
                        var percentW:Float = def.tileRect.w / rectW;
                        var percentH:Float = def.tileRect.h / rectH;
                        var rectX:Float = def.tileRect.x + def.tileRect.w * (1.0 - percentW) * anchorX;
                        var rectY:Float = def.tileRect.y + def.tileRect.h * (1.0 - percentH) * anchorY;
                        quad = new Quad();
                        quad.texture = texture;
                        quad.frame(
                            rectX, rectY,
                            def.tileRect.w * percentW,
                            def.tileRect.h * percentH
                        );
                        quad.anchor(anchorX, anchorY);
                        quad.pos(w * anchorX, h * anchorY);
                        quad.size(w, h);
                        add(quad);

                    case FitInside:
                        var quadScale:Float = Math.min(w / def.tileRect.w, h / def.tileRect.h);
                        quad = new Quad();
                        quad.texture = texture;
                        quad.frame(
                            def.tileRect.x, def.tileRect.y,
                            def.tileRect.w, def.tileRect.h
                        );
                        quad.anchor(anchorX, anchorY);
                        quad.size(def.tileRect.w * quadScale, def.tileRect.h * quadScale);
                        quad.pos(
                            w * anchorX + (w - quad.width) * anchorX,
                            h * anchorY + (h - quad.height) * anchorY
                        );
                        add(quad);

                    case Repeat:

                    case Stretch:

                    case FullSizeCropped:

                    case FullSizeUncropped:

                    case NineSlice:
                }
            }
        }

    }

}
