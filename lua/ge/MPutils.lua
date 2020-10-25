--=============================================================--
--	Generic helper functions added by the BeamMP team
--		feel free to suggest more
--=============================================================--


-- split() splits an S string into a table separated by SEP
function split(s, sep)
    local fields = {}

    local sep = sep or " "
    local pattern = string.format("([^%s]+)", sep)
    string.gsub(s, pattern, function(c) fields[#fields + 1] = c end)

    return fields
end


-- from https://github.com/Wavalab/rgb-hsl-rgb
-- h, s, l, r, g, b, are all in range [0, 1]
function hslToRgb(h, s, l)
    if s == 0 then return l, l, l end
    local function to(p, q, t)
        if t < 0 then t = t + 1 end
        if t > 1 then t = t - 1 end
        if t < .16667 then return p + (q - p) * 6 * t end
        if t < .5 then return q end
        if t < .66667 then return p + (q - p) * (.66667 - t) * 6 end
        return p
    end
    local q = l < .5 and l * (1 + s) or l + s - l * s
    local p = 2 * l - q
    return to(p, q, h + .33334), to(p, q, h), to(p, q, h - .33334)
end

function rgbToHsl(r, g, b)
    local max, min = math.max(r, g, b), math.min(r, g, b)
    local b = max + min
    local h = b / 2
    if max == min then return 0, 0, h end
    local s, l = h, h
    local d = max - min
    s = l > .5 and d / (2 - b) or d / b
    if max == r then h = (g - b) / d + (g < b and 6 or 0)
    elseif max == g then h = (b - r) / d + 2
    elseif max == b then h = (r - g) / d + 4
    end
    return h * .16667, s, l
end


function ColorFtoPoint4F(color)
	return Point4F(color.r, color.g, color.b, color.a)
end

function Point4FtoColorF(point)
	return ColorF(point.x, point.y, point.z, point.w)
end

function interpolateRGB(colors, numOfSteps, step)
	local h = step / numOfSteps
	local i = math.floor(h * table.getn(colors))
	local p = h * table.getn(colors) - i
	local q = 1 - p


	local colorsIndex = i % table.getn(colors) + 1
	
	local p = step % timePeriod;
	
	local r = colors[colorsIndex].r * (1.0 - p) + ( colors[colorsIndex+1].r * p );
	local g = colors[colorsIndex].g * (1.0 - p) + ( colors[colorsIndex+1].g * p );
	local b = colors[colorsIndex].b * (1.0 - p) + ( colors[colorsIndex+1].b * p );
	local a = colors[colorsIndex].a * (1.0 - p) + ( colors[colorsIndex+1].a * p );

	return ColorF(r, g, b, a)
end

function interpolateHSL(colors, numOfSteps, step)
	local h = step / numOfSteps
	local i = math.floor(h * table.getn(colors))
	local p = h * table.getn(colors) - i
	local q = 1 - p
	local colorsIndex = i % table.getn(colors) + 1
	local p = step % timePeriod;

	local h1, s1, l1 = rgbToHsl(colors[colorsIndex].r, colors[colorsIndex].g, colors[colorsIndex].b)

	local h2, s2, l2 = rgbToHsl(colors[colorsIndex+1].r, colors[colorsIndex+1].g, colors[colorsIndex+1].b)

	local h = h1 * (1.0 - p) + ( h2 * p );
	local s = s1 * (1.0 - p) + ( s2 * p );
	local l = l1 * (1.0 - p) + ( l2 * p );
	local a = colors[colorsIndex].a * (1.0 - p) + ( colors[colorsIndex+1].a * p );

	local r, g, b = hslToRgb(h, s, l)

	return ColorF(r, g, b, a)
end











