
    function foo (a,b)
      local x
      do local c = a - b end
      local a = 1
      for k,v in pairs(debug.getinfo(foo)) do
         print(k,v)
      end
      while true do
        local name, value = debug.getlocal(1, a)
        if not name then break end
        print(name, value)
        a = a + 1
      end
    end
    
    foo(10, 20)

