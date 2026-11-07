#!/usr/bin/env bash
#
# Checks linc_notifications_linux.cpp (freedesktop notifications over DBus)
# without Linux: the file is compiled for the host with a few hxcpp types
# (hxcpp.h here) and run against a fake libdbus with a fake notification
# service (fake_dbus.cpp), loaded with dlopen under the name libdbus-1.so.3
# like the real one. What it cannot check: the real libdbus ABI and a real
# notification service (see docs/CERAMIC_APIS.md in glaze-golden for the
# Linux check procedure).
#
set -eu
cd "$(dirname "$0")"
LINC=../../runtime/src/notifications/linc
OUT="$(mktemp -d -t ceramic-notifications-dbus)"
CXX="${CXX:-c++}"

mkdir "$OUT/lib"
"$CXX" -std=c++17 -Wall -Wextra -Wno-unused-parameter -Wno-unused-const-variable -shared -fPIC -o "$OUT/lib/libdbus-1.so.3" fake_dbus.cpp
"$CXX" -std=c++17 -Wall -Wextra -Wno-unused-parameter -Wno-unused-const-variable -I. -I"$LINC" -o "$OUT/harness" \
    harness.cpp "$LINC/linc_notifications_linux.cpp" "$LINC/linc_notifications_common.cpp" -ldl

# No libdbus at all (nothing on the search path)
(cd "$OUT" && ./harness nolib)
# libdbus, no notification service
(cd "$OUT" && DYLD_LIBRARY_PATH="$OUT/lib" LD_LIBRARY_PATH="$OUT/lib" FAKE_DBUS_NO_SERVICE=1 ./harness noservice)
# The fake service
(cd "$OUT" && DYLD_LIBRARY_PATH="$OUT/lib" LD_LIBRARY_PATH="$OUT/lib" ./harness full)
echo "linux dbus: OK"
