--// > BloodifyPreferences.lua < //--
--// ? all the settings used across the Bloodify plugin
--// ? select something that isn't the module to delete the module and save your preferences
--// ? don't worry if you delete some preferences in here, there are fallbacks for most, if not all of them

return {
	--// > NotificationService.lua < //--
	--// ? all the settings for the Notifications UI
	--// ! general settings
	notifPadding = 10, --// (num) | the distance in pixels between each notification (default: 10)
	maxNotificationWidth = 1200, --// (num) | the maximum width of the notifications (default: 1200)
	--// ! wiggle settings
	floatYMult = 3, --// (num) | the wiggle on the Y axis of the text (default: 3)
	floatXMult = 1, --// (num) | the wiggle on the X axis of the text (default: 1)
	floatRotMult = 12, --// (num) | the wiggle on the rotation of the text (default: 12)
	floatSpeed = 1, --// (num) | the multiplier of the wiggle speed on the text (default: 1)
	--// ! hover settings
	hoverRadius = 200, --// (num) | the radius of the mouse's hover area (default: 200)
	hoverMovePower = 8, --// (num) | the max amount of pixels a letter will move when hovered (default: 20)
	hoverScaleLimit = 1.15, --// (num) | the max scale of a letter when hovered (default: 1.15)
	bounceElasticity = 0.1, --// (num) | the elasticity of the bounce-back when unhovered (default: 0.1)
	bounceFriction = 0.85, --// (num) | the friction of the bounce-back when unhovered (default: 0.85)
	--// ! text settings
	textSuccessColor = Color3.fromRGB(85, 255, 127), --// (Color3) | the color of the notification success text (default: Color3.fromRGB(85, 255, 127))
	textFailColor = Color3.fromRGB(255, 85, 127), --// (Color3) | the color of the notification fail text (default: Color3.fromRGB(255, 85, 127))
	textFont = Enum.Font.BuilderSansExtraBold, --// (Color3) | the font of the notification text (default: Enum.Font.BuilderSansExtraBold)
	textSize = 26, --// (num) | the size of the notification text (default: 26)
	textSpeed = 0.02, --// (num) | the speed of the typewriter effect of the notification text (default: 0.02)
	textEndSpeed = 0.015, --// (num) | the speed of the typewriter effect of the notification text ending (default: 0.015)
	--// ! sound settings
	disableNotificationSounds = false, --// (bool) | if true, disables the sounds below (default: false)
	startSoundID = "122902269090596", --// (ID) | the ID of the sound that plays when a notification appears (default: 122902269090596)
	typeSoundID = "75801415132502", --// (ID) | the ID of the sound that plays when a letter appears in the notification (default: 75801415132502)
	endSoundID = "103829267136732", --// (ID) | the ID of the sound that plays when a letter appears in the notification (default: 103829267136732)

	--// ! stroke settings
	strokeColor = Color3.fromRGB(0, 0, 0), --// (Color3) | the color of the stroke on the text (default: Color3.fromRGB(0, 0, 0))

	--// > AccessoryService.lua < //--
	--// ? all the settings for the Accessory Converter
	--// ! weld settings
	useLegacyWeldParenting = false, --// (bool) | if true, will put the welds in a folder under Accessories/Hats instead of the accessory (default: false)
	useLegacyAccessoryWeld = false, --// (bool) | if true, the weld will be a normal Weld instead of a WeldConstraint. this means you cannot move the part or the weld breaks (default: false)
	--// ! accessory settings
	useLegacyAccessoryParenting = false, --// (bool) | if true, creates a single folder under the model itself for all accessories, similar to HDify (default: false)
	accessoryNamePrefix = "[Accessory]", --// (string) | the prefix that is put in front of the name of the accessory (default: "[Accessory]")
	accessoryRenderFidelity = Enum.RenderFidelity.Automatic, --// (enum) | the render fidelity of the Accessory Mesh (default: Enum.RenderFidelity.Automatic)
	accessoryCollisionFidelity = Enum.CollisionFidelity.Hull, --// (enum) | the collision fidelity of the Accessory Mesh (affects raycasts i think) (default: Enum.CollisionFidelity.Hull)
	accessoryCanQuery = false, --// (bool) | if true, keeps CanQuery enabled. not recommended for performance reasons (default: false)
	accessoryCanTouch = false, --// (bool) | if true, keeps CanTouch enabled. not recommended for performance reasons (default: false)
	accessorySoundCollision = false, --// (bool) | if true, keeps AudioCanCollide enabled. not recommended for performance reasons (default: false)
	accessoryFluidForces = false, --// (bool) | if true, keeps EnableFluidForces enabled. i don't even know what this does so just don't touch it ok? ok (default: false)

	--// > FaceService.lua < //--
	--// ? all the settings for the Face/Head Converter
	facePartName = "FacePart", --// (string) | the name that the facePart will use (default: "FacePart")
	faceMeshName = "HeadMesh", --// (string) | the name that the Specialmesh under FacePart will use (default: "HeadMesh")
	faceDecalName = "MainFaceDecal", --// (string) | the name that the face Decal under facePart will use (default: "MainFaceDecal")
	useLegacyFaceWeld = false, --// (bool) | if true, the weld will be a normal Weld instead of a WeldConstraint. this means you cannot move the part or the weld breaks (default: false)
	keepOldFace = false, --// (bool) | if true, the original face after the conversion will stay under a folder of the head. this is what HDify does also (default: false)
	
	--// > OutlineService.lua < //--
	--// ? all the settings for the extremely buggy Outline creator
	outlineScaleMultiplier = -1.075, --// (num) | the scale multiplier that is applied to the outline (default: -1.075)
	outlineColor = Color3.fromRGB(0, 0, 0), --// (Color3) | the color that is applied to the outline (default: Color3.fromRGB(0, 0, 0))
}
