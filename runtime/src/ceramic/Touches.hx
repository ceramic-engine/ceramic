package ceramic;

abstract Touches(IntMap<Touch>) {

    inline public function new() {

        this = new IntMap<Touch>(8, 0.5, false);

    }

    inline public function get(touchIndex:Int):Touch {

        return this.get(touchIndex);

    }

    inline public function set(touchIndex:Int, touch:Touch):Void {

        this.set(touchIndex, touch);

    }

	inline public function iterator():TouchesIterator {

        return new TouchesIterator(this);

    }

}

