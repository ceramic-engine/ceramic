package backend;

class IO implements spec.IO {

    public function new() {}

    public function saveString(key:String, str:String):Bool {

        return Luxe.io.string_save(key, str, 0);

    } //saveString

    public function appendString(key:String, str:String):Bool {

        var str0 = Luxe.io.string_load(key, 0);
        if (str0 == null) {
            str0 = '';
        }
        
        return Luxe.io.string_save(key, str0 + str, 0);

    } //appendString

    public function readString(key:String):String {

        return Luxe.io.string_load(key, 0);

    } //readString

} //IO
