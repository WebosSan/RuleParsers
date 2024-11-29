
a = 'hello world'

local b = 'Hello World'

function f(c)
	if c then
		trace('hx');
		return 'rulescript'
	elseif c == 0 then
		return 'rulescript: 0'
	else
		return 'Rulescript'
end

trace(f(true));