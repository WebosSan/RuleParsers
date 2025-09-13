import { Aea } from "Aea"
import { Local } from "Local"

(function (name) {
    var instance = new Aea(name)
    trace(instance.getName())

    trace(Local.sum(10, 53))
})("Jonas :)")

let a = 0
while (a != 3) {
    a++
    trace(a)
}