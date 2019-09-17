import "Scripts/Functions/ReleaseTableObjects.lua"

Script.acceleration=10
Script.tiremass=100
Script.followdistance=4
Script.mincameraangle = -15
Script.maxcameraangle = 55
Script.enableESP=true
Script.goal=41 --Int "Start Goal"
Script.maxspeed=18
Script.id=0 --Int ID
Script.done=false
Script.brakes=0
Script.localtime=0
Script.slowdown=0
Script.dimensions=Vec3(2,2,6)
Script.offset=Vec3(0,1,0)
Script.recycle=0
Script.repawn=true
Script.distance=6000 --60
Script.resettime=3000
Script.spawned=false
Script.chase=0
Script.startmass=1500
Script.timethreshold=300

function Script:Start()

		self.entity:SetPickMode(0)
		if self.questcriminal then
			questAI=self.entity
		end

		if self.criminal then
			currentmessagetime=Time:Millisecs()
		end

		carsinplaym=carsinplaym+1
		carsinplay=carsinplay+1
		self.body=self.entity:FindChild("body")

		self.pointer=Sprite:Create()
		self.pointer:SetPosition(self.entity:GetPosition(true)+Vec3(0,2,0))
		self.pointer:SetParent(self.entity)
		self.compass=Pivot:Create(self.entity)

		if self.criminal then
			self.pointer:SetMaterial(pointertexture)
			self.maxspeed=self.maxspeed*2
			self.acceleration=self.acceleration*5
		else
			self.pointer:SetMaterial(invisibletexture)
		end

        self.frontclose=Pivot:Create(self.entity)
        self.frontfar=Pivot:Create(self.entity)
		self.hitbox=Model:Box(self.entity)
		self.hitbox:SetScale(self.dimensions)
		self.hitbox:SetPosition(self.offset)
		self.hitbox:SetMaterial(invisibletexture)
		
		self.frontclose:SetPosition(self.entity:GetPosition()+Vec3(0,1,2),true)
		self.frontfar:SetPosition(self.entity:GetPosition()+Vec3(0,1,6),true)
        
        self.sound={}
        self.sound.engineloop=Sound:Load("Addons/CarDemo prefab (requires addon Vehicles installed)/run.wav")
        self.sound.enginestart=Sound:Load("Addons/CarDemo prefab (requires addon Vehicles installed)/start.wav")
        self.sound.tireskid=Sound:Load("Addons/CarDemo prefab (requires addon Vehicles installed)/skid.wav")
        
        self.source={}
        self.tires={}
		
		--Build the vehicle
		self:BuildVehicle()
end

function Script:BuildVehicle()
		
		local n,box
        local child={}
        local tirepos
        local tirewidth = 0.25
        local tireradius = 0.4
		
        self.vehicle = Vehicle:Create(self.entity) 
        for n=0,7 do
                child[0] = self.entity:FindChild("tire"..tostring(n*2+0))
                child[1] = self.entity:FindChild("tire"..tostring(n*2+1))
                if child[0]~=nil and child[1]~=nil then
                        for i=0,1 do
                                box = self:CalculateTireSize(child[i])
                                if box~=nil then
                                        tireradius = math.max(box.size.y,box.size.z)*0.5
                                        tirewidth = box.size.x
                                        tirepos = box.center + child[i]:GetPosition(false)
                                        self.vehicle:AddTire(tirepos.x,tirepos.y,tirepos.z,self.tiremass,tireradius,tirewidth,n<1)
                                        table.insert(self.tires,child[i])
                                end
                        end
                        if n>0 then
                                self.vehicle:AddAxle(self.vehicle:CountTires()-2,self.vehicle:CountTires()-1)
                        end
                end
        end
		self.vehicle:Build()

end

function Script:CalculateTireSize(entity)
        local n,model,surf,v,p,box
        
        if entity:GetClass()==Object.ModelClass then
                model = tolua.cast(entity,"Model")
                for n=0,model:CountSurfaces()-1 do
                        surf = model:GetSurface(n)
                        for v=0,surf:CountVertices()-1 do
                                p = surf:GetVertexPosition(v) * entity.scale
                                if box==nil then
                                        box=AABB(p,p)
                                else
                                        box.min.x = math.min(box.min.x,p.x)
                                        box.min.y = math.min(box.min.y,p.y)
                                        box.min.z = math.min(box.min.z,p.z)
                                        box.max.x = math.max(box.max.x,p.x)
                                        box.max.y = math.max(box.max.y,p.y)
                                        box.max.z = math.max(box.max.z,p.z)
                                end
                        end
                end
        end
        if box~=nil then box:Update() end
        return box
end

function Script:UpdatePhysics()
        carsx[self.id]=self.entity:GetPosition(true).x
		carsz[self.id]=self.entity:GetPosition(true).z
		self.compass:Point(points[self.goal])
		
        local steerangle=0
		steerangle=self:toAngle(self.compass:GetRotation().y+180)--(self:toAngle(Math:ATan2(points[self.goal]:GetPosition(true).y-self.entity:GetPosition().y,points[self.goal]:GetPosition(true).x-self.entity:GetPosition().x))+90)

        --if window:KeyDown(Key.Space) then brakes = 5000 end
        self.vehicle:SetBrakes(self.brakes)

        if self.enableESP then
                local force=0
                local n
                local threshold=50
                for n=0,self.vehicle:CountTires()-1 do
                        force = math.max(force, self.vehicle:GetTireLateralForce(n))
                end
                force = force / self.tiremass
                
                self.steerangle = steerangle * Math:Clamp((threshold-(force-threshold))/threshold,0,1)
                --local roll = math.abs(self.entity:GetRotation().z)
                --steerangle = steerangle * Math:Clamp((5-roll)/5,0,1)
        end
        
        if self.smoothedsteerangle==nil then self.smoothedsteerangle = self.steerangle end
        
        self.smoothedsteerangle = Math:Inc(self.steerangle,self.smoothedsteerangle,3)
        self.vehicle:SetSteering(self.smoothedsteerangle)
        
        self.steerangle=steerangle
        
        ----------------------------------------------
        --Handle acceleration
        ----------------------------------------------
        local gas = 0
		
        if not self:CheckDistance(points[self.goal]:GetPosition(),1) and math.abs(steerangle)<100 then
				if self.entity:GetVelocity():Length()*speedconstant<self.maxspeed then
					if self.done==false then
						gas = gas - self.acceleration
					end
				end
                
                --Start engine
                if self.vehicle:GetEngineRunning()==false then
                        self.enginestarttime=Time:GetCurrent()
                        self.vehicle:SetEngineRunning(true)
                        self.vehicle:SetHandBrakes(0)
                        if self.sound.enginestart~=nil then
                                if self.source.enginestart==nil then
                                        self.source.enginestart=Source:Create()
                                        self.source.enginestart:SetSound(self.sound.enginestart)
                                end
                                --self.source.enginestart:Play()
                        end
                        if self.source.engineloop==nil then
                                if self.sound.engineloop~=nil then
                                        self.source.engineloop=Source:Create()
                                        self.source.engineloop:SetSound(self.sound.engineloop)
                                        self.source.engineloop:SetLoopMode(true)                                        
                                end
                        end
                end
		else
			--System:Print("goal")
			--System:Print(self.goal)
			local string1=points[self.goal]:GetKeyValue("next1")
			local string2=points[self.goal]:GetKeyValue("next2")
			local string3=points[self.goal]:GetKeyValue("next3")
			local choicestring=0
			math.randomseed(Math:Round(Time:Millisecs()))
			--print (choicestring)
			if string2=="" and string3=="" then
				self.goal=tonumber(string1)
			elseif string3=="" then
				choicestring=math.random(0,100)
				if choicestring>50 then
					self.goal=tonumber(string1)
				else
					self.goal=tonumber(string2)
				end
			else
				choicestring=math.random(0,100)
				if choicestring<33 then
					self.goal=tonumber(string1)
				elseif choicestring>66 then
					self.goal=tonumber(string2)
				else
					self.goal=tonumber(string3)
				end
			end
			--print(tostring(self.goal).."test2")
        end
        
        if gas<0 then
                --gas = gas + self.acceleration
        end
        
        if self.vehicle:GetEngineRunning() then
                if Time:GetCurrent()-self.enginestarttime>2000 then
                        local gear
                        if gas<0 then
                                gas = -gas
                                gear = -1
                        else
                                gear = 1
                        end
                        
                        if self.smoothedgas==nil then self.smoothedgas = 0 end
                        if gas>self.smoothedgas then
                                self.smoothedgas = Math:Inc(gas,self.smoothedgas,0.01)
                        else
                                self.smoothedgas=gas
                        end
                        
						if Time:Millisecs()-self.localtime>self.timethreshold then
							for i=0,spikesize-1 do
								if spikes[i]~=nil then
									if self:getDist(spikes[i]:GetPosition(), self.entity:GetPosition())<4 then
										gas=0
										self.brakes=5000
										self.done=true
									end
								end
							end
							local pickfront=PickInfo()
							local lworld=World:GetCurrent()
							self.localtime=Time:Millisecs()
							if lworld:Pick(self.frontclose:GetPosition(true),self.frontfar:GetPosition(true),pickfront) then
								self.slowdown=1
							else
								self.slowdown=0
							end
						end
						

						if self.slowdown==1 then
							self.smoothedgas=0
							self.brakes=5000
						elseif pointslights[self.goal]==1 then
							if self:CheckDistance(points[self.goal]:GetPosition(true),4) then
								self.brakes=self:ClampZero(self.entity:GetVelocity():Length()*10000)
								self.smoothedgas=0
							end
						else
							self.brakes=0
						end
						
						if self.entity:GetVelocity():Length()>(.01*self.maxspeed)*self:ClampZero(100-math.abs(steerangle)) then
							self.smoothedgas=0
							self.brakes=(1000*self.maxspeed)/self:ClampZero(100-math.abs(steerangle))
						end
                        self.vehicle:SetAcceleration(self.smoothedgas)
                        self.vehicle:SetGear(gear)
                end
        end
        ----------------------------------------------
        ----------------------------------------------
        
        if self.vehicle:GetEngineRunning() then
                if self.source.engineloop~=nil then
                        if self.source.engineloop:GetState()==Source.Stopped then
                                if self.source.enginestart~=nil then                                    
                                        if self.source.enginestart:GetTime()>1 then
                                                --self.source.engineloop:Play()
                                        end
                                else
                                        --self.source.engineloop:Play()
                                end
                        end
                        local pitch = self.vehicle:GetRPM()/5500.0+0.5
                        if self.smoothedpitch==nil then self.smoothedpitch=pitch end
                        self.smoothedpitch = Math:Curve(pitch,self.smoothedpitch,10)
                        self.source.engineloop:SetPitch(self.smoothedpitch)
                end
        end
		

end

function Script:UpdateWorld()
	local point1=0
	if self.criminal==true then
		if self:getDist(self.entity:GetPosition(), Vec3(posx, posy, posz))<25 then
			if  self.entity:GetVelocity():Length()*speedconstant<5 then
				self.criminal=false
				criminalspots=criminalspots+1
				score=score+1
				cash=cash+100
				criminalarrests=criminalarrests+1
				self.pointer:SetMaterial(invisibletexture)
			end
		end
	end
	
	if self.chase==1 then
		if self:getDist(self.entity:GetPosition(), Vec3(posx, posy, posz))<25 then
			if  self.entity:GetVelocity():Length()*speedconstant<5 then
				self.chase=0
				questcriminal=true
				self.pointer:SetMaterial(invisibletexture)
			end
		end
	end
	
	if self.criminal==false and (self.questcriminal==false or questcriminal==false) and self.repawn then
	if carsinplay>=carsinplaym then
		if math.abs(posx-self.entity:GetPosition(true).x)>self.distance or math.abs(posz-self.entity:GetPosition(true).z)>self.distance then
			local pickground=PickInfo()
			carsinplay=carsinplay-1
			local lworld=World:GetCurrent()

			local string1=points[currentminpoint]:GetKeyValue("next1")
			local string2=points[currentminpoint]:GetKeyValue("next2")
			local string3=points[currentminpoint]:GetKeyValue("next3")
			local choicestring=0
			math.randomseed(Math:Round(Time:Millisecs()))
			--print (choicestring)
			if string2=="" and string3=="" then
				point1=tonumber(string1)
			elseif string3=="" then
				choicestring=math.random(0,100)
				if choicestring>50 then
					point1=tonumber(string1)
				else
					point1=tonumber(string2)
				end
			else
				choicestring=math.random(0,100)
				if choicestring<33 then
					point1=tonumber(string1)
				elseif choicestring>66 then
					point1=tonumber(string2)
				else
					point1=tonumber(string3)
				end
			end
			
			local string1=points[point1]:GetKeyValue("next1")
			local string2=points[point1]:GetKeyValue("next2")
			local string3=points[point1]:GetKeyValue("next3")
			local choicestring=0
			math.randomseed(Math:Round(Time:Millisecs()))
			--print (choicestring)
			if string2=="" and string3=="" then
				point1=tonumber(string1)
			elseif string3=="" then
				choicestring=math.random(0,100)
				if choicestring>50 then
					point1=tonumber(string1)
				else
					point1=tonumber(string2)
				end
			else
				choicestring=math.random(0,100)
				if choicestring<33 then
					point1=tonumber(string1)
				elseif choicestring>66 then
					point1=tonumber(string2)
				else
					point1=tonumber(string3)
				end
			end
			--System:Print(tostring(point1).."fail")
			if self.recycle==0 then
				self.recycle=self.recycle+1
				--self.body:Release()
				
				math.randomseed(Math:Round(Time:Millisecs()))
				local rand_num=math.random(0,100)
				
			end
			
			local near=true
			local move=0
			
			while near==true do
				near=false
				local tempposition=Vec3(move,0,0)+Vec3(points[point1]:GetPosition(true).x,points[point1]:GetPosition(true).y+2,points[point1]:GetPosition(true).z)
				carsx[self.id]=tempposition.x
				carsz[self.id]=tempposition.z
				for key,value in ipairs(carsx) do
					--if self:getDist(Vec3(points[point1]:GetPosition(true).x,points[point1]:GetPosition(true).y,points[point1]:GetPosition(true).z)+Vec3(move,0,0),Vec3(value,0,carsz[key]))<16 then
					if math.abs(points[point1]:GetPosition(true).x-carsx[key])<4 and math.abs(points[point1]:GetPosition(true).z-carsz[key])<16 then
						near=true
						--print("jalsdfjlkasjdfklasjfklasjflsadjfl")
					end
				end
				if near==false then
					tempposition=Vec3(move,0,0)+Vec3(points[point1]:GetPosition(true).x,points[point1]:GetPosition(true).y+1,points[point1]:GetPosition(true).z)
					--lworld:Pick(tempposition+Vec3(0,100,0),Vec3(tempposition.x,-1,tempposition.z),pickground)
					lastcarinplay=Time:Millisecs()
					--System:Print(tostring(point1).."test2")

					self.entity:PhysicsSetPosition(tempposition.x,tempposition.y,tempposition.z,0)
					self.entity:SetMass(0)
					self.body:SetPosition(self.entity:GetPosition(true)+Vec3(0,.3,0),true)
					self.body:SetRotation(self.entity:GetRotation(true),true)
					self.body:SetParent(self.entity)
					self.entity:SetPosition(Vec3(tempposition.x,tempposition.y,tempposition.z),true)
					carsx[self.id]=self.entity:GetPosition(true).x
					carsz[self.id]=self.entity:GetPosition(true).z
					--print(carsx[self.id])
					--print(carsz[self.id])
					self.spawned=true
					print("test")
				else
					move=move+5
				end
			end
			
			self.entity:SetMass(2000)

			if criminalspots>0 then
				criminalspots=criminalspots-1
				if self.questcriminal==false then
					self.criminal=true
				end
				currentmessagetime=Time:Millisecs()
				self.pointer:SetMaterial(pointertexture)
			end

			--self:BuildVehicle()
			--self.entity:SetPosition(self.entity:GetPosition()+Vec3(0,.1,0))
			local string1=points[point1]:GetKeyValue("next1")
			local string2=points[point1]:GetKeyValue("next2")
			local string3=points[point1]:GetKeyValue("next3")
			local choicestring=0
			math.randomseed(Math:Round(Time:Millisecs()))
			--print (choicestring)
			if string2=="" and string3=="" then
				point1=tonumber(string1)
			elseif string3=="" then
				choicestring=math.random(0,100)
				if choicestring>50 then
					point1=tonumber(string1)
				else
					point1=tonumber(string2)
				end
			else
				choicestring=math.random(0,100)
				if choicestring<33 then
					point1=tonumber(string1)
				elseif choicestring>66 then
					point1=tonumber(string2)
				else
					point1=tonumber(string3)
				end
			end
			
			--System:Print(tostring(point1).."test")

			self.goal=point1
			self.compass:Point(points[self.goal])
			self.entity:PhysicsSetRotation(0,self.compass:GetRotation().y,0,0)
			self.entity:SetMass(0)
			self.entity:SetRotation(0,self.compass:GetRotation().y,0)
			self.entity:SetMass(1000)
			
			
			if math.abs(posx-self.entity:GetPosition(true).x)<=self.distance and math.abs(posz-self.entity:GetPosition(true).z)<=self.distance then
				self.recycle=0
			end
			
		end
	end
	end
	
	if Time:Millisecs()-lastcarinplay>self.resettime and self.spawned then
		carsinplay=carsinplay+1
		self.spawned=false
	end
	--System:Print(tostring(self.goal).."test3")
end

function Script:Draw()
        local index
        local child
        local scale
        
        for index,child in ipairs(self.tires) do
                scale = child:GetScale()
                child:SetMatrix(self.vehicle:GetTireMatrix(index-1),true)
                child:SetScale(scale)
        end
end

function Script:toAngle(angle)
	if angle<-180 then
		angle=180+(angle+180)
	end
	if angle>180 then
		angle=-180-(180-angle)
	end
	return angle
end

function Script:getDist(vec3a, vec3b)
	return (math.pow(vec3a.x-vec3b.x,2)+math.pow(vec3a.z-vec3b.z,2))
end

function Script:questPlace(spawn,goala)
	local tempposition=Vec3(spawn:GetPosition(true).x,spawn:GetPosition(true).y+1,spawn:GetPosition(true).z)
	self.entity:SetMass(0)
	self.body:SetPosition(self.entity:GetPosition(true)+Vec3(0,.3,0),true)
	self.body:SetRotation(self.entity:GetRotation(true),true)
	self.body:SetParent(self.entity)
	self.entity:SetPosition(Vec3(tempposition.x,tempposition.y,tempposition.z),true)
	carsx[self.id]=self.entity:GetPosition(true).x
	carsz[self.id]=self.entity:GetPosition(true).z
	self.goal=goala
	self.pointer:SetMaterial(pointertexture)
	self.compass:Point(points[self.goal])
	self.entity:PhysicsSetRotation(0,self.compass:GetRotation().y,0,0)
	self.entity:SetMass(0)
	self.entity:SetRotation(0,self.compass:GetRotation().y,0)
	self.entity:SetMass(1000)
	self.chase=1
end

function Script:CheckDistance(veca, dist)
	if math.abs(veca.x-self.entity:GetPosition().x)<dist and math.abs(veca.z-self.entity:GetPosition().z)<dist then
		return true
	else
		return false
	end
end

function Script:ClampZero(a)
	if a<0 then
		return 0
	else
		return a
	end
end

function Script:Detach()
        ReleaseTableObjects(self.source)
        ReleaseTableObjects(self.sound)
end