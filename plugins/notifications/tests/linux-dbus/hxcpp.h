// A few hxcpp types, enough to compile linc_notifications_linux.cpp and
// linc_notifications_common.cpp outside of a Haxe build (see run.sh).
#pragma once
#define HXCPP_H

#include <memory>
#include <string>
#include <vector>

class null {
public:
    null() {}
};

class String {
public:
    const char *__s;
    String() : __s(NULL) {}
    String(const null &) : __s(NULL) {}
    String(const char *value) : __s(NULL) { set(value, -1); }
    String(const String &other) : __s(NULL) { if (other.__s != NULL) set(other.__s, -1); }
    String &operator=(const String &other) { if (other.__s != NULL) set(other.__s, -1); else { storage.reset(); __s = NULL; } return *this; }
    const char *utf8_str() const { return __s; }
    static String create(const char *value, int length = -1) { String result; result.set(value, length); return result; }
    bool isNull() const { return __s == NULL; }
    std::string str() const { return __s != NULL ? std::string(__s) : std::string("(null)"); }
private:
    std::shared_ptr<std::string> storage;
    void set(const char *value, int length) {
        storage = std::make_shared<std::string>(length < 0 ? std::string(value) : std::string(value, length));
        __s = storage->c_str();
    }
};

template <typename T>
class Array_obj {
public:
    std::vector<T> items;
    int length = 0;
    void push(const T &value) { items.push_back(value); length = (int)items.size(); }
};

template <typename T>
class Array {
public:
    std::shared_ptr< Array_obj<T> > ptr;
    Array() : ptr(std::make_shared< Array_obj<T> >()) {}
    Array(const null &) {}
    Array_obj<T> *operator->() const { return ptr.get(); }
    T &operator[](int index) const { return ptr->items[index]; }
    bool operator!=(const null &) const { return ptr != nullptr; }
    bool operator==(const null &) const { return ptr == nullptr; }
};
