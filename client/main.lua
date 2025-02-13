local ox_inventory = exports.ox_inventory
local Racks = {}
local RenderDistance = 150
local rackModel = `xm_prop_xm_gunlocker_01a`
local tempRackObj = nil

local Keys = {
	["Q"] = 44, ["E"] = 38, ["ENTER"] = 18, ["X"] = 73
}

local ox_items = exports.ox_inventory:Items()
for item, data in pairs(ox_items) do
    if Config.rackableWeapons[item] then
        Config.rackableWeapons[item].label = data.label
    end
end

local function storeWeapon(rack, slot, name)
    TriggerServerEvent('js5m_gunrack:server:storeWeapon', rack, slot, name)
end

local function takeWeapon(rack, rackSlot, name)
    TriggerServerEvent('js5m_gunrack:server:takeWeapon', rack, rackSlot, name)
end

local function GetRackPositionOffset(rackIndex, slot, weapon)
    local rack = Racks[rackIndex].object
    local weaponType = Config.rackableWeapons[weapon].weaponType
    local xOffset = 0.0
    if weaponType == 'rifles' then
        if slot == 1 then
            xOffset = -0.395
        elseif slot == 2 then
            xOffset = -0.28
        elseif slot == 3 then
            xOffset = -0.17
        elseif slot == 4 then
            xOffset = -0.06
        elseif slot == 5 then
            xOffset = 0.06
        end
    elseif weaponType == 'pistols' then
        if slot == 1 then
            xOffset = -0.32
        elseif slot == 2 then
            xOffset = -0.17
        elseif slot == 3 then
            xOffset = 0.00
        elseif slot == 4 then
            xOffset = 0.15
        elseif slot == 5 then
            xOffset = 0.30
        end
    end

    local weaponData = Config.rackableWeapons[weapon]
    local zOffset = weaponData.offset.z or 0.0
    local yOffset = weaponData.offset.y or 0.0

    local xRotation = weaponData.rotation.x or 1
    local yRotation = weaponData.rotation.y or 260
    local rackHeading = Racks[rackIndex].coords.w
    local weaponZRotation = weaponData.rotation.z or 90
    local zRotation = rackHeading - weaponZRotation
    return {offset = GetOffsetFromEntityInWorldCoords(rack, xOffset, yOffset, zOffset), rot = {x = xRotation, y = yRotation, z = zRotation}}
end

local function hasVarMod(hash, components)
    for i = 1, #components do
        local component = ox_items[components[i]]

        if component.type == 'skin' or component.type == 'upgrade' then
            local weaponComp = component.client.component
            for j = 1, #weaponComp do
                local weaponComponent = weaponComp[j]
                if DoesWeaponTakeWeaponComponent(hash, weaponComponent) then
                    return GetWeaponComponentTypeModel(weaponComponent)
                end
            end
        end
    end
end

local function getWeaponComponents(name, hash, components)
    local weaponComponents = {}
    local amount = 0
    local hadClip = false
    local varMod = hasVarMod(hash, components)

    for i = 1, #components do
        local weaponComp = ox_items[components[i]]
        for j = 1, #weaponComp.client.component do
            local weaponComponent = weaponComp.client.component[j]
            if DoesWeaponTakeWeaponComponent(hash, weaponComponent) and varMod ~= weaponComponent then
                amount += 1
                weaponComponents[amount] = weaponComponent

                if weaponComp.type == 'magazine' then
                    hadClip = true
                end

                break
            end
        end
    end

    if not hadClip then
        amount += 1
        weaponComponents[amount] = joaat(('COMPONENT_%s_CLIP_01'):format(name:sub(8)))
    end


    return varMod, weaponComponents, hadClip
end

local function spawnGun(rackId, slot, weaponType)
    local rack = Racks[rackId]
    if not rack then return end

    local position = GetRackPositionOffset(rackId, slot, rack[weaponType][slot].name)
    local hash = GetHashKey(rack[weaponType][slot].name)
    lib.requestWeaponAsset(hash, 5000, 31, 0)
    rack[weaponType][slot].object = CreateWeaponObject(hash, 50, position.offset.x, position.offset.y, position.offset.z, true, 1.0, 0)
    while not DoesEntityExist(rack[weaponType][slot].object) do Wait(1) end
    SetEntityCoords(rack[weaponType][slot].object, position.offset.x, position.offset.y, position.offset.z, false, false, false, true)
    local hasLuxeMod, components, hadClip = getWeaponComponents(rack[weaponType][slot].name, hash, rack[weaponType][slot].metadata.components)
    if hasLuxeMod then
        lib.requestModel(hasLuxeMod, 500)
    end
    if components then
        for i = 1, #components do
            GiveWeaponComponentToWeaponObject(rack[weaponType][slot].object, components[i])
        end
    end
    if rack[weaponType][slot].tint then
        SetWeaponObjectTintIndex(rack[weaponType][slot].object, rack[weaponType][slot].tint)
    end
    FreezeEntityPosition(rack[weaponType][slot].object, true)
    SetEntityRotation(rack[weaponType][slot].object, position.rot.x, position.rot.y, position.rot.z)
end

local function fadeGun(rackId, slot, weaponType)
    local rack = Racks[rackId]
    if not rack then return end
    local object = rack[weaponType][slot].object
    if object then
        DeleteEntity(object)
    end
end

local function fadeGunRack(id)
    local rack = Racks[id]
    if DoesEntityExist(rack.object) then
        for i=1, #rack.rifles do
            local object = rack.rifles[i].object
            if object then
                DeleteEntity(object)
            end
        end
        for i=1, #rack.pistols do
            local object = rack.pistols[i].object
            if object then
                DeleteEntity(object)
            end
        end
        exports["qb-target"]:RemoveTargetEntity({rack.object})
        DeleteEntity(rack.object)
        rack.object = nil
        rack.isRendered = false
    end
end

local function displayPlayerWeapons(data)
    local registeredMenu = {
        id = 'js5m_gunrack_storeWeaponsMenu',
        title = 'Store Weapons',
        options = {}
    }
    local options = {}

    local items = ox_inventory:GetPlayerItems()
    for k, v in pairs(items) do
        if Config.rackableWeapons[v.name] then
            local metadata = {}
            for i=1, #v.metadata.components do
                metadata[#metadata+1] = {label = "Component", value = ox_items[v.metadata.components[i]].label}
            end
            metadata[#metadata+1] = {label = "Ammo", value = v.metadata.ammo}
            metadata[#metadata+1] = {label = "Durability", value = v.metadata.durability..'%'}
            options[#options+1] = {
                title = 'Store ' .. v.label,
                onSelect = function()
                    storeWeapon(data.args.rack, v.slot, v.name)
                end,
                metadata = metadata,
            }
        end
    end

    if #options == 0 then
        options[#options+1] = {
            title = 'No weapons to store',
            disabled = true
        }
    end

    registeredMenu["options"] = options
    
    lib.registerContext(registeredMenu)
    lib.showContext('js5m_gunrack_storeWeaponsMenu')
end

local function takeRackWeapons(data)
    local rack = Racks[data.args.rack]
    local registeredMenu = {
        id = 'js5m_gunrack_takeWeaponsMenu',
        title = 'Take Weapons',
        options = {}
    }
    local options = {}

    for i=1, #rack.rifles do
        local item = rack.rifles[i]
        if item.name then
            local metadata = {}
            for i=1, #item.metadata.components do
                metadata[#metadata+1] = {label = "Component", value = ox_items[item.metadata.components[i]].label}
            end
            metadata[#metadata+1] = {label = "Ammo", value = item.metadata.ammo}
            metadata[#metadata+1] = {label = "Durability", value = item.metadata.durability ..'%'}
            options[#options+1] = {
                
                title = 'Take ' .. Config.rackableWeapons[item.name].label,
                onSelect = function()
                    takeWeapon(data.args.rack, i, item.name)
                end,
                metadata = metadata,
            }
        end
    end

    for i=1, #rack.pistols do
        local item = rack.pistols[i]
        if item.name then
            local metadata = {}
            for i=1, #item.metadata.components do
                metadata[#metadata+1] = {label = "Component", value = ox_items[item.metadata.components[i]].label}
            end
            metadata[#metadata+1] = {label = "Ammo", value = item.metadata.ammo}
            metadata[#metadata+1] = {label = "Durability", value = item.metadata.durability ..'%'}
            options[#options+1] = {
                
                title = 'Take ' .. Config.rackableWeapons[item.name].label,
                onSelect = function()
                    takeWeapon(data.args.rack, i, item.name)
                end,
                metadata = metadata,
            }
        end
    end

    if #options == 0 then
        options[#options+1] = {
            title = 'No weapons to take',
            disabled = true
        }
    end

    registeredMenu["options"] = options
    
    lib.registerContext(registeredMenu)
    lib.showContext('js5m_gunrack_takeWeaponsMenu')
end

local function destroyGunRack(data)
    local rack = data.args.rack
    local confirm = lib.alertDialog({
        header = 'Destroy the gun rack?',
        content = 'Are you sure that you want to destroy this build? You will lose all the contents.',
        centered = true,
        cancel = true
    })
    if confirm ~= 'confirm' then return end
    TriggerServerEvent('js5m_gunrack:server:destroyGunRack', rack)
end

local rackJob = nil

local function spawnGunRack(id)
    local rack = Racks[id]
    lib.requestModel(rackModel)
    rack.object = CreateObject(rackModel, rack.coords.x, rack.coords.y, rack.coords.z, false, false, false)
    SetEntityHeading(rack.object, rack.coords.w)
    SetEntityAlpha(rack.object, 0)
    PlaceObjectOnGroundProperly(rack.object)
    FreezeEntityPosition(rack.object, true)

    if rack.job == "null" then 
        rackJob = nil
    else 
        rackJob = rack.job
    end
    
    exports["qb-target"]:AddTargetEntity({rack.object}, {
        options = {
            {
                label = 'Store Weapon',
                name = 'gunrack:storeWeapon',
                icon = 'fa-solid fa-hand-holding',
                distance = 1.5,
                job = rackJob,
                action = function()
                    displayPlayerWeapons({args = {rack = id}})
                end,
            },
            {
                label = 'Take Weapon',
                name = 'gunrack:takeWeapon',
                icon = 'fa-solid fa-hand-fist',
                distance = 1.5,
                job = rackJob,
                action = function()
                    takeRackWeapons({args = {rack = id}})
                end,
            },
            {
                label = 'Destroy Gun Rack',
                name = 'gunrack:destroyGunRack',
                icon = 'fa-solid fa-trash-can',
                distance = 1.5,
                job = rackJob,
                action = function()
                    destroyGunRack({args = {rack = id}})
                end,
            }
        },
        distance = 1.5
    })

    for i = 0, 255, 51 do
        Wait(50)
        SetEntityAlpha(rack.object, i, false)
    end
    rack.isRendered = true
    for i=1, #rack.rifles do
        if not rack.rifles[i].available then
            spawnGun(id, i, 'rifles')
        end
    end
    for i=1, #rack.pistols do
        if not rack.pistols[i].available then
            spawnGun(id, i, 'pistols')
        end
    end
end

local function RotationToDirection(rotation)
	local adjustedRotation =
	{
		x = (math.pi / 180) * rotation.x,
		y = (math.pi / 180) * rotation.y,
		z = (math.pi / 180) * rotation.z
	}
	local direction =
	{
		x = -math.sin(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
		y = math.cos(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
		z = math.sin(adjustedRotation.x)
	}
	return direction
end

local function RayCastGamePlayCamera(distance)
    local cameraRotation = GetGameplayCamRot()
	local cameraCoord = GetGameplayCamCoord()
	local direction = RotationToDirection(cameraRotation)
	local destination =
	{
		x = cameraCoord.x + direction.x * distance,
		y = cameraCoord.y + direction.y * distance,
		z = cameraCoord.z + direction.z * distance
	}
	local a, b, c, d, e = GetShapeTestResult(StartShapeTestSweptSphere(cameraCoord.x, cameraCoord.y, cameraCoord.z, destination.x, destination.y, destination.z, 0.2, 339, PlayerPedId(), 4))
	return b, c, e
end

local PlacingObject = false

exports('placeGunRack', function()
    if PlacingObject then return end
    local playerCoords = GetEntityCoords(cache.ped)
    lib.requestModel(rackModel)
    tempRackObj = CreateObject(rackModel, playerCoords.x, playerCoords.y, playerCoords.z, true, true, false)
    local heading = 0.0
    SetEntityHeading(tempRackObj, 0)
    
    SetEntityAlpha(tempRackObj, 225)
    SetEntityCollision(tempRackObj, false, false)
    -- SetEntityInvincible(tempRackObj, true)
    FreezeEntityPosition(tempRackObj, true)

    PlacingObject = true
    local rackCoords = nil
    local inRange = false

    local function deleteRack()
        PlacingObject = false
        SetEntityDrawOutline(tempRackObj, false)
        DeleteEntity(tempRackObj)
        tempRackObj = nil
        lib.hideTextUI()
    end

    lib.showTextUI(
        '**[Q/E]**   -   Rotate  \n' ..
        '**[ENTER]**   -   Place gun rack  \n' ..
        '**[X]**   -   Abandon  \n'
    )

    CreateThread(function()
        while PlacingObject do
            local hit, coords, entity = RayCastGamePlayCamera(20.0)
            rackCoords = coords
            DisableControlAction( 0, Keys["Q"], true ) -- cover
            DisableControlAction( 0, Keys["E"], true ) -- cover

            if hit then
                SetEntityCoords(tempRackObj, coords.x, coords.y, coords.z)
                PlaceObjectOnGroundProperly(tempRackObj)
                SetEntityDrawOutline(tempRackObj, true)
            end

            if #(rackCoords - GetEntityCoords(cache.ped)) < 2.0 then
                SetEntityDrawOutlineColor(2, 241, 181, 255)
                inRange = true
            else --not in range
                inRange = false
                SetEntityDrawOutlineColor(244, 68, 46, 255)
            end

            if IsControlPressed(0, Keys["X"]) then
                deleteRack()
                PlacingObject = false
            end
            
            if IsDisabledControlPressed(0, Keys["Q"]) then
                heading = heading + 2
                if heading > 360 then heading = 0.0 end
            end
    
            if IsDisabledControlPressed(0, Keys["E"]) then
                heading = heading - 2
                if heading < 0 then heading = 360.0 end
            end

            SetEntityHeading(tempRackObj, heading)
            if IsControlJustPressed(0, Keys["ENTER"]) then

               local input = lib.inputDialog('Gun racks', {
                    {type = 'input', label = 'Required job', description = 'Here put a required job ("null" if not restriced for job)', required = true, min = 4, max = 16},
                })

                local job = input[1]

                if not IsPedOnFoot(cache.ped) then
                    deleteRack()
                    return
                end
                if not inRange then
                    deleteRack()
                    return
                end
                local rackRot = GetEntityHeading(tempRackObj)
                local rackCoords = GetEntityCoords(tempRackObj)
                deleteRack()

                TaskStartScenarioInPlace(cache.ped, "WORLD_HUMAN_HAMMERING", 0, true)
                if lib.progressBar({
                    duration = 10000,
                    label = 'Building Gun Rack',
                    useWhileDead = false,
                    canCancel = true,
                    disable = {
                        car = true,
                    },
                }) then
                    ClearPedTasks(cache.ped)
                    TriggerServerEvent('js5m_gunrack:server:placeGunRack', rackCoords, rackRot, job)
                else
                    ClearPedTasks(cache.ped)
                end
            end
        Wait(0)
        end
    end)
end)

RegisterNetEvent('js5m_gunrack:client:placeGunRack', function(id, data)
    if source == '' then return end
    Racks[id] = data
end)

RegisterNetEvent('js5m_gunrack:client:storeWeapon', function(rackIndex, rackSlot, rackType, data)
    if source == '' then return end
    Racks[rackIndex][rackType][rackSlot] = data
    spawnGun(rackIndex, rackSlot, rackType)
end)

RegisterNetEvent('js5m_gunrack:client:takeWeapon', function(rackIndex, rackSlot, rackType)
    if source == '' then return end
    fadeGun(rackIndex, rackSlot, rackType)
    Racks[rackIndex][rackType][rackSlot] = {name = nil, available = true}
end)

RegisterNetEvent('js5m_gunrack:client:destroyGunRack', function(id)
    if source == '' then return end
    local rack = Racks[id]
    if rack.isRendered then
        fadeGunRack(id)
    end
    Racks[id] = nil
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    for k, v in pairs(Racks) do
        for k, v in pairs(v.rifles) do
            if v.object then
                DeleteEntity(v.object)
            end
        end
        for k, v in pairs(v.pistols) do
            if v.object then
                DeleteEntity(v.object)
            end
        end
        exports["qb-target"]:RemoveTargetEntity({v.object})
        DeleteEntity(v.object)
    end
    if tempRackObj then
        DeleteEntity(tempRackObj)
    end
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    Racks = lib.callback.await('js5m_gunrack:server:getRacks', false)
end)

CreateThread(function()
    while true do
        local playerCoords = GetEntityCoords(cache.ped)
        for k, rack in pairs(Racks) do
            local dist = #(playerCoords - vec3(rack.coords.x, rack.coords.y, rack.coords.z))
            if dist < RenderDistance and not rack.isRendered then
                spawnGunRack(k)
            elseif dist >= RenderDistance and rack.isRendered then
                fadeGunRack(k)
            end
        end
        Wait(2500)
    end
end)
