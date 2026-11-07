object Demo extends App {
  case class Point(x: Int, y: Int)
  val points = List(Point(1, 2), Point(3, 4))
  def norm(p: Point): Double = math.sqrt(p.x * p.x + p.y * p.y)
  points.map(norm).foreach(n => println(s"norm = $n"))
}
