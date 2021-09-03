package ceramic;

using ceramic.Extensions;

class TouchesIterator {

    var intMap:IntMap<Touch>;

    var i:Int;

    var len:Int;

    @:allow(ceramic.Touches)
    inline private function new(intMap:IntMap<Touch>) {

        this.intMap = intMap;
        i = 0;
        len = this.intMap.values.length;

    }

    inline public function hasNext():Bool {

        // Skip null items
        while (i < len && intMap.values.get(i) == null) {
            i++;
        }

        return i < len;
    }

    inline public function next():Touch {

        var n = i++;
        return intMap.values.get(n);

    }

}
