package tools;

import haxe.io.Path;

@:structInit
class Asset {

    /** Asset name/relative path */
    public var name:String;

    /** Asset root directory */
    public var rootDirectory:String;

    /** Asset full absolute path */
    public var absolutePath:String;

    public function new(name:String, rootDirectory:String) {

        this.name = name;
        this.rootDirectory = rootDirectory;
        this.absolutePath = Path.join([rootDirectory, name]);

    }

}
