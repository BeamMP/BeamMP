-- Copyright (C) 2024 BeamMP Ltd., BeamMP team and contributors.
-- Licensed under AGPL-3.0 (or later), see <https://www.gnu.org/licenses/>.
-- SPDX-License-Identifier: AGPL-3.0-or-later

--- Client side chat filter.
-- Hides offensive words on the local screen by replacing every character with `*`.
-- Nothing is blocked or changed for other players, and the raw message is still logged.
--
-- The word lists live in `beammp/chatFilterLists/level_N.txt` (one entry per line), they are written and kept up to
-- date by the moderation team. The chosen level uses the file for that level only, so each file has to be complete
-- on its own. The user can add their own words on top.
--
-- Matching works on whole words, not on substrings, so harmless words that merely contain a blocked word are left alone.
-- A word is still caught when:
--   - it uses capital letters, repeated letters ("fuuuck") or letters spread out ("f u c k"),
--   - it swaps letters for numbers, symbols or look alike characters from other alphabets ("sh1t", "a$$", "fиck"),
--   - it is a common variation of a blocked word (plurals, "-ing", "-ed", ...), or has up to 2 extra letters on
--     the end of a blocked word that is at least 6 letters long ("orgasme"). Variations are never applied to words
--     in `allowed.txt`, which holds harmless words that happen to look like a variation ("spiced").
--
-- This module has no game dependencies except the global `readFile`, so it can be tested with plain LuaJIT.
-- @module chatFilter
-- @usage local chatFilter = require("beammp.chatFilter")
-- @usage local text = chatFilter.filter("hello", 2, "word one, word two")

local M = {}

local LIST_PATH = "/lua/ge/extensions/beammp/chatFilterLists/level_%d.txt"
local ALLOWED_PATH = "/lua/ge/extensions/beammp/chatFilterLists/allowed.txt"
local MAX_LEVEL = 4
local MIN_EXTENDABLE = 6 -- blocked words at least this long also match with a few extra letters at the end
local MAX_EXTRA_LETTERS = 2
local MAX_TOKEN_LENGTH = 40 -- longer "words" are skipped, they are links or spam, not insults
local MAX_SPACED_LETTERS = 12
local MAX_CUSTOM_ENTRIES = 200
local MAX_CUSTOM_ENTRY_LENGTH = 64

-- common endings that still make a blocked word a blocked word. [ending] = minimum length of what is left over
local SUFFIXES = {
	s = 3, ed = 3, ing = 3, ings = 3,
	["es"] = 3, -- only after s, x, z, ch and sh: "asses", "bitches", but not "spices"
	["in"] = 4, -- "fuckin", but not "cumin"
}
local ES_AFTER = {s = true, x = true, z = true, h = true}

-- one UTF-8 encoded character
local CHAR = "[%z\1-\127\194-\244][\128-\191]*"

-- characters that stand in for letters. An entry is a letter, or a table of letters when it is ambiguous.
local LEET = {
	["0"] = "o", ["1"] = {"i", "l"}, ["3"] = "e", ["4"] = "a", ["5"] = "s", ["7"] = "t", ["8"] = "b", ["9"] = "g",
	["@"] = "a", ["$"] = "s", ["!"] = {"i", "l"}, ["|"] = {"i", "l"},
}
local AMBIGUOUS_CHARS = "[1!|]"

-- non ASCII characters that look like a latin letter. [codepoint] = {letters, isRealLetter}
local LOOKALIKE = {}
do
	local function add(letter, ...)
		for _, codepoint in ipairs({...}) do LOOKALIKE[codepoint] = {letter, true} end
	end
	-- latin letters with accents
	add("a", 0xE0, 0xE1, 0xE2, 0xE3, 0xE4, 0xE5, 0xC0, 0xC1, 0xC2, 0xC3, 0xC4, 0xC5)
	add("c", 0xE7, 0xC7)
	add("e", 0xE8, 0xE9, 0xEA, 0xEB, 0xC8, 0xC9, 0xCA, 0xCB)
	add("i", 0xEC, 0xED, 0xEE, 0xEF, 0xCC, 0xCD, 0xCE, 0xCF, 0x131)
	add("l", 0x142, 0x141)
	add("n", 0xF1, 0xD1)
	add("o", 0xF2, 0xF3, 0xF4, 0xF5, 0xF6, 0xF8, 0xD2, 0xD3, 0xD4, 0xD5, 0xD6, 0xD8)
	add("u", 0xF9, 0xFA, 0xFB, 0xFC, 0xD9, 0xDA, 0xDB, 0xDC)
	add("y", 0xFD, 0xFF, 0xDD)
	add("ss", 0xDF)
	-- cyrillic
	add("a", 0x430, 0x410)
	add("b", 0x432, 0x412)
	add("c", 0x441, 0x421)
	add("e", 0x435, 0x415, 0x451, 0x401)
	add("h", 0x43D, 0x41D)
	add("i", 0x456, 0x406)
	add("j", 0x458, 0x408)
	add("k", 0x43A, 0x41A)
	add("m", 0x43C, 0x41C)
	add("o", 0x43E, 0x41E)
	add("p", 0x440, 0x420)
	add("s", 0x455, 0x405)
	add("t", 0x442, 0x422)
	add("x", 0x445, 0x425)
	add("y", 0x443, 0x423)
	-- greek
	add("a", 0x3B1, 0x391)
	add("b", 0x3B2, 0x392)
	add("e", 0x3B5, 0x395)
	add("h", 0x397)
	add("i", 0x3B9, 0x399)
	add("k", 0x3BA, 0x39A)
	add("m", 0x39C)
	add("n", 0x39D)
	add("o", 0x3BF, 0x39F)
	add("p", 0x3C1, 0x3A1)
	add("t", 0x3C4, 0x3A4)
	add("u", 0x3C5)
	add("v", 0x3BD)
	add("x", 0x3C7, 0x3A7)
	add("y", 0x3A5)
	add("z", 0x396, 0x3B6)
	-- fullwidth latin letters
	for offset = 0, 25 do
		LOOKALIKE[0xFF21 + offset] = {string.char(97 + offset), true}
		LOOKALIKE[0xFF41 + offset] = {string.char(97 + offset), true}
	end
	-- symbols that stand in for a letter, like the numbers above
	LOOKALIKE[0x20AC] = {"e", false} -- euro sign
	LOOKALIKE[0xA2] = {"c", false} -- cent sign
	-- fullwidth digits
	for offset = 0, 9 do LOOKALIKE[0xFF10 + offset] = {tostring(offset), false} end
end

local function decode(char)
	local b1, b2, b3, b4 = char:byte(1, 4)
	if b1 < 0x80 then return b1 end
	b2, b3, b4 = (b2 or 0x80) - 0x80, (b3 or 0x80) - 0x80, (b4 or 0x80) - 0x80
	if b1 < 0xE0 then return (b1 - 0xC0) * 0x40 + b2 end
	if b1 < 0xF0 then return (b1 - 0xE0) * 0x1000 + b2 * 0x40 + b3 end
	return (b1 - 0xF0) * 0x40000 + b2 * 0x1000 + b3 * 0x40 + b4
end

--- Reduces text to plain lowercase latin letters and digits: swaps look alikes and number/symbol stand ins for
-- letters, and drops everything else (punctuation, zero width characters, emoji, ...).
-- @tparam string text
-- @tparam string ambiguous which letter `1`, `!` and `|` stand for, `i` or `l`
-- @treturn string the reduced text
-- @treturn number how many real letters (not stand ins) the text had
local function fold(text, ambiguous)
	local out, count, real = {}, 0, 0
	for char in text:gmatch(CHAR) do
		local codepoint = decode(char)
		local mapped, isLetter
		if codepoint < 128 then
			if codepoint >= 97 and codepoint <= 122 then
				mapped, isLetter = char, true
			elseif codepoint >= 65 and codepoint <= 90 then
				mapped, isLetter = string.char(codepoint + 32), true
			else
				local leet = LEET[char]
				if type(leet) == "table" then
					mapped = ambiguous == "l" and leet[2] or leet[1]
				elseif leet then
					mapped = leet
				elseif codepoint >= 48 and codepoint <= 57 then
					mapped = char
				end
			end
		else
			local lookalike = LOOKALIKE[codepoint]
			if lookalike then mapped, isLetter = lookalike[1], lookalike[2] end
		end
		if mapped then
			count = count + 1
			out[count] = mapped
			if isLetter then real = real + 1 end
		end
	end
	return table.concat(out), real
end

--- Collapses runs of 3 or more of the same character down to `keep` copies. Expects plain ASCII, as made by `fold`.
local function squash(text, keep)
	local out, count, index = {}, 0, 1
	while index <= #text do
		local char = text:sub(index, index)
		local last = index
		while text:sub(last + 1, last + 1) == char do last = last + 1 end
		local run = last - index + 1
		if run >= 3 then run = keep end
		count = count + 1
		out[count] = char:rep(run)
		index = last + 1
	end
	return table.concat(out)
end

--- Replaces every character except whitespace with `*`.
local function mask(text)
	return (text:gsub(CHAR, function(char)
		if char:find("^%s$") then return char end
		return "*"
	end))
end

local function trim(text)
	return (text:gsub("%s+", " "):match("^ ?(.-) ?$"))
end

-- ---------------------------------------------------------------------------------------------------------------------
-- compiling a word list

local function newMatcher()
	return {
		words = {}, -- foldable single words
		long = {}, -- the subset of `words` that may be followed by a few extra letters
		phrases = {}, -- foldable phrases, words joined with single spaces
		literal = {}, -- single words with digits or punctuation in them ("g-spot"), compared as written
		literalPhrases = {}, -- phrases with digits or punctuation in them ("2 girls 1 cup")
		symbols = {}, -- entries without any letters, like emoji. Replaced anywhere in the text
		allowed = {}, -- harmless words that are never matched as a variation of a blocked word
		maxPhraseWords = 2,
	}
end

local function addEntry(matcher, entry)
	entry = trim(entry:lower())
	if entry == "" then return end
	local isPhrase = entry:find(" ", 1, true) ~= nil

	if entry:find("[%d%p]") then
		-- contains digits or punctuation: compare exactly as written instead of looking for look alikes
		if isPhrase then
			matcher.literalPhrases[entry] = true
			local _, spaces = entry:gsub(" ", "")
			matcher.maxPhraseWords = math.max(matcher.maxPhraseWords, spaces + 1)
		else
			matcher.literal[entry] = true
		end
		return
	end

	local folded, allWordsHaveLetters = {}, true
	for word in entry:gmatch("%S+") do
		local reduced, real = fold(word, "i")
		if real == 0 then allWordsHaveLetters = false end
		folded[#folded + 1] = reduced
	end
	if not allWordsHaveLetters then
		-- only symbols (emoji and similar)
		if not entry:find("[%w]") and entry:find("[\128-\255]") then
			matcher.symbols[#matcher.symbols + 1] = entry
		end
		return
	end

	if #folded > 1 then
		matcher.phrases[table.concat(folded, " ")] = true
		matcher.maxPhraseWords = math.max(matcher.maxPhraseWords, #folded)
	else
		local word = folded[1]
		matcher.words[word] = true
		if #word >= MIN_EXTENDABLE then matcher.long[word] = true end
	end
end

--- Compiles a list of words and phrases.
-- @tparam table entries array of strings
-- @tparam[opt] table allowed array of harmless words that must not be matched as a variation of a blocked word
-- @treturn table a matcher to pass to `filterWith`
function M.compile(entries, allowed)
	local matcher = newMatcher()
	for _, entry in ipairs(entries or {}) do
		if type(entry) == "string" then addEntry(matcher, entry) end
	end
	for _, word in ipairs(allowed or {}) do
		if type(word) == "string" then
			local reduced = fold(word, "i")
			if reduced ~= "" then matcher.allowed[reduced] = true end
		end
	end
	return matcher
end

-- ---------------------------------------------------------------------------------------------------------------------
-- matching

--- Is this reduced word a blocked word, or a common variation of one?
local function matchesWord(matcher, word)
	if matcher.words[word] then return true end
	if matcher.allowed[word] then return false end

	-- endings: plural, "-ing", "-ed", ...
	local length = #word
	for suffix, minimumStem in pairs(SUFFIXES) do
		local stemLength = length - #suffix
		if stemLength >= minimumStem and word:sub(stemLength + 1) == suffix then
			local stem = word:sub(1, stemLength)
			if suffix ~= "es" or ES_AFTER[stem:sub(-1)] then
				if matcher.words[stem] then return true end
				-- doubled final consonant: "shitting" -> "shitt" -> "shit"
				if stem:sub(-1) == stem:sub(-2, -2) and matcher.words[stem:sub(1, -2)] then return true end
			end
		end
	end

	-- a few extra letters on a long blocked word: "orgasme"
	for extra = 1, MAX_EXTRA_LETTERS do
		local stemLength = length - extra
		if stemLength < MIN_EXTENDABLE then break end
		if matcher.long[word:sub(1, stemLength)] then return true end
	end
	return false
end

--- The reduced forms of a word to try: with and without repeated letters, for both readings of ambiguous characters.
local function candidates(core)
	local list, seen = {}, {}
	local function add(candidate)
		if #candidate >= 2 and not seen[candidate] then
			seen[candidate] = true
			list[#list + 1] = candidate
		end
	end
	local ambiguous = core:find(AMBIGUOUS_CHARS) ~= nil
	for _, reading in ipairs({"i", "l"}) do
		local reduced, real = fold(core, reading)
		if real == 0 then return list end -- "$100", "1337": numbers and symbols alone are never a word
		add(reduced)
		add(squash(reduced, 1))
		add(squash(reduced, 2))
		if not ambiguous then break end
	end
	return list
end

-- leading/trailing punctuation is not part of the word, but `@`, `$` and `|` often are ("@ss", "a$$")
local KEEP_LEADING = {["@"] = true, ["$"] = true, ["|"] = true}
local KEEP_TRAILING = {["$"] = true}

--- Splits text into whitespace separated words, without the punctuation around them.
local function tokenize(text)
	local tokens = {}
	for start, word in text:gmatch("()(%S+)") do
		local first, last = 1, #word
		while first <= last do
			local char = word:sub(first, first)
			if char:find("%p") and not KEEP_LEADING[char] then first = first + 1 else break end
		end
		while last >= first do
			local char = word:sub(last, last)
			if char:find("%p") and not KEEP_TRAILING[char] then last = last - 1 else break end
		end
		if first <= last then
			local core = word:sub(first, last)
			tokens[#tokens + 1] = {
				first = start + first - 1, last = start + last - 1, core = core, lower = core:lower(),
				length = #core,
				-- punctuation next to the word, so phrases do not run over a comma or the end of a sentence
				punctuationBefore = first > 1, punctuationAfter = last < #word,
			}
		end
	end
	return tokens
end

local function replacePlain(text, needle)
	local out, position = {}, 1
	while true do
		local first, last = text:find(needle, position, true)
		if not first then break end
		out[#out + 1] = text:sub(position, first - 1)
		out[#out + 1] = mask(needle)
		position = last + 1
	end
	if position == 1 then return text end
	out[#out + 1] = text:sub(position)
	return table.concat(out)
end

--- Filters text with a matcher from `compile`.
-- @tparam table matcher
-- @tparam string text
-- @treturn string the text, with every blocked word replaced by `*`
function M.filterWith(matcher, text)
	if not matcher or type(text) ~= "string" or text == "" then return text end

	for _, symbol in ipairs(matcher.symbols) do
		text = replacePlain(text, symbol)
	end

	local tokens = tokenize(text)
	local spans = {}
	local function censor(first, last) spans[#spans + 1] = {first, last} end

	-- phrases ("god damn"), the longest first
	local hasPhrases = next(matcher.phrases) ~= nil or next(matcher.literalPhrases) ~= nil
	if hasPhrases and #tokens > 1 then
		for _, token in ipairs(tokens) do token.reduced = fold(token.core, "i") end
		local index = 1
		while index < #tokens do
			local found
			-- how many words in a row, starting here, have nothing but whitespace between them
			local available = 1
			while index + available <= #tokens and available < matcher.maxPhraseWords
				and not tokens[index + available - 1].punctuationAfter and not tokens[index + available].punctuationBefore do
				available = available + 1
			end
			for count = available, 2, -1 do
				local reduced, literal = {}, {}
				for offset = 0, count - 1 do
					reduced[#reduced + 1] = tokens[index + offset].reduced
					literal[#literal + 1] = tokens[index + offset].lower
				end
				if matcher.phrases[table.concat(reduced, " ")] or matcher.literalPhrases[table.concat(literal, " ")] then
					found = count
					break
				end
			end
			if found then
				censor(tokens[index].first, tokens[index + found - 1].last)
				index = index + found
			else
				index = index + 1
			end
		end
	end

	-- single words
	for _, token in ipairs(tokens) do
		if token.length <= MAX_TOKEN_LENGTH then
			local blocked = matcher.literal[token.lower]
			if not blocked then
				for _, candidate in ipairs(candidates(token.core)) do
					if matchesWord(matcher, candidate) then blocked = true break end
				end
			end
			if blocked then censor(token.first, token.last) end
		end
	end

	-- letters spread out with spaces: "f u c k"
	local index = 1
	while index <= #tokens do
		if tokens[index].length == 1 and tokens[index].core:find("^%a$") then
			local runEnd = index
			while runEnd < #tokens and runEnd - index + 1 < MAX_SPACED_LETTERS
				and tokens[runEnd + 1].length == 1 and tokens[runEnd + 1].core:find("^%a$") do
				runEnd = runEnd + 1
			end
			local start = index
			while start <= runEnd - 2 do
				local matched
				for stop = runEnd, start + 2, -1 do
					local letters = {}
					for position = start, stop do letters[#letters + 1] = tokens[position].lower end
					if matchesWord(matcher, table.concat(letters)) then matched = stop break end
				end
				if matched then
					censor(tokens[start].first, tokens[matched].last)
					start = matched + 1
				else
					start = start + 1
				end
			end
			index = runEnd + 1
		else
			index = index + 1
		end
	end

	if #spans == 0 then return text end

	-- apply the spans, merging the ones that overlap
	table.sort(spans, function(a, b) return a[1] < b[1] end)
	local out, position = {}, 1
	local currentFirst, currentLast = spans[1][1], spans[1][2]
	local function flush()
		out[#out + 1] = text:sub(position, currentFirst - 1)
		out[#out + 1] = mask(text:sub(currentFirst, currentLast))
		position = currentLast + 1
	end
	for i = 2, #spans do
		if spans[i][1] <= currentLast then
			currentLast = math.max(currentLast, spans[i][2])
		else
			flush()
			currentFirst, currentLast = spans[i][1], spans[i][2]
		end
	end
	flush()
	out[#out + 1] = text:sub(position)
	return table.concat(out)
end

-- ---------------------------------------------------------------------------------------------------------------------
-- word lists and settings

--- Function used to read the word lists, returns the file contents or nil. Replaceable for testing.
M.readFile = function(path) return readFile(path) end

local function splitLines(contents)
	local lines = {}
	for line in (contents or ""):gmatch("[^\r\n]+") do lines[#lines + 1] = line end
	return lines
end

--- Parses the user's custom words: separated by commas, semicolons or new lines.
-- @tparam string custom
-- @treturn table array of entries
function M.parseCustomWords(custom)
	local entries = {}
	if type(custom) ~= "string" then return entries end
	for entry in custom:gmatch("[^,;\r\n]+") do
		entry = trim(entry)
		if entry ~= "" and #entry <= MAX_CUSTOM_ENTRY_LENGTH then
			entries[#entries + 1] = entry
			if #entries >= MAX_CUSTOM_ENTRIES then break end
		end
	end
	return entries
end

--- Reads the list of harmless words that must not be matched as a variation of a blocked word.
-- @treturn table array of words
function M.loadAllowed()
	local contents = M.readFile(ALLOWED_PATH)
	if not contents then
		log("E", "chatFilter", "Failed to read word list " .. ALLOWED_PATH)
		return {}
	end
	return splitLines(contents)
end

--- Reads the word list for a level.
-- @tparam number level 1 to 4
-- @treturn table array of entries
function M.loadLevel(level)
	local entries = {}
	local path = LIST_PATH:format(math.min(level, MAX_LEVEL))
	local contents = M.readFile(path)
	if contents then
		for _, line in ipairs(splitLines(contents)) do entries[#entries + 1] = line end
	else
		log("E", "chatFilter", "Failed to read word list " .. path)
	end
	return entries
end

local cachedLevel, cachedCustom, cachedMatcher

--- Gets the matcher for the given settings. It is rebuilt only when a setting changes.
-- @tparam[opt] number level 0 (or nil) is off, up to 4
-- @tparam[opt] string custom the user's custom words
-- @treturn table|nil the matcher, or nil when nothing needs filtering
function M.getMatcher(level, custom)
	level = math.floor(tonumber(level) or 0)
	if level < 0 then level = 0 end
	if level > MAX_LEVEL then level = MAX_LEVEL end
	if type(custom) ~= "string" then custom = "" end
	if level == 0 and custom:find("^%s*$") then return nil end

	if cachedMatcher and level == cachedLevel and custom == cachedCustom then return cachedMatcher end
	local entries = level > 0 and M.loadLevel(level) or {}
	for _, entry in ipairs(M.parseCustomWords(custom)) do entries[#entries + 1] = entry end
	cachedLevel, cachedCustom, cachedMatcher = level, custom, M.compile(entries, M.loadAllowed())
	return cachedMatcher
end

--- Filters text with the list for `level` plus the user's custom words.
-- @tparam string text
-- @tparam[opt] number level 0 (or nil) is off, up to 4
-- @tparam[opt] string custom the user's custom words
-- @treturn string the filtered text
function M.filter(text, level, custom)
	local matcher = M.getMatcher(level, custom)
	if not matcher then return text end
	return M.filterWith(matcher, text)
end

return M
