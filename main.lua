----------------------------------------------------------------
-- Copyright (c) 2012 Christopher Waite
-- Bytesize Adventures
-- All Rights Reserved.
-- http://www.bytesizeadventures.com
----------------------------------------------------------------

-------------------------------
-- global variables
-------------------------------

-- screen
local screenSizeX = 1280
local screenSizeY = 768

-- frame per second
local totalFrames = 30

-- sprite size (sqaured)
local sprite_size = 16

-- dirt row & column tracking
local currentDirtLayer = 0

-- calculate the total columns and rows
local totalColumns = screenSizeX/sprite_size
local totalRows = screenSizeY/sprite_size

local rowsInHalfAScreen = math.floor((totalRows/2) + 0.5)

-- the current column should be the center of the columns
local currentDirtColumn = totalColumns/2

-- table for rendering
local dirtLayers = {}

-- table for data recording
local levelData = {}

-- keyboard
local currentKey = ""
local drill = false

-- world size
local chunks = 5
local maxRows = (chunks*rowsInHalfAScreen)

worldGeneration = false

-- variables for collection
local dirtCollected = 0
local rockCollected = 0
local sandCollected = 0

--------------------------------
-- helper functions
--------------------------------

local function printf ( ... )
	return io.stdout:write ( string.format ( ... ))
end

local function convertGridToXY ( column, row )
	-- convery a row and column to actual screen position values
	local x = (column - (totalColumns/2)) * sprite_size
	local y = (row - 1) * - sprite_size

	return x,y

end

local function convertXYToGrid ( x, y )
	-- convert an x and y coord to a grid position
	local column = (totalColumns/2) + (x/sprite_size)
	local row = (-y/sprite_size) + 1

	return column, row

end

local function isPlayerAtGridPos ( column, row )

	local playerX, playerY = player:getLoc()

	local playerColumn, playerRow = convertXYToGrid( playerX, playerY )

	if playerColumn == column and playerRow == row then

		return true

	end

	return false

end

local function printDebug (  )
	local x1, y1 = player:getLoc ()
	printf ( "player: x:%d y%d\n", x1, y1 )
	printf ( "current row = %d\n", currentDirtLayer )
	printf ( "current column = %d\n", currentDirtColumn )

	local c, r = convertXYToGrid (x1, y1)
	printf ("temp c=%d r=%d\n", c, r)
end

local function updateMaterialCollected (type, amount)

	if type == "d" then

		dirtCollected = dirtCollected + amount

		dirtCollectedTextbox:setString(string.format('Dirt Collected: %d',dirtCollected))

	elseif type == "r" then

		rockCollected = rockCollected + amount

		rockCollectedTextbox:setString(string.format('Rock Collected: %d',rockCollected))

	elseif type == "s" then

		sandCollected = sandCollected + amount

		sandCollectedTextbox:setString(string.format('Sand Collected: %d',sandCollected))

	end

end

-- remove a block from the screen & the data - replace it with empty
function removeBlock ( column, row )
	
	-- if the row exists
	if (dirtLayers [ row ]) then

		-- set local variables to the layers (rendering and data)
		local dirtPropRow = dirtLayers [ row ]
		local dirtPropRowData = levelData [ row ]

		-- if the column exists
		if (dirtPropRow [ column ]) then
			local dirtProp = dirtPropRow [ column ]
			
			local h = dirtProp:returnHealth()
			printf ( "original block health: %d\n", h )

			if h==0 then

				updateMaterialCollected (dirtProp:returnBlockType(), 1)
				
				dirtProp:destroy()
				dirtPropRow [ column ] = nil
				dirtPropRowData [ column ] = 'e'

				--sound:play ()
				
				return true
			else
				dirtProp:reduceHealth(1)
				h = dirtProp:returnHealth()
				printf ( "new block health: %d\n", h )
				return false
			end			
		end
	end

	return false

end

-- replace a block with a new one
function replaceBlock ( column, row, type )

	local dirtPropRowData = levelData [ row ]
	local dirtPropRow = {}

	if (dirtLayers [ row ] and dirtLayers [ row ] ~= nil) then
		dirtPropRow = dirtLayers [ row ]

		-- remove the rendered block if it exists
		if (dirtPropRow [ column ]) then
			local dirtProp = dirtPropRow [ column ]
			dirtProp:destroy()
			dirtPropRow [ column ] = nil
		end
	end

	-- find the real pixel position
	local posX,posY = convertGridToXY ( column, row )

	-- add a block
	if type == 'dirt' then

		local dirtPropCreated = makeDirtPiece (posX, posY)
		-- set the redering table - omly if its visible
		dirtPropRow [ column ] = dirtPropCreated
		-- set the data table
		dirtPropRowData [ column ] = 'd'

	elseif type == 'ladder' then

		local dirtPropCreated = makeLadder (posX, posY)
		-- set the redering table
		dirtPropRow [ column ] = dirtPropCreated
		-- set the data table
		dirtPropRowData [ column ] = 'l'

	elseif type == 'rock' then

		local dirtPropCreated = makeRock (posX, posY)
		dirtPropRow [ column ] = dirtPropCreated
		dirtPropRowData [ column ] = 'r'

	elseif type == 'water' then

		local dirtPropCreated = makeWater (posX, posY)
		dirtPropRow [ column ] = dirtPropCreated
		dirtPropRowData [ column ] = 'w'

	elseif type == 'sand' then

		local dirtPropCreated = makeSand (posX, posY)
		dirtPropRow [ column ] = dirtPropCreated
		dirtPropRowData [ column ] = 's'

	elseif type == 'empty' then

		dirtPropRowData [ column ] = 'e'

	end

end

--[[function moveWaterBlock ( column_start, row_start, column_end, row_end )
		
	local dirtPropRowData = levelData [ row_start ]
	local dirtPropRow = dirtLayers [ row_start ]

	if dirtPropRow [ column_start ] ~= nil then

		-- remove existing data
		dirtPropRowData [ column_start ] = 'e'

		-- move sprite and add it to render table
		local blockProp = dirtPropRow [ column_start ]

		local newX,newY = convertGridToXY (column_end, row_end)
		
		--this needs to be a very fast movement animation
		blockProp:moveLoc (newX,newY,0.25)

		local dirtPropRowNew = dirtLayers [ row_end ]

		dirtPropRowNew [ column_end ] = blockProp

		-- set old sprite to nil
		dirtPropRow [ column_start ] = nil

		-- set new data

		local dirtPropRowDataNew = levelData [ row_end ]
		
		dirtPropRowDataNew [ column_end ] = 'w'

	end

end]]--

--------------------------------
-- world generation
--------------------------------

function makeDirtPiece (x,y)

	local dirtProp = MOAIProp2D.new ()
  	dirtProp:setDeck ( dirt )
  	dirtProp:setLoc (x,y)
  	layer:insertProp ( dirtProp )

  	local health = 1
  	local blockType = "d"

  	function dirtProp:destroy ()
 		layer:removeProp ( self )
		self = nil
 	end

 	function dirtProp:returnBlockType ()
 		return blockType
 	end

 	function dirtProp:returnHealth ()
 		return health
 	end

	function dirtProp:reduceHealth (reduction)
 		health = health-reduction
 	end

  	return dirtProp
end

function makeLadder (x,y)

	-- create the ladder and add it
	local dirtProp = MOAIProp2D.new ()
	--dirtProp:setPriority (0)
  	dirtProp:setDeck ( ladder )
  	dirtProp:setLoc (x,y)
  	layer:insertProp ( dirtProp )

  	local blockType = "l"

  	function dirtProp:destroy ()
 		layer:removeProp ( self )
		self = nil
 	end

 	function dirtProp:returnBlockType ()
 		return blockType
 	end

  	return dirtProp

end

function makeRock (x,y)

	-- create the rock and add it
	local dirtProp = MOAIProp2D.new ()
  	dirtProp:setDeck ( rock )
  	dirtProp:setLoc (x,y)
  	layer:insertProp ( dirtProp )

  	local health = 10
  	local blockType = "r"

  	function dirtProp:destroy ()
 		layer:removeProp ( self )
		self = nil
 	end

 	function dirtProp:returnBlockType ()
 		return blockType
 	end

 	function dirtProp:returnHealth ()
 		return health
 	end

	function dirtProp:reduceHealth (reduction)
 		health = health-reduction
 	end

  	return dirtProp

end

function makeSand (x,y)

	-- create the rock and add it
	local dirtProp = MOAIProp2D.new ()
  	dirtProp:setDeck ( sand )
  	dirtProp:setLoc (x,y)
  	layer:insertProp ( dirtProp )

  	local health = 1
  	local blockType = "s"

  	function dirtProp:destroy ()
 		layer:removeProp ( self )
		self = nil
 	end

 	function dirtProp:returnBlockType ()
 		return blockType
 	end

 	function dirtProp:returnHealth ()
 		return health
 	end

	function dirtProp:reduceHealth (reduction)
 		health = health-reduction
 	end

 	return dirtProp

end

function makeWater (x,y)

	-- create the water and add it
	local dirtProp = MOAIProp2D.new ()
  	--dirtProp:setPriority (20)
  	dirtProp:setDeck ( water )
  	dirtProp:setLoc (x,y)
  	layer:insertProp ( dirtProp )

  	local blockType = "w"

  	function dirtProp:destroy ()
 		layer:removeProp ( self )
		self = nil
 	end

 	function dirtProp:returnBlockType ()
 		return blockType
 	end

 	function dirtProp:returnHealth ()
 		return 0
 	end

 	return dirtProp

end

function loadExistingChunk ( column_start, column_end, row_start, row_end )
	
	for r=row_start, row_end do

		if(levelData [ r ]) then
			local dirtPropRow = levelData [ r ]
			local dirtBlocks = {}

			for c=column_start, column_end do
				if (dirtPropRow [ c ]) then
					
					if dirtPropRow [ c ] == 'd' then
						local posX,posY = convertGridToXY ( c, r )
						local dirtProp = makeDirtPiece (posX,posY)
						dirtBlocks [ c ] = dirtProp
					elseif dirtPropRow [ c ] == 'l' then
						local posX,posY = convertGridToXY ( c, r )
						local dirtProp = makeLadder (posX,posY)
						dirtBlocks [ c ] = dirtProp
					elseif dirtPropRow [ c ] == 'r' then
						local posX,posY = convertGridToXY ( c, r )
						local dirtProp = makeRock (posX,posY)
						dirtBlocks [ c ] = dirtProp
					elseif dirtPropRow [ c ] == 'w' then
						local posX,posY = convertGridToXY ( c, r )
						local dirtProp = makeWater (posX,posY)
						dirtBlocks [ c ] = dirtProp
					elseif dirtPropRow [ c ] == 's' then
						local posX,posY = convertGridToXY ( c, r )
						local dirtProp = makeSand (posX,posY)
						dirtBlocks [ c ] = dirtProp
					end


				end
			end

			dirtLayers [ r ] = dirtBlocks

		end
	end

end

function removeScreenChunk ( column_start, column_end, row_start, row_end )

	for r=row_start, row_end do

		if(dirtLayers [ r ]) then
			local dirtPropRow = dirtLayers [ r ]

			for c=column_start, column_end do
				if (dirtPropRow [ c ]) then
					local dirtProp = dirtPropRow [ c ]
					dirtProp:destroy()
					dirtPropRow [ c ] = nil
				end
			end
		end
	end

end


------------------------------------
-- Algorithm to generate the world
------------------------------------

-- This generates the world data before the game loads. It loads it into the levelData array. It can do multiple passes to make an interesting landscape.

-- this just replaces the block data since no rendering has happened yet
function replaceBlockData ( column, row, type )

	if levelData [ row ] then
		local dirtPropRowData = levelData [ row ]
		
		-- add a block
		if type == 'dirt' then

			-- set the data table
			dirtPropRowData [ column ] = 'd'

		elseif type == 'ladder' then

			dirtPropRowData [ column ] = 'l'

		elseif type == 'rock' then

			dirtPropRowData [ column ] = 'r'

		elseif type == 'water' then

			dirtPropRowData [ column ] = 'w'

		elseif type == 'sand' then

			dirtPropRowData [ column ] = 's'

		elseif type == 'empty' then

			dirtPropRowData [ column ] = 'e'

		end
	end

end

function getBlockTypeAtLocation (column, row)

	local blockType = ''

	if levelData [ row ] then
		local dirtPropRowData = levelData [ row ]

		blockType = dirtPropRowData [ column ]
	end

	return blockType

end

function createVeins (nunberOfVeins, veinSize, type)

	-- define the starting points of the veins
	local veins = {}

	--randomly select x number of vein positions
	for n=1, nunberOfVeins do
		local randomColumn = math.random(1, totalColumns)
		-- can't appear until 10 rows deep
		local randomRow = math.random(10, maxRows)
		-- row -> column
		veins [ randomRow ] = randomColumn
	end
	
	for i,v in pairs(veins) do

		printf("creating %s vein at row:%d column:%d\n",type,i,v)

		-- the rock vein is generated

		local currentRow = i
		local currentColumn = v

		for x=1,veinSize do

			-- 1 of 4 directions
			local direction = math.random(1,4)

			-- north
			if direction == 1 then

				currentRow = currentRow - 1
				
			-- east
			elseif direction == 2 then

				currentColumn = currentColumn + 1

			-- south
			elseif direction == 3 then

				currentRow = currentRow + 1

			-- west
			elseif direction == 4 then

				currentColumn = currentColumn - 1

			end

			--it could replace block data a few tiles around its new location too for more dramatic effects
			replaceBlockData ( currentColumn,currentRow, type )

		end

	end

end

function generateWorld (size)

	local column_start = 0
	local column_end = totalColumns
	local row_start = 1
	local row_end = size

	printf("-- BUILDING WORLD WITH %d COLUMNS AND %d ROWS - SIZE=%d --\n",column_end,size,column_end*size)

	-- first pass to create the dirt
	for r=row_start, row_end do

		-- array for flat data
		local dataRow = {}

		for c=column_start, column_end do
				
			local posX,posY = convertGridToXY ( c, r )
			
			dataRow [ c ] = 'd'	
		
		end

		-- set the lookup for data
		levelData [ r ] = dataRow
		
	end

	-- second pass for veins of ore

	-- create veins of rock
	createVeins (5, 20, "rock")

	-- create veins of sand
	createVeins (10, 100, "sand")

	-- third pass for caves

	local numberOfCavesToCreate = 5
	-- define the starting points of the caves
	local caves = {}

	local caveSize = 500

	-- table to store the water points
	local water = {}

	--randomly select x number of vein positions
	for n=1, numberOfCavesToCreate do
		local randomColumn = math.random(1, totalColumns)
		-- can't appear until x rows deep
		local randomRow = math.random(20, maxRows)
		-- row -> column
		caves [ randomRow ] = randomColumn
	end
	
	for i,v in pairs(caves) do

		printf("creating cave at row:%d column:%d\n",i,v)

		--for each of these start points, loop x number of time and destroy an adjacent tile

		local currentRow = i
		local currentColumn = v

		local caveColumnStart = currentColumn
		local caveColumnEnd = currentColumn
		local caveRowLowest = currentRow

		local waterData = {}

		for x=1,caveSize do

			-- 1 of 4 directions
			local direction = math.random(1,4)

			-- north
			if direction == 1 then

				currentRow = currentRow - 1
				
			-- east
			elseif direction == 2 then

				currentColumn = currentColumn + 1

			-- south
			elseif direction == 3 then

				currentRow = currentRow + 1

			-- west
			elseif direction == 4 then

				currentColumn = currentColumn - 1

			end

			-- mine the current block
			replaceBlockData ( currentColumn,currentRow, "empty" )

			-- mine a block in either direction. This creates a bulkier effect
			replaceBlockData ( currentColumn+1,currentRow, "empty" )
			replaceBlockData ( currentColumn-1,currentRow, "empty" )
			replaceBlockData ( currentColumn,currentRow+1, "empty" )
			replaceBlockData ( currentColumn,currentRow-1, "empty" )

			-- determine cave confines
			if (currentRow + 1) > caveRowLowest then
				caveRowLowest = (currentRow + 1)
			end

			if (currentColumn - 1) < caveColumnStart then
				caveColumnStart = (currentColumn - 1)
			end

			if (currentColumn + 1) > caveColumnEnd then
				caveColumnEnd = (currentColumn + 1)
			end

		end

		-- setup the water data
		-- column start => column end
		waterData [ caveColumnStart ] = caveColumnEnd

		-- lowest row => column data
		water [ caveRowLowest ] = waterData

	end


	-- fourth pass for water, foliage, etc

	-- Water, use the cave start points to generate a source block

	for i,v in pairs(caves) do

		for x=-10,10 do
			for y=-10,10 do
				if getBlockTypeAtLocation(v+x,i+y) == 'e' and v+x >= 0 and v+x <= totalColumns and i+y <= maxRows then
					replaceBlockData ( v+x,i+y, "water" )
					printf("creating water at column:%d row%d\n",v+x,i+y)
				end
			end
		end
	end

	-- Now make the water flow - just the data though. Same algo as renderer sans render








	worldGeneration = true

end


--------------------------------
-- keyboard events
--------------------------------

function onKeyboardEvent ( key, down )

	if down == true then
		--printf ( "keyboard: %d down\n", key )
		if key == 97 then
			currentKey = "left"

		elseif key == 100 then
			currentKey = "right"

		elseif key == 115 then
			currentKey = "down"

		elseif key == 119 then
			currentKey = "up"

		elseif key == 32 then
			drill = true

		end
	else
		if key == 97 then
			currentKey = ""

		elseif key == 100 then
			currentKey = ""

		elseif key == 115 then
			currentKey = ""

		elseif key == 119 then
			currentKey = ""

		elseif key == 32 then
			drill = ""

		end
	end
end

--------------------------
-- camera
--------------------------

function moveCamera ( directionX, directionY )

	fitterX, fitterY = fitter:getFitLoc ()	
	fitter:setFitLoc ( (fitterX+directionX), (fitterY+directionY) )
	
end

--------------------------
-- collision detection
--------------------------

function hit ( prop1, prop2, dist )

	x1, y1 = prop1:getLoc ()
	x2, y2 = prop2:getLoc ()
	
	if x1 == x2 and y1 == y2 then
		return true
	end

	return false

end

function radialHit ( prop1, prop2, dist )

	x1, y1 = prop1:getLoc ()
	x2, y2 = prop2:getLoc ()
	
	dx = x2 - x1
	dy = y2 - y1
	
	return dx * dx + dy * dy <= dist * dist

end

function checkCollision (layerToCheck, columnToCheck)

	-- block detection
	if levelData [ layerToCheck ] then
		
		local currentLayerData = levelData [ layerToCheck ]

		-- if were coliding with dirt, remove the block
		if currentLayerData [ columnToCheck ] == 'd' and drill == true then
			
			local actionBool = removeBlock ( columnToCheck, layerToCheck )
			return actionBool

		elseif currentLayerData [columnToCheck] == 'r' and drill == true then

			local actionBool = removeBlock ( columnToCheck, layerToCheck )
			return actionBool
			--once we have a gui layer, we can increment the rock quantities here - or rather, add it to the current player bucket

		elseif currentLayerData [columnToCheck] == 's' and drill == true then

			local actionBool = removeBlock ( columnToCheck, layerToCheck )
			return actionBool

		-- when its empty we can go ahead and move so force true
		elseif currentLayerData [columnToCheck] == 'e' or currentLayerData [columnToCheck] == 'l' or currentLayerData [columnToCheck] == 'w' then

			return true

		end

	end

	return false

end

function checkEmptySpaceBelow ()

	if currentDirtLayer ~= 0 and currentDirtLayer < maxRows then
		local rowBelow = levelData [ currentDirtLayer+1 ]
		local currentRow = levelData [ currentDirtLayer ]

		if((rowBelow [ currentDirtColumn ] == 'e' or (rowBelow [ currentDirtColumn ] == 'w' and (currentKey ~= "up"))) and currentRow [ currentDirtColumn ] ~= 'l') then
			action = player:moveLoc ( 0, -sprite_size, 0 )
			moveCamera ( 0, -sprite_size )
			currentDirtLayer = currentDirtLayer+1
			printDebug()
			loadExistingChunk ( 0, totalColumns, currentDirtLayer+rowsInHalfAScreen, currentDirtLayer+rowsInHalfAScreen )
			removeScreenChunk ( 0, totalColumns, currentDirtLayer-rowsInHalfAScreen, currentDirtLayer-rowsInHalfAScreen )
		end
	end
end

----------------------------------
-------- Fluid Simulation --------
----------------------------------

function simulateWater ( column, row )
	
	local gridC = column
	local gridR = row

	if getBlockTypeAtLocation(gridC,gridR+1) == 'e' then

		if gridR < currentDirtLayer+rowsInHalfAScreen and gridR > currentDirtLayer-rowsInHalfAScreen then

			replaceBlock (gridC,gridR,"empty")

		else

			replaceBlockData (gridC,gridR,"empty")

		end

		if gridR+1 <= currentDirtLayer+rowsInHalfAScreen and gridR+1 > currentDirtLayer-rowsInHalfAScreen then
		
			replaceBlock (gridC,gridR+1,"water")

		else

			replaceBlockData (gridC,gridR+1,"water")

		end
		
	elseif getBlockTypeAtLocation(gridC+1,gridR+1) == 'e' and gridC+1 <= totalColumns then

		if gridR <= currentDirtLayer+rowsInHalfAScreen and gridR > currentDirtLayer-rowsInHalfAScreen then

			replaceBlock (gridC,gridR,"empty")

		else

			replaceBlockData (gridC,gridR,"empty")

		end

		if gridR+1 <= currentDirtLayer+rowsInHalfAScreen and gridR+1 > currentDirtLayer-rowsInHalfAScreen then
		
			replaceBlock (gridC+1,gridR+1,"water")

		else

			replaceBlockData (gridC+1,gridR+1,"water")

		end

	elseif getBlockTypeAtLocation(gridC-1,gridR+1) == 'e' and gridC-1 >= 0 then

		if gridR <= currentDirtLayer+rowsInHalfAScreen and gridR > currentDirtLayer-rowsInHalfAScreen then

			replaceBlock (gridC,gridR,"empty")

		else

			replaceBlockData (gridC,gridR,"empty")

		end

		if gridR+1 <= currentDirtLayer+rowsInHalfAScreen and gridR+1 > currentDirtLayer-rowsInHalfAScreen then
		
			replaceBlock (gridC-1,gridR+1,"water")

		else

			replaceBlockData (gridC+1,gridR+1,"water")

		end

	elseif getBlockTypeAtLocation(gridC+1,gridR) == 'e' and getBlockTypeAtLocation(gridC,gridR+1) ~= 'e' and gridC+1 <= totalColumns then

		if gridR <= currentDirtLayer+rowsInHalfAScreen and gridR > currentDirtLayer-rowsInHalfAScreen then

			replaceBlock (gridC,gridR,"empty")
			replaceBlock (gridC+1,gridR,"water")

		else

			replaceBlockData (gridC,gridR,"empty")
			replaceBlockData (gridC+1,gridR,"water")

		end

	elseif getBlockTypeAtLocation(gridC-1,gridR) == 'e' and getBlockTypeAtLocation(gridC,gridR+1) ~= 'e' and gridC-1 >= 0 then

		if gridR <= currentDirtLayer+rowsInHalfAScreen and gridR > currentDirtLayer-rowsInHalfAScreen then

			replaceBlock (gridC,gridR,"empty")
			replaceBlock (gridC-1,gridR,"water")

		else

			replaceBlockData (gridC,gridR,"empty")
			replaceBlockData (gridC-1,gridR,"water")

		end

	end

end

function simulateSand (column, row )

	local gridC = column
	local gridR = row
	
	if (getBlockTypeAtLocation(gridC,gridR+1) == 'e' or getBlockTypeAtLocation(gridC,gridR+1) == 'w') and isPlayerAtGridPos(gridC,gridR+1) == false then

		if gridR < currentDirtLayer+rowsInHalfAScreen and gridR > currentDirtLayer-rowsInHalfAScreen then

			replaceBlock (gridC,gridR,"empty")

		else

			replaceBlockData (gridC,gridR,"empty")

		end

		if gridR+1 < currentDirtLayer+rowsInHalfAScreen and gridR+1 > currentDirtLayer-rowsInHalfAScreen then
		
			replaceBlock (gridC,gridR+1,"sand")

		else

			replaceBlockData (gridC,gridR+1,"sand")

		end
		
	elseif (getBlockTypeAtLocation(gridC+1,gridR+1) == 'e' or getBlockTypeAtLocation(gridC+1,gridR+1) == 'w') and gridC+1 <= totalColumns and isPlayerAtGridPos(gridC+1,gridR+1) == false then

		if gridR < currentDirtLayer+rowsInHalfAScreen and gridR > currentDirtLayer-rowsInHalfAScreen then

			replaceBlock (gridC,gridR,"empty")

		else

			replaceBlockData (gridC,gridR,"empty")

		end

		if gridR+1 < currentDirtLayer+rowsInHalfAScreen and gridR+1 > currentDirtLayer-rowsInHalfAScreen then
		
			replaceBlock (gridC+1,gridR+1,"sand")

		else

			replaceBlockData (gridC+1,gridR+1,"sand")

		end

	elseif (getBlockTypeAtLocation(gridC-1,gridR+1) == 'e' or getBlockTypeAtLocation(gridC-1,gridR+1) == 'w') and gridC-1 >= 0 and isPlayerAtGridPos(gridC-1,gridR+1) == false then

		if gridR < currentDirtLayer+rowsInHalfAScreen and gridR > currentDirtLayer-rowsInHalfAScreen then

			replaceBlock (gridC,gridR,"empty")

		else

			replaceBlockData (gridC,gridR,"empty")

		end

		if gridR+1 < currentDirtLayer+rowsInHalfAScreen and gridR+1 > currentDirtLayer-rowsInHalfAScreen then
		
			replaceBlock (gridC-1,gridR+1,"sand")

		else

			replaceBlockData (gridC-1,gridR+1,"sand")

		end

	end

end

function fluidSimulation (frameIn)

	local startRow = (currentDirtLayer - (rowsInHalfAScreen+20))
	local endRow = (currentDirtLayer + (rowsInHalfAScreen+20))

	for row=startRow,endRow do

		if (levelData [ row ] and levelData [ row ] ~= nil) then

			local rowData = levelData [row]

			for column,blockType in pairs(rowData) do

				if (rowData [ column ] and rowData [ column ] ~= nil) then

					local bType = rowData [ column ]

					-- water
					if bType == "w" then
							
						simulateWater (column,row)

					-- sand. Slowed down using frame to represent more realistic falling
					--elseif bType == "s" and frameIn%(totalFrames/10) == 0 then
					elseif bType == "s" then

						simulateSand (column,row)

					end

				end

			end

		end

	end

end




---- NEXT UP IS MAKING THE SPRITES X2




-------------------------
-- initialisation
-------------------------

function init ()

	-- setup window
	MOAISim.openWindow ( "Subterranea", screenSizeX, screenSizeY )
	MOAISim.setStep ( 1 / totalFrames ) -- Lock at 30 FPS

	--MOAIDebugLines.setStyle ( MOAIDebugLines.TEXT_BOX, 1, 1, 1, 1, 1 )
	--MOAIDebugLines.setStyle ( MOAIDebugLines.TEXT_BOX_LAYOUT, 1, 0, 0, 1, 1 )
	--MOAIDebugLines.setStyle ( MOAIDebugLines.TEXT_BOX_BASELINES, 1, 1, 0, 0, 1 )

	-- setup viewport
	viewport = MOAIViewport.new ()
	viewport:setSize ( screenSizeX, screenSizeY )
	-- this sets the world units to use which can be different to the size
	viewport:setScale ( screenSizeX, screenSizeY )

	-- initialise camera
	camera = MOAICamera2D.new ()

	-- setup layer
	layer = MOAILayer2D.new ()
	layer:setViewport ( viewport )
	layer:setCamera ( camera )
	MOAISim.pushRenderPass ( layer )

	gui = MOAILayer2D.new ()
	gui:setViewport ( viewport )
	MOAISim.pushRenderPass ( gui )


	-- setup fonts and styles

	charcodes = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 .,:;!?()&/-'
	text = ''

	font = MOAIFont.new ()
	font:loadFromBMFont ( "impact.fnt" )
	--font:load ( "Dwarves.TTF" )
	font:preloadGlyphs ( charcodes, 14 )
	
	local style = MOAITextStyle.new ()
	style:setFont ( font )
	style:setSize ( 14 )
	
	-- textboxes

	dirtCollectedTextbox = MOAITextBox.new ()
	dirtCollectedTextbox:setStyle ( style )
	dirtCollectedTextbox:setString ( text )
	dirtCollectedTextbox:setRect ( -600, 325, -400, 350 )
	dirtCollectedTextbox:setShader ( MOAIShaderMgr.getShader ( MOAIShaderMgr.DECK2D_SHADER ))
	dirtCollectedTextbox:setYFlip ( true )
	gui:insertProp ( dirtCollectedTextbox )

	rockCollectedTextbox = MOAITextBox.new ()
	rockCollectedTextbox:setStyle ( style )
	rockCollectedTextbox:setString ( text )
	rockCollectedTextbox:setRect ( -600, 285, -400, 310 )
	rockCollectedTextbox:setShader ( MOAIShaderMgr.getShader ( MOAIShaderMgr.DECK2D_SHADER ))
	rockCollectedTextbox:setYFlip ( true )
	gui:insertProp ( rockCollectedTextbox )

	sandCollectedTextbox = MOAITextBox.new ()
	sandCollectedTextbox:setStyle ( style )
	sandCollectedTextbox:setString ( text )
	sandCollectedTextbox:setRect ( -600, 245, -400, 270 )
	sandCollectedTextbox:setShader ( MOAIShaderMgr.getShader ( MOAIShaderMgr.DECK2D_SHADER ))
	sandCollectedTextbox:setYFlip ( true )
	gui:insertProp ( sandCollectedTextbox )

	-- initialise text values

	updateMaterialCollected ('d',dirtCollected)
	updateMaterialCollected ('r',rockCollected)
	updateMaterialCollected ('s',sandCollected)

	-- camera fitter setup
	fitter = MOAICameraFitter2D.new ()
	fitter:setViewport ( viewport )
	fitter:setCamera ( camera )
	-- don't need fitter bounds
	--fitter:setBounds ( -400, -2000, 400, 300 )
	fitter:setMin ( screenSizeX )
	fitter:start ()

	-- player texture
	playerQuad = MOAIGfxQuad2D.new ()
	playerQuad:setTexture( "resources/player_large.png" )
	playerQuad:setRect ( -(sprite_size/2), -(sprite_size/2), (sprite_size/2), (sprite_size/2) )

	-- player prop
	player = MOAIProp2D.new ()
	player:setDeck ( playerQuad )
	player:setLoc (0,sprite_size)
	layer:insertProp ( player )

	-- dirt texture
	dirt = MOAIGfxQuad2D.new ()
	dirt:setTexture ( "resources/dirt_large.png" )
	dirt:setRect ( -(sprite_size/2), -(sprite_size/2), (sprite_size/2), (sprite_size/2) )

	-- sand texture
	sand = MOAIGfxQuad2D.new ()
	sand:setTexture ( "resources/sand_large.png" )
	sand:setRect ( -(sprite_size/2), -(sprite_size/2), (sprite_size/2), (sprite_size/2) )

	-- ladder texture
	ladder = MOAIGfxQuad2D.new ()
	ladder:setTexture ( "resources/ladder_large.png" )
	ladder:setRect ( -(sprite_size/2), -(sprite_size/2), (sprite_size/2), (sprite_size/2) )

	-- rock texture
	rock = MOAIGfxQuad2D.new ()
	rock:setTexture ( "resources/rock_large.png" )
	rock:setRect ( -(sprite_size/2), -(sprite_size/2), (sprite_size/2), (sprite_size/2) )

	-- water texture
	water = MOAIGfxQuad2D.new ()
	water:setTexture ( "resources/water_large.png" )
	water:setRect ( -(sprite_size/2), -(sprite_size/2), (sprite_size/2), (sprite_size/2) )

	-- Music and Sound Effects

	--MOAIUntzSystem.initialize ()

	--sound = MOAIUntzSound.new ()
	--sound:load ( 'resources/sounds/dig.wav' )
	--sound:setVolume ( 1 )
	--sound:setLooping ( false )

	-- generate the entire world
	generateWorld (maxRows)

	-- inital screen streaming
	local addRowStart = (currentDirtLayer + 1)
	local addRowEnd = (currentDirtLayer + rowsInHalfAScreen)
	loadExistingChunk (0, totalColumns, addRowStart, addRowEnd)

	-- setup keyboard listener
	MOAIInputMgr.device.keyboard:setCallback ( onKeyboardEvent )

	printDebug()

end

------------------------
-- game loop
------------------------

mainThread = MOAICoroutine.new ()
mainThread:run (

	function ()

		if worldGeneration == true then

		local frame = 1

		while not gameOver do
			coroutine.yield ()

			if frame <= totalFrames then
				frame = frame + 1
			else
				frame = 1
			end

			-- check block below and drop the player if its empty
			checkEmptySpaceBelow ()

			-- run the fluid simulation and pass in the frame
			fluidSimulation (frame)
			

			-- slow down player movement
			if frame%(totalFrames/10) == 0 then

				if currentKey == "left" then

					if checkCollision (currentDirtLayer,currentDirtColumn-1) == true then
					
						action = player:moveLoc ( -sprite_size, 0, 0 )
						currentDirtColumn = currentDirtColumn-1
						printDebug()

					end

				elseif currentKey == "right" then

					if checkCollision (currentDirtLayer,currentDirtColumn+1) == true then
					
						action = player:moveLoc ( sprite_size, 0, 0 )
						currentDirtColumn = currentDirtColumn+1
						printDebug()

					end

				elseif currentKey == "up" then
					if currentDirtLayer > 1 then

						local dirtLayerData = levelData [ currentDirtLayer-1 ]

						if dirtLayerData [ currentDirtColumn ] == 'l' or dirtLayerData [ currentDirtColumn ] == 'e' or dirtLayerData [ currentDirtColumn ] == 'w' then

							action = player:moveLoc ( 0, sprite_size, 0 )
							moveCamera ( 0, sprite_size )
							currentDirtLayer = currentDirtLayer-1
							
							if dirtLayerData [ currentDirtColumn ] == 'e' then
								replaceBlock ( currentDirtColumn, currentDirtLayer, 'ladder' )
							end

							printDebug()

							loadExistingChunk ( 0, totalColumns, currentDirtLayer - (rowsInHalfAScreen-1), currentDirtLayer - (rowsInHalfAScreen-1) )
							removeScreenChunk ( 0, totalColumns, currentDirtLayer + (rowsInHalfAScreen+1), currentDirtLayer + (rowsInHalfAScreen+1) )

						end

					end

				elseif currentKey == "down" then
					
					if currentDirtLayer < maxRows-1 then
						
						if checkCollision (currentDirtLayer+1,currentDirtColumn) == true then

							action = player:moveLoc ( 0, -sprite_size, 0 )
							moveCamera ( 0, -sprite_size )
							currentDirtLayer = currentDirtLayer+1
							
							printDebug()

							--stream the next row
							loadExistingChunk ( 0, totalColumns, currentDirtLayer+rowsInHalfAScreen, currentDirtLayer+rowsInHalfAScreen )
							removeScreenChunk ( 0, totalColumns, currentDirtLayer-rowsInHalfAScreen, currentDirtLayer-rowsInHalfAScreen )

						end

					end

				end

			end

		end

		end

	end
)

----------------------
-- start the game
----------------------

init ()