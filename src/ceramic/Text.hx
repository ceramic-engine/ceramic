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

/// Display

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

        var char = 'A';
        var glyph = font.data.chars.get(char.uCharCodeAt(0));
        var pointSizeFactor = pointSize / font.data.pointSize;

        var letter = new Quad();
        letter.texture = font.pages.get(glyph.page);
        letter.color = color;
        letter.frame(
            glyph.x / letter.texture.density,
            glyph.y / letter.texture.density,
            glyph.width / letter.texture.density,
            glyph.height / letter.texture.density
        );
        letter.anchor(0, 0);
        letter.pos(0, 0);
        letter.size(glyph.width * pointSizeFactor, glyph.height * pointSizeFactor);
        add(letter);
        
        contentDirty = false;

    } //computeContent

} //Text
