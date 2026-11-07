package demo

import kotlin.math.max

/** KDoc. */
data class User(val name: String, var age: Int = 0)

fun main(args: Array<String>) {
    val users = listOf(User("Ann", 31), User("Bob"))
    val oldest = users.maxByOrNull { it.age } ?: return
    println("Oldest: ${oldest.name} ${max(1, 2)}")
    when (oldest.age) { in 0..17 -> println("minor"); else -> println(true) }
}
