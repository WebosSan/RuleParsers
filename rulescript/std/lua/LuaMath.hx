package rulescript.std.lua;

class LuaMath {
	public static var huge:Float = 1.0 / 0.0; 

	private static var _lcgSeed:Float = Math.random() * 4294967296.0;
	private static inline function _lcgNext():Float {
		_lcgSeed = (1664525.0 * _lcgSeed + 1013904223.0) % 4294967296.0;
		return _lcgSeed / 4294967296.0;
	}

	public static function abs(x:Float):Float return Math.abs(x);
	public static function acos(x:Float):Float return Math.acos(x);
	public static function asin(x:Float):Float return Math.asin(x);
	public static function atan(x:Float):Float return Math.atan(x);
	public static function atan2(y:Float, x:Float):Float return Math.atan2(y, x);

	public static function ceil(x:Float):Float return Math.ceil(x);

	public static function cos(x:Float):Float return Math.cos(x);

	public static function cosh(x:Float):Float {
		return (Math.exp(x) + Math.exp(-x)) / 2.0;
	}

	public static function deg(x:Float):Float return x * 180.0 / Math.PI;

	public static function exp(x:Float):Float return Math.exp(x);

	public static function floor(x:Float):Float return Math.floor(x);

	public static function fmod(x:Float, y:Float):Null<Float> {
		if (y == 0) return null;
		var q:Float = x / y;
		var qtrunc:Float = (q >= 0) ? Math.floor(q) : Math.ceil(q);
		return x - qtrunc * y;
	}

	public static function frexp(x:Float):Dynamic {
		if (x == 0) return { m: 0.0, e: 0 };
		var e:Int = 0;
		var m:Float = x;
		while (Math.abs(m) >= 1.0) {
			m /= 2.0;
			e++;
		}
		while (Math.abs(m) < 0.5) {
			m *= 2.0;
			e--;
		}
		return { m: m, e: e };
	}

	public static function ldexp(m:Float, e:Int):Float {
		return m * Math.pow(2.0, e);
	}

	public static function log(x:Float):Float return Math.log(x);

	public static function log10(x:Float):Float return Math.log(x) / Math.log(10.0);

	public static function max(x:Float, ...rest:Float):Float {
		var m:Float = x;
		for (v in rest) if (v > m) m = v;
		return m;
	}

	public static function min(x:Float, ...rest:Float):Float {
		var m:Float = x;
		for (v in rest) if (v < m) m = v;
		return m;
	}

	public static function modf(x:Float):Dynamic {
		var intPart:Float = (x >= 0) ? Math.floor(x) : Math.ceil(x);
		var frac:Float = x - intPart;
		return { intPart: intPart, fracPart: frac };
	}
	public static final pi:Float = Math.PI;

	public static function pow(x:Float, y:Float):Float return Math.pow(x, y);

	public static function rad(x:Float):Float return x * Math.PI / 180.0;

	public static function random(?m:Int, ?n:Int):Dynamic {
		var r:Float = _lcgNext();
		if (m == null) return r;
		if (n == null) {
			if (m <= 0) return 0;
			return Std.int(Math.floor(r * m)) + 1;
		} else {
			if (n < m) return 0;
			return Std.int(Math.floor(r * (n - m + 1))) + m;
		}
	}

	public static function randomseed(x:Float):Void {
		_lcgSeed = Math.abs(x) % 4294967296.0;
		if (_lcgSeed == 0) _lcgSeed = 1.0;
	}

	public static function sin(x:Float):Float return Math.sin(x);

	public static function sinh(x:Float):Float {
		return (Math.exp(x) - Math.exp(-x)) / 2.0;
	}

	public static function sqrt(x:Float):Float return Math.sqrt(x);

    public static function tan(x:Float):Float return Math.tan(x);

	public static function tanh(x:Float):Float {
		var ex:Float = Math.exp(x);
		var enx:Float = Math.exp(-x);
		return (ex - enx) / (ex + enx);
	}
}
