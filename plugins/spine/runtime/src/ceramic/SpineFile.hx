package ceramic;

import spine.support.files.FileHandle;

class SpineFile implements FileHandle {

    public var path:String;

    public var content:String;

    public function getContent():String {
        return content;
    }

    public function new(path:String, content:String) {
        this.path = path;
        this.content = content;
    }

} //SpineFile
