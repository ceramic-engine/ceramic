// Runs linc_notifications_linux.cpp against the fake libdbus (fake_dbus.cpp):
// the messages it sends, the ids it keeps per tag, the responses it queues.
// Usage: see run.sh. Exit status 0 when every check passes.

#include "linc_notifications.h"

#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <string>

using namespace linc::notifications;

static int checks = 0;
static int failures = 0;

static void check(bool condition, const std::string &what) {
    checks++;
    if (!condition) {
        failures++;
        printf("FAILED: %s\n", what.c_str());
    }
}

static void equals(const std::string &expected, const std::string &actual, const std::string &what) {
    checks++;
    if (expected != actual) {
        failures++;
        printf("FAILED: %s\n  expected: %s\n  actual:   %s\n", what.c_str(), expected.c_str(), actual.c_str());
    }
}

typedef const char *(*LogFunction)();
typedef void (*ClearFunction)();
typedef void (*ActionFunction)(uint32_t, const char *);
typedef void (*ClosedFunction)(uint32_t, uint32_t);

static LogFunction fakeLog;
static ClearFunction fakeClear;
static ActionFunction fakeAction;
static ClosedFunction fakeClosed;

static std::string takeLog() {
    std::string out = fakeLog();
    fakeClear();
    return out;
}

static std::string events() {
    std::string out;
    while (true) {
        int kind = nextEvent();
        if (kind == EVENT_NONE) break;
        if (!out.empty()) out += ",";
        if (kind == EVENT_RESPONSE) {
            ::String action = eventActionId();
            out += "response " + eventTag().str() + " " + (action.isNull() ? std::string("body") : action.str());
        }
        else {
            char value[64];
            snprintf(value, sizeof(value), "authorization %d %s", eventAuthorization(), kind == EVENT_AUTHORIZATION_REQUESTED ? "requested" : "read");
            out += value;
        }
    }
    return out;
}

static ::Array< ::String > strings(const char *a = NULL, const char *b = NULL) {
    ::Array< ::String > result;
    if (a != NULL) result->push(::String(a));
    if (b != NULL) result->push(::String(b));
    return result;
}

int main(int argc, char **argv) {
    const char *mode = argc > 1 ? argv[1] : "full";

    if (strcmp(mode, "nolib") == 0) {
        check(!available(), "unavailable without libdbus");
        check(!start(), "does not start without libdbus");
        readAuthorization();
        equals("authorization 0 read", events(), "unavailable read");
    }
    else if (strcmp(mode, "noservice") == 0) {
        check(available(), "libdbus loads");
        check(!start(), "does not start without a notification service");
        requestAuthorization();
        equals("authorization 0 requested", events(), "unavailable request");
        show(::String("t"), ::String("T"), ::String(""), strings(), strings());
        poll();
        equals("", events(), "nothing without the service");
    }
    else {
        void *fake = dlopen("libdbus-1.so.3", RTLD_NOW);
        check(fake != NULL, "fake libdbus found");
        fakeLog = (LogFunction)dlsym(fake, "fake_dbus_log");
        fakeClear = (ClearFunction)dlsym(fake, "fake_dbus_clear_log");
        fakeAction = (ActionFunction)dlsym(fake, "fake_dbus_emit_action");
        fakeClosed = (ClosedFunction)dlsym(fake, "fake_dbus_emit_closed");

        check(available(), "available with libdbus");
        equals("libdbus=1 started=0 connection=0 tags=0 ids=0", describe().str(), "nothing touched before start");

        setAppIdentity(::String("com.example.tasks"), ::String("Tasks"));
        check(start(), "starts");
        equals("start org.freedesktop.Notifications\n"
            "match type='signal',interface='org.freedesktop.Notifications',member='ActionInvoked'\n"
            "match type='signal',interface='org.freedesktop.Notifications',member='NotificationClosed'",
            takeLog(), "service started and signals matched");

        readAuthorization();
        requestAuthorization();
        equals("authorization 3 read,authorization 3 requested", events(), "never asks: authorized");

        // Notify with the body action, the buttons and the desktop entry
        show(::String("t1"), ::String("Title"), ::String("Body"), strings("open", "default"), strings("Open", "Default"));
        equals("call Notify s:Tasks u:0 s: s:Title s:Body a(s s:default s:default s:ceramic-action-0 s:Open s:ceramic-action-1 s:Default ) a({sv} e( s:desktop-entry v(s s:com.example.tasks ) ) ) i:-1",
            takeLog(), "Notify arguments");
        equals("app=Tasks replaces=0 summary=Title body=Body actions=default:default,ceramic-action-0:Open desktop-entry=com.example.tasks",
            describeRequest(::String("t1"), ::String("Title"), ::String("Body"), strings("open"), strings("Open")).str(), "request description before the reply");
        poll();
        equals("libdbus=1 started=1 connection=1 tags=1 ids=1", describe().str(), "id kept after the reply");

        // The same tag replaces the notification
        show(::String("t1"), ::String("Title 2"), ::String(""), strings("open", "default"), strings("Open", "Default"));
        check(takeLog().find("call Notify s:Tasks u:1 s: s:Title 2 s: ") == 0, "replaces_id of the tag");
        poll();

        // Responses: body, buttons (an action named "default" is a button), other ids and keys ignored
        fakeAction(1, "default");
        fakeAction(1, "ceramic-action-1");
        fakeAction(1, "ceramic-action-0");
        fakeAction(99, "default");
        fakeAction(1, "ceramic-action-7");
        fakeAction(1, "bogus");
        equals("", events(), "nothing before the poll");
        poll();
        equals("response t1 body,response t1 default,response t1 open", events(), "responses");

        // Dismiss closes the notification; the service's closed signal forgets it
        dismiss(::String("t1"));
        equals("send CloseNotification u:1", takeLog(), "CloseNotification");
        poll();
        equals("libdbus=1 started=1 connection=1 tags=0 ids=0", describe().str(), "forgotten after dismiss");
        dismiss(::String("t1"));
        equals("", takeLog(), "dismissing again sends nothing");

        // Dismissed before the reply: closed once the id is known
        show(::String("t2"), ::String("Two"), ::String(""), strings(), strings());
        dismiss(::String("t2"));
        check(takeLog().find("call Notify s:Tasks u:0 s: s:Two s: a(s s:default s:default ) a({sv} e(") == 0, "Notify without buttons");
        poll();
        equals("send CloseNotification u:2", takeLog(), "closed when the id came");
        poll();
        equals("libdbus=1 started=1 connection=1 tags=0 ids=0", describe().str(), "nothing kept");

        // Shown again before the first reply: the superseded one is closed
        show(::String("t3"), ::String("Three"), ::String(""), strings(), strings());
        show(::String("t3"), ::String("Three again"), ::String(""), strings(), strings());
        takeLog();
        poll();
        equals("send CloseNotification u:3", takeLog(), "superseded notification closed");
        poll();
        equals("libdbus=1 started=1 connection=1 tags=1 ids=1", describe().str(), "the latest one kept");
        fakeAction(4, "default");
        fakeAction(3, "default");
        poll();
        equals("response t3 body", events(), "only the latest one answers");

        // Closed by the user: forgotten, a new post does not replace it
        fakeClosed(4, 2);
        poll();
        equals("libdbus=1 started=1 connection=1 tags=0 ids=0", describe().str(), "forgotten after the user closed it");
        show(::String("t3"), ::String("Three"), ::String(""), strings(), strings());
        check(takeLog().find("call Notify s:Tasks u:0 ") == 0, "a new notification after close");
        poll();

        // Simulated responses (tests of the Haxe side) use the same queue
        simulateResponse(::String("x"), null());
        simulateResponse(::String("x"), ::String("go"));
        equals("response x body,response x go", events(), "simulated responses");
    }

    printf("linux dbus harness (%s): %d checks, %d failed\n", mode, checks, failures);
    return failures == 0 ? 0 : 1;
}
