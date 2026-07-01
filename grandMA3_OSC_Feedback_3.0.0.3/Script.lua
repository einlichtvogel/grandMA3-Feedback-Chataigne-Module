-- pam-OSC. It allows to control GrandMA3 with Midi Devices over Open Stage Control and allows for Feedback from MA.
-- Copyright (C) 2024  xxpasixx
-- Modifications Copyright (C) 2025 Luca Heß (einlichtvogel)
-- Changes were made fundamentally to the original script so a detailed description is not possible, please compare to the original script for details.
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <https://www.gnu.org/licenses/>.
-- v3.0.0.3


-- Configuration Constants
local OSC_FEEDBACK_OUTPUT_PORT = 8093
local OSC_CHATAIGNE_INPUT_PORT = 8080
local POLL_RATE = 1 / 10
local RESEND_INTERVAL = 15
local FADER_MIDI_SCALE = 1.27

-- OSC Entry Names
local OSC_FEEDBACK_OUTPUT_NAME = "grandMA3 OSC Feedback Output"
local OSC_CHATAIGNE_INPUT_NAME = "grandMA3 OSC Chataigne Input"

-- Configurable Executor Ranges for Current Page (Wings 1-4, rows 100-400, buttons 1-16)
local EXECUTOR_RANGES_CURRENT_PAGE = {
    {start = 101, stop = 116}, -- Wing 1
    {start = 201, stop = 216}, -- Wing 2
    {start = 301, stop = 316}, -- Wing 3
    {start = 401, stop = 416}, -- Wing 4
}

-- State Variables
local executorsToWatchCurrentPage = {}
local executorsToWatchAnyPage = {}
local oldButtonValues = {}
local oldColorValues = {}
local oldNameValues = {}
local oldFaderValues = {}
local oldMasterEnabledValue = {
    highlight = false,
    lowlight = false,
    solo = false,
    blind = false
}
local existingPages = {}

-- Initialize default executorsToWatchCurrentPage from configurable ranges
local function initDefaultExecutors()
    executorsToWatchCurrentPage = {}
    for _, range in ipairs(EXECUTOR_RANGES_CURRENT_PAGE) do
        for i = range.start, range.stop do
            executorsToWatchCurrentPage[#executorsToWatchCurrentPage + 1] = i
        end
    end
end
initDefaultExecutors()

local oscEntry = -1

-- Polling timing
local resendTick = 0

-- Utility Functions --

local function getAppearanceColor(sequence)
    local apper = sequence["APPEARANCE"]
    if apper ~= nil then
        return apper['BACKR'] .. "," .. apper['BACKG'] .. "," .. apper['BACKB'] .. "," .. apper['BACKALPHA']
    else
        return "255,255,255,255"
    end
end

local function getName(sequence)
    if sequence["CUENAME"] ~= nil then
        return sequence["NAME"] .. ";" .. sequence["CUENAME"]
    end
    return sequence["NAME"] .. ";"
end

local function getMasterEnabled(masterName)
    if MasterPool()['Grand'][masterName]['FADERENABLED'] then
        return true
    else
        return false
    end
end

function table.contains(tbl, val)
    for _, v in ipairs(tbl) do
        if v == val then return true end
    end
    return false
end

function table.nameContainsString(tbl, val)
    for _, v in ipairs(tbl) do
        if v.Name == val then return v end
    end
    return nil
end

local function processExecutorStrings(executorsString)
    -- Iterate through each range of numbers separated by ";"
    if executorsString then
        executorsToWatchAnyPage = {}
        for executorRange in string.gmatch(executorsString, "([^;]+)") do
            -- Split the range at "-"
            local start, stop = executorRange:match("(%d+)-(%d+)")
            if start and stop then
                start = tonumber(start)
                stop = tonumber(stop)

                -- Validate that start <= stop to prevent infinite loops
                if start > stop then
                    Printf("WARNING: Invalid executor range %d-%d, skipping", start, stop)
                else
                    -- Iterate through the range from start to stop
                    for i = start, stop do
                        executorsToWatchAnyPage[#executorsToWatchAnyPage + 1] = i
                    end
                end
            end
        end
    end
end

local function findExecutor(pageNum, executorNum)
    local page = DataPool().Pages[pageNum]
    if not page then return nil end
    for _, exec in ipairs(page:Children()) do
        if exec.No == executorNum then
            return exec
        end
    end
    return nil
end

local function setupOSCENTries()
    local value = table.nameContainsString(ShowData().OSCBase:Children(), OSC_FEEDBACK_OUTPUT_NAME)

    if value == nil then
        Cmd('Store OSC OSCData "' .. OSC_FEEDBACK_OUTPUT_NAME .. '" "PORT" "' .. OSC_FEEDBACK_OUTPUT_PORT .. '" "SENDCOMMAND" "Yes"')
        Cmd('Store OSC OSCData "' .. OSC_CHATAIGNE_INPUT_NAME .. '" "PORT" "' .. OSC_CHATAIGNE_INPUT_PORT .. '" "RECEIVE" "Yes" "RECEIVECOMMAND" "Yes"')
        value = table.nameContainsString(ShowData().OSCBase:Children(), OSC_FEEDBACK_OUTPUT_NAME)
    end

    if value then
        oscEntry = value.No
        return true
    else
        return false
    end
end

local function sendOSCCommand(command)
    if oscEntry == -1 then
        Printf("ERROR: OSC entry not initialized")
        return
    end
    Cmd(command)
end

-- Helper function to initialize or get cached value table
local function getOrInitTable(cache, key)
    if cache[key] == nil then
        cache[key] = {}
    end
    return cache[key]
end

-- Helper function to cleanup old page values
local function cleanupOldPageValues(pageNo)
    oldButtonValues[pageNo] = nil
    oldColorValues[pageNo] = nil
    oldNameValues[pageNo] = nil
    oldFaderValues[pageNo] = nil
end

-- End Utility Functions --

local function main()
    local automaticResendButtons = GetVar(GlobalVars(), "gmaf_automaticResendButtons") or false
    local sendColors = GetVar(GlobalVars(), "gmaf_sendColors")
    local sendNames = GetVar(GlobalVars(), "gmaf_sendNames")
    local sendFaders = GetVar(GlobalVars(), "gmaf_sendFaders")

    local destPage = 1
    local forceReload = true
    local forceReloadButtons = false

    -- Select Mode (Start / Stop - Settings)
    local descTable = {
        title = "Mode",
        caller = GetFocusDisplay(),
        items = { GetVar(GlobalVars(), "gmaf_updateOSC") and "Stop" or "Start", "Settings"},
    }
    local a = PopupInput(descTable)

    -- Settings
    if (tonumber(a) == 2) then
        local states = {
            {name = "sendColors", state = GetVar(GlobalVars(), "gmaf_sendColors")},
            {name = "sendNames", state = GetVar(GlobalVars(), "gmaf_sendNames")},
            {name = "sendFaders", state = GetVar(GlobalVars(), "gmaf_sendFaders")},
            {name = "automaticResendButtons", state = GetVar(GlobalVars(), "gmaf_automaticResendButtons")},
        }

        local inputs = {
            {name = "Any Page", value = GetVar(GlobalVars(), "gmaf_executorsToWatchAnyPage")},
        }

        local resultTable =
            MessageBox(
            {
                title = "Settings for grandMA3 OSC Feedback",
                message = "You can enter the executors in the following format:\n'101-115;201-215;301-315'.\nIn 'Any Page', the changes from executors of all pages are updated, and their page is added to chataigne.",
                inputs = inputs,
                states = states,
                commands = {{value = 1, name = "Ok"}, {value = 0, name = "Cancel"}},
                backColor = "Global.Default",
                icon = "logo_small",
                messageTextColor = "Global.Text",
                autoCloseOnInput = false
            }
        )

        -- if okay is pressed
        if resultTable.result == 1 then
            for k,v in pairs(resultTable.states) do
                SetVar(GlobalVars(), "gmaf_" .. k, v)
            end

            for k,v in pairs(resultTable.inputs) do
                if k == "Any Page" then
                    SetVar(GlobalVars(), "gmaf_executorsToWatchAnyPage", v)
                end
            end

            -- Setup OSC
            setupOSCENTries()

            -- only rerun the program if the program is running
            if GetVar(GlobalVars(), "gmaf_updateOSC") ~= nil and GetVar(GlobalVars(), "gmaf_updateOSC") == true then
                SetVar(GlobalVars(), "gmaf_updateOSC", false)
                Printf(" -- Stopping grandMA3 OSC Feedback -- ")
                Printf(" !! Start again for changes to apply !! ")
                Printf(" ------------------------------------ ")
            end
        end
    end

    -- Start / Stop
    if(tonumber(a) == 1) then
        -- push all values saved in the settings from the executors into the global variables
        local execsAny = GetVar(GlobalVars(), "gmaf_executorsToWatchAnyPage")
        processExecutorStrings(execsAny)

        -- trigger value to start the Feedback
        if GetVar(GlobalVars(), "gmaf_updateOSC") ~= nil then
            SetVar(GlobalVars(), "gmaf_updateOSC", not GetVar(GlobalVars(), "gmaf_updateOSC"))
        else
            Printf(" ------------------------------------ ")
            Printf(" -- Starting grandMA3 OSC Feedback -- ")

            -- Setup OSC
            if not setupOSCENTries() then
                Printf(" -- ERROR: OSC Data not yet setup, run settings first -- ")
                Printf(" -- Stopping grandMA3 OSC Feedback -- ")
                Printf(" ------------------------------------ ")
                return
            end

            SetVar(GlobalVars(), "gmaf_updateOSC", true)
        end

        -- welcome / bye messages
        if(GetVar(GlobalVars(), "gmaf_updateOSC") == true) then
            Printf(" Running... ")

            -- Feedback for the Chataigne Plugin to set itself up
            local pages = {}
            for i, child in ipairs(DataPool().Pages:Children()) do
                pages[#pages + 1] = tostring(child)
            end
            local resultString = table.concat(pages, ";")

            sendOSCCommand(string.format('SendOSC %d "/Setup/executorsToWatchAnyPage,s,%s"', oscEntry, execsAny))
            sendOSCCommand(string.format('SendOSC %d "/Setup/pages,s,%s"', oscEntry, resultString))
            sendOSCCommand(string.format('SendOSC %d "/Setup/setupAllValues,i,1"', oscEntry))
        else
            -- Cleanup
            SetVar(GlobalVars(), "gmaf_updateOSC", nil)
            Printf(" -- Stopping grandMA3 OSC Feedback -- ")
            Printf(" ------------------------------------ ")
        end
    end

    -- main plugin loop
    while (GetVar(GlobalVars(), "gmaf_updateOSC")) do
        if GetVar(GlobalVars(), "gmaf_forceReload") == true then
            forceReload = true
            automaticResendButtons = GetVar(GlobalVars(), "gmaf_automaticResendButtons") or false
            sendColors = GetVar(GlobalVars(), "gmaf_sendColors") or false
            sendNames = GetVar(GlobalVars(), "gmaf_sendNames") or false
            SetVar(GlobalVars(), "gmaf_forceReload", false)
        end

        if automaticResendButtons then
            resendTick = resendTick + 1
        end
        if resendTick >= RESEND_INTERVAL then
            forceReloadButtons = true
            resendTick = 0
        end

        -- Check Master Enabled Values
        for masterKey, masterValue in pairs(oldMasterEnabledValue) do
            local currValue = getMasterEnabled(masterKey)
            if currValue ~= masterValue then
                sendOSCCommand(string.format('SendOSC %d "/masterEnabled/%s,i,%d"', oscEntry, masterKey, currValue and 1 or 0))
                oldMasterEnabledValue[masterKey] = currValue
            end
        end

        -- Get current selected page
        local myPage = CurrentExecPage()
        
        -- Detect page changes and cleanup deleted pages
        local currentPageIndices = {}
        for _, page in ipairs(DataPool().Pages:Children()) do
            currentPageIndices[page.No] = true
        end
        
        -- Cleanup old values for deleted pages
        for pageNo, _ in pairs(existingPages) do
            if not currentPageIndices[pageNo] then
                cleanupOldPageValues(pageNo)
            end
        end
        
        -- Update existing pages tracking
        existingPages = currentPageIndices
        
        -- Reset values if page changed
        if myPage.index ~= destPage then
            destPage = myPage.index
            
            -- Reset current page executor values
            local currentValues = getOrInitTable(oldFaderValues, 0)
            for maKey, _ in pairs(currentValues) do
                currentValues[maKey] = 0
            end
            
            currentValues = getOrInitTable(oldButtonValues, 0)
            for maKey, _ in pairs(currentValues) do
                currentValues[maKey] = false
            end
            
            forceReload = true
            sendOSCCommand(string.format('SendOSC %d "/updatePage/current,i,%d"', oscEntry, destPage))
        end

        -- Get all pages once for optimization
        local allPages = DataPool().Pages:Children()
        
        -- Build a lookup table for pages to avoid repeated iteration
        local pageLookup = {}
        for _, page in ipairs(allPages) do
            pageLookup[page.No] = page
        end

        -- Optimized: Process all pages in single pass
        -- First, collect all data for all pages
        local pageDataCache = {}
        local faderOptions = {}
        faderOptions.value = faderEnd
        faderOptions.token = "FaderMaster"
        faderOptions.faderDisabled = false
        
        for _, page in ipairs(allPages) do
            pageDataCache[page.No] = {}
            
            -- Process Any Page executors for this page
            for _, executor in ipairs(executorsToWatchAnyPage) do
                local buttonValue = false
                local colorValue = "0,0,0,0"
                local nameValue = ";"
                local faderValue = 0
                local isFlash = false

                local maValue = findExecutor(page.No, executor)
                if maValue then
                    local myobject = maValue.Object

                    if myobject ~= nil then
                        buttonValue = myobject:HasActivePlayback()
                        if sendColors then colorValue = getAppearanceColor(myobject) end
                        if sendNames then nameValue = getName(myobject) end
                        if sendFaders then
                            faderValue = maValue:GetFader(faderOptions)
                            isFlash = maValue.KEY == "Flash"
                        end
                    end
                end

                pageDataCache[page.No][executor] = {
                    button = buttonValue,
                    color = colorValue,
                    name = nameValue,
                    fader = faderValue,
                    isFlash = isFlash
                }
            end
        end

        -- Now send OSC commands based on cached data
        for _, page in ipairs(allPages) do
            local pageNo = page.No
            local executorData = pageDataCache[pageNo]
            
            -- Initialize cache tables once per page
            local oldButtons = getOrInitTable(oldButtonValues, pageNo)
            local oldColors = getOrInitTable(oldColorValues, pageNo)
            local oldNames = getOrInitTable(oldNameValues, pageNo)
            local oldFaders = getOrInitTable(oldFaderValues, pageNo)
            
            for _, executor in ipairs(executorsToWatchAnyPage) do
                local data = executorData[executor]
                
                -- Check for new changes
                if oldButtons[executor] ~= data.button or forceReload or forceReloadButtons then
                    oldButtons[executor] = data.button
                    sendOSCCommand(string.format('SendOSC %d "/Page%d/Exec%d/Button,s,%s"',
                        oscEntry, pageNo, executor, data.button and "On" or "Off"))
                end

                if sendFaders and ((oldFaders[executor] ~= data.fader and not (data.isFlash and data.button and data.fader == 100)) or forceReload) then
                    oldFaders[executor] = data.fader
                    sendOSCCommand(string.format('SendOSC %d "/Page%d/Exec%d/Fader,i,%d"',
                        oscEntry, pageNo, executor, math.floor(data.fader * FADER_MIDI_SCALE)))
                end

                if sendColors and (oldColors[executor] ~= data.color or forceReload) then
                    oldColors[executor] = data.color
                    sendOSCCommand(string.format('SendOSC %d "/Page%d/Exec%d/Color,s,%s"',
                        oscEntry, pageNo, executor, data.color:gsub(",", ";")))
                end

                if sendNames and (oldNames[executor] ~= data.name or forceReload) then
                    oldNames[executor] = data.name
                    sendOSCCommand(string.format('SendOSC %d "/Page%d/Exec%d/Name,s,%s"',
                        oscEntry, pageNo, executor, data.name))
                end
            end
        end

        -- 2. Executors from current page (Current Page - Page is not sent with the feedback)
        -- Initialize current page cache tables
        local currentOldButtons = getOrInitTable(oldButtonValues, 0)
        local currentOldColors = getOrInitTable(oldColorValues, 0)
        local currentOldNames = getOrInitTable(oldNameValues, 0)
        local currentOldFaders = getOrInitTable(oldFaderValues, 0)
        
        for _, executor in ipairs(executorsToWatchCurrentPage) do
            if table.contains(executorsToWatchAnyPage, executor) then goto continue end

            local buttonValue = false
            local colorValue = "0,0,0,0"
            local nameValue = ";"
            local faderValue = 0
            local isFlash = false

            local maValue = findExecutor(destPage, executor)

            if maValue then
                local myobject = maValue.Object

                if myobject ~= nil then
                    buttonValue = myobject:HasActivePlayback()
                    if sendColors then colorValue = getAppearanceColor(myobject) end
                    if sendNames then nameValue = getName(myobject) end
                    if sendFaders then
                        faderValue = maValue:GetFader(faderOptions)
                        isFlash = maValue.KEY == "Flash"
                    end
                end
            end

            -- Check for new changes
            if currentOldButtons[executor] ~= buttonValue or forceReload or forceReloadButtons then
                currentOldButtons[executor] = buttonValue
                sendOSCCommand(string.format('SendOSC %d "/Exec%d/Button,s,%s"',
                    oscEntry, executor, buttonValue and "On" or "Off"))
            end

            if sendFaders and ((currentOldFaders[executor] ~= faderValue and not (isFlash and buttonValue and faderValue == 100)) or forceReload) then
                currentOldFaders[executor] = faderValue
                sendOSCCommand(string.format('SendOSC %d "/Exec%d/Fader,i,%d"',
                    oscEntry, executor, math.floor(faderValue * FADER_MIDI_SCALE)))
            end

            if sendColors and (currentOldColors[executor] ~= colorValue or forceReload) then
                currentOldColors[executor] = colorValue
                sendOSCCommand(string.format('SendOSC %d "/Exec%d/Color,s,%s"',
                    oscEntry, executor, colorValue:gsub(",", ";")))
            end

            if sendNames and (currentOldNames[executor] ~= nameValue or forceReload) then
                currentOldNames[executor] = nameValue
                sendOSCCommand(string.format('SendOSC %d "/Exec%d/Name,s,%s"',
                    oscEntry, executor, nameValue))
            end
            ::continue::
        end

        forceReload = false
        forceReloadButtons = false

        -- delay
        coroutine.yield(POLL_RATE)
    end
end

return main
