--// > HeadService.lua < //--
--// ! Made by BloodLight (@Heavenly_Strings)
--// ! Converts the face to HD
--// this does require alot more comments tho ngl..
--!optimize 2
--!native
--!strict
local HeadService = {}

--// > Services < //--
--// ! all services used in this service
local Selection = game:GetService("Selection") --// for getting current selection
local ChangeHistoryService = game:GetService("ChangeHistoryService") --// to revert changes

--// > Resources < //--
--// ! all the modules and assets used in this service
local NotificationService = require(script.Parent.NotificationService) --// for notifications
local Preferences: any --// preferences

--// > Helpers < //--
--// ! helpers used in the service
function HeadService.Init(prefsTable: any) Preferences = prefsTable end --// init

--// > Main < //--
--// ! the main part of this service
function HeadService.ConvertHead(): number
	if not Preferences then --// no idea how this would even happen ngl unless it's a custom version of the plugin
		error("{ConvertPlus} [!] // > HeadService not initialized! No Preferences ModuleScript. Did you modify the source code and remove it?")
		return 0
	end

	local startTime: number = os.clock() --// start time of conversion process
	local selected: {Instance} = Selection:Get()

	if #selected == 0 then NotificationService.Notify("No selection found! Did you do this to test?", false, "HeadService", 3) return 0 end

	local successCount: number = 0
	local failReasons: {string}, modelsToProcess: {Model}, processedModels: {[Instance]: boolean} = {}, {}, {} --// tables for various things

	--// check if the selection is a model or a folder, if it's a model, add it to the models to process, if it's a folder, add all the models in the folder to process
	for _, obj in ipairs(selected) do
		if obj:IsA("Model") and not processedModels[obj] then --// add to process if model
			processedModels[obj] = true --// add to dictionary
			table.insert(modelsToProcess, obj) --// add to process
		elseif obj:IsA("Folder") then
			for _, desc in ipairs(obj:GetDescendants()) do if desc:IsA("Model") then --// add all descendants of folder to process if folder
					processedModels[desc] = true --// add to dictionary
					table.insert(modelsToProcess, desc) --// add to process
				end
			end
		else table.insert(failReasons, "[" .. obj.Name .. "]: Not a model/folder!") end --// fail reason
	end

	local recording = ChangeHistoryService:TryBeginRecording("ConvertHeads")
	if not recording then return 0 end

	--// check if the selection is a model
	for _, model: Model in ipairs(modelsToProcess) do
		if not model:IsA("Model") then table.insert(failReasons, model.Name .. ": Not a model!") continue end --// fail reason

		local head = model:FindFirstChild("Head") :: BasePart --// find head in model
		if not head or not head:IsA("BasePart") then table.insert(failReasons, model.Name .. ": No Head found or isn't BasePart!") continue end --// fail reason

		local currentFace = head:FindFirstChild("face") or head:FindFirstChild("Face") or head:FindFirstChildOfClass("Decal") --// original face decal

		if not currentFace then table.insert(failReasons, ("["..model.Name.."]: " .. "No face found!")) continue --// not found
		elseif not currentFace:IsA("Decal") then table.insert(failReasons, ("["..model.Name.."]: " .. "Face not a Decal!")) continue --// not a decal
		end

		local facePart = Instance.new("Part") --// part where the new face is under
		facePart.Name = Preferences.facePartName or "FacePart"
		facePart.Size, facePart.CFrame, facePart.Transparency = head.Size, head.CFrame, 1
		--// collisions
		facePart.CanCollide, facePart.CanQuery, facePart.CanTouch, facePart.AudioCanCollide, facePart.Anchored, facePart.EnableFluidForces = false, false, false, false, false, false

		local weld = Instance.new(if Preferences.useLegacyFaceWeld then "Weld" else "WeldConstraint") --// weld used to connect the head and the facepart
		weld.Name = ("Weld [%s] >> [%s]"):format(head.Name, facePart.Name)
		weld.Part0, weld.Part1 = head, facePart --// weld parts
		weld.Parent = facePart

		if weld:IsA("Weld") then weld.C0, weld.C1 = CFrame.new() , facePart.CFrame:ToObjectSpace(head.CFrame) end --// if legacy weld, use legacy weld vers of Part0/Part1

		local faceMesh = Instance.new("SpecialMesh") --// specialmesh for facePart
		local originalFaceMesh = head:FindFirstChildOfClass("SpecialMesh") :: SpecialMesh --// original specialmesh of Head (now shut up strict)

		local defaultScale = Vector3.new(1, 1, 1)
		local defaultType = Enum.MeshType.Head
		local defaultId = ""

		if originalFaceMesh then
			--// if we found a SpecialMesh, use its actual data
			faceMesh.MeshType = originalFaceMesh.MeshType
			faceMesh.MeshId = originalFaceMesh.MeshId
			faceMesh.Scale = originalFaceMesh.Scale * 1.001
		else
			--// if it's a MeshPart head, grab the ID from the Head itself
			if head:IsA("MeshPart") then
				faceMesh.MeshType = Enum.MeshType.FileMesh
				faceMesh.MeshId = head.MeshId
				faceMesh.Scale = defaultScale * 1.001
			else
				faceMesh.MeshType = defaultType
				faceMesh.Scale = defaultScale * 1.001
			end
		end

		faceMesh.Parent = facePart --// genuinely no idea why but i didn't have this in the last upd i'm so sorry

		local faceTextureToUse = currentFace.Texture --// fallback logic for face decal (because ugc heads are weird)
		if Preferences.meshTextureFallbackForFace and faceTextureToUse == "rbxasset://textures/face.png" then
			local fallbackTexture = ""

			if originalFaceMesh and originalFaceMesh.TextureId ~= "" then
				fallbackTexture = originalFaceMesh.TextureId
				originalFaceMesh.TextureId = ""
			elseif head:IsA("MeshPart") and head.TextureID ~= "" then
				fallbackTexture = head.TextureID
				head.TextureID = ""
			end

			--// only override if a valid fallback texture was actually found
			if fallbackTexture ~= "" then
				faceTextureToUse = fallbackTexture
			end
		end

		local mainFace = Instance.new("Decal") --// the face itself
		mainFace.Name = Preferences.faceDecalName or "MainFaceDecal"
		mainFace.Texture = faceTextureToUse
		mainFace.Parent = facePart

		if Preferences.keepOldFace then --// HDify feature
			local oldFaceFolder = (head:FindFirstChild("OldFace") or Instance.new("Folder")) :: Folder
			if oldFaceFolder.Parent ~= head then
				oldFaceFolder.Name = "OldFace"
				oldFaceFolder.Parent = head
			end currentFace.Parent = oldFaceFolder
		else currentFace.Parent = nil end --// used to be :Destroy() but same reason as AccessoryService

		facePart.Parent = head
		successCount += 1 --// yay one Head done!!
	end

	local duration: number = os.clock() - startTime --// total time for all Heads converted
	local isSuccess: boolean = (successCount > 0) --// if there is atleast one Head converted, then it is a success
	local resultMsg: string = ("Converted %d face(s) in %.2fs (%.1fms)"):format(successCount, duration, duration * 1000)

	if #failReasons > 0 then resultMsg ..= "\nSkipped:\n" .. table.concat(failReasons, "\n") end --// skipped heads/models
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit) --// finish recording
	NotificationService.Notify(resultMsg, isSuccess, "HeadService") --// final notification
	return successCount
end

return HeadService
