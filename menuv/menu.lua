----------------------- [ MenuV ] -----------------------
-- GitHub: https://github.com/ThymonA/menuv/
-- License: GNU General Public License v3.0
--          https://choosealicense.com/licenses/gpl-3.0/
-- Author: Thymon Arens <contact@arens.io>
-- Name: MenuV
-- Version: 1.0.0
-- Description: FiveM menu libarary for creating menu's
----------------------- [ MenuV ] -----------------------
local assert = assert
---@type Utilities
local U = assert(Utilities)
local type = assert(type)
local pairs = assert(pairs)
local ipairs = assert(ipairs)
local lower = assert(string.lower)
local upper = assert(string.upper)
local sub = assert(string.sub)
local insert = assert(table.insert)
local remove = assert(table.remove)
local pack = assert(table.pack)
local unpack = assert(table.unpack)
local encode = assert(json.encode)
local rawset = assert(rawset)
local rawget = assert(rawget)
local setmetatable = assert(setmetatable)

--- FiveM globals
local GET_CURRENT_RESOURCE_NAME = assert(GetCurrentResourceName)
local GET_INVOKING_RESOURCE = assert(GetInvokingResource)

--- MenuV local variable
local current_resource = GET_CURRENT_RESOURCE_NAME()

--- Create a new menu item
---@param info table Menu information
---@return Menu New item
function CreateMenu(info)
    info = U:Ensure(info, {})

    local item = {
        ---@type string
        UUID = U:UUID(),
        ---@type string
        Title = U:Ensure(info.Title or info.title, 'MenuV'),
        ---@type string
        Subtitle = U:Ensure(info.Subtitle or info.subtitle, ''),
        ---@type string | "'topleft'" | "'topcenter'" | "'topright'" | "'centerleft'" | "'center'" | "'centerright'" | "'bottomleft'" | "'bottomcenter'" | "'bottomright'"
        Position = U:Ensure(info.Position or info.position, 'topleft'),
        ---@type table
        Color = {
            R = U:Ensure(info.R or info.r, 0),
            G = U:Ensure(info.G or info.g, 0),
            B = U:Ensure(info.B or info.b, 255)
        },
        ---@type table
        Events = U:Ensure(info.Events or info.events, {}),
        ---@type Item[]
        Items = {},
        ---@param t Menu
        ---@param event string Name of Event
        Trigger = function(t, event, ...)
            event = lower(U:Ensure(event, 'unknown'))

            if (event == 'unknown') then return end
            if (U:StartsWith(event, 'on')) then
                event = 'On' .. sub(event, 3):gsub('^%l', upper)
            else
                event = 'On' .. event:gsub('^%l', upper)
            end

            if (not U:Any(event, (t.Events or {}), 'key')) then
                return
            end

            local args = pack(...)

            for _, v in pairs(t.Events[event]) do
                if (type(v) == 'table' and U:Typeof(v.func) == 'function') then
                    CreateThread(function()
                        v.func(t, unpack(args))
                    end)
                end
            end
        end,
        ---@param t Menu
        ---@param event string Name of event
        ---@param func function|Menu Function or Menu to trigger
        ---@return string UUID of event
        On = function(t, event, func)
            local ir = GET_INVOKING_RESOURCE()
            local resource = U:Ensure(ir, current_resource)

            event = lower(U:Ensure(event, 'unknown'))

            if (event == 'unknown') then return end
            if (U:StartsWith(event, 'on')) then
                event = 'On' .. sub(event, 3):gsub('^%l', upper)
            else
                event = 'On' .. event:gsub('^%l', upper)
            end

            if (not U:Any(event, (t.Events or {}), 'key')) then
                return
            end

            func = U:Ensure(func, function() end)

            local uuid = U:UUID()

            insert(t.Events[event], {
                __uuid = uuid,
                __resource = resource,
                func = func
            })

            return uuid
        end,
        ---@param t Menu
        ---@param event string Name of event
        ---@param uuid string UUID of event
        RemoveOnEvent = function(t, event, uuid)
            local ir = GET_INVOKING_RESOURCE()
            local resource = U:Ensure(ir, current_resource)

            event = lower(U:Ensure(event, 'unknown'))

            if (event == 'unknown') then return end
            if (U:StartsWith(event, 'on')) then
                event = 'On' .. sub(event, 3):gsub('^%l', upper)
            else
                event = 'On' .. event:gsub('^%l', upper)
            end

            if (not U:Any(event, (t.Events or {}), 'key')) then
                return
            end

            uuid = U:Ensure(uuid, '00000000-0000-0000-0000-000000000000')

            for i = 1, #t.Events[event], 1 do
                if (t.Events[event][i] ~= nil and
                    t.Events[event][i].__uuid == uuid and
                    t.Events[event][i].__resource == resource) then
                    remove(t.Events[event], i)
                end
            end
        end,
        ---@param t Item
        ---@param k string
        ---@param v string
        Validate = U:Ensure(info.Validate or info.validate, function(t, k, v)
            return true
        end),
        ---@param t Item
        ---@param k string
        ---@param v string
        Parser = function(t, k, v)
            if (k == 'Position' or k == 'position') then
                local position = lower(U:Ensure(v, 'topleft'))

                if (U:Any(position, {'topleft', 'topcenter', 'topright', 'centerleft', 'center', 'centerright', 'bottomleft', 'bottomcenter', 'bottomright'}, 'value')) then
                    return position
                else
                    return 'topleft'
                end
            end

            return v
        end,
        ---@param t Item
        ---@param k string
        ---@param v string
        NewIndex = U:Ensure(info.NewIndex or info.newIndex, function(t, k, v)
        end),
        ---@type function
        ---@param t Menu MenuV menu
        ---@param info table Information about button
        ---@return Item New item
        AddButton = function(t, info)
            info = U:Ensure(info, {})

            info.Type = 'button'
            info.Events = { OnSelect = {} }
            info.PrimaryEvent = 'OnSelect'

            if (U:Typeof(info.Value or info.value) == 'Menu') then
                info.Type = 'menu'
            end

            local item = CreateMenuItem(info)

            if (info.Type == 'menu') then
                item:On('select', function() item.Value() end)
            end

            insert(t.Items, item)

            return t.Items[#t.Items] or item
        end,
        ---@type function
        ---@param t Menu MenuV menu
        ---@param info table Information about checkbox
        ---@return Item New item
        AddCheckbox = function(t, info)
            info = U:Ensure(info, {})

            info.Type = 'checkbox'
            info.Value = U:Ensure(info.Value or info.value, false)
            info.Events = { OnChange = {}, OnCheck = {}, OnUncheck = {} }
            info.PrimaryEvent = 'OnCheck'

            local item = CreateMenuItem(info)

            insert(t.Items, item)

            return t.Items[#t.Items] or item
        end,
        ---@type function
        ---@param t Menu MenuV menu
        ---@param info table Information about slider
        ---@return SliderItem New slider item
        AddSlider = function(t, info)
            info = U:Ensure(info, {})

            info.Type = 'slider'
            info.Events = { OnChange = {}, OnSelect = {} }
            info.PrimaryEvent = 'OnSelect'

            ---@class SliderItem : Item
            ---@filed private __event string Name of primary event
            ---@field public UUID string UUID of Item
            ---@field public Icon string Icon/Emoji for Item
            ---@field public Label string Label of Item
            ---@field public Description string Description of Item
            ---@field public Value any Value of Item
            ---@field public Values table[] List of values
            ---@field public Min number Min range value
            ---@field public Max number Max range value
            ---@field public Disabled boolean Disabled state of Item
            ---@field private Events table<string, function[]> List of registered `on` events
            ---@field public Trigger fun(t: Item, event: string)
            ---@field public On fun(t: Item, event: string, func: function)
            ---@field public Validate fun(t: Item, k: string, v:any)
            ---@field public NewIndex fun(t: Item, k: string, v: any)
            ---@field public GetValue fun(t: Item):any
            ---@field public AddValue fun(t: Item, info: table)
            ---@field public AddValues fun(t: Item)
            local item = CreateMenuItem(info)

            --- Add a value to slider
            ---@param info table Information about slider
            function item:AddValue(info)
                info = U:Ensure(info, {})

                local value = {
                    Label = U:Ensure(info.Label or info.label, 'Value'),
                    Description = U:Ensure(info.Description or info.description, ''),
                    Value = info.Value or info.value
                }

                insert(self.Values, value)
            end

            --- Add values to slider
            ---@vararg table[] List of values
            function item:AddValues(...)
                local arguments = pack(...)

                for _, argument in pairs(arguments) do
                    if (U:Typeof(argument) == 'table') then
                        local hasIndex = argument[1] or nil

                        if (hasIndex and U:Typeof(hasIndex) == 'table') then
                            self:AddValues(unpack(argument))
                        else
                            self:AddValue(argument)
                        end
                    end
                end
            end

            local values = U:Ensure(info.Values or info.values, {})

            if (#values > 0) then
                item:AddValues(values)
            end

            insert(t.Items, item)

            return t.Items[#t.Items] or item
        end,
        ---@type function
        ---@param t Menu MenuV menu
        ---@param info table Information about range
        ---@return RangeItem New Range item
        AddRange = function(t, info)
            info = U:Ensure(info, {})

            info.Type = 'range'
            info.Events = { OnChange = {}, OnSelect = {}, OnMin = {}, OnMax = {} }
            info.PrimaryEvent = 'OnSelect'
            info.Value = U:Ensure(info.Value or info.value, 0)
            info.Min = U:Ensure(info.Min or info.min, 0)
            info.Max = U:Ensure(info.Max or info.max, 0)
            info.Validate = function(t, k, v)
                if (k == 'Value' or k == 'value') then
                    v = U:Ensure(v, 0)

                    if (t.Min > v) then return false end
                    if (t.Max < v) then return false end
                end

                return true
            end

            if (info.Min > info.Max) then
                local min = info.Min
                local max = info.Max

                info.Min = min
                info.Max = max
            end

            if (info.Value < info.Min) then info.Value = info.Min end
            if (info.Value > info.Max) then info.Value = info.Max end

            ---@class RangeItem : Item
            ---@filed private __event string Name of primary event
            ---@field public UUID string UUID of Item
            ---@field public Icon string Icon/Emoji for Item
            ---@field public Label string Label of Item
            ---@field public Description string Description of Item
            ---@field public Value any Value of Item
            ---@field public Values table[] List of values
            ---@field public Min number Min range value
            ---@field public Max number Max range value
            ---@field public Disabled boolean Disabled state of Item
            ---@field private Events table<string, function[]> List of registered `on` events
            ---@field public Trigger fun(t: Item, event: string)
            ---@field public On fun(t: Item, event: string, func: function)
            ---@field public Validate fun(t: Item, k: string, v:any)
            ---@field public NewIndex fun(t: Item, k: string, v: any)
            ---@field public GetValue fun(t: Item):any
            ---@field public SetMinValue fun(t: any)
            ---@field public SetMaxValue fun(t: any)
            local item = CreateMenuItem(info)

            --- Update min value of range
            ---@param input number Minimum value of Range
            function item:SetMinValue(input)
                input = U:Ensure(input, 0)

                self.Min = input

                if (self.Value < self.Min) then
                    self.Value = self.Min
                end

                if (self.Min > self.Max) then
                    self.Max = self.Min
                end
            end

            --- Update max value of range
            ---@param input number Minimum value of Range
            function item:SetMaxValue(input)
                input = U:Ensure(input, 0)

                self.Min = input

                if (self.Value > self.Max) then
                    self.Value = self.Max
                end

                if (self.Min < self.Max) then
                    self.Min = self.Max
                end
            end

            insert(t.Items, item)

            return t.Items[#t.Items] or item
        end,
        ---@type function
        ---@param t Menu MenuV menu
        ---@param info table Information about confirm
        ---@return ConfirmItem New Confirm item
        AddConfirm = function(t, info)
            info = U:Ensure(info, {})

            info.Type = 'confirm'
            info.Value = U:Ensure(info.Value or info.value, false)
            info.Events = { OnConfirm = {}, OnDeny = {}, OnChange = {} }
            info.PrimaryEvent = 'OnConfirm'
            info.NewIndex = function(t, k, v)
                if (k == 'Value') then
                    local value = U:Ensure(v, false)

                    if (value) then
                        t:Trigger('confirm', t)
                    else
                        t:Trigger('deny', t)
                    end
                end
            end

            ---@class ConfirmItem : Item
            ---@filed private __event string Name of primary event
            ---@field public UUID string UUID of Item
            ---@field public Icon string Icon/Emoji for Item
            ---@field public Label string Label of Item
            ---@field public Description string Description of Item
            ---@field public Value any Value of Item
            ---@field public Values table[] List of values
            ---@field public Min number Min range value
            ---@field public Max number Max range value
            ---@field public Disabled boolean Disabled state of Item
            ---@field private Events table<string, function[]> List of registered `on` events
            ---@field public Trigger fun(t: Item, event: string)
            ---@field public On fun(t: Item, event: string, func: function)
            ---@field public Validate fun(t: Item, k: string, v:any)
            ---@field public NewIndex fun(t: Item, k: string, v: any)
            ---@field public GetValue fun(t: Item):any
            ---@field public Confirm fun(t: Item)
            ---@field public Deny fun(t: Item)
            local item = CreateMenuItem(info)

            --- Confirm this item
            function item:Confirm() item.Value = true end
            --- Deny this item
            function item:Deny() item.Value = false end

            insert(t.Items, item)

            return t.Items[#t.Items] or item
        end,
        --- Change title of menu
        ---@param t Menu
        ---@param title string Title of menu
        SetTitle = function(t, title)
            t.Title = U:Ensure(title, 'MenuV')
        end,
        --- Change subtitle of menu
        ---@param t Menu
        ---@param subtitle string Subtitle of menu
        SetSubtitle = function(t, subtitle)
            t.Subtitle = U:Ensure(subtitle, '')
        end,
        --- Change subtitle of menu
        ---@param t Menu
        ---@param position string | "'topleft'" | "'topcenter'" | "'topright'" | "'centerleft'" | "'center'" | "'centerright'" | "'bottomleft'" | "'bottomcenter'" | "'bottomright'"
        SetPosition = function(t, position)
            t.Position = U:Ensure(position, 'topleft')
        end,
        --- @see Menu to @see table
        ---@param t Menu
        ---@return table
        ToTable = function(t)
            local tempTable = {
                uuid = U:Ensure(t.UUID, '00000000-0000-0000-0000-000000000000'),
                title = U:Ensure(t.Title, 'MenuV'),
                subtitle = U:Ensure(t.Subtitle, ''),
                color = {
                    r = U:Ensure(t.Color.R, 0),
                    g = U:Ensure(t.Color.G, 0),
                    b = U:Ensure(t.Color.B, 255)
                },
                items = {}
            }

            if (tempTable.color.r <= 0) then tempTable.color.r = 0 end
            if (tempTable.color.r >= 255) then tempTable.color.r = 255 end
            if (tempTable.color.g <= 0) then tempTable.color.g = 0 end
            if (tempTable.color.g >= 255) then tempTable.color.g = 255 end
            if (tempTable.color.b <= 0) then tempTable.color.b = 0 end
            if (tempTable.color.b >= 255) then tempTable.color.b = 255 end

            local _items = U:Ensure(t.Items, {})
            local index = 0

            ---@param option Item
            for _, option in pairs(_items) do
                index = index + 1

                tempTable.items[index] = {
                    index = index,
                    type = option.__type,
                    uuid = U:Ensure(option.UUID, 'unknown'),
                    icon = U:Ensure(option.Icon, '▶️'),
                    label = U:Ensure(option.Label, 'Unknown'),
                    description = U:Ensure(option.Description, ''),
                    value = 'none',
                    values = {},
                    min = U:Ensure(option.Min, 0),
                    max = U:Ensure(option.Max, 0),
                    disabled = U:Ensure(option.Disabled, false)
                }

                if (option.__type == 'button' or option.__type == 'menu') then
                    tempTable.items[index].value = 'none'
                elseif (option.__type == 'checkbox' or option.__type == 'confirm') then
                    tempTable.items[index].value = U:Ensure(option.Value, false)
                elseif (option.__type == 'range') then
                    tempTable.items[index].value = U:Ensure(option.Value, 0)

                    if (tempTable.items[index].value <= tempTable.items[index].min) then
                        tempTable.items[index].value = tempTable.items[index].min
                    elseif (tempTable.items[index].value >= tempTable.items[index].max) then
                        tempTable.items[index].value = tempTable.items[index].max
                    end
                elseif (option.__type == 'slider') then
                    tempTable.items[index].value = 0
                end

                local _values = U:Ensure(option.Values, {})
                local vIndex = 0

                for valueIndex, value in pairs(_values) do
                    vIndex = vIndex + 1

                    tempTable.items[index].values[vIndex] = {
                        label = U:Ensure(value.Label, 'Option'),
                        description = U:Ensure(value.Description, ''),
                        value = vIndex
                    }

                    if (option.__type == 'slider') then
                        if (U:Ensure(option.Value, 0) == valueIndex) then
                            tempTable.items[index].value = (valueIndex - 1)
                        end
                    end
                end
            end

            return tempTable
        end
    }

    item.Events.OnOpen = {}
    item.Events.OnClose = {}
    item.Events.OnSelect = {}
    item.Events.OnUpdate = {}
    item.Events.OnSwitch = {}
    item.Events.OnChange = {}

    local mt = {
        __index = function(t, k)
            return rawget(t.data, k)
        end,
        ---@param t Menu
        __tostring = function(t)
            return encode(t:ToTable())
        end,
        __call = function(t)
            MenuV:OpenMenu(t)
        end,
        __newindex = function(t, k, v)
            local key = U:Ensure(k, 'unknown')
            local oldValue = rawget(t.data, k)
            local checkInput = t.Validate ~= nil and type(t.Validate) == 'function'
            local inputParser = t.Parser ~= nil and type(t.Parser) == 'function'
            local updateIndexTrigger = t.NewIndex ~= nil and type(t.NewIndex) == 'function'

            if (checkInput) then
                local result = t:Validate(key, v)
                result = U:Ensure(result, true)

                if (not result) then
                   return
                end
            end

            if (inputParser) then
                local parsedValue = t:Parser(key, v)

                v = parsedValue or v
            end

            rawset(t.data, k, v)

            if (updateIndexTrigger) then
                t:NewIndex(key, v)
            end

            if (t.Trigger ~= nil and type(t.Trigger) == 'function') then
                t:Trigger('update', key, v, oldValue)
            end
        end,
        __len = function(t)
            return #t.Items
        end,
        __pairs = function(t)
            return pairs(rawget(t.data, 'Items') or {})
        end,
        __ipairs = function(t)
            return ipairs(rawget(t.data, 'Items') or {})
        end,
        __metatable = 'MenuV',
    }

    ---@class Menu
    ---@field public UUID string UUID of Menu
    ---@field public Title string Title of Menu
    ---@field public Subtitle string Subtitle of Menu
    ---@field public Position string | "'topleft'" | "'topcenter'" | "'topright'" | "'centerleft'" | "'center'" | "'centerright'" | "'bottomleft'" | "'bottomcenter'" | "'bottomright'"
    ---@field public Color table<string, number> Color of Menu
    ---@field private Events table<string, fun[]> List of registered `on` events
    ---@field private Items Item[] List of items
    ---@field public Trigger fun(t: Item, event: string)
    ---@field public On fun(t: Menu, event: string, func: function|Menu): string
    ---@field public RemoveOnEvent fun(t: Menu, event: string, uuid: string)
    ---@field public Validate fun(t: Menu, k: string, v:any)
    ---@field public NewIndex fun(t: Menu, k: string, v: any)
    ---@field public Parser fun(t: Menu, k: string, v: any)
    ---@field public AddButton fun(t: Menu, info: table):Item
    ---@field public AddCheckbox fun(t: Menu, info: table):Item
    ---@field public AddSlider fun(t: Menu, info: table):SliderItem
    ---@field public AddRange fun(t: Menu, info: table):RangeItem
    ---@field public AddConfirm fun(t: Menu, info: table):ConfirmItem
    ---@field public ToTable fun(t: Menu):table
    return setmetatable({ data = item, __class = 'Menu', __type = 'Menu' }, mt)
end