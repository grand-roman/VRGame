Script.speedlimit="20"--String "Speed Limit"
Script.next1=""--String "Choice 1"
Script.next2=""--String "Choice 2"
Script.next3=""--String "Choice 3"

function Script:Start()
	self.entity:SetKeyValue("speedlimit",tostring(self.speedlimit))
	self.entity:SetKeyValue("next1",self.next1)
	self.entity:SetKeyValue("next2",self.next2)
	self.entity:SetKeyValue("next3",self.next3)
end