package backend;

#if documentation

typedef AudioHandle = clay.audio.AudioHandle;

#else

abstract AudioHandle(clay.audio.AudioHandle) from clay.audio.AudioHandle to clay.audio.AudioHandle {

    inline function toString() {

        return 'AudioHandle($this)';

    }

}

#end
