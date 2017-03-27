package ceramic;

class Quad extends Visual {

    public var background(default,set):Color = -1;
    function set_background(background:Color):Color {
        if (this.background == background) return background;
        this.background = background;
        return background;
    }

} //Quad
