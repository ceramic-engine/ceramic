# Ruby sample
require 'json'

module Demo
  class Point < Struct.new(:x, :y)
    attr_reader :label

    def initialize(x, y, label = "p")
      super(x, y)
      @label = label
      @@count ||= 0
    end

    def to_s = "#{label}(#{x}, #{y})"
  end
end

points = [1, 2, 3].map { |n| Demo::Point.new(n, n * 2) }
puts points.select(&:x).inspect if points.any? && /p\d/ =~ "p1"
