package ceramic;

using unifill.Unifill;

enum TextAlign {
    LEFT;
    RIGHT;
    CENTER;
    JUSTIFY;
}

class Text extends Visual {

    public var color:Color = Color.WHITE;

    public var content(default,set):String = '';
    function set_content(content:String):String {
        if (this.content == content) return content;
        contentDirty = true;
        this.content = content;
        return content;
    }

    public var pointSize(default,set):Int = 20;
    function set_pointSize(pointSize:Int):Int {
        if (this.pointSize == pointSize) return pointSize;
        contentDirty = true;
        this.pointSize = pointSize;
        return pointSize;
    }

    public var lineHeight(default,set):Float = 1.0;
    function set_lineHeight(lineHeight:Float):Float {
        if (this.lineHeight == lineHeight) return lineHeight;
        contentDirty = true;
        this.lineHeight = lineHeight;
        return lineHeight;
    }

    public var letterSpacing(default,set):Float = 0.0;
    function set_letterSpacing(letterSpacing:Float):Float {
        if (this.letterSpacing == letterSpacing) return letterSpacing;
        contentDirty = true;
        this.letterSpacing = letterSpacing;
        return letterSpacing;
    }

    public var font(default,set):BitmapFont;
    function set_font(font:BitmapFont):BitmapFont {
        if (this.font == font) return font;
        contentDirty = true;
        this.font = font;
        return font;
    }

    public var align(default,set):TextAlign = LEFT;
    function set_align(align:TextAlign):TextAlign {
        if (this.align == align) return align;
        contentDirty = true;
        this.align = align;
        return align;
    }

/// Overrides

    override function set_depth(depth:Float):Float {
        if (this.depth == depth) return depth;

        // Ensure text glyphs have the requested depth
        for (quad in glyphQuads) {
            quad.depth = depth;
        }

        return super.set_depth(depth);
    }

/// Lifecycle

    override public function new() {

        super();

    } //new

/// Display

    var glyphQuads:Array<Quad> = [];

    override function computeContent() {

        if (font == null) {
            contentDirty = false;
            return;
        }

        var i = 0;

        if (children != null) {
            for (child in children) {
                child.destroy();
            }
        }

        var x = 0.0;
        var y = 0.0;
        var len = content.uLength();
        var sizeFactor = pointSize / font.data.pointSize;
        var char = null;
        var code = -1;
        var prevChar = null;
        var prevCode = -1;
        var i = 0;
        
        while (i < len) {

            prevChar = char;
            prevCode = code;
            char = content.uCharAt(i);
            code = char.uCharCodeAt(0);
            var glyph = font.data.chars.get(code);

            if (prevChar != null) {
                x += font.kerning(prevCode, code) * sizeFactor;
            }

            // Reuse or create quad
            var quad:Quad = i < glyphQuads.length ? glyphQuads[i] : null;
            if (quad == null) {
                quad = new Quad();
                glyphQuads.push(quad);
                add(quad);
            }
            quad.texture = font.pages.get(glyph.page);
            quad.color = color;
            quad.depth = depth;
            quad.frame(
                glyph.x / quad.texture.density,
                glyph.y / quad.texture.density,
                glyph.width / quad.texture.density,
                glyph.height / quad.texture.density
            );
            quad.anchor(0, 0);
            quad.pos(x + glyph.xOffset * sizeFactor, y + glyph.yOffset * sizeFactor);
            quad.size(glyph.width * sizeFactor, glyph.height * sizeFactor);

            x += glyph.xAdvance * sizeFactor + letterSpacing;

            i++;

        }

        // Remove unused quads
        while (i < glyphQuads.length) {
            var quad = glyphQuads.pop();
            quad.destroy();
        }
        
        contentDirty = false;

    } //computeContent

} //Text
