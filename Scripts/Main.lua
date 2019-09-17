--Set the application title
title="VR Template"

--Create a window
local windowstyle = 0
local winwidth
local winheight
local gfxmode = System:GetGraphicsMode(System:CountGraphicsModes()-1)

if System:GetProperty("devmode")=="1" then
	gfxmode.x = math.min(1280,gfxmode.x)
	gfxmode.y = Math:Round(gfxmode.x * 9 / 16)
	windowstyle = Window.Titlebar
else
	gfxmode.x = System:GetProperty("screenwidth",gfxmode.x)
	gfxmode.y = System:GetProperty("screenheight",gfxmode.y)
	windowstyle = Window.Fullscreen
end
window=Window:Create(title,0,0,gfxmode.x,gfxmode.y,windowstyle)

--Create the graphics context
context=Context:Create(window,0)
if context==nil then return end

--Create a world
world=World:Create()

--Load a map
local mapfile = System:GetProperty("map","Maps/start.map")
if mapfile~="" then
	if Map:Load(mapfile)==false then return end
	prevmapname = FileSystem:StripAll(changemapname)
	
	--Send analytics event
	Analytics:SendProgressEvent("Start",prevmapname)
	
	window:HideMouse()
end

while window:Closed()==false do
	
	if window:KeyHit(Key.Escape) then return end

	--Handle map change
	if changemapname~=nil then
		
		--Pause the clock
		Time:Pause()
		
		--Pause garbage collection
		System:GCSuspend()		
		
		--Clear all entities
		world:Clear()
		
		--Send analytics event
		Analytics:SendProgressEvent("Complete",prevmapname)
		
		--Load the next map
		if Map:Load("Maps/"..changemapname..".map")==false then return end
		prevmapname = changemapname
		
		--Send analytics event
		Analytics:SendProgressEvent("Start",prevmapname)
		
		--Resume garbage collection
		System:GCResume()
		
		--Resume the clock
		Time:Resume()
		
		changemapname = nil
	end	
	
	--Update the app timing
	Time:Update()
	
	world:Update()

	--Render the world
	world:Render()
	
	--Refresh the screen
	VR:MirrorDisplay(context)
	context:Sync()
	
end
