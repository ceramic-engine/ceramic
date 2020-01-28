package npm;

@:jsRequire('command-exists')
extern class CommandExists {

    inline static function existsSync(name:String):Bool {
        return js.Node.require('command-exists').sync(name);
    }

}
