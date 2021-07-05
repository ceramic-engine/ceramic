package backend;

#if documentation

typedef AudioHandle = AudioHandleImpl;

#else

abstract AudioHandle(AudioHandleImpl) from AudioHandleImpl to AudioHandleImpl {}

#end
