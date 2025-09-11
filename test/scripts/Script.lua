--Comment test
local str = "String"

local num = 1
local float = 1.5

print(#str, #num, #float)

local obj = {}
obj.name = "Jonas"
obj.greet = function (self)
    print("Hello " + self.name)
    return nil
end