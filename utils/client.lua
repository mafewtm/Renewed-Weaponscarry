local Config = require 'config'
local ox_items = exports.ox_inventory:Items()
local skins = {}
local Utils = {}

local playerSlots = {
	{ -- Bigger weapons such as bats, crowbars, Assaultrifles, and also good place for wet weed.
		{ bone = 24817, pos = vec3(0.04, -0.15, 0.12), rot = vec3(0.0, 0.0, 0.0) },
		{ bone = 24817, pos = vec3(0.04, -0.17, 0.02), rot = vec3(0.0, 0.0, 0.0) },
		{ bone = 24817, pos = vec3(0.04, -0.19, -0.08), rot = vec3(0.0, 0.0, 0.0) },
	},

	{ -- Use this for katana knives etc. stuff that goes sideways on the players body
		{ bone = 24817, pos = vec3(-0.13, -0.16, -0.14), rot = vec3(5.0, 62.0, 0.0) },
		{ bone = 24817, pos = vec3(-0.13, -0.15, 0.10), rot = vec3(5.0, 124.0,0.0) },
	},

	{ -- Contraband like Drugs and shit
		{ bone = 24817, pos = vec3(-0.28, -0.14, 0.15), rot = vec3(0.0, 92.0, -13.0) },
		{ bone = 24817, pos = vec3(-0.27, -0.14, 0.15), rot = vec3(0.0, 92.0, 13.0) },
	},
}

for k, v in pairs(ox_items) do
    if v.type == 'skin' then
        skins[#skins+1] = k
    end
end

function Utils.resetSlots()
    for i = 1, #playerSlots do
        for v = 1, #playerSlots[i] do
            playerSlots[i][v].isBusy = false
        end
    end
end

function Utils.getLuxeComponent(metadata)
    for i = 1, #metadata do

        if lib.table.contains(skins, metadata[i]) then
            table.remove(metadata, i)
            return metadata, ox_items['at_skin_luxe'].client.component
        end
    end

    return metadata
end


function Utils.equipComponents(metadata, weaponObj)
    local modelSwap

    if metadata.components then
        local compData, varMod = Utils.getLuxeComponent(metadata.components)

        if varMod and next(varMod) then
            for i = 1, #varMod do
                local component = varMod[i]
                if DoesWeaponTakeWeaponComponent(metadata.hash, component) then
                    modelSwap = GetWeaponComponentTypeModel(component)
                    GiveWeaponComponentToWeaponObject(weaponObj, component)
                end
            end
        end

        for i = 1, #compData do
            local components = ox_items[compData[i]].client.component
            for v = 1, #components do
                local component = components[v]
                if DoesWeaponTakeWeaponComponent(metadata.hash, component) then
                    GiveWeaponComponentToWeaponObject(weaponObj, component)
                end
            end
        end
    end

    if metadata.tint then
        SetWeaponObjectTintIndex(weaponObj, tint)
    end

    if modelSwap then
        lib.requestModel(modelSwap, 1000)
        local coords = GetEntityCoords(weaponObj)
        CreateModelSwap(coords.x, coords.y, coords.z, 0.1, GetEntityModel(weaponObj), modelSwap)
        SetModelAsNoLongerNeeded(modelSwap)
    end
end

function Utils.createWeapon(item)
    lib.requestWeaponAsset(item.hash, 1000, 31, 0)
    RequestWeaponHighDetailModel(item.hash)
    local weaponObject = CreateWeaponObject(item.hash, 50, 0.0, 0.0, 0.0, true, 1.0, 0)

    RemoveWeaponAsset(item.hash)
    RemoveObjectHighDetailModel(item.hash)

    Utils.equipComponents(item, weaponObject)

    return weaponObject
end

function Utils.createObject(item)
    lib.requestModel(item.model, 1000)
    local Object = CreateObject(item.model, 0.0, 0.0, 0.0, false, false, false)
    SetModelAsNoLongerNeeded(item.model)

    return Object
end

function Utils.findOpenSlot(tier)
    local slotTier = playerSlots[tier]
    for i = 1, #slotTier do
        if not slotTier[i].isBusy then
            slotTier[i].isBusy = true
            return slotTier[i]
        end
    end

    return slotTier[#slotTier]
end

function Utils.formatData(itemData, configTable)
    local searchName = itemData.name:lower()
    local isWeapon = searchName:find('weapon_')

    local slot = Utils.findOpenSlot(Config[searchName].slot)

    return {
        name = itemData.name,
        hash = isWeapon and configTable.hash or joaat(itemData.name),
        components = isWeapon and itemData?.metadata?.components,
        tint = isWeapon and itemData?.metadata?.tint,
        model = not isWeapon and Config[itemData.name].model,
        pos = slot and slot.pos,
        rot = slot and slot.rot,
        bone = slot and slot.bone,
    }
end


function Utils.formatPlayerInventory(inventory, currentWeapon)
    local items = {}
    local amount = 0

    for _, itemData in pairs(inventory) do
        local name = itemData and itemData.name:lower()

        if currentWeapon and itemData and currentWeapon.name == itemData.name and lib.table.matches(itemData.metadata.components, currentWeapon.metadata.components) then
            currentWeapon = nil
        elseif name then
            if Config[name] then
                amount += 1
                items[amount] = Utils.formatData(itemData, Config[name])
            end
        end
    end

    Utils.resetSlots()

    return items
end

return Utils