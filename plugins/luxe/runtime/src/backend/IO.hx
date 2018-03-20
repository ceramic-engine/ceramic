package backend;

class IO implements spec.IO {

    public function new() {}

    public function stringSave(key:String, str:String):Bool {

        return Luxe.io.string_save(key, str, 0);

    } //stringSave

    public function stringRead(key:String):String {

        return Luxe.io.string_load(key, 0);

    } //stringRead

} //IO
