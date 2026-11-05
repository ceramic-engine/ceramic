// A fake libdbus with a fake org.freedesktop.Notifications service in the
// same process, built as "libdbus-1.so.3" so that linc_notifications_linux.cpp
// loads it with dlopen like the real one (see run.sh). It implements the
// functions the plugin uses, records the calls it gets, and lets the harness
// emit the service's signals.

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <deque>
#include <string>
#include <vector>

typedef uint32_t dbus_bool_t;
typedef uint32_t dbus_uint32_t;
typedef int32_t dbus_int32_t;

struct DBusError {
    const char *name;
    const char *message;
    unsigned int dummy1 : 1;
    unsigned int dummy2 : 1;
    unsigned int dummy3 : 1;
    unsigned int dummy4 : 1;
    unsigned int dummy5 : 1;
    void *padding1;
};

struct Arg {
    int type;
    std::string text;
    uint32_t number;
};

struct DBusMessage {
    int type;
    std::string iface;
    std::string member;
    std::vector<Arg> args;   // flat: containers are 'a', 'e', 'v' markers then ')'
};

struct DBusPendingCall {
    DBusMessage *reply;
    void (*notify)(DBusPendingCall *, void *);
    void *data;
    void (*free)(void *);
};

struct DBusConnection {
    int dummy;
};

struct FakeIter {
    DBusMessage *message;
    size_t index;
};

typedef int (*DBusHandleMessageFunction)(DBusConnection *, DBusMessage *, void *);

static DBusConnection theConnection;
static DBusHandleMessageFunction filter = NULL;
static uint32_t nextId = 1;
static std::string logText;

struct Delivery {
    DBusPendingCall *pending;
    DBusMessage *signal;
};
static std::deque<Delivery> queue;

static void logLine(const std::string &line) {
    if (!logText.empty()) logText += "\n";
    logText += line;
}

static FakeIter *fake(void *iter) {
    return (FakeIter *)iter;
}

static void queueSignal(const char *member, uint32_t id, const Arg *second) {
    DBusMessage *signal = new DBusMessage();
    signal->type = 4;
    signal->iface = "org.freedesktop.Notifications";
    signal->member = member;
    Arg first = { 'u', "", id };
    signal->args.push_back(first);
    signal->args.push_back(*second);
    Delivery delivery = { NULL, signal };
    queue.push_back(delivery);
}

extern "C" {

void dbus_error_init(DBusError *error) { memset(error, 0, sizeof(DBusError)); }
dbus_bool_t dbus_error_is_set(const DBusError *error) { return error->name != NULL; }
void dbus_error_free(DBusError *error) { memset(error, 0, sizeof(DBusError)); }

DBusConnection *dbus_bus_get(int type, DBusError *error) {
    if (getenv("FAKE_DBUS_NO_BUS") != NULL) {
        error->name = "org.freedesktop.DBus.Error.NoServer";
        error->message = "no bus";
        return NULL;
    }
    return &theConnection;
}

void dbus_connection_set_exit_on_disconnect(DBusConnection *, dbus_bool_t) {}

dbus_bool_t dbus_bus_start_service_by_name(DBusConnection *, const char *name, dbus_uint32_t, dbus_uint32_t *result, DBusError *error) {
    if (getenv("FAKE_DBUS_NO_SERVICE") != NULL) {
        error->name = "org.freedesktop.DBus.Error.ServiceUnknown";
        error->message = "no service";
        return 0;
    }
    if (result != NULL) *result = 2;
    logLine(std::string("start ") + name);
    return 1;
}

void dbus_bus_add_match(DBusConnection *, const char *rule, DBusError *) {
    logLine(std::string("match ") + rule);
}

dbus_bool_t dbus_connection_add_filter(DBusConnection *, DBusHandleMessageFunction function, void *, void (*)(void *)) {
    filter = function;
    return 1;
}

DBusMessage *dbus_message_new_method_call(const char *destination, const char *path, const char *iface, const char *method) {
    DBusMessage *message = new DBusMessage();
    message->type = 1;
    message->iface = iface;
    message->member = method;
    return message;
}

void dbus_message_iter_init_append(DBusMessage *message, void *iter) {
    fake(iter)->message = message;
    fake(iter)->index = 0;
}

dbus_bool_t dbus_message_iter_append_basic(void *iter, int type, const void *value) {
    Arg arg = { type, "", 0 };
    if (type == 's') arg.text = *(const char *const *)value;
    else if (type == 'u') arg.number = *(const uint32_t *)value;
    else if (type == 'i') arg.number = (uint32_t)*(const int32_t *)value;
    fake(iter)->message->args.push_back(arg);
    return 1;
}

dbus_bool_t dbus_message_iter_open_container(void *iter, int type, const char *signature, void *sub) {
    Arg arg = { type, signature != NULL ? signature : "", 0 };
    fake(iter)->message->args.push_back(arg);
    fake(sub)->message = fake(iter)->message;
    return 1;
}

dbus_bool_t dbus_message_iter_close_container(void *iter, void *) {
    Arg arg = { ')', "", 0 };
    fake(iter)->message->args.push_back(arg);
    return 1;
}

static std::string describeArgs(const DBusMessage *message) {
    std::string out;
    for (size_t i = 0; i < message->args.size(); i++) {
        const Arg &arg = message->args[i];
        if (!out.empty() && arg.type != ')') out += " ";
        char number[32];
        switch (arg.type) {
            case 's': out += "s:" + arg.text; break;
            case 'u': snprintf(number, sizeof(number), "u:%u", arg.number); out += number; break;
            case 'i': snprintf(number, sizeof(number), "i:%d", (int32_t)arg.number); out += number; break;
            case ')': out += " )"; break;
            default: out += std::string(1, (char)arg.type) + "(" + arg.text; break;
        }
    }
    return out;
}

dbus_bool_t dbus_connection_send(DBusConnection *, DBusMessage *message, dbus_uint32_t *) {
    logLine("send " + message->member + " " + describeArgs(message));
    if (message->member == "CloseNotification" && !message->args.empty()) {
        // The service answers with NotificationClosed, reason 3 (closed by a call)
        Arg reason = { 'u', "", 3 };
        queueSignal("NotificationClosed", message->args[0].number, &reason);
    }
    return 1;
}

dbus_bool_t dbus_connection_send_with_reply(DBusConnection *, DBusMessage *message, DBusPendingCall **pending, int) {
    logLine("call " + message->member + " " + describeArgs(message));
    DBusMessage *reply = new DBusMessage();
    if (message->member == "Notify" && message->args.size() > 1 && getenv("FAKE_DBUS_NOTIFY_ERROR") == NULL) {
        reply->type = 2;
        uint32_t replaces = message->args[1].number;
        Arg id = { 'u', "", replaces != 0 ? replaces : nextId++ };
        reply->args.push_back(id);
    }
    else {
        reply->type = 3;
    }
    DBusPendingCall *call = new DBusPendingCall();
    call->reply = reply;
    call->notify = NULL;
    call->data = NULL;
    call->free = NULL;
    *pending = call;
    Delivery delivery = { call, NULL };
    queue.push_back(delivery);
    return 1;
}

dbus_bool_t dbus_pending_call_set_notify(DBusPendingCall *pending, void (*notify)(DBusPendingCall *, void *), void *data, void (*free)(void *)) {
    pending->notify = notify;
    pending->data = data;
    pending->free = free;
    return 1;
}

DBusMessage *dbus_pending_call_steal_reply(DBusPendingCall *pending) {
    DBusMessage *reply = pending->reply;
    pending->reply = NULL;
    return reply;
}

void dbus_pending_call_unref(DBusPendingCall *pending) {
    // Freed after the notify returns (see dbus_connection_dispatch)
}

void dbus_message_unref(DBusMessage *message) { delete message; }
int dbus_message_get_type(DBusMessage *message) { return message->type; }

dbus_bool_t dbus_message_is_signal(DBusMessage *message, const char *iface, const char *name) {
    return message->type == 4 && message->iface == iface && message->member == name;
}

dbus_bool_t dbus_message_iter_init(DBusMessage *message, void *iter) {
    fake(iter)->message = message;
    fake(iter)->index = 0;
    return !message->args.empty();
}

int dbus_message_iter_get_arg_type(void *iter) {
    FakeIter *it = fake(iter);
    return it->index < it->message->args.size() ? it->message->args[it->index].type : 0;
}

void dbus_message_iter_get_basic(void *iter, void *value) {
    const Arg &arg = fake(iter)->message->args[fake(iter)->index];
    if (arg.type == 's') *(const char **)value = arg.text.c_str();
    else *(uint32_t *)value = arg.number;
}

dbus_bool_t dbus_message_iter_next(void *iter) {
    fake(iter)->index++;
    return fake(iter)->index < fake(iter)->message->args.size();
}

dbus_bool_t dbus_connection_read_write(DBusConnection *, int) { return 1; }

int dbus_connection_dispatch(DBusConnection *connection) {
    if (queue.empty()) return 1;
    Delivery delivery = queue.front();
    queue.pop_front();
    if (delivery.pending != NULL) {
        DBusPendingCall *pending = delivery.pending;
        if (pending->notify != NULL) pending->notify(pending, pending->data);
        if (pending->free != NULL) pending->free(pending->data);
        if (pending->reply != NULL) delete pending->reply;
        delete pending;
    }
    else if (delivery.signal != NULL) {
        if (filter != NULL) filter(connection, delivery.signal, NULL);
        delete delivery.signal;
    }
    return queue.empty() ? 1 : 0;
}

void dbus_connection_flush(DBusConnection *) {}

// Harness hooks

void fake_dbus_emit_action(uint32_t id, const char *key) {
    Arg action = { 's', key, 0 };
    queueSignal("ActionInvoked", id, &action);
}

void fake_dbus_emit_closed(uint32_t id, uint32_t reason) {
    Arg value = { 'u', "", reason };
    queueSignal("NotificationClosed", id, &value);
}

const char *fake_dbus_log() {
    return logText.c_str();
}

void fake_dbus_clear_log() {
    logText.clear();
}

}
