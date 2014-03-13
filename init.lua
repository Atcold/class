local argcheck = require 'argcheck'
local argcheckenv = require 'argcheck.env'
local doc = require 'argcheck.doc'

doc[[
Object Classes for Lua
----------------------

This package provide simple object-oriented capabilities to Lua.
Each class is defined with a metatable, which contains methods.
Inheritance is achieved by setting metatables over metatables.
An efficient type checking is provided.

## Typical Example

```lua
local class = require 'class'

-- define some dummy A class
local A = class('A')

function A:__init(stuff)
  self.stuff = stuff
end

function A:run()
  print(self.stuff)
end

-- define some dummy B class, inheriting from A
local B = class('B', 'A')

function B:__init(stuff)
  A.__init(self, stuff) -- call the parent init
end

function B:run5()
  for i=1,5 do
    print(self.stuff)
  end
end

-- create some instances of both classes
local a = A('hello world from A')
local b = B('hello world from B')

-- run stuff
a:run()
b:run()
b:run5()
```

## Documentation

First, require the package
```lua
local class = require 'class'
```
Note that `class` does not clutter the global namespace.

Class metatables are then created with `class(name)` or equivalently `class.new(name)`.
```lua
local A = class('A')
local B = class('B', 'A') -- B inherit from A
```

You then have to fill-up the returned metatable with methods.
```lua
function A:myMethod()
  -- do something
end
```

There are two special methods: `new()`, which already exists when the class is created and _should not be overrided_
and `__init()` which is called by `new()` at the creation of the class.
```lua
function A:__init(args)
  -- do something with args
  -- note that self exists
end
```

Creation of an instance is then achieved with the `new()` function or (equivalently) using the Lua `__call` metamethod:
```lua
local a = A('blah blah') -- an instance of A
local aa = A.new('blah blah') -- equivalent of the above
```

]]

local class = {}
local classes = {}
local isofclass = {}

-- create a constructor table
local function constructortbl(metatable)
   local ct = {}
   setmetatable(ct, {
                   __index=metatable,
                   __newindex=metatable,
                   __metatable=metatable,
                   __call=function(self, ...)
                             return self.new(...)
                          end
                })
   return ct
end

class.new = argcheck{
   doc = [[
### `class.new(name[, parentname])`

Creates a new class called `name`, which might optionally inherit from `parentname`.
Returns a table, in which methods should be defined.

Note that the returned table is not the metatable, but a _constructor_ table (with a `__call`
function defined). In that respect, one can use the following shorthand:
```lua
local A = class.new('A')
local a = A.new() -- instance.
local aa = A()    -- another instance (shorthand).
```

There is also a shorthand`class.new()`, which is `class()`.

]],
   {name="name", type="string"},
   {name="parentname", type="string", opt=true},
   call =
      function(name, parentname)
         assert(not classes[name], string.format('class <%s> already exists', name))

         local class = {__typename = name, __version=1}
         class.__index = class

         class.__init =
            function()
            end

         class.new =
            function(...)
               local self = {}
               setmetatable(self, class)
               self:__init(...)
               return self
            end

         classes[name] = class
         isofclass[name] = {[name]=true}

         if parentname then
            assert(classes[parentname], string.format('parent class <%s> does not exist', parentname))
            setmetatable(class, classes[parentname])
            isofclass[parentname][name] = true
            return constructortbl(class), classes[parentname]
         else
            return constructortbl(class)
         end
      end
}

class.factory = argcheck{
   doc = [[
### `class.factory(name)`

Return a new (empty) instance of the class `name`. No `__init` method will be called.

]],
   {name="name", type="string"},
   call =
      function(name)
         assert(classes[name], string.format('unknown class <%s>', name))
         local t = {}
         setmetatable(t, classes[name])
         return t
      end
}

class.metatable = argcheck{
   doc = [[
### `class.metatable(name)`

Return the metatable (i.e. the table containing all methods) related to class `name`.

]],
   {name="name", type="string"},
   call =
      function(name)
         return classes[name]
      end
}

doc[[
### `class.type(obj)`

Return the type of the object `obj` (if this is a known class), or the type
returned by the standard lua `type()` function (if it is not known).

]]

function class.type(obj)
   local tname = type(obj)
   if tname == 'table' then
      local mt = getmetatable(obj)
      if mt then
         return rawget(mt, '__typename') or tname
      end
   end
   return tname
end

doc[[
### `class.istype(obj, name)`

Check is `obj` is an instance (or a child) of class `name`. Returns a boolean.

]]

function class.istype(obj, typename)
   local tname = type(obj)
   if tname == 'table' then
      local mt = getmetatable(obj)
      if mt then
         local objname = rawget(mt, '__typename')
         if objname then -- we are now sure it is one of our object
            local valid = isofclass[typename]
            if valid then
               return rawget(valid, objname) or false
            else
               return false
            end
         end
      end
   end
   return tname == typename
end

-- make sure argcheck understands those types
argcheckenv.istype = class.istype

-- allow class() instead of class.new()
setmetatable(class, {__call=
                        function(self, ...)
                           return self.new(...)
                        end})

return class
