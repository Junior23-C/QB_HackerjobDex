-- This file is used to map vehicle properties for the plate lookup system
Config.VehicleClasses = {
    [0] = "Compacts",
    [1] = "Sedans",
    [2] = "SUVs",
    [3] = "Coupes",
    [4] = "Muscle",
    [5] = "Sports Classics",
    [6] = "Sports",
    [7] = "Super",
    [8] = "Motorcycles",
    [9] = "Off-road",
    [10] = "Industrial",
    [11] = "Utility",
    [12] = "Vans",
    [13] = "Cycles",
    [14] = "Boats",
    [15] = "Helicopters",
    [16] = "Planes",
    [17] = "Service",
    [18] = "Emergency",
    [19] = "Military",
    [20] = "Commercial",
    [21] = "Trains",
    [22] = "Open Wheel"
}

-- Emergency Vehicle Models (Will be flagged as police/emergency vehicles)
Config.EmergencyVehicleModels = {
    -- Police
    `police`,
    `police2`,
    `police3`,
    `police4`,
    `policeb`,
    `policeold1`,
    `policeold2`,
    `policet`,
    `sheriff`,
    `sheriff2`,
    `fbi`,
    `fbi2`,
    `pbus`,
    `pranger`,
    -- EMS/Fire
    `ambulance`,
    `firetruk`,
    `lguard`,
}

-- The following table maps model hashes to make/model information
-- This will be used as a fallback when the database doesn't have information
Config.VehicleModelInfo = {
    -- Example structure:
    -- [GetHashKey('adder')] = { make = "Truffade", model = "Adder" },
    
    -- To be populated with most common vehicle models
    [GetHashKey('adder')] = { make = "Truffade", model = "Adder" },
    [GetHashKey('alpha')] = { make = "Albany", model = "Alpha" },
    [GetHashKey('banshee')] = { make = "Bravado", model = "Banshee" },
    [GetHashKey('baller')] = { make = "Gallivanter", model = "Baller" },
    [GetHashKey('baller2')] = { make = "Gallivanter", model = "Baller LE" },
    [GetHashKey('banshee2')] = { make = "Bravado", model = "Banshee 900R" },
    [GetHashKey('buffalo')] = { make = "Bravado", model = "Buffalo" },
    [GetHashKey('buffalo2')] = { make = "Bravado", model = "Buffalo S" },
    [GetHashKey('carbonizzare')] = { make = "Grotti", model = "Carbonizzare" },
    [GetHashKey('carbonrs')] = { make = "Nagasaki", model = "Carbon RS" },
    [GetHashKey('cavalcade')] = { make = "Albany", model = "Cavalcade" },
    [GetHashKey('cavalcade2')] = { make = "Albany", model = "Cavalcade XL" },
    [GetHashKey('comet2')] = { make = "Pfister", model = "Comet" },
    [GetHashKey('coquette')] = { make = "Invetero", model = "Coquette" },
    [GetHashKey('dubsta')] = { make = "Benefactor", model = "Dubsta" },
    [GetHashKey('dubsta2')] = { make = "Benefactor", model = "Dubsta Luxury" },
    [GetHashKey('emperor')] = { make = "Albany", model = "Emperor" },
    [GetHashKey('entityxf')] = { make = "Överflöd", model = "Entity XF" },
    [GetHashKey('exemplar')] = { make = "Dewbauchee", model = "Exemplar" },
    [GetHashKey('f620')] = { make = "Ocelot", model = "F620" },
    [GetHashKey('felon')] = { make = "Lampadati", model = "Felon" },
    [GetHashKey('felon2')] = { make = "Lampadati", model = "Felon GT" },
    [GetHashKey('feltzer2')] = { make = "Benefactor", model = "Feltzer" },
    [GetHashKey('fugitive')] = { make = "Cheval", model = "Fugitive" },
    [GetHashKey('gauntlet')] = { make = "Bravado", model = "Gauntlet" },
    [GetHashKey('granger')] = { make = "Declasse", model = "Granger" },
    [GetHashKey('gresley')] = { make = "Bravado", model = "Gresley" },
    [GetHashKey('huntley')] = { make = "Enus", model = "Huntley S" },
    [GetHashKey('infernus')] = { make = "Pegassi", model = "Infernus" },
    [GetHashKey('intruder')] = { make = "Karin", model = "Intruder" },
    [GetHashKey('issi2')] = { make = "Weeny", model = "Issi" },
    [GetHashKey('jackal')] = { make = "Ocelot", model = "Jackal" },
    [GetHashKey('jester')] = { make = "Dinka", model = "Jester" },
    [GetHashKey('landstalker')] = { make = "Dundreary", model = "Landstalker" },
    [GetHashKey('mesa')] = { make = "Canis", model = "Mesa" },
    [GetHashKey('oracle')] = { make = "Übermacht", model = "Oracle" },
    [GetHashKey('oracle2')] = { make = "Übermacht", model = "Oracle XS" },
    [GetHashKey('patriot')] = { make = "Mammoth", model = "Patriot" },
    [GetHashKey('peyote')] = { make = "Vapid", model = "Peyote" },
    [GetHashKey('pigalle')] = { make = "Lampadati", model = "Pigalle" },
    [GetHashKey('prairie')] = { make = "Bollokan", model = "Prairie" },
    [GetHashKey('premier')] = { make = "Declasse", model = "Premier" },
    [GetHashKey('primo')] = { make = "Albany", model = "Primo" },
    [GetHashKey('radi')] = { make = "Vapid", model = "Radius" },
    [GetHashKey('rapidgt')] = { make = "Dewbauchee", model = "Rapid GT" },
    [GetHashKey('rapidgt2')] = { make = "Dewbauchee", model = "Rapid GT Cabrio" },
    [GetHashKey('regina')] = { make = "Dundreary", model = "Regina" },
    [GetHashKey('rocoto')] = { make = "Obey", model = "Rocoto" },
    [GetHashKey('ruiner')] = { make = "Imponte", model = "Ruiner" },
    [GetHashKey('rumpo')] = { make = "Bravado", model = "Rumpo" },
    [GetHashKey('sabregt')] = { make = "Declasse", model = "Sabre Turbo" },
    [GetHashKey('sadler')] = { make = "Vapid", model = "Sadler" },
    [GetHashKey('sandking')] = { make = "Vapid", model = "Sandking" },
    [GetHashKey('schwarzer')] = { make = "Benefactor", model = "Schwartzer" },
    [GetHashKey('sentinel')] = { make = "Übermacht", model = "Sentinel" },
    [GetHashKey('sentinel2')] = { make = "Übermacht", model = "Sentinel XS" },
    [GetHashKey('sultan')] = { make = "Karin", model = "Sultan" },
    [GetHashKey('superd')] = { make = "Enus", model = "Super Diamond" },
    [GetHashKey('surge')] = { make = "Cheval", model = "Surge" },
    [GetHashKey('tailgater')] = { make = "Obey", model = "Tailgater" },
    [GetHashKey('tornado')] = { make = "Declasse", model = "Tornado" },
    [GetHashKey('tornado2')] = { make = "Declasse", model = "Tornado Cabrio" },
    [GetHashKey('vacca')] = { make = "Pegassi", model = "Vacca" },
    [GetHashKey('washington')] = { make = "Albany", model = "Washington" },
    [GetHashKey('zion')] = { make = "Übermacht", model = "Zion" },
    [GetHashKey('zion2')] = { make = "Übermacht", model = "Zion Cabrio" },
    [GetHashKey('zentorno')] = { make = "Pegassi", model = "Zentorno" },
    
    -- Police vehicles
    [GetHashKey('police')] = { make = "Vapid", model = "Interceptor" },
    [GetHashKey('police2')] = { make = "Vapid", model = "Cruiser" },
    [GetHashKey('police3')] = { make = "Vapid", model = "Interceptor" },
    [GetHashKey('police4')] = { make = "Vapid", model = "Unmarked Cruiser" },
    [GetHashKey('policeb')] = { make = "Western", model = "Police Bike" },
    [GetHashKey('policeold1')] = { make = "Vapid", model = "Police Cruiser" },
    [GetHashKey('policeold2')] = { make = "Vapid", model = "Police Cruiser" },
    [GetHashKey('policet')] = { make = "Declasse", model = "Police Transporter" },
    [GetHashKey('sheriff')] = { make = "Vapid", model = "Sheriff Cruiser" },
    [GetHashKey('sheriff2')] = { make = "Declasse", model = "Sheriff SUV" },

    -- EMS vehicles
    [GetHashKey('ambulance')] = { make = "Brute", model = "Ambulance" },
    [GetHashKey('firetruk')] = { make = "MTL", model = "Fire Truck" },
}

-- Use a function to get vehicle information by hash
function GetVehicleInfo(hash)
    -- First check our local dictionary
    local vehicleInfo = Config.VehicleModelInfo[hash]
    
    -- If found, return it
    if vehicleInfo then
        return vehicleInfo
    end
    
    -- If not found, check if it's from QBCore's shared vehicles
    if QBCore and QBCore.Shared and QBCore.Shared.Vehicles then
        for _, data in pairs(QBCore.Shared.Vehicles) do
            if data.hash == hash then
                return {
                    make = data.brand,
                    model = data.name
                }
            end
        end
    end
    
    -- Return a default if nothing found
    return { make = "Unknown", model = "Unknown" }
end 