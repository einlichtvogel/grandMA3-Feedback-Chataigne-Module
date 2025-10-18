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

-- Initial setup for executorsToWatchCurrentPage
for i = 101, 116 do
    executorsToWatchCurrentPage [#executorsToWatchCurrentPage + 1] = i
end
for i = 201, 216 do
    executorsToWatchCurrentPage [#executorsToWatchCurrentPage + 1] = i
end
for i = 301, 316 do
    executorsToWatchCurrentPage [#executorsToWatchCurrentPage + 1] = i
end
for i = 401, 416 do
    executorsToWatchCurrentPage [#executorsToWatchCurrentPage + 1] = i
end

local oscEntry = -1

-- the Speed to check executors
local tick = 1 / 10 -- 1/10
local resendTick = 0

-- Utils --

local function getApereanceColor(sequence)
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
    -- Iteriere über jede Zahlenreihe, die durch ";" getrennt ist

    if executorsString then
        if anyPage then
            executorsToWatchCurrentPage = {}
        else
            executorsToWatchAnyPage = {}
        end
        for executorRange in string.gmatch(executorsString, "([^;]+)") do
            -- Splitte die Zahlenreihe bei "-"
            local start, stop = executorRange:match("(%d+)-(%d+)")
            if start and stop then
                start = tonumber(start)  -- Konvertiere in eine Zahl
                stop = tonumber(stop)    -- Konvertiere in eine Zahl

                -- Iteriere über den Bereich von start bis stop
                for i = start, stop do
                    executorsToWatchAnyPage[#executorsToWatchAnyPage + 1] = i
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

-- Utils end --

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
    local a,b = PopupInput(descTable)

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
            local value = table.nameContainsString(ShowData().OSCBase:Children(), "grandMA3 OSC Feedback Output")

            if value == nil then
                Cmd('Store OSC OSCData "grandMA3 OSC Feedback Output" "PORT" "8093" "SENDCOMMAND" "Yes"');
                Cmd('Store OSC OSCData "grandMA3 OSC Chataigne Input" "PORT" "8080" "RECEIVE" "Yes" "RECEIVECOMMAND" "Yes"');
            end


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
            local value = table.nameContainsString(ShowData().OSCBase:Children(), "grandMA3 OSC Feedback Output")

            if value then
                oscEntry = value.No
            else
                Cmd('Store OSC OSCData "grandMA3 OSC Feedback Output" "PORT" "8093" "SENDCOMMAND" "Yes"');
                Cmd('Store OSC OSCData "grandMA3 OSC Chataigne Input" "PORT" "8080" "RECEIVE" "Yes" "RECEIVECOMMAND" "Yes"');
                local value = table.nameContainsString(ShowData().OSCBase:Children(), "grandMA3 OSC Feedback Output")
                if value then
                    oscEntry = value.No;
                else
                    Printf(" -- ERROR: OSC Data not yet setup, run settings first -- ")
                    Printf(" -- Stopping grandMA3 OSC Feedback -- ")
                    Printf(" ------------------------------------ ")
                    return;
                end
            end

            SetVar(GlobalVars(), "gmaf_updateOSC", true)
        end

        -- welcome / bye messages
        if(GetVar(GlobalVars(), "gmaf_updateOSC") == true) then
            Printf(" Running... ")

            -- Feedback for the Cahatigne Plugin to set itself up
            local resultString = ""
            for i, child in ipairs(DataPool().Pages:Children()) do
                resultString = resultString .. child  -- Fügen Sie den Kindnamen zum String hinzu
                if i < #DataPool().Pages:Children() then
                    resultString = resultString .. ";"  -- Fügen Sie ein Komma hinzu, wenn es nicht das letzte Element ist
                end
            end
            Cmd(string.format('SendOSC %d "/Setup/executorsToWatchAnyPage,s,%s"', oscEntry, execsAny))
            Cmd(string.format('SendOSC %d "/Setup/pages,s,%s"', oscEntry, resultString))
            Cmd(string.format('SendOSC %d "/Setup/setupAllValues,i,1"', oscEntry))
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
        if resendTick >= 15 then
            forceReloadButtons = true
            resendTick = 0
        end

        -- Check Master Enabled Values
        for masterKey, masterValue in pairs(oldMasterEnabledValue) do
            local currValue = getMasterEnabled(masterKey)
            if currValue ~= masterValue then
                Cmd('SendOSC ' .. oscEntry .. ' "/masterEnabled/' .. masterKey .. ',i,' .. (currValue and 1 or 0))
                oldMasterEnabledValue[masterKey] = currValue
            end
        end

        -- Get current selected page
        local myPage = CurrentExecPage()
        -- Reset values if page changed
        if myPage.index ~= destPage then
            destPage = myPage.index
            for maKey, maValue in pairs(oldFaderValues) do
                oldFaderValues[0][maKey] = 000
            end
            for maKey, maValue in pairs(oldButtonValues) do
                oldButtonValues[0][maKey] = false
            end
            forceReload = true
            Cmd('SendOSC ' .. oscEntry .. ' "/updatePage/current,i,' .. destPage)
        end

        -- 1. Executor over all pages (Any Page - Page gets sent with the feedback)
        for _, executor in ipairs(executorsToWatchAnyPage) do
            for _, page in ipairs(DataPool().Pages:Children()) do

                local buttonValue = false
                local colorValue = "0,0,0,0"
                local nameValue = ";"
                local faderValue = 0

                local faderOptions = {}
                faderOptions.value = faderEnd
                faderOptions.token = "FaderMaster"
                faderOptions.faderDisabled = false
                local isFlash = false

                local maValue = findExecutor(page.No, executor)
                if maValue then
                    local myobject = maValue.Object

                    if myobject ~= nil then
                        buttonValue = myobject:HasActivePlayback() and true or false
                        if sendColors then colorValue = getApereanceColor(myobject) end
                        if sendNames then nameValue = getName(myobject) end
                        if sendFaders then
                            faderValue = maValue:GetFader(faderOptions)
                            isFlash = maValue.KEY == "Flash"
                        end
                    end
                else
                    -- If the executor is not found, set default values
                    buttonValue = false
                    colorValue = "0,0,0,0"
                    nameValue = ";"
                    faderValue = 0
                end

                -- Init all values
                oldButtonValues[page.No] = oldButtonValues[page.No] or {}
                oldColorValues[page.No] = oldColorValues[page.No] or {}
                oldNameValues[page.No] = oldNameValues[page.No] or {}
                oldFaderValues[page.No] = oldFaderValues[page.No] or {}

                -- Check for new changes
                if oldButtonValues[page.No][executor] ~= buttonValue or forceReload or forceReloadButtons then
                    oldButtonValues[page.No][executor] = buttonValue
                    Cmd(string.format('SendOSC %d "/Page%d/Exec%d/Button,s,%s"',
                        oscEntry, page.No, executor, buttonValue and "On" or "Off"))
                end

                if sendFaders and ((oldFaderValues[page.No][executor] ~= faderValue and not (isFlash and buttonValue and faderValue == 100)) or forceReload) then
                    oldFaderValues[page.No][executor] = faderValue
                    Cmd(string.format('SendOSC %d "/Page%d/Exec%d/Fader,i,%s"',
                        oscEntry, page.No, executor, faderValue * 1.27))
                end

                if sendColors and (oldColorValues[page.No][executor] ~= colorValue or forceReload) then
                    oldColorValues[page.No][executor] = colorValue
                    Cmd(string.format('SendOSC %d "/Page%d/Exec%d/Color,s,%s"',
                        oscEntry, page.No, executor, colorValue:gsub(",", ";")))
                end

                if sendNames and (oldNameValues[page.No][executor] ~= nameValue or forceReload) then
                    oldNameValues[page.No][executor] = nameValue
                    Cmd(string.format('SendOSC %d "/Page%d/Exec%d/Name,s,%s"',
                        oscEntry, page.No, executor, nameValue))
                end
            end
        end

        -- 2. Executors from current page (Current Page - Page is not sent with the feedback)
        for _, executor in ipairs(executorsToWatchCurrentPage) do
            if table.contains(executorsToWatchAnyPage, executor) then goto continue end

            local buttonValue = false
            local colorValue = "0,0,0,0"
            local nameValue = ";"
            local faderValue = 0

            local faderOptions = {}
            faderOptions.value = faderEnd
            faderOptions.token = "FaderMaster"
            faderOptions.faderDisabled = false
            local isFlash = false

            local maValue = findExecutor(destPage, executor)

            if maValue then
                local myobject = maValue.Object

                if myobject ~= nil then
                    buttonValue = myobject:HasActivePlayback() and true or false
                    if sendColors then colorValue = getApereanceColor(myobject) end
                    if sendNames then nameValue = getName(myobject) end
                    if sendFaders then
                        faderValue = maValue:GetFader(faderOptions)
                        isFlash = maValue.KEY == "Flash"
                    end
                end
            else
                -- If the executor is not found, set default values
                buttonValue = false
                colorValue = "0,0,0,0"
                nameValue = ";"
                faderValue = 0
            end

            -- Init all values
            oldButtonValues[0] = oldButtonValues[0] or {}
            oldColorValues[0] = oldColorValues[0] or {}
            oldNameValues[0] = oldNameValues[0] or {}
            oldFaderValues[0] = oldFaderValues[0] or {}

            -- Check for new changes
            if oldButtonValues[0][executor] ~= buttonValue or forceReload or forceReloadButtons then
                oldButtonValues[0][executor] = buttonValue
                Cmd(string.format('SendOSC %d "/Exec%d/Button,s,%s"',
                    oscEntry, executor, buttonValue and "On" or "Off"))
            end

            if sendFaders and ((oldFaderValues[0][executor] ~= faderValue and not (isFlash and buttonValue and faderValue == 100)) or forceReload) then
                oldFaderValues[0][executor] = faderValue
                Cmd(string.format('SendOSC %d "/Exec%d/Fader,i,%s"',
                    oscEntry, executor, faderValue * 1.27))
            end

            if sendColors and (oldColorValues[0][executor] ~= colorValue or forceReload) then
                oldColorValues[0][executor] = colorValue
                Cmd(string.format('SendOSC %d "/Exec%d/Color,s,%s"',
                    oscEntry, executor, colorValue:gsub(",", ";")))
            end

            if sendNames and (oldNameValues[0][executor] ~= nameValue or forceReload) then
                oldNameValues[0][executor] = nameValue
                Cmd(string.format('SendOSC %d "/Exec%d/Name,s,%s"',
                    oscEntry, executor, nameValue))
            end
            ::continue::
        end

        forceReload = false
        forceReloadButtons = false

        -- delay
        coroutine.yield(tick)
    end
end

return main