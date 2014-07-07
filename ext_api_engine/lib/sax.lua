--
-- Created by IntelliJ IDEA.
-- User: jasonxu
-- Date: 5/14/13
-- Time: 11:55 AM
-- To change this template use File | Settings | File Templates.
--

local sax = {}

sax.parse = function(doc, callbacks)
    local c,b,e,tag = 1,1,1
    while c<string.len(doc) do
        b,e,tag = string.find(doc, "<(.-)>",c)
        if b == nil then break end
        c=e+1

        if string.sub(tag,1,1) ~= '/' then
            if callbacks.startElement then
                callbacks.startElement(tag)
            end
            b,e,v = string.find(doc, "([^<^>]-)<.->",c)
            if b and callbacks.characters then
                c=b+string.len(v)
                callbacks.characters(v)
            end
        else
            if callbacks.endElement then
                callbacks.endElement(string.sub(tag,2))
            end
        end
    end
end

return sax