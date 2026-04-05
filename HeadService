--// > HeadService.lua < //--
--// ! Made by BloodLight (@Heavenly_Strings)
--// ? Converts the face to HD
--// ? this does require alot more comments tho ngl..
--!optimize 2
--!native
local HeadService = {}

--// > Services < //--
local Selection = game:GetService("Selection")

--// > Resources < //--
local NotificationService = require(script.Parent.NotificationService)
local Preferences = nil
local FACE_SCALE = Vector3.new(1.25, 1.25, 1.25)

--// > Helpers < //--
function HeadService.Init(prefsTable)
	Preferences = prefsTable
end

--// > Main < //--
function HeadService.ConvertHead()
	if not Preferences then error("{BloodifyPlugin} [!] // > HeadService not initialized! No Preferences ModuleScript. Did you modify the source code and remove it?") return end

	local startTime = os.clock()
	local selected = Selection:Get()

	if #selected == 0 then
		return NotificationService.Notify("No selection found! Did you do this to test?", false, "HeadService", 3)
	end

	local successCount = 0
	local failReasons = {}

	for _, model in ipairs(selected) do
		if not model:IsA("Model") then
			table.insert(failReasons, model.Name .. ": Not a model!")
			continue
		end

		local head = model:FindFirstChild("Head")
		if not head then
			table.insert(failReasons, model.Name .. ": No Head found!")
			continue
		end

		local currentFace = head:FindFirstChild("face") or head:FindFirstChild("Face") or head:FindFirstChildOfClass("Decal")

		if not currentFace then
			table.insert(failReasons, ("["..model.Name.."]: " .. "No face found!"))
			continue
		elseif not currentFace:IsA("Decal") then
			table.insert(failReasons, ("["..model.Name.."]: " .. "Face not a Decal!"))
			continue
		end

		local facePart = Instance.new("Part")
		facePart.Name = Preferences.facePartName or "FacePart"
		facePart.Size = head.Size
		facePart.CFrame = head.CFrame
		facePart.Transparency = 1
		facePart.CanCollide = false
		facePart.CanQuery = false
		facePart.CanTouch = false
		facePart.AudioCanCollide = false
		facePart.Anchored = false

		local weld = Instance.new(if Preferences.useLegacyFaceWeld then "Weld" else "WeldConstraint")
		weld.Name = ("Weld [%s] >> [%s]"):format(head.Name, facePart.Name)
		weld.Part0 = head
		weld.Part1 = facePart
		weld.Parent = facePart

		if weld:IsA("Weld") then
			weld.C0 = CFrame.new() 
			weld.C1 = facePart.CFrame:ToObjectSpace(head.CFrame)
		end

		local faceMesh = Instance.new("SpecialMesh")
		faceMesh.MeshType = Enum.MeshType.Head
		faceMesh.Name = Preferences.faceMeshName or "HeadMesh"
		faceMesh.Scale = FACE_SCALE
		faceMesh.Parent = facePart

		local mainFace = Instance.new("Decal")
		mainFace.Name = Preferences.faceDecalName or "MainFaceDecal"
		mainFace.Texture = currentFace.Texture
		mainFace.Parent = facePart

		if Preferences.keepOldFace then
			local oldFaceFolder = head:FindFirstChild("OldFace") or Instance.new("Folder")
			if oldFaceFolder.Parent ~= head then
				oldFaceFolder.Name = "OldFace"
				oldFaceFolder.Parent = head
			end
			currentFace.Parent = oldFaceFolder
		else
			currentFace:Destroy()
		end

		facePart.Parent = head
		successCount += 1
	end

	local duration = os.clock() - startTime
	local isSuccess = (successCount > 0)
	local resultMsg = ("Converted %d face(s) in %.2fs (%.1fms)"):format(successCount, duration, duration * 1000)

	if #failReasons > 0 then
		resultMsg ..= "\nSkipped:\n" .. table.concat(failReasons, "\n")
	end

	NotificationService.Notify(resultMsg, isSuccess, "HeadService", 6)
	return successCount
end

return HeadService
