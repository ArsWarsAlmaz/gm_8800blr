local function init()
	local EyePos = EyePos
	local EyeVector = EyeVector
	local SysTime = SysTime
	local LocalPlayer = LocalPlayer
	local ClientsideModel = ClientsideModel
	local table_sort = table.sort
	local string_format = string.format
	local gui_IsGameUIVisible = gui.IsGameUIVisible
	local vgui_GetKeyboardFocus = vgui.GetKeyboardFocus
	local input_IsKeyDown = input.IsKeyDown
	local render_SetMaterial = render.SetMaterial
	local render_DrawQuadEasy = render.DrawQuadEasy
	local render_GetColorModulation = render.GetColorModulation
	local render_GetBlend = render.GetBlend
	local render_SetColorModulation = render.SetColorModulation
	local render_SetBlend = render.SetBlend

	local function loadData()
		-- panorama position and angle info is stored in its own binary data format
		local f = file.Open("8800blr/pano.dat.lua", "rb", "LUA")

		local total, data = f:ReadUShort(), {}

		for i = 1, total do
			local pX, pY, pZ = f:ReadFloat(), f:ReadFloat(), f:ReadFloat()
			local aX, aY, aZ = f:ReadFloat(), f:ReadFloat(), f:ReadFloat()
			data[i] = {
				index = i,
				pos = Vector(pX, pY, pZ),
				ang = Angle(aX, aY, aZ)
			}
		end

		return total, data
	end

	local PANO_TOTAL, PANO_DATA = loadData()
	local FOCUS_LEN = 0.5
	local FOCUS_DIST = 1000
	local FOCUS_KEY = KEY_E

	local viewing = false
	local focusing = false
	local focusTime
	local oldKey
	local currKey
	local lastIndex

	local iconMat = Material("8800blr/pano_icon.png", "smooth")
	local panoMats = {}
	for i = 1, 6 do
		panoMats[i] = Material("8800blr/pano_" .. (i - 1))
	end

	local function draw()
		local eyePos, eyeVector = EyePos(), EyeVector()
		local time = SysTime()

		-- sort data by pos distance
		table_sort(PANO_DATA, function(a, b) return eyePos:DistToSqr(a.pos) < eyePos:DistToSqr(b.pos) end)
		local closest = PANO_DATA[1]

		-- update keys
		oldKey = currKey
		currKey = input_IsKeyDown(FOCUS_KEY)

		-- handle viewing/focusing
		if not viewing then
			if not gui_IsGameUIVisible() and not vgui_GetKeyboardFocus()
				and currKey and eyePos:DistToSqr(closest.pos) <= FOCUS_DIST then
				if not focusing then
					if not oldKey then -- start focusing
						focusing = true
						focusTime = time
					end
				elseif time - focusTime >= FOCUS_LEN then -- start viewing/stop focusing
					viewing = true
					focusing = false
				end
			else -- cancel focusing
				focusing = false
			end
		elseif not gui_IsGameUIVisible() and not vgui_GetKeyboardFocus()
			and not oldKey and currKey or LocalPlayer():GetAbsVelocity():Length() > 0 then -- stop viewing
			viewing = false
		end

		-- draw panorama icons
		if not viewing then
			render_SetMaterial(iconMat)
			for i = PANO_TOTAL, 1, -1 do
				render_DrawQuadEasy(PANO_DATA[i].pos, -eyeVector, 16, 16, color_white, 180)
			end
		end

		-- draw panorama model
		if viewing or focusing then
			local index = closest.index
			if index ~= lastIndex then -- update textures used by the panorama model
				for i = 1, 6 do
					panoMats[i]:SetTexture("$basetexture", string_format("8800blr/pano/%03d_%d", index - 1, i - 1))
				end
			end
			lastIndex = index

			local pano = ClientsideModel("models/8800blr/panorama.mdl")
			pano:SetPos(eyePos)
			pano:SetAngles(closest.ang)
			local r, g, b = render_GetColorModulation()
			local blend = render_GetBlend()
			render_SetColorModulation(1, 1, 1)
			render_SetBlend(viewing and 1 or (time - focusTime) / FOCUS_LEN) -- fade in effect
			pano:DrawModel()
			render_SetColorModulation(r, g, b)
			render_SetBlend(blend)
			pano:Remove()
		end
	end

	hook.Add("PostDrawTranslucentRenderables", "8800blr_drawPano", draw)
end

hook.Add("Initialize", "8800blr_pano_init", function()
	if game.GetMap() == "gm_8800blr" then init() end
end)