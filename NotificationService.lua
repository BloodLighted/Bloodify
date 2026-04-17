--// > NotificationService.lua < //--
--// ! Made by BloodLight (@Heavenly_Strings)
--// Handles all the notifications, mainly for debugging and general use
--!strict
--!optimize 2
--!native

--// > Types < //--
--// ! general types used in this service (not commenting this i'm too lazy)
export type Preferences = {
	startSoundID: number?, typeSoundID: number?, endSoundID: number?, disableNotificationSounds: boolean?,
	hoverRadius: number?, hoverMovePower: number?, hoverScaleLimit: number?, bounceElasticity: number?, bounceFriction: number?,
	floatSpeed: number?, floatYMult: number?, floatXMult: number?, floatRotMult: number?,
	textSpeed: number?, textEndSpeed: number?, textSuccessColor: Color3?, textFailColor: Color3?, maxNotificationWidth: number?, textSize: number?, textFont: Enum.Font?, strokeColor: Color3?
}
type UINode = { Layout: Frame, Drop: Frame, Label: TextLabel, Stroke: UIStroke }
type LabelState = { offsetX: number, offsetY: number, velocityX: number, velocityY: number, textSize: number, angleOffset: number, rotation: number, sinW: number, cosW: number }
type NotificationData = {Container:Frame,Labels:{TextLabel},baseSize:number,ExpireTime:number,TotalDuration:number,Count:number,CounterLabel:TextLabel?,CounterStroke:UIStroke?, ActiveTween:Tween?,TimerLabel:TextLabel?,DurationBar:Frame?,BarTween:Tween?,BgFrame:Frame,BgStroke:UIStroke
}

local NotificationService = {}

--// > Services < //--
--// ! all the services used in this service
local GuiService = game:GetService("GuiService") --// for the topbar inset
local CoreGui = game:GetService("CoreGui") --// where the notification GUI is stored
local TweenService = game:GetService("TweenService") --// used for tweening everything
local RunService = game:GetService("RunService") --// used for the heartbeat connection
local TextService = game:GetService("TextService") --// used for getting text size
local ContentProvider = game:GetService("ContentProvider") --// used for loading sounds
local UserInputService = game:GetService("UserInputService") --// for the mouse position
local Debris = game:GetService("Debris") --// to eat garbage nom nom nom oghh i'm so big

--// > Resources < //--
--// ! all the modules and assets used in this service
local Preferences: Preferences --// preferences
local activeNotifications: {NotificationData} = {} --// to store the notifications
local existingNotifications: {[string]: NotificationData} = {} --// to store the notification templates, used for counter
local activeNotificationCount: number = 0 --// the amount of active notifications, used for counter
local heartbeatConnection: RBXScriptConnection? = nil --// heartbeat connection
local SoundHost: DockWidgetPluginGui? --// the sound host
local startSound: string?, typeSound: string?, endSound: string? --// the sounds
local allActiveLabels: {TextLabel} = {} --// to store all labels for wiggly wiggler
local labelBaseSize: {[TextLabel]: number} = {} --// to store the base sizes of the labels
local labelWaveData: {[TextLabel]: {number}} = {} --// {[1] = sinW, [2] = cosW}
local guiInsetX: number, guiInsetY: number = 0, 0 --// cached inset values i don't care that much about

--// > Helpers < //--
--// ! all the helper functions used in this service
local function getValidatedSoundId(customId: any, defaultId: number): string --// for checking if sounds are moderated or deleted. if so, use backup
	if not customId then return "rbxassetid://" .. tostring(defaultId) end --// if there is no custom id, return the default id

	local tempSound = Instance.new("Sound") --// create temporary sound
	tempSound.SoundId = "rbxassetid://" .. tostring(customId) --// set SoundId to customId
	tempSound.Parent = game:GetService("SoundService") --// parent it to SoundService temporarily

	local success = pcall(function() ContentProvider:PreloadAsync({tempSound}) end) --// preload sound
	local timeout, start = 2, os.clock() --// timeout and start
	while success and tempSound.TimeLength <= 0 and (tick() - start) < timeout do task.wait() end --// wait until sound is loaded

	local isValid = success and tempSound.TimeLength > 0 --// check if sound is valid
	tempSound:Destroy() --// not needed anymore

	if isValid then return "rbxassetid://" .. tostring(customId) --// return the id if successful
		--// return default id if it failed
	else warn(string.format("{ConvertPlus} // > Custom sound ID (%s) failed to load or is moderated. Reverting to default.", tostring(customId))) return "rbxassetid://" .. tostring(defaultId) end
end

function NotificationService.Init(plugin: Plugin, PreferencesTable: Preferences) --// init, aswell as set up sounds
	Preferences = PreferencesTable --// preferences

	--// cache inset once — it won't change mid-session
	local inset = GuiService:GetGuiInset()
	guiInsetX, guiInsetY = inset.X, inset.Y

	local defaultStartSound, defaultTypeSound, defaultEndSound = 122902269090596, 75801415132502, 103829267136732 --// default/fallback sounds

	startSound = getValidatedSoundId(PreferencesTable.startSoundID, defaultStartSound) --// start sound
	typeSound = getValidatedSoundId(PreferencesTable.typeSoundID, defaultTypeSound) --// type sound
	endSound = getValidatedSoundId(PreferencesTable.endSoundID, defaultEndSound) --// end sound

	if not SoundHost then --// if it doesn't already exist
		SoundHost = plugin:CreateDockWidgetPluginGuiAsync("ConvertPlusAudioHost", DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, false, true, 0, 0))
	end
	local activeHost = SoundHost :: DockWidgetPluginGui --// set activehost to host
	activeHost.Title, activeHost.Enabled = "ConvertPlusAudioHostYoureNotMeantToSee", false --// values for activehost
end

type SizeCharCache = {[string]: Vector2}
type SizeLevelCache = {[number]: SizeCharCache}
type TextSizeCacheMap = {[string]: SizeLevelCache}
local textSizeCache: TextSizeCacheMap = {}

--// gets the text size and caches it
local function getCachedTextSize(char: string, size: number, font: Enum.Font): Vector2
	local fontLevel = textSizeCache[font.Name]
	if not fontLevel then fontLevel = {}; textSizeCache[font.Name] = fontLevel end
	local sizeLevel = fontLevel[size]
	if not sizeLevel then sizeLevel = {}; fontLevel[size] = sizeLevel end

	local cached = sizeLevel[char]
	if not cached then cached = TextService:GetTextSize(char, size, font, Vector2.new(1000, 1000)) sizeLevel[char] = cached
	end return cached
end

--// used to play sounds
local function playSound(id: string?, volume: number?, pitch: number?) --// yo david if you make me do this again i will genuinely crucify you
	if not Preferences or Preferences.disableNotificationSounds == true then return end --// check if disabled
	if not id or id == "" or not SoundHost then return end --//> check for invalid id and host

	local sound = Instance.new("Sound") --// sound
	sound.SoundId = id --// id
	sound.Volume, sound.PlaybackSpeed = volume or 0.5, pitch or 1 --// volume and pitch
	sound.Parent = SoundHost --// parent it to soundhost

	if not sound.IsLoaded then local timeout, elapsed = 2, 0 while not sound.IsLoaded and elapsed < timeout do elapsed += task.wait() end end --// wait for it to load with hopes and prayers

	if sound.IsLoaded then --// if sound is loaded
		sound:Play() --// play
		local duration = (sound.TimeLength > 0) and (sound.TimeLength * 2) or 2 --// duration
		Debris:AddItem(sound, duration) --// used to use a task.delay but it was consuming threads like lucasberry does wingstop
	else sound:Destroy() end
end

--// replaces math.sin/math.cos in updateWiggles with.. whatever this is bruh (this is very scary)
local lutSize, sinLut: {[number]: number} = 2048, {}
local sinLut: {[number]: number} = {} --// super evil table
for _i = 0, lutSize - 1 do sinLut[_i] = math.sin((_i / lutSize) * (math.pi * 2)) end
local INV_LUT = lutSize / (math.pi * 2) --// pre-divided so fastSin/fastCos multiply instead of dividing

local function fastSin(x: number): number return sinLut[math.floor(x * INV_LUT) % lutSize] end --// faster version of math.sin i think
local function fastCos(x: number): number return sinLut[math.floor((x + (math.pi / 2)) * INV_LUT) % lutSize] end --// faster version of math.cos i think

local introStates: {[TextLabel]: boolean} = setmetatable({}, { __mode = "k" }) :: any --// table for evil intro stuff ig
local labelStates: {[TextLabel]: LabelState} = setmetatable({}, { __mode = "k" }) :: any --// used to store the state of the labels

local function updateWiggles() --// wiggle wiggle wiggle
	if not Preferences then return end --// check if preferences got shot dead.. wait does this even matter tbh uhh
	if #allActiveLabels == 0 then --// if no active labels, disconnect connection
		if heartbeatConnection then heartbeatConnection:Disconnect(); heartbeatConnection = nil end return
	end

	local rawPos = UserInputService:GetMouseLocation() --// raw position of mouse
	local mousePosX, mousePosY = rawPos.X - guiInsetX, rawPos.Y - guiInsetY --// x/y position of mouse with inset

	local hoverRadius = Preferences.hoverRadius or 200 --// radius of the mouse
	local hoverMovePower = Preferences.hoverMovePower or 4 --// pixels it moves toward the mouse
	local hoverScaleLimit = Preferences.hoverScaleLimit or 1.15 --// max size mult
	local bounceElasticity = Preferences.bounceElasticity or 0.1 --// elasticity of the bounce-back
	local bounceFriction = Preferences.bounceFriction or 0.85 --// friction of the bounce-back
	local speed = Preferences.floatSpeed or 1 --// speed of the float
	local yMult = Preferences.floatYMult or 3 --// y multiplier
	local xMult = Preferences.floatXMult or 2 --// x multiplier
	local rotMult = Preferences.floatRotMult or 12 --// rotation multiplier

	local invHoverRadius = 1 / hoverRadius --// division once per frame, multiply inside loop. super evil stuff going on here i think
	local hoverScaleDelta = hoverScaleLimit - 1 --// pre-subtract avoids per-label subtraction because i heart performance sm yea

	local t = os.clock() --// clock
	local tY, tX, tRot = t * (5 * speed), t * (4 * speed), t * (3 * speed) --// 3 different speeds

	--// compute all six trig values once per frame using LUT
	local sinTY = fastSin(tY); local cosTY = fastCos(tY) --// sin/cosTY
	local sinTX = fastSin(tX); local cosTX = fastCos(tX) --// sin/cosTX
	local sinTRot = fastSin(tRot); local cosTRot = fastCos(tRot) --// sin/cosTRot

	for _, label in ipairs(allActiveLabels) do --// loop through flat labels
		if introStates[label] then continue end --// if still in intro
		if not label.Parent then continue end --// safety: recycled label not yet removed, no container or container has no parent

		local baseSize = labelBaseSize[label] or 26 --// base size
		local state = labelStates[label] --// get label state

		if not state then --// first time this label is processed: build state from stored wave data (if no state, make one)
			local waveData = labelWaveData[label]
			local sinW, cosW = if waveData then waveData[1] else 0, if waveData then waveData[2] else 1
			state = { offsetX = 0, offsetY = 0, velocityX = 0, velocityY = 0, textSize = baseSize, angleOffset = label.Rotation, rotation = label.Rotation, sinW = sinW, cosW = cosW }
			labelStates[label] = state --// set state
		end

		local sinW, cosW = state.sinW, state.cosW

		--// angle-addition identities: sin(tY+w), cos(tX+w), cos(tRot+w)
		--// avoids computing separate per-label trig; just recombine the shared frame values
		local floatY = (sinTY * cosW + cosTY * sinW) * yMult --// float y axis
		local floatX = (cosTX * cosW - sinTX * sinW) * xMult --// float x axis
		local targetRot = ((cosTRot * cosW - sinTRot * sinW) * rotMult) + state.angleOffset --// target rotation

		--// raw scalar arithmetic instead of Vector2 subtraction → magnitude → normalize → multiply
		--// each of those Vector2 ops allocates a new table on the heap
		local absPos = label.AbsolutePosition --// absolute position and size of label
		local absSize = label.AbsoluteSize
		local dx = mousePosX - (absPos.X + absSize.X * 0.5)
		local dy = mousePosY - (absPos.Y + absSize.Y * 0.5)
		local dist = math.sqrt(dx * dx + dy * dy)

		local targetSize: number, targetZIndex: number, targetOffsetX: number, targetOffsetY = baseSize, 1, 0, 0

		if dist < hoverRadius and dist > 0.001 then --// if in hover radius and not too close
			local pct = 1 - (dist * invHoverRadius) --// get the percentage
			local influence = pct * pct * pct --// influence can be done better probably but idrc rn
			local invDist = 1 / dist --// one division instead of Vector2.Unit
			targetOffsetX = (dx * invDist) * (hoverMovePower * influence) --// target offset of x
			targetOffsetY = (dy * invDist) * (hoverMovePower * influence) --// target offset of y
			targetSize = baseSize + (baseSize * hoverScaleDelta * influence) --// target size
			targetZIndex = 20 --// target zindex
		end

		--// spring physics with raw scalars — no Vector2 allocs
		local forceX = (targetOffsetX - state.offsetX) * bounceElasticity --// force of x axis
		local forceY = (targetOffsetY - state.offsetY) * bounceElasticity --// force of y axis
		state.velocityX = (state.velocityX + forceX) * bounceFriction --// velocity of x axis
		state.velocityY = (state.velocityY + forceY) * bounceFriction --// velocity of y axis
		state.offsetX += state.velocityX --// offset of x axis
		state.offsetY += state.velocityY --// offset of y axis

		state.textSize += (targetSize - state.textSize) * 0.15 --// lerp text size
		state.rotation += (targetRot - state.rotation) * 0.15 --// lerp rotation

		--// mround on offsets avoids writing a new UDim2 for sub-pixel changes
		label.Position = UDim2.new(0.5, math.round(floatX + state.offsetX), 0.5, math.round(floatY + state.offsetY)) --// position
		label.Rotation = state.rotation --// rotation

		local roundedTextSize = math.round(state.textSize)
		if label.TextSize ~= roundedTextSize then label.TextSize = roundedTextSize end --// text size
		if label.ZIndex ~= targetZIndex then label.ZIndex = targetZIndex end --// zindex
	end
end

local characterPool: {UINode} = {} --// char pool

--// get character UI
local function getCharUI(): UINode
	local uiNode: UINode --// ui node
	if #characterPool > 0 then uiNode = table.remove(characterPool) :: UINode --// remove from pool
	else
		local layoutFrame = Instance.new("Frame") --// layoutFrame
		layoutFrame.BackgroundTransparency, layoutFrame.AutomaticSize = 1, Enum.AutomaticSize.None --// transparency, automatic size

		local dropFrame = Instance.new("Frame") --// dropFrame
		dropFrame.BackgroundTransparency, dropFrame.Size = 1, UDim2.new(1, 0, 1, 0) --// transparency, size
		dropFrame.Parent = layoutFrame --// parent to layoutFrame

		local charLabel = Instance.new("TextLabel") --// characterLabel
		charLabel.BackgroundTransparency, charLabel.TextTransparency = 1, 1 --// transparency
		charLabel.Size, charLabel.TextSize, charLabel.Rotation, charLabel.AnchorPoint = UDim2.new(1, 10, 1, 10), 0, math.random(-35, 35), Vector2.new(0.5, 0.5) --// sizes, rotation, anchorpoint
		charLabel.Position, charLabel.ClipsDescendants, charLabel.ZIndex = UDim2.new(0.5, 0, 0.5, 0), false, 1 --// position, clips, zindex
		charLabel.Parent = dropFrame --// parent to dropFrame

		local stroke = Instance.new("UIStroke") --// stroke
		stroke.Thickness, stroke.ApplyStrokeMode, stroke.StrokeSizingMode, stroke.Transparency = 0, Enum.ApplyStrokeMode.Contextual, Enum.StrokeSizingMode.ScaledSize, 1 --// properties
		stroke.Parent = charLabel --// parent to charLabel
		uiNode = { Layout = layoutFrame, Drop = dropFrame, Label = charLabel, Stroke = stroke } --// set node
	end

	uiNode.Label.TextSize, uiNode.Label.TextTransparency = 0, 1 --// text size, transparency
	introStates[uiNode.Label] = true --// no idea why SetAttribute was used in the first place to be entirely honest with you
	uiNode.Label.Rotation, uiNode.Drop.Position = math.random(-35, 35), UDim2.new(0, 0, 1.2, 0) --// rotation, position
	uiNode.Stroke.Transparency, uiNode.Stroke.Thickness = 1, 0 --// stroke transparency, thickness

	return uiNode
end

local function releaseCharUI(uiNode: UINode)
	uiNode.Layout.Parent = nil
	uiNode.Label.TextTransparency = 1
	uiNode.Stroke.Transparency = 1
	uiNode.Stroke.Thickness = 0
	uiNode.Drop.Position = UDim2.new(0, 0, 1.2, 0)
	table.insert(characterPool, uiNode)
	introStates[uiNode.Label] = nil --// die
end

--// gets ui, else creates it
local function getOrCreateGui(): (ScreenGui, ScrollingFrame?)
	local existingGui = CoreGui:FindFirstChild("ConvertPlusNotifications") :: ScreenGui? --// find existing
	local gui: ScreenGui --// gui

	if existingGui and existingGui:IsA("ScreenGui") then
		gui = existingGui :: ScreenGui
	else
		gui = Instance.new("ScreenGui") --// gui
		gui.Name, gui.DisplayOrder, gui.IgnoreGuiInset, gui.ResetOnSpawn = "ConvertPlusNotifications", 10, true, false --// properties
		gui.Parent = CoreGui --// parent to coregui
	end

	local existingStack = gui:FindFirstChild("NotificationStack") :: ScrollingFrame?
	local stack: ScrollingFrame

	if existingStack then stack = existingStack
	else
		stack = Instance.new("ScrollingFrame")
		stack.CanvasSize, stack.ScrollBarThickness, stack.ScrollingEnabled, stack.Name = UDim2.new(0,0,0,0), 0, false, "NotificationStack" --// properties 1
		stack.Size, stack.AnchorPoint, stack.Position, stack.BackgroundTransparency = UDim2.new(1, 0, 1, 0), Vector2.new(0.5, 0.5), UDim2.new(0.5, 0, 0.5, 0), 1 --// properties 2
		stack.Parent = gui --// parent to gui

		local listLayout = Instance.new("UIListLayout")
		local alignmentCenter, alignmentTop, layoutOrder = Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top, Enum.SortOrder.LayoutOrder --// readability
		listLayout.HorizontalAlignment, listLayout.VerticalAlignment, listLayout.SortOrder, listLayout.Padding = alignmentCenter, alignmentTop, layoutOrder, UDim.new(0, 10) --// properties
		listLayout.Parent = stack --// parent to stack

		listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() stack.CanvasSize = UDim2.fromOffset(0, listLayout.AbsoluteContentSize.Y) end)

		local padding = Instance.new("UIPadding") --// padding
		padding.PaddingTop = UDim.new(0, 5) --// padding on top
		padding.Parent = stack --// parent to stack
	end

	return gui :: ScreenGui, stack
end

--// > Main < //--
--// ! the main part of this service
function NotificationService.Notify(message: string, isSuccess: boolean, serviceName: string?, duration: number?)
	if not Preferences then --// no idea how this would even happen ngl unless it's a custom version of the plugin
		error("{ConvertPlus} [!] NotificationService not initialized! No Preferences ModuleScript. Did you modify the source code and remove it?")
		return
	end

	local gui, stack = getOrCreateGui() --// gui
	local dur = duration or 6 --// duration
	message = string.gsub(message, "\\n", "\n") --// escape newlines

	local textSpeed = Preferences.textSpeed or 0.02 --// speed of the typewriter
	local statusText = isSuccess and "Success!" or "Error!"
	local prefix = string.format("{ConvertPlus} | {%s} [%s] // > ", serviceName or "System", statusText)
	local fullText = prefix .. message
	local textColor = isSuccess and (Preferences.textSuccessColor or Color3.fromRGB(85, 255, 127)) or (Preferences.textFailColor or Color3.fromRGB(255, 85, 127))

	local data = existingNotifications[fullText] --// check if notification already exists
	if data then
		data.ExpireTime = os.clock() + dur
		data.TotalDuration = dur
		data.Count += 1
		
		if data.TimerLabel then data.TimerLabel.Text = string.format("%.1fs", dur) end

		--// restart duration bar tween and text
		if data.BarTween then data.BarTween:Cancel() end
		if data.DurationBar then
			data.DurationBar.Size = UDim2.new(1, 0, 0, 3)
			local newBarTween = TweenService:Create(data.DurationBar, TweenInfo.new(dur, Enum.EasingStyle.Linear), {Size = UDim2.new(0, 0, 0, 3)})
			newBarTween:Play()
			data.BarTween = newBarTween
		end

		local counterLabel, counterStroke = data.CounterLabel, data.CounterStroke
		if counterLabel and counterStroke then
			counterLabel.Text = " (x" .. tostring(data.Count) .. ")"
			counterLabel.TextTransparency, counterStroke.Transparency = 0, 0.4
			local targetSize = data.baseSize * 0.8
			counterLabel.TextSize = targetSize * 1.35
			TweenService:Create(counterLabel, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {TextSize = targetSize, Rotation = math.random(-5, 5)}):Play()
		end
		playSound(typeSound, 0.2, math.random(1.3, 1.7))
		return
	end

	local maxWidth = Preferences.maxNotificationWidth or 1200
	local prefSize = Preferences.textSize or 26
	local prefFont = Preferences.textFont or Enum.Font.BuilderSansExtraBold

	playSound(startSound, 0.35)
	print(fullText)

	local mainContainer = Instance.new("Frame")
	mainContainer.Name = "Notification_" .. tostring(os.clock())
	mainContainer.Size = UDim2.new(0, 0, 0, 0)
	mainContainer.BackgroundTransparency = 1
	mainContainer.AutomaticSize = Enum.AutomaticSize.XY
	mainContainer.ClipsDescendants = false
	mainContainer.LayoutOrder = tick()
	mainContainer.Parent = stack

	local bgFrame = Instance.new("Frame")
	bgFrame.Name = "BackgroundPanel"
	bgFrame.Size = UDim2.new(0, 0, 0, 0)
	bgFrame.Position = UDim2.new(0, 0, 0, -15)
	bgFrame.AutomaticSize = Enum.AutomaticSize.XY
	bgFrame.BackgroundColor3 = Color3.fromRGB(15, 20, 30):Lerp(textColor, 0.08) --// evil tint
	bgFrame.BackgroundTransparency = 1
	bgFrame.ClipsDescendants = true
	bgFrame.Parent = mainContainer

	local bgCorner = Instance.new("UICorner")
	bgCorner.CornerRadius = UDim.new(0, 12)
	bgCorner.Parent = bgFrame

	local bgStroke = Instance.new("UIStroke")
	bgStroke.Color = textColor:Lerp(Color3.new(1, 1, 1), 0.4)
	bgStroke.Thickness = 1.5
	bgStroke.Transparency = 1
	bgStroke.Parent = bgFrame

	local timerLabel = Instance.new("TextLabel")
	timerLabel.Name = "Timer"
	timerLabel.Text = tostring(math.ceil(dur)) .. "s"
	timerLabel.Font = prefFont
	timerLabel.TextSize = prefSize * 0.75
	timerLabel.TextColor3 = textColor:Lerp(Color3.new(1, 1, 1), 0.4)
	timerLabel.BackgroundTransparency = 1
	timerLabel.Size = UDim2.new(0, 45, 1, 0)
	timerLabel.Position = UDim2.new(0, 0, 0, 0)
	timerLabel.TextXAlignment = Enum.TextXAlignment.Center
	timerLabel.Parent = bgFrame

	local durationBar = Instance.new("Frame")
	durationBar.Name = "DurationBar"
	durationBar.Size = UDim2.new(1, 0, 0, 7)
	durationBar.Position = UDim2.new(0.5, 0, 1, 0)
	durationBar.AnchorPoint = Vector2.new(0.5, 1)
	durationBar.BackgroundColor3 = textColor
	durationBar.BorderSizePixel = 0
	durationBar.Parent = bgFrame

	local contentFrame = Instance.new("Frame")
	contentFrame.Name = "Content"
	contentFrame.Size = UDim2.new(0, 0, 0, 0)
	contentFrame.AutomaticSize = Enum.AutomaticSize.XY
	contentFrame.BackgroundTransparency = 1
	contentFrame.Parent = bgFrame

	local contentLayout = Instance.new("UIListLayout")
	contentLayout.FillDirection = Enum.FillDirection.Vertical
	contentLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	contentLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
	contentLayout.Padding = UDim.new(0, 5)
	contentLayout.Parent = contentFrame

	local contentPadding = Instance.new("UIPadding")
	contentPadding.PaddingTop = UDim.new(0, 10)
	contentPadding.PaddingBottom = UDim.new(0, 14)
	contentPadding.PaddingLeft = UDim.new(0, 45)
	contentPadding.PaddingRight = UDim.new(0, 16)
	contentPadding.Parent = contentFrame

	local bgIntroInfo = TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	TweenService:Create(bgFrame, bgIntroInfo, {Position = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 0.15}):Play()
	TweenService:Create(bgStroke, bgIntroInfo, {Transparency = 0}):Play()

	local labelsTable: {TextLabel} = table.create(#fullText, nil :: any)
	local dropsTable: {Frame} = table.create(#fullText, nil :: any)
	local strokesTable: {UIStroke} = table.create(#fullText, nil :: any)
	local uiNodesTable: {UINode} = table.create(#fullText, nil :: any)

	local textLength: number = #fullText --// thank you --!strict for shutting up
	local maxIntroDelay = (textLength ^ 0.995) * textSpeed
	local introBuffer = maxIntroDelay + 5

	local notificationData: NotificationData = {
		Container = mainContainer, Labels = labelsTable, baseSize = prefSize, ExpireTime = os.clock() + dur, TotalDuration = dur, Count = 1,
		TimerLabel = timerLabel, DurationBar = durationBar, BgFrame = bgFrame, BgStroke = bgStroke
	}
	existingNotifications[fullText] = notificationData
	table.insert(activeNotifications, notificationData)
	activeNotificationCount += 1

	local currentLineIndex = 1
	local function createLineContainer(): Frame
		local lineFrame = Instance.new("Frame")
		lineFrame.Name = "Line_" .. currentLineIndex
		lineFrame.BackgroundTransparency = 1
		lineFrame.AutomaticSize = Enum.AutomaticSize.XY
		lineFrame.Size = UDim2.new(0, 0, 0, prefSize + 8)
		lineFrame.LayoutOrder = currentLineIndex
		lineFrame.Parent = contentFrame --// parent to contentFrame instead of mainContainer now!

		local lineLayout = Instance.new("UIListLayout")
		lineLayout.FillDirection = Enum.FillDirection.Horizontal
		lineLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left --// left alignment for new polish
		lineLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		lineLayout.SortOrder = Enum.SortOrder.LayoutOrder
		lineLayout.Padding = UDim.new(0, 1)
		lineLayout.Parent = lineFrame

		currentLineIndex += 1
		return lineFrame
	end

	local currentLineContainer = createLineContainer()
	local globalCharCount = 0
	local currentLineWidth = 0

	--// ! create TextLabel's for each character/letter
	for i = 1, #fullText do
		local char = string.sub(fullText, i, i)

		if char == "\n" then --// newline
			currentLineContainer = createLineContainer()
			currentLineWidth = 0
			continue
		end

		if char ~= " " and (i == 1 or string.sub(fullText, i-1, i-1) == " " or string.sub(fullText, i-1, i-1) == "\n") then --// if character isn't a space and or newline
			local word = string.match(fullText, "^%S+", i)
			if word then
				local wordWidth = 0
				for c = 1, #word do
					local wChar = string.sub(word, c, c)
					local wCharSize = getCachedTextSize(wChar, prefSize, prefFont)
					wordWidth += (wCharSize.X + 4) + 1
				end
				if currentLineWidth + wordWidth > maxWidth and currentLineWidth > 0 then
					currentLineContainer = createLineContainer()
					currentLineWidth = 0
				end
			end
		end

		local charSize = getCachedTextSize(char, prefSize, prefFont)
		local charLayoutWidth = charSize.X + 4
		local charTotalWidth = charLayoutWidth + 1

		if currentLineWidth + charTotalWidth > maxWidth and currentLineWidth > 0 then
			currentLineContainer = createLineContainer()
			currentLineWidth = 0
		end

		globalCharCount += 1
		currentLineWidth += charTotalWidth

		local uiNode = getCharUI()
		local layoutFrame = uiNode.Layout
		local dropFrame = uiNode.Drop
		local charLabel = uiNode.Label
		local stroke = uiNode.Stroke

		layoutFrame.Size = UDim2.new(0, charLayoutWidth, 0, charSize.Y)
		layoutFrame.LayoutOrder = globalCharCount
		layoutFrame.Parent = currentLineContainer

		dropFrame.Position = UDim2.new(0, 0, 1.2, 0)

		charLabel.Text = (char == " ") and "\u{00A0}" or char
		charLabel.Font = prefFont
		charLabel.TextColor3 = textColor

		stroke.Color = Preferences.strokeColor or Color3.fromRGB(0, 0, 0)

		table.insert(labelsTable, charLabel) --// labels table
		table.insert(dropsTable, dropFrame) --// dropframe's table
		table.insert(strokesTable, stroke) --// uistroke's table
		table.insert(uiNodesTable, uiNode) --// uiNodes table

		--// register in flat tracking tables
		allActiveLabels[#allActiveLabels + 1] = charLabel
		labelBaseSize[charLabel] = prefSize
		local waveMod = globalCharCount * 0.2
		labelWaveData[charLabel] = {fastSin(waveMod), fastCos(waveMod)} --// store wave values per label

		--// the initial tween for the labels
		--// ^ instead of math.pow — i is already number, tonumber() not needed
		local staggerDelay = (i ^ 0.995) * textSpeed --// the stagger delay
		task.delay(staggerDelay, function() if char ~= " " then playSound(typeSound, 0.15, math.random(0.9, 1.1)) end end) --// play sound

		--// tweeninfo stuff
		local introInfo = TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, staggerDelay) --// the intro tweeninfo for size and transparency
		local rotInfo = TweenInfo.new(2, Enum.EasingStyle.Circular, Enum.EasingDirection.Out, 0, false, staggerDelay) --// the intro tweeninfo for rotation
		local dropInfo = TweenInfo.new(0.6, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, 0, false, staggerDelay) --// the intro tweeninfo for dropframe

		local introTween = TweenService:Create(charLabel, introInfo, {TextSize = prefSize, TextTransparency = 0}) --// intro tween for size and transparency
		local rotTween = TweenService:Create(charLabel, rotInfo, {Rotation = 0}) --// intro tween for rotation (seperate because i want it to be more delayed)
		introTween:Play(); rotTween:Play() --// play the tweens
		introTween.Completed:Connect(function() introStates[charLabel] = nil end) --// once done, set an attribute to let UpdateWiggles do it's work
		TweenService:Create(stroke, introInfo, {Thickness = 0.1, Transparency = 0.4}):Play() --// intro tween for uistrokes
		TweenService:Create(dropFrame, dropInfo, {Position = UDim2.new(0, 0, 0, 0)}):Play() --// intro tween for dropframe
	end

	local counterLabel = Instance.new("TextLabel") --// the counter label for stacking notifications
	counterLabel.Name = "Counter" --// name of counter label
	counterLabel.BackgroundTransparency, counterLabel.TextTransparency = 1, 1 --// transparencies of counter label
	counterLabel.TextColor3 = textColor:Lerp(Color3.new(1,1,1), 0.3) --// text color of counter label
	counterLabel.Font = prefFont --// font of counter label
	counterLabel.TextSize, counterLabel.Text = prefSize * 0.8, "" --// text size and text of counter label
	counterLabel.AutomaticSize, counterLabel.LayoutOrder = Enum.AutomaticSize.XY, globalCharCount + 1 --// automatic size and layoutorder of counter label
	counterLabel.Parent = currentLineContainer --// parent of counter label

	local counterStroke = Instance.new("UIStroke") --// stroke for counter label
	counterStroke.Thickness, counterStroke.StrokeSizingMode = 0.1, Enum.StrokeSizingMode.ScaledSize --// thickness and sizing mode of counter stroke
	counterStroke.Transparency = 1 --// transparency of counter stroke
	counterStroke.Color = Preferences.strokeColor or Color3.fromRGB(0, 0, 0) --// color of counter stroke
	counterStroke.Parent = counterLabel --// parent of counter stroke

	notificationData.CounterLabel, notificationData.CounterStroke = counterLabel, counterStroke --// counter label and stroke

	if not heartbeatConnection then heartbeatConnection = RunService.Heartbeat:Connect(updateWiggles) end --// connect the heartbeat function if it's not already connected

	--// > Cleanup < //--
	--// general cleanup, aswell as the last tween for the labels
	local textIntroTime = (globalCharCount * textSpeed) + 1.2

	--// Update the expire time so the notification actually stays for 'dur' AFTER the intro finishes
	notificationData.ExpireTime = os.clock() + textIntroTime + dur

	task.spawn(function()

		--// kick off the progress bar tween right after intro text finishes rendering
		if notificationData.DurationBar and not notificationData.BarTween then
			local remaining = math.max(0, notificationData.ExpireTime - os.clock())

			--// FIX: Separate creation and playing so BarTween correctly holds the Tween object, not nil
			local barTween = TweenService:Create(notificationData.DurationBar, TweenInfo.new(remaining, Enum.EasingStyle.Linear), {Size = UDim2.new(0, 0, 0, 3)})
			notificationData.BarTween = barTween
			barTween:Play()
		end

		while os.clock() < notificationData.ExpireTime do 
			local remaining = math.max(0, notificationData.ExpireTime - os.clock())
			if notificationData.TimerLabel then 
				notificationData.TimerLabel.Text = string.format("%.1fs", remaining) 
			end
			RunService.Heartbeat:Wait()
		end

		if not mainContainer or not mainContainer.Parent then return end --// if the container was destroyed, then we can just be lazy

		if existingNotifications[fullText] == notificationData then existingNotifications[fullText] = nil end --// remove from existingnotifications table i think i lowk forgot

		playSound(endSound, 0.35) --// play endsound
		
		local counterInfo = TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut) --// outro tweeninfo for counterlabel
		if notificationData.CounterLabel and notificationData.CounterStroke then --// if counter label and counter stroke
			TweenService:Create(notificationData.CounterLabel, counterInfo, {TextTransparency = 1}):Play() --// outro tween for counterlabel
			TweenService:Create(notificationData.CounterStroke, counterInfo, {Transparency = 1}):Play() --// outro tween for counterstroke
		end

		if notificationData.TimerLabel then
			notificationData.TimerLabel.Text = "0.0s"
			TweenService:Create(notificationData.TimerLabel, counterInfo, {TextTransparency = 1}):Play()
		end

		local totalChars = #dropsTable --// total character count
		for i, drop in ipairs(dropsTable) do
			local sDelay = i * (Preferences.textEndSpeed or 0.015) --// stagger delay
			local outInfo = TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.In, 0, false, sDelay) --// the outro tweeninfo for labels and strokes
			TweenService:Create(labelsTable[i], outInfo, {TextTransparency = 1}):Play() --// outro tween for labels
			TweenService:Create(strokesTable[i], outInfo, {Transparency = 1}):Play() --// outro tween for strokes

			local dropTween = TweenService:Create(drop, outInfo, {Position = UDim2.new(0, math.random(-10, 10), math.random(1.5, 1.75), 0)}) --// the tween for drops
			dropTween:Play() --// play droptween

			if i == totalChars then
				dropTween.Completed:Connect(function()
					local idx = table.find(activeNotifications, notificationData) --// finds activenotifications table
					if idx then table.remove(activeNotifications, idx) end --// cleans up activenotifications table

					--// swap-remove each label from the flat tracking tables (O(1) per label)
					for _, label in ipairs(labelsTable) do
						local labelIdx = table.find(allActiveLabels, label)
						if labelIdx then
							allActiveLabels[labelIdx] = allActiveLabels[#allActiveLabels]
							allActiveLabels[#allActiveLabels] = nil
						end
						labelBaseSize[label] = nil
						labelWaveData[label] = nil
						labelStates[label] = nil
					end
					
					--// slide the background frame back UP while fading for that sweet outro
					local bgOutroInfo = TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
					TweenService:Create(notificationData.BgFrame, bgOutroInfo, {Position = UDim2.new(0, 0, 0, -20), BackgroundTransparency = 1}):Play()
					if notificationData.BgStroke then TweenService:Create(notificationData.BgStroke, bgOutroInfo, {Transparency = 1}):Play() end

					local finalSize = mainContainer.AbsoluteSize --// final size for maincontainer
					local collapseInfo = TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out) --// the outro tween for maincontainer
					mainContainer.AutomaticSize, mainContainer.Size, mainContainer.ClipsDescendants = Enum.AutomaticSize.None, UDim2.fromOffset(finalSize.X, finalSize.Y), true --// maincontainer values

					local collapseTween = TweenService:Create(mainContainer, collapseInfo, {Size = UDim2.new(0, finalSize.X, 0, 0)}) --// tween out maincontainer
					collapseTween:Play() --// play collapsetween
					collapseTween.Completed:Connect(function()
						for _, node in ipairs(uiNodesTable) do releaseCharUI(node) end
						mainContainer:Destroy()
					end)
				end)
			end
		end
	end)
end

return NotificationService
