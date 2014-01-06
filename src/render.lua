
COLOUR_RGB = {
	WHITE = {240, 240, 240},
	ORANGE = {242, 178, 51},
	MAGENTA = {229, 127, 216},
	LIGHT_BLUE = {153, 178, 242},
	YELLOW = {222, 222, 108},
	LIME = {127, 204, 25},
	PINK = {242, 178, 204},
	GRAY = {76, 76, 76},
	LIGHT_GRAY = {153, 153, 153},
	CYAN = {76, 153, 178},
	PURPLE = {178, 102, 229},
	BLUE = {37, 49, 146},
	BROWN = {127, 102, 76},
	GREEN = {87, 166, 78},
	RED = {204, 76, 76},
	BLACK = {0, 0, 0},
}

COLOUR_CODE = {
	[1] = COLOUR_RGB.WHITE,
	[2] = COLOUR_RGB.ORANGE,
	[4] =  COLOUR_RGB.MAGENTA,
	[8] = COLOUR_RGB.LIGHT_BLUE,
	[16] = COLOUR_RGB.YELLOW,
	[32] = COLOUR_RGB.LIME,
	[64] = COLOUR_RGB.PINK,
	[128] = COLOUR_RGB.GRAY,
	[256] = COLOUR_RGB.LIGHT_GRAY,
	[512] = COLOUR_RGB.CYAN,
	[1024] = COLOUR_RGB.PURPLE,
	[2048] = COLOUR_RGB.BLUE,
	[4096] = COLOUR_RGB.BROWN,
	[8192] = COLOUR_RGB.GREEN,
	[16384] = COLOUR_RGB.RED,
	[32768] = COLOUR_RGB.BLACK,
}

Screen = {
	width = _conf.terminal_width,
	height = _conf.terminal_height,
	sWidth = (_conf.terminal_width * 6 * _conf.terminal_guiScale) + (_conf.terminal_guiScale * 2),
	sHeight = (_conf.terminal_height * 9 * _conf.terminal_guiScale) + (_conf.terminal_guiScale * 2),
	textB = {},
	backgroundColourB = {},
	textColourB = {},
	font = nil,
	pixelWidth = _conf.terminal_guiScale * 6,
	pixelHeight = _conf.terminal_guiScale * 9,
	showCursor = false,
	lastCursor = nil,
	dirty = true,
	tOffset = {},
}
function Screen:init()
	for y = 1, self.height do
		self.textB[y] = {}
		self.backgroundColourB[y] = {}
		self.textColourB[y] = {}
		for x = 1, self.width do
			self.textB[y][x] = " "
			self.backgroundColourB[y][x] = 32768
			self.textColourB[y][x] = 1
		end
	end

	self.font = love.graphics.getFont()
	for i = 32,126 do self.tOffset[string.char(i)] = math.floor(3 - self.font:getWidth(string.char(i)) / 2) * _conf.terminal_guiScale end
	self.tOffset["@"] = 0
	self.tOffset["~"] = 0
	self.dirty = true
end

-- Local functions are faster than global
local lsetCol = love.graphics.setColor
local ldrawRect = love.graphics.rectangle
local ldrawLine = love.graphics.line
local lprint = love.graphics.print
local tOffset = Screen.tOffset
local decWidth = Screen.width - 1
local decHeight = Screen.height - 1

local lastColor
local function setColor(c,f)
	if f or lastColor ~= c then
		lastColor = c
		lsetCol(c)
	end
end

function Screen:draw()
	if not Emulator.running then
		lsetCol({0,0,0})
		ldrawRect("fill", 0, 0, self.sWidth, self.sHeight)
		return
	end

	-- TODO Better damn rendering!
	-- Should only update sections that changed.

	-- Render the Background Color
	setColor( COLOUR_CODE[ self.backgroundColourB[1][1] ], true )
	for y = 0, decHeight do
		for x = 0, decWidth do

			setColor( COLOUR_CODE[ self.backgroundColourB[y + 1][x + 1] ] ) -- TODO COLOUR_CODE lookup might be too slow?
			ldrawRect("fill", x * self.pixelWidth + (x == 0 and 0 or _conf.terminal_guiScale), y * self.pixelHeight + (y == 0 and 0 or _conf.terminal_guiScale), self.pixelWidth + ((x == 0 or x == decWidth) and _conf.terminal_guiScale or 0), self.pixelHeight + ((y == 0 or y == decHeight) and _conf.terminal_guiScale or 0))

		end
	end

	-- Render the Text
	for y = 0, self.height - 1 do
		for x = 0, self.width - 1 do
			local text = self.textB[y + 1][x + 1]
			if text ~= " " and text ~= "\t" then
				local sByte = string.byte(text)
				if sByte == 9 then
					text = " "
				elseif sByte < 32 or sByte > 126 or sByte == 96 then
					text = "?"
				end
				setColor( COLOUR_CODE[ self.textColourB[y + 1][x + 1] ] )
				lprint( text, x * self.pixelWidth + tOffset[text] + _conf.terminal_guiScale, y * self.pixelHeight + _conf.terminal_guiScale, 0, _conf.terminal_guiScale, _conf.terminal_guiScale)
			end
		end
	end

	if api.comp.blink and self.showCursor then
		setColor(COLOUR_CODE[ api.comp.fg ])
		lprint("_", (api.comp.cursorX - 1) * self.pixelWidth + tOffset["_"] + _conf.terminal_guiScale, (api.comp.cursorY - 1) * self.pixelHeight + _conf.terminal_guiScale, 0, _conf.terminal_guiScale, _conf.terminal_guiScale)
	end
end
