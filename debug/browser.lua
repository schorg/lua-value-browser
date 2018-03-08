local is51 = _VERSION == "Lua 5.1"

local string = require "string"
local io = require "io"
local table = require "table"
local coroutine = require "coroutine"
local debug = require "debug"

local assert = assert
local error = error
local type = type
local setmetatable = setmetatable
local getmetatable = getmetatable
local getfenv = getfenv -- nil for 5.2
local load = load -- nil for 5.1
local loadstring = loadstring -- nil for 5.2
local pcall = pcall
local pairs = pairs
local ipairs = ipairs
local tostring = tostring
local rawset = rawset
local print = print

local _ENV = is51 and module(...) or {} -- nil for 5.1

version = "Lua value browser 0.2"
copyright = "Copyright (C) 2010-2018, schorg@gmail.com"

--[[--------------------------------------------------------------------

  A pretty printer 

--]]--------------------------------------------------------------------


local modes = "flat" or "break" -- just for comment purposes
space = " "

function wrap(string)
   string = string or space
   assert(type(string) == "string")
   return {wrap = string}
end

function nest(doc)
   assert(type(doc) == "table" or type(doc) == "action")
   return {nest = doc}
end

function group(doc)
   assert(type(doc) == "table" or type(doc) == "action")
   return {group = doc}
end

function pretty_printer(tab, width, write)
   -- returns a pretty printer closure for width 

   local remaining_space

   local function fits(doc)
      local tdoc = type(doc)
      if tdoc == "string" then
	      remaining_space = remaining_space - string.len(doc)
	      return remaining_space > 0 
      elseif tdoc == "table" then
         if doc.nest then
            remaining_space = remaining_space - string.len(space)
            return fits(doc.nest)
         elseif doc.group then
            return fits(doc.group)
         elseif doc.wrap then
            remaining_space = remaining_space - string.len(doc.wrap)
            return remaining_space > 0
         else
            local r = true
            for i in ipairs(doc) do
               r = fits(doc[i]) and r
            end
            return r
         end
      else
	      error("this should not happen")
      end
   end
   
   local available_space = width or 72
   
   local function layout(indent, mode, doc)
      local tdoc = type(doc)
      if tdoc == "string" then
         available_space = available_space - string.len(doc) 
         write(doc)
      elseif tdoc == "table" then
         if doc.nest then
            indent = indent + tab
            return layout(indent, mode, doc.nest)
         elseif doc.group then
            remaining_space = available_space 
            if fits(doc.group) then
               return layout(indent, "flat", doc.group)
            else
               return layout(indent, "break", doc.group)
            end
         elseif doc.wrap then
            if mode == "flat" then
               available_space = available_space - string.len(doc.wrap)
               write(doc.wrap)
            else
               available_space = width - indent
               write('\n', string.rep(space, indent))
            end
         else
            for i in ipairs(doc) do
               layout(indent, mode, doc[i])
            end
         end
      else
	      error("this should not happen")
      end
   end
   
   return function(doc)
	          return layout(0, "flat", doc)
	       end
end

--[[ examples 

function binop(left, op, right)
   return group{left, space, op, nest{wrap(), right}}
end

function cond()
   return binop("a", "==", "b")
end

function expr1()
   return binop("a", "<<", "2")
end

function expr2()
   return binop("a", "+", "b")
end

function ifthen(c, e1, e2)
   return group{
      group{"if", nest{wrap(), c}},
      wrap(),
      group{"then", nest{wrap(), e1}},
      wrap(),
      group{"else", nest{wrap(), e2}},
   }
end

doc = ifthen(cond(), expr1(), expr2())

pretty_printer(2, 9, io.write)(doc)

--]]

--------
-- model
--------

local function issimple (value)
   local t = type(value)
   return  t == "nil" 
      or t == "string"
      or t == "boolean" 
      or t == "number" 
      or t == "thread" 
--       or t == "userdata" 
end

local function isfunction (value)
   return type(value) == "function"
end

local function istable (value)
   return type(value) == "table"
end

local function isuserdata (value)
   return type(value) == "userdata"
end

local function key2name (key)
   local t = type(key)
   if t == "string" then
      return key
   elseif t == "boolean" or t == "number" then
      return "["..tostring(key).."]"
   else
      return "<"..tostring(key)..">"
   end
end

local function key2link(key)
   local t = type(key)
   if t == "string" then
      return '.'..key
   else
      return 
   end
end

local function simple2repr (value)
   return tostring(value)
end

local function complex2repr (value)
   local repr = {links = {}}   
   for k,v in pairs(value) do
      local elem = {}
      elem.name = key2name(k)
      elem.value = v
      if istable(v) or isfunction(v) or isuserdata(v) then
	 repr.links["."..elem.name] = elem
      end
      table.insert(repr, elem)
   end
   local mt = getmetatable(value)
   if mt then
      local elem = {name = "<metatable>" , value = mt}
      repr.links[".<metatable>"] = elem
      table.insert(repr, elem)
   end
   table.sort(repr, function (a,b) return a.name < b.name end)
   return repr
end

local function table2repr(value)
   return complex2repr(value)
end

local function userdata2repr(value)
   local mt = getmetatable(value)
   if mt then
      local repr = {links = {}}   
      local elem = {name = "<metatable>" , value = mt}
      repr.links[".<metatable>"] = elem
      table.insert(repr, elem)
      return repr
   else
      return simple2repr(value)
   end
end


local function function2repr (value)
   local function upvalues(func)
      local i = 0
      return function() 
                i = i+1 
                return debug.getupvalue(func, i) 
             end
   end 
   local ft = debug.getinfo(value, "nS")
   ft["<fenv>"] = is51 and getfenv(value) or debug.getupvalue(value, 1)
   local ups
   for k, v in upvalues(value) do
      ups = ups or {}
      ups[k] = v
   end
   ft["<upvalues>"] = ups
   return complex2repr(ft)
end

function visit (value)
   local repr
   if istable(value) then
      repr = table2repr(value)
   elseif isuserdata(value) then
      repr = userdata2repr(value)
   elseif issimple(value) then
      repr = simple2repr(value)
   else -- typ == "function"
      repr = function2repr(value)
   end
   return repr
end


---------
-- view
---------

local function simple2doc(repr)
   return repr
end

local function value2doc(name, value)
   if issimple(value) then
      return nest{wrap(), "= ", tostring(value)}
   else 
      return nest{wrap(), "= ", "."..name}
   end
end
      
local function complex2doc (repr)
   local delems = {}
   local doc =  group{
      nest{"{", nest{delems}, wrap "", "}"}
   }
   local fst = true   
   for _, v in ipairs(repr) do
      local delem = group{
         group{v.name, ":", nest{wrap(), type(v.value)}}, 
         value2doc(v.name, v.value)
      }
      if fst then
	      table.insert(delems, {wrap "", delem})
	      fst = false
      else
	      table.insert(delems, {",", wrap " ", delem})
      end
   end

   return doc
end

local function function2doc (repr)
   return complex2doc(repr)
end

local function table2doc (repr)
   return complex2doc(repr)
end

local function userdata2doc (repr)
   if type(repr) == "table" then
      return complex2doc(repr)
   else
      return simple2doc(repr)
   end
end

function view (name, type, repr)
   local dr
   if type == "table" then
      dr = table2doc(repr)
   elseif type == "userdata" then
      dr = userdata2doc(repr)
   elseif type == "function" then
      dr = function2doc(repr)
   else -- simple type
      dr = simple2doc(repr)
   end

   local doc = group{
      group{name, ":", nest{wrap(), type}},
      group{nest{wrap(), "= ", dr}}
   }

   return doc
end

function show(doc)
   return pretty_printer(2, 80, io.write)(doc)
end

--[[--------------------------------------------------------------------

   ADT Course - caches a linear course

--]]--------------------------------------------------------------------

Course = (function ()
	         local adt = {}
	         adt.__index = adt
	         return adt
	      end)()

function course(equals)
   assert(type(equals) == "function")
   local h = {
      index = 0,
      cache = {},
      equals = equals
   }
   return setmetatable(h, Course)
end
   

function Course:current()
   return self.cache[self.index]
end

function Course:prev()
   if self.index > 1 then
      self.index = self.index - 1
      return self.cache[self.index]
   end
end

function Course:next()
   if self.index < #self.cache then
      self.index = self.index + 1
      return self.cache[self.index]
   end
end

function Course:add(elem)
   self.index = self.index + 1
   if not self.equals(elem, self.cache[self.index] or {}) then
      for i = self.index, #self.cache do
	      table.remove(self.cache, i)
      end
      table.insert(self.cache, self.index, elem)
   end
end

------------
-- Controller 
------------

local history = course(function (e1, e2) return e1.value == e2.value end)

local function getvalue(expression)
   local code = expression
   local chunk = string.format("return %s", code)
   local f, err
   if is51 then  -- depends on lua version
      f, err = loadstring(chunk)
   else
      f, err = load(chunk) 
   end
   if f == nil then
      io.write(err)
   else
      local ok, ret = pcall(f)
      if not ok then
         io.write(ret)
      elseif ret == nil then
         io.write(code.." does not exist")
      else
         return ret
      end
   end
end

local function getlinkvalue(link)
   local ret = history:current().repr.links[link]
   if ret == nil then  
      io.write(link.." does not exist")
   else
      return ret
   end
end


local prompt = ": "
local newline = "\n"
local beep = "\07"


local commands 

local h =
[[
   Browse Lua runtime values, like a web page.

   Available Commands:
   (h)elp  (f)orward (b)ack (r)eload .<link> (t)ab [@]<expr> (q)uit
   
   <enter>     executes one of the above commands
   [@]<expr>   show data entity for Lua <expr>, @ quotes commands
   help (h)    show this message
   forward (f) history forward
   back (b)    history back
   reload (r)  reload current
   .<link>     select .<link>
   .<prefix>   complete to next matching link with prefix .<prefix>
   tab (t)     selects the next link
   quit (q)    quit browser
]]

function help(path)
   io.write(h)
   io.write(newline..prompt)
   return nil, path
end

local linkiterator

local function mktab(repr)
   local list = {}
   if type(repr) == "table" then
      for k, v in pairs(repr.links) do
	      table.insert(list, k)
      end
      table.sort(list)
   end

   local i = 0
   local n = #list
   local function tab()
      i = i + 1
      if i > n then
	      i = 0
	      return nil
      else
	      return list[i]
      end
   end
   
   linkiterator = tab
end

function tab(path)
   local link
   if linkiterator then
      link = linkiterator()
   end
   if link then
      io.write(prompt..link)
   end
   io.write(prompt)
   return link, path
end

function back()
   local prev = history:prev()
   local name
   if prev then
      name = prev.name
      io.write(show(prev.doc))
      mktab(prev.repr)
   else
      name = history:current().name
      io.write("back history not available")
   end
   io.write(newline..prompt)   
   return nil, name
end

function forward()
   local next = history:next()
   local name
   if next then
      name = next.name
      io.write(show(next.doc))
      mktab(next.repr)
   else
      name = history:current().name
      io.write("forward history not available")
   end
   io.write(newline..prompt)
   return nil, name
end

function reload()
   local current = history:current()
   local name 
   if current then
      name = current.name
      io.write(show(current.doc))
      mktab(current.repr)
   else
      io.write("nothing to reload")
   end
   io.write(newline..prompt)
   return nil, name
end

function quit()
   coroutine.yield()
   io.write(prompt)
   return nil, nil
end

commands = {
   ["help"] = help, ["h"] = help,
   ["tab"] = tab, ["t"] = tab,
   ["forward"] = forward, ["f"] = forward,
   ["back"] = back, ["b"] = back,
   ["reload"] = reload, ["r"] = reload,
   ["quit"] = quit, ["q"] = quit,   
}


function go (path, expressioninput)
   local value = getvalue(expressioninput)
   if value ~= nil then
      local name = '('..expressioninput..')'
      local type = type(value)
      local repr = visit(value)
      local doc = view(name, type, repr)
      io.write(show(doc))
      history:add{name = name, value = value, doc = doc, repr = repr}
      mktab(repr)
      io.write(newline..prompt)
      return nil, name
   else
      io.write(newline..prompt)
      return nil, path
   end
end


function click(path, linkinput)
   local ret = getlinkvalue(linkinput)
   local name = path
   if ret then
      name = path..linkinput
      local value = ret.value
      local type = type(value)
      local repr = visit(value)
      local doc = view(name, type, repr)
      io.write(show(doc))
      history:add{name = name, value = value, doc = doc, repr = repr}
      mktab(repr)
   end
   io.write(newline..prompt)
   return nil, name
end

local function complete(path, sublink)
   local function check(sublink, link)
      return string.sub(link, 1, string.len(sublink)) == sublink
   end
   local link
   for lnk in linkiterator do
      if check(sublink, lnk) then
	      link = lnk
	      break
      end
   end
   if link then 
      io.write(prompt..link)
   end
   io.write(prompt)
   return link, path
end

local function islink(input)
   local c = history:current()
   if c and type(c.repr) ~= "string" then
      return c.repr.links[input] ~= nil
   else
      return false
   end
end

local function islinkprefix(input)
   local c = string.sub(input, 1, 1)
   return c == "." or c == "[" or c == "#"
end

local function isquoted(input)
   return string.sub(input, 1, 1) == '@'
end

local function browser()
   local input
   local path
   io.write(version, newline, copyright, newline)
   io.write("Type 'q' to quit, 'help' for help", newline)
   io.write(prompt)
   mktab({links={}})
   while true do
      input = input or ""
      local ip = io.read("*l")
      local command = commands[ip]
      if command then
         input, path = command(path)
      else
         input = input..ip
         if islink(input) then
            input, path = click(path, input)
         elseif islinkprefix(input) then
            input, path = complete(path, input) 
         elseif isquoted(input) then
            input, path = go(path, string.sub(input,2))
         elseif input ~= "" then
            input, path = go(path, input)
         else
            io.write(prompt)
         end
      end
   end
end

local browse = coroutine.wrap(
   function ()
      local ok, err = pcall(browser)
      if not ok then
         io.write(err, newline)
      end
   end
)

-- add function browse to module "debug"
debug["browse"] = browse
