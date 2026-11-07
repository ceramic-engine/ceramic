package main

import (
	"fmt"
	"strings"
)

// Shape is an interface.
type Shape interface {
	Area() float64
}

type Rect struct{ W, H float64 }

func (r Rect) Area() float64 { return r.W * r.H }

func main() {
	shapes := []Shape{Rect{W: 2, H: 3.5}}
	for i, s := range shapes {
		fmt.Println(i, s.Area(), strings.ToUpper("ok"), `raw`, 'x', nil, true)
	}
}
