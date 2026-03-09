-- RageVoid GUI Script | alpha v0.9 — REDESIGN (Dark Minimal / ESP-Client Style)
-- Insert = menu | Custom Keybinds
local Players         = game:GetService("Players")
local LocalPlayer     = Players.LocalPlayer
local RunService      = game:GetService("RunService")
local UserInputService= game:GetService("UserInputService")
local Workspace       = game:GetService("Workspace")
local Camera          = Workspace.CurrentCamera
local HttpService     = game:GetService("HttpService")
local Lighting        = game:GetService("Lighting")
local IS_MOBILE       = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- =====================================================================
-- НАСТРОЙКИ
-- =====================================================================
local DefaultSettings = {
	ESP = {
		Enabled      = false,
		ShowPlayers  = true,
		ShowNPCs     = true,
		ShowNames    = true,
		ShowHealth   = true,
		ShowDistance = true,
		ShowTracers  = true,
		ShowCorners  = true,
		ShowSkeleton = true,
		ShowWeapon   = true,
		MaxDistance  = 1000,
		CornerLen    = 8,
	},
	Chams = {
		Enabled        = false,
		Players        = true,
		NPCs           = false,
		Wallcheck      = true,   -- разный цвет сквозь стену
		PlayerR        = 255, PlayerG = 60,  PlayerB = 60,
		PlayerWallR    = 255, PlayerWallG = 160, PlayerWallB = 0,
		NPCR           = 60,  NPCG = 200,  NPCB = 255,
		NPCWallR       = 60,  NPCWallG = 80,  NPCWallB = 200,
		Transparency   = 0.5,
		WallTransparency = 0.7,
	},
	Aimbot = {
		Enabled = false, FOV = 200, Smoothness = 50,
		ShowFOV = true, IgnoreTeam = true, TargetPart = "Head"
	},
	Teleport = { TeleportTime = 1, Distance = 5 },
	Movement = { BunnyHop = false, BHopSpeed = 10, AutoJump = true, MaxSpeed = 100 },
	AntiAim  = {
		Enabled = false, Mode = "Random",
		SpinSpeed = 15, StaticAngle = 180, JitterRange = 45, Interval = 0.07,
	},
	FakeLag = {
		Enabled  = false,
		Distance = 15,
		Interval = 0.12,
		ShowCube = true,
	},
	Watermark = { Enabled = true },
	Keybinds = {
		ToggleMenu    = "Insert",
		QuickTP       = "None",
		ToggleESP     = "None",
		ToggleAimbot  = "None",
		ToggleFakeLag = "None",
		ToggleBhop    = "None",
		ToggleAntiAim = "None",
	},
	Visuals = {
		Brightness = 1,
		AmbientR = 0, AmbientG = 0, AmbientB = 0,
		OutdoorR = 70, OutdoorG = 70, OutdoorB = 70,
		FogEnabled = false, FogEnd = 1000,
		SkyEnabled = false, SkyPreset = "Night",
	}
}

local function DeepCopy(t)
	local c = {}
	for k,v in pairs(t) do c[k] = type(v)=="table" and DeepCopy(v) or v end
	return c
end
local Settings = DeepCopy(DefaultSettings)

-- =====================================================================
-- ПЕРЕМЕННЫЕ
-- =====================================================================
local FOVCircle, ScreenGui, WatermarkFrame
local bhopConnection, lastJumpTime, jumpCooldown = nil, 0, 0.1
local isTeleporting, currentTeleportTarget, teleportConnection = false, nil, nil
local npcCache, lastNPCUpdate, NPC_UPDATE_INTERVAL = {}, 0, 2
local antiAimConnection, antiAimAngle = nil, 0
local visualSky = nil
local fakeLagConnection = nil
local fakeLagCube       = nil
local chamsObjects      = {} -- { model -> { parts -> {orig highlight} } }
local chamsHighlights   = {} -- { model -> Highlight }
local keybindListening  = nil
local keybindButtons    = {}

local KEYBIND_IDS = {
	{ id="ToggleMenu",    label="Toggle Menu"    },
	{ id="QuickTP",       label="Quick Teleport" },
	{ id="ToggleESP",     label="Toggle ESP"     },
	{ id="ToggleAimbot",  label="Toggle Aimbot"  },
	{ id="ToggleFakeLag", label="Toggle FakeLag" },
	{ id="ToggleBhop",    label="Toggle BHop"    },
	{ id="ToggleAntiAim", label="Toggle AntiAim" },
}

local CONFIG_FOLDER = "RushvoidConfigs"
local CONFIG_EXT    = ".json"

-- =====================================================================
-- ЦВЕТА — НОВАЯ ПАЛИТРА (Dark Minimal / ESP-Client)
-- =====================================================================
local C = {
	BG        = Color3.fromRGB(13, 13, 15),
	Sidebar   = Color3.fromRGB(17, 17, 20),
	Content   = Color3.fromRGB(17, 17, 20),
	Row       = Color3.fromRGB(24, 24, 28),
	RowHover  = Color3.fromRGB(30, 30, 35),
	Text      = Color3.fromRGB(220, 220, 228),
	Dim       = Color3.fromRGB(95, 95, 108),
	Dimmer    = Color3.fromRGB(60, 60, 70),
	Accent    = Color3.fromRGB(130, 180, 255),
	AccentDim = Color3.fromRGB(65, 100, 160),
	AccentBG  = Color3.fromRGB(20, 28, 45),
	Green     = Color3.fromRGB(80, 200, 120),
	Red       = Color3.fromRGB(200, 60, 60),
	Orange    = Color3.fromRGB(210, 145, 50),
	Purple    = Color3.fromRGB(140, 90, 220),
	Teal      = Color3.fromRGB(50, 190, 170),
	SliderBG  = Color3.fromRGB(28, 28, 33),
	SliderFill= Color3.fromRGB(100, 155, 230),
	ToggleOff = Color3.fromRGB(40, 40, 46),
	ToggleOn  = Color3.fromRGB(55, 140, 90),
	Border    = Color3.fromRGB(35, 35, 42),
	ActiveTab = Color3.fromRGB(22, 22, 27),
	TabInd    = Color3.fromRGB(100, 155, 230),
	Header    = Color3.fromRGB(15, 15, 18),
}

local Icons = {
	aimbot    = "rbxassetid://2766332187",
	esp       = "rbxassetid://104375575611634",
	movement  = "rbxassetid://10874965872",
	visuals   = "rbxassetid://4483345998",
	configlist= "rbxassetid://106913556469827",
	info      = "rbxassetid://14446132837",
	settings  = "rbxassetid://88492401190037",
}

-- =====================================================================
-- КОНФИГ
-- =====================================================================
local ConfigSystem = {}
local FS_AVAILABLE = (isfolder ~= nil and writefile ~= nil and readfile ~= nil)

local function SafeCall(fn, ...)
	local ok, result = pcall(fn, ...)
	return ok, result
end

local function EnsureFolder()
	if not FS_AVAILABLE then return false end
	local ok = SafeCall(function()
		if not isfolder(CONFIG_FOLDER) then makefolder(CONFIG_FOLDER) end
	end)
	return ok
end

function ConfigSystem.Serialize()
	local data = {
		ESP=DeepCopy(Settings.ESP), Chams=DeepCopy(Settings.Chams), Aimbot=DeepCopy(Settings.Aimbot),
		Teleport=DeepCopy(Settings.Teleport), Movement=DeepCopy(Settings.Movement),
		AntiAim=DeepCopy(Settings.AntiAim), FakeLag=DeepCopy(Settings.FakeLag),
		Keybinds=DeepCopy(Settings.Keybinds), Visuals=DeepCopy(Settings.Visuals),
	}
	local ok, result = SafeCall(function() return HttpService:JSONEncode(data) end)
	if ok and type(result)=="string" then return result end
	return nil, "Serialize error: "..tostring(result)
end

function ConfigSystem.Deserialize(json)
	if type(json)~="string" or json=="" then return false, "Empty or invalid JSON" end
	local ok, data = SafeCall(function() return HttpService:JSONDecode(json) end)
	if not ok then return false, "JSON decode error: "..tostring(data) end
	if type(data)~="table" then return false, "Decoded data is not a table" end
	local function MergeTable(target, source)
		if type(target)~="table" or type(source)~="table" then return end
		for k,v in pairs(source) do
			if type(v)=="table" and type(target[k])=="table" then MergeTable(target[k],v)
			elseif type(target[k])~="userdata" then target[k]=v end
		end
	end
	for section,tbl in pairs(data) do
		if Settings[section] and type(tbl)=="table" then MergeTable(Settings[section],tbl) end
	end
	return true, "OK"
end

local function GetConfigPath(name)
	local cleanName = name:gsub(CONFIG_EXT.."$","")
	return CONFIG_FOLDER.."/"..cleanName..CONFIG_EXT
end

function ConfigSystem.Save(name)
	if not FS_AVAILABLE then return false, "File system not available" end
	if type(name)~="string" or name:match("^%s*$") then return false, "Invalid config name" end
	local folderOk = EnsureFolder()
	if not folderOk then return false, "Failed to create config folder" end
	local json, serErr = ConfigSystem.Serialize()
	if not json then return false, serErr or "Serialization failed" end
	local path = GetConfigPath(name)
	local ok, err = SafeCall(function() writefile(path,json) end)
	if ok then return true, "Saved to "..path
	else return false, "Write error: "..tostring(err) end
end

function ConfigSystem.Load(name)
	if not FS_AVAILABLE then return false, "File system not available" end
	local path = GetConfigPath(name)
	local exists = false
	SafeCall(function() exists = isfile(path) end)
	if not exists then return false, "Config not found: "..path end
	local ok, json = SafeCall(function() return readfile(path) end)
	if not ok or type(json)~="string" then return false, "Read error: "..tostring(json) end
	if json=="" then return false, "Config file is empty" end
	local success, msg = ConfigSystem.Deserialize(json)
	if success then return true, "Loaded: "..name
	else return false, "Parse error: "..(msg or "unknown") end
end

function ConfigSystem.Delete(name)
	if not FS_AVAILABLE then return false, "File system not available" end
	local path = GetConfigPath(name)
	local ok, err = SafeCall(function() delfile(path) end)
	return ok, ok and "Deleted" or tostring(err)
end

function ConfigSystem.List()
	if not FS_AVAILABLE then return {}, "File system not available" end
	EnsureFolder()
	local list = {}
	local ok, files = SafeCall(function() return listfiles(CONFIG_FOLDER) end)
	if not ok or type(files)~="table" then return {}, "Could not list files: "..tostring(files) end
	local seen = {}
	for _,path in ipairs(files) do
		local filename = tostring(path):match("([^/\\]+)$")
		if filename then
			local baseName = filename:match("^(.+)"..CONFIG_EXT.."$")
			if baseName and not seen[baseName] then
				seen[baseName]=true; table.insert(list,baseName)
			end
		end
	end
	table.sort(list)
	return list, "OK"
end

function ConfigSystem.Export()
	local json, err = ConfigSystem.Serialize()
	if json then return json end
	return nil, err
end

function ConfigSystem.Import(json)
	return ConfigSystem.Deserialize(json)
end

-- =====================================================================
-- VISUALS
-- =====================================================================
local function ApplySky()
	local V = Settings.Visuals
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmo then atmo = Instance.new("Atmosphere", Lighting) end
	if not V.SkyEnabled then
		atmo.Density = 0.395; atmo.Offset = 0
		atmo.Color = Color3.fromRGB(199,199,199)
		atmo.Decay = Color3.fromRGB(106,127,153)
		atmo.Glare = 0; atmo.Haze = 0
		return
	end
	local presets = {
		Night    = {density=0.8, offset=0.25, r=10,  g=10,  b=40,  dr=5,  dg=5,  db=20,  glare=0,   haze=2},
		DeepNight= {density=1.0, offset=0.5,  r=3,   g=3,   b=15,  dr=1,  dg=1,  db=8,   glare=0,   haze=0},
		Sunset   = {density=0.4, offset=0.1,  r=255, g=100, b=50,  dr=180,dg=60, db=20,  glare=0.3, haze=1},
		Fog      = {density=0.9, offset=0,    r=180, g=180, b=180, dr=120,dg=120,db=120, glare=0,   haze=3},
	}
	local p = presets[V.SkyPreset] or presets.Night
	atmo.Density = p.density; atmo.Offset = p.offset
	atmo.Color   = Color3.fromRGB(p.r, p.g, p.b)
	atmo.Decay   = Color3.fromRGB(p.dr, p.dg, p.db)
	atmo.Glare   = p.glare; atmo.Haze = p.haze
end

local function ApplyLighting()
	local V = Settings.Visuals
	pcall(function()
		Lighting.Brightness=V.Brightness
		Lighting.Ambient=Color3.fromRGB(V.AmbientR,V.AmbientG,V.AmbientB)
		Lighting.OutdoorAmbient=Color3.fromRGB(V.OutdoorR,V.OutdoorG,V.OutdoorB)
		Lighting.FogEnd=V.FogEnabled and V.FogEnd or 100000
		Lighting.FogStart=0
	end)
end

-- =====================================================================
-- ESP (Drawing API)
-- =====================================================================
local function HPColor(pct)
	if pct > 0.6 then return Color3.fromRGB(50,220,80)
	elseif pct > 0.3 then return Color3.fromRGB(240,190,30)
	else return Color3.fromRGB(220,50,50) end
end

local espObjects = {}

local SKELETON_PAIRS = {
	{"Head","UpperTorso"},{"UpperTorso","LowerTorso"},
	{"LowerTorso","LeftUpperLeg"},{"LowerTorso","RightUpperLeg"},
	{"LeftUpperLeg","LeftLowerLeg"},{"RightUpperLeg","RightLowerLeg"},
	{"LeftLowerLeg","LeftFoot"},{"RightLowerLeg","RightFoot"},
	{"UpperTorso","LeftUpperArm"},{"UpperTorso","RightUpperArm"},
	{"LeftUpperArm","LeftLowerArm"},{"RightUpperArm","RightLowerArm"},
	{"LeftLowerArm","LeftHand"},{"RightLowerArm","RightHand"},
}

local function NewLine(color, thick)
	local l=Drawing.new("Line"); l.Visible=false; l.Color=color or Color3.new(1,1,1)
	l.Thickness=thick or 1; l.Transparency=1; return l
end

local function NewText(size, color, outline)
	local t=Drawing.new("Text"); t.Visible=false; t.Size=size or 13
	t.Color=color or Color3.new(1,1,1); t.Outline=outline~=false
	t.OutlineColor=Color3.new(0,0,0); t.Center=true; t.Font=Drawing.Fonts.UI; return t
end

local function CreateESPDrawings(model, isPlayer)
	local clr = isPlayer and Color3.fromRGB(255,80,80) or Color3.fromRGB(80,220,255)
	local obj = {
		model=model, isPlayer=isPlayer, color=clr, corners={},
		tracer=NewLine(clr,1.2), hpBG=NewLine(Color3.fromRGB(20,20,20),4),
		hpFill=NewLine(Color3.fromRGB(50,220,80),3),
		nameText=NewText(13,Color3.new(1,1,1)), distText=NewText(11,Color3.fromRGB(180,180,180)),
		weapText=NewText(11,Color3.fromRGB(255,210,80)), skeleton={},
	}
	for i=1,8 do table.insert(obj.corners,NewLine(clr,1.5)) end
	for _=1,#SKELETON_PAIRS do table.insert(obj.skeleton,NewLine(Color3.fromRGB(255,255,255),0.8)) end
	espObjects[model]=obj; return obj
end

local function RemoveESPDrawings(model)
	local obj=espObjects[model]; if not obj then return end
	local function kill(d) pcall(function() d:Remove() end) end
	kill(obj.tracer); kill(obj.hpBG); kill(obj.hpFill)
	kill(obj.nameText); kill(obj.distText); kill(obj.weapText)
	for _,l in ipairs(obj.corners) do kill(l) end
	for _,l in ipairs(obj.skeleton) do kill(l) end
	espObjects[model]=nil
end

local function ClearAllESP()
	for model,_ in pairs(espObjects) do RemoveESPDrawings(model) end
	espObjects={}
end

local function WorldToScreen(pos)
	local sp,vis=Camera:WorldToViewportPoint(pos)
	if not vis or sp.Z<0 then return nil end
	return Vector2.new(sp.X,sp.Y)
end

local function GetBoundingBox(root, head)
	if not root or not head then return nil end
	local sp1=WorldToScreen(head.Position+Vector3.new(0,head.Size.Y*0.5,0))
	local sp2=WorldToScreen(root.Position-Vector3.new(0,2.8,0))
	if not sp1 or not sp2 then return nil end
	local top=math.min(sp1.Y,sp2.Y); local bottom=math.max(sp1.Y,sp2.Y)
	local h=bottom-top; local w=h*0.55; local cx=(sp1.X+sp2.X)*0.5
	return cx,top,w,h
end

local function DrawCornerBox(corners,x,y,w,h,len,clr)
	local pts={
		{Vector2.new(x,y),Vector2.new(x+len,y)},{Vector2.new(x,y),Vector2.new(x,y+len)},
		{Vector2.new(x+w,y),Vector2.new(x+w-len,y)},{Vector2.new(x+w,y),Vector2.new(x+w,y+len)},
		{Vector2.new(x,y+h),Vector2.new(x+len,y+h)},{Vector2.new(x,y+h),Vector2.new(x,y+h-len)},
		{Vector2.new(x+w,y+h),Vector2.new(x+w-len,y+h)},{Vector2.new(x+w,y+h),Vector2.new(x+w,y+h-len)},
	}
	for i,pair in ipairs(pts) do
		corners[i].From=pair[1]; corners[i].To=pair[2]; corners[i].Color=clr; corners[i].Visible=true
	end
end

local function UpdateESP()
	if not Settings.ESP.Enabled then
		for _,obj in pairs(espObjects) do
			obj.tracer.Visible=false; obj.hpBG.Visible=false; obj.hpFill.Visible=false
			obj.nameText.Visible=false; obj.distText.Visible=false; obj.weapText.Visible=false
			for _,l in ipairs(obj.corners) do l.Visible=false end
			for _,l in ipairs(obj.skeleton) do l.Visible=false end
		end
		return
	end
	local myChar=LocalPlayer.Character
	local myRoot=myChar and myChar:FindFirstChild("HumanoidRootPart")
	local screenCenter=Vector2.new(Camera.ViewportSize.X/2,Camera.ViewportSize.Y)
	for model,_ in pairs(espObjects) do
		if not model or not model.Parent then RemoveESPDrawings(model) end
	end
	local targets={}
	if Settings.ESP.ShowPlayers then
		for _,p in ipairs(Players:GetPlayers()) do
			if p~=LocalPlayer and p.Character then
				table.insert(targets,{model=p.Character,isPlayer=true,player=p})
			end
		end
	end
	if Settings.ESP.ShowNPCs then
		local t=tick()
		if t-lastNPCUpdate>NPC_UPDATE_INTERVAL then
			lastNPCUpdate=t; npcCache={}
			for _,obj in ipairs(Workspace:GetDescendants()) do
				if obj:IsA("Model") and obj~=myChar
					and not Players:GetPlayerFromCharacter(obj)
					and obj:FindFirstChild("Humanoid")
					and obj:FindFirstChild("HumanoidRootPart") then
					table.insert(npcCache,obj)
				end
			end
		end
		for _,m in ipairs(npcCache) do table.insert(targets,{model=m,isPlayer=false,player=nil}) end
	end
	for _,tgt in ipairs(targets) do
		local model=tgt.model; local isPlayer=tgt.isPlayer
		local hum=model:FindFirstChild("Humanoid")
		local root=model:FindFirstChild("HumanoidRootPart")
		local head=model:FindFirstChild("Head")
		local function HideObj(obj)
			if not obj then return end
			obj.tracer.Visible=false; obj.hpBG.Visible=false; obj.hpFill.Visible=false
			obj.nameText.Visible=false; obj.distText.Visible=false; obj.weapText.Visible=false
			for _,l in ipairs(obj.corners) do l.Visible=false end
			for _,l in ipairs(obj.skeleton) do l.Visible=false end
		end
		if not hum or not root or not head or hum.Health<=0 then
			RemoveESPDrawings(model)
		else
			local dist=myRoot and (root.Position-myRoot.Position).Magnitude or 0
			if dist>Settings.ESP.MaxDistance then
				HideObj(espObjects[model])
			else
				local obj=espObjects[model]
				if not obj then obj=CreateESPDrawings(model,isPlayer) end
				local clr=isPlayer and Color3.fromRGB(255,80,80) or Color3.fromRGB(80,220,255)
				obj.color=clr
				local cx,boxTop,bw,bh=GetBoundingBox(root,head)
				if cx==nil then
					HideObj(obj)
				else
					local boxX=cx-bw*0.5; local clen=Settings.ESP.CornerLen
					if Settings.ESP.ShowCorners then DrawCornerBox(obj.corners,boxX,boxTop,bw,bh,clen,clr)
					else for _,l in ipairs(obj.corners) do l.Visible=false end end
					if Settings.ESP.ShowTracers then
						local footSP=WorldToScreen(root.Position-Vector3.new(0,2.8,0))
						if footSP then
							obj.tracer.From=screenCenter; obj.tracer.To=footSP
							obj.tracer.Color=clr; obj.tracer.Visible=true
						else obj.tracer.Visible=false end
					else obj.tracer.Visible=false end
					if Settings.ESP.ShowHealth then
						local pct=math.max(0,math.min(1,hum.Health/math.max(hum.MaxHealth,1)))
						local barX=boxX-5; local barH=bh*pct
						obj.hpBG.From=Vector2.new(barX,boxTop); obj.hpBG.To=Vector2.new(barX,boxTop+bh)
						obj.hpBG.Color=Color3.fromRGB(20,20,20); obj.hpBG.Thickness=4; obj.hpBG.Visible=true
						obj.hpFill.From=Vector2.new(barX,boxTop+bh); obj.hpFill.To=Vector2.new(barX,boxTop+bh-barH)
						obj.hpFill.Color=HPColor(pct); obj.hpFill.Thickness=3; obj.hpFill.Visible=true
					else obj.hpBG.Visible=false; obj.hpFill.Visible=false end
					if Settings.ESP.ShowNames then
						local label=""
						if isPlayer and tgt.player then
							label=tgt.player.DisplayName~="" and tgt.player.DisplayName or tgt.player.Name
						else label=model.Name end
						obj.nameText.Text=label; obj.nameText.Position=Vector2.new(cx,boxTop-16)
						obj.nameText.Color=Color3.new(1,1,1); obj.nameText.Visible=true
					else obj.nameText.Visible=false end
					if Settings.ESP.ShowDistance then
						local yOff=Settings.ESP.ShowNames and -3 or -16
						obj.distText.Text=string.format("[%.0fm]",dist)
						obj.distText.Position=Vector2.new(cx,boxTop+yOff-13)
						obj.distText.Color=Color3.fromRGB(180,180,180); obj.distText.Visible=true
					else obj.distText.Visible=false end
					if Settings.ESP.ShowWeapon then
						local weapName=""
						if isPlayer and tgt.player then
							local ch=tgt.player.Character
							if ch then
								local tool=ch:FindFirstChildOfClass("Tool")
								if tool then weapName=tool.Name
								else for _,item in ipairs(tgt.player.Backpack:GetChildren()) do
									if item:IsA("Tool") then weapName=item.Name; break end
								end end
							end
						end
						if weapName~="" then
							obj.weapText.Text="⚔ "..weapName
							obj.weapText.Position=Vector2.new(cx,boxTop+bh+4)
							obj.weapText.Color=Color3.fromRGB(255,210,80); obj.weapText.Visible=true
						else obj.weapText.Visible=false end
					else obj.weapText.Visible=false end
					if Settings.ESP.ShowSkeleton then
						for i,pair in ipairs(SKELETON_PAIRS) do
							local p1=model:FindFirstChild(pair[1]); local p2=model:FindFirstChild(pair[2])
							local line=obj.skeleton[i]
							if p1 and p2 then
								local sp1=WorldToScreen(p1.Position); local sp2=WorldToScreen(p2.Position)
								if sp1 and sp2 then
									line.From=sp1; line.To=sp2; line.Color=Color3.fromRGB(255,255,255); line.Visible=true
								else line.Visible=false end
							else line.Visible=false end
						end
					else for _,l in ipairs(obj.skeleton) do l.Visible=false end end
				end
			end
		end
	end
	local targetSet={}
	for _,tgt in ipairs(targets) do targetSet[tgt.model]=true end
	for model,_ in pairs(espObjects) do
		if not targetSet[model] then RemoveESPDrawings(model) end
	end
end

-- =====================================================================
-- ANTI-AIM
-- =====================================================================
local function StopAntiAim()
	if antiAimConnection then antiAimConnection:Disconnect(); antiAimConnection=nil end
end

local function StartAntiAim()
	StopAntiAim()
	if not Settings.AntiAim.Enabled then return end
	local lastTick,jitterFlip=0,1
	antiAimConnection=RunService.Heartbeat:Connect(function()
		if not Settings.AntiAim.Enabled then return end
		if not LocalPlayer.Character then return end
		local root=LocalPlayer.Character:FindFirstChild("HumanoidRootPart"); if not root then return end
		local now=tick()
		if now-lastTick<Settings.AntiAim.Interval then return end
		lastTick=now
		local angle=0; local mode=Settings.AntiAim.Mode
		if mode=="Random" then angle=math.random(0,360)
		elseif mode=="Spin" then antiAimAngle=(antiAimAngle+Settings.AntiAim.SpinSpeed)%360; angle=antiAimAngle
		elseif mode=="Static" then angle=Settings.AntiAim.StaticAngle
		elseif mode=="Jitter" then jitterFlip=-jitterFlip; angle=Settings.AntiAim.JitterRange*jitterFlip end
		pcall(function()
			root.CFrame=CFrame.new(root.Position)*CFrame.Angles(0,math.rad(angle),0)
		end)
	end)
end

-- =====================================================================
-- ДВИЖЕНИЕ
-- =====================================================================
local function IsOnGround(char)
	if not char or not char:FindFirstChild("HumanoidRootPart") then return false end
	local hum=char:FindFirstChild("Humanoid"); if not hum then return false end
	local s=hum:GetState()
	if s==Enum.HumanoidStateType.Freefall or s==Enum.HumanoidStateType.Flying or s==Enum.HumanoidStateType.Jumping then return false end
	local rp=RaycastParams.new()
	rp.FilterDescendantsInstances={char}; rp.FilterType=Enum.RaycastFilterType.Exclude; rp.IgnoreWater=true
	return Workspace:Raycast(char.HumanoidRootPart.Position,Vector3.new(0,-4,0),rp)~=nil
end

local function DisableBunnyHop()
	if bhopConnection then bhopConnection:Disconnect(); bhopConnection=nil end
end

local function SetupBunnyHop()
	DisableBunnyHop()
	if not Settings.Movement.BunnyHop then return end
	bhopConnection=RunService.Heartbeat:Connect(function()
		if not LocalPlayer.Character then return end
		local hum=LocalPlayer.Character:FindFirstChild("Humanoid")
		local root=LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		if not hum or not root or hum.Health<=0 then return end
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) and Settings.Movement.AutoJump then
			local t=tick()
			if t-lastJumpTime>=jumpCooldown and IsOnGround(LocalPlayer.Character) then
				hum:ChangeState(Enum.HumanoidStateType.Jumping); lastJumpTime=t
			end
		end
		local s=hum:GetState()
		local inAir=s==Enum.HumanoidStateType.Freefall or s==Enum.HumanoidStateType.Jumping or s==Enum.HumanoidStateType.Flying
		if inAir then
			local mv=hum.MoveDirection
			if mv.Magnitude>0 then
				local vel=root.AssemblyLinearVelocity
				if Vector3.new(vel.X,0,vel.Z).Magnitude<Settings.Movement.MaxSpeed then
					local acc=mv*Settings.Movement.BHopSpeed
					root.AssemblyLinearVelocity=Vector3.new(vel.X+acc.X,vel.Y,vel.Z+acc.Z)
				end
			end
		end
	end)
end

-- =====================================================================
-- ТЕЛЕПОРТ
-- =====================================================================
local function GetRandomPlayer()
	local list={}
	for _,p in ipairs(Players:GetPlayers()) do
		if p~=LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
			local h=p.Character:FindFirstChild("Humanoid")
			if h and h.Health>0 then table.insert(list,p) end
		end
	end
	return #list>0 and list[math.random(1,#list)] or nil
end

local function TeleportBehindPlayer(tp)
	if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return false end
	if not tp.Character or not tp.Character:FindFirstChild("HumanoidRootPart") then return false end
	local tr=tp.Character.HumanoidRootPart
	LocalPlayer.Character.HumanoidRootPart.CFrame=CFrame.new(
		tr.Position+(-tr.CFrame.LookVector*Settings.Teleport.Distance),tr.Position)
	return true
end

local function StopTeleport()
	isTeleporting=false; currentTeleportTarget=nil
	if teleportConnection then teleportConnection:Disconnect(); teleportConnection=nil end
end

local function TeleportToRandomPlayer()
	if isTeleporting then return end
	local tp=GetRandomPlayer(); if not tp then return end
	isTeleporting=true; currentTeleportTarget=tp
	local st=tick()
	teleportConnection=RunService.Heartbeat:Connect(function()
		if not isTeleporting or not currentTeleportTarget then
			if teleportConnection then teleportConnection:Disconnect(); teleportConnection=nil end; return
		end
		if tick()-st>=Settings.Teleport.TeleportTime then
			TeleportBehindPlayer(currentTeleportTarget); StopTeleport()
		else TeleportBehindPlayer(currentTeleportTarget) end
	end)
end

-- =====================================================================
-- АИМБОТ
-- =====================================================================
local function IsVisible(from, to, ignore)
	local rp=RaycastParams.new()
	rp.FilterDescendantsInstances={ignore,LocalPlayer.Character}
	rp.FilterType=Enum.RaycastFilterType.Exclude; rp.IgnoreWater=true
	local res=Workspace:Raycast(from,to-from,rp)
	if not res then return true end
	local h=res.Instance
	while h and h.Parent do if h==ignore then return true end; h=h.Parent end
	return false
end

local function GetClosestEnemy()
	if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return nil end
	local best,bestDist=nil,math.huge
	local sc=Vector2.new(Camera.ViewportSize.X/2,Camera.ViewportSize.Y/2)
	for _,p in ipairs(Players:GetPlayers()) do
		if p~=LocalPlayer and p.Character then
			if Settings.Aimbot.IgnoreTeam and p.Team==LocalPlayer.Team and p.Team~=nil then
			else
				local tp=p.Character:FindFirstChild(Settings.Aimbot.TargetPart)
				local h=p.Character:FindFirstChild("Humanoid")
				if tp and h and h.Health>0 then
					local sp,onScreen=Camera:WorldToViewportPoint(tp.Position)
					if onScreen then
						local d=(Vector2.new(sp.X,sp.Y)-sc).Magnitude
						if d<=Settings.Aimbot.FOV and d<bestDist and IsVisible(Camera.CFrame.Position,tp.Position,p.Character) then
							best=p.Character; bestDist=d
						end
					end
				end
			end
		end
	end
	return best
end

local function AimAt(target)
	if not target then return end
	local tp=target:FindFirstChild(Settings.Aimbot.TargetPart); if not tp then return end
	Camera.CFrame=Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position,tp.Position),Settings.Aimbot.Smoothness/100)
end

-- =====================================================================
-- FAKE LAG (forward teleport + cube preview)
-- =====================================================================

local function CreateFakeLagCube()
	if fakeLagCube then
		pcall(function() fakeLagCube:Destroy() end)
	end
	local cube = Instance.new("Part")
	cube.Name           = "FakeLagPreview"
	cube.Size           = Vector3.new(1.5, 1.5, 1.5)
	cube.Anchored       = true
	cube.CanCollide     = false
	cube.CanQuery       = false
	cube.CastShadow     = false
	cube.Transparency   = 0.55
	cube.Material       = Enum.Material.Neon
	cube.Color          = Color3.fromRGB(100, 155, 230)
	cube.Parent         = Workspace

	local sel = Instance.new("SelectionBox")
	sel.Adornee             = cube
	sel.Color3              = Color3.fromRGB(130, 180, 255)
	sel.LineThickness       = 0.03
	sel.SurfaceTransparency = 1
	sel.SurfaceColor3       = Color3.fromRGB(130, 180, 255)
	sel.Parent              = Workspace

	fakeLagCube = cube
end

local function DestroyFakeLagCube()
	if fakeLagCube then
		for _, v in ipairs(Workspace:GetChildren()) do
			if v:IsA("SelectionBox") and v.Adornee == fakeLagCube then
				pcall(function() v:Destroy() end)
			end
		end
		pcall(function() fakeLagCube:Destroy() end)
		fakeLagCube = nil
	end
end

-- Проверка: есть ли земля под позицией (не телепортируем в воздухе)
local function IsGroundBelow(pos, char)
	local rp = RaycastParams.new()
	rp.FilterDescendantsInstances = { char }
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.IgnoreWater = true
	return Workspace:Raycast(pos + Vector3.new(0, 1, 0), Vector3.new(0, -7, 0), rp) ~= nil
end

-- Проверка: нет ли стены между текущей и целевой позицией
local function IsPathClear(fromPos, toPos, char)
	local rp = RaycastParams.new()
	rp.FilterDescendantsInstances = { char }
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.IgnoreWater = true
	local dir = toPos - fromPos
	local res = Workspace:Raycast(fromPos, dir, rp)
	return res == nil
end

local function GetFakeLagTarget(char)
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return nil end
	local dist    = Settings.FakeLag.Distance
	local forward = root.CFrame.LookVector
	local origin  = root.Position
	local flatFwd = Vector3.new(forward.X, 0, forward.Z)
	if flatFwd.Magnitude < 0.001 then return nil end
	local target  = origin + flatFwd.Unit * dist
	if not IsGroundBelow(target, char) then return nil end
	if not IsPathClear(origin + Vector3.new(0, 1, 0), target + Vector3.new(0, 1, 0), char) then return nil end
	return target
end

local function UpdateFakeLagCube()
	if not Settings.FakeLag.Enabled or not Settings.FakeLag.ShowCube then
		if fakeLagCube then
			pcall(function() fakeLagCube.Transparency = 1 end)
		end
		return
	end
	local char = LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		if fakeLagCube then pcall(function() fakeLagCube.Transparency = 1 end) end
		return
	end
	if not fakeLagCube or not fakeLagCube.Parent then
		CreateFakeLagCube()
	end
	local target = GetFakeLagTarget(char)
	if target then
		-- Синий = телепорт возможен
		fakeLagCube.Transparency = 0.55
		fakeLagCube.CFrame       = CFrame.new(target)
		fakeLagCube.Color        = Color3.fromRGB(100, 155, 230)
		for _, v in ipairs(Workspace:GetChildren()) do
			if v:IsA("SelectionBox") and v.Adornee == fakeLagCube then
				v.Color3 = Color3.fromRGB(130, 180, 255)
			end
		end
	else
		-- Красный = заблокировано (стена / воздух)
		local forward = root.CFrame.LookVector
		local flatFwd = Vector3.new(forward.X, 0, forward.Z)
		if flatFwd.Magnitude > 0.001 then
			local blocked = root.Position + flatFwd.Unit * Settings.FakeLag.Distance
			fakeLagCube.Transparency = 0.65
			fakeLagCube.CFrame       = CFrame.new(blocked)
			fakeLagCube.Color        = Color3.fromRGB(200, 60, 60)
			for _, v in ipairs(Workspace:GetChildren()) do
				if v:IsA("SelectionBox") and v.Adornee == fakeLagCube then
					v.Color3 = Color3.fromRGB(200, 60, 60)
				end
			end
		end
	end
end

local function StopFakeLag()
	if fakeLagConnection then
		fakeLagConnection:Disconnect()
		fakeLagConnection = nil
	end
end

local function StartFakeLag()
	StopFakeLag()
	if not Settings.FakeLag.Enabled then return end
	local lastTick = 0
	fakeLagConnection = RunService.Heartbeat:Connect(function()
		if not Settings.FakeLag.Enabled then return end

		local char = LocalPlayer.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum  = char and char:FindFirstChild("Humanoid")
		if not root or not hum or hum.Health <= 0 then return end

		-- Только на земле
		if not IsOnGround(char) then return end

		-- Проверка реальной физической скорости (не MoveDirection)
		local vel = root.AssemblyLinearVelocity
		local horizSpeed = Vector3.new(vel.X, 0, vel.Z).Magnitude
		if horizSpeed < 1 then return end

		local now = tick()
		if now - lastTick < Settings.FakeLag.Interval then return end
		lastTick = now

		local target = GetFakeLagTarget(char)
		if target then
			root.CFrame = CFrame.new(target, target + root.CFrame.LookVector)
		end
	end)
end

-- =====================================================================
-- CHAMS (Highlight-based)
-- =====================================================================
local function GetChamsColor(isPlayer, visible)
	local CH = Settings.Chams
	if isPlayer then
		if visible or not CH.Wallcheck then
			return Color3.fromRGB(CH.PlayerR, CH.PlayerG, CH.PlayerB), CH.Transparency
		else
			return Color3.fromRGB(CH.PlayerWallR, CH.PlayerWallG, CH.PlayerWallB), CH.WallTransparency
		end
	else
		if visible or not CH.Wallcheck then
			return Color3.fromRGB(CH.NPCR, CH.NPCG, CH.NPCB), CH.Transparency
		else
			return Color3.fromRGB(CH.NPCWallR, CH.NPCWallG, CH.NPCWallB), CH.WallTransparency
		end
	end
end

local function IsModelVisible(model)
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	local rp = RaycastParams.new()
	rp.FilterDescendantsInstances = { model, LocalPlayer.Character }
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.IgnoreWater = true
	local res = Workspace:Raycast(Camera.CFrame.Position, root.Position - Camera.CFrame.Position, rp)
	return res == nil
end

local function ApplyChamsToModel(model, isPlayer)
	if chamsHighlights[model] then return end
	local hl = Instance.new("SelectionBox")
	hl.Adornee         = model
	hl.LineThickness   = 0
	hl.SurfaceTransparency = 0.5
	hl.SurfaceColor3   = Color3.fromRGB(255, 60, 60)
	hl.Parent          = model
	chamsHighlights[model] = { hl = hl, isPlayer = isPlayer }
end

local function RemoveChamsFromModel(model)
	local data = chamsHighlights[model]
	if not data then return end
	pcall(function() data.hl:Destroy() end)
	chamsHighlights[model] = nil
end

local function ClearAllChams()
	for model, _ in pairs(chamsHighlights) do
		RemoveChamsFromModel(model)
	end
	chamsHighlights = {}
end

local chamsLastUpdate = 0
local function UpdateChams()
	if not Settings.Chams.Enabled then
		ClearAllChams()
		return
	end

	local now = tick()
	local myChar = LocalPlayer.Character

	-- Собираем цели
	local targets = {}
	if Settings.Chams.Players then
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= LocalPlayer and p.Character then
				local hum = p.Character:FindFirstChild("Humanoid")
				if hum and hum.Health > 0 then
					table.insert(targets, { model = p.Character, isPlayer = true })
				end
			end
		end
	end
	if Settings.Chams.NPCs then
		for _, obj in ipairs(Workspace:GetDescendants()) do
			if obj:IsA("Model") and obj ~= myChar
				and not Players:GetPlayerFromCharacter(obj)
				and obj:FindFirstChild("Humanoid")
				and obj:FindFirstChild("HumanoidRootPart") then
				local hum = obj:FindFirstChild("Humanoid")
				if hum and hum.Health > 0 then
					table.insert(targets, { model = obj, isPlayer = false })
				end
			end
		end
	end

	-- Удаляем чамсы для тех кто исчез
	local targetSet = {}
	for _, t in ipairs(targets) do targetSet[t.model] = true end
	for model, _ in pairs(chamsHighlights) do
		if not targetSet[model] then RemoveChamsFromModel(model) end
	end

	-- Применяем/обновляем
	for _, t in ipairs(targets) do
		local model = t.model
		local isPlayer = t.isPlayer
		if not chamsHighlights[model] then
			ApplyChamsToModel(model, isPlayer)
		end
		local data = chamsHighlights[model]
		if data and data.hl and data.hl.Parent then
			local visible = IsModelVisible(model)
			local color, transp = GetChamsColor(isPlayer, visible)
			data.hl.SurfaceColor3       = color
			data.hl.SurfaceTransparency = transp
			-- Цвет обводки (чуть темнее)
			data.hl.Color3 = Color3.new(
				math.max(0, color.R - 0.15),
				math.max(0, color.G - 0.15),
				math.max(0, color.B - 0.15)
			)
			data.hl.LineThickness = 0.06
		end
	end
end

-- =====================================================================
-- GUI
-- =====================================================================
local function CreateGUI()
	ScreenGui=Instance.new("ScreenGui")
	ScreenGui.Name="RageVoidGUI"; ScreenGui.ResetOnSpawn=false
	ScreenGui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
	ScreenGui.IgnoreGuiInset=true; ScreenGui.DisplayOrder=9999

	-- FOV circle
	FOVCircle=Instance.new("Frame")
	FOVCircle.AnchorPoint=Vector2.new(0.5,0.5)
	FOVCircle.Size=UDim2.new(0,Settings.Aimbot.FOV*2,0,Settings.Aimbot.FOV*2)
	FOVCircle.Position=UDim2.new(0.5,0,0.5,0)
	FOVCircle.BackgroundTransparency=1; FOVCircle.BorderSizePixel=0
	FOVCircle.Visible=false; FOVCircle.ZIndex=5; FOVCircle.Parent=ScreenGui
	Instance.new("UICorner",FOVCircle).CornerRadius=UDim.new(1,0)
	local fovSt=Instance.new("UIStroke",FOVCircle)
	fovSt.Color=C.Accent; fovSt.Thickness=1; fovSt.Transparency=0.4

	-- WATERMARK
	WatermarkFrame=Instance.new("Frame",ScreenGui)
	WatermarkFrame.Size=UDim2.new(0,400,0,28)
	WatermarkFrame.Position=UDim2.new(0,755,0,90)
	WatermarkFrame.BackgroundColor3=C.Header
	WatermarkFrame.BorderSizePixel=0
	WatermarkFrame.ZIndex=100
	WatermarkFrame.Visible=Settings.Watermark.Enabled
	Instance.new("UICorner",WatermarkFrame).CornerRadius=UDim.new(0,4)
	local wmStroke=Instance.new("UIStroke",WatermarkFrame)
	wmStroke.Color=C.Border; wmStroke.Thickness=1; wmStroke.Transparency=0

	-- Синяя полоска сверху
	local wmTopBar=Instance.new("Frame",WatermarkFrame)
	wmTopBar.Size=UDim2.new(1,0,0,2)
	wmTopBar.Position=UDim2.new(0,0,0,0)
	wmTopBar.BackgroundColor3=C.Accent
	wmTopBar.BorderSizePixel=0; wmTopBar.ZIndex=103
	Instance.new("UICorner",wmTopBar).CornerRadius=UDim.new(0,4)
	local wmTopFix=Instance.new("Frame",wmTopBar)
	wmTopFix.Size=UDim2.new(1,0,0.5,0); wmTopFix.Position=UDim2.new(0,0,0.5,0)
	wmTopFix.BackgroundColor3=C.Accent; wmTopFix.BorderSizePixel=0; wmTopFix.ZIndex=103

	-- Название слева
	local wmLbl=Instance.new("TextLabel",WatermarkFrame)
	wmLbl.Size=UDim2.new(0,180,1,0); wmLbl.Position=UDim2.new(0,10,0,0)
	wmLbl.BackgroundTransparency=1
	wmLbl.Text="RAGEVOID  · alpha v0.9.2  ·  cloudbound.dev"
	wmLbl.TextColor3=C.Text; wmLbl.Font=Enum.Font.GothamBold
	wmLbl.TextSize=11; wmLbl.TextXAlignment=Enum.TextXAlignment.Left
	wmLbl.ZIndex=101

	-- Время посередине
	local wmTime=Instance.new("TextLabel",WatermarkFrame)
	wmTime.Size=UDim2.new(0,150,1,0); wmTime.Position=UDim2.new(0,200,0,0)
	wmTime.BackgroundTransparency=1
	wmTime.Text="--:--:--"
	wmTime.TextColor3=C.Dim; wmTime.Font=Enum.Font.GothamBold
	wmTime.TextSize=11; wmTime.TextXAlignment=Enum.TextXAlignment.Center
	wmTime.ZIndex=101

	-- Пинг
	local wmPing=Instance.new("TextLabel",WatermarkFrame)
	wmPing.Size=UDim2.new(0,100,1,0); wmPing.Position=UDim2.new(0,278,0,0)
	wmPing.BackgroundTransparency=1
	wmPing.Text="-- ms"
	wmPing.TextColor3=C.Green; wmPing.Font=Enum.Font.GothamBold
	wmPing.TextSize=11; wmPing.TextXAlignment=Enum.TextXAlignment.Center
	wmPing.ZIndex=101

	-- FPS справа
	local wmFPS=Instance.new("TextLabel",WatermarkFrame)
	wmFPS.Size=UDim2.new(0,70,1,0); wmFPS.Position=UDim2.new(1,-74,0,0)
	wmFPS.BackgroundTransparency=1
	wmFPS.Text="-- fps"
	wmFPS.TextColor3=C.Green; wmFPS.Font=Enum.Font.GothamBold
	wmFPS.TextSize=11; wmFPS.TextXAlignment=Enum.TextXAlignment.Right
	wmFPS.ZIndex=102

	local wmFrames, wmLastTick = 0, tick()
	RunService.RenderStepped:Connect(function()
		wmFrames = wmFrames + 1
		local now = tick()
		if now - wmLastTick >= 0.5 then
			local fps = math.floor(wmFrames / (now - wmLastTick))
			wmFrames = 0; wmLastTick = now
			wmFPS.Text = fps.." fps"
			wmFPS.TextColor3 = fps>=60 and C.Green or (fps>=30 and C.Orange or C.Red)
			local ping = math.floor(LocalPlayer:GetNetworkPing()*1000)
			wmPing.Text = ping.." ms"
			wmPing.TextColor3 = ping<80 and C.Green or (ping<150 and C.Orange or C.Red)
		end
		local h=math.floor(os.time()/3600)%24
		local m=math.floor(os.time()/60)%60
		local s=os.time()%60
		wmTime.Text=string.format("%02d:%02d:%02d",h,m,s)
	end)

	-- МОБИЛЬНАЯ ПОДДЕРЖКА
	local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local VP = workspace.CurrentCamera.ViewportSize

	-- Кнопка открытия меню на телефоне
	local MobileBtn = Instance.new("TextButton", ScreenGui)
	MobileBtn.Size = UDim2.new(0,48,0,48)
	MobileBtn.Position = UDim2.new(0,8,0,60)
	MobileBtn.BackgroundColor3 = C.AccentBG
	MobileBtn.BorderSizePixel = 0
	MobileBtn.Text = "☰"
	MobileBtn.TextColor3 = C.Accent
	MobileBtn.Font = Enum.Font.GothamBold
	MobileBtn.TextSize = 22
	MobileBtn.ZIndex = 100
	MobileBtn.Visible = isMobile
	Instance.new("UICorner", MobileBtn).CornerRadius = UDim.new(0,10)
	local mbSt = Instance.new("UIStroke", MobileBtn)
	mbSt.Color = C.Border; mbSt.Thickness = 1

	-- ПАНЕЛЬ БЫСТРЫХ КНОПОК (вместо KBFrame с кейбиндами)
	local KBFrame = Instance.new("Frame", ScreenGui)
	KBFrame.Size = UDim2.new(0, 150, 0, 0)
	KBFrame.Position = UDim2.new(1, -160, 0, 80)
	KBFrame.BackgroundColor3 = C.Header
	KBFrame.BackgroundTransparency = 0
	KBFrame.BorderSizePixel = 0
	KBFrame.ZIndex = 55
	KBFrame.AutomaticSize = Enum.AutomaticSize.Y
	KBFrame.Active = true; KBFrame.Draggable = true
	Instance.new("UICorner", KBFrame).CornerRadius = UDim.new(0,6)
	local kbSt = Instance.new("UIStroke", KBFrame)
	kbSt.Color = C.Border; kbSt.Thickness = 1
	local kbPad = Instance.new("UIPadding", KBFrame)
	kbPad.PaddingLeft = UDim.new(0,6); kbPad.PaddingRight = UDim.new(0,6)
	kbPad.PaddingTop = UDim.new(0,6); kbPad.PaddingBottom = UDim.new(0,6)
	local kbLayout = Instance.new("UIListLayout", KBFrame)
	kbLayout.Padding = UDim.new(0,4); kbLayout.SortOrder = Enum.SortOrder.LayoutOrder

	local kbTitle = Instance.new("TextLabel", KBFrame)
	kbTitle.Size = UDim2.new(1,0,0,14)
	kbTitle.BackgroundTransparency = 1
	kbTitle.Text = IS_MOBILE and "QUICK ACTIONS" or "KEYBINDS"
	kbTitle.TextColor3 = C.Dim; kbTitle.Font = Enum.Font.GothamBold
	kbTitle.TextSize = 9; kbTitle.TextXAlignment = Enum.TextXAlignment.Center
	kbTitle.LayoutOrder = 0

	local kbDiv = Instance.new("Frame", KBFrame)
	kbDiv.Size = UDim2.new(1,0,0,1)
	kbDiv.BackgroundColor3 = C.Border; kbDiv.BorderSizePixel = 0
	kbDiv.LayoutOrder = 1

	-- Состояния кнопок
	local actionStates = {
		ESP = false, Aimbot = false, FakeLag = false,
		BHop = false, AntiAim = false,
	}
	local actionButtons = {}

	local ACTIONS = {
		{ id="ESP",     label="ESP",      order=2 },
		{ id="Aimbot",  label="Aimbot",   order=3 },
		{ id="AntiAim", label="Anti-Aim", order=4 },
		{ id="BHop",    label="BHop",     order=5 },
		{ id="FakeLag", label="Fake Lag", order=6 },
		{ id="QuickTP", label="Quick TP", order=7 },
	}

	local function UpdateActionBtn(id)
		local btn = actionButtons[id]
		if not btn then return end
		if id == "QuickTP" then
			btn.BackgroundColor3 = C.AccentDim
			btn.TextColor3 = C.Text
		elseif actionStates[id] then
			btn.BackgroundColor3 = C.ToggleOn
			btn.TextColor3 = C.Text
		else
			btn.BackgroundColor3 = C.Row
			btn.TextColor3 = C.Dim
		end
	end

	local function FireAction(id)
		if id == "ESP" then
			Settings.ESP.Enabled = not Settings.ESP.Enabled
			actionStates.ESP = Settings.ESP.Enabled
			if not Settings.ESP.Enabled then ClearAllESP() end
		elseif id == "Aimbot" then
			Settings.Aimbot.Enabled = not Settings.Aimbot.Enabled
			actionStates.Aimbot = Settings.Aimbot.Enabled
			if FOVCircle then FOVCircle.Visible = Settings.Aimbot.Enabled and Settings.Aimbot.ShowFOV end
		elseif id == "AntiAim" then
			Settings.AntiAim.Enabled = not Settings.AntiAim.Enabled
			actionStates.AntiAim = Settings.AntiAim.Enabled
			if Settings.AntiAim.Enabled then StartAntiAim() else StopAntiAim() end
		elseif id == "BHop" then
			Settings.Movement.BunnyHop = not Settings.Movement.BunnyHop
			actionStates.BHop = Settings.Movement.BunnyHop
			if Settings.Movement.BunnyHop then SetupBunnyHop() else DisableBunnyHop() end
		elseif id == "FakeLag" then
			Settings.FakeLag.Enabled = not Settings.FakeLag.Enabled
			actionStates.FakeLag = Settings.FakeLag.Enabled
			if Settings.FakeLag.Enabled then StartFakeLag() else StopFakeLag(); DestroyFakeLagCube() end
		elseif id == "QuickTP" then
			if isTeleporting then StopTeleport(); task.wait(0.2) end
			TeleportToRandomPlayer()
		end
		UpdateActionBtn(id)
	end

	local kbDynLabels = {}

	if IS_MOBILE then
		-- На мобиле: кнопки быстрых действий
		for _, act in ipairs(ACTIONS) do
			local btn = Instance.new("TextButton", KBFrame)
			btn.Size = UDim2.new(1,0,0,26)
			btn.BackgroundColor3 = C.Row
			btn.BorderSizePixel = 0
			btn.Text = act.label
			btn.TextColor3 = C.Dim
			btn.Font = Enum.Font.GothamBold
			btn.TextSize = 11
			btn.ZIndex = 56
			btn.LayoutOrder = act.order
			Instance.new("UICorner", btn).CornerRadius = UDim.new(0,4)
			actionButtons[act.id] = btn
			UpdateActionBtn(act.id)
			btn.MouseButton1Click:Connect(function() FireAction(act.id) end)
		end
	else
		-- На ПК: строки с кейбиндами
		KBFrame.Size = UDim2.new(0,180,0,0)
		KBFrame.Position = UDim2.new(1,-190,0,80)
		for _, kb in ipairs(KEYBIND_IDS) do
			local row = Instance.new("Frame", KBFrame)
			row.Size = UDim2.new(1,0,0,18)
			row.BackgroundTransparency = 1
			row.BorderSizePixel = 0
			row.LayoutOrder = 10
			local keyLbl = Instance.new("TextLabel", row)
			keyLbl.Size = UDim2.new(0,55,1,0)
			keyLbl.BackgroundColor3 = C.AccentBG
			keyLbl.BorderSizePixel = 0
			keyLbl.Text = Settings.Keybinds[kb.id] or "None"
			keyLbl.TextColor3 = C.Accent
			keyLbl.Font = Enum.Font.GothamBold
			keyLbl.TextSize = 9
			keyLbl.TextXAlignment = Enum.TextXAlignment.Center
			Instance.new("UICorner", keyLbl).CornerRadius = UDim.new(0,3)
			local nameLbl = Instance.new("TextLabel", row)
			nameLbl.Size = UDim2.new(1,-60,1,0)
			nameLbl.Position = UDim2.new(0,60,0,0)
			nameLbl.BackgroundTransparency = 1
			nameLbl.Text = kb.id
			nameLbl.TextColor3 = C.Dim
			nameLbl.Font = Enum.Font.Gotham
			nameLbl.TextSize = 9
			nameLbl.TextXAlignment = Enum.TextXAlignment.Left
			kbDynLabels[kb.id] = keyLbl
		end
	end

	-- ГЛАВНОЕ ОКНО
	local SW,CW,WH
	if IS_MOBILE then
		SW=72; CW=222; WH=288
	else
		SW=120; CW=370; WH=480
	end
	local WW=SW+CW
	local Window=Instance.new("Frame",ScreenGui)
	Window.Name="Window"; Window.Size=UDim2.new(0,WW,0,WH)
	Window.Position=UDim2.new(0.05,0,0.1,0)
	Window.BackgroundColor3=C.BG; Window.BorderSizePixel=0
	Window.Active=true; Window.Draggable=true
	Window.Visible=false; Window.ZIndex=20
	Instance.new("UICorner",Window).CornerRadius=UDim.new(0,6)
	local winSt=Instance.new("UIStroke",Window)
	winSt.Color=C.Border; winSt.Thickness=1

	-- Мобильный drag (Touch)
	do
		local dragActive=false; local dragStartPos, dragStartOff
		Window.InputBegan:Connect(function(inp)
			if inp.UserInputType==Enum.UserInputType.Touch then
				dragActive=true; dragStartPos=inp.Position; dragStartOff=Window.Position
			end
		end)
		Window.InputEnded:Connect(function(inp)
			if inp.UserInputType==Enum.UserInputType.Touch then dragActive=false end
		end)
		Window.InputChanged:Connect(function(inp)
			if dragActive and inp.UserInputType==Enum.UserInputType.Touch then
				local d=inp.Position-dragStartPos
				Window.Position=UDim2.new(dragStartOff.X.Scale,dragStartOff.X.Offset+d.X,dragStartOff.Y.Scale,dragStartOff.Y.Offset+d.Y)
			end
		end)
	end

	-- Мобильная кнопка открытия меню
	MobileBtn.MouseButton1Click:Connect(function()
		Window.Visible = not Window.Visible
	end)

	local TitleBar=Instance.new("Frame",Window)
	local TB_H = IS_MOBILE and 20 or 28
	TitleBar.Size=UDim2.new(0,WW,0,TB_H); TitleBar.Position=UDim2.new(0,0,0,0)
	TitleBar.BackgroundColor3=C.Header; TitleBar.BorderSizePixel=0; TitleBar.ZIndex=21
	Instance.new("UICorner",TitleBar).CornerRadius=UDim.new(0,6)
	local tbFix=Instance.new("Frame",TitleBar)
	tbFix.Size=UDim2.new(1,0,0,8); tbFix.Position=UDim2.new(0,0,1,-8)
	tbFix.BackgroundColor3=C.Header; tbFix.BorderSizePixel=0; tbFix.ZIndex=21
	local titleLine=Instance.new("Frame",Window)
	titleLine.Size=UDim2.new(0,WW,0,1); titleLine.Position=UDim2.new(0,0,0,TB_H)
	titleLine.BackgroundColor3=C.Border; titleLine.BorderSizePixel=0; titleLine.ZIndex=22
	local titleLbl=Instance.new("TextLabel",TitleBar)
	titleLbl.Size=UDim2.new(1,-SW,0,TB_H); titleLbl.Position=UDim2.new(0,SW,0,0)
	titleLbl.BackgroundTransparency=1
	titleLbl.Text="RAGEVOID  ·  alpha v0.9"
	titleLbl.TextColor3=C.Text; titleLbl.Font=Enum.Font.GothamBold
	titleLbl.TextSize= IS_MOBILE and 7 or 11; titleLbl.ZIndex=22
	local titleDot=Instance.new("Frame",TitleBar)
	titleDot.Size=UDim2.new(0,4,0,4); titleDot.Position=UDim2.new(0,SW+6,0.5,-2)
	titleDot.BackgroundColor3=C.Accent; titleDot.BorderSizePixel=0; titleDot.ZIndex=23
	Instance.new("UICorner",titleDot).CornerRadius=UDim.new(1,0)

	local Sidebar=Instance.new("Frame",Window)
	Sidebar.Size=UDim2.new(0,SW,1,-TB_H); Sidebar.Position=UDim2.new(0,0,0,TB_H)
	Sidebar.BackgroundColor3=C.Sidebar; Sidebar.BorderSizePixel=0; Sidebar.ZIndex=21
	local sideDiv=Instance.new("Frame",Window)
	sideDiv.Size=UDim2.new(0,1,1,-TB_H); sideDiv.Position=UDim2.new(0,SW,0,TB_H)
	sideDiv.BackgroundColor3=C.Border; sideDiv.BorderSizePixel=0; sideDiv.ZIndex=22
	local ContentPanel=Instance.new("Frame",Window)
	ContentPanel.Size=UDim2.new(0,CW-1,1,-TB_H); ContentPanel.Position=UDim2.new(0,SW+1,0,TB_H)
	ContentPanel.BackgroundColor3=C.Content; ContentPanel.BorderSizePixel=0; ContentPanel.ZIndex=21

	-- TABS
	local tabList={}
	local TAB_H   = IS_MOBILE and 24 or 36
	local TAB_PAD = IS_MOBILE and 4  or 6
	local TAB_ICON= IS_MOBILE and 11 or 16

	local function CreateTab(name, iconId, order)
		local TabBtn=Instance.new("TextButton",Sidebar)
		TabBtn.Size=UDim2.new(1,0,0,TAB_H)
		TabBtn.Position=UDim2.new(0,0,0,TAB_PAD+(order-1)*(TAB_H+2))
		TabBtn.BackgroundColor3=C.Sidebar; TabBtn.BorderSizePixel=0
		TabBtn.Text=""; TabBtn.AutoButtonColor=false; TabBtn.ZIndex=22
		local Ind=Instance.new("Frame",TabBtn)
		Ind.Size=UDim2.new(0,2,0,TAB_H-12); Ind.Position=UDim2.new(1,-2,0.5,-(TAB_H-12)/2)
		Ind.BackgroundColor3=C.TabInd; Ind.BorderSizePixel=0; Ind.Visible=false; Ind.ZIndex=25
		Instance.new("UICorner",Ind).CornerRadius=UDim.new(1,0)
		local Icon=Instance.new("ImageLabel",TabBtn)
		Icon.Size=UDim2.new(0,TAB_ICON,0,TAB_ICON)
		Icon.Position=UDim2.new(0,10,0.5,-TAB_ICON/2)
		Icon.BackgroundTransparency=1; Icon.Image=iconId
		Icon.ImageColor3=C.Dimmer; Icon.ScaleType=Enum.ScaleType.Fit; Icon.ZIndex=23
		local Lbl=Instance.new("TextLabel",TabBtn)
		Lbl.Size=UDim2.new(1,-(10+TAB_ICON+8),1,0)
		Lbl.Position=UDim2.new(0,10+TAB_ICON+8,0,0)
		Lbl.BackgroundTransparency=1; Lbl.Text=name:upper()
		Lbl.TextColor3=C.Dimmer; Lbl.Font=Enum.Font.GothamSemibold
		Lbl.TextSize= IS_MOBILE and 7 or 10; Lbl.TextXAlignment=Enum.TextXAlignment.Left; Lbl.ZIndex=23
		local Content=Instance.new("ScrollingFrame",ContentPanel)
		Content.Size=UDim2.new(1,-10,1,-8); Content.Position=UDim2.new(0,5,0,4)
		Content.BackgroundTransparency=1; Content.BorderSizePixel=0
		Content.ScrollBarThickness=3; Content.ScrollBarImageColor3=C.Dimmer
		Content.Visible=false; Content.CanvasSize=UDim2.new(0,0,0,0)
		Content.AutomaticCanvasSize=Enum.AutomaticSize.Y; Content.ZIndex=22
		local CList=Instance.new("UIListLayout",Content)
		CList.Padding=UDim.new(0,6); CList.SortOrder=Enum.SortOrder.LayoutOrder
		Instance.new("UIPadding",Content).PaddingTop=UDim.new(0,6)
		table.insert(tabList,{btn=TabBtn,content=Content,icon=Icon,lbl=Lbl,ind=Ind})
		TabBtn.MouseButton1Click:Connect(function()
			for _,t in pairs(tabList) do
				t.content.Visible=false
				t.btn.BackgroundColor3=C.Sidebar
				t.icon.ImageColor3=C.Dimmer; t.lbl.TextColor3=C.Dimmer
				t.ind.Visible=false
			end
			Content.Visible=true
			TabBtn.BackgroundColor3=C.ActiveTab
			Icon.ImageColor3=C.Accent; Lbl.TextColor3=C.Text
			Ind.Visible=true
		end)
		if order==1 then
			Content.Visible=true; TabBtn.BackgroundColor3=C.ActiveTab
			Icon.ImageColor3=C.Accent; Lbl.TextColor3=C.Text; Ind.Visible=true
		end
		return Content
	end

	-- UI HELPERS
	local TS  = IS_MOBILE and 9  or 11  -- text size
	local TSS = IS_MOBILE and 7  or 9   -- small text size
	local RH  = IS_MOBILE and 22 or 28  -- row height
	local BH  = IS_MOBILE and 22 or 26  -- button height
	local SLH = IS_MOBILE and 14 or 18  -- section label height
	local function SectionLabel(parent, text)
		local Wrap=Instance.new("Frame",parent)
		Wrap.Size=UDim2.new(1,0,0,SLH); Wrap.BackgroundTransparency=1; Wrap.ZIndex=23
		local line=Instance.new("Frame",Wrap)
		line.Size=UDim2.new(1,0,0,1); line.Position=UDim2.new(0,0,1,-1)
		line.BackgroundColor3=C.Border; line.BorderSizePixel=0; line.ZIndex=23
		local lbl=Instance.new("TextLabel",Wrap)
		lbl.Size=UDim2.new(1,0,0,SLH-3); lbl.Position=UDim2.new(0,0,0,0)
		lbl.BackgroundTransparency=1
		lbl.Text=text:upper()
		lbl.TextColor3=C.Dimmer; lbl.Font=Enum.Font.GothamBold; lbl.TextSize=TSS
		lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.ZIndex=24
	end

	local function Toggle(parent, text, default, cb)
		local Row=Instance.new("Frame",parent)
		Row.Size=UDim2.new(1,0,0,RH); Row.BackgroundColor3=C.Row
		Row.BorderSizePixel=0; Row.ZIndex=23
		Instance.new("UICorner",Row).CornerRadius=UDim.new(0,4)
		local Hover=Instance.new("Frame",Row)
		Hover.Size=UDim2.new(1,0,1,0); Hover.BackgroundColor3=Color3.fromRGB(255,255,255)
		Hover.BackgroundTransparency=1; Hover.BorderSizePixel=0; Hover.ZIndex=23
		Instance.new("UICorner",Hover).CornerRadius=UDim.new(0,4)
		local RowLbl=Instance.new("TextLabel",Row)
		RowLbl.Size=UDim2.new(0.72,0,1,0); RowLbl.Position=UDim2.new(0,7,0,0)
		RowLbl.BackgroundTransparency=1; RowLbl.Text=text; RowLbl.TextColor3=C.Text
		RowLbl.Font=Enum.Font.GothamSemibold; RowLbl.TextSize=TS
		RowLbl.TextXAlignment=Enum.TextXAlignment.Left; RowLbl.ZIndex=24
		local Track=Instance.new("Frame",Row)
		Track.Size=UDim2.new(0,26,0,14)
		Track.Position=UDim2.new(1,-32,0.5,-7)
		Track.BackgroundColor3=default and C.ToggleOn or C.ToggleOff
		Track.BorderSizePixel=0; Track.ZIndex=24
		Instance.new("UICorner",Track).CornerRadius=UDim.new(1,0)
		local Knob=Instance.new("Frame",Track)
		Knob.Size=UDim2.new(0,9,0,9)
		Knob.Position=default and UDim2.new(1,-11,0.5,-4.5) or UDim2.new(0,2,0.5,-4.5)
		Knob.BackgroundColor3=Color3.new(1,1,1); Knob.BorderSizePixel=0; Knob.ZIndex=25
		Instance.new("UICorner",Knob).CornerRadius=UDim.new(1,0)
		local enabled=default
		local Click=Instance.new("TextButton",Row)
		Click.Size=UDim2.new(1,0,1,0); Click.BackgroundTransparency=1; Click.Text=""; Click.ZIndex=26
		Click.MouseEnter:Connect(function() Hover.BackgroundTransparency=0.96 end)
		Click.MouseLeave:Connect(function() Hover.BackgroundTransparency=1 end)
		Click.MouseButton1Click:Connect(function()
			enabled=not enabled
			Track.BackgroundColor3=enabled and C.ToggleOn or C.ToggleOff
			Knob.Position=enabled and UDim2.new(1,-11,0.5,-4.5) or UDim2.new(0,2,0.5,-4.5)
			cb(enabled)
		end)
		local function SetState(val)
			enabled=val
			Track.BackgroundColor3=val and C.ToggleOn or C.ToggleOff
			Knob.Position=val and UDim2.new(1,-11,0.5,-4.5) or UDim2.new(0,2,0.5,-4.5)
		end
		return Row, SetState
	end

	local function Slider(parent, text, min, max, default, cb)
		local Frame=Instance.new("Frame",parent)
		Frame.Size=UDim2.new(1,0,0,RH+12); Frame.BackgroundColor3=C.Row
		Frame.BorderSizePixel=0; Frame.ZIndex=23
		Instance.new("UICorner",Frame).CornerRadius=UDim.new(0,4)
		local SlLbl=Instance.new("TextLabel",Frame)
		SlLbl.Size=UDim2.new(0.7,0,0,RH-4); SlLbl.Position=UDim2.new(0,7,0,4)
		SlLbl.BackgroundTransparency=1; SlLbl.Text=text; SlLbl.TextColor3=C.Text
		SlLbl.Font=Enum.Font.GothamSemibold; SlLbl.TextSize=TS
		SlLbl.TextXAlignment=Enum.TextXAlignment.Left; SlLbl.ZIndex=24
		local ValLbl=Instance.new("TextLabel",Frame)
		ValLbl.Size=UDim2.new(0.28,0,0,RH-4); ValLbl.Position=UDim2.new(0.72,0,0,4)
		ValLbl.BackgroundTransparency=1; ValLbl.Text=tostring(default)
		ValLbl.TextColor3=C.Accent; ValLbl.Font=Enum.Font.GothamBold; ValLbl.TextSize=TS
		ValLbl.TextXAlignment=Enum.TextXAlignment.Right; ValLbl.ZIndex=24
		local BarBG=Instance.new("Frame",Frame)
		BarBG.Size=UDim2.new(1,-14,0,4); BarBG.Position=UDim2.new(0,7,0,24)
		BarBG.BackgroundColor3=C.SliderBG; BarBG.BorderSizePixel=0; BarBG.ZIndex=24
		Instance.new("UICorner",BarBG).CornerRadius=UDim.new(1,0)
		local Fill=Instance.new("Frame",BarBG)
		Fill.Size=UDim2.new((default-min)/(max-min),0,1,0)
		Fill.BackgroundColor3=C.SliderFill; Fill.BorderSizePixel=0; Fill.ZIndex=25
		Instance.new("UICorner",Fill).CornerRadius=UDim.new(1,0)
		local Handle=Instance.new("Frame",Fill)
		Handle.Size=UDim2.new(0,7,0,7); Handle.Position=UDim2.new(1,-3.5,0.5,-3.5)
		Handle.BackgroundColor3=Color3.new(1,1,1); Handle.BorderSizePixel=0; Handle.ZIndex=26
		Instance.new("UICorner",Handle).CornerRadius=UDim.new(1,0)
		local Btn=Instance.new("TextButton",BarBG)
		Btn.Size=UDim2.new(1,0,0,18); Btn.Position=UDim2.new(0,0,-1.5,0)
		Btn.BackgroundTransparency=1; Btn.Text=""; Btn.ZIndex=27
		local dragging=false
		local function Update(x)
			local rel=math.max(0,math.min(1,(x-BarBG.AbsolutePosition.X)/BarBG.AbsoluteSize.X))
			local v=math.floor(min+(max-min)*rel+0.5)
			v=math.max(min,math.min(max,v))
			Fill.Size=UDim2.new((v-min)/(max-min),0,1,0)
			ValLbl.Text=tostring(v); cb(v)
		end
		local function SetValue(v)
			v=math.max(min,math.min(max,v))
			Fill.Size=UDim2.new((v-min)/(max-min),0,1,0); ValLbl.Text=tostring(v)
		end
		Btn.MouseButton1Down:Connect(function() dragging=true end)
		Btn.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch then dragging=true end end)
		Btn.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch then dragging=false end end)
		UserInputService.InputEnded:Connect(function(i)
			if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end
		end)
		UserInputService.InputChanged:Connect(function(i)
			if dragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then Update(i.Position.X) end
		end)
		Btn.MouseButton1Click:Connect(function() Update(UserInputService:GetMouseLocation().X) end)
		return Frame, SetValue
	end

	local function Button(parent, text, color, cb)
		local Btn=Instance.new("TextButton",parent)
		Btn.Size=UDim2.new(1,0,0,BH); Btn.BackgroundColor3=color or C.Accent
		Btn.BorderSizePixel=0; Btn.Text=text; Btn.TextColor3=Color3.new(1,1,1)
		Btn.Font=Enum.Font.GothamBold; Btn.TextSize=TS; Btn.ZIndex=23
		Instance.new("UICorner",Btn).CornerRadius=UDim.new(0,4)
		Btn.MouseEnter:Connect(function()
			Btn.BackgroundColor3=Color3.new(
				math.min((color or C.Accent).R+0.06,1),
				math.min((color or C.Accent).G+0.06,1),
				math.min((color or C.Accent).B+0.06,1)
			)
		end)
		Btn.MouseLeave:Connect(function() Btn.BackgroundColor3=color or C.Accent end)
		Btn.MouseButton1Click:Connect(cb)
		return Btn
	end

	local function TextInput(parent, labelText, placeholder)
		local Wrap=Instance.new("Frame",parent)
		Wrap.Size=UDim2.new(1,0,0,RH+16); Wrap.BackgroundColor3=C.Row
		Wrap.BorderSizePixel=0; Wrap.ZIndex=23
		Instance.new("UICorner",Wrap).CornerRadius=UDim.new(0,4)
		local Lbl=Instance.new("TextLabel",Wrap)
		Lbl.Size=UDim2.new(1,-10,0,RH-8); Lbl.Position=UDim2.new(0,7,0,3)
		Lbl.BackgroundTransparency=1; Lbl.Text=labelText; Lbl.TextColor3=C.Dim
		Lbl.Font=Enum.Font.GothamSemibold; Lbl.TextSize=TSS
		Lbl.TextXAlignment=Enum.TextXAlignment.Left; Lbl.ZIndex=24
		local Input=Instance.new("TextBox",Wrap)
		Input.Size=UDim2.new(1,-14,0,RH-6); Input.Position=UDim2.new(0,7,0,RH+2)
		Input.BackgroundColor3=C.SliderBG; Input.BorderSizePixel=0
		Input.Text=""; Input.PlaceholderText=placeholder
		Input.TextColor3=C.Text; Input.PlaceholderColor3=C.Dimmer
		Input.Font=Enum.Font.GothamSemibold; Input.TextSize=TSS
		Input.TextXAlignment=Enum.TextXAlignment.Left
		Input.ClearTextOnFocus=false; Input.ZIndex=25
		Instance.new("UICorner",Input).CornerRadius=UDim.new(0,3)
		return Wrap, function() return Input.Text end, function(v) Input.Text=v end, Input
	end

	local function Dropdown(parent, text, options, default, cb)
		local DF=Instance.new("Frame",parent)
		DF.Size=UDim2.new(1,0,0,RH); DF.BackgroundColor3=C.Row
		DF.BorderSizePixel=0; DF.ZIndex=23; DF.ClipsDescendants=false
		Instance.new("UICorner",DF).CornerRadius=UDim.new(0,4)
		local DLbl=Instance.new("TextLabel",DF)
		DLbl.Size=UDim2.new(0.5,0,1,0); DLbl.Position=UDim2.new(0,7,0,0)
		DLbl.BackgroundTransparency=1; DLbl.Text=text; DLbl.TextColor3=C.Text
		DLbl.Font=Enum.Font.GothamSemibold; DLbl.TextSize=TS
		DLbl.TextXAlignment=Enum.TextXAlignment.Left; DLbl.ZIndex=24
		local DBtn=Instance.new("TextButton",DF)
		DBtn.Size=UDim2.new(0,90,0,RH-6); DBtn.Position=UDim2.new(1,-96,0.5,-(RH-6)/2)
		DBtn.BackgroundColor3=C.SliderBG; DBtn.BorderSizePixel=0
		DBtn.Text=default.."  ▾"; DBtn.TextColor3=C.Accent
		DBtn.Font=Enum.Font.GothamBold; DBtn.TextSize=TS; DBtn.ZIndex=25
		Instance.new("UICorner",DBtn).CornerRadius=UDim.new(0,3)
		local DList=Instance.new("Frame",DF)
		DList.Size=UDim2.new(0,90,0,#options*(RH-2)); DList.Position=UDim2.new(1,-96,1,2)
		DList.BackgroundColor3=C.Header; DList.BorderSizePixel=0; DList.Visible=false; DList.ZIndex=80
		Instance.new("UICorner",DList).CornerRadius=UDim.new(0,4)
		local dlSt=Instance.new("UIStroke",DList); dlSt.Color=C.Border; dlSt.Thickness=1
		local function SetSelected(opt)
			DBtn.Text=opt.."  ▾"; DList.Visible=false; cb(opt)
		end
		for i,opt in ipairs(options) do
			local OBtn=Instance.new("TextButton",DList)
			OBtn.Size=UDim2.new(1,0,0,RH-2); OBtn.Position=UDim2.new(0,0,0,(i-1)*(RH-2))
			OBtn.BackgroundTransparency=1; OBtn.Text=opt; OBtn.TextColor3=C.Text
			OBtn.Font=Enum.Font.GothamSemibold; OBtn.TextSize=TS; OBtn.ZIndex=81
			OBtn.MouseButton1Click:Connect(function() SetSelected(opt) end)
			OBtn.MouseEnter:Connect(function() OBtn.TextColor3=C.Accent end)
			OBtn.MouseLeave:Connect(function() OBtn.TextColor3=C.Text end)
		end
		DBtn.MouseButton1Click:Connect(function() DList.Visible=not DList.Visible end)
		UserInputService.InputBegan:Connect(function(i)
			if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then task.wait(); DList.Visible=false end
		end)
		return DF, function(val) DBtn.Text=val.."  ▾" end
	end

	-- ВКЛАДКИ
	local AimbotTab = CreateTab("AIMBOT",  Icons.aimbot,     1)
	local ESPTab    = CreateTab("ESP",     Icons.esp,        2)
	local MoveTab   = CreateTab("MOVEMENT",Icons.movement,   3)
	local VisualsTab= CreateTab("VISUALS", Icons.visuals,    4)
	local ConfigTab = CreateTab("CONFIG",  Icons.configlist, 5)
	local InfoTab   = CreateTab("INFO",    Icons.info,       6)
	local SetTab    = CreateTab("SETTINGS",Icons.settings,   7)

	-- ===== AIMBOT =====
	SectionLabel(AimbotTab,"Aimbot")
	local _,setAimbotEnabled     = Toggle(AimbotTab,"Enable Aimbot",Settings.Aimbot.Enabled,function(v)
		Settings.Aimbot.Enabled=v; FOVCircle.Visible=v and Settings.Aimbot.ShowFOV
	end)
	local _,setAimbotShowFOV     = Toggle(AimbotTab,"Show FOV Circle",Settings.Aimbot.ShowFOV,function(v)
		Settings.Aimbot.ShowFOV=v; FOVCircle.Visible=v and Settings.Aimbot.Enabled
	end)
	local _,setAimbotIgnoreTeam  = Toggle(AimbotTab,"Ignore Teammates",Settings.Aimbot.IgnoreTeam,function(v) Settings.Aimbot.IgnoreTeam=v end)
	local _,setAimbotFOV         = Slider(AimbotTab,"FOV Size",20,500,Settings.Aimbot.FOV,function(v)
		Settings.Aimbot.FOV=v; if FOVCircle then FOVCircle.Size=UDim2.new(0,v*2,0,v*2) end
	end)
	local _,setAimbotSmooth      = Slider(AimbotTab,"Smoothness",1,100,Settings.Aimbot.Smoothness,function(v) Settings.Aimbot.Smoothness=v end)
	SectionLabel(AimbotTab,"Anti-Aim")
	local _,setAntiAimEnabled    = Toggle(AimbotTab,"Enable Anti-Aim",Settings.AntiAim.Enabled,function(v)
		Settings.AntiAim.Enabled=v; if v then StartAntiAim() else StopAntiAim() end
	end)
	local _,setAntiAimMode       = Dropdown(AimbotTab,"Mode",{"Random","Spin","Static","Jitter"},Settings.AntiAim.Mode,function(v)
		Settings.AntiAim.Mode=v; if Settings.AntiAim.Enabled then StartAntiAim() end
	end)
	local _,setAntiAimSpin       = Slider(AimbotTab,"Spin Speed",1,50,Settings.AntiAim.SpinSpeed,function(v) Settings.AntiAim.SpinSpeed=v end)
	local _,setAntiAimStatic     = Slider(AimbotTab,"Static Angle",0,360,Settings.AntiAim.StaticAngle,function(v) Settings.AntiAim.StaticAngle=v end)
	local _,setAntiAimJitter     = Slider(AimbotTab,"Jitter Range",10,180,Settings.AntiAim.JitterRange,function(v) Settings.AntiAim.JitterRange=v end)
	local _,setAntiAimInterval   = Slider(AimbotTab,"Interval (ms)",1,500,math.floor(Settings.AntiAim.Interval*1000),function(v) Settings.AntiAim.Interval=v/1000 end)

	-- ===== ESP =====
	SectionLabel(ESPTab,"Targets")
	local _,setESPEnabled        = Toggle(ESPTab,"Enable ESP",Settings.ESP.Enabled,function(v)
		Settings.ESP.Enabled=v; if not v then ClearAllESP() end
	end)
	local _,setESPPlayers        = Toggle(ESPTab,"Show Players",Settings.ESP.ShowPlayers,function(v) Settings.ESP.ShowPlayers=v end)
	local _,setESPNPCs           = Toggle(ESPTab,"Show NPCs",Settings.ESP.ShowNPCs,function(v) Settings.ESP.ShowNPCs=v end)
	SectionLabel(ESPTab,"Render")
	local _,setESPCorners        = Toggle(ESPTab,"Corner Box",Settings.ESP.ShowCorners,function(v) Settings.ESP.ShowCorners=v end)
	local _,setESPTracers        = Toggle(ESPTab,"Tracers",Settings.ESP.ShowTracers,function(v) Settings.ESP.ShowTracers=v end)
	local _,setESPSkeleton       = Toggle(ESPTab,"Skeleton",Settings.ESP.ShowSkeleton,function(v) Settings.ESP.ShowSkeleton=v end)
	local _,setESPNames          = Toggle(ESPTab,"Names",Settings.ESP.ShowNames,function(v) Settings.ESP.ShowNames=v end)
	local _,setESPHealth         = Toggle(ESPTab,"HP Bar",Settings.ESP.ShowHealth,function(v) Settings.ESP.ShowHealth=v end)
	local _,setESPDistance       = Toggle(ESPTab,"Distance",Settings.ESP.ShowDistance,function(v) Settings.ESP.ShowDistance=v end)
	local _,setESPWeapon         = Toggle(ESPTab,"Weapon",Settings.ESP.ShowWeapon,function(v) Settings.ESP.ShowWeapon=v end)
	SectionLabel(ESPTab,"Distance")
	local _,setESPCornerLen      = Slider(ESPTab,"Corner Length",4,20,Settings.ESP.CornerLen,function(v) Settings.ESP.CornerLen=v end)
	local _,setESPMaxDist        = Slider(ESPTab,"Max Distance",100,2000,Settings.ESP.MaxDistance,function(v) Settings.ESP.MaxDistance=v end)

	SectionLabel(ESPTab,"Chams")
	local _,setChamsEnabled      = Toggle(ESPTab,"Enable Chams",Settings.Chams.Enabled,function(v)
		Settings.Chams.Enabled=v; if not v then ClearAllChams() end
	end)
	local _,setChamsPlayers      = Toggle(ESPTab,"Players",Settings.Chams.Players,function(v) Settings.Chams.Players=v end)
	local _,setChamsNPCs         = Toggle(ESPTab,"NPCs",Settings.Chams.NPCs,function(v) Settings.Chams.NPCs=v end)
	local _,setChamsWallcheck    = Toggle(ESPTab,"Wall Color Diff",Settings.Chams.Wallcheck,function(v) Settings.Chams.Wallcheck=v end)

	SectionLabel(ESPTab,"Player Color")
	local _,setChamsPR           = Slider(ESPTab,"R",0,255,Settings.Chams.PlayerR,function(v) Settings.Chams.PlayerR=v end)
	local _,setChamsPG           = Slider(ESPTab,"G",0,255,Settings.Chams.PlayerG,function(v) Settings.Chams.PlayerG=v end)
	local _,setChamsPB           = Slider(ESPTab,"B",0,255,Settings.Chams.PlayerB,function(v) Settings.Chams.PlayerB=v end)

	SectionLabel(ESPTab,"Player Wall Color")
	local _,setChamsPWR          = Slider(ESPTab,"R",0,255,Settings.Chams.PlayerWallR,function(v) Settings.Chams.PlayerWallR=v end)
	local _,setChamsPWG          = Slider(ESPTab,"G",0,255,Settings.Chams.PlayerWallG,function(v) Settings.Chams.PlayerWallG=v end)
	local _,setChamsPWB          = Slider(ESPTab,"B",0,255,Settings.Chams.PlayerWallB,function(v) Settings.Chams.PlayerWallB=v end)

	SectionLabel(ESPTab,"Transparency")
	local _,setChamsTransp       = Slider(ESPTab,"Visible Transp",0,95,math.floor(Settings.Chams.Transparency*100),function(v) Settings.Chams.Transparency=v/100 end)
	local _,setChamsWallTransp   = Slider(ESPTab,"Wall Transp",0,95,math.floor(Settings.Chams.WallTransparency*100),function(v) Settings.Chams.WallTransparency=v/100 end)

	-- ===== MOVEMENT =====
	SectionLabel(MoveTab,"Movement")
	local _,setBhop              = Toggle(MoveTab,"Bunny Hop",Settings.Movement.BunnyHop,function(v)
		Settings.Movement.BunnyHop=v; if v then SetupBunnyHop() else DisableBunnyHop() end
	end)
	local _,setAutoJump          = Toggle(MoveTab,"Auto Jump",Settings.Movement.AutoJump,function(v) Settings.Movement.AutoJump=v end)
	local _,setBhopSpeed         = Slider(MoveTab,"BHop Speed",1,50,Settings.Movement.BHopSpeed,function(v) Settings.Movement.BHopSpeed=v end)
	local _,setMaxSpeed          = Slider(MoveTab,"Max Speed",50,200,Settings.Movement.MaxSpeed,function(v) Settings.Movement.MaxSpeed=v end)
	SectionLabel(MoveTab,"Teleport")
	Button(MoveTab,"Teleport to Random",C.Accent,function()
		if isTeleporting then StopTeleport(); task.wait(0.2) end
		TeleportToRandomPlayer()
	end)
	Button(MoveTab,"Skip to Next Target",C.Orange,function()
		if isTeleporting then StopTeleport(); task.wait(0.2); TeleportToRandomPlayer() end
	end)
	local _,setTPTime            = Slider(MoveTab,"TP Time (sec)",0,3,Settings.Teleport.TeleportTime,function(v) Settings.Teleport.TeleportTime=v end)
	local _,setTPDist            = Slider(MoveTab,"Distance Behind",3,10,Settings.Teleport.Distance,function(v) Settings.Teleport.Distance=v end)

	-- ===== FAKE LAG =====
	SectionLabel(MoveTab,"Fake Lag")
	local _,setFakeLagEnabled    = Toggle(MoveTab,"Enable Fake Lag",Settings.FakeLag.Enabled,function(v)
		Settings.FakeLag.Enabled=v
		if v then StartFakeLag(); if Settings.FakeLag.ShowCube then CreateFakeLagCube() end
		else StopFakeLag(); DestroyFakeLagCube() end
	end)
	local _,setFakeLagCube       = Toggle(MoveTab,"Show Preview Cube",Settings.FakeLag.ShowCube,function(v)
		Settings.FakeLag.ShowCube=v
		if not v then if fakeLagCube then pcall(function() fakeLagCube.Transparency=1 end) end end
	end)
	local _,setFLDist            = Slider(MoveTab,"FL Distance",5,50,Settings.FakeLag.Distance,function(v) Settings.FakeLag.Distance=v end)
	local _,setFLInterval        = Slider(MoveTab,"FL Interval (ms)",50,500,math.floor(Settings.FakeLag.Interval*1000),function(v)
		Settings.FakeLag.Interval=v/1000
		if Settings.FakeLag.Enabled then StartFakeLag() end
	end)

	-- ===== VISUALS =====
	SectionLabel(VisualsTab,"Lighting")
	local _,setVBrightness       = Slider(VisualsTab,"Brightness",0,10,Settings.Visuals.Brightness,function(v)
		Settings.Visuals.Brightness=v; pcall(function() Lighting.Brightness=v end)
	end)
	local _,setVAmbR             = Slider(VisualsTab,"Ambient R",0,255,Settings.Visuals.AmbientR,function(v)
		Settings.Visuals.AmbientR=v
		pcall(function() Lighting.Ambient=Color3.fromRGB(Settings.Visuals.AmbientR,Settings.Visuals.AmbientG,Settings.Visuals.AmbientB) end)
	end)
	local _,setVAmbG             = Slider(VisualsTab,"Ambient G",0,255,Settings.Visuals.AmbientG,function(v)
		Settings.Visuals.AmbientG=v
		pcall(function() Lighting.Ambient=Color3.fromRGB(Settings.Visuals.AmbientR,Settings.Visuals.AmbientG,Settings.Visuals.AmbientB) end)
	end)
	local _,setVAmbB             = Slider(VisualsTab,"Ambient B",0,255,Settings.Visuals.AmbientB,function(v)
		Settings.Visuals.AmbientB=v
		pcall(function() Lighting.Ambient=Color3.fromRGB(Settings.Visuals.AmbientR,Settings.Visuals.AmbientG,Settings.Visuals.AmbientB) end)
	end)
	SectionLabel(VisualsTab,"Fog")
	local _,setVFog              = Toggle(VisualsTab,"Enable Fog",Settings.Visuals.FogEnabled,function(v)
		Settings.Visuals.FogEnabled=v
		pcall(function() Lighting.FogEnd=v and Settings.Visuals.FogEnd or 100000; Lighting.FogStart=0 end)
	end)
	local _,setVFogDist          = Slider(VisualsTab,"Fog Distance",50,2000,Settings.Visuals.FogEnd,function(v)
		Settings.Visuals.FogEnd=v
		if Settings.Visuals.FogEnabled then pcall(function() Lighting.FogEnd=v end) end
	end)
	SectionLabel(VisualsTab,"Sky / Atmosphere")
	local _,setVSky = Toggle(VisualsTab,"Enable",Settings.Visuals.SkyEnabled,function(v)
		Settings.Visuals.SkyEnabled=v; ApplySky()
	end)
	local _,setVSkyPreset = Dropdown(VisualsTab,"Preset",{"Night","DeepNight","Sunset","Fog"},
		Settings.Visuals.SkyPreset or "Night",function(v)
		Settings.Visuals.SkyPreset=v
		Settings.Visuals.SkyEnabled=true; setVSky(true); ApplySky()
	end)
	Button(VisualsTab,"Apply",C.Teal,function()
		Settings.Visuals.SkyEnabled=true; setVSky(true); ApplySky()
	end)
	Button(VisualsTab,"Remove",C.Red,function()
		Settings.Visuals.SkyEnabled=false; setVSky(false); ApplySky()
	end)
	Button(VisualsTab,"Reset Lighting",C.Orange,function()
		Settings.Visuals.Brightness=1
		Settings.Visuals.AmbientR=0; Settings.Visuals.AmbientG=0; Settings.Visuals.AmbientB=0
		Settings.Visuals.FogEnabled=false
		pcall(function()
			Lighting.Brightness=1; Lighting.Ambient=Color3.fromRGB(0,0,0)
			Lighting.OutdoorAmbient=Color3.fromRGB(70,70,70)
			Lighting.FogEnd=100000; Lighting.FogStart=0
		end)
	end)

	-- =====================================================================
	-- ApplyGUI — синхронизирует все UI элементы с текущим Settings
	-- Вызывается после Load/Import конфига
	-- =====================================================================
	local function ApplyGUI()
		-- Aimbot
		setAimbotEnabled(Settings.Aimbot.Enabled)
		setAimbotShowFOV(Settings.Aimbot.ShowFOV)
		setAimbotIgnoreTeam(Settings.Aimbot.IgnoreTeam)
		setAimbotFOV(Settings.Aimbot.FOV)
		setAimbotSmooth(Settings.Aimbot.Smoothness)
		if FOVCircle then
			FOVCircle.Visible = Settings.Aimbot.Enabled and Settings.Aimbot.ShowFOV
			FOVCircle.Size = UDim2.new(0, Settings.Aimbot.FOV*2, 0, Settings.Aimbot.FOV*2)
		end
		-- Anti-Aim
		setAntiAimEnabled(Settings.AntiAim.Enabled)
		setAntiAimMode(Settings.AntiAim.Mode)
		setAntiAimSpin(Settings.AntiAim.SpinSpeed)
		setAntiAimStatic(Settings.AntiAim.StaticAngle)
		setAntiAimJitter(Settings.AntiAim.JitterRange)
		setAntiAimInterval(math.floor(Settings.AntiAim.Interval*1000))
		-- Chams
		setChamsEnabled(Settings.Chams.Enabled)
		setChamsPlayers(Settings.Chams.Players)
		setChamsNPCs(Settings.Chams.NPCs)
		setChamsWallcheck(Settings.Chams.Wallcheck)
		setChamsPR(Settings.Chams.PlayerR); setChamsPG(Settings.Chams.PlayerG); setChamsPB(Settings.Chams.PlayerB)
		setChamsPWR(Settings.Chams.PlayerWallR); setChamsPWG(Settings.Chams.PlayerWallG); setChamsPWB(Settings.Chams.PlayerWallB)
		setChamsTransp(math.floor(Settings.Chams.Transparency*100))
		setChamsWallTransp(math.floor(Settings.Chams.WallTransparency*100))
		if not Settings.Chams.Enabled then ClearAllChams() end
		-- ESP
		setESPEnabled(Settings.ESP.Enabled)
		setESPPlayers(Settings.ESP.ShowPlayers)
		setESPNPCs(Settings.ESP.ShowNPCs)
		setESPCorners(Settings.ESP.ShowCorners)
		setESPTracers(Settings.ESP.ShowTracers)
		setESPSkeleton(Settings.ESP.ShowSkeleton)
		setESPNames(Settings.ESP.ShowNames)
		setESPHealth(Settings.ESP.ShowHealth)
		setESPDistance(Settings.ESP.ShowDistance)
		setESPWeapon(Settings.ESP.ShowWeapon)
		setESPCornerLen(Settings.ESP.CornerLen)
		setESPMaxDist(Settings.ESP.MaxDistance)
		-- Movement
		setBhop(Settings.Movement.BunnyHop)
		setAutoJump(Settings.Movement.AutoJump)
		setBhopSpeed(Settings.Movement.BHopSpeed)
		setMaxSpeed(Settings.Movement.MaxSpeed)
		setTPTime(Settings.Teleport.TeleportTime)
		setTPDist(Settings.Teleport.Distance)
		-- FakeLag
		setFakeLagEnabled(Settings.FakeLag.Enabled)
		setFakeLagCube(Settings.FakeLag.ShowCube)
		setFLDist(Settings.FakeLag.Distance)
		setFLInterval(math.floor(Settings.FakeLag.Interval*1000))
		-- Visuals
		setVBrightness(Settings.Visuals.Brightness)
		setVAmbR(Settings.Visuals.AmbientR)
		setVAmbG(Settings.Visuals.AmbientG)
		setVAmbB(Settings.Visuals.AmbientB)
		setVFog(Settings.Visuals.FogEnabled)
		setVFogDist(Settings.Visuals.FogEnd)
		setVSky(Settings.Visuals.SkyEnabled)
		setVSkyPreset(Settings.Visuals.SkyPreset or "Night")
		-- Keybinds (кнопки в таб + значки в KBFrame)
		for _, bind in ipairs(KEYBIND_IDS) do
			local val = Settings.Keybinds[bind.id] or "None"
			local btn = keybindButtons[bind.id]
			if btn then
				btn.Text = val
				btn.TextColor3 = (val == "None") and C.Dimmer or C.Accent
				btn.BackgroundColor3 = C.SliderBG
			end
			local lbl = kbDynLabels[bind.id]
			if lbl then
				lbl.Text = val
				lbl.TextColor3 = (val == "None") and C.Dimmer or C.Accent
				lbl.BackgroundColor3 = (val == "None") and C.Row or C.AccentBG
			end
		end
		-- Watermark
		WatermarkFrame.Visible = Settings.Watermark.Enabled
		-- Sync action buttons
		actionStates.ESP     = Settings.ESP.Enabled
		actionStates.Aimbot  = Settings.Aimbot.Enabled
		actionStates.AntiAim = Settings.AntiAim.Enabled
		actionStates.BHop    = Settings.Movement.BunnyHop
		actionStates.FakeLag = Settings.FakeLag.Enabled
		for id,_ in pairs(actionStates) do UpdateActionBtn(id) end
		-- Запуск/остановка систем
		if Settings.AntiAim.Enabled then StartAntiAim() else StopAntiAim() end
		if Settings.Movement.BunnyHop then SetupBunnyHop() else DisableBunnyHop() end
		if Settings.FakeLag.Enabled then StartFakeLag() else StopFakeLag(); DestroyFakeLagCube() end
		ApplyLighting()
		ApplySky()
	end

	-- ===== CONFIG TAB =====
	local StatusFrame=Instance.new("Frame",ConfigTab)
	StatusFrame.Size=UDim2.new(1,0,0,18)
	StatusFrame.BackgroundColor3=C.Row; StatusFrame.BorderSizePixel=0; StatusFrame.ZIndex=23
	Instance.new("UICorner",StatusFrame).CornerRadius=UDim.new(0,4)
	local StatusLabel=Instance.new("TextLabel",StatusFrame)
	StatusLabel.Size=UDim2.new(1,-16,1,0); StatusLabel.Position=UDim2.new(0,8,0,0)
	StatusLabel.BackgroundTransparency=1
	StatusLabel.Text=FS_AVAILABLE and "Ready" or "File system unavailable"
	StatusLabel.TextColor3=FS_AVAILABLE and C.Dim or C.Orange
	StatusLabel.Font=Enum.Font.Gotham; StatusLabel.TextSize=7
	StatusLabel.TextXAlignment=Enum.TextXAlignment.Left; StatusLabel.ZIndex=24

	local function SetStatus(msg, col)
		StatusLabel.Text=msg; StatusLabel.TextColor3=col or C.Dim
	end

	SectionLabel(ConfigTab,"Saved Configs")
	local cfgListFrame=Instance.new("Frame",ConfigTab)
	cfgListFrame.Size=UDim2.new(1,0,0,90)
	cfgListFrame.BackgroundColor3=C.Row; cfgListFrame.BorderSizePixel=0
	cfgListFrame.ZIndex=23; cfgListFrame.ClipsDescendants=true
	Instance.new("UICorner",cfgListFrame).CornerRadius=UDim.new(0,4)
	local cfgScroll=Instance.new("ScrollingFrame",cfgListFrame)
	cfgScroll.Size=UDim2.new(1,-4,1,-4); cfgScroll.Position=UDim2.new(0,2,0,2)
	cfgScroll.BackgroundTransparency=1; cfgScroll.BorderSizePixel=0
	cfgScroll.ScrollBarThickness=3; cfgScroll.ScrollBarImageColor3=C.Dimmer
	cfgScroll.CanvasSize=UDim2.new(0,0,0,0)
	cfgScroll.AutomaticCanvasSize=Enum.AutomaticSize.Y; cfgScroll.ZIndex=24
	local csLayout=Instance.new("UIListLayout",cfgScroll)
	csLayout.Padding=UDim.new(0,1); csLayout.SortOrder=Enum.SortOrder.LayoutOrder
	local csPad=Instance.new("UIPadding",cfgScroll)
	csPad.PaddingTop=UDim.new(0,2); csPad.PaddingLeft=UDim.new(0,2); csPad.PaddingRight=UDim.new(0,2)

	local selectedConfig=nil
	local cfgRows={}

	local function RebuildCfgList()
		for _,r in pairs(cfgRows) do if r and r.Parent then r:Destroy() end end
		cfgRows={}; selectedConfig=nil
		if not FS_AVAILABLE then
			local e=Instance.new("TextLabel",cfgScroll)
			e.Size=UDim2.new(1,0,0,26); e.BackgroundTransparency=1
			e.Text="  File system unavailable"; e.TextColor3=C.Red
			e.Font=Enum.Font.Gotham; e.TextSize=7
			e.TextXAlignment=Enum.TextXAlignment.Left; e.ZIndex=25
			table.insert(cfgRows,e); return
		end
		local list,_ = ConfigSystem.List()
		if #list==0 then
			local e=Instance.new("TextLabel",cfgScroll)
			e.Size=UDim2.new(1,0,0,26); e.BackgroundTransparency=1
			e.Text="  No configs saved yet"; e.TextColor3=C.Dimmer
			e.Font=Enum.Font.Gotham; e.TextSize=7
			e.TextXAlignment=Enum.TextXAlignment.Left; e.ZIndex=25
			table.insert(cfgRows,e); return
		end
		for _,name in ipairs(list) do
			local Row=Instance.new("TextButton",cfgScroll)
			Row.Size=UDim2.new(1,0,0,16)
			Row.BackgroundTransparency=1; Row.BorderSizePixel=0
			Row.Text="  "..name; Row.TextColor3=C.Text
			Row.Font=Enum.Font.GothamSemibold; Row.TextSize=8
			Row.TextXAlignment=Enum.TextXAlignment.Left; Row.ZIndex=25
			Row.MouseEnter:Connect(function()
				if selectedConfig~=name then Row.BackgroundTransparency=0.85; Row.BackgroundColor3=C.AccentBG end
			end)
			Row.MouseLeave:Connect(function()
				if selectedConfig~=name then Row.BackgroundTransparency=1 end
			end)
			Row.MouseButton1Click:Connect(function()
				for _,r in pairs(cfgRows) do
					if r:IsA("TextButton") then r.BackgroundTransparency=1 end
				end
				Row.BackgroundColor3=C.AccentBG; Row.BackgroundTransparency=0.6
				selectedConfig=name; SetStatus("Selected: "..name, C.Accent)
			end)
			table.insert(cfgRows,Row)
		end
	end

	SectionLabel(ConfigTab,"Config Name")
	local _,GetCfgName,SetCfgName,cfgInput=TextInput(ConfigTab,"Name","Enter config name...")
	SectionLabel(ConfigTab,"Actions")
	Button(ConfigTab,"Save Config",C.Green,function()
		local name=GetCfgName():match("^%s*(.-)%s*$")
		if name=="" then SetStatus("Enter a config name!", C.Orange); return end
		name=name:gsub('[/\\:*?"<>|%c]',"_")
		if name=="" then SetStatus("Invalid name!", C.Orange); return end
		local ok,msg=ConfigSystem.Save(name)
		if ok then SetStatus("Saved: "..name, C.Green); SetCfgName(""); RebuildCfgList()
		else SetStatus((msg or "Save failed"), C.Red) end
	end)
	Button(ConfigTab,"Load Config",C.Accent,function()
		if not selectedConfig then SetStatus("Select a config first!", C.Orange); return end
		local ok,msg=ConfigSystem.Load(selectedConfig)
		if ok then
			SetStatus("Loaded: "..selectedConfig, C.Green)
			ApplyGUI()
		else SetStatus((msg or "Load failed"), C.Red) end
	end)
	Button(ConfigTab,"Delete Config",C.Red,function()
		if not selectedConfig then SetStatus("Select a config first!", C.Orange); return end
		local name=selectedConfig
		local ok,msg=ConfigSystem.Delete(name)
		if ok then SetStatus("Deleted: "..name, C.Dim)
		else SetStatus("Delete failed: "..(msg or "?"), C.Red) end
		selectedConfig=nil; RebuildCfgList()
	end)
	Button(ConfigTab,"Refresh List",C.Orange,function()
		RebuildCfgList(); SetStatus("Refreshed", C.Dim)
	end)
	SectionLabel(ConfigTab,"Export / Import")
	local _,GetImportText,SetImportText,importInput=TextInput(ConfigTab,"Paste JSON to import","{ ... }")
	Button(ConfigTab,"Export to Console",C.Purple,function()
		local json,err=ConfigSystem.Export()
		if json then print("[RageVoid Export]\n"..json); SetStatus("Exported to console (F9)", C.Green)
		else SetStatus("Export failed: "..(err or "?"), C.Red) end
	end)
	Button(ConfigTab,"Import from Text",C.Teal,function()
		local json=GetImportText():match("^%s*(.-)%s*$")
		if json=="" then SetStatus("Paste JSON first!", C.Orange); return end
		local ok,msg=ConfigSystem.Import(json)
		if ok then
			SetStatus("Imported", C.Green); SetImportText("")
			ApplyGUI()
		else SetStatus("Import error: "..(msg or "?"), C.Red) end
	end)
	RebuildCfgList()

	-- ===== KEYBINDS (в Config таб) =====
	SectionLabel(ConfigTab, "Keybinds")

	local BindHint = Instance.new("Frame", ConfigTab)
	BindHint.Size = UDim2.new(1,0,0,16)
	BindHint.BackgroundColor3 = C.AccentBG
	BindHint.BorderSizePixel = 0; BindHint.ZIndex = 23
	Instance.new("UICorner", BindHint).CornerRadius = UDim.new(0,4)
	local BindHintLbl = Instance.new("TextLabel", BindHint)
	BindHintLbl.Size = UDim2.new(1,-12,1,0); BindHintLbl.Position = UDim2.new(0,6,0,0)
	BindHintLbl.BackgroundTransparency = 1
	BindHintLbl.Text = "LMB = set key  ·  RMB = clear  ·  ESC = clear"
	BindHintLbl.TextColor3 = C.Accent; BindHintLbl.Font = Enum.Font.Gotham
	BindHintLbl.TextSize = 7; BindHintLbl.ZIndex = 24

	local function BuildBindRow(parent, bindId, bindLabel)
		local Row = Instance.new("Frame", parent)
		Row.Size = UDim2.new(1,0,0,RH)
		Row.BackgroundColor3 = C.Row; Row.BorderSizePixel = 0; Row.ZIndex = 23
		Instance.new("UICorner", Row).CornerRadius = UDim.new(0,4)

		local Lbl = Instance.new("TextLabel", Row)
		Lbl.Size = UDim2.new(0.55,0,1,0); Lbl.Position = UDim2.new(0,10,0,0)
		Lbl.BackgroundTransparency = 1; Lbl.Text = bindLabel
		Lbl.TextColor3 = C.Text; Lbl.Font = Enum.Font.GothamSemibold
		Lbl.TextSize = TS; Lbl.TextXAlignment = Enum.TextXAlignment.Left; Lbl.ZIndex = 24

		local current = Settings.Keybinds[bindId]
		local isNone = (current == "None" or current == "" or current == nil)

		local KeyBtn = Instance.new("TextButton", Row)
		KeyBtn.Size = UDim2.new(0,72,0,RH-8); KeyBtn.Position = UDim2.new(1,-78,0.5,-(RH-8)/2)
		KeyBtn.BackgroundColor3 = C.SliderBG; KeyBtn.BorderSizePixel = 0
		KeyBtn.Text = current or "None"
		KeyBtn.TextColor3 = isNone and C.Dimmer or C.Accent
		KeyBtn.Font = Enum.Font.GothamBold
		KeyBtn.TextSize = TSS; KeyBtn.ZIndex = 25
		Instance.new("UICorner", KeyBtn).CornerRadius = UDim.new(0,3)
		local kbStroke = Instance.new("UIStroke", KeyBtn)
		kbStroke.Color = C.AccentDim; kbStroke.Thickness = 1

		keybindButtons[bindId] = KeyBtn

		KeyBtn.MouseButton1Click:Connect(function()
			if keybindListening and keybindListening ~= bindId then
				local prev = keybindButtons[keybindListening]
				if prev then
					local prevVal = Settings.Keybinds[keybindListening]
					local prevNone = (prevVal == "None" or prevVal == "" or prevVal == nil)
					prev.Text = prevVal or "None"
					prev.BackgroundColor3 = C.SliderBG
					prev.TextColor3 = prevNone and C.Dimmer or C.Accent
				end
			end
			keybindListening = bindId
			KeyBtn.Text = "[ press key ]"
			KeyBtn.BackgroundColor3 = C.AccentBG
			KeyBtn.TextColor3 = C.Orange
			kbStroke.Color = C.Orange
		end)

		KeyBtn.MouseButton2Click:Connect(function()
			if keybindListening == bindId then keybindListening = nil end
			Settings.Keybinds[bindId] = "None"
			KeyBtn.Text = "None"
			KeyBtn.BackgroundColor3 = C.SliderBG
			KeyBtn.TextColor3 = C.Dimmer
			kbStroke.Color = C.AccentDim
			local lbl = kbDynLabels[bindId]
			if lbl then lbl.Text="None"; lbl.TextColor3=C.Dimmer; lbl.BackgroundColor3=C.Row end
		end)

		return Row
	end

	for _, bind in ipairs(KEYBIND_IDS) do
		BuildBindRow(ConfigTab, bind.id, bind.label)
	end

	Button(ConfigTab, "Reset All to None", C.Red, function()
		for _, bind in ipairs(KEYBIND_IDS) do
			if bind.id ~= "ToggleMenu" then
				Settings.Keybinds[bind.id] = "None"
				if keybindButtons[bind.id] then
					keybindButtons[bind.id].Text = "None"
					keybindButtons[bind.id].TextColor3 = C.Dimmer
					keybindButtons[bind.id].BackgroundColor3 = C.SliderBG
				end
			end
		end
		Settings.Keybinds.ToggleMenu = "Insert"
		if keybindButtons.ToggleMenu then
			keybindButtons.ToggleMenu.Text = "Insert"
			keybindButtons.ToggleMenu.TextColor3 = C.Accent
		end
		keybindListening = nil
	end)

	-- ===== INFO =====
	SectionLabel(InfoTab,"About")
	local IBox=Instance.new("Frame",InfoTab)
	IBox.Size=UDim2.new(1,0,0,110); IBox.BackgroundColor3=C.Row
	IBox.BorderSizePixel=0; IBox.ZIndex=23
	Instance.new("UICorner",IBox).CornerRadius=UDim.new(0,4)
	local IT=Instance.new("TextLabel",IBox)
	IT.Size=UDim2.new(1,-20,1,-16); IT.Position=UDim2.new(0,10,0,8)
	IT.BackgroundTransparency=1; IT.ZIndex=24
	IT.Text="RageVoid  |  alpha v0.9\n\n[Insert]  toggle menu\nCustom keybinds in KEYBINDS tab\n\nESP: corner box, tracers, skeleton, HP, names, weapon\nAimbot + Anti-Aim\nBunnyHop + Teleport\nFake Lag: forward dash, wall/air checks, cube preview\nVisuals: lighting, fog, sky\nConfig: save / load / export / import"
	IT.TextColor3=C.Dim; IT.Font=Enum.Font.Gotham; IT.TextSize=8
	IT.TextXAlignment=Enum.TextXAlignment.Left; IT.TextYAlignment=Enum.TextYAlignment.Top
	IT.TextWrapped=true

	-- ===== SETTINGS =====
	SectionLabel(SetTab,"Interface")
	Toggle(SetTab,"Show Watermark",Settings.Watermark.Enabled,function(v)
		Settings.Watermark.Enabled=v; WatermarkFrame.Visible=v
	end)
	Toggle(SetTab,"Show Quick Actions",true,function(v) KBFrame.Visible=v end)
	SectionLabel(SetTab,"Quick Actions")
	Button(SetTab,"Enable Everything",C.Green,function()
		Settings.ESP.Enabled=true; Settings.Aimbot.Enabled=true
		Settings.Movement.BunnyHop=true; Settings.AntiAim.Enabled=true
		Settings.FakeLag.Enabled=true; Settings.Chams.Enabled=true
		SetupBunnyHop(); StartAntiAim(); StartFakeLag()
		if FOVCircle then FOVCircle.Visible=true end
	end)
	Button(SetTab,"Disable Everything",C.Red,function()
		Settings.ESP.Enabled=false; Settings.Aimbot.Enabled=false
		Settings.Movement.BunnyHop=false; Settings.AntiAim.Enabled=false
		Settings.FakeLag.Enabled=false; Settings.Chams.Enabled=false
		ClearAllESP(); DisableBunnyHop(); StopAntiAim(); StopFakeLag(); DestroyFakeLagCube(); ClearAllChams()
		if FOVCircle then FOVCircle.Visible=false end
	end)
	SectionLabel(SetTab,"Config Shortcuts")
	Button(SetTab,"Quick Save 'default'",C.Purple,function()
		local ok,msg=ConfigSystem.Save("default")
		print(ok and "Saved 'default'" or ("Failed: "..tostring(msg)))
	end)
	Button(SetTab,"Quick Load 'default'",C.Purple,function()
		local ok,msg=ConfigSystem.Load("default")
		if ok then
			ApplyGUI(); print("Loaded 'default'")
		else print("Failed: "..tostring(msg)) end
	end)

	ScreenGui.Parent=LocalPlayer:WaitForChild("PlayerGui")
	return ScreenGui, Window
end

-- =====================================================================
-- ИНИЦИАЛИЗАЦИЯ
-- =====================================================================
local Gui, Window = CreateGUI()

UserInputService.InputBegan:Connect(function(input, gp)
	-- Перехват назначения кнопки
	if keybindListening then
		if input.UserInputType == Enum.UserInputType.Keyboard then
			local keyName = input.KeyCode.Name
			local blocked = { LeftShift=true, RightShift=true, LeftControl=true,
				RightControl=true, LeftAlt=true, RightAlt=true }
			-- ESC = сбросить бинд в None
			if input.KeyCode == Enum.KeyCode.Escape then
				Settings.Keybinds[keybindListening] = "None"
				local btn = keybindButtons[keybindListening]
				if btn then
					btn.Text = "None"
					btn.BackgroundColor3 = C.SliderBG
					btn.TextColor3 = C.Dimmer
				end
				local lbl = kbDynLabels[keybindListening]
				if lbl then lbl.Text="None"; lbl.TextColor3=C.Dimmer; lbl.BackgroundColor3=C.Row end
				keybindListening = nil
				return
			end
			if not blocked[keyName] then
				Settings.Keybinds[keybindListening] = keyName
				local btn = keybindButtons[keybindListening]
				if btn then
					btn.Text = keyName
					btn.BackgroundColor3 = C.SliderBG
					btn.TextColor3 = C.Accent
				end
				local lbl = kbDynLabels[keybindListening]
				if lbl then lbl.Text=keyName; lbl.TextColor3=C.Accent; lbl.BackgroundColor3=C.AccentBG end
				keybindListening = nil
				return
			end
		end
		return
	end

	if gp then return end

	local keyName = input.KeyCode.Name

	-- Toggle Menu
	if keyName == Settings.Keybinds.ToggleMenu then
		Window.Visible = not Window.Visible
		if Window.Visible then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			UserInputService.MouseIconEnabled = true
		end
		return
	end

	-- Остальные кейбинды (пропускаем None)
	for _, bind in ipairs(KEYBIND_IDS) do
		local assigned = Settings.Keybinds[bind.id]
		if bind.id ~= "ToggleMenu" and assigned ~= "None" and assigned ~= "" and keyName == assigned then
			local id = bind.id
			if id == "QuickTP" then
				if isTeleporting then StopTeleport(); task.wait(0.2) end
				TeleportToRandomPlayer()
			elseif id == "ToggleESP" then
				Settings.ESP.Enabled = not Settings.ESP.Enabled
				if not Settings.ESP.Enabled then ClearAllESP() end
			elseif id == "ToggleAimbot" then
				Settings.Aimbot.Enabled = not Settings.Aimbot.Enabled
				if FOVCircle then FOVCircle.Visible = Settings.Aimbot.Enabled and Settings.Aimbot.ShowFOV end
			elseif id == "ToggleFakeLag" then
				Settings.FakeLag.Enabled = not Settings.FakeLag.Enabled
				if Settings.FakeLag.Enabled then StartFakeLag()
				else StopFakeLag(); DestroyFakeLagCube() end
			elseif id == "ToggleBhop" then
				Settings.Movement.BunnyHop = not Settings.Movement.BunnyHop
				if Settings.Movement.BunnyHop then SetupBunnyHop() else DisableBunnyHop() end
			elseif id == "ToggleAntiAim" then
				Settings.AntiAim.Enabled = not Settings.AntiAim.Enabled
				if Settings.AntiAim.Enabled then StartAntiAim() else StopAntiAim() end
			end
			return
		end
	end
end)

RunService.RenderStepped:Connect(function()
	if Window and Window.Visible then
		if UserInputService.MouseBehavior~=Enum.MouseBehavior.Default then
			UserInputService.MouseBehavior=Enum.MouseBehavior.Default
			UserInputService.MouseIconEnabled=true
		end
	end
	if FOVCircle then FOVCircle.Visible=Settings.Aimbot.Enabled and Settings.Aimbot.ShowFOV end
	if Settings.Aimbot.Enabled then
		local t=GetClosestEnemy(); if t then AimAt(t) end
	end
	UpdateESP()
	UpdateFakeLagCube()
	UpdateChams()
end)

LocalPlayer.CharacterAdded:Connect(function()
	task.wait(1)
	if Window and Window.Visible then
		UserInputService.MouseBehavior=Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled=true
	end
	antiAimAngle=0
	if Settings.Movement.BunnyHop then SetupBunnyHop() end
	if Settings.AntiAim.Enabled then StartAntiAim() end
	if Settings.FakeLag.Enabled then StartFakeLag() end
end)

Players.PlayerRemoving:Connect(function(p)
	if p.Character then RemoveESPDrawings(p.Character) end
end)
Players.PlayerAdded:Connect(function(p)
	p.CharacterRemoving:Connect(function(c) RemoveESPDrawings(c) end)
end)
for _,p in ipairs(Players:GetPlayers()) do
	if p~=LocalPlayer then
		p.CharacterRemoving:Connect(function(c) RemoveESPDrawings(c) end)
	end
end

if Settings.Movement.BunnyHop then SetupBunnyHop() end
if Settings.AntiAim.Enabled then StartAntiAim() end
if Settings.FakeLag.Enabled then StartFakeLag() end

print("RageVoid v0.9 | Dark Minimal Redesign + FakeLag + Custom Keybinds loaded")


