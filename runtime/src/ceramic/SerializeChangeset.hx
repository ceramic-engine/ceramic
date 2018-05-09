package ceramic;

@:structInit
class SerializeChangeset {

    public var data:String;

    public var append:Bool = false;

    public function new(data:String, append:Bool = false) {

        this.data = data;
        this.append = append;

    } //new

    function toString() {

#if debug_changesets
            var u = new haxe.Unserializer(data);
            var toAppend:Array<Dynamic> = u.unserialize();
            var toPrint = [];
            for (item in toAppend) {
                toPrint.push(item.type + '#' + item.id);
            }
            return '' + {
                append: append,
                data: toPrint
            };

#else
            return '' + {
                append: append,
                data: data
            };
#end

    } //toString

} //SerializeChangeset
