--	This will be the module table
local M			= {}

--	A function that prints some text
--	and prevent raising an error if it is 'nil'
local function printText( text )
	print( "Your text was: " .. tostring( text ) )
end

--	This is the callback that is called once a GUI event is triggered (button click, ...)
local function GUICallback( mode, str )

	--	Extract args
	local args	= unserialize( str )

	--	Clicked the Ok button
	if mode == "apply" then
		printText( args.inputText )
	end
end

--	This is the function that displays the GUI
--	It should be included in the public interface so that
--	any external component can call it (like a key bind in keyboard mappings)
local function showGUI()
	local g		= [[beamngguiconfig 1
callback system testGUI.GUICallback
title Test GUI

container
	type = verticalStack
	name = root

control
	type = text
	name = inputText
	description = Your text here

control
	type = doneButton
	icon = tools/gui/images/iconAccept.png
	description = Ok

]]
	gameEngine:showGUI( g )
end

--	Public interface
--	Defines what is visible to the outside world
M.printText		= printText
M.showGUI		= showGUI
M.GUICallback	= GUICallback

--	Return the module table
return M
