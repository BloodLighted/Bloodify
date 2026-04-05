--// > NotificationService.lua < //--
--// ! Made by BloodLight (@Heavenly_Strings)
--// ? Handles all the notifications, mainly for debugging and general use
--// ? this does require alot more comments tho ngl..
--!optimize 2
--!native
local NotificationService = {}

--// > Services < //--
--// ? all the services used in this service
local GuiService = game:GetService("GuiService") --// ? something
local CoreGui = game:GetService("CoreGui") --// ? where the notification GUI is stored
local TweenService = game:GetService("TweenService") --// ? used for tweening everything
local RunService = game:GetService("RunService") --// ? used for the heartbeat connection
local TextService = game:GetService("TextService") --// ? used for getting text size
local ContentProvider = game:GetService("ContentProvider") --// ? used for loading sounds
local UserInputService = game:GetService("UserInputService") --// ? for the mouse position
local Debris = game:GetService("Debris") --// ? to eat garbage nom nom nom oghh i'm so big

--// > Resources < //--
--// ? all the modules and assets used in this service
local Preferences --// ? preferences
local activeNotifications = {} --// ? to store the notifications
local existingNotifications = {} --// ? to store the notification templates, used for counter
local activeNotificationCount = 0 --// ? the amount of active notifications, used for counter
local heartbeatConnection = nil --// ? heartbeat connection
local SoundHost --// ? the sound host
local startSound, typeSound, endSound
local random = Random.new()

--// > Helpers < //--
function NotificationService.Init(plugin, prefsTable)
	Preferences = prefsTable

	startSound = "rbxassetid://" .. (Preferences.startSoundID or 122902269090596)
	typeSound = "rbxassetid://" .. (Preferences.typeSoundID or 75801415132502)
	endSound = "rbxassetid://" .. (Preferences.endSoundID or 103829267136732)

	if not SoundHost then
		SoundHost = plugin:CreateDockWidgetPluginGui(
			"BloodifyAudioHost", 
			DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, false, true, 0, 0)
		)
		SoundHost.Title = "BloodifyAudioHostYoureNotMeantToSee"
		SoundHost.Enabled = false
	end
end

local textSizeCache = {}
local function getCachedTextSize(char, size, font)
	local key = font.Name .. "_" .. size .. "_" .. char

	if not textSizeCache[key] then
		textSizeCache[key] = TextService:GetTextSize(char, size, font, Vector2.new(1000, 1000))
	end

	return textSizeCache[key]
end

local function playSound(id, volume, pitch) --// yo david if you make me do this again i will genuinely crucify you
	if not Preferences or Preferences.disableNotificationSounds == true then return end
	if not id or id == "" or not SoundHost then return end

	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume or 0.5
	sound.PlaybackSpeed = pitch or 1
	sound.Parent = SoundHost

	if not sound.IsLoaded then
		sound.Loaded:Wait()
	end

	sound:Play()

	local duration = (sound.TimeLength > 0) and (sound.TimeLength * 2) or 2
	Debris:AddItem(sound, duration) --// ? used to use a task.delay but it was consuming threads like lucasberry does wingstop
end

local labelStates = setmetatable({}, { __mode = "k" }) --// ? used to store the state of the labels

local function updateWiggles()
	if #activeNotifications == 0 then
		if heartbeatConnection then
			heartbeatConnection:Disconnect()
			heartbeatConnection = nil
		end
		return
	end

	local rawMousePos = UserInputService:GetMouseLocation()
	local mousePos = rawMousePos - GuiService:GetGuiInset()

	local hoverRadius = Preferences.hoverRadius or 200 --// ? radius of the mouse
	local hoverMovePower = Preferences.hoverMovePower or 4 --// ? pixels it moves toward the mouse
	local hoverScaleLimit = Preferences.hoverScaleLimit or 1.15 --// ? max size mult
	local bounceElasticity = Preferences.bounceElasticity or 0.1 --// ? elasticity of the bounce-back
	local bounceFriction = Preferences.bounceFriction or 0.85 --// ? friction of the bounce-back

	local speed = Preferences.floatSpeed or 1
	local yMult = Preferences.floatYMult or 3
	local xMult = Preferences.floatXMult or 2
	local rotMult = Preferences.floatRotMult or 12
	local waveOffset = 0.2

	local t = os.clock()
	local tY, tX, tRot = t * (5 * speed), t * (4 * speed), t * (3 * speed)
	
	local sinTY, cosTY = math.sin(tY), math.cos(tY)
	local sinTX, cosTX = math.sin(tX), math.cos(tX)
	local sinTRot, cosTRot = math.sin(tRot), math.cos(tRot)

	for _, notification in ipairs(activeNotifications) do
		if not notification.Container or not notification.Container.Parent then continue end
		local baseSize = notification.baseSize or 26

		for i, label in ipairs(notification.Labels) do
			if label:GetAttribute("IsIntro") then continue end

			local state = labelStates[label]
			if not state then
				local waveMod = i * 0.2
				state = {
					offset = Vector2.zero,
					velocity = Vector2.zero,
					textSize = baseSize,
					angleOffset = label.Rotation,
					rotation = label.Rotation,
					sinW = math.sin(waveMod),
					cosW = math.cos(waveMod)
				}
				labelStates[label] = state
			end

			local floatY = (sinTY * state.cosW + cosTY * state.sinW) * yMult
			local floatX = (cosTX * state.cosW - sinTX * state.sinW) * xMult
			local targetRot = ((cosTRot * state.cosW - sinTRot * state.sinW) * rotMult) + state.angleOffset

			local labelCenter = label.AbsolutePosition + (label.AbsoluteSize / 2)
			local offsetVector = mousePos - labelCenter
			local dist = offsetVector.Magnitude

			local targetSize = baseSize
			local targetZIndex = 1
			local targetMouseOffset = Vector2.zero

			if dist < hoverRadius and dist > 0.001 then
				local pct = 1 - (dist * (1 / hoverRadius))
				local influence = pct * pct * pct 

				local direction = offsetVector * (1 / dist)

				targetMouseOffset = direction * (hoverMovePower * influence)
				targetSize = baseSize + (baseSize * (hoverScaleLimit - 1) * influence)
				targetZIndex = 20
			end

			local force = (targetMouseOffset - state.offset) * bounceElasticity
			state.velocity = (state.velocity + force) * bounceFriction
			state.offset += state.velocity

			state.textSize += (targetSize - state.textSize) * 0.15
			state.rotation += (targetRot - state.rotation) * 0.15

			label.Position = UDim2.new(0.5, floatX + state.offset.X, 0.5, floatY + state.offset.Y)
			label.Rotation = state.rotation

			local roundedTextSize = math.round(state.textSize)
			if label.TextSize ~= roundedTextSize then
				label.TextSize = roundedTextSize
			end

			if label.ZIndex ~= targetZIndex then
				label.ZIndex = targetZIndex
			end
		end
	end
end

--// > Object Pooling < //--
local characterPool = {}

local function getCharUI()
	local uiNode
	if #characterPool > 0 then
		uiNode = table.remove(characterPool)
	else
		
		local layoutFrame = Instance.new("Frame")
		layoutFrame.BackgroundTransparency = 1
		layoutFrame.AutomaticSize = Enum.AutomaticSize.None

		local dropFrame = Instance.new("Frame")
		dropFrame.BackgroundTransparency = 1
		dropFrame.Size = UDim2.new(1, 0, 1, 0)
		dropFrame.Parent = layoutFrame

		local charLabel = Instance.new("TextLabel")
		charLabel.BackgroundTransparency = 1
		charLabel.TextTransparency = 1
		charLabel.Size = UDim2.new(1, 10, 1, 10)
		charLabel.TextSize = 0
		charLabel.Rotation = random:NextNumber(-35, 35)
		charLabel.AnchorPoint = Vector2.new(0.5, 0.5)
		charLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
		charLabel.ClipsDescendants = false
		charLabel.ZIndex = 1
		charLabel.Parent = dropFrame

		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 0
		stroke.Transparency = 1
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		stroke.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
		stroke.Parent = charLabel
		uiNode = { Layout = layoutFrame, Drop = dropFrame, Label = charLabel, Stroke = stroke }
	end
	
	uiNode.Label.TextSize = 0
	uiNode.Label.TextTransparency = 1
	uiNode.Label:SetAttribute("IsIntro", true)
	uiNode.Label.Rotation = random:NextNumber(-35, 35)
	uiNode.Drop.Position = UDim2.new(0, 0, 1.2, 0)
	uiNode.Stroke.Transparency = 1
	uiNode.Stroke.Thickness = 0
		
	return uiNode
end

local function releaseCharUI(uiNode)
	uiNode.Layout.Parent = nil
	uiNode.Label.TextTransparency = 1
	uiNode.Stroke.Transparency = 1
	uiNode.Stroke.Thickness = 0
	uiNode.Drop.Position = UDim2.new(0, 0, 1.2, 0)

	table.insert(characterPool, uiNode)
end

local function getOrCreateGui()
	local gui = CoreGui:FindFirstChild("BloodifyNotifications")
	if not gui then
		gui = Instance.new("ScreenGui")
		gui.Name = "BloodifyNotifications"
		gui.DisplayOrder = 10
		gui.IgnoreGuiInset = true
		gui.ResetOnSpawn = false
		gui.Parent = CoreGui
	end

	local stack = gui:FindFirstChild("NotificationStack")
	if not stack then
		stack = Instance.new("ScrollingFrame")
		stack.CanvasSize = UDim2.new(0,0,0,0)
		stack.ScrollBarThickness = 0
		stack.ScrollingEnabled = false
		stack.Name = "NotificationStack"
		stack.Size = UDim2.new(1, 0, 1, 0)
		stack.AnchorPoint = Vector2.new(0.5, 0.5)
		stack.Position = UDim2.new(0.5, 0, 0.5, 0)
		stack.BackgroundTransparency = 1
		stack.Parent = gui

		local listLayout = Instance.new("UIListLayout")
		listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		listLayout.VerticalAlignment = Enum.VerticalAlignment.Top
		listLayout.SortOrder = Enum.SortOrder.LayoutOrder
		listLayout.Padding = UDim.new(0, 10)
		listLayout.Parent = stack

		listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
			stack.CanvasSize = UDim2.fromOffset(0, listLayout.AbsoluteContentSize.Y)
		end)

		local padding = Instance.new("UIPadding")
		padding.PaddingTop = UDim.new(0, 5)
		padding.Parent = stack
	end

	return gui, stack
end

--// > Main < //--
function NotificationService.Notify(message, isSuccess, serviceName, duration)
	if not Preferences then warn("{BloodifyPlugin} [!] // > NotificationService not initialized! No Preferences ModuleScript. Did you modify the source code and remove it?") return end
	local gui, stack = getOrCreateGui()
	if not stack then warn("{BloodifyPlugin} [Error] [!] // > NotificationStack missing! No idea how this even happens lwk..") return end
	duration = duration or 6
	message = string.gsub(message, "\\n", "\n")

	local textSpeed = Preferences.textSpeed or 0.02
	local statusText = isSuccess and "Success!" or "Error!"
	local prefix = string.format("{BloodifyPlugin} | {%s} [%s] // > ", serviceName or "System", statusText)
	local fullText = prefix .. message
	local textColor = isSuccess and (Preferences.textSuccessColor or Color3.fromRGB(85, 255, 127)) or (Preferences.textFailColor or Color3.fromRGB(255, 85, 127))
	
	if existingNotifications[fullText] then
		local data = existingNotifications[fullText]
		data.ExpireTime = os.clock() + duration
		data.Count += 1

		if data.CounterLabel then
			if data.ActiveTween then data.ActiveTween:Cancel() end
			
			data.CounterLabel.Text = " (x" .. data.Count .. ")"
			data.CounterLabel.TextTransparency, data.CounterStroke.Transparency = 0, 0.4

			local targetSize = data.baseSize * 0.8
			data.CounterLabel.TextSize = targetSize * 1.35
			data.CounterLabel.Rotation = random:NextNumber(-35, 35)
			TweenService:Create(data.CounterLabel, TweenInfo.new(0.15, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {TextSize = targetSize, Rotation = 0}):Play()
		end
		playSound(typeSound, 0.2, 1.1 + (random:NextNumber() * 0.2))
		return 
	end

	local maxWidth = Preferences.maxNotificationWidth or 1200
	local prefSize = Preferences.textSize or 26
	local prefFont = Preferences.textFont or Enum.Font.BuilderSansExtraBold

	playSound(startSound, 0.35)
	print(fullText)

	local mainContainer = Instance.new("Frame")
	mainContainer.Name = "Notification_" .. os.clock()
	mainContainer.Size = UDim2.new(0, 0, 0, 0)
	mainContainer.BackgroundTransparency = 1
	mainContainer.AutomaticSize = Enum.AutomaticSize.XY
	mainContainer.ClipsDescendants = false
	mainContainer.LayoutOrder = tick()
	mainContainer.Parent = stack

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 5)
	layout.Parent = mainContainer

	local separator = nil
	if #activeNotifications > 0 then
		separator = Instance.new("Frame")
		separator.Name = "Separator"
		separator.Size = UDim2.new(0, 0, 0, 2)
		separator.BackgroundColor3 = textColor
		separator.BackgroundTransparency = 0.2
		separator.BorderSizePixel = 0
		separator.LayoutOrder = -1
		separator.Parent = mainContainer

		local glow = Instance.new("UIStroke")
		glow.Thickness = 0
		glow.Color = textColor
		glow.Transparency = 1
		glow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		glow.Parent = separator

		task.defer(function()
			if not mainContainer or not separator then return end
			local targetWidth = mainContainer.AbsoluteSize.X
			local sepInfo = TweenInfo.new(2, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
			TweenService:Create(separator, sepInfo, {Size = UDim2.new(0, targetWidth, 0, 2)}):Play()
			TweenService:Create(glow, sepInfo, {Thickness = 4, Transparency = 0.6}):Play()
		end)
	end

	local labelsTable = {}
	local dropsTable = {}
	local strokesTable = {}
	local uiNodesTable = {}
	
	local maxIntroDelay = math.pow(tonumber(#fullText), 0.995) * textSpeed
	local introBuffer = maxIntroDelay + 5
	
	local notificationData = {Container = mainContainer, Labels = labelsTable, baseSize = prefSize, ExpireTime = os.clock() + duration, Count = 1}
	existingNotifications[fullText] = notificationData
	table.insert(activeNotifications, notificationData)
	activeNotificationCount += 1

	local currentLineIndex = 1
	local function createLineContainer()
		local lineFrame = Instance.new("Frame")
		lineFrame.Name = "Line_" .. currentLineIndex
		lineFrame.BackgroundTransparency = 1
		lineFrame.AutomaticSize = Enum.AutomaticSize.X
		lineFrame.Size = UDim2.new(0, 0, 0, prefSize + 8)
		lineFrame.LayoutOrder = currentLineIndex
		lineFrame.Parent = mainContainer

		local lineLayout = Instance.new("UIListLayout")
		lineLayout.FillDirection = Enum.FillDirection.Horizontal
		lineLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
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

	local uiNodesTable = {}

	--// > Label Setup < //--
	--// ? create TextLabel's for each character/letter
	for i = 1, #fullText do
		local char = string.sub(fullText, i, i)

		if char == "\n" then --// ? newline
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

		table.insert(labelsTable, charLabel) --// ? labels table
		table.insert(dropsTable, dropFrame) --// ? dropframe's table
		table.insert(strokesTable, stroke) --// ? uistroke's table
		table.insert(uiNodesTable, uiNode) --// ? uiNodes table

		--// ? the initial tween for the labels
		local staggerDelay = math.pow(tonumber(i), 0.995) * textSpeed
		task.delay(staggerDelay, function() if char ~= " " then playSound(typeSound, 0.15, 0.9 + (random:NextNumber() * 0.2)) end end)
		
		--// ? tweeninfo's
		local introInfo = TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, staggerDelay) --// ? the intro tween for size and transparency
		local rotInfo = TweenInfo.new(1, Enum.EasingStyle.Circular, Enum.EasingDirection.Out, 0, false, staggerDelay) --// ? the intro tween for rotation
		local dropInfo = TweenInfo.new(0.6, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, 0, false, staggerDelay) --// ? the intro tween for dropframe

		local introTween = TweenService:Create(charLabel, introInfo, {TextSize = prefSize, TextTransparency = 0}) --// ? intro tween for size and transparency
		local rotTween = TweenService:Create(charLabel, rotInfo, {Rotation = 0}) --// ? intro tween for rotation (seperate because i want it to be more delayed)
		introTween:Play() rotTween:Play() --// ? play the tweens
		introTween.Completed:Connect(function() charLabel:SetAttribute("IsIntro", false) end) --// ? once done, set an attribute to let UpdateWiggles do it's work
		TweenService:Create(stroke, introInfo, {Thickness = 0.1, Transparency = 0.4}):Play() --// ? intro tween for uistrokes
		TweenService:Create(dropFrame, dropInfo, {Position = UDim2.new(0, 0, 0, 0)}):Play() --// ? intro tween for dropframe
	end

	local counterLabel = Instance.new("TextLabel") --// ? the counter label for stacking notifications
	counterLabel.Name = "Counter"
	counterLabel.BackgroundTransparency, counterLabel.TextTransparency = 1, 1
	counterLabel.TextColor3 = textColor:Lerp(Color3.new(1,1,1), 0.3)
	counterLabel.Font = prefFont
	counterLabel.TextSize, counterLabel.Text = prefSize * 0.8, ""
	counterLabel.AutomaticSize, counterLabel.LayoutOrder = Enum.AutomaticSize.XY, globalCharCount + 1 
	counterLabel.Parent = currentLineContainer
	
	local counterStroke = Instance.new("UIStroke") --// ? stroke for counter label
	counterStroke.Thickness, counterStroke.StrokeSizingMode = 0.1, Enum.StrokeSizingMode.ScaledSize
	counterStroke.Transparency = 1
	counterStroke.Color = Preferences.strokeColor or Color3.fromRGB(0, 0, 0)
	counterStroke.Parent = counterLabel
	
	notificationData.CounterLabel, notificationData.CounterStroke = counterLabel, counterStroke

	if not heartbeatConnection then heartbeatConnection = RunService.Heartbeat:Connect(updateWiggles) end

	--// > Cleanup < //--
	--// ? general cleanup, aswell as the last tween for the labels
	local introDuration = ((globalCharCount * textSpeed) + 1.2) + duration --// ? total amount of time

	task.spawn(function()
		task.wait(introDuration - 0.1)
		local timeLeft = math.max(0, notificationData.ExpireTime - os.clock())

		task.delay(timeLeft, function()
			if not mainContainer or not mainContainer.Parent then end

			if os.clock() >= notificationData.ExpireTime then if existingNotifications[fullText] == notificationData then existingNotifications[fullText] = nil end
				playSound(endSound, 0.35)

				local separator = mainContainer:FindFirstChild("Separator") --// ? seperator
				if separator then --// ? tween out for the seperator if there is one
					local sepGlow, sepOutInfo = separator:FindFirstChildOfClass("UIStroke"), TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.In) --// ? seperator's uistroke, aswell as the tween info
					TweenService:Create(separator, sepOutInfo, {Size = UDim2.new(0, 0, 0, 2), BackgroundTransparency = 1}):Play() --// ? tween out seperator
					if sepGlow then TweenService:Create(sepGlow, sepOutInfo, {Thickness = 0, Transparency = 1}):Play() end --// ? tween out glow
				end
				
				local counterInfo = TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut) --// ? outro tween for counterlabel

				TweenService:Create(counterLabel, counterInfo, {TextTransparency = 1}):Play() TweenService:Create(counterStroke, counterInfo, {Transparency = 1}):Play()

				local totalChars = #dropsTable --// ? total character count

				for i, drop in ipairs(dropsTable) do
					local staggerDelay = i * (Preferences.textEndSpeed or 0.015) --// ? stagger delay
					local outInfo = TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.In, 0, false, staggerDelay) --// ? the outro tween for labels and strokes
					TweenService:Create(labelsTable[i], outInfo, {TextTransparency = 1}):Play() TweenService:Create(strokesTable[i], outInfo, {Transparency = 1}):Play()
					local dropTween = TweenService:Create(drop, outInfo, {Position = UDim2.new(0, random:NextNumber(-10, 10), random:NextNumber(1.5, 1.75), 0)}) --// ? the tween for drops
					dropTween:Play() --// ? play droptween

					if i == totalChars then
						dropTween.Completed:Connect(function()
							local idx = table.find(activeNotifications, notificationData) --// ? finds activenotifications table
							if idx then table.remove(activeNotifications, idx) end --// ? cleans up activenotifications table

							local finalSize = mainContainer.AbsoluteSize --// ? final size for maincontainer
							local collapseInfo = TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out) --// ? the outro tween for maincontainer
							mainContainer.AutomaticSize, mainContainer.Size, mainContainer.ClipsDescendants = Enum.AutomaticSize.None, UDim2.fromOffset(finalSize.X, finalSize.Y), true --// ? maincontainer values
							local collapseTween = TweenService:Create(mainContainer, collapseInfo, {Size = UDim2.new(0, finalSize.X, 0, 0)}) --// ? tween out maincontainer
							collapseTween:Play() --// ? play collapsetween
							collapseTween.Completed:Connect(function() for _, node in ipairs(uiNodesTable) do releaseCharUI(node) end mainContainer:Destroy() end)
						end)
					end
				end
			end
		end)
	end)
end
return NotificationService
