local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemDatabase = require(ReplicatedStorage:WaitForChild("ItemDatabase"))

-- ตำแหน่งเริ่มต้นที่จะให้ปืนดรอป (แก้พิกัด XYZ ได้ตามต้องการ)
local startPosition = Vector3.new(0, 5, 20) 
local spacing = 4 -- ระยะห่างระหว่างปืนแต่ละกระบอก
local offset = 0

-- สร้าง Folder สำหรับ ItemSpawns ถ้ายังไม่มีใน Workspace
local itemSpawnsFolder = workspace:FindFirstChild("ItemSpawns")
if not itemSpawnsFolder then
	itemSpawnsFolder = Instance.new("Folder")
	itemSpawnsFolder.Name = "ItemSpawns"
	itemSpawnsFolder.Parent = workspace
end

-- ฟังก์ชันสำหรับสร้างจุดดรอป
local function spawnItemForTesting()
	for itemId, itemData in pairs(ItemDatabase.Items) do
		-- เช็คว่าเป็นอาวุธไหม (ถ้าอยากให้ดรอปกระสุนหรือยาด้วยก็เอาเงื่อนไขนี้ออก)
		if type(itemData) == "table" and itemData.Type == "Weapon" then

			-- สร้างตัวแทนของที่ดรอป (ถ้ามี Model ปืนแล้ว ให้อ่านคำแนะนำด้านล่างครับ)
			local dropPart = Instance.new("Part")
			dropPart.Name = "ItemSpawn_" .. itemId
			dropPart.Size = Vector3.new(3, 1, 1)
			dropPart.Position = startPosition + Vector3.new(offset, 0, 0)
			dropPart.Anchored = true
			dropPart.CanCollide = false
			dropPart.BrickColor = BrickColor.new("Bright blue")
			dropPart.Parent = itemSpawnsFolder

			-- สร้างป้ายชื่อลอยอยู่บนไอเทม (BillboardGui)
			local billboard = Instance.new("BillboardGui")
			billboard.Size = UDim2.new(0, 150, 0, 50)
			billboard.StudsOffset = Vector3.new(0, 2, 0)
			billboard.AlwaysOnTop = true
			billboard.Parent = dropPart

			local textLabel = Instance.new("TextLabel")
			textLabel.Size = UDim2.new(1, 0, 1, 0)
			textLabel.BackgroundTransparency = 1
			textLabel.Text = itemData.Name .. "\n[F] เก็บ"
			textLabel.TextColor3 = Color3.new(1, 1, 1)
			textLabel.TextStrokeTransparency = 0
			textLabel.TextScaled = true
			textLabel.Font = Enum.Font.FredokaOne
			textLabel.Parent = billboard

			-- ขยับจุดเกิดของชิ้นต่อไป
			offset = offset + spacing
		end
	end
end

-- หน่วงเวลาเล็กน้อยรอให้เกมโหลดเสร็จก่อนค่อยเสก
task.wait(2)
spawnItemForTesting()