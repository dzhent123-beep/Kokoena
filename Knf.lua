-- luxxs | knife duels
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")

local LP = Players.LocalPlayer
local KEY = "KNF-DLS1488"
local ICON_ASSET = "" -- rbxassetid://... for the icon, empty = "L" text
local CFG_DIR = "LuXxS"

local guiParent = (gethui and gethui()) or CoreGui

local BG = Color3.fromRGB(15, 15, 18)
local ROW = Color3.fromRGB(25, 25, 30)
local TXT = Color3.fromRGB(228, 228, 234)
local DIM = Color3.fromRGB(120, 120, 130)

local function hsv(c) return Color3.fromHSV(c.h, 1, 1) end
local function op(c) return 1 - c.t end

local cfg = {
	menu = {w = 460, ratio = "16:9", color = {h = 0, t = 0}},
	aim = {on = false, smooth = 6, fov = 120, fovShow = true, fovColor = {h = 0, t = 0.4}, bone = "Head"},
	anti = {mode = "Off"},
	kill = {on = false, range = 60},
	esp = {box2 = false, box3 = false, names = false, teams = false, color = {h = 0.36, t = 0}},
	chams = {on = false, teams = false, fill = {h = 0.75, t = 0.4}, outline = {h = 0, t = 0}},
	hat = {on = false, size = 1.2, color = {h = 0.13, t = 0.2}},
	trail = {on = false, time = 2, dist = 150, color = {h = 0.5, t = 0.2}},
	misc = {
		third = false, tpDist = 8, fovOn = false, fov = 90, stretch = 100,
		spin = false, spinSpeed = 360,
		hand = {x = 0, y = 0, z = 0},
	},
	body = {headless = false, legless = false},
	world = {sky = false, skyColor = {h = 0.6, t = 0.3}, shader = "Off"},
}

local function mk(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	if parent then o.Parent = parent end
	return o
end

local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

local function merge(dst, src)
	for k, v in pairs(src) do
		if type(v) == "table" and type(dst[k]) == "table" then
			merge(dst[k], v)
		else
			dst[k] = v
		end
	end
end

-- ui core ----------------------------------------------------------------

local paint, refresh = {}, {}
local menu
local pages = {}
local dragger

local function accent(obj, prop)
	paint[#paint + 1] = {obj, prop}
	obj[prop] = hsv(cfg.menu.color)
	return obj
end

local function repaint()
	local c = hsv(cfg.menu.color)
	for i = #paint, 1, -1 do
		local p = paint[i]
		if p[1].Parent == nil then
			table.remove(paint, i)
		else
			p[1][p[2]] = c
		end
	end
	for _, f in ipairs(refresh) do f() end
end

UIS.InputChanged:Connect(function(i)
	if dragger and i.UserInputType == Enum.UserInputType.MouseMovement then dragger() end
end)
UIS.InputEnded:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1 then dragger = nil end
end)

local function row(parent, h)
	local r = mk("Frame", {BackgroundColor3 = ROW, BorderSizePixel = 0, Size = UDim2.new(1, -6, 0, h)}, parent)
	mk("UICorner", {CornerRadius = UDim.new(0, 4)}, r)
	return r
end

local HUE_KEYS = {}
for i = 0, 6 do HUE_KEYS[#HUE_KEYS + 1] = ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6, 1, 1)) end
local HUE = ColorSequence.new(HUE_KEYS)
local GREY = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(30, 30, 30))

-- horizontal bar with a knob. returns place() to resync the knob.
local function bar(parent, y, grad, getP, setP)
	local b = mk("Frame", {Position = UDim2.new(0, 8, 0, y), Size = UDim2.new(1, -16, 0, 5), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0}, parent)
	mk("UICorner", {CornerRadius = UDim.new(1, 0)}, b)
	if grad then mk("UIGradient", {Color = grad}, b) end
	local k = mk("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(10, 10), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0}, b)
	mk("UICorner", {CornerRadius = UDim.new(1, 0)}, k)
	mk("UIStroke", {Color = Color3.new(0, 0, 0), Thickness = 1}, k)
	local function place() k.Position = UDim2.fromScale(getP(), 0.5) end
	local hit = mk("TextButton", {BackgroundTransparency = 1, Text = "", Position = UDim2.new(0, 0, 0, -4), Size = UDim2.new(1, 0, 0, 13), AutoButtonColor = false}, b)
	local function set()
		local p = math.clamp((UIS:GetMouseLocation().X - b.AbsolutePosition.X) / b.AbsoluteSize.X, 0, 1)
		setP(p)
		place()
	end
	hit.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then
			dragger = set
			set()
		end
	end)
	place()
	return place
end

local function toggle(page, label, tbl, key, cb)
	local r = row(page, 24)
	local hit = mk("TextButton", {BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = "", AutoButtonColor = false}, r)
	mk("TextLabel", {BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -50, 1, 0), Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = TXT, TextXAlignment = Enum.TextXAlignment.Left, Text = label}, r)
	local sw = mk("Frame", {Position = UDim2.new(1, -36, 0.5, -6), Size = UDim2.fromOffset(28, 12), BackgroundColor3 = Color3.fromRGB(48, 48, 56), BorderSizePixel = 0}, r)
	mk("UICorner", {CornerRadius = UDim.new(1, 0)}, sw)
	local kn = mk("Frame", {Position = UDim2.fromOffset(2, 2), Size = UDim2.fromOffset(8, 8), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0}, sw)
	mk("UICorner", {CornerRadius = UDim.new(1, 0)}, kn)
	local function draw()
		local on = tbl[key]
		TweenService:Create(kn, TweenInfo.new(0.12), {Position = on and UDim2.fromOffset(18, 2) or UDim2.fromOffset(2, 2)}):Play()
		sw.BackgroundColor3 = on and hsv(cfg.menu.color) or Color3.fromRGB(48, 48, 56)
	end
	hit.MouseButton1Click:Connect(function()
		tbl[key] = not tbl[key]
		draw()
		if cb then cb(tbl[key]) end
	end)
	refresh[#refresh + 1] = draw
	draw()
end

local function slider(page, label, tbl, key, mn, mx, step, dec, suffix, cb)
	local r = row(page, 34)
	mk("TextLabel", {BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 3), Size = UDim2.new(1, -16, 0, 12), Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = TXT, TextXAlignment = Enum.TextXAlignment.Left, Text = label}, r)
	local val = mk("TextLabel", {BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 3), Size = UDim2.new(1, -16, 0, 12), Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Right, Text = ""}, r)
	local function showVal()
		val.Text = string.format("%." .. dec .. "f", tbl[key]) .. (suffix or "")
	end
	local place = bar(r, 22, nil, function()
		return (tbl[key] - mn) / (mx - mn)
	end, function(p)
		local v = mn + p * (mx - mn)
		tbl[key] = math.clamp(math.floor(v / step + 0.5) * step, mn, mx)
		showVal()
		if cb then cb() end
	end)
	refresh[#refresh + 1] = function()
		place()
		showVal()
	end
	refresh[#refresh]()
end

local function colorRow(page, label, c)
	local r = row(page, 40)
	mk("TextLabel", {BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 3), Size = UDim2.new(1, -40, 0, 12), Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = TXT, TextXAlignment = Enum.TextXAlignment.Left, Text = label}, r)
	local sw = mk("Frame", {Position = UDim2.new(1, -24, 0, 3), Size = UDim2.fromOffset(16, 12), BorderSizePixel = 0, BackgroundColor3 = hsv(c)}, r)
	mk("UICorner", {CornerRadius = UDim.new(0, 3)}, sw)
	local tv = mk("TextLabel", {BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 3), Size = UDim2.new(1, -40, 0, 12), Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Right, Text = ""}, r)
	local placeH = bar(r, 18, HUE, function() return c.h end, function(p)
		c.h = p
		repaint()
	end)
	local placeT = bar(r, 31, GREY, function() return c.t end, function(p)
		c.t = p
		repaint()
	end)
	refresh[#refresh + 1] = function()
		sw.BackgroundColor3 = hsv(c)
		sw.BackgroundTransparency = c.t
		tv.Text = "transparency " .. math.floor(c.t * 100) .. "%"
		placeH()
		placeT()
	end
	refresh[#refresh]()
end

local function dropdown(page, label, tbl, key, opts, cb)
	local holder = mk("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, -6, 0, 24), AutomaticSize = Enum.AutomaticSize.Y}, page)
	mk("UIListLayout", {Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder}, holder)
	local head = mk("TextButton", {BackgroundColor3 = ROW, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 24), AutoButtonColor = false, Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = TXT, TextXAlignment = Enum.TextXAlignment.Left, Text = ""}, holder)
	mk("UIPadding", {PaddingLeft = UDim.new(0, 8)}, head)
	mk("UICorner", {CornerRadius = UDim.new(0, 4)}, head)
	local list = mk("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Visible = false}, holder)
	mk("UIListLayout", {Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder}, list)
	local function draw()
		head.Text = label .. "  :  " .. tbl[key]
	end
	for _, o in ipairs(opts) do
		local ob = mk("TextButton", {BackgroundColor3 = Color3.fromRGB(34, 34, 41), BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 20), AutoButtonColor = false, Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = TXT, Text = o}, list)
		mk("UICorner", {CornerRadius = UDim.new(0, 4)}, ob)
		ob.MouseButton1Click:Connect(function()
			tbl[key] = o
			list.Visible = false
			draw()
			if cb then cb(o) end
		end)
	end
	head.MouseButton1Click:Connect(function() list.Visible = not list.Visible end)
	refresh[#refresh + 1] = draw
	draw()
end

local function button(page, text, cb)
	local b = mk("TextButton", {BackgroundColor3 = ROW, BorderSizePixel = 0, Size = UDim2.new(1, -6, 0, 24), AutoButtonColor = false, Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = TXT, Text = text}, page)
	mk("UICorner", {CornerRadius = UDim.new(0, 4)}, b)
	b.MouseButton1Click:Connect(cb)
	return b
end

local function header(page, text)
	local l = mk("TextLabel", {BackgroundTransparency = 1, Size = UDim2.new(1, -6, 0, 16), Font = Enum.Font.GothamBold, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, Text = string.upper(text)}, page)
	accent(l, "TextColor3")
end

-- config -----------------------------------------------------------------

local function saveCfg(name)
	if not writefile then return false end
	if makefolder and isfolder and not isfolder(CFG_DIR) then makefolder(CFG_DIR) end
	writefile(CFG_DIR .. "/" .. name .. ".json", HttpService:JSONEncode(cfg))
	return true
end

local function loadCfg(name)
	if not (readfile and isfile) then return false end
	local path = CFG_DIR .. "/" .. name .. ".json"
	if not isfile(path) then return false end
	local ok, data = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
	if not ok then return false end
	merge(cfg, data)
	return true
end

local function listNames()
	if not (listfiles and isfolder and isfolder(CFG_DIR)) then return "none" end
	local out = {}
	for _, f in ipairs(listfiles(CFG_DIR)) do
		local n = f:match("([^/\\]+)%.json$")
		if n then out[#out + 1] = n end
	end
	return #out > 0 and table.concat(out, ", ") or "none"
end

-- game helpers -----------------------------------------------------------

local function charParts(p)
	local c = p.Character
	if not c then return nil end
	local h = c:FindFirstChildOfClass("Humanoid")
	local r = c:FindFirstChild("HumanoidRootPart")
	if not h or not r or h.Health <= 0 then return nil end
	return c, h, r
end

local function enemy(p)
	if p == LP then return false end
	if LP.Team and p.Team == LP.Team then return false end
	return true
end

local function nearestEnemy(range)
	local me = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
	if not me then return nil end
	local best, bestD = nil, range
	for _, p in ipairs(Players:GetPlayers()) do
		if enemy(p) then
			local c, _, r = charParts(p)
			if c then
				local d = (r.Position - me.Position).Magnitude
				if d < bestD then
					best, bestD = c, d
				end
			end
		end
	end
	return best
end

local rayP = RaycastParams.new()
rayP.FilterType = Enum.RaycastFilterType.Exclude
local function clearShot(part, char)
	local list = {char}
	if LP.Character then list[#list + 1] = LP.Character end
	rayP.FilterDescendantsInstances = list
	local o = workspace.CurrentCamera.CFrame.Position
	return workspace:Raycast(o, part.Position - o, rayP) == nil
end

local function aimTarget()
	local cam = workspace.CurrentCamera
	local center = cam.ViewportSize / 2
	local best, bestD = nil, cfg.aim.fov
	for _, p in ipairs(Players:GetPlayers()) do
		if enemy(p) then
			local c, _, r = charParts(p)
			if c then
				local part = c:FindFirstChild(cfg.aim.bone) or r
				local v, on = cam:WorldToViewportPoint(part.Position)
				if on and v.Z > 0 then
					local d = (Vector2.new(v.X, v.Y) - center).Magnitude
					if d < bestD and clearShot(part, c) then
						best, bestD = part, d
					end
				end
			end
		end
	end
	return best
end

local function stretch(v)
	local center = workspace.CurrentCamera.ViewportSize / 2
	local k = cfg.misc.stretch / 100
	return Vector2.new(center.X + (v.X - center.X) * k, v.Y)
end

-- drawing pools ----------------------------------------------------------

local sets = {}

local function newSet()
	return {L = {}, T = {}, N = {}, used = {L = 0, T = 0, N = 0}}
end

local function take(s, kind)
	local n = s.used[kind] + 1
	s.used[kind] = n
	local list = s[kind]
	local d = list[n]
	if not d then
		d = Drawing.new(kind == "L" and "Line" or (kind == "T" and "Triangle" or "Text"))
		list[n] = d
	end
	d.Visible = true
	return d
end

local function finish(s)
	for _, kind in ipairs({"L", "T", "N"}) do
		for i = s.used[kind] + 1, #s[kind] do
			s[kind][i].Visible = false
		end
	end
	s.used = {L = 0, T = 0, N = 0}
end

local function ln(s, a, b, col, alpha, th)
	local d = take(s, "L")
	d.From = a
	d.To = b
	d.Color = hsv(col)
	d.Transparency = alpha
	d.Thickness = th or 1
end

local function tri(s, a, b, c2, col, alpha)
	local d = take(s, "T")
	d.PointA = a
	d.PointB = b
	d.PointC = c2
	d.Color = hsv(col)
	d.Filled = true
	d.Transparency = alpha
end

local function txt(s, pos, str, col)
	local d = take(s, "N")
	d.Position = pos
	d.Text = str
	d.Color = hsv(col)
	d.Transparency = 1
	d.Center = true
	d.Outline = true
	d.Size = 13
end

local EDGES = {}
for i = 0, 7 do
	for _, b in ipairs({4, 2, 1}) do
		if i % (b * 2) < b then
			EDGES[#EDGES + 1] = {i + 1, i + b + 1}
		end
	end
end

local function drawEsp(s, p, char)
	local cam = workspace.CurrentCamera
	local cf, size = char:GetBoundingBox()
	local hx, hy, hz = size.X / 2, size.Y / 2, size.Z / 2
	local pts, ons = {}, {}
	local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
	local any = false
	for i = 0, 7 do
		local sx = i >= 4 and 1 or -1
		local sy = i % 4 >= 2 and 1 or -1
		local sz = i % 2 == 1 and 1 or -1
		local v, on = cam:WorldToViewportPoint((cf * CFrame.new(sx * hx, sy * hy, sz * hz)).Position)
		on = on and v.Z > 0
		local q = stretch(Vector2.new(v.X, v.Y))
		pts[i + 1] = q
		ons[i + 1] = on
		any = any or on
		x0, y0 = math.min(x0, q.X), math.min(y0, q.Y)
		x1, y1 = math.max(x1, q.X), math.max(y1, q.Y)
	end
	local col = cfg.esp.color
	local a = op(col)
	if cfg.esp.box2 and any then
		local A, B = Vector2.new(x0, y0), Vector2.new(x1, y0)
		local C, D = Vector2.new(x1, y1), Vector2.new(x0, y1)
		ln(s, A, B, col, a)
		ln(s, B, C, col, a)
		ln(s, C, D, col, a)
		ln(s, D, A, col, a)
	end
	if cfg.esp.box3 then
		for _, e in ipairs(EDGES) do
			if ons[e[1]] and ons[e[2]] then
				ln(s, pts[e[1]], pts[e[2]], col, a)
			end
		end
	end
	if cfg.esp.names and any then
		local head = char:FindFirstChild("Head")
		if head then
			local v, on = cam:WorldToViewportPoint(head.Position + Vector3.new(0, head.Size.Y / 2 + 0.8, 0))
			if on and v.Z > 0 then
				txt(s, stretch(Vector2.new(v.X, v.Y)), p.Name, col)
			end
		end
	end
end

local function drawHat(s, char)
	local head = char:FindFirstChild("Head")
	if not head then return end
	local cam = workspace.CurrentCamera
	local base = head.Position + Vector3.new(0, head.Size.Y / 2 + 0.05, 0)
	local rad = cfg.hat.size
	local tip, onTip = cam:WorldToViewportPoint(base + Vector3.new(0, rad * 1.1, 0))
	if not onTip or tip.Z <= 0 then return end
	local tipS = stretch(Vector2.new(tip.X, tip.Y))
	local N = 24
	local rim = {}
	for i = 0, N - 1 do
		local a = i / N * math.pi * 2
		local v = cam:WorldToViewportPoint(base + Vector3.new(math.cos(a) * rad, 0, math.sin(a) * rad))
		if v.Z <= 0 then return end
		rim[i + 1] = stretch(Vector2.new(v.X, v.Y))
	end
	local col = cfg.hat.color
	local alpha = op(col)
	for i = 1, N do
		tri(s, tipS, rim[i], rim[i % N + 1], col, alpha)
	end
end

local trailPts, trailSet, lastTrail = {}, newSet(), nil
local function drawTrail(root)
	local now = os.clock()
	if cfg.trail.on then
		if root then
			if not lastTrail or (root.Position - lastTrail).Magnitude > 0.3 then
				trailPts[#trailPts + 1] = {p = root.Position, t = now}
				lastTrail = root.Position
			end
		end
		while trailPts[1] and now - trailPts[1].t > cfg.trail.time do
			table.remove(trailPts, 1)
		end
		local cam = workspace.CurrentCamera
		local col = cfg.trail.color
		for i = 2, #trailPts do
			local a, b = trailPts[i - 1], trailPts[i]
			local mid = (a.p + b.p) / 2
			if (mid - cam.CFrame.Position).Magnitude <= cfg.trail.dist then
				local va, oa = cam:WorldToViewportPoint(a.p)
				local vb, ob = cam:WorldToViewportPoint(b.p)
				if oa and ob and va.Z > 0 and vb.Z > 0 then
					local fade = math.max(0, 1 - (now - b.t) / cfg.trail.time)
					ln(trailSet, stretch(Vector2.new(va.X, va.Y)), stretch(Vector2.new(vb.X, vb.Y)), col, op(col) * fade, 2)
				end
			end
		end
	else
		trailPts = {}
		lastTrail = nil
	end
	finish(trailSet)
end

-- third person -----------------------------------------------------------

local origZoom = {min = LP.CameraMinZoomDistance, max = LP.CameraMaxZoomDistance, mode = LP.CameraMode}
local tpOn = false
local function applyThird()
	if cfg.misc.third then
		LP.CameraMode = Enum.CameraMode.Classic
		LP.CameraMinZoomDistance = cfg.misc.tpDist
		LP.CameraMaxZoomDistance = cfg.misc.tpDist
		tpOn = true
	elseif tpOn then
		LP.CameraMinZoomDistance = origZoom.min
		LP.CameraMaxZoomDistance = origZoom.max
		LP.CameraMode = origZoom.mode
		tpOn = false
	end
end

-- world / body mods ------------------------------------------------------

local origFov
local function fovUpdate()
	local cam = workspace.CurrentCamera
	if cfg.misc.fovOn then
		origFov = origFov or cam.FieldOfView
		cam.FieldOfView = cfg.misc.fov
	elseif origFov then
		cam.FieldOfView = origFov
		origFov = nil
	end
end

local skyObj, skyMade, skyOrig = nil, false, {}
local function skyUpdate()
	if cfg.world.sky then
		if not skyObj then
			skyObj = Lighting:FindFirstChildOfClass("Atmosphere")
			if skyObj then
				skyOrig = {Color = skyObj.Color, Decay = skyObj.Decay, Density = skyObj.Density, Haze = skyObj.Haze}
			else
				skyObj = mk("Atmosphere", {Name = "LXS_Atmo"}, Lighting)
				skyMade = true
			end
		end
		local c = cfg.world.skyColor
		skyObj.Color = hsv(c)
		skyObj.Decay = Color3.fromHSV(c.h, 0.7, 0.6)
		skyObj.Density = 0.1 + (1 - c.t) * 0.5
		skyObj.Haze = 1.5
	elseif skyObj then
		if skyMade then
			skyObj:Destroy()
		else
			for k, v in pairs(skyOrig) do skyObj[k] = v end
		end
		skyObj = nil
		skyMade = false
	end
end

local FX = {
	Bloom = {{"BloomEffect", {Intensity = 0.8, Size = 24, Threshold = 0.9}}},
	Vivid = {{"ColorCorrectionEffect", {Saturation = 0.4, Contrast = 0.15}}},
	Noir = {{"ColorCorrectionEffect", {Saturation = -1, Contrast = 0.25}}},
	Warm = {{"ColorCorrectionEffect", {TintColor = Color3.fromRGB(255, 225, 190), Saturation = 0.1}}},
	Cold = {{"ColorCorrectionEffect", {TintColor = Color3.fromRGB(185, 215, 255), Saturation = 0.05}}},
	Sunrays = {{"SunRaysEffect", {Intensity = 0.15, Spread = 0.6}}},
}
local fxMade, fxName = {}, "Off"
local function shaderUpdate()
	local want = cfg.world.shader
	if want == fxName then return end
	for _, o in ipairs(fxMade) do o:Destroy() end
	fxMade = {}
	fxName = want
	for _, def in ipairs(FX[want] or {}) do
		fxMade[#fxMade + 1] = mk(def[1], def[2], Lighting)
	end
end

local HEAD_PARTS = {"Head"}
local LEG_PARTS = {"LeftLeg", "RightLeg", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot"}
local savedT = {}
local function hideP(part, on)
	if on then
		if savedT[part] == nil then savedT[part] = part.Transparency end
		part.Transparency = 1
	elseif savedT[part] ~= nil then
		part.Transparency = savedT[part]
		savedT[part] = nil
	end
end

local function bodyUpdate()
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LP and p.Character then
			local en = enemy(p)
			local ch = p.Character
			for _, n in ipairs(HEAD_PARTS) do
				local part = ch:FindFirstChild(n)
				if part then
					hideP(part, en and cfg.body.headless)
					local face = part:FindFirstChildOfClass("Decal")
					if face then hideP(face, en and cfg.body.headless) end
				end
			end
			for _, n in ipairs(LEG_PARTS) do
				local part = ch:FindFirstChild(n)
				if part then hideP(part, en and cfg.body.legless) end
			end
		end
	end
end

local function chamsUpdate()
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LP and p.Character then
			local c = p.Character
			local hl = c:FindFirstChild("LXS_Cham")
			local want = cfg.chams.on and (enemy(p) or cfg.chams.teams)
			if want then
				if not hl then
					hl = Instance.new("Highlight")
					hl.Name = "LXS_Cham"
					hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
					hl.Parent = c
				end
				hl.FillColor = hsv(cfg.chams.fill)
				hl.FillTransparency = cfg.chams.fill.t
				hl.OutlineColor = hsv(cfg.chams.outline)
				hl.OutlineTransparency = cfg.chams.outline.t
			elseif hl then
				hl:Destroy()
			end
		end
	end
end

local motorBase = {}
local function handUpdate()
	local c = LP.Character
	if not c then return end
	local torso = c:FindFirstChild("UpperTorso") or c:FindFirstChild("Torso")
	local m = torso and (torso:FindFirstChild("RightShoulder") or torso:FindFirstChild("Right Shoulder"))
	if not m or not m:IsA("Motor6D") then return end
	if not motorBase[m] then motorBase[m] = m.C0 end
	local h = cfg.misc.hand
	m.C0 = motorBase[m] * CFrame.new(h.x, h.y, h.z)
end

-- menu -------------------------------------------------------------------

local function sizeMenu()
	local ratio = {["1:1"] = {1, 1}, ["4:3"] = {4, 3}, ["16:9"] = {16, 9}, ["21:9"] = {21, 9}}
	local r = ratio[cfg.menu.ratio] or {16, 9}
	menu.Size = UDim2.fromOffset(cfg.menu.w, math.floor(cfg.menu.w * r[2] / r[1]))
end

local function movable(handle, target)
	local st = {}
	handle.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then
			st.on = true
			st.moved = false
			st.from = UIS:GetMouseLocation()
			st.pos = target.Position
		end
	end)
	UIS.InputChanged:Connect(function(i)
		if st.on and i.UserInputType == Enum.UserInputType.MouseMovement then
			local d = UIS:GetMouseLocation() - st.from
			if d.Magnitude > 4 then st.moved = true end
			target.Position = UDim2.new(st.pos.X.Scale, st.pos.X.Offset + d.X, st.pos.Y.Scale, st.pos.Y.Offset + d.Y)
		end
	end)
	UIS.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then st.on = false end
	end)
	return st
end

local tabNames = {"Combat", "Visuals", "Misc", "Config"}

local function buildMain()
	local gui = mk("ScreenGui", {Name = "LXS_Main", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 10}, guiParent)

	local mark = mk("TextLabel", {BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 8), Size = UDim2.fromOffset(120, 22), Font = Enum.Font.GothamBlack, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Right, Text = "LuXxS"}, gui)
	accent(mark, "TextColor3")

	local icon = mk("TextButton", {Position = UDim2.fromOffset(16, 120), Size = UDim2.fromOffset(38, 38), BackgroundColor3 = Color3.fromRGB(20, 20, 24), AutoButtonColor = false, Font = Enum.Font.GothamBlack, TextSize = 18, TextColor3 = TXT, Text = "L"}, gui)
	mk("UICorner", {CornerRadius = UDim.new(0, 8)}, icon)
	accent(mk("UIStroke", {Thickness = 1.5}, icon), "Color")
	if ICON_ASSET ~= "" then
		icon.Text = ""
		mk("ImageLabel", {BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Image = ICON_ASSET}, icon)
	end

	menu = mk("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = BG, BorderSizePixel = 0, Visible = false, ClipsDescendants = true}, gui)
	mk("UICorner", {CornerRadius = UDim.new(0, 8)}, menu)
	accent(mk("UIStroke", {Thickness = 1.5}, menu), "Color")
	sizeMenu()

	local iconDrag = movable(icon, icon)
	icon.MouseButton1Click:Connect(function()
		if not iconDrag.moved then menu.Visible = not menu.Visible end
	end)

	local top = mk("Frame", {BackgroundColor3 = Color3.fromRGB(10, 10, 12), BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 26)}, menu)
	local title = mk("TextLabel", {BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 0), Size = UDim2.new(0.6, 0, 1, 0), Font = Enum.Font.GothamBlack, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, Text = "LuXxS"}, top)
	accent(title, "TextColor3")
	local close = mk("TextButton", {BackgroundTransparency = 1, Position = UDim2.new(1, -28, 0, 0), Size = UDim2.fromOffset(28, 26), Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = DIM, Text = "x", AutoButtonColor = false}, top)
	close.MouseButton1Click:Connect(function() menu.Visible = false end)
	movable(top, menu)

	local side = mk("Frame", {BackgroundColor3 = Color3.fromRGB(20, 20, 24), BorderSizePixel = 0, Position = UDim2.fromOffset(0, 26), Size = UDim2.new(0, 92, 1, -26)}, menu)
	local content = mk("Frame", {BackgroundTransparency = 1, Position = UDim2.fromOffset(98, 32), Size = UDim2.new(1, -104, 1, -38)}, menu)

	local active = "Combat"
	local tabBtns = {}
	local function show(name)
		active = name
		for n, p in pairs(pages) do p.Visible = (n == name) end
		for n, b in pairs(tabBtns) do
			b.BackgroundTransparency = (n == name) and 0 or 1
			b.BackgroundColor3 = ROW
		end
		for _, f in ipairs(refresh) do f() end
	end
	refresh[#refresh + 1] = function()
		for n, b in pairs(tabBtns) do
			b.TextColor3 = (n == active) and hsv(cfg.menu.color) or DIM
		end
	end

	for i, name in ipairs(tabNames) do
		local b = mk("TextButton", {BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.new(0, 6, 0, 6 + (i - 1) * 28), Size = UDim2.new(1, -12, 0, 24), AutoButtonColor = false, Font = Enum.Font.GothamBold, TextSize = 12, Text = name}, side)
		mk("UICorner", {CornerRadius = UDim.new(0, 4)}, b)
		b.MouseButton1Click:Connect(function() show(name) end)
		tabBtns[name] = b
	end

	for _, name in ipairs(tabNames) do
		local p = mk("ScrollingFrame", {BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 2, Visible = false}, content)
		accent(p, "ScrollBarImageColor3")
		mk("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}, p)
		pages[name] = p
	end

	local C, V, M, S = pages.Combat, pages.Visuals, pages.Misc, pages.Config

	header(C, "aimbot")
	toggle(C, "enabled (hold rmb)", cfg.aim, "on")
	dropdown(C, "bone", cfg.aim, "bone", {"Head", "UpperTorso", "HumanoidRootPart"})
	slider(C, "smoothness", cfg.aim, "smooth", 1, 30, 1, 0)
	slider(C, "fov size", cfg.aim, "fov", 20, 400, 5, 0, " px")
	toggle(C, "show fov circle", cfg.aim, "fovShow")
	colorRow(C, "fov color", cfg.aim.fovColor)
	header(C, "anti aim")
	dropdown(C, "mode", cfg.anti, "mode", {"Off", "Dodge", "Jitter", "Spin", "Back"})
	header(C, "kill aura")
	toggle(C, "kill aura", cfg.kill, "on")
	slider(C, "range", cfg.kill, "range", 10, 300, 5, 0, " st")

	header(V, "esp")
	toggle(V, "2d box", cfg.esp, "box2")
	toggle(V, "3d box", cfg.esp, "box3")
	toggle(V, "names", cfg.esp, "names")
	toggle(V, "show teammates", cfg.esp, "teams")
	colorRow(V, "box color", cfg.esp.color)
	header(V, "chams")
	toggle(V, "chams", cfg.chams, "on")
	toggle(V, "show teammates", cfg.chams, "teams")
	colorRow(V, "fill", cfg.chams.fill)
	colorRow(V, "outline", cfg.chams.outline)
	header(V, "chinese hat")
	toggle(V, "hat", cfg.hat, "on")
	slider(V, "size", cfg.hat, "size", 0.5, 4, 0.1, 1, " st")
	colorRow(V, "hat color", cfg.hat.color)
	header(V, "trail")
	toggle(V, "trail", cfg.trail, "on")
	slider(V, "time", cfg.trail, "time", 0.5, 10, 0.5, 1, " s")
	slider(V, "distance", cfg.trail, "dist", 20, 500, 10, 0, " st")
	colorRow(V, "trail color", cfg.trail.color)

	header(M, "camera")
	toggle(M, "third person", cfg.misc, "third", applyThird)
	slider(M, "tp distance", cfg.misc, "tpDist", 3, 20, 1, 0, " st", applyThird)
	toggle(M, "custom fov", cfg.misc, "fovOn")
	slider(M, "fov", cfg.misc, "fov", 40, 120, 1, 0)
	slider(M, "screen stretch", cfg.misc, "stretch", 50, 150, 1, 0, "%")
	header(M, "viewmodel")
	slider(M, "x offset", cfg.misc.hand, "x", -3, 3, 0.05, 2)
	slider(M, "y offset", cfg.misc.hand, "y", -3, 3, 0.05, 2)
	slider(M, "z offset", cfg.misc.hand, "z", -3, 3, 0.05, 2)
	header(M, "spin")
	toggle(M, "spin", cfg.misc, "spin")
	slider(M, "speed", cfg.misc, "spinSpeed", 60, 1440, 30, 0, " deg/s")
	header(M, "body")
	toggle(M, "headless", cfg.body, "headless")
	toggle(M, "legless", cfg.body, "legless")
	header(M, "world")
	toggle(M, "sky color", cfg.world, "sky")
	colorRow(M, "sky", cfg.world.skyColor)
	dropdown(M, "shader", cfg.world, "shader", {"Off", "Bloom", "Vivid", "Noir", "Warm", "Cold", "Sunrays"})

	header(S, "menu")
	colorRow(S, "menu color", cfg.menu.color)
	slider(S, "width", cfg.menu, "w", 300, 720, 10, 0, " px", sizeMenu)
	dropdown(S, "aspect", cfg.menu, "ratio", {"1:1", "4:3", "16:9", "21:9"}, sizeMenu)
	header(S, "config")
	local nameBox = mk("TextBox", {BackgroundColor3 = ROW, BorderSizePixel = 0, Size = UDim2.new(1, -6, 0, 24), Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = TXT, PlaceholderText = "config name", Text = "", ClearTextOnFocus = false}, S)
	mk("UICorner", {CornerRadius = UDim.new(0, 4)}, nameBox)
	local status = mk("TextLabel", {BackgroundTransparency = 1, Size = UDim2.new(1, -6, 0, 16), Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Left, Text = ""}, S)
	local listLbl = mk("TextLabel", {BackgroundTransparency = 1, Size = UDim2.new(1, -6, 0, 16), Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, Text = "configs: " .. listNames()}, S)
	button(S, "save", function()
		local n = trim(nameBox.Text)
		if n == "" then
			status.Text = "type a name first"
			return
		end
		status.Text = saveCfg(n) and ("saved: " .. n) or "save failed (no writefile)"
		listLbl.Text = "configs: " .. listNames()
	end)
	button(S, "load", function()
		local n = trim(nameBox.Text)
		if n == "" then
			status.Text = "type a name first"
			return
		end
		if loadCfg(n) then
			repaint()
			sizeMenu()
			status.Text = "loaded: " .. n
		else
			status.Text = "no config called " .. n
		end
	end)

	show("Combat")
	repaint()

	-- watermark, overlay, aim, logic
	RunService:BindToRenderStep("luxs_aim", Enum.RenderPriority.Camera.Value + 1, function()
		if not cfg.aim.on or not UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then return end
		local t = aimTarget()
		if t then
			local cam = workspace.CurrentCamera
			local goal = CFrame.lookAt(cam.CFrame.Position, t.Position)
			cam.CFrame = cam.CFrame:Lerp(goal, 1 / math.max(cfg.aim.smooth, 1))
		end
	end)

	local fovC = Drawing.new("Circle")
	fovC.Thickness = 1
	fovC.NumSides = 64
	fovC.Filled = false

	RunService.RenderStepped:Connect(function()
		local cam = workspace.CurrentCamera
		fovC.Visible = cfg.aim.on and cfg.aim.fovShow
		fovC.Position = cam.ViewportSize / 2
		fovC.Radius = cfg.aim.fov
		fovC.Color = hsv(cfg.aim.fovColor)
		fovC.Transparency = op(cfg.aim.fovColor)

		for _, p in ipairs(Players:GetPlayers()) do
			local s = sets[p]
			if not s then
				s = newSet()
				sets[p] = s
			end
			local c = charParts(p)
			if c and p ~= LP and (enemy(p) or cfg.esp.teams) and (cfg.esp.box2 or cfg.esp.box3 or cfg.esp.names) then
				drawEsp(s, p, c)
			end
			if c and cfg.hat.on and (p ~= LP or cfg.misc.third) then
				drawHat(s, c)
			end
			finish(s)
		end
		local _, _, lr = charParts(LP)
		drawTrail(lr)
	end)

	local lastKill, aaOff, spinA, spinM = 0, Vector3.zero, 0, 0
	local dodgeT, dodgeSide, bodyT = 0, 1, 0
	RunService.Heartbeat:Connect(function(dt)
		local c, hum, root = charParts(LP)
		if c then
			local aa = cfg.anti.mode
			local spinning = cfg.misc.spin
			local rot = aa ~= "Off" or spinning
			hum.AutoRotate = not rot

			if cfg.kill.on and os.clock() - lastKill > 0.2 then
				local tool = c:FindFirstChildOfClass("Tool")
				local ec = nearestEnemy(cfg.kill.range)
				local er = ec and ec:FindFirstChild("HumanoidRootPart")
				if tool and er then
					root.CFrame = CFrame.lookAt((er.CFrame * CFrame.new(0, 0, 3)).Position, er.Position)
					tool:Activate()
					lastKill = os.clock()
				end
			end

			dodgeT = dodgeT + dt
			local want = Vector3.zero
			local extra = 0
			if aa == "Jitter" then
				extra = (os.clock() * 12) % 2 < 1 and math.rad(75) or -math.rad(75)
			elseif aa == "Back" then
				extra = math.pi
			elseif aa == "Spin" then
				spinA = spinA + math.rad(720) * dt
				extra = spinA
			elseif aa == "Dodge" and nearestEnemy(18) then
				if dodgeT > 0.2 then
					dodgeT = 0
					dodgeSide = -dodgeSide
				end
				local rv = workspace.CurrentCamera.CFrame.RightVector
				rv = Vector3.new(rv.X, 0, rv.Z)
				if rv.Magnitude > 0 then want = rv.Unit * 2.2 * dodgeSide end
			end
			if spinning then
				spinM = spinM + math.rad(cfg.misc.spinSpeed) * dt
				extra = extra + spinM
			end

			if rot or aaOff ~= Vector3.zero then
				local look = workspace.CurrentCamera.CFrame.LookVector
				local yaw = math.atan2(-look.X, -look.Z) + extra
				local base = root.Position - aaOff
				aaOff = want
				root.CFrame = CFrame.new(base + aaOff) * CFrame.Angles(0, yaw, 0)
			end
		else
			aaOff = Vector3.zero
		end

		fovUpdate()
		skyUpdate()
		shaderUpdate()
		handUpdate()
		bodyT = bodyT + dt
		if bodyT > 0.25 then
			bodyT = 0
			chamsUpdate()
			bodyUpdate()
		end
	end)

	Players.PlayerRemoving:Connect(function(p)
		local s = sets[p]
		if s then
			for _, k in ipairs({"L", "T", "N"}) do
				for _, d in ipairs(s[k]) do d:Remove() end
			end
			sets[p] = nil
		end
	end)

	UIS.InputBegan:Connect(function(i, gp)
		if not gp and i.KeyCode == Enum.KeyCode.RightShift then
			menu.Visible = not menu.Visible
		end
	end)
end

-- key screen -------------------------------------------------------------

local function keyScreen()
	local gui = mk("ScreenGui", {Name = "LXS_Key", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 100}, guiParent)
	local card = mk("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(300, 176), BackgroundColor3 = BG, BorderSizePixel = 0}, gui)
	mk("UICorner", {CornerRadius = UDim.new(0, 10)}, card)
	local edge = mk("UIStroke", {Thickness = 1.5, Color = Color3.fromRGB(255, 45, 45)}, card)
	local title = mk("TextLabel", {BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 14), Size = UDim2.new(1, 0, 0, 44), Font = Enum.Font.GothamBlack, TextSize = 36, TextColor3 = Color3.fromRGB(255, 45, 45), Text = ""}, card)

	local alive = true
	task.spawn(function()
		local word = "LuXxS"
		for i = 1, #word do
			if not alive then return end
			title.Text = word:sub(1, i)
			task.wait(0.14)
		end
	end)
	task.spawn(function()
		while alive and gui.Parent do
			local col = Color3.fromHSV((os.clock() * 0.2) % 1, 0.9, 1)
			title.TextColor3 = col
			edge.Color = col
			task.wait()
		end
	end)

	local input = mk("TextBox", {Position = UDim2.fromOffset(20, 78), Size = UDim2.new(1, -40, 0, 30), BackgroundColor3 = ROW, BorderSizePixel = 0, Font = Enum.Font.Code, TextSize = 14, TextColor3 = TXT, PlaceholderText = "enter key", Text = "", ClearTextOnFocus = false}, card)
	mk("UICorner", {CornerRadius = UDim.new(0, 6)}, input)
	local go = mk("TextButton", {Position = UDim2.fromOffset(20, 118), Size = UDim2.new(1, -40, 0, 30), BackgroundColor3 = Color3.fromRGB(200, 30, 30), BorderSizePixel = 0, Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Color3.new(1, 1, 1), Text = "unlock", AutoButtonColor = false}, card)
	mk("UICorner", {CornerRadius = UDim.new(0, 6)}, go)
	local status = mk("TextLabel", {BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 152), Size = UDim2.new(1, 0, 0, 16), Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = DIM, Text = ""}, card)

	local busy = false
	local function attempt()
		if busy then return end
		busy = true
		local typed = string.upper(trim(input.Text))
		if typed == KEY then
			status.Text = "access granted"
			status.TextColor3 = Color3.fromRGB(90, 230, 120)
			task.wait(0.5)
			alive = false
			gui:Destroy()
			buildMain()
		else
			status.Text = "invalid key"
			status.TextColor3 = Color3.fromRGB(255, 80, 80)
			for _, dx in ipairs({8, -8, 6, -6, 0}) do
				card.Position = UDim2.new(0.5, dx, 0.5, 0)
				task.wait(0.03)
			end
			busy = false
		end
	end

	go.MouseButton1Click:Connect(attempt)
	input.FocusLost:Connect(function(enter)
		if enter then attempt() end
	end)
end

keyScreen()
