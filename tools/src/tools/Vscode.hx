package tools;

typedef VscodeChooserItem = {

    var displayName:String;

    var description:String;

    var tasks:Array<VscodeChooserItemTask>;

    @:optional var onSelect:VscodeChooserItemOnSelect;

}

typedef VscodeChooserItemTask = {

    var type:String;

    var label:String;

    var presentation:VscodeChooserItemTaskPresentation;

    var command:String;

    var args:Array<String>;

    var group:VscodeChooserItemTaskGroup;

    var problemMatcher:String;

    var runOptions:VscodeChooserItemTaskRunOptions;
    
}

typedef VscodeChooserItemTaskRunOptions = {

    var instanceLimit:Int;

}

typedef VscodeChooserItemOnSelect = {

    var command:String;

    var args:Array<String>;

}

typedef VscodeChooserItemTaskPresentation = {

    var echo:Bool;

    var reveal:String;

    var focus:Bool;

    var panel:String;

}

typedef VscodeChooserItemTaskGroup = {

    var kind:String;
    
    var isDefault:Bool;

}
