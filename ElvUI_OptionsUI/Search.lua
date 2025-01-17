local E, _, V, P, G = unpack(ElvUI)
local C, L = unpack(E.OptionsUI)
local ACH = E.Libs.ACH
local SearchText = ''

local gsub = gsub
local wipe = wipe
local next = next
local type = type
local pcall = pcall
local pairs = pairs
local format = format
local gmatch = gmatch
local strtrim = strtrim
local strfind = strfind
local strjoin = strjoin
local strlower = strlower
local strmatch = strmatch
local strsplit = strsplit

E.Options.args.search = ACH:Group(format('%s%s|r', E.media.hexvaluecolor, L["Search"]), nil, 4)

local Search =  E.Options.args.search.args
local EditBox = ACH:Input(L["Search"], nil, 0, nil, 1.5, function() return SearchText end, function(_, value) C:Search_ClearResults() if strmatch(value, '%S+') then SearchText = strtrim(strlower(value)) C:Search_Config() C:Search_AddResults() end end)
Search.editbox = EditBox

local start = 100
local depth = start + 2
local inline = depth - 1
local results, entries = {}, {}
local sep = ' |cFF888888>|r '

local searchCache = {}
local blockOption = {
	filters = true,
	info = true,
	plugins = true,
	search = true,
	tagGroup = true,
	modulecontrol = true,
	profiles = true
}

local typeInvalid = {
	description = true,
	header = true
}

local typeValue = {
	multiselect = true,
	select = true,
}

local nameIndex = {
	[L["General"]] = 1,
	[L["Global"]] = 0
}

function C:Search_DisplayResults(groups, section)
	if groups.entries then
		groups.entries.section = section
	end

	local index = groups.index or start
	groups.index = nil

	for name, group in pairs(groups) do
		if name ~= 'entries' then
			local sub = ACH:Group(name, nil, nameIndex[name] or index, 'tab')
			sub.inline = index == inline
			section[name] = sub

			C:Search_DisplayResults(group, sub.args)
		end
	end

	if groups.entries then
		C:Search_DisplayButtons(groups.entries)
	end
end

function C:Search_ButtonFunc()
	if self.option then
		E.Libs.AceConfigDialog:SelectGroup('ElvUI', strsplit(',', self.option.location))
	end
end

function C:Search_DisplayButtons(buttons)
	local section = buttons.section
	buttons.section = nil

	for _, data in next, buttons do
		local button = ACH:Execute(data.clean, nil, nil, C.Search_ButtonFunc, nil, nil, 1.5)
		button.location = data.location
		section[data.name] = button
	end
end

function C:Search_AddResults()
	wipe(results)
	wipe(entries)

	for location, name in pairs(searchCache) do
		local group, index, clean = results, start, name
		for groupName in gmatch(name, '(.-)'..sep) do
			if index > depth then break end

			-- button name
			clean = gsub(clean, '^' .. E:EscapeString(groupName) .. sep, '')

			-- sub groups
			if not group[groupName] then group[groupName] = { index = index } end
			group = group[groupName]

			index = index + 1
		end

		-- sub buttons
		local count, entry = (entries.count or 0) + 1, { name = name, clean = clean, location = location }
		entries.count, entries[count] = count, entry

		-- linking
		if not group.entries then group.entries = {} end
		group.entries[count] = entry
	end

	C:Search_DisplayResults(results, Search)
end

function C:Search_ClearResults()
	wipe(searchCache)
	wipe(Search)

	Search.editbox = EditBox
	SearchText = ''
end

function C:Search_FindText(text)
	return strfind(strlower(text and E:StripString(text) or '\a'), SearchText, nil, true)
end

function C:Search_GetReturn(value, ...)
	if type(value) == 'function' then
		local success, arg1 = pcall(value, ...)
		if success then
			return arg1
		end
	else
		return value
	end
end

function C:Search_Config(tbl, loc, locName)
	if SearchText == '' then return end

	for option, infoTable in pairs(tbl or E.Options.args) do
		if not (blockOption[option] or infoTable.hidden or typeInvalid[infoTable.type]) then
			local location, locationName = loc and (infoTable.type == 'group' and not infoTable.inline and strjoin(',', loc, option) or loc) or option
			local name = C:Search_GetReturn(infoTable.name, option)
			if type(name) == 'string' then -- bad apples
				locationName = locName and (strmatch(name, '%S+') and strjoin(sep, locName, name) or locName) or name
				if C:Search_FindText(name) then
					searchCache[location] = locationName
				else
					local values = (typeValue[infoTable.type] and not infoTable.dialogControl) and C:Search_GetReturn(infoTable.values, option)
					if values then
						for _, subName in next, values do
							if type(subName) == 'string' and C:Search_FindText(subName) then
								searchCache[location] = locationName
								break -- only need one
							end
						end
					end
				end
			end

			-- process objects (sometimes without a locationName)
			if type(infoTable) == 'table' and infoTable.args then
				C:Search_Config(infoTable.args, location, locationName)
			end
		end
	end
end
