package backend;

class Info implements spec.Info {

    public function new() {}

/// Assets

    inline public function imageExtensions():Array<String> {
        return ['png'];
    }

    inline public function textExtensions():Array<String> {
        return ['txt', 'json', 'fnt'];
    }

    inline public function soundExtensions():Array<String> {
        return ['ogg', 'wav'];
    }

} //Info
