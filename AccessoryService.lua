--// > AccessoryService.lua < //--
--// ! Made by BloodLight (@Heavenly_Strings)
--// ? Handles converting, coloring, naming, and welding accessories/hats
--!optimize 2
--!native
--!strict
local AccessoryService = {}

--// > Services < //--
--// ? all services used in this service
local Selection = game:GetService("Selection") --// ? for getting current selection
local InsertService = game:GetService("InsertService") --// ? for inserting the meshpart
local ChangeHistoryService = game:GetService("ChangeHistoryService") --// ? so ctrl + z won't mangle the accessories

--// > Resources < //--
--// ? all the modules and assets used in this service
local NotificationService = require(script.Parent.NotificationService)
local Preferences: any --// ? preferences
local sessionCache: {[string]: MeshPart} = {} --// ? store meshes in current session

--// > Helpers < //--
--// ? helpers used in the service
local function bakeVertexColor(pColor: Color3, vVector: Vector3): Color3 --// ? for baking the vertex color onto the color of the MeshPart
	return Color3.new(math.clamp(pColor.R * vVector.X, 0, 1), math.clamp(pColor.G * vVector.Y, 0, 1), math.clamp(pColor.B * vVector.Z, 0, 1))
end

function AccessoryService.Init(prefsTable: any) Preferences = prefsTable end --// ? init

--// > Main < //--
--// ? the main part of this service
function AccessoryService.ConvertAccessories(): number
	if not Preferences then error("{BloodifyPlugin} [!] // > AccessoryService not initialized! No Preferences ModuleScript. Did you modify the source code and remove it?") return 0 end

	local startTime: number, selected: {Instance} = os.clock(), Selection:Get() --// ? start time of conversion process, aswell as current selection

	if #selected == 0 then NotificationService.Notify("No selection found! Did you do this to test?", false, "AccessoryService", 3) return 0 end --// ? no selection found

	local successCount: number = 0 --// ? count of successful conversions
	local failReasons: {string} = {} --// ? list of reasons for failed conversions
	local taskQueue: {any} = {} --// ? queue of tasks to be performed
	local meshTemplates: {[string]: MeshPart} = {} --// ? store meshes for reuse
	local uniqueMeshIds: {[string]: number} = {} --// ? store unique meshes for reuse
	local folderCache: {[Instance]: {[string]: Folder}} = {} --// ? store folders for reuse
	local modelsToProcess: {Model} = {} --// ? store models to process
	local processedModels: {[Instance]: boolean} = {} --// ? store processed models for reuse
	
	--// ? check if the selection is a model or a folder, if it's a model, add it to the models to process, if it's a folder, add all the models in the folder to process
	local processedModels: {[Instance]: boolean} = {} --// ? dictionary to prevent duplicate processing (like if a user selects a model under a folder and selects said folder also)
	for _, obj in ipairs(selected) do --// ? add to process if model
		if obj:IsA("Model") and not processedModels[obj] then
			processedModels[obj] = true --// ? add to dictionary
			table.insert(modelsToProcess, obj) --// ? add to process
		elseif obj:IsA("Folder") then --// ? add all descendants of folder to process if folder
			for _, desc in ipairs(obj:GetDescendants()) do if desc:IsA("Model") then
					processedModels[desc] = true --// ? add to dictionary
					table.insert(modelsToProcess, desc) --// ? add to process
				end
			end
		else table.insert(failReasons, "[" .. obj.Name .. "]: Not a model/folder!") end --// ? fail reason
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

	local toDownload: {string} = {}


	for meshId, _ in pairs(uniqueMeshIds) do
		if sessionCache[meshId] then meshTemplates[meshId] = sessionCache[meshId]
		else table.insert(toDownload, meshId) end
	end
	
	--// ? create MeshPart and count it as a completed download
	if #toDownload > 0 then
		local completedDownloads = 0 --// ? number of completed downloads
		local masterThread = coroutine.running() --// ? main thread
		local renderFidelity = Preferences.accessoryRenderFidelity or Enum.RenderFidelity.Automatic --// ? render fidelity of meshes
		local collisionFidelity = Preferences.accessoryCollisionFidelity or Enum.CollisionFidelity.Hull --// ? collision fidelity of meshes
		for _, meshId in ipairs(toDownload) do --// ? meshes to download
			task.spawn(function()
				local success, part = pcall(function()
					return InsertService:CreateMeshPartAsync(meshId, collisionFidelity, renderFidelity) end) --// ? creates meshpart

				if success and part then 
					for _, child in part:GetChildren() do
						if child:IsA("SpecialMesh") or child:IsA("Weld") or child:IsA("AccessoryWeld") then child.Parent = nil end --// ? parent to nil
					end
					sessionCache[meshId] = part meshTemplates[meshId] = part end
				completedDownloads += 1 --// ? add +1 to completedDownloads
				if completedDownloads >= #toDownload then task.defer(masterThread) end --// ? all meshes have been downloaded
			end)
		end
		coroutine.yield() --// ? yield until all meshes have been downloaded
	end
	
	local recording = ChangeHistoryService:TryBeginRecording("ConvertAccessories") --// ? try to begin recording the changes
	if not recording then return 0 end
	
	local prefCanQuery = Preferences.accessoryCanQuery or false --// ? canquery preference
	local prefCanTouch = Preferences.accessoryCanTouch or false --// ? cantouch preference
	local prefSoundCollision = Preferences.accessorySoundCollision or false --// ? soundcollision preference
	local prefFluidForces = Preferences.accessoryFluidForces or false --// ? fluidforces preference
	local prefix = Preferences.accessoryNamePrefix or "[Accessory]" --// ? prefix

	for _, data in ipairs(taskQueue) do --// ? start converting accessories
		local acc: Accessory, handle: BasePart, mesh: SpecialMesh = data.Acc, data.Handle, data.Mesh --// ? accessory data
		local template = meshTemplates[mesh.MeshId] --// ? get template

		if not template then table.insert(failReasons, "[" .. acc.Name .. "]: Mesh download failed!") continue end --// ? mesh download failed

		local weldbutnotreally = handle:FindFirstChildOfClass("Weld") or handle:FindFirstChild("AccessoryWeld") --// ? find weld
		local limb: BasePart?
		if weldbutnotreally and (weldbutnotreally:IsA("Weld") or weldbutnotreally:IsA("ManualWeld")) then
			local weld = weldbutnotreally :: Weld --// ? just so it shuts up
			limb = (weld.Part0 == handle and weld.Part1 or weld.Part0) :: BasePart --// ? limb of accessory
		end

		if not limb or not limb:IsA("BasePart") then table.insert(failReasons, "[" .. acc.Name .. "]: No limb/basepart found to weld to!") continue end --// ? no proper limb found

		local targetParent = Preferences.useLegacyAccessoryParenting and data.Model or limb --// ? parent of Accessory
		local folderName = Preferences.useLegacyAccessoryParenting and "Accessories/Hats" or (limb.Name .. " | Accessories") --// ? folder name of Accessories
		local parentCache = folderCache[targetParent]
		if not parentCache then
			parentCache = {}
			folderCache[targetParent] = parentCache
		end
		
		if not folderCache[targetParent] then folderCache[targetParent] = {} end
		
		local folder: Folder --// ? folder of Accessories
		local cachedFolder = parentCache[folderName]
		if cachedFolder then folder = cachedFolder
		else
	local foundFolder = targetParent:FindFirstChild(folderName)
	if foundFolder and foundFolder:IsA("Folder") then folder = foundFolder
	else
		folder = Instance.new("Folder")
		folder.Name = folderName
		folder.Parent = targetParent
	end parentCache[folderName] = folder end

		local accessoryPart = template:Clone() --// ? clone the template
		
		local cleanName = acc.Name:gsub("^[Aa][Cc][Cc][Ee][Ss][Ss][Oo][Rr][Yy]", ""):gsub("[%s%(%)]", "") --// ? this looks weird but if it works it works i guess
		accessoryPart.Name = (Preferences.accessoryNamePrefix or "[Accessory]") .. " " .. cleanName --// ? cleaned-up name of Accessory
		accessoryPart.Color = bakeVertexColor(handle.Color, mesh.VertexColor) --// ? bakes the vertex color
		accessoryPart.Size *= mesh.Scale
		accessoryPart.TextureID, accessoryPart.CFrame = mesh.TextureId, handle.CFrame
		accessoryPart.CanCollide, accessoryPart.CanQuery, accessoryPart.CanTouch, accessoryPart.AudioCanCollide = false, prefCanQuery, prefCanTouch, prefSoundCollision --// ? disable collisions
		accessoryPart.EnableFluidForces = Preferences.accessoryFluidForces or false --// ? genuinely not a clue what fluidforces is but it is probably not needed
		
		--// ? welds
		local wc = Instance.new("WeldConstraint")
		wc.Part0, wc.Part1 = limb, accessoryPart --// ? welds limb to Accessory
		wc.Name = "Weld [".. limb.Name .."] >> [".. accessoryPart.Name .."]" --// ? [Head] >> [Accessory]

		if Preferences.useLegacyWeldParenting then
			local wf: Folder
			local existingWf = folder:FindFirstChild("WeldFolder")

			if existingWf and existingWf:IsA("Folder") then wf = existingWf
			else
				wf = Instance.new("Folder")
				wf.Name = "WeldFolder"
				wf.Parent = folder
			end wc.Parent = wf
		else wc.Parent = accessoryPart end

		accessoryPart.Parent = folder --// ? parent new Accessory to folder
		acc.Parent = nil --// ? used to be :Destroy(), but ChangeHistoryService was not very happy with that. at all
		successCount += 1 --// ? yay one Accessory done!!
	end

	local duration: number = os.clock() - startTime --// ? total time for all accessories converted
	local isSuccess: boolean = (successCount > 0) --// ? if there is atleast one accessory converted, then it is a success
	local resultMsg: string = ("Converted %d accessor(y/ies) in %.2fs (%.1fms)"):format(successCount, duration, duration * 1000)

	if #failReasons > 0 then resultMsg ..= "\nSkipped:\n" .. table.concat(failReasons, "\n") end --// ? skipped accessories/models
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit) --// ? finish recording
	NotificationService.Notify(resultMsg, isSuccess, "AccessoryService") --// ? notification
	return successCount
end
return AccessoryService
