package rulescript.std.lua.iterators;

class LuaNumberIterator {
    var current:Int;
    var last:Int;
    var step:Int;

    public function new(from:Int, to:Int, step:Int = 1) {
        this.current = from - step; 
        this.last = to;
        this.step = step;
    }

    public function hasNext():Bool {
        return step > 0 ? current + step <= last : current + step >= last;
    }

    public function next():Int {
        current += step;
        return current;
    }

    public static function createInstance(from:Int, to:Int, step:Int = 1) {
        return new LuaNumberIterator(from, to, step);
    }
}
