--// > ConvertPlus | An HDify Fork < //--
--// ! Version: V1.2.1 | Last Updated: 3/21/26 | Made by BloodLight (@Heavenly_Strings on Roblox)
--// the main purpose of the plugin is to convert Accessories to be much better and less partcount-intensive in heavy games
--// devforum: https://devforum.roblox.com/t/convertplus-an-optimized-accessory-and-face-converter-v120
--[[// | TODO: 
previous todo was repurposed into a diff plugin that may or may not release
make converting into meshparts in AccessoryService optional via Preferences | next upd
figure out a way to make new keys/values be automatically added to Preferences | unsure if possible
//]]
--!optimize 2
--!native
--!strict

--// > Services < //--
--// ! all the services used in the plugin
local Selection = game:GetService("Selection") --// used for current selection, for Preferences
local RunService = game:GetService("RunService") --// used for :IsStudio()
local ServerStorage = game:GetService("ServerStorage") --// used for storing Preferences temporarily
local ScriptEditorService = game:GetService("ScriptEditorService") --// used for opening Preferences

--// > Resources < //--
--// ! all the modules and assets used in the plugin
local Modules = script:WaitForChild("Modules")
local Preferences = require(Modules:WaitForChild("ConvertPlusPreferences") :: any) :: {[string]: any} --// all settings/preferences for the plugin
local AccService = require(Modules.AccessoryService) --// handles accessories
local HeadService = require(Modules.HeadService) --// handles faces
local NotificationService = require(Modules.NotificationService) --// handles notifications

--// > Functions < //--
--// ! functions used for Preferences
--// convert other types to strings for SetSetting
local function Serialize(val: any): any
	if typeof(val) == "Color3" then return "COLOR3:" .. val:ToHex()
	elseif typeof(val) == "EnumItem" then return "ENUM:" .. tostring(val) end return val
end

--// convert string values to their original types
local function Deserialize(val: any): any
	if type(val) == "string" then
		if val:find("COLOR3:") then return Color3.fromHex((val:gsub("COLOR3:", "")))
		elseif val:find("ENUM:") then
			local path = val:gsub("ENUM:", "")
			local parts = path:split(".") --// expecting: ["Enum", "Font", "BuilderSansExtraBold"]
			if #parts >= 3 then local success, enumObj = pcall(function() return Enum[parts[2]][parts[3]] end)
				return success and enumObj or val
			end
		end
	end return val end

--// save the preferences
local function SavePreferences(newPrefsTable: {[string]: any}, rawSource: string?)
	for key, value in pairs(newPrefsTable) do local safeValue = Serialize(value) plugin:SetSetting(key, safeValue) Preferences[key] = value end
	if rawSource then plugin:SetSetting("SavedRawSource", rawSource) end
end

--// load the preferences
local function LoadPreferences()
	for key, defaultValue in pairs(Preferences) do local savedValue = plugin:GetSetting(key)
		if savedValue ~= nil then Preferences[key] = Deserialize(savedValue) end
	end
end
LoadPreferences()

--// > Init < //--
--// ! handles the initialization of the modules for Preferences, aswell as check if the plugin is the latest ver
AccService.Init(Preferences) HeadService.Init(Preferences) NotificationService.Init(plugin, Preferences)

--// > Toolbar < //--
--// ! handles the creation of the toolbar icons
local toolbar = plugin:CreateToolbar("ConvertPlus | An HDify Fork")
local accessoryButton = toolbar:CreateButton("Accessories", "Makes Accessories HD and optimizes them", "rbxassetid://136990043927364", "Accessories")
local headButton = toolbar:CreateButton("Head", "Makes the face HD* (if decal itself is HD originally)", "rbxassetid://109758820965979", "Head")
local preferencesButton = toolbar:CreateButton("Preferences", "All the settings across the plugin", "rbxassetid://123923917372564", "Preferences/Settings")

--// > Connections < //--
--// ! the connections of the toolbar icons
accessoryButton.Click:Connect(function() AccService.ConvertAccessories() end) headButton.Click:Connect(function() HeadService.ConvertHead() end)

local selectionConnection: RBXScriptConnection? = nil
preferencesButton.Click:Connect(function()
	if selectionConnection then return end
	local prefScript = ServerStorage:FindFirstChild("ConvertPlusPreferences")

	if not prefScript then prefScript = Modules.ConvertPlusPreferences:Clone()
		local savedSource = plugin:GetSetting("SavedRawSource")
		if savedSource then prefScript.Source = savedSource end
		prefScript.Parent = ServerStorage
	end
	
	--// selects and opens the module
	Selection:Set({prefScript}) ScriptEditorService:OpenScriptDocumentAsync(prefScript)

	selectionConnection = Selection.SelectionChanged:Connect(function()
		local currentSelection = Selection:Get()

		--// check if the selection is empty or the first item is not the script
		if #currentSelection == 0 or currentSelection[1] ~= prefScript then
			if selectionConnection then selectionConnection:Disconnect() selectionConnection = nil end
			
			if not prefScript then return end
			
			--// save before deleting
			local code = (prefScript :: ModuleScript).Source
			--// 1. | Load the chunk first
			local chunk, compileError = loadstring(code)

			--// 2. | Check if it actually loaded due to strict
			if not chunk then warn("{ConvertPlus} [Error] [!] // > Syntax Error in Preferences: " .. tostring(compileError)) return end

			--// 3. | Execute the chunk
			local success, result = pcall(chunk)

			if success and type(result) == "table" then
				if type(result) == "table" then
					--// success, save
					SavePreferences(result, code) NotificationService.Notify("Preferences Saved & Cleaned Up! ^_^", true, "System", 6)
				else
					--// if the result isn't a table, mainly if the entire table got deleted or something similar
					NotificationService.Notify("Save Failed: Script must return a table. :c", false, "System", 7)
				end
			elseif game:GetService("RunService"):IsStudio() and game:GetService("RunService"):IsRunning() then
				--// cannot save if in studio playtest
				NotificationService.Notify("Save Failed: Cannot save during Playtest. :c", false, "System", 7)
			elseif not success and result:find("setv") or result:find("getv") then
				--// if the result contains getv or setv
				NotificationService.Notify("Save Failed: Restricted global variable used. :c", false, "System", 7)
			else
				--// shows the lua error as a last resort
				warn("{ConvertPlus} [Error] [!] // > " .. tostring(result))
				NotificationService.Notify("Save Failed: " .. tostring(result), false, "System", 14)
			end

			--// cleanup
			prefScript:Destroy()
		end
	end)
end)
