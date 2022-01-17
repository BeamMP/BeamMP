--thx to https://github.com/sulai/Lib-Pico8/blob/master/lang.lua

function enum(names, offset)
    offset=offset or 1
    local objects = {}
    local size=0
    for idr,name in pairs(names) do
        local id = idr + offset - 1
        local obj = {
            id=id,
            idr=idr,
            name=name
        }
        objects[name] = obj
        objects[id] = obj
        size=size+1
    end
    objects.idstart = offset
    objects.idend = offset+size-1
    objects.size=size
    objects.all = function()
        local list = {}
        for _,name in pairs(names) do
            add(list,objects[name])
        end
        local i=0
        return function() i=i+1 if i<=#list then return list[i] end end
    end
    return objects
end
