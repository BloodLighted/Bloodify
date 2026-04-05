--// > AccessoryService.lua < //--
--// ! Made by BloodLight (@Heavenly_Strings)
--// ? Handles converting, coloring, naming, and welding accessories/hats
--!optimize 2
--!native
local AccessoryService = {}

--// > Services < //--
--// ? all services used in this service
local Selection = game:GetService("Selection") --// ? for getting current selection
local InsertService = game:GetService("InsertService") --// ? for inserting the meshpart
local ChangeHistoryService = game:GetService("ChangeHistoryService") --// ? so ctrl + z won't mangle the game

--// > Resources < //--
--// ? all the modules and assets used in this service
local NotificationService = require(script.Parent.NotificationService)
local Preferences = nil
local SESSION_CACHE = {} 

--// > Helpers < //--
--// ? helpers used in the service
local function bakeVertexColor(pColor, vVector) --// ? for baking the vertex color onto the color of the MeshPart
	return Color3.new(math.clamp(pColor.R * vVector.X, 0, 1), math.clamp(pColor.G * vVector.Y, 0, 1), math.clamp(pColor.B * vVector.Z, 0, 1))
end

function AccessoryService.Init(prefsTable) Preferences = prefsTable end --// ? init

--// > Main < //--
--// ? the main part of this service
function AccessoryService.ConvertAccessories()
	if not Preferences then error("{BloodifyPlugin} [!] // > AccessoryService not initialized! No Preferences ModuleScript. Did you modify the source code and remove it?") return end

	local startTime = os.clock() --// ? start time of conversion process
	local selected = Selection:Get() --// ? get current selection

	if #selected == 0 then 
		return NotificationService.Notify("No selection found! Did you do this to test?", false, "AccessoryService", 3) --// ? no selection found
	end

	local successCount = 0 --// ? count of successful conversions
	local failReasons, taskQueue, meshTemplates, uniqueMeshIds, folderCache, modelsToProcess = {}, {}, {}, {}, {}, {} --// ? tables for various things
	
	local recording = ChangeHistoryService:TryBeginRecording("ConvertAccessories") --// ? try to begin recording the changes
	if not recording then return end
	
	--// ? check if the selection is a model or a folder, if it's a model, add it to the models to process, if it's a folder, add all the models in the folder to process
	for _, obj in ipairs(selected) do --// ? add to process if model
		if obj:IsA("Model") then table.insert(modelsToProcess, obj)
		elseif obj:IsA("Folder") then --// ? add all descendants of folder to process if folder
			for _, desc in ipairs(obj:GetDescendants()) do if desc:IsA("Model") then table.insert(modelsToProcess, desc) end end
		else --// ? fail reason
			table.insert(failReasons, "[" .. obj.Name .. "]: Not a model/folder!")
		end
	end
	
	--// ? check if the model has accessories; if it does, add them to the task queue
	for _, model in ipairs(modelsToProcess) do
		local foundInModel = false
		for _, acc in ipairs(model:GetDescendants()) do
			if acc:IsA("Accessory") or acc:IsA("Hat") then --// ? if accessory
				local handle = acc:FindFirstChild("Handle") or acc:FindFirstChildOfClass("BasePart") --// ? handle of accessory
				local mesh = handle and handle:FindFirstChildOfClass("SpecialMesh") --// ? mesh of accessory

				if handle and mesh and mesh.MeshId ~= "" then --// ? if mesh is valid
					table.insert(taskQueue, {Acc = acc, Handle = handle, Mesh = mesh, Model = model}) --// ? insert into queue
					if not uniqueMeshIds[mesh.MeshId] then uniqueMeshIds[mesh.MeshId] = 0 end
					foundInModel = true
				else
					table.insert(failReasons, "[" .. acc.Name .. "]: Missing Mesh Data!") --// ? no mesh data
				end
			end
		end

		if not foundInModel and #selected == 1 then
			table.insert(failReasons, "[" .. model.Name .. "]: No valid accessories found!") --// ? no accessories
		end
	end

	local downloadsRequired, completedDownloads, toDownload = 0, 0, {}
	local masterThread = coroutine.running() --// ? main thread
	local renderFidelity = Preferences.accessoryRenderFidelity or Enum.RenderFidelity.Automatic --// ? render fidelity of meshes

	for meshId, _ in pairs(uniqueMeshIds) do
		if SESSION_CACHE[meshId] then MeshTemplates[meshId] = SESSION_CACHE[meshId]
		else table.insert(toDownload, meshId) end
	end
	
	--// ? create MeshPart and count it as a completed download
	downloadsRequired = #toDownload
	if downloadsRequired > 0 then
		for _, meshId in ipairs(toDownload) do --// ? meshes to download
			task.spawn(function()
				local success, part = pcall(function()
					return InsertService:CreateMeshPartAsync(meshId, (Preferences.collisionFidelity or Enum.CollisionFidelity.Hull), renderFidelity) end) --// ? creates meshpart

				if success and part then local masterCopy = part SESSION_CACHE[meshId], meshTemplates[meshId] = masterCopy, masterCopy end
				completedDownloads += 1 --// ? add +1 to completedDownloads
				if completedDownloads >= downloadsRequired then --// ? all meshes have been downloaded
					task.defer(masterThread)
				end
			end)
		end
		coroutine.yield() --// ? yield until all meshes have been downloaded
	end

	for _, data in ipairs(taskQueue) do --// ? start converting accessories
		local acc, handle, mesh = data.Acc, data.Handle, data.Mesh --// ? accessory data
		local template = meshTemplates[mesh.MeshId] --// ? get template

		if not template then table.insert(failReasons, "[" .. acc.Name .. "]: Mesh download failed!") continue end --// ? mesh download failed

		local weld = handle:FindFirstChildOfClass("Weld") or handle:FindFirstChild("AccessoryWeld") --// ? find weld
		local limb = weld and (weld.Part0 == handle and weld.Part1 or weld.Part0) --// ? limb of accessory

		if not limb or not limb:IsA("BasePart") then table.insert(failReasons, "[" .. acc.Name .. "]: No limb/basepart found to weld to!") continue end --// ? no proper limb found

		local targetParent = Preferences.useLegacyAccessoryParenting and data.Model or limb --// ? parent of Accessory
		local folderName = Preferences.useLegacyAccessoryParenting and "Accessories/Hats" or (limb.Name .. " | Accessories") --// ? folder name of Accessories
		local cacheKey = tostring(targetParent:GetDebugId()) .. folderName --// ? cache key for folder

		local folder = folderCache[cacheKey] or targetParent:FindFirstChild(folderName) --// ? folder of Accessories
		if not folder then
			folder = Instance.new("Folder")
			folder.Name, folder.Parent = folderName, targetParent
			folderCache[cacheKey] = folder
		end

		local accessoryPart = template:Clone() --// ? clone the template
		
		--// ? here for readability below
		local prefCanQuery, prefCanTouch, prefSoundCollision = Preferences.accessoryCanQuery or false, Preferences.accessoryCanTouch or false, Preferences.accessorySoundCollision or false
		
		local cleanName = acc.Name:gsub("^[Aa][Cc][Cc][Ee][Ss][Ss][Oo][Rr][Yy]", ""):gsub("[%s%(%)]", "") --// ? this looks weird but if it works it works i guess
		accessoryPart.Name = (Preferences.accessoryNamePrefix or "[Accessory]") .. " " .. cleanName --// ? cleaned-up name of Accessory
		accessoryPart.Color = bakeVertexColor(handle.Color, mesh.VertexColor) --// ? bakes the vertex color
		accessoryPart.Size *= mesh.Scale
		accessoryPart.TextureID = mesh.TextureId
		accessoryPart.CFrame = handle.CFrame
		accessoryPart.CanCollide, accessoryPart.CanQuery, accessoryPart.CanTouch, accessoryPart.AudioCanCollide = false, prefCanQuery, prefCanTouch, prefSoundCollision --// ? disable collisions
		accessoryPart.EnableFluidForces = Preferences.accessoryFluidForces or false --// ? genuinely not a clue what fluidforces is but it is probably not needed

		for _, child in ipairs(accessoryPart:GetChildren()) do
			if child:IsA("SpecialMesh") or child:IsA("Weld") or child:IsA("ManualWeld") then child:Destroy() end --// ? we don't need the specialmesh or welds anymore
		end
		
		--// ? welds
		local wc = Instance.new("WeldConstraint")
		wc.Part0, wc.Part1 = limb, accessoryPart --// ? welds limb to Accessory
		wc.Name = "Weld [".. limb.Name .."] >> [".. accessoryPart.Name .."]" --// ? [Head] >> [Accessory]

		if Preferences.useLegacyWeldParenting then --// ? carried from HDify
			local wf = folder:FindFirstChild("WeldFolder") or Instance.new("Folder")
			wf.Name, wf.Parent = "WeldFolder", folder
			wc.Parent = wf
		else
			wc.Parent = accessoryPart --// ? normal parenting
		end

		accessoryPart.Parent = folder --// ? parent new Accessory to folder
		acc:Destroy() --// ? destroy original Accessory
		successCount += 1 --// ? yay one Accessory done!!
	end

	local duration = os.clock() - startTime --// ? total time for all accessories converted
	local isSuccess = (successCount > 0) --// ? if there is atleast one accessory converted, then it is a success
	local resultMsg = ("Converted %d accessor(y/ies) in %.2fs (%.1fms)"):format(successCount, duration, duration * 1000)

	if #failReasons > 0 then resultMsg ..= "\nSkipped:\n" .. table.concat(failReasons, "\n") end --// ? skipped accessories/models
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit) --// ? doesn't even work btw
	NotificationService.Notify(resultMsg, isSuccess, "AccessoryService") --// ? notification
	return successCount
end
return AccessoryService
