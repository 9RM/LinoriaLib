local httpService = game:GetService('HttpService')

local IDManager = {} do
	IDManager.Folder = 'LinoriaLibSettings'
	IDManager.Ignore = {}
	IDManager.Parser = {
		Toggle = {
			Save = function(idx, object) 
				return { type = 'Toggle', idx = idx, value = object.Value } 
			end,
			Load = function(idx, data)
				if Toggles[idx] then 
					Toggles[idx]:SetValue(data.value)
				end
			end,
		},
		Slider = {
			Save = function(idx, object)
				return { type = 'Slider', idx = idx, value = tostring(object.Value) }
			end,
			Load = function(idx, data)
				if Options[idx] then 
					Options[idx]:SetValue(data.value)
				end
			end,
		},
		Dropdown = {
			Save = function(idx, object)
				return { type = 'Dropdown', idx = idx, value = object.Value, mutli = object.Multi }
			end,
			Load = function(idx, data)
				if Options[idx] then 
					Options[idx]:SetValue(data.value)
				end
			end,
		},
		ColorPicker = {
			Save = function(idx, object)
				return { type = 'ColorPicker', idx = idx, value = object.Value:ToHex() }
			end,
			Load = function(idx, data)
				if Options[idx] then 
					Options[idx]:SetValueRGB(Color3.fromHex(data.value))
				end
			end,
		},
		KeyPicker = {
			Save = function(idx, object)
				return { type = 'KeyPicker', idx = idx, mode = object.Mode, key = object.Value }
			end,
			Load = function(idx, data)
				if Options[idx] then 
					Options[idx]:SetValue({ data.key, data.mode })
				end
			end,
		},

		Input = {
			Save = function(idx, object)
				return { type = 'Input', idx = idx, text = object.Value }
			end,
			Load = function(idx, data)
				if Options[idx] and type(data.text) == 'string' then
					Options[idx]:SetValue(data.text)
				end
			end,
		},
	}

	function IDManager:SetIgnoreIndexes(list)
		for _, key in next, list do
			self.Ignore[key] = true
		end
	end

	function IDManager:SetFolder(folder)
		self.Folder = folder;
		self:BuildFolderTree()
	end

	function IDManager:Save(name)
		local fullPath = self.Folder .. '/logged-IDs/' .. name .. '.json'

		local data = {
			objects = {}
		}

		for idx, toggle in next, Toggles do
			if self.Ignore[idx] then continue end

			table.insert(data.objects, self.Parser[toggle.Type].Save(idx, toggle))
		end

		for idx, option in next, Options do
			if not self.Parser[option.Type] then continue end
			if self.Ignore[idx] then continue end

			table.insert(data.objects, self.Parser[option.Type].Save(idx, option))
		end	

		local success, encoded = pcall(httpService.JSONEncode, httpService, data)
		if not success then
			return false, 'failed to encode data'
		end

		writefile(fullPath, encoded)
		return true
	end

	function IDManager:Load(name)
		local file = self.Folder .. '/logged-IDs/' .. name .. '.json'
		if not isfile(file) then return false, 'invalid file' end

		local success, decoded = pcall(httpService.JSONDecode, httpService, readfile(file))
		if not success then return false, 'decode error' end

		for _, option in next, decoded.objects do
			if self.Parser[option.type] then
				self.Parser[option.type].Load(option.idx, option)
			end
		end

		return true
	end

	function IDManager:IgnoreThemeSettings()
		self:SetIgnoreIndexes({ 
			"BackgroundColor", "MainColor", "AccentColor", "OutlineColor", "FontColor", -- themes
			"ThemeManager_ThemeList", 'ThemeManager_CustomThemeList', 'ThemeManager_CustomThemeName', -- themes
		})
	end

	function IDManager:BuildFolderTree()
		local paths = {
			self.Folder,
			self.Folder .. '/themes',
			self.Folder .. '/settings',
			self.Folder .. '/logged-IDs'
		}

		for i = 1, #paths do
			local str = paths[i]
			if not isfolder(str) then
				makefolder(str)
			end
		end
	end

	function IDManager:RefreshConfigList()
		local list = listfiles(self.Folder .. '/logged-IDs')

		local out = {}
		for i = 1, #list do
			local file = list[i]
			if file:sub(-5) == '.json' then
				-- i hate this but it has to be done ...

				local pos = file:find('.json', 1, true)
				local start = pos

				local char = file:sub(pos, pos)
				while char ~= '/' and char ~= '\\' and char ~= '' do
					pos = pos - 1
					char = file:sub(pos, pos)
				end

				if char == '/' or char == '\\' then
					table.insert(out, file:sub(pos + 1, start - 1))
				end
			end
		end
		
		return out
	end

	function IDManager:SetLibrary(library)
		self.Library = library
	end

	function IDManager:LoadAutoloadConfig()
		if isfile(self.Folder .. '/logged-IDs/autoload.txt') then
			local name = readfile(self.Folder .. '/logged-IDs/autoload.txt')

			local success, err = self:Load(name)
			if not success then
				return self.Library:Notify('Failed to load autoload config: ' .. err)
			end

			self.Library:Notify(string.format('Auto loaded config %q', name))
		end
	end


	function IDManager:BuildConfigSection(tab)
		assert(self.Library, 'Must set IDManager.Library')

		local section = tab:AddRightGroupbox('Configuration')

		section:AddDropdown('IDManager_ConfigList', { Text = 'ID list', Values = self:RefreshConfigList(), AllowNull = true })
		section:AddInput('IDManager_ConfigName',    { Text = 'ID name' })

		section:AddDivider()

		section:AddButton('Save ID', function()
			local name = Options.IDManager_ConfigName.Value

			if name:gsub(' ', '') == '' then 
				return self.Library:Notify('Invalid ID name (empty)', 2)
			end

			local success, err = self:Save(name)
			if not success then
				return self.Library:Notify('Failed to save ID: ' .. err)
			end

			self.Library:Notify(string.format('Saved ID %q', name))

			Options.IDManager_ConfigList.Values = self:RefreshConfigList()
			Options.IDManager_ConfigList:SetValues()
			Options.IDManager_ConfigList:SetValue(nil)
		end):AddButton('Load ID', function()
			local name = Options.IDManager_ConfigList.Value

			local success, err = self:Load(name)
			if not success then
				return self.Library:Notify('Failed to load ID: ' .. err)
			end

			self.Library:Notify(string.format('Loaded config %q', name))
		end)

		section:AddButton('Overwrite config', function()
			local name = Options.IDManager_ConfigList.Value

			local success, err = self:Save(name)
			if not success then
				return self.Library:Notify('Failed to overwrite ID: ' .. err)
			end

			self.Library:Notify(string.format('Overwrote ID %q', name))
		end)
		

		section:AddButton('Refresh ID list', function()
			Options.IDManager_ConfigList.Values = self:RefreshConfigList()
			Options.IDManager_ConfigList:SetValues()
			Options.IDManager_ConfigList:SetValue(nil)
		end)

		IDManager:SetIgnoreIndexes({ 'IDManager_ConfigList', 'IDManager_ConfigName' })
	end

	IDManager:BuildFolderTree()
end

return IDManager
