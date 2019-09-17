function Script:Start()
	local current=0
	local x=0
	while current<self.entity:CountChildren() do
		if self.entity:FindChild("Point" .. tostring(x))~=nil then
			points[x]=self.entity:FindChild("Point" .. tostring(x))
			pointslights[x]=0
			pointsi[current]=x
			numpoints=current
			current=current+1
		end
		toppoint=x
		x=x+1
		System:Print("number of points")
	end
end