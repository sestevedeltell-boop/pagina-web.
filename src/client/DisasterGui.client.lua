-- DisasterGui: efectos de pantalla de los desastres (aviso, temblor, destello de rayo, tinte).
-- Recibe del servidor: ("banner", titulo, descripcion, segundosHastaEmpezar), ("shake", intensidad, segundos),
-- ("flash"), ("tint", color, transparencia) y ("clear").

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local DisasterFX = ReplicatedStorage:WaitForChild("IslasRemotes"):WaitForChild("DisasterFX")
local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "DesastresGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 5
gui.Parent = player:WaitForChild("PlayerGui")

-- capa de color (lluvia acida, destellos)
local overlay = Instance.new("Frame")
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundTransparency = 1
overlay.BorderSizePixel = 0
overlay.Active = false
overlay.Parent = gui

-- cartel de aviso
local banner = Instance.new("Frame")
banner.Size = UDim2.new(0, 520, 0, 110)
banner.Position = UDim2.new(0.5, -260, 0, 70)
banner.BackgroundColor3 = Color3.fromRGB(120, 20, 20)
banner.BackgroundTransparency = 0.15
banner.Visible = false
banner.Parent = gui
Instance.new("UICorner", banner).CornerRadius = UDim.new(0, 14)

local bannerTitle = Instance.new("TextLabel")
bannerTitle.Size = UDim2.new(1, -20, 0, 44)
bannerTitle.Position = UDim2.new(0, 10, 0, 8)
bannerTitle.BackgroundTransparency = 1
bannerTitle.Font = Enum.Font.GothamBlack
bannerTitle.TextSize = 32
bannerTitle.TextColor3 = Color3.fromRGB(255, 230, 120)
bannerTitle.Parent = banner

local bannerDesc = Instance.new("TextLabel")
bannerDesc.Size = UDim2.new(1, -24, 0, 50)
bannerDesc.Position = UDim2.new(0, 12, 0, 52)
bannerDesc.BackgroundTransparency = 1
bannerDesc.Font = Enum.Font.GothamMedium
bannerDesc.TextSize = 17
bannerDesc.TextWrapped = true
bannerDesc.TextColor3 = Color3.new(1, 1, 1)
bannerDesc.Parent = banner

local bannerToken = 0
local function showBanner(title, desc, delay)
	bannerToken = bannerToken + 1
	local token = bannerToken
	bannerTitle.Text = "¡" .. title .. "!"
	bannerDesc.Text = desc .. (delay and delay > 0 and ("  (empieza en " .. delay .. "s)") or "")
	banner.Visible = true
	task.delay((delay or 0) + 6, function()
		if token == bannerToken then
			banner.Visible = false
		end
	end)
end

-- temblor de camara: mueve el offset de la camara del humanoide
local shakeIntensity, shakeEnd = 0, 0
RunService.RenderStepped:Connect(function()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	if shakeIntensity > 0 and os.clock() < shakeEnd then
		hum.CameraOffset = Vector3.new(
			(math.random() - 0.5) * shakeIntensity,
			(math.random() - 0.5) * shakeIntensity,
			0
		)
	elseif hum.CameraOffset ~= Vector3.zero then
		hum.CameraOffset = Vector3.zero
		shakeIntensity = 0
	end
end)

DisasterFX.OnClientEvent:Connect(function(kind, a, b, c)
	if kind == "banner" then
		showBanner(a, b, c)
	elseif kind == "shake" then
		shakeIntensity, shakeEnd = a, os.clock() + b
	elseif kind == "flash" then
		overlay.BackgroundColor3 = Color3.new(1, 1, 1)
		overlay.BackgroundTransparency = 0.2
		TweenService:Create(overlay, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
	elseif kind == "tint" then
		overlay.BackgroundColor3 = a
		overlay.BackgroundTransparency = b
	elseif kind == "clear" then
		shakeIntensity = 0
		overlay.BackgroundTransparency = 1
		banner.Visible = false
	end
end)
