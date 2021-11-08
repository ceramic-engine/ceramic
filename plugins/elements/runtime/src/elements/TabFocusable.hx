package elements;

interface TabFocusable {

    public function allowsTabFocus():Bool;

    public function tabFocus():Void;

    public function escapeTabFocus():Void;

}
