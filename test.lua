function string2Repr(s)
   local byte2Repr= {
      [0] = "\\0",
      [7] = "\\a", 
      [8] = "\\b", 
      [9] = "\\t", 
      [11] = "\\v",
      [12] = "\\f",
      [13] = "\\r", 
      [34] = "\\\"", 
      [39] = "\\\'",
      [92] = "\\\\" 
   }
   local sr = "\""   
   for i=1, #s do
      local b = string.byte(s, i)
      local r = byte2Repr[b]
      if r == nil then
         if b >= 32 and b <= 127 then
            r = string.char(b)
         else
            r = "\\x"..string.format('%02X', b)
         end
      end
      sr = sr .. r
   end
   sr = sr .. "\""
   return sr
end