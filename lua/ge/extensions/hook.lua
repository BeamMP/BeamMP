-- Author: Christian Vallentin <mail@vallentinsource.com> // Thank you for your work, Christian!
-- Repository: https://github.com/MrVallentin/hook.lua

local unpack = unpack or table.unpack
local hook = {}

local function callhooks(hookedfunc, ...)
    local result = nil

    for i = 1, #hookedfunc.__hooks, 1 do
        result = {hookedfunc.__hooks[i](...)}

        if result ~= nil and #result > 0 then
            return unpack(result)
        end
    end

    return nil
end

local function newhook(func, hook)
    local hookedfunc = {}

    hookedfunc.__hooks = { hook }
    hookedfunc.__func = func

    setmetatable(hookedfunc, {
        __call = function(func, ...)
            local result = {callhooks(hookedfunc, ...)}

            if result ~= nil and #result > 0 then
                return unpack(result)
            end

            return hookedfunc.__func(...)
        end
    })

    return hookedfunc
end

local function addhook(func, hook)
    func.__hooks[#func.__hooks + 1] = hook

    return func
end

local function ishookedfunc(hookedfunc)
    if type(hookedfunc) == "table" then
        if type(hookedfunc.__hooks) == "table" then
            return true
        end
    end

    return false
end


function hook.add(func, hook)
    if hook == nil then
        return func
    end

    local t = type(func)

    if t == "function" then
        return newhook(func, hook)
    elseif t == "table" then
        return addhook(func, hook)
    end

    return func
end

function hook.call(hookedfunc, ...)
    if ishookedfunc(hookedfunc) then
        return callhooks(hookedfunc, ...)
    end

    return nil
end

function hook.remove(hookedfunc, hook)
    if ishookedfunc(hookedfunc) then
        for i = #hookedfunc.__hooks, 1, -1 do
            if hookedfunc.__hooks[i] == hook then
                table.remove(hookedfunc.__hooks, i)
            end
        end

        if #hookedfunc.__hooks == 0 then
            return hookedfunc.__func
        end
    end

    return hookedfunc
end

function hook.clear(hookedfunc)
    if ishookedfunc(hookedfunc) then
        hookedfunc.__hooks = {}

        return hookedfunc.__func
    end

    return hookedfunc
end

function hook.count(hookedfunc)
    if ishookedfunc(hookedfunc) then
        return #hookedfunc.__hooks
    end

    return 0
end

function hook.gethooks(hookedfunc)
    if ishookedfunc(hookedfunc) then
        local hooks = {}

        for i = 1, #hookedfunc.__hooks, 1 do
            hooks[i] = hookedfunc.__hooks[i]
        end

        return hooks
    end

    return nil
end

return hook