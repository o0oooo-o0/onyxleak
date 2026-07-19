getgenv().Library = (function()

local Services = setmetatable({}, {
    __index = function(self, serviceName)
        local success, service = pcall(game.GetService, game, serviceName)
        if success and service then rawset(self, serviceName, service) return service end
        return nil
    end
})

local TweenService     = Services.TweenService
local UserInputService = Services.UserInputService
local RunService       = Services.RunService
local Players          = Services.Players

local ScreenGui = Instance.new('ScreenGui')
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 2147483647
ScreenGui.Name = "NewTestGui"
ScreenGui.Parent = (gethui and gethui()) or Services.CoreGui

local IsTouch = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

local Toggles = {}
local Options = {}

local Library = {
    Registry            = {};
    RegistryMap         = {};
    HudRegistry         = {};
    FontColor           = Color3.fromRGB(235, 235, 240);
    DimFontColor        = Color3.fromRGB(150, 150, 160);
    MainColor           = Color3.fromRGB(26,  26,  32 );
    BackgroundColor     = Color3.fromRGB(18,  18,  22 );
    SurfaceColor        = Color3.fromRGB(32,  32,  40 );
    AccentColor         = Color3.fromRGB(120, 130, 255);
    OutlineColor        = Color3.fromRGB(45,  45,  55 );
    RiskColor           = Color3.fromRGB(255, 80,  80 );
    Black               = Color3.new(0, 0, 0);
    Font                = Enum.Font.Gotham;
    FontBold            = Enum.Font.GothamBold;
    CornerRadius        = 8;
    OpenedFrames        = {};
    Signals             = {};
    UnloadCallbacks     = {};
    DependencyBoxes     = {};
    VisibilityCallbacks = {};
    ScreenGui           = ScreenGui;
    Toggled             = false;
    Unloaded            = false;
}

Library.AccentColorDark = Color3.fromRGB(80, 88, 190)
Library.Toggles = Toggles
Library.Options = Options

local TweenFast   = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TweenSmooth = TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local TweenSlow   = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local TweenBounce = TweenInfo.new(0.30, Enum.EasingStyle.Back,  Enum.EasingDirection.Out)

local function Animate(instance, properties, tweenInfo)
    local tween = TweenService:Create(instance, tweenInfo or TweenSmooth, properties)
    tween:Play()
    return tween
end

function Library:GetDarkerColor(color)
    local hue, saturation, value = Color3.toHSV(color)
    return Color3.fromHSV(hue, saturation, value * 0.66)
end

function Library:MapValue(value, inMin, inMax, outMin, outMax)
    return outMin + (outMax - outMin) * ((value - inMin) / (inMax - inMin))
end

function Library:SafeCallback(callback, ...)
    if not callback then return end
    local success, result = pcall(callback, ...)
    if not success then
        task.defer(error, result)
    end
end

function Library:GiveSignal(signal)
    table.insert(Library.Signals, signal)
    return signal
end

function Library:OnUnload(callback)
    table.insert(Library.UnloadCallbacks, callback)
end

function Library:AttemptSave()
    if Library.SaveManager then
        pcall(function() Library.SaveManager:Save(Library.SaveManager.SelectedConfig or 'autosave') end)
    end
end

function Library:Create(className, properties)
    local instance = Instance.new(className)
    for propertyName, propertyValue in pairs(properties) do
        if propertyName ~= 'Parent' then
            instance[propertyName] = propertyValue
        end
    end
    instance.Parent = properties.Parent
    return instance
end

local function Round(instance, radius)
    return Library:Create('UICorner', { CornerRadius = UDim.new(0, radius or Library.CornerRadius); Parent = instance })
end

local function Stroke(instance, color, transparency)
    local uiStroke = Library:Create('UIStroke', {
        Color = color or Library.OutlineColor;
        Transparency = transparency or 0;
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border;
        Parent = instance;
    })
    return uiStroke
end

function Library:CreateLabel(properties)
    local defaults = {
        BackgroundTransparency = 1;
        Font = Library.Font;
        TextColor3 = Library.FontColor;
        TextSize = 13;
        Text = '';
    }
    for propertyName, propertyValue in pairs(properties) do defaults[propertyName] = propertyValue end
    return Library:Create('TextLabel', defaults)
end

function Library:ApplyCase(text) return text end
function Library:TrackLabel() end
function Library:AddToRegistry(instance, registryProperties)
    local registryData = { Instance = instance; Properties = registryProperties }
    table.insert(Library.Registry, registryData)
    Library.RegistryMap[instance] = registryData
end
function Library:RemoveFromRegistry(instance)
    local registryData = Library.RegistryMap[instance]
    if registryData then
        for index, data in ipairs(Library.Registry) do
            if data == registryData then table.remove(Library.Registry, index) break end
        end
        Library.RegistryMap[instance] = nil
    end
end
function Library:UpdateColorsUsingRegistry()
    for _, registryData in ipairs(Library.Registry) do
        for propertyName, colorKey in pairs(registryData.Properties) do
            if type(colorKey) == 'string' and Library[colorKey] then
                registryData.Instance[propertyName] = Library[colorKey]
            end
        end
    end
end

function Library:SetAccentColor(color)
    Library.AccentColor = color
    Library.AccentColorDark = Library:GetDarkerColor(color)
    Library:UpdateColorsUsingRegistry()
    for _, toggle in pairs(Toggles) do
        if toggle.UpdateColors then toggle:UpdateColors() end
    end
    for _, option in pairs(Options) do
        if option.UpdateColors then option:UpdateColors() end
    end
end

function Library:IsPointerInput(input)
    return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

function Library:HasOpenedFrames()
    for _, frame in pairs(Library.OpenedFrames) do
        if frame.Visible then return true end
    end
    return false
end

function Library:MouseIsOverOpenedFrame()
    local mouseLocation = UserInputService:GetMouseLocation()
    for frame in pairs(Library.OpenedFrames) do
        local absolutePosition = frame.AbsolutePosition
        local absoluteSize = frame.AbsoluteSize
        if mouseLocation.X >= absolutePosition.X and mouseLocation.X <= absolutePosition.X + absoluteSize.X
        and mouseLocation.Y >= absolutePosition.Y and mouseLocation.Y <= absolutePosition.Y + absoluteSize.Y then
            return true
        end
    end
    return false
end

function Library:MakeDraggable(frame, dragHandle)
    local handle = (typeof(dragHandle) == 'Instance') and dragHandle or frame
    local dragging = false
    local dragStart, startPosition

    handle.InputBegan:Connect(function(input)
        if Library:IsPointerInput(input) then
            dragging = true
            dragStart = input.Position
            startPosition = frame.Position
        end
    end)
    Library:GiveSignal(UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                startPosition.X.Scale, startPosition.X.Offset + delta.X,
                startPosition.Y.Scale, startPosition.Y.Offset + delta.Y
            )
        end
    end))
    Library:GiveSignal(UserInputService.InputEnded:Connect(function(input)
        if Library:IsPointerInput(input) then dragging = false end
    end))
end

do
    local TooltipFrame = Library:Create('Frame', {
        BackgroundColor3 = Library.SurfaceColor;
        BorderSizePixel = 0;
        Size = UDim2.fromOffset(0, 26);
        ZIndex = 500;
        Visible = false;
        Parent = ScreenGui;
    })
    Round(TooltipFrame, 6)
    Stroke(TooltipFrame, Library.OutlineColor)
    local TooltipLabel = Library:CreateLabel({
        Size = UDim2.new(1, -12, 1, 0);
        Position = UDim2.fromOffset(6, 0);
        TextSize = 12;
        ZIndex = 501;
        Parent = TooltipFrame;
    })

    function Library:AddToolTip(text, hoverInstance)
        hoverInstance.MouseEnter:Connect(function()
            TooltipLabel.Text = text
            local textWidth = Services.TextService:GetTextSize(text, 12, Library.Font, Vector2.new(1000, 26)).X
            TooltipFrame.Size = UDim2.fromOffset(textWidth + 16, 26)
            TooltipFrame.Visible = true
            TooltipFrame.BackgroundTransparency = 1
            TooltipLabel.TextTransparency = 1
            Animate(TooltipFrame, { BackgroundTransparency = 0 }, TweenFast)
            Animate(TooltipLabel, { TextTransparency = 0 }, TweenFast)
        end)
        hoverInstance.MouseMoved:Connect(function()
            local mouseLocation = UserInputService:GetMouseLocation()
            TooltipFrame.Position = UDim2.fromOffset(mouseLocation.X + 14, mouseLocation.Y + 10)
        end)
        hoverInstance.MouseLeave:Connect(function()
            TooltipFrame.Visible = false
        end)
    end
end

function Library:UpdateDependencyBoxes()
    for _, dependencyBox in ipairs(Library.DependencyBoxes) do
        dependencyBox:Update()
    end
end

do
    local NotificationHolder = Library:Create('Frame', {
        AnchorPoint = Vector2.new(1, 0);
        BackgroundTransparency = 1;
        Position = UDim2.new(1, -16, 0, 16);
        Size = UDim2.fromOffset(280, 800);
        ZIndex = 600;
        Parent = ScreenGui;
    })
    Library:Create('UIListLayout', {
        Padding = UDim.new(0, 8);
        HorizontalAlignment = Enum.HorizontalAlignment.Right;
        SortOrder = Enum.SortOrder.LayoutOrder;
        Parent = NotificationHolder;
    })

    function Library:Notify(text, duration)
        duration = duration or 4
        local NotificationFrame = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderSizePixel = 0;
            Size = UDim2.fromOffset(0, 40);
            ClipsDescendants = true;
            ZIndex = 601;
            Parent = NotificationHolder;
        })
        Round(NotificationFrame, 8)
        Stroke(NotificationFrame, Library.OutlineColor)
        local AccentBar = Library:Create('Frame', {
            BackgroundColor3 = Library.AccentColor;
            BorderSizePixel = 0;
            Size = UDim2.new(0, 3, 1, -12);
            Position = UDim2.fromOffset(6, 6);
            ZIndex = 602;
            Parent = NotificationFrame;
        })
        Round(AccentBar, 2)
        local NotificationLabel = Library:CreateLabel({
            Size = UDim2.new(1, -24, 1, 0);
            Position = UDim2.fromOffset(18, 0);
            Text = text;
            TextXAlignment = Enum.TextXAlignment.Left;
            TextTransparency = 1;
            ZIndex = 602;
            Parent = NotificationFrame;
        })
        local textWidth = Services.TextService:GetTextSize(text, 13, Library.Font, Vector2.new(1000, 40)).X
        local targetWidth = math.min(textWidth + 34, 280)
        Animate(NotificationFrame, { Size = UDim2.fromOffset(targetWidth, 40) }, TweenBounce)
        Animate(NotificationLabel, { TextTransparency = 0 }, TweenSmooth)
        task.delay(duration, function()
            Animate(NotificationLabel, { TextTransparency = 1 }, TweenFast)
            local closeTween = Animate(NotificationFrame, { Size = UDim2.fromOffset(0, 40) }, TweenSmooth)
            closeTween.Completed:Wait()
            NotificationFrame:Destroy()
        end)
    end
end

do
    local WatermarkFrame = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderSizePixel = 0;
        Position = UDim2.fromOffset(16, 16);
        Size = UDim2.fromOffset(0, 30);
        Visible = false;
        ZIndex = 550;
        Parent = ScreenGui;
    })
    Round(WatermarkFrame, 8)
    Stroke(WatermarkFrame, Library.OutlineColor)
    local WatermarkLabel = Library:CreateLabel({
        Size = UDim2.new(1, -16, 1, 0);
        Position = UDim2.fromOffset(8, 0);
        TextXAlignment = Enum.TextXAlignment.Left;
        ZIndex = 551;
        Parent = WatermarkFrame;
    })
    Library:MakeDraggable(WatermarkFrame)
    Library.Watermark = WatermarkFrame

    function Library:SetWatermark(text)
        WatermarkLabel.Text = text
        local textWidth = Services.TextService:GetTextSize(text, 13, Library.Font, Vector2.new(2000, 30)).X
        Animate(WatermarkFrame, { Size = UDim2.fromOffset(textWidth + 16, 30) }, TweenSmooth)
        WatermarkFrame.Visible = true
    end
    function Library:SetWatermarkVisibility(visible)
        WatermarkFrame.Visible = visible
    end
end

function Library:Unload()
    Library.Unloaded = true
    for _, callback in ipairs(Library.UnloadCallbacks) do
        Library:SafeCallback(callback)
    end
    for _, signal in ipairs(Library.Signals) do
        pcall(function() signal:Disconnect() end)
    end
    ScreenGui:Destroy()
    getgenv().Library = nil
end

local BaseAddons = {}
BaseAddons.__index = BaseAddons

local function CreateColorPickerPopup(colorPickerData, swatchButton)
    local PopupFrame = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderSizePixel = 0;
        Size = UDim2.fromOffset(200, 230);
        Visible = false;
        ZIndex = 300;
        Parent = ScreenGui;
    })
    Round(PopupFrame, 10)
    Stroke(PopupFrame, Library.OutlineColor)
    Library.OpenedFrames[PopupFrame] = PopupFrame

    local SaturationMap = Library:Create('ImageButton', {
        BackgroundColor3 = Color3.fromHSV(colorPickerData.Hue, 1, 1);
        BorderSizePixel = 0;
        Position = UDim2.fromOffset(10, 10);
        Size = UDim2.fromOffset(180, 150);
        Image = 'rbxassetid://4155801252';
        AutoButtonColor = false;
        ZIndex = 301;
        Parent = PopupFrame;
    })
    Round(SaturationMap, 8)
    local SaturationCursor = Library:Create('Frame', {
        AnchorPoint = Vector2.new(0.5, 0.5);
        BackgroundColor3 = Color3.new(1, 1, 1);
        BorderSizePixel = 0;
        Size = UDim2.fromOffset(10, 10);
        ZIndex = 303;
        Parent = SaturationMap;
    })
    Round(SaturationCursor, 5)
    Stroke(SaturationCursor, Color3.new(0, 0, 0), 0.5)

    local HueBar = Library:Create('TextButton', {
        BackgroundColor3 = Color3.new(1, 1, 1);
        BorderSizePixel = 0;
        Position = UDim2.fromOffset(10, 168);
        Size = UDim2.fromOffset(180, 14);
        Text = '';
        AutoButtonColor = false;
        ZIndex = 301;
        Parent = PopupFrame;
    })
    Round(HueBar, 7)
    Library:Create('UIGradient', {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 0, 0));
            ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0));
            ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0));
            ColorSequenceKeypoint.new(0.50, Color3.fromRGB(0, 255, 255));
            ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255));
            ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255));
            ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 0, 0));
        });
        Parent = HueBar;
    })
    local HueCursor = Library:Create('Frame', {
        AnchorPoint = Vector2.new(0.5, 0.5);
        BackgroundColor3 = Color3.new(1, 1, 1);
        BorderSizePixel = 0;
        Position = UDim2.new(0, 0, 0.5, 0);
        Size = UDim2.fromOffset(6, 18);
        ZIndex = 302;
        Parent = HueBar;
    })
    Round(HueCursor, 3)
    Stroke(HueCursor, Color3.new(0, 0, 0), 0.5)

    local PreviewFrame = Library:Create('Frame', {
        BackgroundColor3 = colorPickerData.Value;
        BorderSizePixel = 0;
        Position = UDim2.fromOffset(10, 192);
        Size = UDim2.fromOffset(180, 28);
        ZIndex = 301;
        Parent = PopupFrame;
    })
    Round(PreviewFrame, 8)
    Stroke(PreviewFrame, Library.OutlineColor)

    local function UpdateVisuals()
        SaturationMap.BackgroundColor3 = Color3.fromHSV(colorPickerData.Hue, 1, 1)
        SaturationCursor.Position = UDim2.new(colorPickerData.Sat, 0, 1 - colorPickerData.Vib, 0)
        HueCursor.Position = UDim2.new(colorPickerData.Hue, 0, 0.5, 0)
        Animate(PreviewFrame, { BackgroundColor3 = colorPickerData.Value }, TweenFast)
    end

    local function ApplyHSV()
        colorPickerData.Value = Color3.fromHSV(colorPickerData.Hue, colorPickerData.Sat, colorPickerData.Vib)
        UpdateVisuals()
        colorPickerData:Display()
        Library:SafeCallback(colorPickerData.Callback, colorPickerData.Value)
        Library:SafeCallback(colorPickerData.Changed, colorPickerData.Value)
    end

    local draggingMap = false
    local draggingHue = false
    SaturationMap.InputBegan:Connect(function(input)
        if Library:IsPointerInput(input) then draggingMap = true end
    end)
    HueBar.InputBegan:Connect(function(input)
        if Library:IsPointerInput(input) then draggingHue = true end
    end)
    Library:GiveSignal(UserInputService.InputEnded:Connect(function(input)
        if Library:IsPointerInput(input) then draggingMap = false draggingHue = false end
    end))
    Library:GiveSignal(RunService.RenderStepped:Connect(function()
        if not PopupFrame.Visible then return end
        local mouseLocation = UserInputService:GetMouseLocation()
        if draggingMap then
            local relativeX = math.clamp((mouseLocation.X - SaturationMap.AbsolutePosition.X) / SaturationMap.AbsoluteSize.X, 0, 1)
            local relativeY = math.clamp((mouseLocation.Y - SaturationMap.AbsolutePosition.Y) / SaturationMap.AbsoluteSize.Y, 0, 1)
            colorPickerData.Sat = relativeX
            colorPickerData.Vib = 1 - relativeY
            ApplyHSV()
        elseif draggingHue then
            local relativeX = math.clamp((mouseLocation.X - HueBar.AbsolutePosition.X) / HueBar.AbsoluteSize.X, 0, 1)
            colorPickerData.Hue = relativeX
            ApplyHSV()
        end
    end))

    local function OpenPopup()
        local absolutePosition = swatchButton.AbsolutePosition
        PopupFrame.Position = UDim2.fromOffset(absolutePosition.X, absolutePosition.Y + swatchButton.AbsoluteSize.Y + 6)
        PopupFrame.Visible = true
        PopupFrame.BackgroundTransparency = 1
        UpdateVisuals()
        Animate(PopupFrame, { BackgroundTransparency = 0 }, TweenFast)
    end
    local function ClosePopup()
        PopupFrame.Visible = false
    end

    Library:GiveSignal(UserInputService.InputBegan:Connect(function(input)
        if PopupFrame.Visible and Library:IsPointerInput(input) then
            local mouseLocation = UserInputService:GetMouseLocation()
            local insidePopup = mouseLocation.X >= PopupFrame.AbsolutePosition.X and mouseLocation.X <= PopupFrame.AbsolutePosition.X + PopupFrame.AbsoluteSize.X
                and mouseLocation.Y >= PopupFrame.AbsolutePosition.Y and mouseLocation.Y <= PopupFrame.AbsolutePosition.Y + PopupFrame.AbsoluteSize.Y
            local insideSwatch = mouseLocation.X >= swatchButton.AbsolutePosition.X and mouseLocation.X <= swatchButton.AbsolutePosition.X + swatchButton.AbsoluteSize.X
                and mouseLocation.Y >= swatchButton.AbsolutePosition.Y and mouseLocation.Y <= swatchButton.AbsolutePosition.Y + swatchButton.AbsoluteSize.Y
            if not insidePopup and not insideSwatch then ClosePopup() end
        end
    end))

    return OpenPopup, ClosePopup, PopupFrame
end

function BaseAddons:AddColorPicker(index, info)
    info = info or {}
    local parentElement = self
    local ColorPickerData = {
        Value = info.Default or Color3.new(1, 1, 1);
        Transparency = info.Transparency or 0;
        Type = 'ColorPicker';
        Title = info.Title;
        Callback = info.Callback or function() end;
    }
    ColorPickerData.Hue, ColorPickerData.Sat, ColorPickerData.Vib = Color3.toHSV(ColorPickerData.Value)

    local holder = parentElement.AddonHolder
    local SwatchButton = Library:Create('TextButton', {
        BackgroundColor3 = ColorPickerData.Value;
        BorderSizePixel = 0;
        Size = UDim2.fromOffset(24, 14);
        Text = '';
        AutoButtonColor = false;
        ZIndex = 10;
        Parent = holder;
    })
    Round(SwatchButton, 5)
    Stroke(SwatchButton, Library.OutlineColor)
    ColorPickerData.DisplayFrame = SwatchButton

    function ColorPickerData:Display()
        Animate(SwatchButton, { BackgroundColor3 = ColorPickerData.Value }, TweenFast)
    end
    function ColorPickerData:SetValue(hsv, transparency)
        ColorPickerData.Hue, ColorPickerData.Sat, ColorPickerData.Vib = hsv[1], hsv[2], hsv[3]
        ColorPickerData.Value = Color3.fromHSV(hsv[1], hsv[2], hsv[3])
        ColorPickerData.Transparency = transparency or 0
        ColorPickerData:Display()
        Library:SafeCallback(ColorPickerData.Callback, ColorPickerData.Value)
        Library:SafeCallback(ColorPickerData.Changed, ColorPickerData.Value)
    end
    function ColorPickerData:SetValueRGB(color, transparency)
        ColorPickerData.Hue, ColorPickerData.Sat, ColorPickerData.Vib = Color3.toHSV(color)
        ColorPickerData.Value = color
        ColorPickerData.Transparency = transparency or 0
        ColorPickerData:Display()
        Library:SafeCallback(ColorPickerData.Callback, ColorPickerData.Value)
        Library:SafeCallback(ColorPickerData.Changed, ColorPickerData.Value)
    end
    function ColorPickerData:OnChanged(callback)
        ColorPickerData.Changed = callback
        callback(ColorPickerData.Value)
    end

    local OpenPopup = CreateColorPickerPopup(ColorPickerData, SwatchButton)
    SwatchButton.MouseButton1Click:Connect(OpenPopup)

    if parentElement.Addons then table.insert(parentElement.Addons, ColorPickerData) end
    Options[index] = ColorPickerData
    return self
end

local KeyNameOverrides = {
    LeftControl = 'LCtrl'; RightControl = 'RCtrl';
    LeftShift = 'LShift'; RightShift = 'RShift';
    LeftAlt = 'LAlt'; RightAlt = 'RAlt';
    MouseButton1 = 'MB1'; MouseButton2 = 'MB2'; MouseButton3 = 'MB3';
}
local function FormatKeyName(keyName)
    return KeyNameOverrides[keyName] or keyName
end

function BaseAddons:AddKeyPicker(index, info)
    info = info or {}
    local parentElement = self
    local KeyPickerData = {
        Value = info.Default or 'None';
        Mode = info.Mode or 'Toggle';
        Type = 'KeyPicker';
        Toggled = false;
        SyncToggleState = info.SyncToggleState or false;
        Callback = info.Callback or function() end;
        NoUI = info.NoUI;
        Text = info.Text or '';
    }

    local holder = parentElement.AddonHolder
    local KeyButton = Library:Create('TextButton', {
        BackgroundColor3 = Library.SurfaceColor;
        BorderSizePixel = 0;
        Size = UDim2.fromOffset(38, 16);
        Font = Library.Font;
        Text = FormatKeyName(KeyPickerData.Value);
        TextColor3 = Library.DimFontColor;
        TextSize = 10;
        AutoButtonColor = false;
        ZIndex = 10;
        Parent = holder;
    })
    Round(KeyButton, 5)
    Stroke(KeyButton, Library.OutlineColor)
    KeyPickerData.DisplayFrame = KeyButton

    local function ResizeButton()
        local textWidth = Services.TextService:GetTextSize(KeyButton.Text, 10, Library.Font, Vector2.new(200, 16)).X
        Animate(KeyButton, { Size = UDim2.fromOffset(math.max(textWidth + 12, 26), 16) }, TweenFast)
    end

    function KeyPickerData:Update()
        KeyButton.Text = FormatKeyName(KeyPickerData.Value)
        ResizeButton()
    end
    function KeyPickerData:GetState()
        if KeyPickerData.Mode == 'Always' then return true end
        return KeyPickerData.Toggled
    end
    function KeyPickerData:SetValue(data)
        KeyPickerData.Value = data[1]
        KeyPickerData.Mode = data[2] or KeyPickerData.Mode
        KeyPickerData:Update()
    end
    function KeyPickerData:OnClick(callback) KeyPickerData.Clicked = callback end
    function KeyPickerData:OnChanged(callback)
        KeyPickerData.Changed = callback
        callback(KeyPickerData.Value)
    end
    function KeyPickerData:DoClick()
        if parentElement.Type == 'Toggle' and KeyPickerData.SyncToggleState then
            parentElement:SetValue(not parentElement.Value)
        else
            KeyPickerData.Toggled = not KeyPickerData.Toggled
        end
        Library:SafeCallback(KeyPickerData.Callback, KeyPickerData.Toggled)
        Library:SafeCallback(KeyPickerData.Clicked, KeyPickerData.Toggled)
    end

    local awaitingBind = false
    KeyButton.MouseButton1Click:Connect(function()
        awaitingBind = true
        KeyButton.Text = '...'
        Animate(KeyButton, { TextColor3 = Library.AccentColor }, TweenFast)
        ResizeButton()
    end)

    Library:GiveSignal(UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if awaitingBind then
            local keyName
            if input.UserInputType == Enum.UserInputType.Keyboard then
                keyName = input.KeyCode.Name
                if keyName == 'Escape' then keyName = 'None' end
            elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
                keyName = 'MouseButton2'
            elseif input.UserInputType == Enum.UserInputType.MouseButton3 then
                keyName = 'MouseButton3'
            end
            if keyName then
                awaitingBind = false
                KeyPickerData.Value = keyName
                KeyPickerData:Update()
                Animate(KeyButton, { TextColor3 = Library.DimFontColor }, TweenFast)
                Library:SafeCallback(KeyPickerData.ChangedCallback, keyName)
                Library:SafeCallback(KeyPickerData.Changed, keyName)
                Library:AttemptSave()
            end
            return
        end
        if gameProcessed then return end
        local matches = false
        if input.UserInputType == Enum.UserInputType.Keyboard and KeyPickerData.Value ~= 'None' then
            matches = input.KeyCode.Name == KeyPickerData.Value
        elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
            matches = KeyPickerData.Value == 'MouseButton2'
        elseif input.UserInputType == Enum.UserInputType.MouseButton3 then
            matches = KeyPickerData.Value == 'MouseButton3'
        end
        if matches then
            if KeyPickerData.Mode == 'Hold' then
                KeyPickerData.Toggled = true
                Library:SafeCallback(KeyPickerData.Callback, true)
            else
                KeyPickerData:DoClick()
            end
        end
    end))
    Library:GiveSignal(UserInputService.InputEnded:Connect(function(input)
        if KeyPickerData.Mode ~= 'Hold' then return end
        local matches = false
        if input.UserInputType == Enum.UserInputType.Keyboard and KeyPickerData.Value ~= 'None' then
            matches = input.KeyCode.Name == KeyPickerData.Value
        end
        if matches then
            KeyPickerData.Toggled = false
            Library:SafeCallback(KeyPickerData.Callback, false)
        end
    end))

    KeyPickerData:Update()
    if parentElement.Addons then table.insert(parentElement.Addons, KeyPickerData) end
    Options[index] = KeyPickerData
    return self
end

local GroupboxFuncs = {}

function GroupboxFuncs:AddBlank(blankSize)
    local blankFrame = Library:Create('Frame', {
        BackgroundTransparency = 1;
        Size = UDim2.new(1, 0, 0, blankSize or 6);
        Parent = self.Container;
    })
    return blankFrame
end

function GroupboxFuncs:AddLabel(text, doesWrap)
    local Label = { Type = 'Label'; Addons = {} }
    local labelHolder = Library:Create('Frame', {
        BackgroundTransparency = 1;
        Size = UDim2.new(1, 0, 0, doesWrap and 0 or 16);
        AutomaticSize = doesWrap and Enum.AutomaticSize.Y or Enum.AutomaticSize.None;
        Parent = self.Container;
    })
    local labelText = Library:CreateLabel({
        Size = UDim2.new(1, -6, doesWrap and 0 or 1, 0);
        AutomaticSize = doesWrap and Enum.AutomaticSize.Y or Enum.AutomaticSize.None;
        Text = text;
        TextWrapped = doesWrap or false;
        TextXAlignment = Enum.TextXAlignment.Left;
        Parent = labelHolder;
    })
    local addonHolder = Library:Create('Frame', {
        AnchorPoint = Vector2.new(1, 0.5);
        BackgroundTransparency = 1;
        Position = UDim2.new(1, -4, 0.5, 0);
        Size = UDim2.fromOffset(120, 16);
        Parent = labelHolder;
    })
    Library:Create('UIListLayout', {
        Padding = UDim.new(0, 4);
        FillDirection = Enum.FillDirection.Horizontal;
        HorizontalAlignment = Enum.HorizontalAlignment.Right;
        VerticalAlignment = Enum.VerticalAlignment.Center;
        Parent = addonHolder;
    })
    Label.AddonHolder = addonHolder
    Label.TextLabel = labelText
    function Label:SetText(newText) labelText.Text = newText end
    setmetatable(Label, BaseAddons)
    self:AddBlank(4)
    return Label
end

function GroupboxFuncs:AddNote(text)
    local Note = { Type = 'Note' }
    local noteFrame = Library:Create('Frame', {
        BackgroundColor3 = Library.SurfaceColor;
        BackgroundTransparency = 0.5;
        BorderSizePixel = 0;
        Size = UDim2.new(1, -4, 0, 0);
        AutomaticSize = Enum.AutomaticSize.Y;
        Parent = self.Container;
    })
    Round(noteFrame, 6)
    local noteLabel = Library:CreateLabel({
        Size = UDim2.new(1, -16, 0, 0);
        Position = UDim2.fromOffset(8, 0);
        AutomaticSize = Enum.AutomaticSize.Y;
        Text = text;
        TextColor3 = Library.DimFontColor;
        TextSize = 12;
        TextWrapped = true;
        TextXAlignment = Enum.TextXAlignment.Left;
        Parent = noteFrame;
    })
    Library:Create('UIPadding', { PaddingTop = UDim.new(0, 6); PaddingBottom = UDim.new(0, 6); Parent = noteFrame })
    function Note:SetText(newText) noteLabel.Text = newText end
    self:AddBlank(4)
    return Note
end

function GroupboxFuncs:AddDivider()
    local dividerFrame = Library:Create('Frame', {
        BackgroundColor3 = Library.OutlineColor;
        BorderSizePixel = 0;
        Size = UDim2.new(1, -12, 0, 1);
        Parent = self.Container;
    })
    Library:AddToRegistry(dividerFrame, { BackgroundColor3 = 'OutlineColor' })
    self:AddBlank(6)
    return dividerFrame
end

local function StyleButton(buttonInstance)
    Round(buttonInstance, 7)
    local buttonStroke = Stroke(buttonInstance, Library.OutlineColor)
    buttonInstance.MouseEnter:Connect(function()
        Animate(buttonInstance, { BackgroundColor3 = Library.SurfaceColor }, TweenFast)
        Animate(buttonStroke, { Color = Library.AccentColor }, TweenFast)
    end)
    buttonInstance.MouseLeave:Connect(function()
        Animate(buttonInstance, { BackgroundColor3 = Library.MainColor }, TweenFast)
        Animate(buttonStroke, { Color = Library.OutlineColor }, TweenFast)
    end)
    buttonInstance.MouseButton1Down:Connect(function()
        Animate(buttonInstance, { BackgroundColor3 = Library.AccentColorDark }, TweenFast)
    end)
    buttonInstance.MouseButton1Up:Connect(function()
        Animate(buttonInstance, { BackgroundColor3 = Library.SurfaceColor }, TweenFast)
    end)
end

function GroupboxFuncs:AddButton(...)
    local buttonArgs = { ... }
    local buttonInfo
    if type(buttonArgs[1]) == 'table' then
        buttonInfo = buttonArgs[1]
    else
        buttonInfo = { Text = buttonArgs[1]; Func = buttonArgs[2] }
    end
    local Button = { Type = 'Button' }
    local groupbox = self

    local buttonRow = Library:Create('Frame', {
        BackgroundTransparency = 1;
        Size = UDim2.new(1, -4, 0, 26);
        Parent = groupbox.Container;
    })
    Library:Create('UIListLayout', {
        Padding = UDim.new(0, 6);
        FillDirection = Enum.FillDirection.Horizontal;
        SortOrder = Enum.SortOrder.LayoutOrder;
        Parent = buttonRow;
    })

    local buttonCount = 0
    local function CreateButtonInstance(info)
        buttonCount = buttonCount + 1
        local buttonInstance = Library:Create('TextButton', {
            BackgroundColor3 = Library.MainColor;
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 1, 0);
            Font = Library.Font;
            Text = info.Text or 'Button';
            TextColor3 = Library.FontColor;
            TextSize = 13;
            AutoButtonColor = false;
            Parent = buttonRow;
        })
        StyleButton(buttonInstance)
        buttonInstance.MouseButton1Click:Connect(function()
            if info.DoubleClick then
                buttonInstance.Text = 'Confirm?'
                Animate(buttonInstance, { TextColor3 = Library.AccentColor }, TweenFast)
                local confirmConnection
                local timedOut = false
                confirmConnection = buttonInstance.MouseButton1Click:Connect(function()
                    if timedOut then return end
                    confirmConnection:Disconnect()
                    buttonInstance.Text = info.Text
                    Animate(buttonInstance, { TextColor3 = Library.FontColor }, TweenFast)
                    Library:SafeCallback(info.Func)
                end)
                task.delay(2, function()
                    timedOut = true
                    pcall(function() confirmConnection:Disconnect() end)
                    buttonInstance.Text = info.Text
                    Animate(buttonInstance, { TextColor3 = Library.FontColor }, TweenFast)
                end)
            else
                Library:SafeCallback(info.Func)
            end
        end)
        for _, child in ipairs(buttonRow:GetChildren()) do
            if child:IsA('TextButton') then
                child.Size = UDim2.new(1 / buttonCount, buttonCount > 1 and -4 or 0, 1, 0)
            end
        end
        return buttonInstance
    end

    Button.Outer = CreateButtonInstance(buttonInfo)
    if type(buttonInfo.Tooltip) == 'string' then Library:AddToolTip(buttonInfo.Tooltip, Button.Outer) end

    function Button:AddTooltip(tooltipText)
        if type(tooltipText) == 'string' then Library:AddToolTip(tooltipText, Button.Outer) end
        return Button
    end
    function Button:AddButton(...)
        local subArgs = { ... }
        local subInfo = type(subArgs[1]) == 'table' and subArgs[1] or { Text = subArgs[1]; Func = subArgs[2] }
        local SubButton = { Type = 'Button' }
        SubButton.Outer = CreateButtonInstance(subInfo)
        if type(subInfo.Tooltip) == 'string' then Library:AddToolTip(subInfo.Tooltip, SubButton.Outer) end
        function SubButton:AddTooltip(tooltipText)
            if type(tooltipText) == 'string' then Library:AddToolTip(tooltipText, SubButton.Outer) end
            return SubButton
        end
        return SubButton
    end

    self:AddBlank(6)
    return Button
end

function GroupboxFuncs:AddInput(index, info)
    local Textbox = {
        Value = info.Default or '';
        Type = 'Input';
        Callback = info.Callback or function() end;
    }
    local groupbox = self

    if info.Text then
        local inputTitle = Library:CreateLabel({
            Size = UDim2.new(1, 0, 0, 14);
            Text = info.Text;
            TextXAlignment = Enum.TextXAlignment.Left;
            Parent = groupbox.Container;
        })
        Textbox.TitleLabel = inputTitle
        self:AddBlank(3)
    end

    local inputFrame = Library:Create('Frame', {
        BackgroundColor3 = Library.BackgroundColor;
        BorderSizePixel = 0;
        Size = UDim2.new(1, -4, 0, 26);
        Parent = groupbox.Container;
    })
    Round(inputFrame, 7)
    local inputStroke = Stroke(inputFrame, Library.OutlineColor)
    local inputBox = Library:Create('TextBox', {
        BackgroundTransparency = 1;
        Size = UDim2.new(1, -16, 1, 0);
        Position = UDim2.fromOffset(8, 0);
        Font = Library.Font;
        PlaceholderText = info.Placeholder or '';
        PlaceholderColor3 = Library.DimFontColor;
        Text = Textbox.Value;
        TextColor3 = Library.FontColor;
        TextSize = 13;
        TextXAlignment = Enum.TextXAlignment.Left;
        ClearTextOnFocus = false;
        Parent = inputFrame;
    })

    inputBox.Focused:Connect(function()
        Animate(inputStroke, { Color = Library.AccentColor }, TweenFast)
    end)
    inputBox.FocusLost:Connect(function()
        Animate(inputStroke, { Color = Library.OutlineColor }, TweenFast)
        if info.Finished then
            Textbox.Value = inputBox.Text
            Library:SafeCallback(Textbox.Callback, Textbox.Value)
            Library:SafeCallback(Textbox.Changed, Textbox.Value)
            Library:AttemptSave()
        end
    end)
    if not info.Finished then
        inputBox:GetPropertyChangedSignal('Text'):Connect(function()
            if info.MaxLength and #inputBox.Text > info.MaxLength then
                inputBox.Text = inputBox.Text:sub(1, info.MaxLength)
            end
            if info.Numeric then
                inputBox.Text = inputBox.Text:gsub('[^%d%.%-]', '')
            end
            Textbox.Value = inputBox.Text
            Library:SafeCallback(Textbox.Callback, Textbox.Value)
            Library:SafeCallback(Textbox.Changed, Textbox.Value)
        end)
    end

    function Textbox:SetValue(newValue)
        newValue = tostring(newValue)
        if info.MaxLength and #newValue > info.MaxLength then newValue = newValue:sub(1, info.MaxLength) end
        Textbox.Value = newValue
        inputBox.Text = newValue
        Library:SafeCallback(Textbox.Callback, newValue)
        Library:SafeCallback(Textbox.Changed, newValue)
    end
    function Textbox:OnChanged(callback)
        Textbox.Changed = callback
        callback(Textbox.Value)
    end

    if type(info.Tooltip) == 'string' then Library:AddToolTip(info.Tooltip, inputFrame) end
    self:AddBlank(6)
    Options[index] = Textbox
    return Textbox
end

function GroupboxFuncs:AddToggle(index, info)
    assert(info.Text, 'AddToggle: Missing `Text`.')
    local Toggle = {
        Value = info.Default or false;
        Type = 'Toggle';
        Callback = info.Callback or function() end;
        Addons = {};
        Risky = info.Risky;
    }
    local groupbox = self

    local toggleRow = Library:Create('Frame', {
        BackgroundTransparency = 1;
        Size = UDim2.new(1, -4, 0, 20);
        Parent = groupbox.Container;
    })
    local switchTrack = Library:Create('Frame', {
        AnchorPoint = Vector2.new(0, 0.5);
        BackgroundColor3 = Library.SurfaceColor;
        BorderSizePixel = 0;
        Position = UDim2.new(0, 0, 0.5, 0);
        Size = UDim2.fromOffset(32, 16);
        Parent = toggleRow;
    })
    Round(switchTrack, 8)
    local trackStroke = Stroke(switchTrack, Library.OutlineColor)
    local switchKnob = Library:Create('Frame', {
        AnchorPoint = Vector2.new(0, 0.5);
        BackgroundColor3 = Library.DimFontColor;
        BorderSizePixel = 0;
        Position = UDim2.new(0, 3, 0.5, 0);
        Size = UDim2.fromOffset(10, 10);
        Parent = switchTrack;
    })
    Round(switchKnob, 5)
    local toggleLabel = Library:CreateLabel({
        Size = UDim2.new(1, -160, 1, 0);
        Position = UDim2.fromOffset(40, 0);
        Text = info.Text;
        TextColor3 = Toggle.Risky and Library.RiskColor or Library.FontColor;
        TextXAlignment = Enum.TextXAlignment.Left;
        Parent = toggleRow;
    })
    local addonHolder = Library:Create('Frame', {
        AnchorPoint = Vector2.new(1, 0.5);
        BackgroundTransparency = 1;
        Position = UDim2.new(1, -2, 0.5, 0);
        Size = UDim2.fromOffset(110, 16);
        Parent = toggleRow;
    })
    Library:Create('UIListLayout', {
        Padding = UDim.new(0, 4);
        FillDirection = Enum.FillDirection.Horizontal;
        HorizontalAlignment = Enum.HorizontalAlignment.Right;
        VerticalAlignment = Enum.VerticalAlignment.Center;
        Parent = addonHolder;
    })
    Toggle.AddonHolder = addonHolder
    Toggle.TextLabel = toggleLabel
    Toggle.Container = groupbox.Container

    function Toggle:Display()
        if Toggle.Value then
            Animate(switchTrack, { BackgroundColor3 = Library.AccentColor }, TweenSmooth)
            Animate(trackStroke, { Color = Library.AccentColorDark }, TweenSmooth)
            Animate(switchKnob, { Position = UDim2.new(1, -13, 0.5, 0); BackgroundColor3 = Color3.new(1, 1, 1) }, TweenBounce)
        else
            Animate(switchTrack, { BackgroundColor3 = Library.SurfaceColor }, TweenSmooth)
            Animate(trackStroke, { Color = Library.OutlineColor }, TweenSmooth)
            Animate(switchKnob, { Position = UDim2.new(0, 3, 0.5, 0); BackgroundColor3 = Library.DimFontColor }, TweenBounce)
        end
    end
    function Toggle:UpdateColors() Toggle:Display() end
    function Toggle:OnChanged(callback)
        Toggle.Changed = callback
        callback(Toggle.Value)
    end
    function Toggle:SetValue(newValue)
        newValue = not not newValue
        Toggle.Value = newValue
        Toggle:Display()
        for _, addon in ipairs(Toggle.Addons) do
            if addon.Type == 'KeyPicker' and addon.SyncToggleState then
                addon.Toggled = newValue
                addon:Update()
            end
        end
        Library:SafeCallback(Toggle.Callback, newValue)
        Library:SafeCallback(Toggle.Changed, newValue)
        Library:UpdateDependencyBoxes()
    end

    local hitRegion = Library:Create('TextButton', {
        BackgroundTransparency = 1;
        Size = UDim2.new(1, -115, 1, 0);
        Text = '';
        Parent = toggleRow;
    })
    hitRegion.MouseButton1Click:Connect(function()
        if Library:HasOpenedFrames() then return end
        Toggle:SetValue(not Toggle.Value)
        Library:AttemptSave()
    end)

    if type(info.Tooltip) == 'string' then Library:AddToolTip(info.Tooltip, hitRegion) end

    Toggle:Display()
    setmetatable(Toggle, BaseAddons)
    self:AddBlank(6)
    Toggles[index] = Toggle
    Library:UpdateDependencyBoxes()
    return Toggle
end

function GroupboxFuncs:AddSlider(index, info)
    assert(info.Default ~= nil, 'AddSlider: Missing default.')
    assert(info.Text,           'AddSlider: Missing text.')
    assert(info.Min ~= nil,     'AddSlider: Missing min.')
    assert(info.Max ~= nil,     'AddSlider: Missing max.')
    assert(info.Rounding ~= nil,'AddSlider: Missing rounding.')

    local Slider = {
        Value = info.Default;
        Min = info.Min;
        Max = info.Max;
        Rounding = info.Rounding;
        Type = 'Slider';
        Callback = info.Callback or function() end;
        Info = info;
    }
    local groupbox = self

    local sliderHolder = Library:Create('Frame', {
        BackgroundTransparency = 1;
        Size = UDim2.new(1, -4, 0, 34);
        Parent = groupbox.Container;
    })
    local sliderTitle = Library:CreateLabel({
        Size = UDim2.new(0.6, 0, 0, 14);
        Text = info.Text;
        TextXAlignment = Enum.TextXAlignment.Left;
        Parent = sliderHolder;
    })
    local sliderValueLabel = Library:CreateLabel({
        AnchorPoint = Vector2.new(1, 0);
        Size = UDim2.new(0.4, 0, 0, 14);
        Position = UDim2.new(1, 0, 0, 0);
        TextColor3 = Library.DimFontColor;
        TextXAlignment = Enum.TextXAlignment.Right;
        Parent = sliderHolder;
    })
    local sliderTrack = Library:Create('Frame', {
        BackgroundColor3 = Library.BackgroundColor;
        BorderSizePixel = 0;
        Position = UDim2.new(0, 0, 0, 22);
        Size = UDim2.new(1, 0, 0, 8);
        Parent = sliderHolder;
    })
    Round(sliderTrack, 4)
    Stroke(sliderTrack, Library.OutlineColor, 0.5)
    local sliderFill = Library:Create('Frame', {
        BackgroundColor3 = Library.AccentColor;
        BorderSizePixel = 0;
        Size = UDim2.new(0, 0, 1, 0);
        Parent = sliderTrack;
    })
    Round(sliderFill, 4)
    Library:AddToRegistry(sliderFill, { BackgroundColor3 = 'AccentColor' })
    local sliderKnob = Library:Create('Frame', {
        AnchorPoint = Vector2.new(0.5, 0.5);
        BackgroundColor3 = Color3.new(1, 1, 1);
        BorderSizePixel = 0;
        Position = UDim2.new(0, 0, 0.5, 0);
        Size = UDim2.fromOffset(12, 12);
        ZIndex = 6;
        Parent = sliderTrack;
    })
    Round(sliderKnob, 6)

    local function RoundValue(value)
        if Slider.Rounding == 0 then return math.floor(value + 0.5) end
        return tonumber(string.format('%.' .. Slider.Rounding .. 'f', value))
    end

    function Slider:Display()
        local suffix = Slider.Info.Suffix or ''
        sliderValueLabel.Text = tostring(Slider.Value) .. suffix
        local alpha = 0
        if Slider.Max ~= Slider.Min then
            alpha = math.clamp((Slider.Value - Slider.Min) / (Slider.Max - Slider.Min), 0, 1)
        end
        Animate(sliderFill, { Size = UDim2.new(alpha, 0, 1, 0) }, TweenSmooth)
        Animate(sliderKnob, { Position = UDim2.new(alpha, 0, 0.5, 0) }, TweenSmooth)
    end
    function Slider:UpdateColors()
        sliderFill.BackgroundColor3 = Library.AccentColor
    end
    function Slider:OnChanged(callback)
        Slider.Changed = callback
        callback(Slider.Value)
    end
    function Slider:SetValue(newValue)
        newValue = math.clamp(tonumber(newValue) or Slider.Min, Slider.Min, Slider.Max)
        Slider.Value = RoundValue(newValue)
        Slider:Display()
        Library:SafeCallback(Slider.Callback, Slider.Value)
        Library:SafeCallback(Slider.Changed, Slider.Value)
    end

    local draggingSlider = false
    local function ApplyFromMouse()
        local mouseLocation = UserInputService:GetMouseLocation()
        local alpha = math.clamp((mouseLocation.X - sliderTrack.AbsolutePosition.X) / sliderTrack.AbsoluteSize.X, 0, 1)
        local newValue = RoundValue(Library:MapValue(alpha, 0, 1, Slider.Min, Slider.Max))
        if newValue ~= Slider.Value then
            Slider.Value = newValue
            Slider:Display()
            Library:SafeCallback(Slider.Callback, newValue)
            Library:SafeCallback(Slider.Changed, newValue)
        end
    end
    sliderTrack.InputBegan:Connect(function(input)
        if Library:IsPointerInput(input) and not Library:HasOpenedFrames() then
            draggingSlider = true
            Animate(sliderKnob, { Size = UDim2.fromOffset(16, 16) }, TweenFast)
            ApplyFromMouse()
        end
    end)
    Library:GiveSignal(UserInputService.InputChanged:Connect(function(input)
        if draggingSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            ApplyFromMouse()
        end
    end))
    Library:GiveSignal(UserInputService.InputEnded:Connect(function(input)
        if draggingSlider and Library:IsPointerInput(input) then
            draggingSlider = false
            Animate(sliderKnob, { Size = UDim2.fromOffset(12, 12) }, TweenFast)
            Library:AttemptSave()
        end
    end))

    if type(info.Tooltip) == 'string' then Library:AddToolTip(info.Tooltip, sliderHolder) end

    Slider:Display()
    self:AddBlank(6)
    Options[index] = Slider
    return Slider
end

local function GetPlayersString()
    local playerNames = {}
    for _, player in ipairs(Players:GetPlayers()) do
        table.insert(playerNames, player.Name)
    end
    table.sort(playerNames)
    return playerNames
end

local function GetTeamsString()
    local teamNames = {}
    for _, team in ipairs(Services.Teams:GetTeams()) do
        table.insert(teamNames, team.Name)
    end
    return teamNames
end

function GroupboxFuncs:AddDropdown(index, info)
    if info.SpecialType == 'Player' then info.Values = GetPlayersString(); info.AllowNull = true
    elseif info.SpecialType == 'Team' then info.Values = GetTeamsString(); info.AllowNull = true end
    assert(info.Values, 'AddDropdown: Missing Values.')
    assert(info.AllowNull or info.Default ~= nil, 'AddDropdown: Missing default or AllowNull.')

    local Dropdown = {
        Values = info.Values;
        Value = info.Multi and {};
        Multi = info.Multi;
        Type = 'Dropdown';
        SpecialType = info.SpecialType;
        Callback = info.Callback or function() end;
    }
    local groupbox = self

    if info.Text then
        local dropdownTitle = Library:CreateLabel({
            Size = UDim2.new(1, 0, 0, 14);
            Text = info.Text;
            TextXAlignment = Enum.TextXAlignment.Left;
            Parent = groupbox.Container;
        })
        Dropdown.TitleLabel = dropdownTitle
        self:AddBlank(3)
    end

    local dropdownFrame = Library:Create('TextButton', {
        BackgroundColor3 = Library.BackgroundColor;
        BorderSizePixel = 0;
        Size = UDim2.new(1, -4, 0, 26);
        Text = '';
        AutoButtonColor = false;
        Parent = groupbox.Container;
    })
    Round(dropdownFrame, 7)
    local dropdownStroke = Stroke(dropdownFrame, Library.OutlineColor)
    local selectedLabel = Library:CreateLabel({
        Size = UDim2.new(1, -40, 1, 0);
        Position = UDim2.fromOffset(8, 0);
        TextXAlignment = Enum.TextXAlignment.Left;
        TextTruncate = Enum.TextTruncate.AtEnd;
        Parent = dropdownFrame;
    })
    local arrowLabel = Library:CreateLabel({
        AnchorPoint = Vector2.new(1, 0.5);
        Size = UDim2.fromOffset(16, 16);
        Position = UDim2.new(1, -8, 0.5, 0);
        Text = 'v';
        Font = Library.FontBold;
        TextColor3 = Library.DimFontColor;
        Parent = dropdownFrame;
    })

    local maximumVisibleItems = 8
    local itemHeight = 26
    local listFrame = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderSizePixel = 0;
        Size = UDim2.fromOffset(200, 0);
        ClipsDescendants = true;
        Visible = false;
        ZIndex = 250;
        Parent = ScreenGui;
    })
    Round(listFrame, 8)
    Stroke(listFrame, Library.OutlineColor)
    Library.OpenedFrames[listFrame] = listFrame
    local listScroll = Library:Create('ScrollingFrame', {
        BackgroundTransparency = 1;
        BorderSizePixel = 0;
        Size = UDim2.new(1, 0, 1, 0);
        CanvasSize = UDim2.new(0, 0, 0, 0);
        ScrollBarThickness = 3;
        ScrollBarImageColor3 = Library.AccentColor;
        ScrollingDirection = Enum.ScrollingDirection.Y;
        ElasticBehavior = Enum.ElasticBehavior.Never;
        ZIndex = 251;
        Parent = listFrame;
    })
    Library:Create('UIListLayout', {
        Padding = UDim.new(0, 2);
        SortOrder = Enum.SortOrder.LayoutOrder;
        Parent = listScroll;
    })
    Library:Create('UIPadding', {
        PaddingTop = UDim.new(0, 4);
        PaddingBottom = UDim.new(0, 4);
        PaddingLeft = UDim.new(0, 4);
        PaddingRight = UDim.new(0, 4);
        Parent = listScroll;
    })

    local dropdownOpen = false

    local function UpdateListPosition()
        local absolutePosition = dropdownFrame.AbsolutePosition
        local absoluteSize = dropdownFrame.AbsoluteSize
        listFrame.Position = UDim2.fromOffset(absolutePosition.X, absolutePosition.Y + absoluteSize.Y + 4)
        listFrame.Size = UDim2.fromOffset(absoluteSize.X, listFrame.Size.Y.Offset)
    end
    dropdownFrame:GetPropertyChangedSignal('AbsolutePosition'):Connect(UpdateListPosition)

    function Dropdown:Display()
        local displayText = ''
        if Dropdown.Multi then
            local selectedParts = {}
            for _, value in ipairs(Dropdown.Values) do
                if Dropdown.Value[value] then table.insert(selectedParts, tostring(value)) end
            end
            displayText = table.concat(selectedParts, ', ')
        else
            displayText = Dropdown.Value and tostring(Dropdown.Value) or ''
        end
        selectedLabel.Text = displayText == '' and '--' or displayText
        selectedLabel.TextColor3 = displayText == '' and Library.DimFontColor or Library.FontColor
    end

    local function CloseList()
        dropdownOpen = false
        Animate(arrowLabel, { Rotation = 0; TextColor3 = Library.DimFontColor }, TweenSmooth)
        Animate(dropdownStroke, { Color = Library.OutlineColor }, TweenFast)
        local closeTween = Animate(listFrame, { Size = UDim2.fromOffset(dropdownFrame.AbsoluteSize.X, 0) }, TweenFast)
        closeTween.Completed:Connect(function()
            if not dropdownOpen then listFrame.Visible = false end
        end)
    end

    local function BuildList()
        for _, child in ipairs(listScroll:GetChildren()) do
            if child:IsA('TextButton') then child:Destroy() end
        end
        for itemIndex, value in ipairs(Dropdown.Values) do
            local isSelected = Dropdown.Multi and Dropdown.Value[value] or Dropdown.Value == value
            local itemButton = Library:Create('TextButton', {
                BackgroundColor3 = Library.AccentColor;
                BackgroundTransparency = isSelected and 0.85 or 1;
                BorderSizePixel = 0;
                Size = UDim2.new(1, 0, 0, itemHeight - 2);
                Font = Library.Font;
                Text = tostring(value);
                TextColor3 = isSelected and Library.AccentColor or Library.FontColor;
                TextSize = 13;
                TextXAlignment = Enum.TextXAlignment.Left;
                AutoButtonColor = false;
                LayoutOrder = itemIndex;
                ZIndex = 252;
                Parent = listScroll;
            })
            Round(itemButton, 6)
            Library:Create('UIPadding', { PaddingLeft = UDim.new(0, 8); Parent = itemButton })
            itemButton.MouseEnter:Connect(function()
                if not (Dropdown.Multi and Dropdown.Value[value] or Dropdown.Value == value) then
                    Animate(itemButton, { BackgroundTransparency = 0.92 }, TweenFast)
                end
            end)
            itemButton.MouseLeave:Connect(function()
                if not (Dropdown.Multi and Dropdown.Value[value] or Dropdown.Value == value) then
                    Animate(itemButton, { BackgroundTransparency = 1 }, TweenFast)
                end
            end)
            itemButton.MouseButton1Click:Connect(function()
                if Dropdown.Multi then
                    Dropdown.Value[value] = not Dropdown.Value[value] or nil
                    BuildList()
                else
                    Dropdown.Value = value
                    CloseList()
                end
                Dropdown:Display()
                Library:SafeCallback(Dropdown.Callback, Dropdown.Value)
                Library:SafeCallback(Dropdown.Changed, Dropdown.Value)
                Library:AttemptSave()
            end)
        end
        listScroll.CanvasSize = UDim2.fromOffset(0, #Dropdown.Values * itemHeight + 8)
    end

    local function OpenList()
        dropdownOpen = true
        BuildList()
        UpdateListPosition()
        listFrame.Visible = true
        local targetHeight = math.min(#Dropdown.Values, maximumVisibleItems) * itemHeight + 8
        listFrame.Size = UDim2.fromOffset(dropdownFrame.AbsoluteSize.X, 0)
        Animate(listFrame, { Size = UDim2.fromOffset(dropdownFrame.AbsoluteSize.X, targetHeight) }, TweenSmooth)
        Animate(arrowLabel, { Rotation = 180; TextColor3 = Library.AccentColor }, TweenSmooth)
        Animate(dropdownStroke, { Color = Library.AccentColor }, TweenFast)
    end

    dropdownFrame.MouseButton1Click:Connect(function()
        if dropdownOpen then CloseList() else OpenList() end
    end)

    Library:GiveSignal(UserInputService.InputBegan:Connect(function(input)
        if dropdownOpen and Library:IsPointerInput(input) then
            local mouseLocation = UserInputService:GetMouseLocation()
            local insideList = mouseLocation.X >= listFrame.AbsolutePosition.X and mouseLocation.X <= listFrame.AbsolutePosition.X + listFrame.AbsoluteSize.X
                and mouseLocation.Y >= listFrame.AbsolutePosition.Y and mouseLocation.Y <= listFrame.AbsolutePosition.Y + listFrame.AbsoluteSize.Y
            local insideFrame = mouseLocation.X >= dropdownFrame.AbsolutePosition.X and mouseLocation.X <= dropdownFrame.AbsolutePosition.X + dropdownFrame.AbsoluteSize.X
                and mouseLocation.Y >= dropdownFrame.AbsolutePosition.Y and mouseLocation.Y <= dropdownFrame.AbsolutePosition.Y + dropdownFrame.AbsoluteSize.Y
            if not insideList and not insideFrame then CloseList() end
        end
    end))

    function Dropdown:SetValues(newValues)
        if newValues then Dropdown.Values = newValues end
        if Dropdown.Multi then
            for value in pairs(Dropdown.Value) do
                if not table.find(Dropdown.Values, value) then Dropdown.Value[value] = nil end
            end
        elseif Dropdown.Value and not table.find(Dropdown.Values, Dropdown.Value) then
            Dropdown.Value = nil
        end
        if dropdownOpen then BuildList() end
        Dropdown:Display()
    end
    function Dropdown:SetValue(newValue)
        if Dropdown.Multi then
            Dropdown.Value = {}
            if type(newValue) == 'table' then
                for value, state in pairs(newValue) do
                    if state and table.find(Dropdown.Values, value) then Dropdown.Value[value] = true end
                end
            end
        else
            if newValue == nil then
                Dropdown.Value = nil
            elseif table.find(Dropdown.Values, newValue) then
                Dropdown.Value = newValue
            end
        end
        Dropdown:Display()
        Library:SafeCallback(Dropdown.Callback, Dropdown.Value)
        Library:SafeCallback(Dropdown.Changed, Dropdown.Value)
    end
    function Dropdown:OnChanged(callback)
        Dropdown.Changed = callback
        callback(Dropdown.Value)
    end
    function Dropdown:GetActiveValues()
        if Dropdown.Multi then
            local activeValues = {}
            for value in pairs(Dropdown.Value) do table.insert(activeValues, value) end
            return activeValues
        end
        return Dropdown.Value and { Dropdown.Value } or {}
    end

    if info.SpecialType == 'Player' then
        Library:GiveSignal(Players.PlayerAdded:Connect(function() Dropdown:SetValues(GetPlayersString()) end))
        Library:GiveSignal(Players.PlayerRemoving:Connect(function() task.defer(function() Dropdown:SetValues(GetPlayersString()) end) end))
    end

    if info.Default then
        if Dropdown.Multi and type(info.Default) == 'table' then
            for _, value in ipairs(info.Default) do Dropdown.Value[value] = true end
        elseif type(info.Default) == 'number' and Dropdown.Values[info.Default] then
            Dropdown.Value = Dropdown.Values[info.Default]
        elseif not Dropdown.Multi and table.find(Dropdown.Values, info.Default) then
            Dropdown.Value = info.Default
        end
    end

    if type(info.Tooltip) == 'string' then Library:AddToolTip(info.Tooltip, dropdownFrame) end

    Dropdown:Display()
    self:AddBlank(6)
    Options[index] = Dropdown
    return Dropdown
end

function GroupboxFuncs:AddDependencyBox()
    local groupbox = self
    local DependencyBox = {
        Dependencies = {};
        Type = 'DependencyBox';
    }
    local dependencyContainer = Library:Create('Frame', {
        BackgroundTransparency = 1;
        Size = UDim2.new(1, 0, 0, 0);
        AutomaticSize = Enum.AutomaticSize.Y;
        Visible = false;
        Parent = groupbox.Container;
    })
    Library:Create('UIListLayout', {
        SortOrder = Enum.SortOrder.LayoutOrder;
        Parent = dependencyContainer;
    })
    DependencyBox.Container = dependencyContainer
    for functionName, functionValue in pairs(GroupboxFuncs) do
        DependencyBox[functionName] = functionValue
    end

    function DependencyBox:SetupDependencies(dependencies)
        DependencyBox.Dependencies = dependencies
        DependencyBox:Update()
    end
    function DependencyBox:Update()
        local allSatisfied = true
        for _, dependency in ipairs(DependencyBox.Dependencies) do
            local element, requiredState = dependency[1], dependency[2]
            if element and element.Value ~= requiredState then
                allSatisfied = false
                break
            end
        end
        dependencyContainer.Visible = allSatisfied
    end

    table.insert(Library.DependencyBoxes, DependencyBox)
    return DependencyBox
end

function GroupboxFuncs:Resize() end

local function BuildGroupbox(parentColumn, groupboxName)
    local Groupbox = { Name = groupboxName }

    local groupboxFrame = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderSizePixel = 0;
        Size = UDim2.new(1, 0, 0, 0);
        AutomaticSize = Enum.AutomaticSize.Y;
        Parent = parentColumn;
    })
    Round(groupboxFrame, 10)
    Stroke(groupboxFrame, Library.OutlineColor)
    Library:AddToRegistry(groupboxFrame, { BackgroundColor3 = 'MainColor' })

    if groupboxName then
        local groupboxTitle = Library:CreateLabel({
            Size = UDim2.new(1, -24, 0, 30);
            Position = UDim2.fromOffset(12, 0);
            Font = Library.FontBold;
            Text = groupboxName;
            TextSize = 13;
            TextXAlignment = Enum.TextXAlignment.Left;
            Parent = groupboxFrame;
        })
        local titleAccent = Library:Create('Frame', {
            BackgroundColor3 = Library.AccentColor;
            BorderSizePixel = 0;
            Position = UDim2.fromOffset(12, 26);
            Size = UDim2.fromOffset(18, 2);
            Parent = groupboxFrame;
        })
        Round(titleAccent, 1)
        Library:AddToRegistry(titleAccent, { BackgroundColor3 = 'AccentColor' })
    end

    local containerFrame = Library:Create('Frame', {
        BackgroundTransparency = 1;
        Position = UDim2.fromOffset(12, groupboxName and 34 or 10);
        Size = UDim2.new(1, -24, 0, 0);
        AutomaticSize = Enum.AutomaticSize.Y;
        Parent = groupboxFrame;
    })
    Library:Create('UIListLayout', {
        SortOrder = Enum.SortOrder.LayoutOrder;
        Parent = containerFrame;
    })
    Library:Create('UIPadding', {
        PaddingBottom = UDim.new(0, 12);
        Parent = containerFrame;
    })

    Groupbox.Frame = groupboxFrame
    Groupbox.Container = containerFrame
    for functionName, functionValue in pairs(GroupboxFuncs) do
        Groupbox[functionName] = functionValue
    end
    return Groupbox
end

function Library:CreateWindow(...)
    local windowArgs = { ... }
    local Config = type(windowArgs[1]) == 'table' and windowArgs[1] or { Title = windowArgs[1]; AutoShow = windowArgs[2] }
    if type(Config.Title) ~= 'string' then Config.Title = 'Window' end

    local windowWidth, windowHeight = 620, 480
    if typeof(Config.Size) == 'UDim2' then
        windowWidth = Config.Size.X.Offset
        windowHeight = Config.Size.Y.Offset
    end
    if IsTouch then
        local viewportSize = workspace.CurrentCamera.ViewportSize
        windowWidth = math.clamp(math.floor(viewportSize.X - 20), 280, windowWidth)
        windowHeight = math.clamp(math.floor(viewportSize.Y - 20), 240, windowHeight)
    end

    local Window = { Tabs = {} }
    Library.MainWindow = Window

    local WindowFrame = Library:Create('Frame', {
        AnchorPoint = Vector2.new(0.5, 0.5);
        BackgroundColor3 = Library.BackgroundColor;
        BorderSizePixel = 0;
        Position = UDim2.fromScale(0.5, 0.5);
        Size = UDim2.fromOffset(windowWidth, windowHeight);
        ClipsDescendants = true;
        Visible = false;
        Parent = ScreenGui;
    })
    Round(WindowFrame, 12)
    Stroke(WindowFrame, Library.OutlineColor)
    Library:AddToRegistry(WindowFrame, { BackgroundColor3 = 'BackgroundColor' })
    local WindowScale = Library:Create('UIScale', { Scale = 1; Parent = WindowFrame })

    local sidebarWidth = 150
    local Sidebar = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderSizePixel = 0;
        Size = UDim2.new(0, sidebarWidth, 1, 0);
        Parent = WindowFrame;
    })
    Library:AddToRegistry(Sidebar, { BackgroundColor3 = 'MainColor' })
    Library:Create('Frame', {
        BackgroundColor3 = Library.OutlineColor;
        BorderSizePixel = 0;
        Position = UDim2.new(1, 0, 0, 0);
        Size = UDim2.new(0, 1, 1, 0);
        Parent = Sidebar;
    })

    local TitleLabel = Library:CreateLabel({
        Size = UDim2.new(1, -32, 0, 52);
        Position = UDim2.fromOffset(16, 0);
        Font = Library.FontBold;
        Text = Config.Title;
        TextSize = 16;
        TextXAlignment = Enum.TextXAlignment.Left;
        Parent = Sidebar;
    })
    local TitleUnderline = Library:Create('Frame', {
        BackgroundColor3 = Library.AccentColor;
        BorderSizePixel = 0;
        Position = UDim2.fromOffset(16, 46);
        Size = UDim2.fromOffset(26, 2);
        Parent = Sidebar;
    })
    Round(TitleUnderline, 1)
    Library:AddToRegistry(TitleUnderline, { BackgroundColor3 = 'AccentColor' })

    local TabButtonHolder = Library:Create('ScrollingFrame', {
        BackgroundTransparency = 1;
        BorderSizePixel = 0;
        Position = UDim2.fromOffset(8, 58);
        Size = UDim2.new(1, -16, 1, -66);
        CanvasSize = UDim2.new(0, 0, 0, 0);
        AutomaticCanvasSize = Enum.AutomaticSize.Y;
        ScrollBarThickness = 0;
        ScrollingDirection = Enum.ScrollingDirection.Y;
        ElasticBehavior = Enum.ElasticBehavior.Never;
        Parent = Sidebar;
    })
    Library:Create('UIListLayout', {
        Padding = UDim.new(0, 4);
        SortOrder = Enum.SortOrder.LayoutOrder;
        Parent = TabButtonHolder;
    })

    local ContentArea = Library:Create('Frame', {
        BackgroundTransparency = 1;
        Position = UDim2.fromOffset(sidebarWidth + 1, 0);
        Size = UDim2.new(1, -(sidebarWidth + 1), 1, 0);
        Parent = WindowFrame;
    })

    Library:MakeDraggable(WindowFrame, Sidebar)

    local activeTab = nil

    function Window:AddTab(tabName)
        local Tab = {
            Groupboxes = {};
            Tabboxes = {};
            Name = tabName;
        }

        local TabButton = Library:Create('TextButton', {
            BackgroundColor3 = Library.AccentColor;
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 0, 32);
            Font = Library.Font;
            Text = '';
            AutoButtonColor = false;
            Parent = TabButtonHolder;
        })
        Round(TabButton, 8)
        local TabIndicator = Library:Create('Frame', {
            AnchorPoint = Vector2.new(0, 0.5);
            BackgroundColor3 = Library.AccentColor;
            BorderSizePixel = 0;
            Position = UDim2.new(0, 0, 0.5, 0);
            Size = UDim2.fromOffset(3, 0);
            Parent = TabButton;
        })
        Round(TabIndicator, 2)
        Library:AddToRegistry(TabIndicator, { BackgroundColor3 = 'AccentColor' })
        local TabButtonLabel = Library:CreateLabel({
            Size = UDim2.new(1, -24, 1, 0);
            Position = UDim2.fromOffset(14, 0);
            Text = tabName;
            TextColor3 = Library.DimFontColor;
            TextXAlignment = Enum.TextXAlignment.Left;
            Parent = TabButton;
        })

        local TabContent = Library:Create('ScrollingFrame', {
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 1, 0);
            CanvasSize = UDim2.new(0, 0, 0, 0);
            AutomaticCanvasSize = Enum.AutomaticSize.Y;
            ScrollBarThickness = 3;
            ScrollBarImageColor3 = Library.AccentColor;
            ScrollingDirection = Enum.ScrollingDirection.Y;
            ElasticBehavior = Enum.ElasticBehavior.Never;
            Visible = false;
            Parent = ContentArea;
        })
        Library:AddToRegistry(TabContent, { ScrollBarImageColor3 = 'AccentColor' })
        Library:Create('UIPadding', {
            PaddingTop = UDim.new(0, 12);
            PaddingBottom = UDim.new(0, 12);
            PaddingLeft = UDim.new(0, 12);
            PaddingRight = UDim.new(0, 12);
            Parent = TabContent;
        })

        local LeftColumn = Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(0.5, -6, 0, 0);
            AutomaticSize = Enum.AutomaticSize.Y;
            Parent = TabContent;
        })
        Library:Create('UIListLayout', {
            Padding = UDim.new(0, 12);
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = LeftColumn;
        })
        local RightColumn = Library:Create('Frame', {
            BackgroundTransparency = 1;
            Position = UDim2.new(0.5, 6, 0, 12);
            Size = UDim2.new(0.5, -6, 0, 0);
            AutomaticSize = Enum.AutomaticSize.Y;
            Parent = TabContent;
        })
        Library:Create('UIListLayout', {
            Padding = UDim.new(0, 12);
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = RightColumn;
        })

        local function ShowTab()
            if activeTab == Tab then return end
            if activeTab then activeTab:HideVisuals() end
            activeTab = Tab
            TabContent.Visible = true
            Animate(TabButton, { BackgroundTransparency = 0.88 }, TweenSmooth)
            Animate(TabButtonLabel, { TextColor3 = Library.FontColor; Position = UDim2.fromOffset(18, 0) }, TweenSmooth)
            Animate(TabIndicator, { Size = UDim2.fromOffset(3, 16) }, TweenBounce)
            for _, columnFrame in ipairs({ LeftColumn, RightColumn }) do
                for _, groupboxChild in ipairs(columnFrame:GetChildren()) do
                    if groupboxChild:IsA('Frame') then
                        groupboxChild.BackgroundTransparency = 1
                        Animate(groupboxChild, { BackgroundTransparency = 0 }, TweenSlow)
                    end
                end
            end
        end
        local function HideVisuals()
            TabContent.Visible = false
            Animate(TabButton, { BackgroundTransparency = 1 }, TweenSmooth)
            Animate(TabButtonLabel, { TextColor3 = Library.DimFontColor; Position = UDim2.fromOffset(14, 0) }, TweenSmooth)
            Animate(TabIndicator, { Size = UDim2.fromOffset(3, 0) }, TweenSmooth)
        end
        Tab.ShowTab = ShowTab
        Tab.HideVisuals = HideVisuals

        TabButton.MouseButton1Click:Connect(ShowTab)
        TabButton.MouseEnter:Connect(function()
            if activeTab ~= Tab then
                Animate(TabButton, { BackgroundTransparency = 0.94 }, TweenFast)
                Animate(TabButtonLabel, { TextColor3 = Library.FontColor }, TweenFast)
            end
        end)
        TabButton.MouseLeave:Connect(function()
            if activeTab ~= Tab then
                Animate(TabButton, { BackgroundTransparency = 1 }, TweenFast)
                Animate(TabButtonLabel, { TextColor3 = Library.DimFontColor }, TweenFast)
            end
        end)

        function Tab:AddGroupbox(groupboxInfo)
            local column = groupboxInfo.Side == 2 and RightColumn or LeftColumn
            local Groupbox = BuildGroupbox(column, groupboxInfo.Name)
            Tab.Groupboxes[groupboxInfo.Name] = Groupbox
            return Groupbox
        end
        function Tab:AddLeftGroupbox(groupboxName)  return Tab:AddGroupbox({ Side = 1; Name = groupboxName }) end
        function Tab:AddRightGroupbox(groupboxName) return Tab:AddGroupbox({ Side = 2; Name = groupboxName }) end

        function Tab:AddTabbox(tabboxInfo)
            tabboxInfo = tabboxInfo or {}
            local column = tabboxInfo.Side == 2 and RightColumn or LeftColumn
            local Tabbox = { Tabs = {} }

            local tabboxFrame = Library:Create('Frame', {
                BackgroundColor3 = Library.MainColor;
                BorderSizePixel = 0;
                Size = UDim2.new(1, 0, 0, 0);
                AutomaticSize = Enum.AutomaticSize.Y;
                Parent = column;
            })
            Round(tabboxFrame, 10)
            Stroke(tabboxFrame, Library.OutlineColor)
            Library:AddToRegistry(tabboxFrame, { BackgroundColor3 = 'MainColor' })

            local tabboxButtonRow = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor;
                BorderSizePixel = 0;
                Position = UDim2.fromOffset(8, 8);
                Size = UDim2.new(1, -16, 0, 28);
                Parent = tabboxFrame;
            })
            Round(tabboxButtonRow, 8)
            Library:Create('UIListLayout', {
                FillDirection = Enum.FillDirection.Horizontal;
                SortOrder = Enum.SortOrder.LayoutOrder;
                Parent = tabboxButtonRow;
            })

            local activeSubTab = nil

            function Tabbox:AddTab(subTabName)
                local TabboxTab = { Name = subTabName }

                local subTabButton = Library:Create('TextButton', {
                    BackgroundColor3 = Library.AccentColor;
                    BackgroundTransparency = 1;
                    BorderSizePixel = 0;
                    Size = UDim2.new(0.5, 0, 1, -6);
                    Position = UDim2.fromOffset(0, 3);
                    Font = Library.Font;
                    Text = subTabName;
                    TextColor3 = Library.DimFontColor;
                    TextSize = 12;
                    AutoButtonColor = false;
                    Parent = tabboxButtonRow;
                })
                Round(subTabButton, 6)
                Library:Create('UIPadding', { PaddingTop = UDim.new(0, 0); Parent = subTabButton })

                local subTabContainerHolder = Library:Create('Frame', {
                    BackgroundTransparency = 1;
                    Position = UDim2.fromOffset(12, 44);
                    Size = UDim2.new(1, -24, 0, 0);
                    AutomaticSize = Enum.AutomaticSize.Y;
                    Visible = false;
                    Parent = tabboxFrame;
                })
                Library:Create('UIListLayout', {
                    SortOrder = Enum.SortOrder.LayoutOrder;
                    Parent = subTabContainerHolder;
                })
                Library:Create('UIPadding', {
                    PaddingBottom = UDim.new(0, 12);
                    Parent = subTabContainerHolder;
                })

                TabboxTab.Container = subTabContainerHolder
                for functionName, functionValue in pairs(GroupboxFuncs) do
                    TabboxTab[functionName] = functionValue
                end

                function TabboxTab:Show()
                    if activeSubTab and activeSubTab ~= TabboxTab then activeSubTab:Hide() end
                    activeSubTab = TabboxTab
                    subTabContainerHolder.Visible = true
                    Animate(subTabButton, { BackgroundTransparency = 0.85; TextColor3 = Library.FontColor }, TweenSmooth)
                end
                function TabboxTab:Hide()
                    subTabContainerHolder.Visible = false
                    Animate(subTabButton, { BackgroundTransparency = 1; TextColor3 = Library.DimFontColor }, TweenSmooth)
                end
                function TabboxTab:Resize() end

                subTabButton.MouseButton1Click:Connect(function() TabboxTab:Show() end)

                local subTabCount = 0
                for _, child in ipairs(tabboxButtonRow:GetChildren()) do
                    if child:IsA('TextButton') then subTabCount = subTabCount + 1 end
                end
                for _, child in ipairs(tabboxButtonRow:GetChildren()) do
                    if child:IsA('TextButton') then child.Size = UDim2.new(1 / subTabCount, 0, 1, -6) end
                end

                table.insert(Tabbox.Tabs, TabboxTab)
                if #Tabbox.Tabs == 1 then TabboxTab:Show() end
                return TabboxTab
            end

            Tab.Tabboxes[tabboxInfo.Name or #Tab.Tabboxes + 1] = Tabbox
            return Tabbox
        end
        function Tab:AddLeftTabbox(tabboxName)  return Tab:AddTabbox({ Name = tabboxName; Side = 1 }) end
        function Tab:AddRightTabbox(tabboxName) return Tab:AddTabbox({ Name = tabboxName; Side = 2 }) end
        function Tab:Resize() end

        Window.Tabs[tabName] = Tab
        if not activeTab then ShowTab() end
        return Tab
    end

    function Window:SetWindowTitle(newTitle)
        TitleLabel.Text = newTitle
    end

    local function OpenWindow()
        Library.Toggled = true
        WindowFrame.Visible = true
        WindowScale.Scale = 0.92
        Animate(WindowScale, { Scale = 1 }, TweenBounce)
        for _, callback in ipairs(Library.VisibilityCallbacks) do
            Library:SafeCallback(callback, true)
        end
    end
    local function CloseWindow()
        Library.Toggled = false
        local closeTween = Animate(WindowScale, { Scale = 0.92 }, TweenFast)
        closeTween.Completed:Wait()
        if not Library.Toggled then WindowFrame.Visible = false end
        for _, callback in ipairs(Library.VisibilityCallbacks) do
            Library:SafeCallback(callback, false)
        end
    end

    function Library.Toggle()
        if Library.Toggled then CloseWindow() else OpenWindow() end
    end
    function Library:RegisterVisibilityCallback(callback)
        table.insert(Library.VisibilityCallbacks, callback)
    end

    Library:GiveSignal(UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        local menuKeybind = Library.MenuKeybind or Enum.KeyCode.RightControl
        if input.KeyCode == menuKeybind then
            Library.Toggle()
        end
    end))

    Window.Holder = WindowFrame
    Library.WindowFrame = WindowFrame

    if Config.AutoShow ~= false then
        task.defer(OpenWindow)
    end

    return Window
end

return Library
end)()
