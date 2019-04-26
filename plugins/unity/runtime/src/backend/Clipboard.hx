package backend;

class Clipboard implements spec.Clipboard {

    var clipboardText:String = null;

    public function new() {}

    public function getText():String {
        
        return clipboardText;

    } //getText

    public function setText(text:String):Void {

        clipboardText = text;

    } //setText

} //Clipboard
