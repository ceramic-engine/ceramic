package backend;

@:allow(Main)
class Screen implements spec.Screen implements ceramic.Events {

    public function new() {}

/// Events

    @event function resize();

/// Public API

    inline public function getPixelWidth():Int {

        return Std.int(Luxe.screen.width * Luxe.screen.device_pixel_ratio);

    } //getPixelWidth

    inline public function getPixelHeight():Int {

        return Std.int(Luxe.screen.height * Luxe.screen.device_pixel_ratio);

    } //getPixelHeight

    inline public function getPixelRatio():Float {

        return Luxe.screen.device_pixel_ratio;

    } //getPixelHeight

} //Screen
