package ceramic;

class Velocity {

    var positions:Array<Float> = [];

    var times:Array<Float> = [];

    public function new() {

    }
    
    public function reset():Void {

        // Remove all values
        var len = times.length;
        while (len > 0) {
            times.shift();
            positions.shift();
            len--;
        }

    }

    public function add(position:Float, minusDelta:Float = 0):Void {

        var now = Timer.now - minusDelta;

        positions.push(position);
        times.push(now);

        prune(now - 0.15);

    }

    public function get():Float {

        var now = Timer.now;

        prune(now - 0.15);

        var len = times.length;
        if (len < 2) return 0;

        var distance = positions[len - 1] - positions[0];
        var time = times[len - 1] - times[0];

        if (time <= 0) return 0;

        return distance / Math.max(0.15, time);

    }

/// Internal

    function prune(expireTime:Float):Void {

        // Remove expired values
        var len = times.length;
        while (len > 0 && times[0] <= expireTime) {
            times.shift();
            positions.shift();
            len--;
        }

    }

/// Print

    function toString():String {

        return '' + get();

    }

} // Velocity
