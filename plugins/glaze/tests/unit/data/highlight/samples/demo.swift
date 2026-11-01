import Foundation

/// A shape.
protocol Shape { var area: Double { get } }

struct Circle: Shape {
    let radius: Double
    var area: Double { .pi * radius * radius }
}

@MainActor
final class Store<T> {
    private(set) var items: [T] = []
    func add(_ item: T) -> Int { items.append(item); return items.count }
}

let c = Circle(radius: 2)
print("Area: \(c.area)", c.area > 10 ? "big" : "small", nil as Int?)
