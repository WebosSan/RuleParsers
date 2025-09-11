package rulescript.utils.lua;

import haxe.ds.IntMap;
import haxe.ds.StringMap;

class LuaUtils {
    public static function getLength(v:Dynamic) {
        try {
            return Lambda.count(v);
        } catch (e) {
            if (Reflect.isObject(v)) {
                if (Std.isOfType(v, Class)) return Type.getClassFields(v).length;
                return Reflect.fields(v).length;
            } else {
                return Std.string(v).length;
            }
        }
    }

    public static function getValue(v:Dynamic, key:Dynamic):Dynamic {
        if (v == null) return null;

        if (Std.isOfType(v, Array)) {
            var arr:Array<Dynamic> = cast v;
            var idx = Std.parseInt(Std.string(key));
            if (idx != null && idx >= 0 && idx < arr.length) {
                return arr[idx];
            }
            return null;
        }

        if (Std.isOfType(v, StringMap)) {
            var sm:StringMap<Dynamic> = cast v;
            return sm.get(key);
        }

        if (Std.isOfType(v, IntMap)) {
            var im:IntMap<Dynamic> = cast v;
            var idx = Std.parseInt(key);
            return idx != null ? im.get(idx) : null;
        }

        if (Reflect.isObject(v)) {
            if (Reflect.hasField(v, key)) {
                return Reflect.field(v, key);
            }
        }

        return null;
    }
}
