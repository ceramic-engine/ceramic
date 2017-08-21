
declare module 'keypather' {

    export default function keypather():KeyPather;

    class KeyPather {

        get(obj:any, keyPath:string):any;

        set(obj:any, keyPath:string, value:any):void;

    }

}
