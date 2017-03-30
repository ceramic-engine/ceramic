package ceramic;

import backend.Fonts.Font;

enum TextAlign {
    LEFT;
    RIGHT;
    CENTER;
    JUSTIFY;
}

class Text extends Visual {

    public var color:Color = Color.WHITE;

    public var textSize(default,set):Int;
    function set_textSize(textSize:Int):Int {
        if (this.textSize == textSize) return textSize;
        contentDirty = true;
        this.textSize = textSize;
        return textSize;
    }

    public var font(default,set):Font;
    function set_font(font:Font):Font {
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



} //Text
