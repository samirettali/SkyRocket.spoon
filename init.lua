local function scriptPath()
	local str = debug.getinfo(2, "S").source:sub(2)
	return str:match("(.*/)")
end

local SkyRocket = {}

SkyRocket.author = "David Balatero <d@balatero.com>"
SkyRocket.homepage = "https://github.com/dbalatero/SkyRocket.spoon"
SkyRocket.license = "MIT"
SkyRocket.name = "SkyRocket"
SkyRocket.version = "1.0.2"
SkyRocket.spoonPath = scriptPath()

local dragTypes = {
	resize = 2,
}

local function tableToMap(table)
	local map = {}

	for _, value in pairs(table) do
		map[value] = true
	end

	return map
end

local function getWindowUnderMouse()
	-- Invoke `hs.application` because `hs.window.orderedWindows()` doesn't do it
	-- and breaks itself
	local _ = hs.application

	local my_pos = hs.geometry.new(hs.mouse.absolutePosition())
	local my_screen = hs.mouse.getCurrentScreen()

	return hs.fnutils.find(hs.window.orderedWindows(), function(w)
		return my_screen == w:screen() and my_pos:inside(w:frame())
	end)
end

-- Usage:
--   resizer = SkyRocket:new({
--     resizeModifiers = {'ctrl', 'shift'}
--     resizeMouseButton = 'left',
--     focusWindowOnClick = false,
--   })
--
local function buttonNameToEventType(name, optionName)
	if name == "left" then
		return hs.eventtap.event.types.leftMouseDown
	end
	if name == "right" then
		return hs.eventtap.event.types.rightMouseDown
	end
	error(optionName .. ': only "left" and "right" mouse button supported, got ' .. name)
end

function SkyRocket:new(options)
	options = options or {}

	local resizer = {
		disabledApps = tableToMap(options.disabledApps or {}),
		dragging = false,
		dragType = nil,
		resizeStartMouseEvent = buttonNameToEventType(options.resizeMouseButton or "left", "resizeMouseButton"),
		resizeModifiers = options.resizeModifiers or { "ctrl", "shift" },
		targetWindow = nil,
		focusWindowOnClick = options.focusWindowOnClick or false,
	}

	setmetatable(resizer, self)
	self.__index = self

	resizer.clickHandler = hs.eventtap.new({
		hs.eventtap.event.types.leftMouseDown,
		hs.eventtap.event.types.rightMouseDown,
	}, resizer:handleClick())

	resizer.cancelHandler = hs.eventtap.new({
		hs.eventtap.event.types.leftMouseUp,
		hs.eventtap.event.types.rightMouseUp,
	}, resizer:handleCancel())

	resizer.dragHandler = hs.eventtap.new({
		hs.eventtap.event.types.leftMouseDragged,
		hs.eventtap.event.types.rightMouseDragged,
	}, resizer:handleDrag())

	resizer.clickHandler:start()

	return resizer
end

function SkyRocket:stop()
	self.dragging = false
	self.dragType = nil

	self.cancelHandler:stop()
	self.dragHandler:stop()
	self.clickHandler:start()
end

function SkyRocket:isResizing()
	return self.dragType == dragTypes.resize
end

function SkyRocket:handleDrag()
	return function(event)
		if not self.dragging then
			return nil
		end

		local dx = event:getProperty(hs.eventtap.event.properties.mouseEventDeltaX)
		local dy = event:getProperty(hs.eventtap.event.properties.mouseEventDeltaY)

		if self:isResizing() then
			local currentSize = self.targetWindow:size()

			self.targetWindow:setSize({
				w = currentSize.w + dx,
				h = currentSize.h + dy,
			})

			return true
		else
			return nil
		end
	end
end

function SkyRocket:handleCancel()
	return function()
		if not self.dragging then
			return
		end

		self:stop()
	end
end

function SkyRocket:handleClick()
	return function(event)
		if self.dragging then
			return true
		end

		local flags = event:getFlags()
		local eventType = event:getType()

		local isResizing = eventType == self.resizeStartMouseEvent and flags:containExactly(self.resizeModifiers)

		if isResizing then
			local currentWindow = getWindowUnderMouse()

			if self.disabledApps[currentWindow:application():name()] then
				return nil
			end

			self.dragging = true
			self.targetWindow = currentWindow

			self.dragType = dragTypes.resize

			self.cancelHandler:start()
			self.dragHandler:start()
			self.clickHandler:stop()

			if self.focusWindowOnClick then
				currentWindow:focus()
			end
			return true
		else
			return nil
		end
	end
end

return SkyRocket
