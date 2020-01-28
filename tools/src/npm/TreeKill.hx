package npm;

extern class TreeKill {

    inline static function kill(pid:Int):Void {
        js.Node.require('tree-kill')(pid);
    }

}
