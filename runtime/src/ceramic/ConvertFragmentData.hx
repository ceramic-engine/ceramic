package ceramic;

class ConvertFragmentData implements ConvertField<Dynamic,FragmentData> {

    public function new() {}

    public function basicToField(assets:Assets, basic:Dynamic, done:FragmentData->Void):Void {

        done(basic);

    } //basicToField

    public function fieldToBasic(value:FragmentData):Dynamic {

        return value;

    } //fieldToBasic

} //ConvertFragmentData
