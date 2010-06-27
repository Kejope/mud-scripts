--[[
  Kejope's mud functions
  libkejope.lua v01.00.000
  Copyright 2010
  This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.
  To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/3.0/
  or send a letter to Creative Commons, 171 Second Street, Suite 300, San Francisco, California, 94105, USA.
  Additionally, you may not use any form of this work in a manner which is designed to induce harm to any human.
  You can get the latest version at:  http://github.com/Kejope/mud-scripts

  ----------
  Setup:
  1. Copy this file, "libkejope.lua" in your "C:\Program Files\MUSCHclient\lua" folder.
  2. Make a MUSHclient alias:  File > World Properties -> Input > Alaises -> Add... button.
    Check these boxes:  Enabled, Omit From Log File, Regular Expression, Omit From Output.
    Choose "Script" in the Send To drop-down list
    Enter this into the Alias text line:  inv
    Enter these two lines in the Send text area:
      require "libkejope"
      InventoryUpdate ()
  3. Make a second alias:  (Same way as above)
    Enter this into the Alias text line:  inv off
    Enter these two lines in the Send text area:
      local win = GetPluginID () .. ":inventory"
      WindowShow ( win, false )
  4. Make a trigger:  File > World Properties -> Appearance > Triggers -> Add... button.
    Enter this into the Sequence text line:  99
    Check these boxes:  Enabled, Regular Expression,
    Choose "Script" in the Send To drop-down list
    Enter this into the Alias text line:  ^(You (buy|drop|get|got|receive|sell|sold|store|take|took) )|(\w+ g(a|i)ve(s|) you ).*$
    Enter these this in the Send text area:  Execute ( "inv" )
  5. User configuration, below, in this file.  Edit the user_* and mud_* variables below to suit your tastes.

  ----------
  Usage:
  Once your aliases and triggers are created and enabled, you can type in the command window,
  "inv" to display inventory and "inv off" to hide it.

  ----------
  CHANGELOG:
  v01.000.000
  It works! :)  So far, only have "inv" and "inv off" commands to display Inventory in a window.

  v01.001.000 NOT RELEASED YET
  Will have score and/or who windows.

]]--

-- This line is necessary so that we can receive text from the MUD while inside the alias/trigger.
require "wait"

-- These user settings are case-sensitive.
-- Set your MUD name here.  Various parts of this script will check against this name.
user_mud_name = "NannyMUD" -- default "NannyMUD"
-- Should we force capitalization for the first character of item short description?
user_item_first_upper = "true" -- default "true"
-- Should we sort items alphabetically in the Inventory window?
user_inventory_sort = "true" -- default "true"
-- Should we move definite/indefinite articles to end of item descriptions?
user_article_fix = "true" -- default "true"
-- If we are moving definite/indefinite articles, should we keep the original article at the end?
user_article_keep = "false" -- default "false"

-- Some MUD-specific config settings.  Each MUD should have their own "if ... end" block.
-- If you have a profile for a new MUD, I can include it in my repository.
if user_mud_name == "NannyMUD" then
  -- What command should we send to request inventory?
  mud_inv_cmd = "i" -- default "i"
  -- NannyMUD has no header for inventory display, so match anything for first line.
  mud_inv_start = "*" -- default "*"
  -- NannyMUD has no header for inventory display, so keep that line.
  mud_inv_start_keep_line = "true" -- default "true"
  -- In NannyMUD, we want everything from the middle.
  mud_inv_middle = "*" -- default "*"
  -- NannyMUD has no footer, so we send a second command to receive a known text to match against
  mud_inv_cmd_after = "meow me" -- default "meow me"
  -- TODO FUTURE mud_inv_cmd_after = { "meow me", "purr" }
  -- NannyMUD has no footer, so we send mud_inv_cmd and look for the resulting first line of text
  mud_inv_end = "You meow at yourself." -- default "You meow at yourself."
  -- NannyMUD has no footer for inventory display, so don't keep that line.
  mud_inv_end_keep_line = "false" -- default "false"
  -- After matching mud_inv_end, discard all lines up to this line, inclusive.  Leave blank if no lines to discard.
  mud_inv_end_discard_until = "" -- default ""
  -- NannyMUD lists these in with everything else.
  mud_special = "<autoloader>" -- default "<autoloader>"
  -- Do we want to see them in Inventory window?
  mud_special_keep = "false" -- default "false"

  mud_score_cmd = "score"
  mud_score_cmd_after = ""
  mud_score_start = ""
  mud_score_start_keep_line = "false"
  mud_score_middle = { 1, { "name", "", } }
end


function InventoryUpdate ( name, input, wildcards )
-- called by the do_inv trigger and/or alias
  wait.make ( function () -- "coroutine starts here"

    local inv_list = {}
    local line, wildcards, styles

    -- request inventory
    Send ( mud_inv_cmd )
    Send ( mud_inv_cmd_after )

    -- matching for start of data
    line, wildcards, styles = wait.match (mud_inv_start, 10, trigger_flag.OmitFromOutput)
    if not line then
      ColourNote ( "white", "blue", "ERR:libkejope.lua:InventoryUpdate: Aborted at start, timeout at 10 seconds" )
      return
    end
    if mud_inv_start_keep_line == "true" then
      if string.match ( line, mud_special ) then
	if mud_special_keep == "true" then
	  do_insert = "true"
	  inv_list [ #inv_list + 1 ] = line
	end
      else
	do_insert = "true"
	inv_list [ #inv_list + 1 ] = line
      end
    end

    -- matching for middle part of data
    while true do
      line, wildcards, styles = wait.match ( mud_inv_middle, 10, trigger_flag.OmitFromOutput )
      if not line then
	ColourNote ( "white", "blue", "ERR:libkejope.lua:InventoryUpdate: Aborted in middle, timeout at 10 seconds" )
	return
      end

      -- checking for end part of data
      if string.match ( line, mud_inv_end ) then
	if mud_inv_end_keep_line == "true" then
	  if string.match ( line, mud_special ) then
	    if mud_special_keep == "true" then
	      inv_list [ #inv_list + 1 ] = line
	    end
	  else
	    inv_list [ #inv_list + 1 ] = line
	  end
	end
	while true do
	  line, wildcards, styles = wait.match ( "*", 10, trigger_flag.OmitFromOutput )
	  if not line then
	    ColourNote ( "white", "blue", "ERR:libkejope.lua:InventoryUpdate: Aborted at end, timeout at 10 seconds" )
	    return
	  end
	  if string.match ( line, mud_inv_end_discard_until ) then
	    break
	  end
	end
	break
      else
	-- inserting for middle part of data
	if string.match ( line, mud_special ) then
	  if mud_special_keep == "true" then
	    inv_list [ #inv_list + 1 ] = line
	  end
	else
	  inv_list [ #inv_list + 1 ] = line
	end
      end
    end
    InventoryView ( "on", "FUTURE", inv_list )
  end)
end


function InventoryView ( action, attr, inv_list )
-- part of Model-View-Controller for Inventory handling
  if not action then
    action = "on"
  end
  if not attr then
    ColourNote ( "white", "blue", "ERR:libkejope.lua:InventoryView: attr=nil" )
    return
  end
  if not inv_list then
    ColourNote ( "white", "blue", "ERR:libkejope.lua:InventoryView: inv_list=nil" )
    return
  end
  -- FUTURE assert ( type ( attr ) == "table" )
  --assert ( type ( inv_list ) == "table" )
  local win = GetPluginID () .. ":inventory"
  local font = "f"
  local fontHeight = 0
  local winWidth = 0
  local winHeight = 0
  local border_pixels = 3
  local y = border_pixels
  local x = border_pixels

  if action == "on" then
    -- create and/or update window
    if not WindowInfo ( win, 1 ) then
      WindowCreate ( win, 0, 0, 0, 0, 6, 0, 0 )
      WindowFont ( win, font, "Lucida Console", 9 )
    end
    fontHeight = WindowFontInfo ( win, font, 1 )
    -- format the line for showing, and set winWidth for item with longest pixel width
    for i, inv_item in ipairs ( inv_list ) do
      --ColourNote ( "white", "blue", "PING inventoryview [" .. inv_item .. "] " .. i )
      if user_mud_name == "NannyMUD" then
	inv_item = GetTagless ( inv_item ) -- NannyMUD optionally encloses with XML tags
	inv_item = Trim ( inv_item ) -- NannyMUD puts a single space in front of inventory lines
	local t_item = inv_item
	inv_item = TrimAsterisk ( inv_item ) -- NannyMUD puts a single asterisk in front of inventory lines that are tagged
	if inv_item == t_item then
	  -- FUTURE after implement attr list for inv_list, can indicate that the item is tagged
	end
	inv_item = TrimPeriod ( inv_item ) -- NannyMUD puts a single period after item short description
      end
      if user_article_fix == "true" then
	inv_item = FixArticle ( inv_item, user_article_keep )
      end
      if user_item_first_upper == "true" then
	inv_item = FirstUpper ( inv_item )
      end
      inv_list [ i ] = inv_item
      winWidth = math.max ( winWidth, WindowTextWidth ( win, font, inv_list [ i ] ) )
    end
    winWidth = border_pixels + winWidth + border_pixels
    winHeight = border_pixels + fontHeight * ( 1 + #inv_list ) + border_pixels

    -- make window correct size
    WindowCreate ( win, 0, 0, winWidth, winHeight, 6, 0, ColourNameToRGB "#373737" )
    WindowRectOp ( win, 5, 0, 0, 0, 0, 5, 0x1000 + 0x0f )

    -- heading line
    WindowText ( win, font, "Inventory", border_pixels, border_pixels, 0, 0, ColourNameToRGB  "yellow" )

    -- draw each inventory line
    if user_inventory_sort == "true" then
      table.sort ( inv_list )
    end
    for _, inv_item in ipairs ( inv_list ) do
      y = y + fontHeight
      WindowText ( win, font, inv_item, x, y, 0, 0, ColourNameToRGB ( "white" ) )
    end
    WindowShow ( win, true )
  elseif action == "off" then
    -- hide window
    WindowShow ( win, false )
  end
end


function FirstUpper ( string )
  -- capitalizes only the first character of the string
  if not string then
    ColourNote ( "white", "blue", "ERR:libkejope.lua:FirstUpper: string=nil" )
    return
  end
  return Trim ( string.upper ( string.sub ( string, 1, 1 ) ) .. string.sub ( string, 2, string.len ( string .. "  " ) ) )
end


function GetTagless ( string, level )
-- strips one pair of XML tags from around string, i.e., <short>*</short>
  if not string then
    ColourNote ( "white", "blue", "ERR:libkejope.lua:GetTagless: string=nil" )
    return
  end
  if not level then
    level = 1
  end
  -- TODO confirm properly formed tags, remove only "level" number of layers
  local tagless
  -- basically, regexp s/^<.*>(.*)<\/.*>$/\1/
  tagless = string.match ( string, "^<.*>(.*)</.*>$", 1 )
  if not tagless then
    -- TODO strip for a single tag, i.e., </br>
    return string
  end
  return tagless
end


function GetTag ( string )
-- given a string that begins with an XML tag, return tag name
-- TODO total untested
-- TODO confirm properly formed tags
-- TODO strip for a single tag, i.e., </br>
  -- basically, regexp s/^<(.*)>.*<\/.*>$/\1/
  if not string then
    ColourNote ( "white", "blue", "ERR:libkejope.lua:GetTag: string=nil" )
    return
  end
  local t_start, t_end
  t_start = 1 -- TODO need to not presume that we have a valid tag that starts at position 1
  _, t_end, _ = string.find ( string, ">", 2 ) -- the closing part of the pre-tag  -- TODO need to not presume that we have a valid tag that starts at position 1
  t_end = t_end or string.len ( string ) -- TODO on error, returns entire string, but should return ERR
  return string.sub ( string, t_start + 1, t_end - 1 )
end


function TrimAsterisk ( string )
  -- removes pre- asterisk, i.e., from "*armour" to "armour"
  if not string then
    ColourNote ( "white", "blue", "ERR:libkejope.lua:TrimAsterisk: string=nil" )
    return
  end
  if string == "" then
    return string
  end
  return string.match ( string, "^\*(.*)$" ) or string
end


function TrimPeriod ( string )
  -- removes trailing period, i.e., from "a button." to "a button"
  if not string then
    ColourNote ( "white", "blue", "ERR:libkejope.lua:TrimPeriod: string=nil" )
    return
  end
  if string == "" then
    return string
  end
  --return string.match ( string, "^(.*)\.$" ) or string -- why didn't this line work??
  local t_end = string.len ( string )
  if string.sub ( string, t_end, t_end ) == "." then
    return string.sub ( string, 1, t_end - 1 )
  end
  -- no trimming necessary, so just return same
  return string
end


function FixArticle ( string, keep )
-- moves (the|a|an) to end of string, prserving case, after adding a comma and space
-- basically, "A bag" becomes "bag, A" and "the house" becomes "house, the"
  if not string then
    ColourNote ( "white", "blue", "ERR:libkejope.lua:FixArticle: string=nil" )
    return
  end
  keep = keep or "true"
  local pattern

  -- trying s/^([Aa]) (.*$)/\2, \1/
  pattern = pattern or string.match ( string, "^([Aa] ).*$", 1 )
  -- trying s/^([Tt][Hh][Ee]) (.*$)/\2, \1/
  pattern = pattern or string.match ( string, "^([Tt][Hh][Ee] ).*$", 1 )
  -- trying s/^([Aa][Nn]) (.*$)/\2, \1/
  pattern = pattern or string.match ( string, "^([Aa][Nn] ).*$", 1 )

  if pattern then
    if keepordrop == "true" then
      return string.sub ( string, string.len ( pattern ) + 1, string.len ( string ) ) .. ", " .. string.lower ( string.sub ( string, 1, string.len ( pattern ) - 1 ) )
    else
      return string.sub ( string, string.len ( pattern ) + 1, string.len ( string ) )
    end
  end
  -- no fixing necessary, so just return same.  (You DID Trim string before calling this function, right?)
  return string
end


function string.starts ( string, pattern, casesensitive )
-- boolean test whether string starts with pattern
  if casesensitive == "true" then
    return string.upper ( string.sub ( string, 1, string.len ( pattern ) ) ) == string.upper ( pattern )
  else
    return string.sub ( string, 1, string.len ( pattern ) ) == pattern
  end
end


function string.ends ( string, pattern, casesensitive )
-- boolean test whether string ends with pattern
  if casesensitive == "true" then
    return string.upper ( string.sub ( string, string.len ( string ) - string.len ( pattern ) + 1, string.len ( pattern ) ) ) == string.upper ( pattern )
  else
    return string.sub ( string, string.len ( string ) - string.len ( pattern ) + 1, string.len ( pattern ) ) == pattern
  end
end
