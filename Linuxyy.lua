local NovaLib = {}
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local function New(class, props)
    local obj = Instance.new(class)
    for prop, value in pairs(props or {}) do
        if prop ~= "Parent" then
            obj[prop] = value
        end
    end
    if props and props.Parent then
        obj.Parent = props.Parent
    end
    return obj
end

function NovaLib:NovaJanela(config)
    local ScreenGui = New("ScreenGui", {Parent = Players.LocalPlayer:WaitForChild("PlayerGui"), ResetOnSpawn = false})
    
    local Janela = New("Frame", {
        Size = config.Tamanho or UDim2.fromOffset(550, 350),
        Position = UDim2.new(0.5, -275, 0.5, -175),
        BackgroundColor3 = Color3.fromRGB(25, 25, 25),
        BorderSizePixel = 0,
        Active = true,
        Draggable = true,
        Parent = ScreenGui
    })
    New("UICorner", {CornerRadius = UDim.new(0, 8), Parent = Janela})
    
    local Topo = New("Frame", {
        Size = UDim2.new(1, 0, 0, 35),
        BackgroundColor3 = Color3.fromRGB(30, 30, 30),
        BorderSizePixel = 0,
        Parent = Janela
    })
    New("UICorner", {CornerRadius = UDim.new(0, 8), Parent = Topo})
    
    New("TextLabel", {
        Size = UDim2.new(1, -15, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1,
        Text = config.Nome or "NovaLib",
        TextColor3 = Color3.fromRGB(230, 230, 230),
        TextSize = 15,
        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = Topo
    })
    
    local AbasHolder = New("ScrollingFrame", {
        Size = UDim2.new(0, 110, 1, -45),
        Position = UDim2.new(0, 10, 0, 45),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        Parent = Janela
    })
    
    local ConteudoHolder = New("ScrollingFrame", {
        Size = UDim2.new(1, -125, 1, -45),
        Position = UDim2.new(0, 125, 0, 45),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Color3.fromRGB(255, 255, 255),
        ScrollBarImageTransparency = 0.9,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        Parent = Janela
    })
    New("UIPadding", {PaddingRight = UDim.new(0, 8), PaddingLeft = UDim.new(0, 2), PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 2), Parent = ConteudoHolder})
    
    local Window = {Abas = {}, Conteudos = {}, AbaSelecionada = 0, TotalAbas = 0, Janela = Janela, AbasHolder = AbasHolder, ConteudoHolder = ConteudoHolder}
    
    function Window:NovaAba(config)
        self.TotalAbas = self.TotalAbas + 1
        local AbaIndex = self.TotalAbas
        
        local Aba = {Nome = config.Nome}
        
        Aba.Botao = New("TextButton", {
            Size = UDim2.new(1, -5, 0, 32),
            BackgroundColor3 = Color3.fromRGB(35, 35, 35),
            Text = config.Nome,
            TextColor3 = Color3.fromRGB(230, 230, 230),
            TextSize = 13,
            FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json"),
            TextXAlignment = Enum.TextXAlignment.Left,
            Position = UDim2.new(0, 5, 0, (AbaIndex - 1) * 38),
            Parent = AbasHolder
        })
        New("UICorner", {CornerRadius = UDim.new(0, 6), Parent = Aba.Botao})
        
        local ConteudoLayout = New("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder})
        Aba.Conteudo = New("ScrollingFrame", {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            Parent = ConteudoHolder,
            Visible = false,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Color3.fromRGB(255, 255, 255),
            ScrollBarImageTransparency = 0.9,
            CanvasSize = UDim2.new(0, 0, 0, 0)
        }, {ConteudoLayout, New("UIPadding", {PaddingRight = UDim.new(0, 8), PaddingLeft = UDim.new(0, 2), PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 2)})})
        
        ConteudoLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            Aba.Conteudo.CanvasSize = UDim2.new(0, 0, 0, ConteudoLayout.AbsoluteContentSize.Y + 4)
        end)
        
        Aba.Botao.MouseButton1Click:Connect(function()
            self:SelecionarAba(AbaIndex)
        end)
        
        self.Abas[AbaIndex] = Aba
        self.Conteudos[AbaIndex] = Aba.Conteudo
        AbasHolder.CanvasSize = UDim2.new(0, 0, 0, self.TotalAbas * 38)
        
        if AbaIndex == 1 then self:SelecionarAba(1) end
        
        function Aba:NovaSecao(titulo)
            local SecaoFrame = New("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 25), Parent = Aba.Conteudo})
            local SecaoLayout = New("UIListLayout", {Padding = UDim.new(0, 6), Parent = SecaoFrame})
            local SecaoConteudo = New("Frame", {Size = UDim2.new(1, 0, 0, 25), Position = UDim2.fromOffset(0, 25), BackgroundTransparency = 1, Parent = SecaoFrame}, {SecaoLayout})
            New("TextLabel", {Text = titulo, TextColor3 = Color3.fromRGB(230, 230, 230), TextSize = 17, FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.SemiBold), TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -15, 0, 17), Position = UDim2.fromOffset(0, 2), BackgroundTransparency = 1, Parent = SecaoFrame})
            
            SecaoLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                SecaoConteudo.Size = UDim2.new(1, 0, 0, SecaoLayout.AbsoluteContentSize.Y)
                SecaoFrame.Size = UDim2.new(1, 0, 0, SecaoLayout.AbsoluteContentSize.Y + 25)
            end)
            
            local Secao = {Conteudo = SecaoConteudo}
            
            function Secao:NovoToggle(config)
                local ToggleFrame = New("Frame", {
                    Size = UDim2.new(1, -10, 0, 38),
                    Position = UDim2.new(0, 5, 0, #SecaoConteudo:GetChildren() * 44),
                    BackgroundColor3 = Color3.fromRGB(40, 40, 40),
                    Parent = SecaoConteudo
                })
                New("UICorner", {CornerRadius = UDim.new(0, 6), Parent = ToggleFrame})
                
                New("TextLabel", {
                    Text = config.Nome,
                    TextColor3 = Color3.fromRGB(230, 230, 230),
                    TextSize = 13,
                    FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json"),
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Size = UDim2.new(1, -55, 1, 0),
                    Position = UDim2.new(0, 8, 0, 0),
                    BackgroundTransparency = 1,
                    Parent = ToggleFrame
                })
                
                local Switch = New("Frame", {
                    Size = UDim2.new(0, 38, 0, 18),
                    Position = UDim2.new(1, -45, 0.5, -9),
                    BackgroundColor3 = config.Default and Color3.fromRGB(100, 200, 255) or Color3.fromRGB(50, 50, 50),
                    Parent = ToggleFrame
                })
                New("UICorner", {CornerRadius = UDim.new(0, 9), Parent = Switch})
                
                local Knob = New("Frame", {
                    Size = UDim2.new(0, 14, 0, 14),
                    Position = config.Default and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7),
                    BackgroundColor3 = Color3.fromRGB(230, 230, 230),
                    Parent = Switch
                })
                New("UICorner", {CornerRadius = UDim.new(0, 7), Parent = Knob})
                
                local estado = config.Default or false
                Switch.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        estado = not estado
                        TweenService:Create(Knob, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {Position = estado and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)}):Play()
                        TweenService:Create(Switch, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {BackgroundColor3 = estado and Color3.fromRGB(100, 200, 255) or Color3.fromRGB(50, 50, 50)}):Play()
                        config.Callback(estado)
                    end
                end)
                
                SecaoConteudo.Size = UDim2.new(1, 0, 0, SecaoConteudo.Size.Y.Offset + 44)
            end
            
            function Secao:NovoDropdown(config)
                local DropdownFrame = New("Frame", {
                    Size = UDim2.new(1, -10, 0, 38),
                    Position = UDim2.new(0, 5, 0, #SecaoConteudo:GetChildren() * 44),
                    BackgroundColor3 = Color3.fromRGB(40, 40, 40),
                    Parent = SecaoConteudo
                })
                New("UICorner", {CornerRadius = UDim.new(0, 6), Parent = DropdownFrame})
                
                New("TextLabel", {
                    Text = config.Nome,
                    TextColor3 = Color3.fromRGB(230, 230, 230),
                    TextSize = 13,
                    FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json"),
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Size = UDim2.new(1, -155, 1, 0),
                    Position = UDim2.new(0, 8, 0, 0),
                    BackgroundTransparency = 1,
                    Parent = DropdownFrame
                })
                
                local DropdownBtn = New("TextButton", {
                    Size = UDim2.fromOffset(145, 28),
                    Position = UDim2.new(1, -150, 0.5, -14),
                    BackgroundColor3 = Color3.fromRGB(50, 50, 50),
                    Text = config.Default or config.Valores[1],
                    TextColor3 = Color3.fromRGB(230, 230, 230),
                    TextSize = 12,
                    FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json"),
                    Parent = DropdownFrame
                })
                New("UICorner", {CornerRadius = UDim.new(0, 5), Parent = DropdownBtn})
                New("ImageLabel", {Image = "rbxassetid://10709790948", Size = UDim2.fromOffset(14, 14), Position = UDim2.new(1, -20, 0.5, -7), AnchorPoint = Vector2.new(0, 0.5), BackgroundTransparency = 1, ImageColor3 = Color3.fromRGB(150, 150, 150), Parent = DropdownBtn})
                
                local DropdownHolder = New("Frame", {Size = UDim2.fromOffset(145, 0), BackgroundColor3 = Color3.fromRGB(45, 45, 45), Parent = ScreenGui, Visible = false})
                New("UICorner", {CornerRadius = UDim.new(0, 6), Parent = DropdownHolder})
                
                local DropdownScroll = New("ScrollingFrame", {
                    Size = UDim2.new(1, -5, 1, -8),
                    Position = UDim2.fromOffset(4, 4),
                    BackgroundTransparency = 1,
                    ScrollBarThickness = 3,
                    ScrollBarImageColor3 = Color3.fromRGB(255, 255, 255),
                    ScrollBarImageTransparency = 0.9,
                    CanvasSize = UDim2.fromScale(0, 0),
                    Parent = DropdownHolder
                })
                local DropdownLayout = New("UIListLayout", {Padding = UDim.new(0, 4), Parent = DropdownScroll})
                
                local Dropdown = {Valores = config.Valores, Valor = config.Default or config.Valores[1], Aberto = false, Botoes = {}}
                
                local function AtualizarPosicao()
                    local posY = DropdownBtn.AbsolutePosition.Y + 30
                    if game.Workspace.CurrentCamera.ViewportSize.Y - posY < 200 then
                        posY = DropdownBtn.AbsolutePosition.Y - 200
                    end
                    DropdownHolder.Position = UDim2.fromOffset(DropdownBtn.AbsolutePosition.X, posY)
                end
                DropdownBtn:GetPropertyChangedSignal("AbsolutePosition"):Connect(AtualizarPosicao)
                
                local function ConstruirLista()
                    for _, child in pairs(DropdownScroll:GetChildren()) do
                        if not child:IsA("UIListLayout") then child:Destroy() end
                    end
                    
                    for _, valor in pairs(Dropdown.Valores) do
                        local Btn = New("TextButton", {
                            Size = UDim2.new(1, -5, 0, 28),
                            BackgroundColor3 = Dropdown.Valor == valor and Color3.fromRGB(60, 60, 60) or Color3.fromRGB(50, 50, 50),
                            Text = valor,
                            TextColor3 = Color3.fromRGB(230, 230, 230),
                            TextSize = 12,
                            FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json"),
                            Parent = DropdownScroll
                        })
                        New("UICorner", {CornerRadius = UDim.new(0, 4), Parent = Btn})
                        
                        Btn.MouseButton1Click:Connect(function()
                            Dropdown.Valor = valor
                            DropdownBtn.Text = valor
                            for _, b in pairs(Dropdown.Botoes) do b.BackgroundColor3 = Color3.fromRGB(50, 50, 50) end
                            Btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                            Dropdown:Fechar()
                            config.Callback(valor)
                        end)
                        
                        Dropdown.Botoes[Btn] = Btn
                    end
                    
                    DropdownScroll.CanvasSize = UDim2.fromOffset(0, DropdownLayout.AbsoluteContentSize.Y)
                    DropdownHolder.Size = UDim2.fromOffset(145, math.min(DropdownLayout.AbsoluteContentSize.Y + 8, 200))
                    AtualizarPosicao()
                end
                
                Dropdown.Abrir = function()
                    Dropdown.Aberto = true
                    DropdownHolder.Visible = true
                    TweenService:Create(DropdownHolder, TweenInfo.new(0.2, Enum.EasingStyle.Quart), {Size = UDim2.fromOffset(145, math.min(DropdownLayout.AbsoluteContentSize.Y + 8, 200))}):Play()
                end
                
                Dropdown.Fechar = function()
                    Dropdown.Aberto = false
                    TweenService:Create(DropdownHolder, TweenInfo.new(0.2, Enum.EasingStyle.Quart), {Size = UDim2.fromOffset(145, 0)}):Play()
                    task.wait(0.2)
                    DropdownHolder.Visible = false
                end
                
                DropdownBtn.MouseButton1Click:Connect(function()
                    if Dropdown.Aberto then Dropdown:Fechar() else Dropdown:Abrir() end
                end)
                
                UserInputService.InputBegan:Connect(function(input)
                    if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and Dropdown.Aberto then
                        local mouse = Players.LocalPlayer:GetMouse()
                        local pos, size = DropdownHolder.AbsolutePosition, DropdownHolder.AbsoluteSize
                        if mouse.X < pos.X or mouse.X > pos.X + size.X or mouse.Y < pos.Y or mouse.Y > pos.Y + size.Y then
                            Dropdown:Fechar()
                        end
                    end
                end)
                
                ConstruirLista()
                SecaoConteudo.Size = UDim2.new(1, 0, 0, SecaoConteudo.Size.Y.Offset + 44)
            end
            
            function Secao:NovoTextbox(config)
                local TextboxFrame = New("Frame", {
                    Size = UDim2.new(1, -10, 0, 38),
                    Position = UDim2.new(0, 5, 0, #SecaoConteudo:GetChildren() * 44),
                    BackgroundColor3 = Color3.fromRGB(40, 40, 40),
                    Parent = SecaoConteudo
                })
                New("UICorner", {CornerRadius = UDim.new(0, 6), Parent = TextboxFrame})
                
                New("TextLabel", {
                    Text = config.Nome,
                    TextColor3 = Color3.fromRGB(230, 230, 230),
                    TextSize = 13,
                    FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json"),
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Size = UDim2.new(1, -155, 1, 0),
                    Position = UDim2.new(0, 8, 0, 0),
                    BackgroundTransparency = 1,
                    Parent = TextboxFrame
                })
                
                local Textbox = New("TextBox", {
                    Size = UDim2.fromOffset(145, 28),
                    Position = UDim2.new(1, -150, 0.5, -14),
                    BackgroundColor3 = Color3.fromRGB(50, 50, 50),
                    Text = "",
                    TextColor3 = Color3.fromRGB(230, 230, 230),
                    TextSize = 12,
                    FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json"),
                    ClearTextOnFocus = false,
                    Parent = TextboxFrame
                })
                New("UICorner", {CornerRadius = UDim.new(0, 5), Parent = Textbox})
                
                Textbox:GetPropertyChangedSignal("Text"):Connect(function()
                    local maxChars = 18
                    if #Textbox.Text > maxChars then
                        Textbox.Text = Textbox.Text:sub(#Textbox.Text - maxChars + 1, #Textbox.Text)
                    end
                end)
                
                Textbox.FocusLost:Connect(function()
                    config.Callback(Textbox.Text)
                end)
                
                SecaoConteudo.Size = UDim2.new(1, 0, 0, SecaoConteudo.Size.Y.Offset + 44)
            end
            
            return Secao
        end
        
        return Aba
    end
    
    function Window:SelecionarAba(index)
        local aba = self.Abas[index]
        if not aba then return end
        
        self.AbaSelecionada = index
        for _, a in pairs(self.Abas) do
            a.Botao.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        end
        aba.Botao.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        
        for _, c in pairs(self.Conteudos) do c.Visible = false end
        self.Conteudos[index].Visible = true
    end
    
    return Window
end

return NovaLib
