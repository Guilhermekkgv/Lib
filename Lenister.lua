--[[

██╗░░░░░██╗███╗░░██╗██╗░░░██╗██╗░░██╗
██║░░░░░██║████╗░██║██║░░░██║╚██╗██╔╝
██║░░░░░██║██╔██╗██║██║░░░██║░╚███╔╝░
██║░░░░░██║██║╚████║██║░░░██║░██╔██╗░
███████╗██║██║░╚███║╚██████╔╝██╔╝╚██╗
╚══════╝╚═╝╚═╝░░╚══╝░╚═════╝░╚═╝░░╚═╝

  Autor: LinuxDevBr
  v1.5.6

]]

local TweenService = game:GetService("TweenService")
local InputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")
local MarketplaceService = game:GetService("MarketplaceService")

local function detectDevice()
    local platform = UserInputService:GetPlatform()
    local deviceType = "Unknown"
    
    if platform == Enum.Platform.Windows or platform == Enum.Platform.OSX or platform == Enum.Platform.UWP then
        deviceType = "PC"
    elseif platform == Enum.Platform.IOS or platform == Enum.Platform.Android then
        deviceType = "Mobile"
    elseif UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
        deviceType = "Mobile"
    elseif UserInputService.KeyboardEnabled and UserInputService.MouseEnabled then
        deviceType = "PC"
    end
    
    return deviceType, platform
end

local Linux = {}
Linux.CurrentTheme = "Orange"
Linux.SelectedTheme = "Orange"
Linux.Themes = {
    Orange = Color3.fromRGB(56, 109, 223),
    Purple = Color3.fromRGB(138, 43, 226),
    Blue = Color3.fromRGB(59, 130, 246),
    Red = Color3.fromRGB(255, 0, 0),
    Green = Color3.fromRGB(34, 197, 94)
}
Linux.AccentElements = {}
Linux.CurrentTab = nil
Linux.DeviceType = detectDevice()
Linux.ActiveNotifications = {}
Linux.NotificationCounter = 0

Linux.IgnoredElements = {}

function Linux.SetIgnoreIndexes(names)
    for _, name in ipairs(names) do
        Linux.IgnoredElements[name] = true
    end
end

function Linux.Instance(class, props)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do
        inst[k] = v
    end
    return inst
end

function Linux.RegisterAccentElement(element)
    table.insert(Linux.AccentElements, element)
end

function Linux.ApplyTheme(themeName)
    if not Linux.Themes[themeName] then return end
    
    local newColor = Linux.Themes[themeName]
    Linux.CurrentTheme = themeName
    
    for _, element in pairs(Linux.AccentElements) do
        if element and element.Parent then
            local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            TweenService:Create(element, tweenInfo, {BackgroundColor3 = newColor}):Play()
        end
    end
end

function Linux.SaveThemeSettings()
    local success, result = pcall(function()
        local themeData = {
            Theme = Linux.CurrentTheme
        }
        local json = HttpService:JSONEncode(themeData)
        if writefile then
            if not isfolder(Linux.ConfigFolder) then
                makefolder(Linux.ConfigFolder)
            end
            writefile(Linux.ConfigFolder .. "/theme.json", json)
            return true
        else
            return false, "writefile function not available"
        end
    end)
    if not success then
        print("Error saving theme settings:", result)
    end
    return success, result
end

function Linux.LoadThemeSettings()
    local success, result = pcall(function()
        if readfile and isfile(Linux.ConfigFolder .. "/theme.json") then
            local json = readfile(Linux.ConfigFolder .. "/theme.json")
            local themeData = HttpService:JSONDecode(json)
            Linux.CurrentTheme = themeData.Theme or "Orange"
            Linux.SelectedTheme = Linux.CurrentTheme
            return true
        else
            return false, "Theme settings file not found"
        end
    end)
    if not success then
        print("Error loading theme settings:", result)
    end
    return success, result
end

function Linux:SafeCallback(Function, ...)
    if not Function then
        return
    end
    local Success, ErrorMessage = pcall(Function, ...)
    if not Success then
        local errorText = "Unknown error occurred"
        if ErrorMessage then
            if type(ErrorMessage) == "string" then
                local _, i = ErrorMessage:find(":%d+: ")
                if not i then
                    errorText = ErrorMessage
                else
                    errorText = ErrorMessage:sub(i + 1)
                end
            elseif type(ErrorMessage) == "table" and ErrorMessage.message then
                errorText = tostring(ErrorMessage.message)
            else
                errorText = tostring(ErrorMessage)
            end
        end
        print("Callback error:", errorText)
        self:Notify({
            Title = "Callback Error",
            Content = errorText,
            Duration = 5
        })
    end
end

function Linux.RepositionNotifications()
    local isMobile = Linux.DeviceType == "Mobile"
    local spacing = 10
    local startOffset = 10
    
    for i, notificationData in ipairs(Linux.ActiveNotifications) do
        if notificationData.Frame and notificationData.Frame.Parent then
            local yOffset = startOffset
            for j = 1, i - 1 do
                if Linux.ActiveNotifications[j] and Linux.ActiveNotifications[j].Frame and Linux.ActiveNotifications[j].Frame.Parent then
                    yOffset = yOffset + Linux.ActiveNotifications[j].Frame.Size.Y.Offset + spacing
                end
            end
            
            local targetPosition = UDim2.new(0, isMobile and 10 or 20, 1, -yOffset - notificationData.Frame.Size.Y.Offset)
            local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            TweenService:Create(notificationData.Frame, tweenInfo, {Position = targetPosition}):Play()
        end
    end
end

function Linux.RemoveNotification(notificationId)
    for i, notificationData in ipairs(Linux.ActiveNotifications) do
        if notificationData.Id == notificationId then
            table.remove(Linux.ActiveNotifications, i)
            break
        end
    end
    Linux.RepositionNotifications()
end

function Linux:Notify(config)
    local isMobile = Linux.DeviceType == "Mobile"
    local notificationWidth = isMobile and 200 or 300
    local notificationHeight = config.SubContent and 80 or 60
    local parent = RunService:IsStudio() and LocalPlayer.PlayerGui or game:GetService("CoreGui")
    
    Linux.NotificationCounter = Linux.NotificationCounter + 1
    local notificationId = Linux.NotificationCounter
    
    local NotificationHolder = Linux.Instance("ScreenGui", {
        Name = "NotificationHolder_" .. notificationId,
        Parent = parent,
        ResetOnSpawn = false,
        Enabled = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    })
    
    local Notification = Linux.Instance("Frame", {
        Parent = NotificationHolder,
        BackgroundColor3 = Color3.fromRGB(30, 30, 30),
        BackgroundTransparency = 0.18,
        BorderColor3 = Color3.fromRGB(60, 60, 60),
        BorderSizePixel = 0,
        Size = UDim2.new(0, notificationWidth, 0, notificationHeight),
        Position = UDim2.new(1, 10, 1, -notificationHeight - 10),
        ZIndex = 100
    })
    
    Linux.Instance("UICorner", {
        Parent = Notification,
        CornerRadius = UDim.new(0, 8)
    })
    
    Linux.Instance("UIStroke", {
        Parent = Notification,
        Color = Color3.fromRGB(25, 25, 25),
        Thickness = 1
    })
    
    Linux.Instance("TextLabel", {
        Parent = Notification,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -10, 0, 20),
        Position = UDim2.new(0, 5, 0, 5),
        Font = Enum.Font.GothamSemibold,
        Text = config.Title or "Notification",
        TextColor3 = Color3.fromRGB(240, 240, 240),
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        ZIndex = 101
    })
    
    Linux.Instance("TextLabel", {
        Parent = Notification,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -10, 0, 20),
        Position = UDim2.new(0, 5, 0, 25),
        Font = Enum.Font.GothamSemibold,
        Text = config.Content or "Content",
        TextColor3 = Color3.fromRGB(170, 170, 170),
        TextSize = 14,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        ZIndex = 101
    })
    
    if config.SubContent then
        Linux.Instance("TextLabel", {
            Parent = Notification,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -10, 0, 20),
            Position = UDim2.new(0, 5, 0, 45),
            Font = Enum.Font.GothamSemibold,
            Text = config.SubContent,
            TextColor3 = Color3.fromRGB(170, 170, 170),
            TextSize = 12,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            ZIndex = 101
        })
    end
    
    local ProgressBar = Linux.Instance("Frame", {
        Parent = Notification,
        BackgroundColor3 = Color3.fromRGB(25, 25, 25),
        Size = UDim2.new(1, -10, 0, 4),
        Position = UDim2.new(0, 5, 1, -9),
        ZIndex = 101,
        BorderSizePixel = 0,
        BorderColor3 = Color3.fromRGB(60, 60, 60)
    })
    
    Linux.Instance("UICorner", {
        Parent = ProgressBar,
        CornerRadius = UDim.new(1, 0)
    })
    
    local ProgressFill = Linux.Instance("Frame", {
        Parent = ProgressBar,
        BackgroundColor3 = Linux.Themes[Linux.CurrentTheme],
        Size = UDim2.new(0, 0, 1, 0),
        ZIndex = 101,
        BorderSizePixel = 0,
        BorderColor3 = Color3.fromRGB(60, 60, 60)
    })
    
    Linux.Instance("UICorner", {
        Parent = ProgressFill,
        CornerRadius = UDim.new(1, 0)
    })
    
    Linux.RegisterAccentElement(ProgressFill)
    
    table.insert(Linux.ActiveNotifications, {
        Id = notificationId,
        Frame = Notification,
        Holder = NotificationHolder
    })
    
    Linux.RepositionNotifications()
    
    if config.Duration then
        local progressTweenInfo = TweenInfo.new(config.Duration, Enum.EasingStyle.Linear, Enum.EasingDirection.In)
        TweenService:Create(ProgressFill, progressTweenInfo, {Size = UDim2.new(1, 0, 1, 0)}):Play()
        
        task.delay(config.Duration, function()
            local exitTweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            TweenService:Create(Notification, exitTweenInfo, {Position = UDim2.new(1, 10, Notification.Position.Y.Scale, Notification.Position.Y.Offset)}):Play()
            
            Linux.RemoveNotification(notificationId)
            
            task.wait(0.5)
            if NotificationHolder and NotificationHolder.Parent then
                NotificationHolder:Destroy()
            end
        end)
    end
end

Linux.SavedConfigs = {}
Linux.CurrentConfig = ""
Linux.ConfigFolder = "LinuxConfigs"
Linux.AutoLoadEnabled = false
Linux.AutoLoadConfig = ""
Linux.PrivacyEnabled = false

function Linux.SaveAutoLoadSettings()
    local success, result = pcall(function()
        local autoLoadData = {
            Enabled = Linux.AutoLoadEnabled,
            ConfigName = Linux.AutoLoadConfig
        }
        local json = HttpService:JSONEncode(autoLoadData)
        if writefile then
            if not isfolder(Linux.ConfigFolder) then
                makefolder(Linux.ConfigFolder)
            end
            writefile(Linux.ConfigFolder .. "/autoload.json", json)
            return true
        else
            return false, "writefile function not available"
        end
    end)
    if not success then
        print("Error saving autoload settings:", result)
    end
    return success, result
end

function Linux.LoadAutoLoadSettings()
    local success, result = pcall(function()
        if readfile and isfile(Linux.ConfigFolder .. "/autoload.json") then
            local json = readfile(Linux.ConfigFolder .. "/autoload.json")
            local autoLoadData = HttpService:JSONDecode(json)
            Linux.AutoLoadEnabled = autoLoadData.Enabled or false
            Linux.AutoLoadConfig = autoLoadData.ConfigName or ""
            return true
        else
            return false, "Auto load settings file not found"
        end
    end)
    if not success then
        print("Error loading autoload settings:", result)
    end
    return success, result
end

function Linux.SavePrivacySettings()
    local success, result = pcall(function()
        local privacyData = {
            Enabled = Linux.PrivacyEnabled
        }
        local json = HttpService:JSONEncode(privacyData)
        if writefile then
            if not isfolder(Linux.ConfigFolder) then
                makefolder(Linux.ConfigFolder)
            end
            writefile(Linux.ConfigFolder .. "/privacy.json", json)
            return true
        else
            return false, "writefile function not available"
        end
    end)
    if not success then
        print("Error saving privacy settings:", result)
    end
    return success, result
end

function Linux.LoadPrivacySettings()
    local success, result = pcall(function()
        if readfile and isfile(Linux.ConfigFolder .. "/privacy.json") then
            local json = readfile(Linux.ConfigFolder .. "/privacy.json")
            local privacyData = HttpService:JSONDecode(json)
            Linux.PrivacyEnabled = privacyData.Enabled or false
            return true
        else
            return false, "Privacy settings file not found"
        end
    end)
    if not success then
        print("Error loading privacy settings:", result)
    end
    return success, result
end

function Linux.SaveConfig(name)
    if not name or name == "" then
        return false, "Invalid configuration name"
    end
    
    local configData = {
        Elements = {},
        ConfigName = name,
        SaveTime = os.time()
    }
    
    for _, elementData in pairs(Linux.SavedElements or {}) do
        local element = elementData.Element
        local value = elementData.GetValue and elementData.GetValue() or nil
        
        if value ~= nil and not Linux.IgnoredElements[element.Name] then
            local elementInfo = {
                Type = element.Type,
                Name = element.Name,
                TabName = elementData.TabName,
                Value = nil
            }
            
            if element.Type == "Toggle" then
                elementInfo.Value = value
            elseif element.Type == "Slider" then
                elementInfo.Value = value
            elseif element.Type == "Dropdown" then
                elementInfo.Value = value
            elseif element.Type == "Input" then
                elementInfo.Value = value
            elseif element.Type == "ColorPicker" then
                elementInfo.Value = {value.R, value.G, value.B}
            end
            
            if elementInfo.Value ~= nil then
                table.insert(configData.Elements, elementInfo)
            end
        end
    end
    
    local success, result = pcall(function()
        local json = HttpService:JSONEncode(configData)
        if writefile then
            if not isfolder(Linux.ConfigFolder) then
                makefolder(Linux.ConfigFolder)
            end
            writefile(Linux.ConfigFolder .. "/" .. name .. ".json", json)
            return true
        else
            return false, "writefile function not available"
        end
    end)
    
    if success and result == true then
        Linux.LoadConfigList()
        return true
    else
        print("Error saving config:", result or "Unknown error")
        return false, result or "Error saving configuration"
    end
end

function Linux.LoadConfig(name)
    if not name or name == "" then
        return false, "Invalid configuration name"
    end
    
    local currentAutoLoadConfig = Linux.AutoLoadConfig
    
    local success, result = pcall(function()
        if readfile and isfile(Linux.ConfigFolder .. "/" .. name .. ".json") then
            local json = readfile(Linux.ConfigFolder .. "/" .. name .. ".json")
            local configData = HttpService:JSONDecode(json)
            
            for _, elementInfo in pairs(configData.Elements) do
                for _, elementData in pairs(Linux.SavedElements or {}) do
                    local element = elementData.Element
                    
                    if element.Type == elementInfo.Type and element.Name == elementInfo.Name and elementData.TabName == elementInfo.TabName then
                        if elementData.IsAutoLoadInput then
                            continue
                        end
                        if element.Type == "Toggle" then
                            elementData.SetValue(elementInfo.Value)
                        elseif element.Type == "Slider" then
                            elementData.SetValue(elementInfo.Value)
                        elseif element.Type == "Input" then
                            elementData.SetValue(elementInfo.Value)
                        elseif element.Type == "ColorPicker" then
                            local colorData = elementInfo.Value
                            if type(colorData) == "table" and #colorData == 3 then
                                elementData.SetValue(Color3.fromRGB(colorData[1] * 255, colorData[2] * 255, colorData[3] * 255))
                            end
                        end
                    end
                end
            end
            
            Linux.CurrentConfig = name
            Linux.AutoLoadConfig = currentAutoLoadConfig
            
            for _, elementData in pairs(Linux.SavedElements or {}) do
                if elementData.IsAutoLoadInput then
                    elementData.SetValue(Linux.AutoLoadConfig)
                    break
                end
            end
            
            return true
        else
            return false, "Configuration file not found"
        end
    end)
    
    if not success then
        print("Error loading config:", result)
    end
    return success, result
end

function Linux.DeleteConfig(name)
    if not name or name == "" then
        return false, "Invalid configuration name"
    end
    
    local success, result = pcall(function()
        if delfile and isfile(Linux.ConfigFolder .. "/" .. name .. ".json") then
            delfile(Linux.ConfigFolder .. "/" .. name .. ".json")
            return true
        else
            return false, "Configuration file not found or delfile function not available"
        end
    end)
    
    if success and result == true then
        Linux.LoadConfigList()
        return true
    else
        print("Error deleting config:", result or "Unknown error")
        return false, result or "Error deleting configuration"
    end
end

function Linux.LoadConfigList()
    Linux.SavedConfigs = {}
    local success, result = pcall(function()
        if listfiles and isfolder(Linux.ConfigFolder) then
            local files = listfiles(Linux.ConfigFolder)
            
            for _, file in pairs(files) do
                local fileName = string.match(file, "[^/\\]+$")
                local configName = string.match(fileName, "(.+)%.json$")
                
                if configName and configName ~= "autoload" and configName ~= "privacy" and configName ~= "theme" then
                    table.insert(Linux.SavedConfigs, configName)
                end
            end
            
            return true
        else
            return false, "listfiles function not available or folder not found"
        end
    end)
    
    if not success then
        print("Error loading config list:", result)
    end
    return success, Linux.SavedConfigs
end

function Linux.Create(config)
    if config.ConfigFolder then
        Linux.ConfigFolder = config.ConfigFolder
    end
    
    Linux.LoadAutoLoadSettings()
    Linux.LoadPrivacySettings()
    Linux.LoadThemeSettings()
    
    local parent = RunService:IsStudio() and LocalPlayer:FindFirstChild("PlayerGui") or (gethui and gethui() or game:GetService("CoreGui"))
    local ProtectGui = protectgui or (syn and syn.protect_gui) or function() end
    local LinuxUI = Linux.Instance("ScreenGui", {
        Name = "LinuxUI",
        Parent = nil,
        ResetOnSpawn = false,
        Enabled = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true
    })
    pcall(function()
        if sethiddenproperty then
            sethiddenproperty(LinuxUI, "ScreenInsets", Enum.ScreenInsets.DeviceSafeInsets)
        end
    end)
    task.defer(function()
        ProtectGui(LinuxUI)
        LinuxUI.Parent = parent
    end)
    
    local ToggleUI = nil
    local ToggleButton = nil
    
    if config.ToggleEnabled ~= false then
        ToggleUI = Linux.Instance("ScreenGui", {
            Name = "LinuxUIToggle",
            Parent = nil,
            ResetOnSpawn = false,
            Enabled = true,
            ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        })
        task.defer(function()
            ProtectGui(ToggleUI)
            ToggleUI.Parent = parent
        end)
        
        ToggleButton = Linux.Instance("ImageButton", {
            Parent = ToggleUI,
            BackgroundColor3 = Color3.fromRGB(30, 30, 30),
            BackgroundTransparency = 0.18,
            BorderSizePixel = 0,
            BorderColor3 = Color3.fromRGB(60, 60, 60),
            Size = UDim2.new(0, 50, 0, 50),
            Position = UDim2.new(0, 20, 0.5, -25),
            Image = "rbxassetid://119686822323882",
            ImageColor3 = Color3.fromRGB(255, 255, 255),
            ZIndex = 1000,
            AutoButtonColor = false
        })
        
        Linux.Instance("UICorner", {
            Parent = ToggleButton,
            CornerRadius = UDim.new(0, 8)
        })
        
        local isDragging = false
        local dragStart = nil
        local startPos = nil
        local hasMoved = false
        
        ToggleButton.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                isDragging = true
                dragStart = input.Position
                startPos = ToggleButton.Position
                hasMoved = false
            end
        end)
        
        ToggleButton.InputChanged:Connect(function(input)
            if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local delta = input.Position - dragStart
                if math.abs(delta.X) > 5 or math.abs(delta.Y) > 5 then
                    hasMoved = true
                    local newX = math.clamp(startPos.X.Offset + delta.X, 0, ToggleUI.AbsoluteSize.X - 50)
                    local newY = math.clamp(startPos.Y.Offset + delta.Y, 0, ToggleUI.AbsoluteSize.Y - 50)
                    ToggleButton.Position = UDim2.new(0, newX, 0, newY)
                end
            end
        end)
        
        ToggleButton.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                if isDragging then
                    isDragging = false
                    if not hasMoved then
                        LinuxUI.Enabled = not LinuxUI.Enabled
                        TweenService:Create(ToggleButton, TweenInfo.new(0.1), {Size = UDim2.new(0, 45, 0, 45)}):Play()
                        task.wait(0.001)
                        TweenService:Create(ToggleButton, TweenInfo.new(0.1), {Size = UDim2.new(0, 50, 0, 50)}):Play()
                    end
                end
            end
        end)
        
        InputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                if isDragging then
                    isDragging = false
                end
            end
        end)
    end
    
    local isMobile = Linux.DeviceType == "Mobile"
    local uiSize = isMobile and (config.SizeMobile or UDim2.fromOffset(300, 500)) or (config.SizePC or UDim2.fromOffset(550, 355))
    
    local Shadow = Linux.Instance("ImageLabel", {
        Parent = LinuxUI,
        Image = "rbxassetid://8992230677",
        ScaleType = "Slice",
        SliceCenter = Rect.new(Vector2.new(99, 99), Vector2.new(99, 99)),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.new(0, uiSize.X.Offset + 120, 0, uiSize.Y.Offset + 116),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        BackgroundTransparency = 1,
        ImageColor3 = Color3.fromRGB(0, 0, 0),
        ImageTransparency = 1,
        ZIndex = 0
    })
    
    local Main = Linux.Instance("Frame", {
        Parent = LinuxUI,
        BackgroundColor3 = Color3.fromRGB(30, 30, 30),
        BorderColor3 = Color3.fromRGB(60, 60, 60),
        BackgroundTransparency = 0.18,
        BorderSizePixel = 0,
        Size = UDim2.new(0, 0, 0, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Active = true,
        Draggable = false,
        ZIndex = 1
    })
    
    Linux.Instance("UICorner", {
        Parent = Main,
        CornerRadius = UDim.new(0, 8)
    })
    
    local isDraggingMain = false
    local dragStartMain = nil
    local startPosMain = nil
    local startPosShadow = nil
    
    local openingTween = TweenInfo.new(0.3, Enum.EasingStyle.Quad)
    local mainSizeTween = TweenService:Create(Main, openingTween, {
        Size = uiSize
    })
    mainSizeTween:Play()
    
    mainSizeTween.Completed:Connect(function()
        local shadowTween = TweenService:Create(Shadow, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
            ImageTransparency = 0.5
        })
        shadowTween:Play()
    end)
    
    local ResizeHandle = Linux.Instance("ImageButton", {
        Parent = Main,
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 20, 0, 20),
        Position = UDim2.new(1, -20, 1, -20),
        Image = "rbxassetid://10723346553",
        ImageColor3 = Color3.fromRGB(120, 120, 130),
        ImageTransparency = 1,
        ZIndex = 100,
        AutoButtonColor = false
    })
    
    local isResizing = false
    local startSize = uiSize
    local startPos = Vector2.new(0, 0)
    local isMinimized = false
    
    ResizeHandle.InputBegan:Connect(function(input)
        if not isMinimized and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            isResizing = true
            startSize = Main.Size
            startPos = Vector2.new(input.Position.X, input.Position.Y)
        end
    end)
    
    ResizeHandle.InputChanged:Connect(function(input)
        if isResizing and not isMinimized and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local currentPos = Vector2.new(input.Position.X, input.Position.Y)
            local delta = currentPos - startPos
            
            local newWidth = math.max(400, startSize.X.Offset + delta.X)
            local newHeight = math.max(300, startSize.Y.Offset + delta.Y)
            
            Main.Size = UDim2.new(0, newWidth, 0, newHeight)
            Shadow.Size = UDim2.new(0, newWidth + 120, 0, newHeight + 116)
        end
    end)
    
    ResizeHandle.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isResizing = false
        end
    end)
    
    InputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if isResizing then
                isResizing = false
            end
        end
    end)
    
    local TopBar = Linux.Instance("Frame", {
        Parent = Main,
        BackgroundColor3 = Color3.fromRGB(30, 30, 30),
        BackgroundTransparency = 0.18,
        BorderColor3 = Color3.fromRGB(60, 60, 60),
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 30),
        ZIndex = 2,
        Active = true,
        Draggable = false
    })
    
    Linux.Instance("UICorner", {
        Parent = TopBar,
        CornerRadius = UDim.new(0, 8)
    })
    
    TopBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDraggingMain = true
            dragStartMain = input.Position
            startPosMain = Main.Position
            startPosShadow = Shadow.Position
        end
    end)
    
    TopBar.InputChanged:Connect(function(input)
        if isDraggingMain and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStartMain
            
            local mainNewX = startPosMain.X.Offset + delta.X
            local mainNewY = startPosMain.Y.Offset + delta.Y
            
            local shadowNewX = startPosShadow.X.Offset + delta.X
            local shadowNewY = startPosShadow.Y.Offset + delta.Y
            
            Main.Position = UDim2.new(startPosMain.X.Scale, mainNewX, startPosMain.Y.Scale, mainNewY)
            Shadow.Position = UDim2.new(startPosShadow.X.Scale, shadowNewX, startPosShadow.Y.Scale, shadowNewY)
        end
    end)
    
    TopBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDraggingMain = false
        end
    end)
    
    InputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if isDraggingMain then
                isDraggingMain = false
            end
        end
    end)
    
    local TopBarLine = Linux.Instance("Frame", {
        Parent = Main,
        BackgroundColor3 = Color3.fromRGB(65, 65, 65),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 1),
        Position = UDim2.new(0, 0, 0, 30),
        ZIndex = 2
    })
    
    local hasLogo = config.Logo and config.Logo ~= ""
    local LogoImage = nil
    local titleOffset = 12
    
    if hasLogo then
        LogoImage = Linux.Instance("ImageLabel", {
            Parent = TopBar,
            BackgroundTransparency = 1,
            Size = UDim2.new(0, 22, 0, 22),
            Position = UDim2.new(0, 10, 0.5, -11),
            Image = config.Logo,
            ImageColor3 = Color3.fromRGB(255, 255, 255),
            ZIndex = 2
        })
        titleOffset = 40
    end
    
    local TitleLabel = Linux.Instance("TextLabel", {
        Parent = TopBar,
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 0, 1, 0),
        Position = UDim2.new(0, titleOffset, 0, 0),
        Font = Enum.Font.GothamBold,
        Text = config.Name or "Linux UI",
        TextColor3 = Color3.fromRGB(240, 240, 240),
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left,
        AutomaticSize = Enum.AutomaticSize.X,
        ZIndex = 2
    })
    
    local SubtitleLabel = nil
    if config.Subtitle then
        SubtitleLabel = Linux.Instance("TextLabel", {
            Parent = TopBar,
            BackgroundTransparency = 1,
            Size = UDim2.new(0, 0, 1, 0),
            Position = UDim2.new(0, TitleLabel.AbsoluteSize.X + titleOffset + 8, 0, 0),
            Font = Enum.Font.GothamSemibold,
            Text = config.Subtitle,
            TextColor3 = Color3.fromRGB(170, 170, 170),
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            AutomaticSize = Enum.AutomaticSize.X,
            TextWrapped = false,
            ZIndex = 2
        })
        
        TitleLabel:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
            SubtitleLabel.Position = UDim2.new(0, TitleLabel.AbsoluteSize.X + titleOffset + 8, 0, 0)
        end)
    end
    
    local MinimizeButton = Linux.Instance("ImageButton", {
        Parent = TopBar,
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 16, 0, 16),
        Position = UDim2.new(1, -46, 0.5, -8),
        Image = "rbxassetid://10734896206",
        ImageColor3 = Color3.fromRGB(240, 240, 240),
        ZIndex = 3
    })
    
    local CloseButton = Linux.Instance("ImageButton", {
        Parent = TopBar,
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 16, 0, 16),
        Position = UDim2.new(1, -26, 0.5, -8),
        Image = "rbxassetid://10747384394",
        ImageColor3 = Color3.fromRGB(240, 240, 240),
        ZIndex = 3
    })
    
    local TabsBar = Linux.Instance("Frame", {
        Parent = Main,
        BackgroundColor3 = Color3.fromRGB(30, 30, 30),
        BackgroundTransparency = 0.18,
        Position = UDim2.new(0, 0, 0, 30),
        Size = UDim2.new(0, config.TabWidth or 130, 1, -30),
        ZIndex = 2,
        BorderSizePixel = 0,
        BorderColor3 = Color3.fromRGB(60, 60, 60)
    })
    
    local ProfileFrame = Linux.Instance("Frame", {
        Parent = TabsBar,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 65),
        Position = UDim2.new(0, 0, 1, -65),
        ZIndex = 3
    })
    
    local ProfileImage = Linux.Instance("ImageLabel", {
        Parent = ProfileFrame,
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 32, 0, 32),
        Position = UDim2.new(0, 10, 0, 10),
        Image = Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48),
        ZIndex = 3
    })
    
    Linux.Instance("UICorner", {
        Parent = ProfileImage,
        CornerRadius = UDim.new(1, 0)
    })
    
    local PlayerDisplayName = Linux.Instance("TextLabel", {
        Parent = ProfileFrame,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -52, 0, 16),
        Position = UDim2.new(0, 50, 0, 10),
        Font = Enum.Font.GothamSemibold,
        Text = Linux.PrivacyEnabled and "Anonymous" or LocalPlayer.DisplayName,
        TextColor3 = Color3.fromRGB(240, 240, 240),
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 3
    })
    
    local PlayerRealName = Linux.Instance("TextLabel", {
        Parent = ProfileFrame,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -52, 0, 14),
        Position = UDim2.new(0, 50, 0, 26),
        Font = Enum.Font.GothamSemibold,
        Text = Linux.PrivacyEnabled and "@Anonymous" or ("@" .. LocalPlayer.Name),
        TextColor3 = Color3.fromRGB(170, 170, 170),
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 3
    })
    
    local function UpdatePrivacyDisplay()
        if Linux.PrivacyEnabled then
            PlayerDisplayName.Text = "Anonymous"
            PlayerRealName.Text = "@Anonymous"
        else
            PlayerDisplayName.Text = LocalPlayer.DisplayName
            PlayerRealName.Text = "@" .. LocalPlayer.Name
        end
    end
    
    local TabHolder = Linux.Instance("ScrollingFrame", {
        Parent = TabsBar,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, 8),
        Size = UDim2.new(1, 0, 1, -73),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 0,
        ZIndex = 2,
        BorderSizePixel = 0,
        BorderColor3 = Color3.fromRGB(60, 60, 60),
        ScrollingEnabled = true
    })
    
    Linux.Instance("UIListLayout", {
        Parent = TabHolder,
        Padding = UDim.new(0, 2),
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        VerticalAlignment = Enum.VerticalAlignment.Top,
        SortOrder = Enum.SortOrder.LayoutOrder
    })
    
    Linux.Instance("UIPadding", {
        Parent = TabHolder,
        PaddingLeft = UDim.new(0, 8),
        PaddingRight = UDim.new(0, 8),
        PaddingTop = UDim.new(0, 8)
    })
    
    local Content = Linux.Instance("Frame", {
        Parent = Main,
        BackgroundColor3 = Color3.fromRGB(30, 30, 30),
        BackgroundTransparency = 0.18,
        Position = UDim2.new(0, config.TabWidth or 130, 0, 30),
        Size = UDim2.new(1, -(config.TabWidth or 130), 1, -30),
        ZIndex = 1,
        BorderSizePixel = 0,
        BorderColor3 = Color3.fromRGB(60, 60, 60)
    })
    
    local originalSize = uiSize
    local minimizedSize = UDim2.new(0, uiSize.X.Offset, 0, 30)
    
    MinimizeButton.MouseEnter:Connect(function()
        TweenService:Create(MinimizeButton, TweenInfo.new(0.2), {ImageColor3 = Color3.fromRGB(255, 255, 255)}):Play()
    end)
    
    MinimizeButton.MouseLeave:Connect(function()
        TweenService:Create(MinimizeButton, TweenInfo.new(0.2), {ImageColor3 = Color3.fromRGB(240, 240, 240)}):Play()
    end)
    
    MinimizeButton.MouseButton1Click:Connect(function()
        isMinimized = not isMinimized
        
        if isMinimized then
            TweenService:Create(Main, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {Size = minimizedSize}):Play()
            TweenService:Create(Shadow, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {ImageTransparency = 1}):Play()
            Content.Visible = false
            TabsBar.Visible = false
            TopBarLine.Visible = false
            MinimizeButton.Image = "rbxassetid://10734886496"
            ResizeHandle.ImageTransparency = 1
            ResizeHandle.Active = false
        else
            TweenService:Create(Main, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {Size = originalSize}):Play()
            TweenService:Create(Shadow, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
                ImageTransparency = 0.5,
                Size = UDim2.new(0, originalSize.X.Offset + 120, 0, originalSize.Y.Offset + 116)
            }):Play()
            Content.Visible = true
            TabsBar.Visible = true
            TopBarLine.Visible = true
            MinimizeButton.Image = "rbxassetid://10734896206"
            ResizeHandle.ImageTransparency = 1
            ResizeHandle.Active = true
        end
    end)
    
    CloseButton.MouseEnter:Connect(function()
        TweenService:Create(CloseButton, TweenInfo.new(0.2), {ImageColor3 = Color3.fromRGB(255, 255, 255)}):Play()
    end)
    
    CloseButton.MouseLeave:Connect(function()
        TweenService:Create(CloseButton, TweenInfo.new(0.2), {ImageColor3 = Color3.fromRGB(240, 240, 240)}):Play()
    end)
    
    CloseButton.MouseButton1Click:Connect(function()
        LinuxUI:Destroy()
        if ToggleUI then
            ToggleUI:Destroy()
        end
    end)
    
    InputService.InputBegan:Connect(function(input)
        if input.KeyCode == Enum.KeyCode.LeftAlt then
            LinuxUI.Enabled = not LinuxUI.Enabled
        end
    end)
    
    local LinuxLib = {}
    local Tabs = {}
    local AllElements = {}
    local CurrentTab = nil
    local tabOrder = 0
    local DefaultTab = nil
    Linux.SavedElements = {}
    
    local function AnimateTabSliders(tabIndex)
        spawn(function()
            if Tabs[tabIndex] and Tabs[tabIndex].Elements then
                for _, elementData in pairs(Tabs[tabIndex].Elements) do
                    if elementData.Type == "Slider" then
                        local slider = elementData.Instance
                        local fillBar = slider:FindFirstChild("Bar") and slider.Bar:FindFirstChild("Fill")
                        local knob = slider:FindFirstChild("Bar") and slider.Bar:FindFirstChild("Knob")
                        
                        if fillBar and knob then
                            local currentValue = slider:GetAttribute("Value")
                            local min = slider:GetAttribute("Min")
                            local max = slider:GetAttribute("Max")
                            local targetPos = (currentValue - min) / (max - min)
                            
                            fillBar.Size = UDim2.new(0, 0, 1, 0)
                            knob.Position = UDim2.new(0, -6, 0.5, -6)
                            
                            local tween = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                            TweenService:Create(fillBar, tween, {Size = UDim2.new(targetPos, 0, 1, 0)}):Play()
                            TweenService:Create(knob, tween, {Position = UDim2.new(targetPos, -6, 0.5, -6)}):Play()
                        end
                    end
                end
            end
        end)
    end
    
    local function AnimateTabTransition(newTabContent)
        spawn(function()
            local containerWrapper = newTabContent:FindFirstChild("Frame")
            if containerWrapper then
                containerWrapper.Position = UDim2.new(0, 12, 0, 25)
                local slideDownTween = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                TweenService:Create(containerWrapper, slideDownTween, {
                    Position = UDim2.new(0, 12, 0, 55)
                }):Play()
            end
        end)
    end
    
    local function CheckEmptyState()
        for tabIndex, tab in pairs(Tabs) do
            if tab and tab.EmptyStateFrame then
                local hasVisibleElements = false
                for _, elementData in pairs(tab.Elements) do
                    if elementData.Instance.Parent == tab.Container and elementData.Instance.Visible and elementData.Type ~= "Section" then
                        hasVisibleElements = true
                        break
                    end
                end
                
                if hasVisibleElements then
                    tab.EmptyStateFrame.Visible = false
                    tab.ContainerWrapper.Visible = true
                else
                    tab.EmptyStateFrame.Visible = true
                    tab.ContainerWrapper.Visible = true
                end
            end
        end
    end
    
    function LinuxLib.Tab(config)
        tabOrder = tabOrder + 1
        local tabIndex = tabOrder
        
        local TabBtn = Linux.Instance("TextButton", {
            Parent = TabHolder,
            BackgroundColor3 = Color3.fromRGB(70, 70, 70),
            BackgroundTransparency = 0.82,
            BorderColor3 = Color3.fromRGB(25, 25, 25),
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 32),
            Font = Enum.Font.GothamSemibold,
            Text = "",
            TextColor3 = Color3.fromRGB(240, 240, 240),
            TextSize = 14,
            ZIndex = 2,
            AutoButtonColor = false,
            LayoutOrder = tabIndex
        })
        
        Linux.Instance("UICorner", {
            Parent = TabBtn,
            CornerRadius = UDim.new(0, 6)
        })
        
        local TabAccentBar = Linux.Instance("Frame", {
            Parent = TabBtn,
            BackgroundColor3 = Linux.Themes[Linux.CurrentTheme],
            BackgroundTransparency = 0,
            BorderSizePixel = 0,
            Size = UDim2.new(0, 0, 0, 24),
            Position = UDim2.new(0, 0, 0.5, -12),
            ZIndex = 3
        })
        
        Linux.Instance("UICorner", {
            Parent = TabAccentBar,
            CornerRadius = UDim.new(0, 2)
        })
        
        Linux.RegisterAccentElement(TabAccentBar)
        
        local TabIcon
        if config.Icon and config.Enabled then
            TabIcon = Linux.Instance("ImageLabel", {
                Parent = TabBtn,
                BackgroundTransparency = 1,
                Size = UDim2.new(0, 18, 0, 18),
                Position = UDim2.new(0, 10, 0.5, -9),
                Image = config.Icon,
                ImageColor3 = Color3.fromRGB(240, 240, 240),
                ZIndex = 2
            })
        end
        
        local textOffset = config.Icon and config.Enabled and 33 or 16
        
        local TabText = Linux.Instance("TextLabel", {
            Parent = TabBtn,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -(textOffset + 20), 1, 0),
            Position = UDim2.new(0, textOffset, 0, 0),
            Font = Enum.Font.GothamSemibold,
            Text = config.Name,
            TextColor3 = Color3.fromRGB(240, 240, 240),
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 2
        })
        
        local TabContent = Linux.Instance("Frame", {
            Parent = Content,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 1, 0),
            Visible = false,
            ZIndex = 1,
            BorderSizePixel = 0,
            BorderColor3 = Color3.fromRGB(60, 60, 60)
        })
        
        local TitleFrame = Linux.Instance("Frame", {
            Parent = Content,
            BackgroundColor3 = Color3.fromRGB(30, 30, 30),
            BackgroundTransparency = 0.18,
            Size = UDim2.new(1, 0, 0, 50),
            Position = UDim2.new(0, 0, 0, 0),
            Visible = false,
            ZIndex = 3,
            BorderSizePixel = 0,
            BorderColor3 = Color3.fromRGB(60, 60, 60)
        })
        
        local TitleLabel = Linux.Instance("TextLabel", {
            Parent = TitleFrame,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -20, 1, 0),
            Position = UDim2.new(0, 10, 0, 10),
            Font = Enum.Font.GothamBold,
            Text = config.Name,
            TextColor3 = Color3.fromRGB(240, 240, 240),
            TextSize = 24,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            ZIndex = 4
        })
        
        local ContainerWrapper = Linux.Instance("Frame", {
            Parent = TabContent,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -16, 1, -70),
            Position = UDim2.new(0, 12, 0, 55),
            ZIndex = 1,
            BorderSizePixel = 0,
            BorderColor3 = Color3.fromRGB(60, 60, 60)
        })
        
        local Container = Linux.Instance("ScrollingFrame", {
            Parent = ContainerWrapper,
            BackgroundColor3 = Color3.fromRGB(30, 30, 30),
            BackgroundTransparency = 0.18,
            Size = UDim2.new(1, 0, 1, 0),
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollBarThickness = 0,
            ZIndex = 1,
            BorderSizePixel = 0,
            BorderColor3 = Color3.fromRGB(60, 60, 60),
            ScrollingEnabled = true,
            CanvasPosition = Vector2.new(0, 0)
        })
        
        local ContainerListLayout = Linux.Instance("UIListLayout", {
            Parent = Container,
            Padding = UDim.new(0, 3),
            HorizontalAlignment = Enum.HorizontalAlignment.Left,
            VerticalAlignment = Enum.VerticalAlignment.Top,
            SortOrder = Enum.SortOrder.LayoutOrder
        })
        
        Linux.Instance("UIPadding", {
            Parent = Container,
            PaddingLeft = UDim.new(0, 2),
            PaddingTop = UDim.new(0, 2)
        })
        
        local EmptyStateFrame = Linux.Instance("Frame", {
            Parent = TabContent,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 1, 0),
            Position = UDim2.new(0, 0, 0, 0),
            Visible = false,
            ZIndex = 5
        })
        
        local EmptyIcon = Linux.Instance("ImageLabel", {
            Parent = EmptyStateFrame,
            BackgroundTransparency = 1,
            Size = UDim2.new(0, 80, 0, 80),
            Position = UDim2.new(0.5, -40, 0.5, -60),
            Image = "rbxassetid://10723394681",
            ImageColor3 = Color3.fromRGB(170, 170, 170),
            ZIndex = 5
        })
        
        local EmptyText = Linux.Instance("TextLabel", {
            Parent = EmptyStateFrame,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -40, 0, 30),
            Position = UDim2.new(0, 20, 0.5, 30),
            Font = Enum.Font.GothamSemibold,
            Text = "Looks like there's nothing here",
            TextColor3 = Color3.fromRGB(170, 170, 170),
            TextSize = 16,
            TextXAlignment = Enum.TextXAlignment.Center,
            ZIndex = 5
        })
        
        local function SelectTab()
            if CurrentTab == tabIndex then
                return
            end
            
            local tweenInfoShrink = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            local tweenInfoExpand = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            if CurrentTab and Tabs[CurrentTab] then
                local oldTab = Tabs[CurrentTab]
                oldTab.Content.Visible = false
                oldTab.TitleFrame.Visible = false
                oldTab.ContainerWrapper.Visible = false
                oldTab.Text.TextColor3 = Color3.fromRGB(240, 240, 240)
                
                if oldTab.Icon then
                    oldTab.Icon.ImageColor3 = Color3.fromRGB(240, 240, 240)
                end
                TweenService:Create(oldTab.TabAccentBar, tweenInfoShrink, {Size = UDim2.new(0, 0, 0, 24)}):Play()
            end
            
            TabContent.Visible = true
            TitleFrame.Visible = true
            
            ContainerWrapper.Position = UDim2.new(0, 12, 0, 25)
            ContainerWrapper.Visible = true
            
            local slideDownTween = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            TweenService:Create(ContainerWrapper, slideDownTween, {
                Position = UDim2.new(0, 12, 0, 55)
            }):Play()
            
            TabText.TextColor3 = Color3.fromRGB(255, 255, 255)
            
            if TabIcon then
                TabIcon.ImageColor3 = Color3.fromRGB(255, 255, 255)
            end
            
            TweenService:Create(TabAccentBar, tweenInfoExpand, {Size = UDim2.new(0, 4, 0, 24)}):Play()
            CurrentTab = tabIndex
            Linux.CurrentTab = tabIndex
            Container.CanvasPosition = Vector2.new(0, 0)
            AnimateTabSliders(tabIndex)
            
            CheckEmptyState()
        end
        
        TabBtn.MouseButton1Click:Connect(SelectTab)
        
        Tabs[tabIndex] = {
            Name = config.Name,
            Button = TabBtn,
            Text = TabText,
            Icon = TabIcon,
            Content = TabContent,
            TitleFrame = TitleFrame,
            Elements = {},
            EmptyStateFrame = EmptyStateFrame,
            ContainerWrapper = ContainerWrapper,
            Container = Container,
            ContainerListLayout = ContainerListLayout,
            ElementOrder = 0,
            LastWasDropdown = false,
            TabAccentBar = TabAccentBar
        }
        
        if config.Default == true then
            DefaultTab = tabIndex
            task.spawn(function()
                task.wait(0.1)
                SelectTab()
            end)
        elseif CurrentTab == nil and tabOrder == 1 then
            DefaultTab = tabIndex
            task.spawn(function()
                task.wait(0.1)
                SelectTab()
            end)
        end
        
        local TabElements = {}
        
        local function getTargetContainer()
            return Tabs[tabIndex].Container, Tabs[tabIndex].ContainerListLayout
        end
        
        local function updateElementOrder(isDropdown)
            Tabs[tabIndex].ElementOrder = Tabs[tabIndex].ElementOrder + 1
            if Tabs[tabIndex].LastWasDropdown then
                Tabs[tabIndex].ContainerListLayout.Padding = UDim.new(0, 7)
            else
                Tabs[tabIndex].ContainerListLayout.Padding = UDim.new(0, 3)
            end
            Tabs[tabIndex].LastWasDropdown = isDropdown
            return Tabs[tabIndex].ElementOrder
        end
        
        function TabElements.Button(config)
            local targetContainer, targetListLayout = getTargetContainer()
            local currentElementOrder = updateElementOrder(false)
            
            local hasDescription = config.Description and config.Description ~= ""
            local frameHeight = 36
            
            local BtnFrame = Linux.Instance("Frame", {
                Parent = targetContainer,
                BackgroundColor3 = Color3.fromRGB(70, 70, 70),
                BackgroundTransparency = 0.82,
                BorderColor3 = Color3.fromRGB(25, 25, 25),
                BorderSizePixel = 0,
                Size = UDim2.new(1, 0, 0, frameHeight),
                ZIndex = 1,
                LayoutOrder = currentElementOrder
            })
            
            Linux.Instance("UICorner", {
                Parent = BtnFrame,
                CornerRadius = UDim.new(0, 4)
            })
            
            local Btn = Linux.Instance("TextButton", {
                Parent = BtnFrame,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 1, 0),
                Position = UDim2.new(0, 0, 0, 0),
                Font = Enum.Font.GothamSemibold,
                Text = config.Name,
                TextColor3 = Color3.fromRGB(240, 240, 240),
                TextSize = 14,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 2,
                AutoButtonColor = false
            })
            
            if hasDescription then
                Btn.Position = UDim2.new(0, 0, 0, -8)
            end
            
            Linux.Instance("UIPadding", {
                Parent = Btn,
                PaddingLeft = UDim.new(0, 10)
            })
            
            if hasDescription then
                Linux.Instance("TextLabel", {
                    Parent = BtnFrame,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, -20, 0, 12),
                    Position = UDim2.new(0, 10, 0, 18),
                    Font = Enum.Font.GothamSemibold,
                    Text = config.Description,
                    TextColor3 = Color3.fromRGB(170, 170, 170),
                    TextSize = 12,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextWrapped = true,
                    ZIndex = 2
                })
            end
            
            Btn.MouseEnter:Connect(function()
                TweenService:Create(BtnFrame, TweenInfo.new(0.2), {BackgroundTransparency = 0.75}):Play()
            end)
            
            Btn.MouseLeave:Connect(function()
                TweenService:Create(BtnFrame, TweenInfo.new(0.2), {BackgroundTransparency = 0.82}):Play()
            end)
            
            Btn.MouseButton1Down:Connect(function()
                TweenService:Create(BtnFrame, TweenInfo.new(0.1), {BackgroundTransparency = 0.89}):Play()
            end)
            
            Btn.MouseButton1Up:Connect(function()
                TweenService:Create(BtnFrame, TweenInfo.new(0.1), {BackgroundTransparency = 0.75}):Play()
            end)
            
            local function createConfirmationDialog(confirmationConfig)
                
                local ConfirmationOverlay = Linux.Instance("Frame", {
                    Parent = Main,
                    BackgroundColor3 = Color3.fromRGB(0, 0, 0),
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 1, 0),
                    Position = UDim2.new(0, 0, 0, 0),
                    ZIndex = 1000,
                    Active = true
                })
                
                Linux.Instance("UICorner", {
                    Parent = ConfirmationOverlay,
                    CornerRadius = UDim.new(0, 8)
                })
                
                local overlayTween = TweenService:Create(ConfirmationOverlay, TweenInfo.new(0.2), {BackgroundTransparency = 0.5})
                overlayTween:Play()
                
                for _, element in pairs(Main:GetDescendants()) do
                    if element:IsA("TextButton") or element:IsA("TextBox") or element:IsA("ImageButton") then
                        if element ~= ConfirmationOverlay and not element:IsDescendantOf(ConfirmationOverlay) then
                            element.Active = false
                        end
                    end
                end
                
                local DialogFrame = Linux.Instance("Frame", {
                    Parent = ConfirmationOverlay,
                    BackgroundColor3 = Color3.fromRGB(30, 30, 30),
                    BorderColor3 = Color3.fromRGB(60, 60, 60),
                    BorderSizePixel = 0,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(0, 300, 0, 150),
                    Position = UDim2.new(0.5, -150, 0.5, -75),
                    ZIndex = 1001
                })
                
                Linux.Instance("UICorner", {
                    Parent = DialogFrame,
                    CornerRadius = UDim.new(0, 8)
                })
                
                local dialogTween = TweenService:Create(DialogFrame, TweenInfo.new(0.2), {BackgroundTransparency = 0.18})
                dialogTween:Play()
                
                local TitleLabel = Linux.Instance("TextLabel", {
                    Parent = DialogFrame,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, -20, 0, 30),
                    Position = UDim2.new(0, 10, 0, 10),
                    Font = Enum.Font.GothamBold,
                    Text = confirmationConfig.Title or "Confirm",
                    TextColor3 = Color3.fromRGB(240, 240, 240),
                    TextSize = 16,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 1002
                })
                
                local ContentLabel = Linux.Instance("TextLabel", {
                    Parent = DialogFrame,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, -20, 0, 50),
                    Position = UDim2.new(0, 10, 0, 45),
                    Font = Enum.Font.GothamSemibold,
                    Text = confirmationConfig.Content or "Are you sure?",
                    TextColor3 = Color3.fromRGB(170, 170, 170),
                    TextSize = 14,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextWrapped = true,
                    ZIndex = 1002
                })
                
                local ButtonsFrame = Linux.Instance("Frame", {
                    Parent = DialogFrame,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, -20, 0, 40),
                    Position = UDim2.new(0, 10, 1, -50),
                    ZIndex = 1002
                })
                
                Linux.Instance("UIListLayout", {
                    Parent = ButtonsFrame,
                    FillDirection = Enum.FillDirection.Horizontal,
                    HorizontalAlignment = Enum.HorizontalAlignment.Right,
                    VerticalAlignment = Enum.VerticalAlignment.Center,
                    Padding = UDim.new(0, 10)
                })
                
                local function closeDialog()
                    local closeTweenOverlay = TweenService:Create(ConfirmationOverlay, TweenInfo.new(0.15), {BackgroundTransparency = 1})
                    local closeTweenDialog = TweenService:Create(DialogFrame, TweenInfo.new(0.15), {BackgroundTransparency = 1})
                    
                    closeTweenOverlay:Play()
                    closeTweenDialog:Play()
                    
                    closeTweenDialog.Completed:Wait()
                    
                    for _, element in pairs(Main:GetDescendants()) do
                        if element:IsA("TextButton") or element:IsA("TextBox") or element:IsA("ImageButton") then
                            element.Active = true
                        end
                    end
                    ConfirmationOverlay:Destroy()
                end
                
                if confirmationConfig.Buttons then
                    for i, buttonConfig in ipairs(confirmationConfig.Buttons) do
                        local DialogButton = Linux.Instance("TextButton", {
                            Parent = ButtonsFrame,
                            BackgroundColor3 = i == 1 and Linux.Themes[Linux.CurrentTheme] or Color3.fromRGB(70, 70, 70),
                            BorderSizePixel = 0,
                            BorderColor3 = Color3.fromRGB(25, 25, 25),
                            Size = UDim2.new(0, 80, 0, 30),
                            Font = Enum.Font.GothamSemibold,
                            Text = buttonConfig.Title or "Button",
                            TextColor3 = Color3.fromRGB(255, 255, 255),
                            TextSize = 14,
                            ZIndex = 1003,
                            AutoButtonColor = false,
                            Active = true
                        })
                        
                        Linux.Instance("UICorner", {
                            Parent = DialogButton,
                            CornerRadius = UDim.new(0, 4)
                        })
                        
                        DialogButton.MouseEnter:Connect(function()
                            TweenService:Create(DialogButton, TweenInfo.new(0.2), {
                                BackgroundColor3 = i == 1 and Color3.fromRGB(
                                    math.min(255, Linux.Themes[Linux.CurrentTheme].R * 255 + 20),
                                    math.min(255, Linux.Themes[Linux.CurrentTheme].G * 255 + 20),
                                    math.min(255, Linux.Themes[Linux.CurrentTheme].B * 255 + 20)
                                ) or Color3.fromRGB(100, 100, 100)
                            }):Play()
                        end)
                        
                        DialogButton.MouseLeave:Connect(function()
                            TweenService:Create(DialogButton, TweenInfo.new(0.2), {
                                BackgroundColor3 = i == 1 and Linux.Themes[Linux.CurrentTheme] or Color3.fromRGB(70, 70, 70)
                            }):Play()
                        end)
                        
                        DialogButton.MouseButton1Click:Connect(function()
                            closeDialog()
                            if buttonConfig.Callback then
                                spawn(function() Linux:SafeCallback(buttonConfig.Callback) end)
                            end
                        end)
                    end
                end
                
                ConfirmationOverlay.MouseButton1Click:Connect(function()
                    closeDialog()
                end)
                
                DialogFrame.MouseButton1Click:Connect(function() end)
            end
            
            Btn.MouseButton1Click:Connect(function()
                if config.Confirmation then
                    createConfirmationDialog(config.Confirmation)
                else
                    spawn(function() Linux:SafeCallback(config.Callback) end)
                end
            end)
            
            targetContainer.CanvasPosition = Vector2.new(0, 0)
            
            local element = {
                Type = "Button",
                Name = config.Name,
                Instance = BtnFrame
            }
            table.insert(Tabs[tabIndex].Elements, element)
            table.insert(AllElements, {Tab = tabIndex, Element = element})
            
            CheckEmptyState()
            
            return Btn
        end
        
        function TabElements.Toggle(config)
            local targetContainer, targetListLayout = getTargetContainer()
            local currentElementOrder = updateElementOrder(false)
            
            local hasDescription = config.Description and config.Description ~= ""
            local frameHeight = 36
            
            local Toggle = Linux.Instance("Frame", {
                Parent = targetContainer,
                BackgroundColor3 = Color3.fromRGB(70, 70, 70),
                BackgroundTransparency = 0.82,
                BorderColor3 = Color3.fromRGB(25, 25, 25),
                BorderSizePixel = 0,
                Size = UDim2.new(1, 0, 0, frameHeight),
                ZIndex = 1,
                LayoutOrder = currentElementOrder
            })
            
            Linux.Instance("UICorner", {
                Parent = Toggle,
                CornerRadius = UDim.new(0, 4)
            })
            
            local ToggleText = Linux.Instance("TextLabel", {
                Parent = Toggle,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, -60, 1, 0),
                Position = hasDescription and UDim2.new(0, 10, 0, -8) or UDim2.new(0, 10, 0, 0),
                Font = Enum.Font.GothamSemibold,
                Text = config.Name,
                TextColor3 = Color3.fromRGB(240, 240, 240),
                TextSize = 14,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 2,
                Name = "ToggleText"
            })
            
            if hasDescription then
                Linux.Instance("TextLabel", {
                    Parent = Toggle,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, -70, 0, 12),
                    Position = UDim2.new(0, 10, 0, 18),
                    Font = Enum.Font.GothamSemibold,
                    Text = config.Description,
                    TextColor3 = Color3.fromRGB(170, 170, 170),
                    TextSize = 12,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextWrapped = true,
                    ZIndex = 2
                })
            end
            
            local ToggleTrack = Linux.Instance("Frame", {
                Parent = Toggle,
                BackgroundColor3 = Color3.fromRGB(100, 100, 100),
                Size = UDim2.new(0, 36, 0, 18),
                Position = UDim2.new(1, -46, 0.5, -9),
                ZIndex = 2,
                BorderSizePixel = 0,
                BorderColor3 = Color3.fromRGB(55, 55, 55),
                Name = "Track"
            })
            
            Linux.Instance("UICorner", {
                Parent = ToggleTrack,
                CornerRadius = UDim.new(1, 0)
            })
            
            Linux.Instance("UIStroke", {
                Parent = ToggleTrack,
                Color = Color3.fromRGB(55, 55, 55),
                Thickness = 1
            })
            
            local ToggleKnob = Linux.Instance("Frame", {
                Parent = ToggleTrack,
                BackgroundColor3 = Color3.fromRGB(240, 240, 240),
                Size = UDim2.new(0, 14, 0, 14),
                Position = UDim2.new(0, 2, 0.5, -7),
                ZIndex = 3,
                BorderSizePixel = 0,
                BorderColor3 = Color3.fromRGB(55, 55, 55),
                Name = "Knob"
            })
            
            Linux.Instance("UICorner", {
                Parent = ToggleKnob,
                CornerRadius = UDim.new(1, 0)
            })
            
            local State = config.Default or false
            Toggle:SetAttribute("State", State)
            
            local isToggling = false
            local isDragToggle = false
            local dragStartToggle = nil
            local hasMovedToggle = false
            
            local function UpdateToggle(thisToggle)
                if isToggling then return end
                isToggling = true
                
                local currentState = thisToggle:GetAttribute("State")
                local thisTrack = thisToggle:FindFirstChild("Track")
                local thisKnob = thisTrack and thisTrack:FindFirstChild("Knob")
                
                if thisTrack and thisKnob then
                    local tween = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                    if currentState then
                        TweenService:Create(thisTrack, tween, {BackgroundColor3 = Linux.Themes[Linux.CurrentTheme]}):Play()
                        TweenService:Create(thisKnob, tween, {Position = UDim2.new(0, 20, 0.5, -7), BackgroundColor3 = Color3.fromRGB(255, 255, 255)}):Play()
                        
                        local isAlreadyRegistered = false
                        for _, element in pairs(Linux.AccentElements) do
                            if element == thisTrack then
                                isAlreadyRegistered = true
                                break
                            end
                        end
                        if not isAlreadyRegistered then
                            Linux.RegisterAccentElement(thisTrack)
                        end
                    else
                        TweenService:Create(thisTrack, tween, {BackgroundColor3 = Color3.fromRGB(100, 100, 100)}):Play()
                        TweenService:Create(thisKnob, tween, {Position = UDim2.new(0, 2, 0.5, -7), BackgroundColor3 = Color3.fromRGB(240, 240, 240)}):Play()
                        
                        for i, element in pairs(Linux.AccentElements) do
                            if element == thisTrack then
                                table.remove(Linux.AccentElements, i)
                                break
                            end
                        end
                    end
                end
                
                task.wait(0.25)
                isToggling = false
            end
            
            local function SetValue(newState)
                Toggle:SetAttribute("State", newState)
                UpdateToggle(Toggle)
                spawn(function() Linux:SafeCallback(config.Callback, newState) end)
            end
            
            UpdateToggle(Toggle)
            spawn(function() Linux:SafeCallback(config.Callback, State) end)
            
            local function toggleSwitch()
                if not isToggling and not hasMovedToggle then
                    local newState = not Toggle:GetAttribute("State")
                    SetValue(newState)
                end
            end
            
            ToggleTrack.InputBegan:Connect(function(input)
                if (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1) then
                    isDragToggle = true
                    dragStartToggle = input.Position
                    hasMovedToggle = false
                end
            end)
            
            ToggleTrack.InputChanged:Connect(function(input)
                if isDragToggle and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                    local delta = input.Position - dragStartToggle
                    if math.abs(delta.X) > 5 or math.abs(delta.Y) > 5 then
                        hasMovedToggle = true
                    end
                end
            end)
            
            ToggleTrack.InputEnded:Connect(function(input)
                if (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1) then
                    if isDragToggle then
                        isDragToggle = false
                        if not hasMovedToggle then
                            toggleSwitch()
                        end
                        hasMovedToggle = false
                    end
                end
            end)
            
            ToggleKnob.InputBegan:Connect(function(input)
                if (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1) then
                    isDragToggle = true
                    dragStartToggle = input.Position
                    hasMovedToggle = false
                end
            end)
            
            ToggleKnob.InputChanged:Connect(function(input)
                if isDragToggle and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                    local delta = input.Position - dragStartToggle
                    if math.abs(delta.X) > 5 or math.abs(delta.Y) > 5 then
                        hasMovedToggle = true
                    end
                end
            end)
            
            ToggleKnob.InputEnded:Connect(function(input)
                if (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1) then
                    if isDragToggle then
                        isDragToggle = false
                        if not hasMovedToggle then
                            toggleSwitch()
                        end
                        hasMovedToggle = false
                    end
                end
            end)
            
            InputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    if isDragToggle then
                        isDragToggle = false
                        hasMovedToggle = false
                    end
                end
            end)
            
            targetContainer.CanvasPosition = Vector2.new(0, 0)
            
            local element = {
                Type = "Toggle",
                Name = config.Name,
                Instance = Toggle,
                State = State
            }
            table.insert(Tabs[tabIndex].Elements, element)
            table.insert(AllElements, {Tab = tabIndex, Element = element})
            
            table.insert(Linux.SavedElements, {
                Element = element,
                TabName = Tabs[tabIndex].Name,
                GetValue = function() return Toggle:GetAttribute("State") end,
                SetValue = SetValue
            })
            
            CheckEmptyState()
            
            return Toggle
        end
        
        function TabElements.Dropdown(config)
            local targetContainer, targetListLayout = getTargetContainer()
            local currentElementOrder = updateElementOrder(true)
            
            local hasDescription = config.Description and config.Description ~= ""
            local frameHeight = 36
            
            local Dropdown = Linux.Instance("Frame", {
                Parent = targetContainer,
                BackgroundColor3 = Color3.fromRGB(70, 70, 70),
                BackgroundTransparency = 0.82,
                BorderColor3 = Color3.fromRGB(25, 25, 25),
                BorderSizePixel = 0,
                Size = UDim2.new(1, 0, 0, frameHeight),
                ZIndex = 1,
                LayoutOrder = currentElementOrder
            })
            
            Linux.Instance("UICorner", {
                Parent = Dropdown,
                CornerRadius = UDim.new(0, 4)
            })
            
            local DropdownButton = Linux.Instance("TextButton", {
                Parent = Dropdown,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 1, 0),
                Font = Enum.Font.GothamSemibold,
                Text = "",
                TextColor3 = Color3.fromRGB(240, 240, 240),
                TextSize = 14,
                ZIndex = 2,
                AutoButtonColor = false
            })
            
            Linux.Instance("TextLabel", {
                Parent = DropdownButton,
                BackgroundTransparency = 1,
                Size = UDim2.new(0.6, 0, 1, 0),
                Position = hasDescription and UDim2.new(0, 10, 0, -8) or UDim2.new(0, 10, 0, 0),
                Font = Enum.Font.GothamSemibold,
                Text = config.Name,
                TextColor3 = Color3.fromRGB(240, 240, 240),
                TextSize = 14,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 2
            })
            
            if hasDescription then
                Linux.Instance("TextLabel", {
                    Parent = DropdownButton,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(0.6, -10, 0, 12),
                    Position = UDim2.new(0, 10, 0, 18),
                    Font = Enum.Font.GothamSemibold,
                    Text = config.Description,
                    TextColor3 = Color3.fromRGB(170, 170, 170),
                    TextSize = 12,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextWrapped = true,
                    ZIndex = 2
                })
            end
            
            local Options = config.Options or {}
            local SelectedValue = config.Default or (Options[1] or "None")
            local IsMulti = config.Multi or false
            local SelectedValues = {}
            
            if IsMulti then
                if typeof(config.Default) == "table" then
                    for _, value in pairs(config.Default) do
                        if table.find(Options, value) then
                            table.insert(SelectedValues, value)
                        end
                    end
                elseif config.Default and table.find(Options, config.Default) then
                    table.insert(SelectedValues, config.Default)
                end
            end
            
            local function FormatDisplayText(value)
                if typeof(value) == "table" then
                    if #value > 0 then
                        local displayText = table.concat(value, ", ")
                        return displayText:sub(1, 20) .. (#displayText > 20 and "..." or "")
                    else
                        return "None"
                    end
                else
                    return value and tostring(value) or "None"
                end
            end
            
            local Selected = Linux.Instance("TextLabel", {
                Parent = DropdownButton,
                BackgroundTransparency = 1,
                Size = UDim2.new(0.3, -21, 1, 0),
                Position = UDim2.new(0.65, 5, 0, 0),
                Font = Enum.Font.GothamSemibold,
                Text = IsMulti and FormatDisplayText(SelectedValues) or FormatDisplayText(SelectedValue),
                TextColor3 = Color3.fromRGB(255, 255, 255),
                TextSize = 14,
                TextXAlignment = Enum.TextXAlignment.Right,
                ZIndex = 2
            })
            
            local Arrow = Linux.Instance("ImageLabel", {
                Parent = DropdownButton,
                BackgroundTransparency = 1,
                Size = UDim2.new(0, 16, 0, 16),
                Position = UDim2.new(1, -26, 0.5, -8),
                Image = "https://www.roblox.com/asset/?id=10709791437",
                ImageColor3 = Color3.fromRGB(240, 240, 240),
                Rotation = 0,
                ZIndex = 2
            })
            
            local DropFrame = Linux.Instance("Frame", {
                Parent = targetContainer,
                BackgroundColor3 = Color3.fromRGB(70, 70, 70),
                BackgroundTransparency = 1,
                BorderColor3 = Color3.fromRGB(25, 25, 25),
                BorderSizePixel = 0,
                Size = UDim2.new(1, 0, 0, 0),
                ZIndex = 2,
                LayoutOrder = currentElementOrder + 1,
                ClipsDescendants = true,
                Visible = false
            })
            
            Linux.Instance("UICorner", {
                Parent = DropFrame,
                CornerRadius = UDim.new(0, 4)
            })

            local OptionsHolder = Linux.Instance("ScrollingFrame", {
                Parent = DropFrame,
                BackgroundColor3 = Color3.fromRGB(70, 70, 70),
                BackgroundTransparency = 0.82,
                Size = UDim2.new(1, 0, 1, 0),
                CanvasSize = UDim2.new(0, 0, 0, 0),
                AutomaticCanvasSize = Enum.AutomaticSize.Y,
                ScrollBarThickness = 0,
                ZIndex = 2,
                BorderSizePixel = 0,
                BorderColor3 = Color3.fromRGB(25, 25, 25),
                ScrollingEnabled = true
            })
            
            Linux.Instance("UIListLayout", {
                Parent = OptionsHolder,
                Padding = UDim.new(0, 2),
                HorizontalAlignment = Enum.HorizontalAlignment.Center,
                SortOrder = Enum.SortOrder.LayoutOrder
            })
            
            Linux.Instance("UIPadding", {
                Parent = OptionsHolder,
                PaddingLeft = UDim.new(0, 5),
                PaddingRight = UDim.new(0, 5),
                PaddingTop = UDim.new(0, 5),
                PaddingBottom = UDim.new(0, 5)
            })
            
            local IsOpen = false
            
            local function UpdateDropSize()
                local optionHeight = 28
                local paddingBetween = 2
                local paddingTopBottom = 10
                local maxHeight = 150
                local numOptions = #Options
                local calculatedHeight = numOptions * optionHeight + (numOptions > 0 and (numOptions - 1) * paddingBetween + paddingTopBottom or 0)
                local finalHeight = math.min(calculatedHeight, maxHeight)
                
                local tween = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                
                if IsOpen then
                    DropFrame.Visible = true
                    DropFrame.Size = UDim2.new(1, 0, 0, 0)
                    TweenService:Create(DropFrame, tween, {Size = UDim2.new(1, 0, 0, finalHeight)}):Play()
                    if #Options > 0 then
                        TweenService:Create(Arrow, tween, {Rotation = 85}):Play()
                    end
                else
                    TweenService:Create(DropFrame, tween, {Size = UDim2.new(1, 0, 0, 0)}):Play()
                    if #Options > 0 then
                        TweenService:Create(Arrow, tween, {Rotation = 0}):Play()
                    end
                    task.delay(0.25, function()
                        if not IsOpen then
                            DropFrame.Visible = false
                        end
                    end)
                end
            end
            
            local function UpdateSelectedText()
                if IsMulti then
                    Selected.Text = FormatDisplayText(SelectedValues)
                else
                    Selected.Text = FormatDisplayText(SelectedValue)
                end
            end
            
            local function PopulateOptions()
                for _, child in pairs(OptionsHolder:GetChildren()) do
                    if child:IsA("TextButton") then
                        child:Destroy()
                    end
                end
                
                if IsOpen then
                    for i, opt in pairs(Options) do
                        local isSelected = IsMulti and table.find(SelectedValues, opt) or opt == SelectedValue
                        
                        local OptBtn = Linux.Instance("TextButton", {
                            Parent = OptionsHolder,
                            BackgroundColor3 = Color3.fromRGB(100, 100, 100),
                            BackgroundTransparency = 1,
                            BorderColor3 = Color3.fromRGB(25, 25, 25),
                            BorderSizePixel = 0,
                            Size = UDim2.new(1, -4, 0, 28),
                            Font = Enum.Font.GothamSemibold,
                            Text = tostring(opt),
                            TextColor3 = isSelected and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(170, 170, 170),
                            TextSize = 14,
                            ZIndex = 3,
                            AutoButtonColor = false,
                            LayoutOrder = i
                        })
                        
                        Linux.Instance("UICorner", {
                            Parent = OptBtn,
                            CornerRadius = UDim.new(0, 6)
                        })
                        
                        local OptAccentBar = Linux.Instance("Frame", {
                            Parent = OptBtn,
                            BackgroundColor3 = Linux.Themes[Linux.CurrentTheme],
                            BackgroundTransparency = 0,
                            BorderSizePixel = 0,
                            Size = isSelected and UDim2.new(0, 4, 0, 20) or UDim2.new(0, 0, 0, 20),
                            Position = UDim2.new(0, 0, 0.5, -10),
                            ZIndex = 4
                        })
                        
                        Linux.Instance("UICorner", {
                            Parent = OptAccentBar,
                            CornerRadius = UDim.new(0, 2)
                        })
                        
                        Linux.RegisterAccentElement(OptAccentBar)
                        
                        local textAnimTween = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                        
                        if isSelected then
                            OptBtn.TextColor3 = Color3.fromRGB(170, 170, 170)
                            TweenService:Create(OptBtn, textAnimTween, {TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
                        else
                            OptBtn.TextColor3 = Color3.fromRGB(140, 140, 140)
                            TweenService:Create(OptBtn, textAnimTween, {TextColor3 = Color3.fromRGB(170, 170, 170)}):Play()
                        end
                        
                        OptBtn.MouseButton1Click:Connect(function()
                            if IsMulti then
                                local index = table.find(SelectedValues, opt)
                                local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                                local colorTween = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                                
                                if index then
                                    table.remove(SelectedValues, index)
                                    TweenService:Create(OptBtn, colorTween, {TextColor3 = Color3.fromRGB(170, 170, 170)}):Play()
                                    TweenService:Create(OptAccentBar, tweenInfo, {Size = UDim2.new(0, 0, 0, 20)}):Play()
                                else
                                    table.insert(SelectedValues, opt)
                                    TweenService:Create(OptBtn, colorTween, {TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
                                    TweenService:Create(OptAccentBar, tweenInfo, {Size = UDim2.new(0, 4, 0, 20)}):Play()
                                end
                                UpdateSelectedText()
                                spawn(function() Linux:SafeCallback(config.Callback, SelectedValues) end)
                            else
                                if opt ~= SelectedValue then
                                    SelectedValue = opt
                                    Selected.Text = FormatDisplayText(opt)
                                    Selected.TextColor3 = Color3.fromRGB(255, 255, 255)
                                    
                                    for _, btn in pairs(OptionsHolder:GetChildren()) do
                                        if btn:IsA("TextButton") then
                                            local btnAccentBar = btn:FindFirstChild("Frame")
                                            local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                                            local colorTween = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                                            if btn.Text == tostring(opt) then
                                                TweenService:Create(btn, colorTween, {TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
                                                if btnAccentBar then
                                                    TweenService:Create(btnAccentBar, tweenInfo, {Size = UDim2.new(0, 4, 0, 20)}):Play()
                                                end
                                            else
                                                TweenService:Create(btn, colorTween, {TextColor3 = Color3.fromRGB(170, 170, 170)}):Play()
                                                if btnAccentBar then
                                                    TweenService:Create(btnAccentBar, tweenInfo, {Size = UDim2.new(0, 0, 0, 20)}):Play()
                                                end
                                            end
                                        end
                                    end
                                    
                                    spawn(function() Linux:SafeCallback(config.Callback, opt) end)
                                end
                            end
                        end)
                    end
                end
                
                UpdateDropSize()
            end
            
            if #Options > 0 then
                PopulateOptions()
                if IsMulti then
                    spawn(function() Linux:SafeCallback(config.Callback, SelectedValues) end)
                else
                    spawn(function() Linux:SafeCallback(config.Callback, SelectedValue) end)
                end
            end
            
            DropdownButton.MouseButton1Click:Connect(function()
                IsOpen = not IsOpen
                PopulateOptions()
            end)
            
            local function SetOptions(newOptions)
                Options = newOptions or {}
                if IsMulti then
                    SelectedValues = {}
                else
                    SelectedValue = Options[1] or "None"
                end
                UpdateSelectedText()
                
                IsOpen = false
                UpdateDropSize()
                PopulateOptions()
                
                if IsMulti then
                    spawn(function() Linux:SafeCallback(config.Callback, SelectedValues) end)
                else
                    spawn(function() Linux:SafeCallback(config.Callback, SelectedValue) end)
                end
            end
            
            local function SetValue(value)
                if IsMulti then
                    if typeof(value) == "table" then
                        SelectedValues = {}
                        for _, v in pairs(value) do
                            if table.find(Options, v) then
                                table.insert(SelectedValues, v)
                            end
                        end
                    elseif table.find(Options, value) then
                        SelectedValues = {value}
                    end
                    UpdateSelectedText()
                else
                    if table.find(Options, value) then
                        SelectedValue = value
                        Selected.Text = FormatDisplayText(value)
                        Selected.TextColor3 = Color3.fromRGB(255, 255, 255)
                    end
                end
                
                IsOpen = false
                UpdateDropSize()
                PopulateOptions()
                
                if IsMulti then
                    spawn(function() Linux:SafeCallback(config.Callback, SelectedValues) end)
                else
                    spawn(function() Linux:SafeCallback(config.Callback, SelectedValue) end)
                end
            end
            
            targetContainer.CanvasPosition = Vector2.new(0, 0)
            
            local element = {
                Type = "Dropdown",
                Name = config.Name,
                Instance = Dropdown,
                Value = IsMulti and SelectedValues or SelectedValue
            }
            table.insert(Tabs[tabIndex].Elements, element)
            table.insert(AllElements, {Tab = tabIndex, Element = element})
            
            table.insert(Linux.SavedElements, {
                Element = element,
                TabName = Tabs[tabIndex].Name,
                GetValue = function() return IsMulti and SelectedValues or SelectedValue end,
                SetValue = SetValue
            })
            
            CheckEmptyState()
            
            return {
                Instance = Dropdown,
                SetOptions = SetOptions,
                SetValue = SetValue,
                GetValue = function() return IsMulti and SelectedValues or SelectedValue end
            }
        end
        
        function TabElements.Slider(config)
            local targetContainer, targetListLayout = getTargetContainer()
            local currentElementOrder = updateElementOrder(false)
            
            local hasDescription = config.Description and config.Description ~= ""
            local frameHeight = hasDescription and 68 or 42
            
            local Slider = Linux.Instance("Frame", {
                Parent = targetContainer,
                BackgroundColor3 = Color3.fromRGB(70, 70, 70),
                BackgroundTransparency = 0.82,
                BorderSizePixel = 0,
                BorderColor3 = Color3.fromRGB(25, 25, 25),
                Size = UDim2.new(1, 0, 0, frameHeight),
                ZIndex = 1,
                LayoutOrder = currentElementOrder
            })
            
            Linux.Instance("UICorner", {
                Parent = Slider,
                CornerRadius = UDim.new(0, 4)
            })
            
            local TitleLabel = Linux.Instance("TextLabel", {
                Parent = Slider,
                BackgroundTransparency = 1,
                Size = UDim2.new(0.6, 0, 0, 16),
                Position = UDim2.new(0, 10, 0, 4),
                Font = Enum.Font.GothamSemibold,
                Text = config.Name,
                TextColor3 = Color3.fromRGB(240, 240, 240),
                TextSize = 14,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 2
            })
            
            if hasDescription then
                Linux.Instance("TextLabel", {
                    Parent = Slider,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, -70, 0, 16),
                    Position = UDim2.new(0, 10, 0, 22),
                    Font = Enum.Font.GothamSemibold,
                    Text = config.Description,
                    TextColor3 = Color3.fromRGB(170, 170, 170),
                    TextSize = 12,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextWrapped = true,
                    ZIndex = 2
                })
            end
            
            local SliderBar = Linux.Instance("Frame", {
                Parent = Slider,
                BackgroundColor3 = Color3.fromRGB(100, 100, 100),
                BackgroundTransparency = 0.18,
                Size = UDim2.new(1, -20, 0, 6),
                Position = UDim2.new(0, 10, 0, hasDescription and 50 or 26),
                ZIndex = 2,
                BorderSizePixel = 0,
                BorderColor3 = Color3.fromRGB(55, 55, 55),
                Name = "Bar"
            })
            
            local ValueLabel = Linux.Instance("TextLabel", {
                Parent = Slider,
                BackgroundColor3 = Color3.fromRGB(100, 100, 100),
                BackgroundTransparency = 0.18,
                Size = UDim2.new(0, 50, 0, 16),
                Position = UDim2.new(1, -60, 0, 4),
                Font = Enum.Font.GothamSemibold,
                Text = "",
                TextColor3 = Color3.fromRGB(255, 255, 255),
                TextSize = 14,
                TextXAlignment = Enum.TextXAlignment.Center,
                ZIndex = 2,
                BorderSizePixel = 0,
                BorderColor3 = Color3.fromRGB(55, 55, 55),
                Name = "Value"
            })
            
            Linux.Instance("UICorner", {
                Parent = ValueLabel,
                CornerRadius = UDim.new(0, 4)
            })
            
            local FillBar = Linux.Instance("Frame", {
                Parent = SliderBar,
                BackgroundColor3 = Linux.Themes[Linux.CurrentTheme],
                Size = UDim2.new(0, 0, 1, 0),
                ZIndex = 2,
                BorderSizePixel = 0,
                BorderColor3 = Color3.fromRGB(55, 55, 55),
                Name = "Fill"
            })
            
            Linux.Instance("UICorner", {
                Parent = FillBar,
                CornerRadius = UDim.new(1, 0)
            })
            
            Linux.RegisterAccentElement(FillBar)
            
            local SliderKnob = Linux.Instance("Frame", {
                Parent = SliderBar,
                BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                Size = UDim2.new(0, 12, 0, 12),
                Position = UDim2.new(0, -6, 0.5, -6),
                ZIndex = 4,
                BorderSizePixel = 0,
                Name = "Knob"
            })
            
            Linux.Instance("UICorner", {
                Parent = SliderKnob,
                CornerRadius = UDim.new(1, 0)
            })
            
            local SliderButton = Linux.Instance("TextButton", {
                Parent = SliderBar,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 1, 0),
                Text = "",
                ZIndex = 3
            })
            
            local Min = config.Min or 0
            local Max = config.Max or 100
            local Rounding = config.Rounding or 0
            local Percentage = config.Percentage or false
            
            Slider:SetAttribute("Min", Min)
            Slider:SetAttribute("Max", Max)
            Slider:SetAttribute("Rounding", Rounding)
            Slider:SetAttribute("Percentage", Percentage)
            
            local Value = config.Default or Min
            
            Slider:SetAttribute("Value", Value)
            
            local isDraggingSlider = false
            local animationConnection = nil
            
            local function StartContinuousAnimation()
                if animationConnection then
                    animationConnection:Disconnect()
                    animationConnection = nil
                end
                
                animationConnection = RunService.Heartbeat:Connect(function()
                    if isDraggingSlider then
                        local tween1 = TweenService:Create(ValueLabel, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextSize = 16})
                        tween1:Play()
                        tween1.Completed:Wait()
                        local tween2 = TweenService:Create(ValueLabel, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextSize = 14})
                        tween2:Play()
                        tween2.Completed:Wait()
                    else
                        animationConnection:Disconnect()
                        animationConnection = nil
                    end
                end)
            end
            
            local function StopContinuousAnimation()
                if animationConnection then
                    animationConnection:Disconnect()
                    animationConnection = nil
                end
                local finalTween = TweenService:Create(ValueLabel, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextSize = 14})
                finalTween:Play()
            end
            
            local function FormatValue(value)
                local formattedValue
                if Rounding <= 0 then
                    formattedValue = tostring(math.floor(value))
                else
                    local mult = 10 ^ Rounding
                    formattedValue = tostring(math.floor(value * mult) / mult)
                end
                
                if Percentage then
                    formattedValue = formattedValue .. "%"
                end
                
                return formattedValue
            end
            
            local function UpdateSlider(pos)
                local barSize = SliderBar.AbsoluteSize.X
                local relativePos = math.clamp((pos - SliderBar.AbsolutePosition.X) / barSize, 0, 1)
                
                local min = Slider:GetAttribute("Min")
                local max = Slider:GetAttribute("Max")
                local rounding = Slider:GetAttribute("Rounding")
                
                local value = min + (max - min) * relativePos
                
                if rounding <= 0 then
                    value = math.floor(value + 0.5)
                else
                    local mult = 10 ^ rounding
                    value = math.floor(value * mult + 0.5) / mult
                end
                
                Slider:SetAttribute("Value", value)
                
                local tween = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                TweenService:Create(FillBar, tween, {Size = UDim2.new(relativePos, 0, 1, 0)}):Play()
                TweenService:Create(SliderKnob, tween, {Position = UDim2.new(relativePos, -6, 0.5, -6)}):Play()
                
                ValueLabel.Text = FormatValue(value)
                
                spawn(function() Linux:SafeCallback(config.Callback, value) end)
            end
            
            SliderButton.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                    isDraggingSlider = true
                    StartContinuousAnimation()
                    UpdateSlider(input.Position.X)
                end
            end)
            
            SliderButton.InputChanged:Connect(function(input)
                if (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) and isDraggingSlider then
                    UpdateSlider(input.Position.X)
                end
            end)
            
            SliderButton.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                    isDraggingSlider = false
                    StopContinuousAnimation()
                end
            end)
            
            local function SetValue(newValue)
                local min = Slider:GetAttribute("Min")
                local max = Slider:GetAttribute("Max")
                local rounding = Slider:GetAttribute("Rounding")
                
                newValue = math.clamp(newValue, min, max)
                
                if rounding <= 0 then
                    newValue = math.floor(newValue + 0.5)
                else
                    local mult = 10 ^ rounding
                    newValue = math.floor(newValue * mult + 0.5) / mult
                end
                
                Slider:SetAttribute("Value", newValue)
                
                local relativePos = (newValue - min) / (max - min)
                
                local tween = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                TweenService:Create(FillBar, tween, {Size = UDim2.new(relativePos, 0, 1, 0)}):Play()
                TweenService:Create(SliderKnob, tween, {Position = UDim2.new(relativePos, -6, 0.5, -6)}):Play()
                
                ValueLabel.Text = FormatValue(newValue)
                
                spawn(function() Linux:SafeCallback(config.Callback, newValue) end)
            end
            
            SetValue(Value)
            
            targetContainer.CanvasPosition = Vector2.new(0, 0)
            
            local element = {
                Type = "Slider",
                Name = config.Name,
                Instance = Slider,
                Value = Value
            }
            table.insert(Tabs[tabIndex].Elements, element)
            table.insert(AllElements, {Tab = tabIndex, Element = element})
            
            table.insert(Linux.SavedElements, {
                Element = element,
                TabName = Tabs[tabIndex].Name,
                GetValue = function() return Slider:GetAttribute("Value") end,
                SetValue = SetValue
            })
            
            CheckEmptyState()
            
            return {
                Instance = Slider,
                SetValue = SetValue,
                GetValue = function() return Slider:GetAttribute("Value") end,
                SetMin = function(min)
                    Slider:SetAttribute("Min", min)
                    SetValue(Slider:GetAttribute("Value"))
                end,
                SetMax = function(max)
                    Slider:SetAttribute("Max", max)
                    SetValue(Slider:GetAttribute("Value"))
                end,
                SetRounding = function(rounding)
                    Slider:SetAttribute("Rounding", rounding)
                    SetValue(Slider:GetAttribute("Value"))
                end,
                SetPercentage = function(percentage)
                    Slider:SetAttribute("Percentage", percentage)
                    Percentage = percentage
                    ValueLabel.Text = FormatValue(Slider:GetAttribute("Value"))
                end
            }
        end
        
        function TabElements.Input(config)
            local targetContainer, targetListLayout = getTargetContainer()
            local currentElementOrder = updateElementOrder(false)
            
            local hasDescription = config.Description and config.Description ~= ""
            local frameHeight = 36
            
            local Input = Linux.Instance("Frame", {
                Parent = targetContainer,
                BackgroundColor3 = Color3.fromRGB(70, 70, 70),
                BackgroundTransparency = 0.82,
                BorderColor3 = Color3.fromRGB(25, 25, 25),
                BorderSizePixel = 0,
                Size = UDim2.new(1, 0, 0, frameHeight),
                ZIndex = 1,
                LayoutOrder = currentElementOrder
            })
            
            Linux.Instance("UICorner", {
                Parent = Input,
                CornerRadius = UDim.new(0, 4)
            })
            
            Linux.Instance("TextLabel", {
                Parent = Input,
                BackgroundTransparency = 1,
                Size = UDim2.new(0.5, 0, 1, 0),
                Position = hasDescription and UDim2.new(0, 10, 0, -8) or UDim2.new(0, 10, 0, 0),
                Font = Enum.Font.GothamSemibold,
                Text = config.Name,
                TextColor3 = Color3.fromRGB(240, 240, 240),
                TextSize = 14,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 2
            })
            
            if hasDescription then
                Linux.Instance("TextLabel", {
                    Parent = Input,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(0.5, -10, 0, 12),
                    Position = UDim2.new(0, 10, 0, 18),
                    Font = Enum.Font.GothamSemibold,
                    Text = config.Description,
                    TextColor3 = Color3.fromRGB(170, 170, 170),
                    TextSize = 12,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextWrapped = true,
                    ZIndex = 2
                })
            end
            
            local IsNumeric = config.Numeric or false
            local Finished = config.Finished or false
            
            local TextBoxFrame = Linux.Instance("Frame", {
                Parent = Input,
                BackgroundColor3 = Color3.fromRGB(100, 100, 100),
                BackgroundTransparency = 0.18,
                BorderSizePixel = 0,
                BorderColor3 = Color3.fromRGB(55, 55, 55),
                Size = UDim2.new(0.5, -20, 0, 24),
                Position = UDim2.new(0.5, 10, 0.5, -12),
                ZIndex = 3
            })
            
            Linux.Instance("UICorner", {
                Parent = TextBoxFrame,
                CornerRadius = UDim.new(0, 4)
            })
            
            local TextBox = Linux.Instance("TextBox", {
                Parent = TextBoxFrame,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, -12, 1, 0),
                Position = UDim2.new(0, 6, 0, 0),
                Font = Enum.Font.GothamSemibold,
                Text = config.Default or "",
                PlaceholderText = config.Placeholder or (IsNumeric and "Number here" or "Text here"),
                PlaceholderColor3 = Color3.fromRGB(170, 170, 170),
                TextColor3 = Color3.fromRGB(255, 255, 255),
                TextSize = 12,
                TextScaled = false,
                TextTruncate = Enum.TextTruncate.AtEnd,
                TextXAlignment = Enum.TextXAlignment.Center,
                ClearTextOnFocus = false,
                ClipsDescendants = true,
                ZIndex = 4
            })
            
            local MaxLength = 100
            
            local function FilterNumericInput(text)
                if not IsNumeric then
                    return text
                end
                
                local filtered = string.gsub(text, "[^%d%.%-]", "")
                
                local _, decimalCount = string.gsub(filtered, "%.", "")
                if decimalCount > 1 then
                    local firstDecimal = string.find(filtered, "%.")
                    filtered = string.sub(filtered, 1, firstDecimal) .. string.gsub(string.sub(filtered, firstDecimal + 1), "%.", "")
                end
                
                if string.find(filtered, "%-") then
                    local hasNegative = string.sub(filtered, 1, 1) == "-"
                    filtered = string.gsub(filtered, "%-", "")
                    if hasNegative then
                        filtered = "-" .. filtered
                    end
                end
                
                return filtered
            end
            
            local function CheckTextBounds()
                local currentText = TextBox.Text
                
                if IsNumeric then
                    currentText = FilterNumericInput(currentText)
                end
                
                if #currentText > MaxLength then
                    currentText = string.sub(currentText, 1, MaxLength)
                end
                
                if currentText ~= TextBox.Text then
                    TextBox.Text = currentText
                end
            end
            
            TextBox:GetPropertyChangedSignal("Text"):Connect(function()
                CheckTextBounds()
            end)
            
            local function UpdateInput()
                CheckTextBounds()
                local value = TextBox.Text
                
                if IsNumeric and value ~= "" then
                    local numValue = tonumber(value)
                    if numValue then
                        spawn(function() Linux:SafeCallback(config.Callback, numValue) end)
                    else
                        spawn(function() Linux:SafeCallback(config.Callback, 0) end)
                    end
                else
                    spawn(function() Linux:SafeCallback(config.Callback, value) end)
                end
            end
            
            TextBox.FocusLost:Connect(function(enterPressed)
                if Finished then
                    if enterPressed then
                        UpdateInput()
                    end
                else
                    UpdateInput()
                end
            end)
            
            if not Finished then
                TextBox:GetPropertyChangedSignal("Text"):Connect(function()
                    UpdateInput()
                end)
            end
            
            TextBox.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                    TextBox:CaptureFocus()
                end
            end)
            
            if not Finished then
                spawn(function()
                    local value = TextBox.Text
                    if IsNumeric and value ~= "" then
                        local numValue = tonumber(value)
                        Linux:SafeCallback(config.Callback, numValue or 0)
                    else
                        Linux:SafeCallback(config.Callback, value)
                    end
                end)
            end
            
            local function SetValue(newValue)
                local text = tostring(newValue)
                
                if IsNumeric then
                    text = FilterNumericInput(text)
                end
                
                if #text > MaxLength then
                    text = string.sub(text, 1, MaxLength)
                end
                
                TextBox.Text = text
                if not Finished then
                    UpdateInput()
                end
            end
            
            targetContainer.CanvasPosition = Vector2.new(0, 0)
            
            local element = {
                Type = "Input",
                Name = config.Name,
                Instance = Input,
                Value = TextBox.Text
            }
            table.insert(Tabs[tabIndex].Elements, element)
            table.insert(AllElements, {Tab = tabIndex, Element = element})
            
            table.insert(Linux.SavedElements, {
                Element = element,
                TabName = Tabs[tabIndex].Name,
                GetValue = function()
                    if IsNumeric and TextBox.Text ~= "" then
                        return tonumber(TextBox.Text) or 0
                    else
                        return TextBox.Text
                    end
                end,
                SetValue = SetValue,
                IsAutoLoadInput = config.IsAutoLoadInput
            })
            
            CheckEmptyState()
            
            return {
                Instance = Input,
                SetValue = SetValue,
                GetValue = function()
                    if IsNumeric and TextBox.Text ~= "" then
                        return tonumber(TextBox.Text) or 0
                    else
                        return TextBox.Text
                    end
                end
            }
        end
        
        function TabElements.Label(config)
            local targetContainer, targetListLayout = getTargetContainer()
            local currentElementOrder = updateElementOrder(false)
            
            local LabelFrame = Linux.Instance("Frame", {
                Parent = targetContainer,
                BackgroundColor3 = Color3.fromRGB(70, 70, 70),
                BackgroundTransparency = 0.82,
                BorderColor3 = Color3.fromRGB(25, 25, 25),
                BorderSizePixel = 0,
                Size = UDim2.new(1, 0, 0, 36),
                ZIndex = 1,
                LayoutOrder = currentElementOrder
            })
            
            Linux.Instance("UICorner", {
                Parent = LabelFrame,
                CornerRadius = UDim.new(0, 4)
            })
            
            local iconOffset = 0
            local LabelIcon = nil
            
            if config.Icon then
                LabelIcon = Linux.Instance("ImageLabel", {
                    Parent = LabelFrame,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(0, 18, 0, 18),
                    Position = UDim2.new(0, 10, 0.5, -9),
                    Image = config.Icon,
                    ImageColor3 = Color3.fromRGB(240, 240, 240),
                    ZIndex = 2
                })
                iconOffset = 33
            end
            
            local LabelText = Linux.Instance("TextLabel", {
                Parent = LabelFrame,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, -20 - iconOffset, 1, 0),
                Position = UDim2.new(0, 10 + iconOffset, 0, 0),
                Font = Enum.Font.GothamSemibold,
                Text = config.Text or "Label",
                TextColor3 = Color3.fromRGB(240, 240, 240),
                TextSize = 14,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                ZIndex = 2
            })
            
            local UpdateConnection = nil
            local lastUpdate = 0
            local updateInterval = 0.001
            
            local function StartUpdateLoop()
                if UpdateConnection then
                    UpdateConnection:Disconnect()
                    UpdateConnection = nil
                end
                if config.UpdateCallback then
                    UpdateConnection = RunService.Heartbeat:Connect(function()
                        if not LabelFrame:IsDescendantOf(game) then
                            UpdateConnection:Disconnect()
                            UpdateConnection = nil
                            return
                        end
                        local currentTime = tick()
                        if currentTime - lastUpdate >= updateInterval then
                            local success, newText = pcall(config.UpdateCallback)
                            if success and newText ~= nil then
                                LabelText.Text = tostring(newText)
                            elseif not success then
                                print("Error in label update callback:", newText)
                            end
                            lastUpdate = currentTime
                        end
                    end)
                end
            end
            
            local function SetText(newText)
                if config.UpdateCallback then
                    config.Text = tostring(newText)
                else
                    LabelText.Text = tostring(newText)
                end
            end
            
            if config.UpdateCallback then
                StartUpdateLoop()
            end
            
            targetContainer.CanvasPosition = Vector2.new(0, 0)
            
            local element = {
                Type = "Label",
                Name = config.Text or "Label",
                Instance = LabelFrame
            }
            table.insert(Tabs[tabIndex].Elements, element)
            table.insert(AllElements, {Tab = tabIndex, Element = element})
            
            CheckEmptyState()
            
            return {
                Instance = LabelFrame,
                SetText = SetText,
                GetText = function() return LabelText.Text end
            }
        end
        
        function TabElements.Section(config)
            local targetContainer, targetListLayout = getTargetContainer()
            local currentElementOrder = updateElementOrder(false)
            
            local Section = Linux.Instance("Frame", {
                Parent = targetContainer,
                BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 30),
                ZIndex = 2,
                LayoutOrder = currentElementOrder,
                BorderSizePixel = 0,
                BorderColor3 = Color3.fromRGB(60, 60, 60),
                Name = "Section"
            })
            
            local iconOffset = 0
            local SectionIcon = nil
            
            if config.Icon then
                SectionIcon = Linux.Instance("ImageLabel", {
                    Parent = Section,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(0, 20, 0, 20),
                    Position = UDim2.new(0, 0, 0.5, -10),
                    Image = config.Icon,
                    ImageColor3 = config.TextColor or Color3.fromRGB(255, 255, 255),
                    ZIndex = 2
                })
                iconOffset = 25
            end
            
            local SectionLabel = Linux.Instance("TextLabel", {
                Parent = Section,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, -20 - iconOffset, 1, 0),
                Position = UDim2.new(0, iconOffset, 0, 0),
                Font = Enum.Font.GothamBold,
                Text = config.Name,
                TextColor3 = config.TextColor or Color3.fromRGB(255, 255, 255),
                TextSize = 18,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Center,
                ZIndex = 2
            })
            
            targetContainer.CanvasPosition = Vector2.new(0, 0)
            
            local element = {
                Type = "Section",
                Name = config.Name,
                Instance = Section
            }
            table.insert(Tabs[tabIndex].Elements, element)
            table.insert(AllElements, {Tab = tabIndex, Element = element})
            
            CheckEmptyState()
            
            return Section
        end
        
        function TabElements.Paragraph(config)
            local targetContainer, targetListLayout = getTargetContainer()
            local currentElementOrder = updateElementOrder(false)
            
            local formatText = config.FormatText or false
            
            local function ProcessLineBreaks(text)
                return string.gsub(text, "/", "\n")
            end
            
            local function ProcessTextFormatting(text)
                if not formatText then
                    return text
                end
                
                text = string.gsub(text, "%*%*(.-)%*%*", '<font color="rgb(255,255,255)"><b>%1</b></font>')
                text = string.gsub(text, "%*(.-)%*", "<i>%1</i>")
                text = string.gsub(text, "__(.-)__", "<u>%1</u>")
                text = string.gsub(text, "~~(.-)~~", "<s>%1</s>")
                
                return text
            end
            
            local ParagraphFrame = Linux.Instance("Frame", {
                Parent = targetContainer,
                BackgroundColor3 = Color3.fromRGB(70, 70, 70),
                BackgroundTransparency = 0.82,
                BorderColor3 = Color3.fromRGB(25, 25, 25),
                BorderSizePixel = 0,
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                ZIndex = 1,
                LayoutOrder = currentElementOrder
            })
            
            Linux.Instance("UICorner", {
                Parent = ParagraphFrame,
                CornerRadius = UDim.new(0, 4)
            })
            
            Linux.Instance("TextLabel", {
                Parent = ParagraphFrame,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, -20, 0, 26),
                Position = UDim2.new(0, 10, 0, 5),
                Font = Enum.Font.GothamBold,
                Text = config.Title or "Paragraph",
                TextColor3 = Color3.fromRGB(240, 240, 240),
                TextSize = 16,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 2
            })
            
            local Content = Linux.Instance("TextLabel", {
                Parent = ParagraphFrame,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, -20, 0, 0),
                Position = UDim2.new(0, 10, 0, 30),
                Font = Enum.Font.GothamSemibold,
                Text = ProcessTextFormatting(ProcessLineBreaks(config.Content or "Content")),
                TextColor3 = Color3.fromRGB(170, 170, 170),
                TextSize = 14,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextWrapped = true,
                AutomaticSize = Enum.AutomaticSize.Y,
                RichText = formatText,
                ZIndex = 2
            })
            
            Linux.Instance("UIPadding", {
                Parent = ParagraphFrame,
                PaddingBottom = UDim.new(0, 10)
            })
            
            local function SetTitle(newTitle)
                ParagraphFrame:GetChildren()[3].Text = tostring(newTitle)
            end
            
            local function SetContent(newContent)
                Content.Text = ProcessTextFormatting(ProcessLineBreaks(tostring(newContent)))
            end
            
            targetContainer.CanvasPosition = Vector2.new(0, 0)
            
            local element = {
                Type = "Paragraph",
                Name = config.Title or "Paragraph",
                Instance = ParagraphFrame
            }
            table.insert(Tabs[tabIndex].Elements, element)
            table.insert(AllElements, {Tab = tabIndex, Element = element})
            
            CheckEmptyState()
            
            return {
                Instance = ParagraphFrame,
                SetTitle = SetTitle,
                SetContent = SetContent
            }
        end
        
        function TabElements.ColorPicker(config)
            local targetContainer, targetListLayout = getTargetContainer()
            local currentElementOrder = updateElementOrder(false)
            
            local hasDescription = config.Description and config.Description ~= ""
            local frameHeight = 36
            
            local ColorPicker = Linux.Instance("Frame", {
                Parent = targetContainer,
                BackgroundColor3 = Color3.fromRGB(70, 70, 70),
                BackgroundTransparency = 0.82,
                BorderColor3 = Color3.fromRGB(25, 25, 25),
                BorderSizePixel = 0,
                Size = UDim2.new(1, 0, 0, frameHeight),
                ZIndex = 1,
                LayoutOrder = currentElementOrder
            })
            
            Linux.Instance("UICorner", {
                Parent = ColorPicker,
                CornerRadius = UDim.new(0, 4)
            })
            
            local ColorText = Linux.Instance("TextLabel", {
                Parent = ColorPicker,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, -60, 1, 0),
                Position = hasDescription and UDim2.new(0, 10, 0, -8) or UDim2.new(0, 10, 0, 0),
                Font = Enum.Font.GothamSemibold,
                Text = config.Name,
                TextColor3 = Color3.fromRGB(240, 240, 240),
                TextSize = 14,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 2
            })
            
            if hasDescription then
                Linux.Instance("TextLabel", {
                    Parent = ColorPicker,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, -70, 0, 12),
                    Position = UDim2.new(0, 10, 0, 18),
                    Font = Enum.Font.GothamSemibold,
                    Text = config.Description,
                    TextColor3 = Color3.fromRGB(170, 170, 170),
                    TextSize = 12,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextWrapped = true,
                    ZIndex = 2
                })
            end
            
            local CurrentColor = config.Default or Color3.fromRGB(255, 0, 0)
            local RealTimeUpdate = config.RealTime or false
            
            local ColorDisplay = Linux.Instance("TextButton", {
                Parent = ColorPicker,
                BackgroundColor3 = CurrentColor,
                Size = UDim2.new(0, 24, 0, 24),
                Position = UDim2.new(1, -34, 0.5, -12),
                Text = "",
                ZIndex = 2,
                BorderSizePixel = 0,
                BorderColor3 = Color3.fromRGB(55, 55, 55),
                AutoButtonColor = false
            })
            
            Linux.Instance("UICorner", {
                Parent = ColorDisplay,
                CornerRadius = UDim.new(0, 6)
            })
            
            Linux.Instance("UIStroke", {
                Parent = ColorDisplay,
                Color = Color3.fromRGB(55, 55, 55),
                Thickness = 1
            })
            
            local function RGBToHex(color)
                local r = math.floor(color.R * 255)
                local g = math.floor(color.G * 255)
                local b = math.floor(color.B * 255)
                return string.format("%02X%02X%02X", r, g, b)
            end
            
            local function HexToRGB(hex)
                hex = string.gsub(hex, "#", "")
                hex = string.upper(hex)
                
                if #hex == 3 then
                    hex = string.gsub(hex, "(.)", "%1%1")
                elseif #hex ~= 6 then
                    return nil
                end
                
                local r = tonumber(string.sub(hex, 1, 2), 16)
                local g = tonumber(string.sub(hex, 3, 4), 16)
                local b = tonumber(string.sub(hex, 5, 6), 16)
                
                if r and g and b then
                    return Color3.fromRGB(r, g, b)
                else
                    return nil
                end
            end
            
            local function ValidateHexInput(text)
                text = string.gsub(text, "#", "")
                text = string.gsub(text, "[^0-9A-Fa-f]", "")
                text = string.upper(text)
                return string.sub(text, 1, 6)
            end
            
            local function createColorPickerDialog()
                local isMobile = Linux.DeviceType == "Mobile"
                local dialogWidth = isMobile and 280 or 320
                local dialogHeight = isMobile and 300 or 350
                
                local ColorOverlay = Linux.Instance("Frame", {
                    Parent = Main,
                    BackgroundColor3 = Color3.fromRGB(0, 0, 0),
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 1, 0),
                    Position = UDim2.new(0, 0, 0, 0),
                    ZIndex = 1000,
                    Active = true
                })
                
                Linux.Instance("UICorner", {
                    Parent = ColorOverlay,
                    CornerRadius = UDim.new(0, 8)
                })
                
                local overlayTween = TweenService:Create(ColorOverlay, TweenInfo.new(0.2), {BackgroundTransparency = 0.5})
                overlayTween:Play()
                
                for _, element in pairs(Main:GetDescendants()) do
                    if element:IsA("TextButton") or element:IsA("TextBox") or element:IsA("ImageButton") then
                        if element ~= ColorOverlay and not element:IsDescendantOf(ColorOverlay) then
                            element.Active = false
                        end
                    end
                end
                
                local DialogFrame = Linux.Instance("Frame", {
                    Parent = ColorOverlay,
                    BackgroundColor3 = Color3.fromRGB(30, 30, 30),
                    BorderColor3 = Color3.fromRGB(60, 60, 60),
                    BorderSizePixel = 0,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(0, dialogWidth, 0, dialogHeight),
                    Position = UDim2.new(0.5, -dialogWidth/2, 0.5, -dialogHeight/2),
                    ZIndex = 1001
                })
                
                Linux.Instance("UICorner", {
                    Parent = DialogFrame,
                    CornerRadius = UDim.new(0, 8)
                })
                
                local dialogTween = TweenService:Create(DialogFrame, TweenInfo.new(0.2), {BackgroundTransparency = 0.18})
                dialogTween:Play()
                
                local TitleLabel = Linux.Instance("TextLabel", {
                    Parent = DialogFrame,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, -50, 0, 25),
                    Position = UDim2.new(0, 8, 0, 8),
                    Font = Enum.Font.GothamBold,
                    Text = "Color Picker",
                    TextColor3 = Color3.fromRGB(240, 240, 240),
                    TextSize = 14,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 1002
                })
                
                local ClosePickerButton = Linux.Instance("ImageButton", {
                    Parent = DialogFrame,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(0, 14, 0, 14),
                    Position = UDim2.new(1, -22, 0, 8),
                    Image = "rbxassetid://10747384394",
                    ImageColor3 = Color3.fromRGB(240, 240, 240),
                    ZIndex = 1003
                })
                
                ClosePickerButton.MouseEnter:Connect(function()
                    TweenService:Create(ClosePickerButton, TweenInfo.new(0.2), {ImageColor3 = Color3.fromRGB(255, 255, 255)}):Play()
                end)
                
                ClosePickerButton.MouseLeave:Connect(function()
                    TweenService:Create(ClosePickerButton, TweenInfo.new(0.2), {ImageColor3 = Color3.fromRGB(240, 240, 240)}):Play()
                end)
                
                local ColorArea = Linux.Instance("Frame", {
                    Parent = DialogFrame,
                    BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                    Size = UDim2.new(1, -16, 0, isMobile and 120 or 140),
                    Position = UDim2.new(0, 8, 0, 35),
                    ZIndex = 1002,
                    BorderSizePixel = 0,
                    BorderColor3 = Color3.fromRGB(55, 55, 55)
                })
                
                Linux.Instance("UICorner", {
                    Parent = ColorArea,
                    CornerRadius = UDim.new(0, 4)
                })
                
                local ColorAreaButton = Linux.Instance("TextButton", {
                    Parent = ColorArea,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 1, 0),
                    Text = "",
                    ZIndex = 1003
                })
                
                local ColorCursor = Linux.Instance("Frame", {
                    Parent = ColorArea,
                    BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                    Size = UDim2.new(0, 6, 0, 6),
                    Position = UDim2.new(1, -3, 0, -3),
                    ZIndex = 1004,
                    BorderSizePixel = 0,
                    BorderColor3 = Color3.fromRGB(0, 0, 0)
                })
                
                Linux.Instance("UICorner", {
                    Parent = ColorCursor,
                    CornerRadius = UDim.new(1, 0)
                })
                
                local HexFrame = Linux.Instance("Frame", {
                    Parent = DialogFrame,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, -16, 0, 25),
                    Position = UDim2.new(0, 8, 0, isMobile and 165 or 185),
                    ZIndex = 1002
                })
                
                local HexLabel = Linux.Instance("TextLabel", {
                    Parent = HexFrame,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(0, 25, 1, 0),
                    Position = UDim2.new(0, 0, 0, 0),
                    Font = Enum.Font.GothamSemibold,
                    Text = "HEX",
                    TextColor3 = Color3.fromRGB(240, 240, 240),
                    TextSize = 10,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 1002
                })
                
                local HexInputFrame = Linux.Instance("Frame", {
                    Parent = HexFrame,
                    BackgroundColor3 = Color3.fromRGB(100, 100, 100),
                    BackgroundTransparency = 0.18,
                    Size = UDim2.new(1, -30, 0, 20),
                    Position = UDim2.new(0, 28, 0.5, -10),
                    ZIndex = 1002,
                    BorderSizePixel = 0,
                    BorderColor3 = Color3.fromRGB(55, 55, 55)
                })
                
                Linux.Instance("UICorner", {
                    Parent = HexInputFrame,
                    CornerRadius = UDim.new(0, 3)
                })
                
                local HexInput = Linux.Instance("TextBox", {
                    Parent = HexInputFrame,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, -14, 1, 0),
                    Position = UDim2.new(0, 7, 0, 0),
                    Font = Enum.Font.GothamSemibold,
                    Text = RGBToHex(CurrentColor),
                    PlaceholderText = "FFFFFF",
                    PlaceholderColor3 = Color3.fromRGB(170, 170, 170),
                    TextColor3 = Color3.fromRGB(255, 255, 255),
                    TextSize = 10,
                    TextXAlignment = Enum.TextXAlignment.Center,
                    ZIndex = 1003
                })
                
                local HashSymbol = Linux.Instance("TextLabel", {
                    Parent = HexInputFrame,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(0, 6, 1, 0),
                    Position = UDim2.new(0, 2, 0, 0),
                    Font = Enum.Font.GothamSemibold,
                    Text = "#",
                    TextColor3 = Color3.fromRGB(170, 170, 170),
                    TextSize = 10,
                    TextXAlignment = Enum.TextXAlignment.Center,
                    ZIndex = 1003
                })
                
                local function HSVToRGB(h, s, v)
                    local r, g, b
                    local i = math.floor(h * 6)
                    local f = h * 6 - i
                    local p = v * (1 - s)
                    local q = v * (1 - f * s)
                    local t = v * (1 - (1 - f) * s)
                    
                    local imod = i % 6
                    if imod == 0 then
                        r, g, b = v, t, p
                    elseif imod == 1 then
                        r, g, b = q, v, p
                    elseif imod == 2 then
                        r, g, b = p, v, t
                    elseif imod == 3 then
                        r, g, b = p, q, v
                    elseif imod == 4 then
                        r, g, b = t, p, v
                    elseif imod == 5 then
                        r, g, b = v, p, q
                    end
                    
                    return r, g, b
                end
                
                local function RGBToHSV(r, g, b)
                    local max = math.max(r, g, b)
                    local min = math.min(r, g, b)
                    local delta = max - min
                    
                    local h, s, v = 0, 0, max
                    
                    if delta > 0 then
                        s = delta / max
                        
                        if max == r then
                            h = ((g - b) / delta) % 6
                        elseif max == g then
                            h = (b - r) / delta + 2
                        else
                            h = (r - g) / delta + 4
                        end
                        h = h / 6
                    end
                    
                    return h, s, v
                end
                
                local currentH, currentS, currentV = RGBToHSV(CurrentColor.R, CurrentColor.G, CurrentColor.B)
                
                local function updateColorArea()
                    local hueColor = Color3.fromHSV(currentH, 1, 1)
                    ColorArea.BackgroundColor3 = hueColor
                    
                    local whiteOverlay = ColorArea:FindFirstChild("WhiteOverlay")
                    if not whiteOverlay then
                        whiteOverlay = Linux.Instance("Frame", {
                            Parent = ColorArea,
                            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                            Size = UDim2.new(1, 0, 1, 0),
                            ZIndex = 1002,
                            BorderSizePixel = 0,
                            Name = "WhiteOverlay"
                        })
                        
                        Linux.Instance("UICorner", {
                            Parent = whiteOverlay,
                            CornerRadius = UDim.new(0, 4)
                        })
                        
                        local whiteGradient = Linux.Instance("UIGradient", {
                            Parent = whiteOverlay,
                            Color = ColorSequence.new({
                                ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
                                ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255))
                            }),
                            Transparency = NumberSequence.new({
                                NumberSequenceKeypoint.new(0, 0),
                                NumberSequenceKeypoint.new(1, 1)
                            }),
                            Rotation = 0
                        })
                        
                        local blackOverlay = Linux.Instance("Frame", {
                            Parent = ColorArea,
                            BackgroundColor3 = Color3.fromRGB(0, 0, 0),
                            Size = UDim2.new(1, 0, 1, 0),
                            ZIndex = 1002,
                            BorderSizePixel = 0,
                            Name = "BlackOverlay"
                        })
                        
                        Linux.Instance("UICorner", {
                            Parent = blackOverlay,
                            CornerRadius = UDim.new(0, 4)
                        })
                        
                        local blackGradient = Linux.Instance("UIGradient", {
                            Parent = blackOverlay,
                            Color = ColorSequence.new({
                                ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
                                ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0))
                            }),
                            Transparency = NumberSequence.new({
                                NumberSequenceKeypoint.new(0, 1),
                                NumberSequenceKeypoint.new(1, 0)
                            }),
                            Rotation = 90
                        })
                    end
                end
                
                local function updateCursorPosition()
                    local x = currentS
                    local y = 1 - currentV
                    ColorCursor.Position = UDim2.new(x, -3, y, -3)
                end
                
                local RedSlider, GreenSlider, BlueSlider
                local RedValue, GreenValue, BlueValue
                
                local function updateRGBSliders()
                    local r = math.floor(CurrentColor.R * 255)
                    local g = math.floor(CurrentColor.G * 255)
                    local b = math.floor(CurrentColor.B * 255)
                    
                    if RedValue then RedValue.Text = tostring(r) end
                    if GreenValue then GreenValue.Text = tostring(g) end
                    if BlueValue then BlueValue.Text = tostring(b) end
                    
                    if RedSlider then
                        local redFill = RedSlider:FindFirstChild("Fill")
                        local redKnob = RedSlider:FindFirstChild("Knob")
                        if redFill and redKnob then
                            local pos = r / 255
                            redFill.Size = UDim2.new(pos, 0, 1, 0)
                            redKnob.Position = UDim2.new(pos, -3, 0.5, -3)
                        end
                    end
                    
                    if GreenSlider then
                        local greenFill = GreenSlider:FindFirstChild("Fill")
                        local greenKnob = GreenSlider:FindFirstChild("Knob")
                        if greenFill and greenKnob then
                            local pos = g / 255
                            greenFill.Size = UDim2.new(pos, 0, 1, 0)
                            greenKnob.Position = UDim2.new(pos, -3, 0.5, -3)
                        end
                    end
                    
                    if BlueSlider then
                        local blueFill = BlueSlider:FindFirstChild("Fill")
                        local blueKnob = BlueSlider:FindFirstChild("Knob")
                        if blueFill and blueKnob then
                            local pos = b / 255
                            blueFill.Size = UDim2.new(pos, 0, 1, 0)
                            blueKnob.Position = UDim2.new(pos, -3, 0.5, -3)
                        end
                    end
                    
                    HexInput.Text = RGBToHex(CurrentColor)
                end
                
                local function updateCurrentColor()
                    local r, g, b = HSVToRGB(currentH, currentS, currentV)
                    CurrentColor = Color3.fromRGB(math.floor(r * 255), math.floor(g * 255), math.floor(b * 255))
                    
                    ColorDisplay.BackgroundColor3 = CurrentColor
                    if RealTimeUpdate then
                        spawn(function() Linux:SafeCallback(config.Callback, CurrentColor) end)
                    end
                    updateRGBSliders()
                end
                
                updateColorArea()
                updateCursorPosition()
                
                local accentColor = Linux.Themes[Linux.CurrentTheme]
                local function createRGBSlider(colorName, position, value)
                    local SliderFrame = Linux.Instance("Frame", {
                        Parent = DialogFrame,
                        BackgroundTransparency = 1,
                        Size = UDim2.new(1, -16, 0, 16),
                        Position = position,
                        ZIndex = 1002
                    })
                    
                    local Label = Linux.Instance("TextLabel", {
                        Parent = SliderFrame,
                        BackgroundTransparency = 1,
                        Size = UDim2.new(0, 12, 1, 0),
                        Position = UDim2.new(0, 0, 0, 0),
                        Font = Enum.Font.GothamSemibold,
                        Text = colorName,
                        TextColor3 = Color3.fromRGB(240, 240, 240),
                        TextSize = 10,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        ZIndex = 1002
                    })
                    
                    local ValueFrame = Linux.Instance("Frame", {
                        Parent = SliderFrame,
                        BackgroundColor3 = Color3.fromRGB(100, 100, 100),
                        BackgroundTransparency = 0.18,
                        Size = UDim2.new(0, 30, 0, 12),
                        Position = UDim2.new(1, -30, 0.5, -6),
                        ZIndex = 1002,
                        BorderSizePixel = 0,
                        BorderColor3 = Color3.fromRGB(55, 55, 55)
                    })
                    
                    Linux.Instance("UICorner", {
                        Parent = ValueFrame,
                        CornerRadius = UDim.new(0, 2)
                    })
                    
                    local ValueText = Linux.Instance("TextLabel", {
                        Parent = ValueFrame,
                        BackgroundTransparency = 1,
                        Size = UDim2.new(1, 0, 1, 0),
                        Font = Enum.Font.GothamSemibold,
                        Text = tostring(value),
                        TextColor3 = Color3.fromRGB(255, 255, 255),
                        TextSize = 8,
                        TextXAlignment = Enum.TextXAlignment.Center,
                        ZIndex = 1003
                    })
                    
                    local SliderTrack = Linux.Instance("Frame", {
                        Parent = SliderFrame,
                        BackgroundColor3 = Color3.fromRGB(100, 100, 100),
                        Size = UDim2.new(1, -50, 0, 4),
                        Position = UDim2.new(0, 15, 0.5, -2),
                        ZIndex = 1002,
                        BorderSizePixel = 0,
                        BorderColor3 = Color3.fromRGB(55, 55, 55)
                    })
                    
                    Linux.Instance("UICorner", {
                        Parent = SliderTrack,
                        CornerRadius = UDim.new(0, 2)
                    })
                    
                    local SliderFill = Linux.Instance("Frame", {
                        Parent = SliderTrack,
                        BackgroundColor3 = accentColor,
                        Size = UDim2.new(value / 255, 0, 1, 0),
                        ZIndex = 1002,
                        BorderSizePixel = 0,
                        Name = "Fill"
                    })
                    
                    Linux.Instance("UICorner", {
                        Parent = SliderFill,
                        CornerRadius = UDim.new(0, 2)
                    })
                    
                    local SliderKnob = Linux.Instance("Frame", {
                        Parent = SliderTrack,
                        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                        Size = UDim2.new(0, 6, 0, 6),
                        Position = UDim2.new(value / 255, -3, 0.5, -3),
                        ZIndex = 1003,
                        BorderSizePixel = 0,
                        BorderColor3 = Color3.fromRGB(0, 0, 0),
                        Name = "Knob"
                    })
                    
                    Linux.Instance("UICorner", {
                        Parent = SliderKnob,
                        CornerRadius = UDim.new(1, 0)
                    })
                    
                    local SliderButton = Linux.Instance("TextButton", {
                        Parent = SliderTrack,
                        BackgroundTransparency = 1,
                        Size = UDim2.new(1, 0, 1, 0),
                        Text = "",
                        ZIndex = 1003
                    })
                    
                    local isDragging = false
                    
                    local function updateSlider(pos)
                        local relativePos = math.clamp((pos - SliderTrack.AbsolutePosition.X) / SliderTrack.AbsoluteSize.X, 0, 1)
                        local newValue = math.floor(relativePos * 255)
                        
                        ValueText.Text = tostring(newValue)
                        SliderFill.Size = UDim2.new(relativePos, 0, 1, 0)
                        SliderKnob.Position = UDim2.new(relativePos, -3, 0.5, -3)
                        
                        return newValue
                    end
                    
                    SliderButton.InputBegan:Connect(function(input)
                        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                            isDragging = true
                            local newValue = updateSlider(input.Position.X)
                            
                            if colorName == "R" then
                                CurrentColor = Color3.fromRGB(newValue, CurrentColor.G * 255, CurrentColor.B * 255)
                            elseif colorName == "G" then
                                CurrentColor = Color3.fromRGB(CurrentColor.R * 255, newValue, CurrentColor.B * 255)
                            elseif colorName == "B" then
                                CurrentColor = Color3.fromRGB(CurrentColor.R * 255, CurrentColor.G * 255, newValue)
                            end
                            
                            currentH, currentS, currentV = RGBToHSV(CurrentColor.R, CurrentColor.G, CurrentColor.B)
                            updateColorArea()
                            updateCursorPosition()
                            ColorDisplay.BackgroundColor3 = CurrentColor
                            HexInput.Text = RGBToHex(CurrentColor)
                            if RealTimeUpdate then
                                spawn(function() Linux:SafeCallback(config.Callback, CurrentColor) end)
                            end
                        end
                    end)
                    
                    SliderButton.InputChanged:Connect(function(input)
                        if isDragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
                            local newValue = updateSlider(input.Position.X)
                            
                            if colorName == "R" then
                                CurrentColor = Color3.fromRGB(newValue, CurrentColor.G * 255, CurrentColor.B * 255)
                            elseif colorName == "G" then
                                CurrentColor = Color3.fromRGB(CurrentColor.R * 255, newValue, CurrentColor.B * 255)
                            elseif colorName == "B" then
                                CurrentColor = Color3.fromRGB(CurrentColor.R * 255, CurrentColor.G * 255, newValue)
                            end
                            
                            currentH, currentS, currentV = RGBToHSV(CurrentColor.R, CurrentColor.G, CurrentColor.B)
                            updateColorArea()
                            updateCursorPosition()
                            ColorDisplay.BackgroundColor3 = CurrentColor
                            HexInput.Text = RGBToHex(CurrentColor)
                            if RealTimeUpdate then
                                spawn(function() Linux:SafeCallback(config.Callback, CurrentColor) end)
                            end
                        end
                    end)
                    
                    SliderButton.InputEnded:Connect(function(input)
                        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                            isDragging = false
                        end
                    end)
                    
                    return SliderTrack, ValueText
                end
                
                RedSlider, RedValue = createRGBSlider("R", UDim2.new(0, 8, 0, isMobile and 200 or 220), math.floor(CurrentColor.R * 255))
                GreenSlider, GreenValue = createRGBSlider("G", UDim2.new(0, 8, 0, isMobile and 220 or 240), math.floor(CurrentColor.G * 255))
                BlueSlider, BlueValue = createRGBSlider("B", UDim2.new(0, 8, 0, isMobile and 240 or 260), math.floor(CurrentColor.B * 255))
                
                HexInput:GetPropertyChangedSignal("Text"):Connect(function()
                    local validatedHex = ValidateHexInput(HexInput.Text)
                    if validatedHex ~= HexInput.Text then
                        HexInput.Text = validatedHex
                    end
                end)
                
                HexInput.FocusLost:Connect(function(enterPressed)
                    local hexColor = HexToRGB(HexInput.Text)
                    if hexColor then
                        CurrentColor = hexColor
                        currentH, currentS, currentV = RGBToHSV(CurrentColor.R, CurrentColor.G, CurrentColor.B)
                        updateColorArea()
                        updateCursorPosition()
                        updateRGBSliders()
                        ColorDisplay.BackgroundColor3 = CurrentColor
                        if RealTimeUpdate then
                            spawn(function() Linux:SafeCallback(config.Callback, CurrentColor) end)
                        end
                    else
                        HexInput.Text = RGBToHex(CurrentColor)
                    end
                end)
                
                local isDraggingColor = false
                
                ColorAreaButton.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                        isDraggingColor = true
                        local relativeX = math.clamp((input.Position.X - ColorArea.AbsolutePosition.X) / ColorArea.AbsoluteSize.X, 0, 1)
                        local relativeY = math.clamp((input.Position.Y - ColorArea.AbsolutePosition.Y) / ColorArea.AbsoluteSize.Y, 0, 1)
                        
                        currentS = relativeX
                        currentV = 1 - relativeY
                        
                        updateCurrentColor()
                        updateCursorPosition()
                    end
                end)
                
                ColorAreaButton.InputChanged:Connect(function(input)
                    if isDraggingColor and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
                        local relativeX = math.clamp((input.Position.X - ColorArea.AbsolutePosition.X) / ColorArea.AbsoluteSize.X, 0, 1)
                        local relativeY = math.clamp((input.Position.Y - ColorArea.AbsolutePosition.Y) / ColorArea.AbsoluteSize.Y, 0, 1)
                        
                        currentS = relativeX
                        currentV = 1 - relativeY
                        
                        updateCurrentColor()
                        updateCursorPosition()
                    end
                end)
                
                ColorAreaButton.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                        isDraggingColor = false
                    end
                end)
                
                local function closeDialog()
                    local closeTweenOverlay = TweenService:Create(ColorOverlay, TweenInfo.new(0.15), {BackgroundTransparency = 1})
                    local closeTweenDialog = TweenService:Create(DialogFrame, TweenInfo.new(0.15), {BackgroundTransparency = 1})
                    
                    closeTweenOverlay:Play()
                    closeTweenDialog:Play()
                    
                    closeTweenDialog.Completed:Wait()
                    
                    for _, element in pairs(Main:GetDescendants()) do
                        if element:IsA("TextButton") or element:IsA("TextBox") or element:IsA("ImageButton") then
                            element.Active = true
                        end
                    end
                    ColorOverlay:Destroy()
                    
                    if not RealTimeUpdate then
                        spawn(function() Linux:SafeCallback(config.Callback, CurrentColor) end)
                    end
                end
                
                ClosePickerButton.MouseButton1Click:Connect(function()
                    closeDialog()
                end)
                
                ColorOverlay.MouseButton1Click:Connect(function()
                    closeDialog()
                end)
                
                DialogFrame.MouseButton1Click:Connect(function() end)
                
                InputService.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        if isDraggingColor then
                            isDraggingColor = false
                        end
                    end
                end)
            end
            
            ColorDisplay.MouseButton1Click:Connect(function()
                createColorPickerDialog()
            end)
            
            local function SetValue(newColor)
                if typeof(newColor) == "Color3" then
                    CurrentColor = newColor
                    ColorDisplay.BackgroundColor3 = CurrentColor
                    if not RealTimeUpdate then
                        spawn(function() Linux:SafeCallback(config.Callback, CurrentColor) end)
                    end
                end
            end
            
            if not RealTimeUpdate then
                spawn(function() Linux:SafeCallback(config.Callback, CurrentColor) end)
            end
            
            targetContainer.CanvasPosition = Vector2.new(0, 0)
            
            local element = {
                Type = "ColorPicker",
                Name = config.Name,
                Instance = ColorPicker,
                Value = CurrentColor
            }
            table.insert(Tabs[tabIndex].Elements, element)
            table.insert(AllElements, {Tab = tabIndex, Element = element})
            
            table.insert(Linux.SavedElements, {
                Element = element,
                TabName = Tabs[tabIndex].Name,
                GetValue = function() return CurrentColor end,
                SetValue = SetValue
            })
            
            CheckEmptyState()
            
            return {
                Instance = ColorPicker,
                SetValue = SetValue,
                GetValue = function() return CurrentColor end
            }
        end
        
        return TabElements
    end
    
    if config.ConfigSave ~= false then
        local SettingsTab = LinuxLib.Tab({
            Name = "UI",
            Icon = "rbxassetid://10734950309",
            Enabled = false
        })
        
        SettingsTab.Section({Name = "Settings"})
        
        local configNameInput = SettingsTab.Input({
            Name = "Config Name",
            Placeholder = "Config",
            Default = Linux.CurrentConfig,
            Callback = function(text)
                Linux.CurrentConfig = text
            end
        })
        
        Linux.LoadConfigList()
        
        local configListDropdown = SettingsTab.Dropdown({
            Name = "Config List",
            Options = Linux.SavedConfigs,
            Default = Linux.SavedConfigs[1] or "",
            Callback = function(selected)
                configNameInput.SetValue(selected)
                Linux.CurrentConfig = selected
            end
        })
        
        SettingsTab.Button({
            Name = "Create Config",
            Callback = function()
                local success, result = Linux.SaveConfig(Linux.CurrentConfig)
                if success then
                    Linux.LoadConfigList()
                    configListDropdown.SetOptions(Linux.SavedConfigs)
                else
                    print("Failed to create config:", result)
                end
            end
        })
        
        SettingsTab.Button({
            Name = "Load Config",
            Callback = function()
                local success, result = Linux.LoadConfig(Linux.CurrentConfig)
                if not success then
                    print("Failed to load config:", result)
                end
            end
        })
        
        SettingsTab.Button({
            Name = "Delete Config",
            Callback = function()
                local success, result = Linux.DeleteConfig(Linux.CurrentConfig)
                if success then
                    Linux.LoadConfigList()
                    configListDropdown.SetOptions(Linux.SavedConfigs)
                    if #Linux.SavedConfigs > 0 then
                        configNameInput.SetValue(Linux.SavedConfigs[1])
                        Linux.CurrentConfig = Linux.SavedConfigs[1]
                    else
                        configNameInput.SetValue("")
                        Linux.CurrentConfig = ""
                    end
                else
                    print("Failed to delete config:", result)
                end
            end
        })
        
        SettingsTab.Section({Name = "Initialization"})
        local autoLoadConfigInput = SettingsTab.Input({
            Name = "Load Config",
            Description = "",
            Placeholder = "Config Name",
            Default = Linux.AutoLoadConfig,
            Callback = function(text)
                Linux.AutoLoadConfig = text
                Linux.SaveAutoLoadSettings()
            end,
            IsAutoLoadInput = true
        })
        
        table.insert(Linux.SavedElements, {
            Element = {
                Type = "Input",
                Name = "Load Config"
            },
            TabName = "UI",
            GetValue = function() return Linux.AutoLoadConfig end,
            SetValue = function(value) 
                Linux.AutoLoadConfig = value
                autoLoadConfigInput.SetValue(value)
            end,
            IsAutoLoadInput = true
        })
        
        local autoLoadToggle = SettingsTab.Toggle({
            Name = "Auto Load",
            Description = "",
            Default = Linux.AutoLoadEnabled,
            Callback = function(state)
                Linux.AutoLoadEnabled = state
                Linux.SaveAutoLoadSettings()
            end
        })
        
        SettingsTab.Section({Name = "Privacy"})
        local privacyToggle = SettingsTab.Toggle({
            Name = "Anonymous Mode",
            Description = "Hide your display name within the interface.",
            Default = Linux.PrivacyEnabled,
            Callback = function(state)
                Linux.PrivacyEnabled = state
                Linux.SavePrivacySettings()
                UpdatePrivacyDisplay()
            end
        })
        
        SettingsTab.Section({Name = "Accents"})
        local themeDropdown = SettingsTab.Dropdown({
            Name = "Select Accent",
            Description = "Choose the best color for you",
            Options = {"Orange", "Purple", "Blue", "Red", "Green"},
            Default = Linux.CurrentTheme,
            Callback = function(selected)
                Linux.SelectedTheme = selected
            end
        })
        
        SettingsTab.Button({
            Name = "Apply Accent",
            Description = "Apply the selected color and save.",
            Callback = function()
                Linux.ApplyTheme(Linux.SelectedTheme)
                Linux.SaveThemeSettings()
            end
        })
        
        Linux.SetIgnoreIndexes({
            "Config Name",
            "Config List",
            "Load Config",
            "Auto Load",
            "Anonymous Mode",
            "Select Accent"
        })
    end
    
    if Linux.AutoLoadEnabled and Linux.AutoLoadConfig ~= "" then
        task.spawn(function()
            task.wait(1)
            local success, result = Linux.LoadConfig(Linux.AutoLoadConfig)
            if not success then
                print("Failed to auto-load config:", result)
            end
        end)
    end
    
    function LinuxLib.Destroy()
        LinuxUI:Destroy()
        if ToggleUI then
            ToggleUI:Destroy()
        end
    end
    
    return LinuxLib
end

return Linux
