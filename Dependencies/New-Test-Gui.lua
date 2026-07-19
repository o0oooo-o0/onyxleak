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
    Textbox.Outer = inputFrame
    Textbox.DestroyParts = { Textbox.TitleLabel }
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
    Toggle.Outer = toggleRow

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
        sliderTitle.Text = Slider.Info.Text or ''
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

    Slider.Outer = sliderHolder
    Slider.TextLabel = sliderTitle
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

    Dropdown.Outer = dropdownFrame
    Dropdown.List = listFrame
    Dropdown.Holder = listScroll
    Dropdown.Container = listScroll
    Dropdown.DestroyParts = { listFrame; Dropdown.TitleLabel }
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
    Library.DefaultWindowSize = UDim2.fromOffset(windowWidth, windowHeight)
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


Library.ThemeScales = {}
Library.UIScaleValue = 1.0
Library.IsMobile = false
Library.IconSize = 20
Library.TextRegistry = {}
Library.SliderRegistry = {}
Library.DropdownRegistry = {}
Library.KeybindRegistry = {}
Library.IconSizeCallbacks = {}

function Library:RegisterVisibilityCallback(callback) table.insert(Library.VisibilityCallbacks, callback) end
function Library:RegisterIconSizeCallback(callback) table.insert(Library.IconSizeCallbacks, callback) end

function Library:GetTextBounds(text, font, size, resolution)
    local success, bounds = pcall(Services.TextService.GetTextSize, Services.TextService, text, size, font, resolution or Vector2.new(1920, 1080))
    if not success or not bounds then
        local fallbackSuccess, fallbackBounds = pcall(Services.TextService.GetTextSize, Services.TextService, text, size, Enum.Font.Code, resolution or Vector2.new(1920, 1080))
        bounds = fallbackSuccess and fallbackBounds or Vector2.new(200, size)
    end
    return bounds.X, bounds.Y
end

function Library:SetText(element, newText)
    if not element or newText == nil then return false end
    newText = tostring(newText)
    if element.Info and element.Info.Text ~= nil and element.Display then
        element.Info.Text = newText
        pcall(element.Display, element)
        return true
    end
    local label = element.TextLabel or element.TitleLabel
    if not label then return false end
    local success = pcall(function() label.Text = newText end)
    return success
end

function Library:RemoveElement(element)
    if not element then return false end
    for _, part in ipairs(element.DestroyParts or {}) do
        if part then pcall(function() part:Destroy() end) end
    end
    if element.Outer then pcall(function() element.Outer:Destroy() end) end
    for index, storedElement in pairs(Toggles) do if storedElement == element then Toggles[index] = nil end end
    for index, storedElement in pairs(Options) do if storedElement == element then Options[index] = nil end end
    for listIndex = #Library.DependencyBoxes, 1, -1 do
        if Library.DependencyBoxes[listIndex] == element then table.remove(Library.DependencyBoxes, listIndex) end
    end
    return true
end

function Library:OnHighlight(hoverInstance, targetInstance, onProperties, offProperties)
    local function ResolveAndApply(properties)
        for propertyName, propertyValue in pairs(properties) do
            local resolvedValue = (type(propertyValue) == 'string' and Library[propertyValue]) or propertyValue
            pcall(function() targetInstance[propertyName] = resolvedValue end)
        end
    end
    hoverInstance.MouseEnter:Connect(function() ResolveAndApply(onProperties) end)
    hoverInstance.MouseLeave:Connect(function() ResolveAndApply(offProperties) end)
end

function Library:ForceCase() end
function Library:RefreshTextRegistry() end
function Library:ApplyTextMetrics() end
function Library:RememberTextSize() end
function Library:SetKeybindVisibility() end
function Library:ConfigureNotifications(configuration) Library.NotificationConfig = configuration end
function Library:BindResizeHandle() end
function Library:BindResizeHandleGhost() end
function Library:SetBackdropColor() end
function Library:SetBackdropOpacity() end
function Library:SetBlurOpacity() end
function Library:SetEzLogoTransparency() end
function Library:SetEzLogoPosition() end
function Library:SetEzLogoSize() end
function Library:SetEzLogoColor() end
function Library:SetEzLogoFatness() end
function Library:SetEzLogoMaterial() end
function Library:SetEzLogoSpeed() end

function Library:SetWindowVisible(visible)
    if Library.WindowFrame then Library.WindowFrame.Visible = visible and Library.Toggled end
end

function Library:ResetMainWindowPosition(skipSave)
    if Library.WindowFrame then
        Library.WindowFrame.AnchorPoint = Vector2.new(0.5, 0.5)
        Library.WindowFrame.Position = UDim2.fromScale(0.5, 0.5)
    end
end

function Library:ResetMainWindowSize()
    if Library.WindowFrame and Library.DefaultWindowSize then
        Library.WindowFrame.Size = Library.DefaultWindowSize
    end
end

function Library:CreateHeadlessGroupbox(container)
    local Groupbox = { Container = container }
    for functionName, functionValue in pairs(GroupboxFuncs) do
        Groupbox[functionName] = functionValue
    end
    return Groupbox
end
function Library:GetMainWindowSize() return Library.MainWindowSize end
function Library:SetMainWindowSize(width, height, skipSave)
    Library.MainWindowSize = { w = tonumber(width); h = tonumber(height) }
end
function Library:SetUIScale(scale, skipSave)
    Library.UIScaleValue = tonumber(scale) or 1.0
    for _, themeScale in ipairs(Library.ThemeScales) do
        pcall(function() themeScale.Scale = Library.UIScaleValue end)
    end
end
function Library:SetIconSize(size)
    Library.IconSize = tonumber(size) or Library.IconSize
    for _, callback in ipairs(Library.IconSizeCallbacks) do
        Library:SafeCallback(callback, Library.IconSize)
    end
end

function Library:CreatePrompt(config)
    local outer = Library:Create("TextButton", {
        Size                    = UDim2.fromScale(1, 1),
        BackgroundColor3        = Color3.new(0, 0, 0),
        BackgroundTransparency  = 0.5,
        AutoButtonColor         = false,
        Text                    = "",
        ZIndex                  = 2000,
        Parent                  = Library.ScreenGui,
    })
    outer.MouseButton1Click:Connect(function()
        local mouse = game:GetService("UserInputService"):GetMouseLocation()
        local pos  = inner.AbsolutePosition
        local size = inner.AbsoluteSize
        if mouse.X < pos.X or mouse.X > pos.X + size.X
        or mouse.Y < pos.Y or mouse.Y > pos.Y + size.Y then
            outer:Destroy()
        end
    end)

    local isConfirm = config.Mode == "Confirm"
    local w = isConfirm and (300) or (400)
    local h = isConfirm and (120) or (350)

    local inner = Library:Create("TextButton", {
        AnchorPoint       = Vector2.new(0.5, 0.5),
        Position          = UDim2.fromScale(0.5, 0.5),
        Size              = UDim2.fromOffset(w, h),
        BackgroundColor3  = Library.BackgroundColor,
        BorderColor3      = Library.OutlineColor,
        AutoButtonColor   = false,
        Text              = "",
        Active            = true,
        ZIndex            = 2001,
        Parent            = outer,
    })
    local innerScale = Library:Create('UIScale', { Scale = Library.UIScaleValue or 1.0; Parent = inner })
    table.insert(Library.ThemeScales, innerScale)
    Library:AddToRegistry(inner, {BackgroundColor3="BackgroundColor", BorderColor3="OutlineColor"})
    local titleBar = Library:Create("Frame", {
        Size              = UDim2.new(1, 0, 0, (22)),
        BackgroundColor3  = Library.MainColor,
        BorderSizePixel   = 0,
        ZIndex            = 2002,
        Parent            = inner,
    })
    Library:AddToRegistry(titleBar, {BackgroundColor3="MainColor"})

    local backButton = Library:Create("TextButton", {
        Position          = UDim2.new(0, (3), 0.5, 0),
        AnchorPoint       = Vector2.new(0, 0.5),
        Size              = UDim2.fromOffset((16), (16)),
        BackgroundTransparency = 1,
        AutoButtonColor   = false,
        Text              = "<",
        TextColor3        = Library.FontColor,
        TextSize          = (14),
        Font              = Library.Font,
        ZIndex            = 2003,
        Parent            = titleBar,
    })
    Library:AddToRegistry(backButton, {TextColor3="FontColor", Font="Font"})
    backButton.MouseButton1Click:Connect(function() outer:Destroy() end)

    Library:CreateLabel({
        Position        = UDim2.new(0, (22), 0, 0),
        Size            = UDim2.new(1, -(43), 1, 0),
        Text            = config.Title or "Prompt",
        TextXAlignment  = Enum.TextXAlignment.Left,
        TextSize        = (14),
        ZIndex          = 2003,
        Parent          = titleBar,
    })

    if isConfirm then
        Library:CreateLabel({
            Position        = UDim2.fromOffset((10), (30)),
            Size            = UDim2.new(1, -(20), 1, -(70)),
            Text            = config.Text or "Are you sure?",
            TextXAlignment  = Enum.TextXAlignment.Center,
            TextYAlignment  = Enum.TextYAlignment.Center,
            TextSize        = (14),
            TextWrapped     = true,
            ZIndex          = 2002,
            Parent          = inner,
        })

        local confirmBtn = Library:Create("TextButton", {
            Position          = UDim2.new(0, (10), 1, -(30)),
            Size              = UDim2.new(0.5, -(15), 0, (20)),
            BackgroundColor3  = Library.RiskColor,
            BorderColor3      = Library.OutlineColor,
            TextColor3        = Library.FontColor,
            TextSize          = (14),
            Font              = Library.Font,
            Text              = "Confirm",
            ZIndex            = 2002,
            Parent            = inner,
        })
        Library:AddToRegistry(confirmBtn, {BackgroundColor3="RiskColor", BorderColor3="OutlineColor", TextColor3="FontColor", Font="Font"})

        local cancelBtn = Library:Create("TextButton", {
            Position          = UDim2.new(0.5, (5), 1, -(30)),
            Size              = UDim2.new(0.5, -(15), 0, (20)),
            BackgroundColor3  = Library.MainColor,
            BorderColor3      = Library.OutlineColor,
            TextColor3        = Library.FontColor,
            TextSize          = (14),
            Font              = Library.Font,
            Text              = "Cancel",
            ZIndex            = 2002,
            Parent            = inner,
        })
        Library:AddToRegistry(cancelBtn, {BackgroundColor3="MainColor", BorderColor3="OutlineColor", TextColor3="FontColor", Font="Font"})

        confirmBtn.MouseButton1Click:Connect(function()
            if config.Callback then config.Callback() end
            outer:Destroy()
        end)
        cancelBtn.MouseButton1Click:Connect(function()
            outer:Destroy()
        end)
    else
        local textBox = Library:Create("TextBox", {
            Position          = UDim2.fromOffset((10), (30)),
            Size              = UDim2.new(1, -(20), 1, config.Mode == "Import" and -(100) or -(70)),
            BackgroundColor3  = Library.MainColor,
            BorderColor3      = Library.OutlineColor,
            TextColor3        = Library.FontColor,
            TextSize          = (14),
            Font              = Library.Font,
            TextXAlignment    = Enum.TextXAlignment.Left,
            TextYAlignment    = Enum.TextYAlignment.Top,
            ClearTextOnFocus  = false,
            TextWrapped       = true,
            MultiLine         = true,
            Text              = config.Text or "",
            ZIndex            = 2002,
            Parent            = inner,
        })
        Library:AddToRegistry(textBox, {BackgroundColor3="MainColor", BorderColor3="OutlineColor", TextColor3="FontColor", Font="Font"})

        local nameInput
        if config.Mode == "Import" then
            nameInput = Library:Create("TextBox", {
                Position          = UDim2.new(0, (10), 1, -(60)),
                Size              = UDim2.new(1, -(20), 0, (20)),
                BackgroundColor3  = Library.MainColor,
                BorderColor3      = Library.OutlineColor,
                TextColor3        = Library.FontColor,
                PlaceholderText   = "Enter Name...",
                Text              = "",
                TextSize          = (14),
                Font              = Library.Font,
                ZIndex            = 2002,
                Parent            = inner,
            })
            Library:AddToRegistry(nameInput, {BackgroundColor3="MainColor", BorderColor3="OutlineColor", TextColor3="FontColor", Font="Font"})
        end

        local actionBtn = Library:Create("TextButton", {
            Position          = UDim2.new(0, (10), 1, -(30)),
            Size              = UDim2.new(1, -(20), 0, (20)),
            BackgroundColor3  = Library.AccentColor,
            BorderColor3      = Library.OutlineColor,
            TextColor3        = Library.FontColor,
            TextSize          = (14),
            Font              = Library.Font,
            Text              = config.Mode == "Export" and "Copy to Clipboard" or "Import & Save",
            ZIndex            = 2002,
            Parent            = inner,
        })
        Library:AddToRegistry(actionBtn, {BackgroundColor3="AccentColor", BorderColor3="OutlineColor", TextColor3="FontColor", Font="Font"})

        actionBtn.MouseButton1Click:Connect(function()
            if config.Mode == "Export" then
                if setclipboard then
                    setclipboard(textBox.Text)
                    Library:Notify("Copied to clipboard.", 2)
                    actionBtn.Text = "Copied"
                    task.delay(3, function()
                        if actionBtn and actionBtn.Parent then actionBtn.Text = "Copy to Clipboard" end
                    end)
                else
                    Library:Notify("Executor does not support setclipboard.", 3)
                end
            else
                if config.Callback then
                    config.Callback(textBox.Text, nameInput and nameInput.Text or "")
                    outer:Destroy()
                end
            end
        end)
    end
end

local AUTOLOAD_FILE = 'Elite Zone/Cache/AutoLoad.json'
local AUTOLOAD_GAME = 'Rivals'

local function ReadAutoloadRoot()
	if isfile and isfile(AUTOLOAD_FILE) then
		local ok, data = pcall(function() return Services.HttpService:JSONDecode(readfile(AUTOLOAD_FILE)) end)
		if ok and type(data) == 'table' then return data end
	end
	return {}
end

local function ReadAutoloadFile()
	local game = ReadAutoloadRoot()[AUTOLOAD_GAME]
	if type(game) ~= 'table' then game = { theme = 'none', config = 'none' } end
	return game
end

local function WriteAutoloadField(field, value)
	if not writefile then return end
	if makefolder and isfolder and not isfolder('Elite Zone/Cache') then makefolder('Elite Zone/Cache') end
	local root = ReadAutoloadRoot()
	local game = root[AUTOLOAD_GAME]
	if type(game) ~= 'table' then game = { theme = 'none', config = 'none' } end
	game[field] = value
	root[AUTOLOAD_GAME] = game
	writefile(AUTOLOAD_FILE, Services.HttpService:JSONEncode(root))
end

local ThemeManager = {} do
	ThemeManager.Folder = 'Elite Zone/Rivals'

	ThemeManager.Library = nil
ThemeManager.ColorFields = { "FontColor", "MainColor", "AccentColor", "BackgroundColor", "OutlineColor" }
ThemeManager.FontMap = {
    SourceSans   = Enum.Font.SourceSans,
    Code         = Enum.Font.Code,
    Gotham       = Enum.Font.Gotham,
    GothamBold   = Enum.Font.GothamBold,
    RobotoMono   = Enum.Font.RobotoMono,
    SciFi        = Enum.Font.SciFi,
    Arcade       = Enum.Font.Arcade,
    Fredoka      = Enum.Font.FredokaOne,
    Cartoon      = Enum.Font.Cartoon,
    ProggyClean  = 'custom',
}
ThemeManager.BuiltInThemes = {
    ['Default']      = { 0,  Services.HttpService:JSONDecode('{"FontColor":"ebdbb2","MainColor":"282828","AccentColor":"fe8019","BackgroundColor":"1d2021","OutlineColor":"3c3836"}') },
    ['Elite Zone']   = { 1,  Services.HttpService:JSONDecode('{"MainColor":"181818","AccentColor":"858586","OutlineColor":"1f1f1f","BackgroundColor":"141414","FontColor":"ffffff"}') },
    ['UE']           = { 2,  Services.HttpService:JSONDecode('{"MainColor":"181818","AccentColor":"4777b6","OutlineColor":"1f1f1f","BackgroundColor":"141414","FontColor":"ffffff"}') },
    ['Better UE']    = { 2.5, Services.HttpService:JSONDecode('{"MainColor":"181818","AccentColor":"4777b6","OutlineColor":"1f1f1f","BackgroundColor":"141414","FontColor":"d6d6d6"}') },
    ['BBot']         = { 3,  Services.HttpService:JSONDecode('{"FontColor":"ffffff","MainColor":"1e1e1e","AccentColor":"7e48a3","BackgroundColor":"232323","OutlineColor":"141414"}') },
    ['Fatality']     = { 4,  Services.HttpService:JSONDecode('{"FontColor":"ffffff","MainColor":"1e1842","AccentColor":"c50754","BackgroundColor":"191335","OutlineColor":"3c355d"}') },
    ['Jester']       = { 5,  Services.HttpService:JSONDecode('{"FontColor":"ffffff","MainColor":"242424","AccentColor":"db4467","BackgroundColor":"1c1c1c","OutlineColor":"373737"}') },
    ['Mint']         = { 6,  Services.HttpService:JSONDecode('{"FontColor":"ffffff","MainColor":"242424","AccentColor":"3db488","BackgroundColor":"1c1c1c","OutlineColor":"373737"}') },
    ['Tokyo Night']  = { 7,  Services.HttpService:JSONDecode('{"FontColor":"ffffff","MainColor":"191925","AccentColor":"6759b3","BackgroundColor":"16161f","OutlineColor":"323232"}') },
    ['Ubuntu']       = { 8,  Services.HttpService:JSONDecode('{"FontColor":"ffffff","MainColor":"3e3e3e","AccentColor":"e2581e","BackgroundColor":"323232","OutlineColor":"191919"}') },
    ['Quartz']       = { 9,  Services.HttpService:JSONDecode('{"FontColor":"ffffff","MainColor":"232330","AccentColor":"426e87","BackgroundColor":"1d1b26","OutlineColor":"27232f"}') },
    ['Crimson']      = { 10, Services.HttpService:JSONDecode('{"FontColor":"ffffff","MainColor":"1f1515","AccentColor":"cc2222","BackgroundColor":"160e0e","OutlineColor":"3a1f1f"}') },
    ['Cyberpunk']    = { 11, Services.HttpService:JSONDecode('{"FontColor":"ffffff","MainColor":"0d0d1a","AccentColor":"00ffe0","BackgroundColor":"080810","OutlineColor":"1a1a33"}') },
    ['Caramel']      = { 12, Services.HttpService:JSONDecode('{"FontColor":"ffffff","MainColor":"2b1f10","AccentColor":"d4822a","BackgroundColor":"1c1208","OutlineColor":"3d2b12"}') },
    ['Ocean']        = { 13, Services.HttpService:JSONDecode('{"FontColor":"ffffff","MainColor":"0d1b2a","AccentColor":"1e90ff","BackgroundColor":"080f18","OutlineColor":"1a3a5c"}') },
    ['Lavender']     = { 14, Services.HttpService:JSONDecode('{"FontColor":"ffffff","MainColor":"22203a","AccentColor":"b48ef0","BackgroundColor":"19172d","OutlineColor":"35305a"}') },
    ['Matrix']       = { 15, Services.HttpService:JSONDecode('{"FontColor":"00ff41","MainColor":"0d1a0d","AccentColor":"00cc33","BackgroundColor":"080f08","OutlineColor":"0f2b0f"}') },
    ['Rose Gold']    = { 16, Services.HttpService:JSONDecode('{"FontColor":"ffffff","MainColor":"2a1a1f","AccentColor":"e8a0b0","BackgroundColor":"1e1015","OutlineColor":"3d2030"}') },
    ['Midnight Gold']= { 17, Services.HttpService:JSONDecode('{"FontColor":"ffffff","MainColor":"12162b","AccentColor":"c9a84c","BackgroundColor":"0c0f1e","OutlineColor":"1e2440"}') },
    ['Rust']         = { 18, Services.HttpService:JSONDecode('{"FontColor":"ffffff","MainColor":"1e1510","AccentColor":"c0521a","BackgroundColor":"140e08","OutlineColor":"3b2010"}') },
    ['Slate']        = { 19, Services.HttpService:JSONDecode('{"FontColor":"ffffff","MainColor":"1e2a2a","AccentColor":"4db8b8","BackgroundColor":"141f1f","OutlineColor":"2a3d3d"}') },
    ['Dracula']      = { 20, Services.HttpService:JSONDecode('{"FontColor":"f8f8f2","MainColor":"282a36","AccentColor":"bd93f9","BackgroundColor":"1e1f29","OutlineColor":"44475a"}') },
    ['Synthwave']    = { 21, Services.HttpService:JSONDecode('{"FontColor":"ffffff","MainColor":"1a0a2e","AccentColor":"ff2d78","BackgroundColor":"110720","OutlineColor":"2d1050"}') },
    ['Forest']       = { 22, Services.HttpService:JSONDecode('{"FontColor":"ffffff","MainColor":"1a2215","AccentColor":"5a9e3a","BackgroundColor":"111a0d","OutlineColor":"2a3d1e"}') },
    ['Arctic']       = { 23, Services.HttpService:JSONDecode('{"FontColor":"ffffff","MainColor":"1a2535","AccentColor":"a8d8f0","BackgroundColor":"111c2a","OutlineColor":"253545"}') },
    ['Charcoal']     = { 24, Services.HttpService:JSONDecode('{"FontColor":"ffffff","MainColor":"2e2e2e","AccentColor":"aaaaaa","BackgroundColor":"222222","OutlineColor":"444444"}') },
    ['One Dark']     = { 25, Services.HttpService:JSONDecode('{"FontColor":"abb2bf","MainColor":"282c34","AccentColor":"61afef","BackgroundColor":"21252b","OutlineColor":"3e4451"}') },
    ['Nord']         = { 26, Services.HttpService:JSONDecode('{"FontColor":"d8dee9","MainColor":"2e3440","AccentColor":"88c0d0","BackgroundColor":"242933","OutlineColor":"3b4252"}') },
    ['Ayu Mirage']   = { 28, Services.HttpService:JSONDecode('{"FontColor":"cccac2","MainColor":"1f2430","AccentColor":"ffcc66","BackgroundColor":"171b24","OutlineColor":"242936"}') },
    ['Material Ocean']={ 29, Services.HttpService:JSONDecode('{"FontColor":"8f93a2","MainColor":"0f111a","AccentColor":"80cbc4","BackgroundColor":"090b10","OutlineColor":"1a1c25"}') },
    ['Deep Sea']     = { 30, Services.HttpService:JSONDecode('{"FontColor":"ffffff","MainColor":"001220","AccentColor":"0077b6","BackgroundColor":"000b14","OutlineColor":"002a45"}') },
    ['Vampire']      = { 31, Services.HttpService:JSONDecode('{"FontColor":"ffffff","MainColor":"1a0000","AccentColor":"e60000","BackgroundColor":"0d0000","OutlineColor":"330000"}') },
    ['Obsidian']     = { 32, Services.HttpService:JSONDecode('{"FontColor":"ffffff","MainColor":"0a0a0a","AccentColor":"00ff88","BackgroundColor":"050505","OutlineColor":"1a1a1a"}') },
}
do
	
	
	local CapsCase, LowerCase = {}, {}
	for _, k in ipairs({"CaseTabs","CaseSubTabs","CaseGroupboxes","CaseToggles","CaseButtons",
		"CaseSliders","CaseDropdowns","CaseDDItems","CaseLabels","CaseInputs","CaseTooltip"}) do
		CapsCase[k]  = "Capitalized"
		LowerCase[k] = "Lowercase"
	end
	for name, entry in next, ThemeManager.BuiltInThemes do
		local colors = entry[2]
		colors.backgroundBlur, colors.blurOpacity, colors.backgroundFrame = true, 75, true
		colors.backgroundOpacity = 74
		colors.caseSettings = (name == 'UE' or name == 'Better UE') and LowerCase or CapsCase
	end
end
	local function getFontName(font)
		for name, enum in next, ThemeManager.FontMap do
			if enum == font then
				return name
			end
		end
		return 'Code'
	end

	function ThemeManager:GetAutoloadFile()
		return AUTOLOAD_FILE
	end

	function ThemeManager:NormalizeThemeData(data)
		if type(data) ~= 'table' then
			return nil
		end

		local colors = type(data.colors) == 'table' and data.colors or data
		local out = { colors = {} }
		for _, field in next, self.ColorFields do
			local value = colors[field]
			if type(value) == 'string' and value ~= '' then
				out.colors[field] = value
			end
		end

		local font = data.font or data.Font
		if type(font) == 'string' and font ~= '' then
			out.font = font
		end

		local iconSize = data.iconSize or data.IconSize
		if type(iconSize) == 'number' then
			out.iconSize = iconSize
		end

		local uiScale = data.uiScale or data.UiScale
		if type(uiScale) == 'number' then
			out.uiScale = uiScale
		end

		if type(data.caseSettings) == 'table' then
			out.caseSettings = data.caseSettings
		end

		if type(data.notifications) == 'table' then
			out.notifications = data.notifications
		end

		local backgroundOpacity = data.backgroundOpacity or data.BackgroundOpacity
		if type(backgroundOpacity) == 'number' then
			out.backgroundOpacity = backgroundOpacity
		end

		local blurOpacity = data.blurOpacity or data.BlurOpacity
		if type(blurOpacity) == 'number' then
			out.blurOpacity = blurOpacity
		end

		local backgroundBlur = data.backgroundBlur
		if backgroundBlur == nil then backgroundBlur = data.BackgroundBlur end
		if type(backgroundBlur) == 'boolean' then
			out.backgroundBlur = backgroundBlur
		end

		local backgroundFrame = data.backgroundFrame
		if backgroundFrame == nil then backgroundFrame = data.BackgroundFrame end
		if type(backgroundFrame) == 'boolean' then
			out.backgroundFrame = backgroundFrame
		end

		if type(data.mainWindowSize) == 'table' then
			local w = tonumber(data.mainWindowSize.w)
			local h = tonumber(data.mainWindowSize.h)
			if w and h then
				out.mainWindowSize = { w = w, h = h }
			end
		end

		return out
	end

	function ThemeManager:GetThemeState(theme, isCustom)
		local state = {
			theme     = theme or self.CurrentThemeName or (Options and Options.ThemeManager_ThemeList and Options.ThemeManager_ThemeList.Value) or 'Default',
			custom    = type(isCustom) == 'boolean' and isCustom or self.CurrentThemeCustom == true,
			font      = Options and Options.ThemeManager_Font and Options.ThemeManager_Font.Value or getFontName(self.Library and self.Library.Font),
			iconSize  = tonumber(Options and Options.ThemeManager_IconSize and Options.ThemeManager_IconSize.Value) or tonumber(self.Library and self.Library.IconSize) or 20,
			uiScale   = tonumber(Options and Options.ThemeManager_UIScale and Options.ThemeManager_UIScale.Value) or tonumber(self.Library and self.Library.UIScaleValue) or 1.0,
			colors    = {},
		}
		if self.Library and type(self.Library.GetMainWindowSize) == 'function' then
			state.mainWindowSize = self.Library:GetMainWindowSize()
		end
		for _, field in next, self.ColorFields do
			local value = Options and Options[field] and Options[field].Value or (self.Library and self.Library[field])
			if typeof(value) == 'Color3' then
				state.colors[field] = value:ToHex()
			end
		end

		if Options and Options.NotifyTransparency then
			state.notifications = {
				ClipDescendants = Toggles.NotifyClipDescendants and Toggles.NotifyClipDescendants.Value,
				MaxHeight       = Options.NotifyMaxHeight and Options.NotifyMaxHeight.Value,
				PosX            = Options.NotifyPosX and Options.NotifyPosX.Value,
				PosY            = Options.NotifyPosY and Options.NotifyPosY.Value,
				Transparency    = Options.NotifyTransparency and Options.NotifyTransparency.Value,
				Alignment       = Options.NotifyAlignment and Options.NotifyAlignment.Value,
				BarSide         = Options.NotifyBarSide and Options.NotifyBarSide.Value,
				SortOrder       = Options.NotifySortOrder and Options.NotifySortOrder.Value,
			}
		end

		return state
	end

	function ThemeManager:ApplyTheme(theme)
		local customThemeData = self:GetCustomTheme(theme)
		local builtInTheme = self.BuiltInThemes[theme]
		local isBuiltIn = builtInTheme ~= nil and customThemeData == nil
		local data = self:NormalizeThemeData(customThemeData or (builtInTheme and builtInTheme[2]))

		if not data then return false end

		self.CurrentThemeName = theme
		self.CurrentThemeCustom = not isBuiltIn
		self.ApplyingTheme = true

		if self.Library and type(self.Library.SetMainWindowSize) == 'function' then
			local sw, sh
			if isBuiltIn then
				sw, sh = 500, 592
			elseif data.mainWindowSize then
				sw = tonumber(data.mainWindowSize.w)
				sh = tonumber(data.mainWindowSize.h)
			end
			if sw and sh then
				self.Library:SetMainWindowSize(sw, sh, true)
			end
		end

		for idx, col in next, data.colors do
			local parsed = Color3.fromHex(col)
			self.Library[idx] = parsed
			if Options[idx] then
				Options[idx]:SetValueRGB(parsed)
			end
		end

		if isBuiltIn then
			if Options.ThemeManager_Font then
				Options.ThemeManager_Font:SetValue(theme == 'Default' and 'arcade' or theme == 'Better UE' and 'tahoma' or 'code')
				Options.ThemeManager_Font:Display()
			end
		else
			if Options.ThemeManager_Font then
				local wantFont = string.lower(tostring(data.font or 'code'))
				Options.ThemeManager_Font:SetValue(wantFont)
				Options.ThemeManager_Font:Display()
			end
			if data.iconSize and Options.ThemeManager_IconSize then
				Options.ThemeManager_IconSize:SetValue(data.iconSize)
			end
			if data.uiScale and Options.ThemeManager_UIScale then
				Options.ThemeManager_UIScale:SetValue(data.uiScale)
			end
		end

		local caseKeys = {"CaseTabs","CaseSubTabs","CaseGroupboxes","CaseToggles","CaseButtons","CaseSliders","CaseDropdowns","CaseDDItems","CaseLabels","CaseInputs","CaseTooltip"}
		if data.caseSettings then
			for _, k in ipairs(caseKeys) do
				if Options[k] then Options[k]:SetValue(data.caseSettings[k] or "Capitalized") end
			end
		end

		if data.backgroundOpacity and Options.BackgroundOpacity then
			Options.BackgroundOpacity:SetValue(data.backgroundOpacity)
		end
		if data.blurOpacity and Options.BlurOpacity then
			Options.BlurOpacity:SetValue(data.blurOpacity)
		end
		if data.backgroundBlur ~= nil and Toggles.BackgroundBlur then
			Toggles.BackgroundBlur:SetValue(data.backgroundBlur)
		end
		if data.backgroundFrame ~= nil and Toggles.BackgroundFrame then
			Toggles.BackgroundFrame:SetValue(data.backgroundFrame)
		end

		if data.notifications then
			local n = data.notifications
			if n.ClipDescendants ~= nil and Toggles.NotifyClipDescendants then Toggles.NotifyClipDescendants:SetValue(n.ClipDescendants) end
			if n.MaxHeight ~= nil    and Options.NotifyMaxHeight    then Options.NotifyMaxHeight:SetValue(n.MaxHeight) end
			if n.PosX ~= nil         and Options.NotifyPosX         then Options.NotifyPosX:SetValue(n.PosX) end
			if n.PosY ~= nil         and Options.NotifyPosY         then Options.NotifyPosY:SetValue(n.PosY) end
			if n.Transparency ~= nil and Options.NotifyTransparency then Options.NotifyTransparency:SetValue(n.Transparency) end
			if n.Alignment ~= nil    and Options.NotifyAlignment    then Options.NotifyAlignment:SetValue(n.Alignment) end
			if n.BarSide ~= nil      and Options.NotifyBarSide      then Options.NotifyBarSide:SetValue(n.BarSide) end
			if n.SortOrder ~= nil    and Options.NotifySortOrder    then Options.NotifySortOrder:SetValue(n.SortOrder) end
		end

		self.ApplyingTheme = nil
		self:ThemeUpdate()
		return true
	end

	function ThemeManager:ThemeUpdate()
		for _, field in next, self.ColorFields do
			if Options and Options[field] then
				self.Library[field] = Options[field].Value
			end
		end

		if Options and Options.ThemeManager_Font then
			local fontName = Options.ThemeManager_Font.Value
			local fs       = self.Library.FontSystem
			local lname    = string.lower(tostring(fontName or ''))
			lname = (fs and fs.Aliases and fs.Aliases[lname]) or lname
			local builtinEnum = fs and fs.Builtin and fs.Builtin[lname]
			if builtinEnum then
				self.Library.Font          = builtinEnum
				self.Library.CustomFontFace = nil
			else
				local resolved = fs and fs.Resolve(fontName)
				self.Library.Font          = Enum.Font.Code
				self.Library.CustomFontFace = resolved
			end
		end

		if self.Library and type(self.Library.SetIconSize) == 'function' then
			self.Library:SetIconSize(Options and Options.ThemeManager_IconSize and Options.ThemeManager_IconSize.Value or self.Library.IconSize)
		end

		if self.Library and type(self.Library.SetUIScale) == 'function' then
			self.Library:SetUIScale(Options and Options.ThemeManager_UIScale and Options.ThemeManager_UIScale.Value or self.Library.UIScaleValue, true)
		end

		self.Library.AccentColorDark = self.Library:GetDarkerColor(self.Library.AccentColor);
		self.Library:UpdateColorsUsingRegistry()
	end

	function ThemeManager:LoadDefault()
		self.LoadingDefault = true

		local theme = self:ReadAutoloadName()
		if not (self.BuiltInThemes[theme] or self:GetCustomTheme(theme)) then
			theme = 'Default'
		end

		self:ApplyTheme(theme)

		if self.BuiltInThemes[theme] then
			if Options.ThemeManager_BuiltInThemeList then Options.ThemeManager_BuiltInThemeList:SetValue(theme) end
		else
			if Options.ThemeManager_CustomThemeList then Options.ThemeManager_CustomThemeList:SetValue(theme) end
		end

		self.LoadingDefault = nil
	end

	function ThemeManager:SaveDefault(theme, isCustom)
		local name = (type(theme) == 'string' and theme ~= '') and theme or self.CurrentThemeName or 'Default'
		self.CurrentThemeName = name
		self.CurrentThemeCustom = not self.BuiltInThemes[name]
		WriteAutoloadField('theme', name)
	end

	function ThemeManager:BuildThemeSections(gb, includeColorPickers)
		local function refreshAutoloadLabel(name)
			if ThemeManager.AutoloadLabel1 then ThemeManager.AutoloadLabel1:SetText('Autoload: ' .. name) end
			if ThemeManager.AutoloadLabel2 then ThemeManager.AutoloadLabel2:SetText('Autoload: ' .. name) end
		end

		if includeColorPickers then
			gb:AddLabel('Background color'):AddColorPicker('BackgroundColor', { Default = self.Library.BackgroundColor })
			gb:AddLabel('Main color'):AddColorPicker('MainColor', { Default = self.Library.MainColor })
			gb:AddLabel('Accent color'):AddColorPicker('AccentColor', { Default = self.Library.AccentColor })
			gb:AddLabel('Outline color'):AddColorPicker('OutlineColor', { Default = self.Library.OutlineColor })
			gb:AddLabel('Font color'):AddColorPicker('FontColor', { Default = self.Library.FontColor })
		end

		gb:AddDropdown('ThemeManager_Font', { Text = 'Font', Values = Library.FontSystem.AllNames(), Default = 'code' })
		if self.Library and self.Library.IsMobile then
			gb:AddSlider('ThemeManager_IconSize', { Text = 'Icon Size', Default = self.Library.IconSize or 20, Min = 12, Max = 32, Rounding = 0 })
		end

		gb:AddDropdown('ThemeManager_BuiltInThemeList', {
			Text     = 'Pre-Made Themes',
			Values   = self:GetBuiltInThemeNames(),
			Default  = 1,
		})
		gb:AddButton('Load', function()
			local val = Options.ThemeManager_BuiltInThemeList.Value
			if val and val ~= '' then self:ApplyTheme(val) end
		end):AddButton('Set as Autoload', function()
			local val = Options.ThemeManager_BuiltInThemeList.Value
			if val and val ~= '' then
				self:SaveDefault(val, false)
				refreshAutoloadLabel(val)
			end
		end)

		gb:AddInput('ThemeManager_CustomThemeName', { Text = 'Custom Theme Name' })
		gb:AddDropdown('ThemeManager_CustomThemeList', {
			Text     = 'Custom Themes',
			Values   = self:ReloadCustomThemes(),
			Default  = 1,
		})
		gb:AddButton('Save', function()
			local n = Options.ThemeManager_CustomThemeName.Value
			self:SaveCustomTheme(n)
			local list = self:ReloadCustomThemes()
			Options.ThemeManager_CustomThemeList.Values = list
			Options.ThemeManager_CustomThemeList:SetValues()
			Options.ThemeManager_CustomThemeList:SetValue(n)
		end):AddButton('Load', function()
			local val = Options.ThemeManager_CustomThemeList.Value
			if val and val ~= '' then
				if not self:ApplyTheme(val) then
					self.Library:Notify('Failed to load theme.', 3)
				end
			end
		end)
		gb:AddButton('Overwrite', function()
			local name = Options.ThemeManager_CustomThemeList.Value
			if not name or name == '' then return self.Library:Notify('No theme selected.', 2) end
			self:SaveCustomTheme(name)
		end):AddButton('Delete', function()
			local name = Options.ThemeManager_CustomThemeList.Value
			if not name or name == '' then return self.Library:Notify('No theme selected.', 2) end
			if not delfile or not isfile then return self.Library:Notify('Unsupported executor.', 2) end
			local path = self.Folder .. '/Themes/' .. name .. '.json'
			if not isfile(path) then return self.Library:Notify('Theme not found.', 2) end
			delfile(path)
			local list = self:ReloadCustomThemes()
			Options.ThemeManager_CustomThemeList.Values = list
			Options.ThemeManager_CustomThemeList:SetValues()
			Options.ThemeManager_CustomThemeList:SetValue(nil)
		end)
		gb:AddButton('Refresh', function()
			local list = self:ReloadCustomThemes()
			Options.ThemeManager_CustomThemeList.Values = list
			Options.ThemeManager_CustomThemeList:SetValues()
			Options.ThemeManager_CustomThemeList:SetValue(nil)
		end):AddButton('Set as Autoload', function()
			local val = Options.ThemeManager_CustomThemeList.Value
			if val and val ~= '' then
				self:SaveDefault(val, true)
				refreshAutoloadLabel(val)
			end
		end)
		gb:AddButton('Export', function()
			local ok, encoded = self:GetThemeJSON()
			if not ok then return self.Library:Notify('Invalid Theme.', 3) end
			self.Library:CreatePrompt({ Title = 'Export Theme', Mode = 'Export', Text = encoded })
		end):AddButton('Import', function()
			self.Library:CreatePrompt({
				Title     = 'Import Theme',
				Mode      = 'Import',
				Callback  = function(text, name)
					if name:gsub(' ', '') == '' then
						return self.Library:Notify('Name cannot be empty.', 2)
					end
					if not writefile then return self.Library:Notify('Unsupported executor.', 2) end
					local ok = pcall(Services.HttpService.JSONDecode, Services.HttpService, text)
					if not ok then return self.Library:Notify('Invalid Theme.', 2) end
					writefile(self.Folder .. '/Themes/' .. name .. '.json', text)
					local list = self:ReloadCustomThemes()
					Options.ThemeManager_CustomThemeList.Values = list
					Options.ThemeManager_CustomThemeList:SetValues()
					Options.ThemeManager_CustomThemeList:SetValue(name)
					self:ApplyTheme(name)
				end,
			})
		end)
	end

	function ThemeManager:ReadAutoloadName()
		local name = ReadAutoloadFile().theme
		if type(name) == 'string' and name ~= '' and name ~= 'none' then return name end
		return 'Default'
	end

	function ThemeManager:RegisterSharedCallbacks(gb)
		local function UpdateTheme() self:ThemeUpdate() end
		if Options.ThemeManager_Font then Options.ThemeManager_Font:OnChanged(UpdateTheme) end
		if Options.ThemeManager_IconSize then Options.ThemeManager_IconSize:OnChanged(UpdateTheme) end
		for _, f in ipairs({
			'BackgroundColor','MainColor','AccentColor','OutlineColor','FontColor',
		}) do
			if Options[f] then Options[f]:OnChanged(UpdateTheme) end
		end
	end

	function ThemeManager:CreateThemeManager(groupbox)
		self:BuildThemeSections(groupbox, true)
		ThemeManager.AutoloadLabel1 = groupbox:AddLabel('Autoload: ' .. self:ReadAutoloadName(), true)
		self:RegisterSharedCallbacks(groupbox)
		ThemeManager:LoadDefault()
	end

	function ThemeManager:ApplyToTabs(normalTab, settingsGroupbox)
		assert(self.Library, 'Must set ThemeManager.Library first!')

		normalTab:AddLabel('background'):AddColorPicker('BackgroundColor', { Title = 'background', Default = self.Library.BackgroundColor })
		normalTab:AddLabel('main color'):AddColorPicker('MainColor', { Title = 'main color', Default = self.Library.MainColor })
		normalTab:AddLabel('accent'):AddColorPicker('AccentColor', { Title = 'accent', Default = self.Library.AccentColor })
		normalTab:AddLabel('outline'):AddColorPicker('OutlineColor', { Title = 'outline', Default = self.Library.OutlineColor })
		normalTab:AddLabel('font color'):AddColorPicker('FontColor', { Title = 'font color', Default = self.Library.FontColor })

		normalTab:AddDivider()

		self:BuildThemeSections(settingsGroupbox, false)

		ThemeManager.AutoloadLabel2 = settingsGroupbox:AddLabel('Autoload: ' .. self:ReadAutoloadName(), true)

		self:RegisterSharedCallbacks(settingsGroupbox)
		ThemeManager:LoadDefault()
	end

	function ThemeManager:GetCustomTheme(file)
		if file == '__default' then
			return nil
		end
		local path = self.Folder .. '/Themes/' .. file .. '.json'
		if not isfile(path) then
			return nil
		end

		local data = readfile(path)
		local success, decoded = pcall(Services.HttpService.JSONDecode, Services.HttpService, data)

		if not success then
			return nil
		end

		return decoded
	end

	function ThemeManager:GetThemeJSON()
		local theme = {
			font      = Options.ThemeManager_Font and Options.ThemeManager_Font.Value or getFontName(self.Library.Font),
			iconSize  = tonumber(Options.ThemeManager_IconSize and Options.ThemeManager_IconSize.Value) or self.Library.IconSize or 20,
			uiScale   = tonumber(Options.ThemeManager_UIScale and Options.ThemeManager_UIScale.Value) or self.Library.UIScaleValue or 1.0,
			colors    = {},
		}
		if self.Library and type(self.Library.GetMainWindowSize) == 'function' then
			theme.mainWindowSize = self.Library:GetMainWindowSize()
		end

		for _, field in next, self.ColorFields do
			theme.colors[field] = Options[field].Value:ToHex()
		end

		local caseKeys = {"CaseTabs","CaseSubTabs","CaseGroupboxes","CaseToggles","CaseButtons","CaseSliders","CaseDropdowns","CaseDDItems","CaseLabels","CaseInputs","CaseTooltip"}
		theme.caseSettings = {}
		for _, k in ipairs(caseKeys) do
			if Options[k] then theme.caseSettings[k] = Options[k].Value end
		end
		theme.backgroundOpacity = tonumber(Options.BackgroundOpacity and Options.BackgroundOpacity.Value) or 10
		theme.blurOpacity       = tonumber(Options.BlurOpacity and Options.BlurOpacity.Value) or 75
		theme.backgroundBlur    = Toggles.BackgroundBlur and Toggles.BackgroundBlur.Value
		theme.backgroundFrame   = Toggles.BackgroundFrame and Toggles.BackgroundFrame.Value

		if Options.NotifyTransparency then
			theme.notifications = {
				ClipDescendants = Toggles.NotifyClipDescendants and Toggles.NotifyClipDescendants.Value,
				MaxHeight       = Options.NotifyMaxHeight and Options.NotifyMaxHeight.Value,
				PosX            = Options.NotifyPosX and Options.NotifyPosX.Value,
				PosY            = Options.NotifyPosY and Options.NotifyPosY.Value,
				Transparency    = Options.NotifyTransparency and Options.NotifyTransparency.Value,
				Alignment       = Options.NotifyAlignment and Options.NotifyAlignment.Value,
				BarSide         = Options.NotifyBarSide and Options.NotifyBarSide.Value,
				SortOrder       = Options.NotifySortOrder and Options.NotifySortOrder.Value,
			}
		end

		local ok, encoded = pcall(Services.HttpService.JSONEncode, Services.HttpService, theme)
        if not ok then return false end
        return true, encoded
	end

	function ThemeManager:SaveCustomTheme(file)
		if type(file) ~= 'string' or file:gsub(' ', '') == '' or file == '__default' then
			return self.Library:Notify('Name cannot be empty.', 3)
		end
		if not writefile then return self.Library:Notify('Unsupported executor.', 2) end

		local ok, encoded = self:GetThemeJSON()
		if not ok then return self.Library:Notify('Failed to save theme.', 3) end

		writefile(self.Folder .. '/Themes/' .. file .. '.json', encoded)
	end

	function ThemeManager:ReloadCustomThemes()
		local folder = self.Folder .. '/Themes'
		if not isfolder(folder) then return {} end
		local list = listfiles(folder)
		local out = {}
		for _, file in ipairs(list) do
			if type(file) == 'string' and file:sub(-5) == '.json' then
				local name = file:match"([^/\\]+)%.json$"
				if name and name ~= '' and name ~= '__default' then table.insert(out, name) end
			end
		end
		table.sort(out)
		return out
	end

	function ThemeManager:GetBuiltInThemeNames()
		local sorted = {}
		for name in next, self.BuiltInThemes do table.insert(sorted, name) end
		table.sort(sorted, function(a, b) return self.BuiltInThemes[a][1] < self.BuiltInThemes[b][1] end)
		return sorted
	end

	function ThemeManager:GetAllThemes()
		local out = {}
		for _, name in ipairs(self:GetBuiltInThemeNames()) do table.insert(out, name) end
		local custom = self:ReloadCustomThemes()
		for _, name in ipairs(custom) do
			if not self.BuiltInThemes[name] then
				table.insert(out, name)
			end
		end
		return out
	end

	function ThemeManager:SetLibrary(lib)
		self.Library = lib
		if lib then
			lib.ThemeManager = self
		end
	end

	function ThemeManager:PreApply(library, folder)
		if library then self.Library = library end
		if folder  then self.Folder  = folder  end
		if not self.Library then return end

		self:BuildFolderTree()

		local theme = self:ReadAutoloadName()
		if not (self.BuiltInThemes[theme] or self:GetCustomTheme(theme)) then
			theme = 'Default'
		end

		local customData = self:GetCustomTheme(theme)
		local builtIn    = self.BuiltInThemes[theme]
		local data       = self:NormalizeThemeData(customData or (builtIn and builtIn[2]))
		if not data then return end

		for idx, col in next, data.colors do
			local ok, parsed = pcall(Color3.fromHex, col)
			if ok then self.Library[idx] = parsed end
		end
		self.Library.AccentColorDark = self.Library:GetDarkerColor(self.Library.AccentColor)
		self.CurrentThemeName = theme
		self.CurrentThemeCustom = not self.BuiltInThemes[theme]
	end

	function ThemeManager:BuildFolderTree()
		local paths = {}

		local parts = self.Folder:split('/')
		for idx = 1, #parts do
			paths[#paths + 1] = table.concat(parts, '/', 1, idx)
		end

		table.insert(paths, self.Folder .. '/Themes')

		for i = 1, #paths do
			local str = paths[i]
			if not isfolder(str) then
				makefolder(str)
			end
		end

	end

	function ThemeManager:SetFolder(folder)
		self.Folder = folder
		self:BuildFolderTree()
	end

	function ThemeManager:CreateGroupBox(tab)
		assert(self.Library, 'Must set ThemeManager.Library first!')
		return tab:AddLeftGroupbox('Theme')
	end

	function ThemeManager:ApplyToTab(tab)
		assert(self.Library, 'Must set ThemeManager.Library first!')
		local groupbox = self:CreateGroupBox(tab)
		self:CreateThemeManager(groupbox)
	end

	function ThemeManager:ApplyToGroupbox(groupbox)
		assert(self.Library, 'Must set ThemeManager.Library first!')
		self:CreateThemeManager(groupbox)
	end

	ThemeManager:BuildFolderTree()
end

local SaveManager = {} do

SaveManager.Folder = 'Elite Zone/Rivals'
SaveManager.Ignore = {}
SaveManager.DynamicLists = {}
SaveManager.CustomData   = {}
SaveManager.SaveHooks    = {}
SaveManager.LoadHooks    = {}

function SaveManager.RegisterDynamicList(self, key, dl)
    self.DynamicLists[key] = dl
end

function SaveManager.RegisterCustomData(self, key, saveFn, loadFn)
    self.CustomData[key] = { save = saveFn, load = loadFn }
end

function SaveManager.RegisterSaveHook(self, fn) table.insert(self.SaveHooks, fn) end
function SaveManager.RegisterLoadHook(self, fn) table.insert(self.LoadHooks, fn) end

SaveManager.Parser = {
    Toggle = {
        Save = function(idx, object)
            return { type = 'Toggle', idx = idx, value = object.Value }
        end,
        Load = function(idx, data)
            if Toggles[idx] then Toggles[idx]:SetValue(data.value) end
        end,
    },
    Slider = {
        Save = function(idx, object)
            return { type = 'Slider', idx = idx, value = tostring(object.Value) }
        end,
        Load = function(idx, data)
            if Options[idx] then Options[idx]:SetValue(data.value) end
        end,
    },
    Dropdown = {
        Save = function(idx, object)
            return { type = 'Dropdown', idx = idx, value = object.Value, multi = object.Multi }
        end,
        Load = function(idx, data)
            if Options[idx] then Options[idx]:SetValue(data.value) end
        end,
    },
    ColorPicker = {
        Save = function(idx, object)
            return { type = 'ColorPicker', idx = idx, value = object.Value:ToHex(), transparency = object.Transparency }
        end,
        Load = function(idx, data)
            if Options[idx] then Options[idx]:SetValueRGB(Color3.fromHex(data.value), data.transparency) end
        end,
    },
    KeyPicker = {
        Save = function(idx, object)
            return { type = 'KeyPicker', idx = idx, mode = object.Mode, key = object.Value }
        end,
        Load = function(idx, data)
            if Options[idx] then Options[idx]:SetValue{ data.key, data.mode } end
        end,
    },
    Input = {
        Save = function(idx, object)
            return { type = 'Input', idx = idx, text = object.Value }
        end,
        Load = function(idx, data)
            if Options[idx] and type(data.text) == 'string' then Options[idx]:SetValue(data.text) end
        end,
    },
    GradientColorPicker = {
        Save = function(idx, object)
            local vals, transes = {}, {}
            for i = 1, 3 do
                vals[i]   = object.Values[i]:ToHex()
                transes[i] = object.Transparencies[i]
            end
            return { type = 'GradientColorPicker', idx = idx, values = vals, transparencies = transes }
        end,
        Load = function(idx, data)
            if not Options[idx] then return end
            if type(data.values) ~= 'table' or #data.values ~= 3 then return end
            local vals, transes = {}, {}
            for i = 1, 3 do
                vals[i]   = Color3.fromHex(data.values[i])
                transes[i] = tonumber(data.transparencies and data.transparencies[i]) or 0
            end
            Options[idx]:SetValues(vals, transes)
        end,
    },
    CaseRow = {
        Save = function(idx, object)
            return { type = 'CaseRow', idx = idx, value = object.Value }
        end,
        Load = function(idx, data)
            if Options[idx] and type(data.value) == 'string' then Options[idx]:SetValue(data.value) end
        end,
    },
}

function SaveManager.BuildFolderTree(self)
    if not isfolder then return end
    local paths = {
        'Elite Zone',
        'Elite Zone/Assets',
        'Elite Zone/Rivals',
        'Elite Zone/Rivals/Settings',
        'Elite Zone/Rivals/Themes',
    }
    for _, path in ipairs(paths) do
        if not isfolder(path) then makefolder(path) end
    end
end

function SaveManager.SetIgnoreIndexes(self, list)
    for _, key in next, list do self.Ignore[key] = true end
end

function SaveManager.IgnoreThemeSettings(self)
    self:SetIgnoreIndexes{
        'BackgroundColor', 'MainColor', 'AccentColor', 'OutlineColor', 'FontColor',
        'ThemeManager_Font', 'ThemeManager_IconSize', 'ThemeManager_UIScale',
        'ThemeManager_ThemeList', 'ThemeManager_CustomThemeList', 'ThemeManager_CustomThemeName',
        'MenuBind',
        'SaveManager_ConfigList', 'SaveManager_ConfigName',
        'CaseTabs', 'CaseSubTabs', 'CaseGroupboxes', 'CaseToggles', 'CaseButtons',
        'CaseSliders', 'CaseDropdowns', 'CaseDDItems', 'CaseLabels', 'CaseInputs', 'CaseTooltip',
        'BackgroundOpacity', 'BlurOpacity', 'BackgroundBlur', 'BackgroundFrame',
        'EzLogo', 'EzLogoTransparency', 'EzLogoPosX', 'EzLogoPosY', 'EzLogoMaterial', 'EzLogoSize',
        'EzLogoColor', 'EzLogoFatness', 'EzLogoSpeed',
        'NotifyClipDescendants', 'NotifyMaxHeight', 'NotifyPosX', 'NotifyPosY',
        'NotifyTransparency', 'NotifyAlignment', 'NotifyBarSide', 'NotifySortOrder',
    }
end

function SaveManager.SetFolder(self, folder)
    self.Folder = folder
    self:BuildFolderTree()
end

function SaveManager.SetLibrary(self, library)
    self.Library = library
end

function SaveManager.GetConfigJSON(self)
    local data = { objects = {} }

    for idx, toggle in next, Toggles do
        if self.Ignore[idx] then continue end
        local ok, entry = pcall(self.Parser.Toggle.Save, idx, toggle)
        if ok then table.insert(data.objects, entry) end
    end

    for idx, option in next, Options do
        if self.Ignore[idx] then continue end
        if not self.Parser[option.Type] then continue end
        local ok, entry = pcall(self.Parser[option.Type].Save, idx, option)
        if ok then table.insert(data.objects, entry) end
    end

    local dlData = {}
    for key, dl in next, self.DynamicLists do
        local entries = dl:GetEntries()
        local out = {}
        local isTextOnly = dl.TextOnly
        for _, e in ipairs(entries) do
            if type(e) == "table" and e.textVal ~= nil then
                out[#out+1] = isTextOnly and e.textVal or {text=e.textVal, chance=tonumber(e.chanceVal) or 50}
            else
                out[#out+1] = tostring(e)
            end
        end
        dlData[key] = out
    end
    data.dynamicLists = dlData

    local cdData = {}
    for key, cd in next, self.CustomData do
        local ok, val = pcall(cd.save)
        if ok then cdData[key] = val end
    end
    data.customData = cdData

    for _, h in ipairs(self.SaveHooks) do pcall(h, data) end

    local ok, encoded = pcall(Services.HttpService.JSONEncode, Services.HttpService, data)
    if not ok then return false end
    return true, encoded
end

function SaveManager.Save(self, name)
    if not writefile then self.Library:Notify('Unsupported executor.', 2) return false end
    if not name or name:gsub(' ', '') == '' then self.Library:Notify('Name cannot be empty.', 2) return false end

    local ok, encoded = self:GetConfigJSON()
    if not ok then return false end

    writefile('Elite Zone/Rivals/Settings/' .. name .. '.json', encoded)
    return true
end

function SaveManager.LoadConfigJSON(self, jsonString)
    local ok, decoded = pcall(Services.HttpService.JSONDecode, Services.HttpService, jsonString)
    if not ok then return false end

    local toggles = {}
    for _, option in next, decoded.objects do
        if self.Parser[option.type] then
            if option.type == 'Toggle' then
                toggles[#toggles + 1] = option
            else
                pcall(self.Parser[option.type].Load, option.idx, option)
            end
        end
    end

    if decoded.dynamicLists then
        for key, entries in next, decoded.dynamicLists do
            local dl = self.DynamicLists[key]
            if dl and type(entries) == "table" then
                pcall(function() dl:SetEntries(entries) end)
            end
        end
    end

    if decoded.customData then
        for key, val in next, decoded.customData do
            local cd = self.CustomData[key]
            if cd then
                pcall(cd.load, val)
            end
        end
    end

    task.spawn(function()
        local BATCH = 3
        for i = 1, #toggles do
            local option = toggles[i]
            pcall(self.Parser[option.type].Load, option.idx, option)
            if i % BATCH == 0 then task.wait() end
        end
    end)

    for _, h in ipairs(self.LoadHooks) do pcall(h, decoded) end

    return true
end

function SaveManager.Load(self, name)
    if not readfile then self.Library:Notify('Unsupported executor.', 2) return false end
    if not name then self.Library:Notify('Name cannot be empty.', 2) return false end

    local file = 'Elite Zone/Rivals/Settings/' .. name .. '.json'
    if not isfile(file) then self.Library:Notify('Config not found.', 2) return false end

    return self:LoadConfigJSON(readfile(file))
end

function SaveManager.RefreshConfigList(self)
    local folder = 'Elite Zone/Rivals/Settings'
    if not isfolder(folder) then return {} end
    local list = listfiles(folder)
    local out = {}
    for _, file in ipairs(list) do
        if type(file) == 'string' and file:sub(-5) == '.json' then
            local name = file:match"([^/\\]+)%.json$"
            if name and name ~= '' then table.insert(out, name) end
        end
    end
    return out
end

function SaveManager.LoadAutoloadConfig(self)
    local name = ReadAutoloadFile().config
    if type(name) == 'string' and name ~= '' and name ~= 'none' then
        local ok, err = self:Load(name)
        if not ok then
            if self.Library then warn('[Elite Zone] Autoload failed: ' .. err) end
            return
        end
    end
end

function SaveManager.GetAutoloadName(self)
    local name = ReadAutoloadFile().config
    if type(name) == 'string' and name ~= '' and name ~= 'none' then return name end
    return nil
end

function SaveManager.SetAutoloadName(self, name)
    WriteAutoloadField('config', name)
end

function SaveManager.BuildConfigSection(self, tabOrGroupbox)
    assert(self.Library, 'SaveManager: call SetLibrary before BuildConfigSection')

    local section
    if type(tabOrGroupbox.AddLeftGroupbox) == 'function' then
        section = tabOrGroupbox:AddLeftGroupbox('Gameplay Configs')
    elseif type(tabOrGroupbox.AddInput) == 'function' then
        section = tabOrGroupbox
    else
        error'BuildConfigSection: expected a Tab or Groupbox'
    end

    section:AddInput('SaveManager_ConfigName', { Text = 'Config Name' })
    section:AddDropdown('SaveManager_ConfigList', { Text = 'Configs', Values = self:RefreshConfigList(), AllowNull = true })

    section:AddButton('Save', function()
        local name = Options.SaveManager_ConfigName.Value
        if name:gsub(' ', '') == '' then return self.Library:Notify('Name cannot be empty.', 2) end
        local ok, err = self:Save(name)
        if not ok then return self.Library:Notify('Failed to save config.', 3) end
        Options.SaveManager_ConfigList.Values = self:RefreshConfigList()
        Options.SaveManager_ConfigList:SetValues()
        Options.SaveManager_ConfigList:SetValue(nil)
    end):AddButton('Load', function()
        local name = Options.SaveManager_ConfigList.Value
        if not name then return self.Library:Notify('No config selected.', 2) end
        local ok, err = self:Load(name)
        if not ok then return self.Library:Notify('Failed to load config.', 3) end
    end)

    section:AddButton('Overwrite', function()
        local name = Options.SaveManager_ConfigList.Value
        if not name then return self.Library:Notify('No config selected.', 2) end
        local ok, err = self:Save(name)
        if not ok then return self.Library:Notify('Failed to save config.', 3) end
    end):AddButton('Delete', function()
        local name = Options.SaveManager_ConfigList.Value
        if not name then return self.Library:Notify('No config selected.', 2) end
        self.Library:CreatePrompt({
            Title = "Delete Config",
            Mode = "Confirm",
            Text = 'Are you sure you want to delete "' .. name .. '"?',
            Callback = function()
                local path = 'Elite Zone/Rivals/Settings/' .. name .. '.json'
                if isfile(path) then
                    delfile(path)
                    Options.SaveManager_ConfigList.Values = self:RefreshConfigList()
                    Options.SaveManager_ConfigList:SetValues()
                    Options.SaveManager_ConfigList:SetValue(nil)
                end
            end
        })
    end)

    section:AddButton('Refresh', function()
        Options.SaveManager_ConfigList.Values = self:RefreshConfigList()
        Options.SaveManager_ConfigList:SetValues()
        Options.SaveManager_ConfigList:SetValue(nil)
    end):AddButton('Set as Autoload', function()
        local name = Options.SaveManager_ConfigList.Value
        if not name then return self.Library:Notify('No config selected.', 2) end
        WriteAutoloadField('config', name)
        if SaveManager.AutoloadLabel then SaveManager.AutoloadLabel:SetText('Autoload: ' .. name) end
    end)


    section:AddButton('Export', function()
        local ok, encoded = self:GetConfigJSON()
        if not ok then return self.Library:Notify('Invalid Config.', 3) end
        self.Library:CreatePrompt({
            Title = "Export Config",
            Mode = "Export",
            Text = encoded,
        })
    end):AddButton('Import', function()
        self.Library:CreatePrompt({
            Title = "Import Config",
            Mode = "Import",
            Callback = function(text, name)
                if name:gsub(' ', '') == '' then
                    return self.Library:Notify('Name cannot be empty.', 2)
                end
                local ok, err = self:LoadConfigJSON(text)
                if not ok then
                    return self.Library:Notify('Invalid Config.', 2)
                end
                self:Save(name)
                Options.SaveManager_ConfigList.Values = self:RefreshConfigList()
                Options.SaveManager_ConfigList:SetValues()
                Options.SaveManager_ConfigList:SetValue(nil)
            end
        })
    end)

    local autoName = '__autosave'
    local savedConfig = ReadAutoloadFile().config
    if type(savedConfig) == 'string' and savedConfig ~= '' and savedConfig ~= 'none' then
        autoName = savedConfig
    end
    SaveManager.AutoloadLabel = section:AddLabel('Autoload: ' .. autoName, true)

    self:SetIgnoreIndexes{ 'SaveManager_ConfigList', 'SaveManager_ConfigName' }
end

SaveManager:BuildFolderTree()
end

Library.SaveManager = SaveManager
Library.ThemeManager = ThemeManager

return {
    Library      = Library;
    ThemeManager = ThemeManager;
    SaveManager  = SaveManager;
}
end)()
