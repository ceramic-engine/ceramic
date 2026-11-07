#include <vector>
#include <string>

namespace demo {
template <typename T>
class Stack {
public:
    void push(const T& value) { items_.push_back(value); }
    [[nodiscard]] bool empty() const noexcept { return items_.empty(); }
private:
    std::vector<T> items_;
};
}  // namespace demo

int main() {
    demo::Stack<std::string> s;
    s.push(R"(raw "string")");
    auto lambda = [&](int x) -> int { return x * 2; };
    return s.empty() ? 0 : lambda(21);
}
