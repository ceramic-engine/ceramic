package backend;

typedef LoadFontOptions = {
    
}

abstract Font(phoenix.BitmapFont) from phoenix.BitmapFont to phoenix.BitmapFont {}

class Fonts implements spec.Fonts {

    public function new() {}

    inline public function load(name:String, ?options:LoadFontOptions, done:Font->Void):Void {

        Luxe.resources.load_font(name, {
        })
        .then(function(font:Font) {
            done(font);
        },
        function(_) {
            done(null);
        });

    } //load

    inline public function destroy(font:Font):Void {
        
        (font:phoenix.BitmapFont).destroy(true);

    } //destroy

    inline public function measureWidth(font:Font, text:String, size:Float):Float {

        return (font:phoenix.BitmapFont).width_of(text, size);

    } //measureWidth

    inline public function measureHeight(font:Font, text:String, size:Float):Float {

        return (font:phoenix.BitmapFont).height_of(text, size);

    } //measureHeight

} //Textures