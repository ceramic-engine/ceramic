#!/bin/bash
# Builds Md5Test with Ceramic's haxe and hxcpp, with the collector and safety
# defines of a Ceramic build, and runs it.
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
C="$(cd "${HERE}/../.." && pwd)"
cd "${HERE}"
"${C}/tools/haxe" -main Md5Test -cp . -cp "${C}/runtime/src" -cpp bin/cpp \
    -D HXCPP_GC_GENERATIONAL -D HXCPP_GC_CONCURRENT -D HXCPP_CHECK_POINTER -D HXCPP_STACK_LINE \
    -D HXCPP_STACK_TRACE -D HXCPP_IMMORTAL_STATICS -D HXCPP_CPP17 -D hxcpp_static_std -D safeMode
bin/cpp/Md5Test
