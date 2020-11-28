package unityengine;

import unityengine.GameObject;

@:native('UnityEngine.MonoBehaviour')
extern class MonoBehaviour extends Behaviour {

    var enabled:Bool;

    var isActiveAndEnabled:Bool;

    var gameObject:GameObject;

    var tag:String;

    var name:String;

}
