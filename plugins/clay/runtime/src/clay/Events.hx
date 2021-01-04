package clay;

class Events {

    public function tick():Void {}

    public function freeze():Void {}

    public function unfreeze():Void {}

    #if clay_sdl

    public function sdlEvent(event:sdl.Event):Void {}

    #end

}
