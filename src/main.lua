repeat task.wait() until game:IsLoaded()

-- =============================================
--  CONFIGURATION DU CONTENEUR VIA FICHIER LOCAL
-- =============================================

local CONFIG_FILE = "VapeConfigPath.txt"

-- Fonction pour lire ou créer le fichier de configuration
local function loadContainerFromFile()
    local defaultPath = "Players"
    local path = defaultPath
    
    -- Vérifie si le fichier existe
    if isfile(CONFIG_FILE) then
        local content = readfile(CONFIG_FILE)
        -- Nettoie le contenu (supprime les espaces, retours à la ligne)
        content = content:gsub("%s+", "")
        if content ~= "" then
            path = content
            print("[Config] Loaded container from file:", path)
        else
            print("[Config] File is empty, using default:", defaultPath)
            writefile(CONFIG_FILE, defaultPath)
        end
    else
        -- Crée le fichier avec la valeur par défaut
        writefile(CONFIG_FILE, defaultPath)
        print("[Config] Created config file with default:", defaultPath)
    end
    
    shared.PlayerContainer = path
    return path
end

-- Charge la configuration au démarrage
loadContainerFromFile()

-- Sauvegarde la nouvelle valeur dans le fichier (si elle change)
local function saveContainerToFile(path)
    if path and path ~= "" then
        writefile(CONFIG_FILE, path)
        print("[Config] Saved container to file:", path)
    end
end

-- Surveille les changements de shared.PlayerContainer pour les sauvegarder
task.spawn(function()
    local lastValue = shared.PlayerContainer
    while task.wait(2) do
        if shared.PlayerContainer and shared.PlayerContainer ~= lastValue then
            saveContainerToFile(shared.PlayerContainer)
            lastValue = shared.PlayerContainer
        end
    end
end)

shared.PlayerContainer = type(shared.PlayerContainer) == "string" and shared.PlayerContainer or "Players"
if shared.vape then shared.vape:Uninject() end

-- Créer vape comme table vide au départ
local vape = {}

local loadstring = function(...)
	local res, err = loadstring(...)
	if err and vape then
		-- vape peut ne pas encore avoir CreateNotification, on utilise warn en fallback
		if vape.CreateNotification then
			vape:CreateNotification('Vape', 'Failed to load : '..err, 30, 'alert')
		else
			warn('[Vape] Failed to load : '..err)
		end
	end
	return res
end

local queue_on_teleport = queue_on_teleport or function() end
local isfile = isfile or function(file)
	local suc, res = pcall(function()
		return readfile(file)
	end)
	return suc and res ~= nil and res ~= ''
end
local cloneref = cloneref or function(obj)
	return obj
end
local playersService = cloneref(game:GetService('Players'))

local function downloadFile(path, func)
	if not isfile(path) then
		local suc, res = pcall(function()
			return game:HttpGet('https://raw.githubusercontent.com/nozory/VapeCompiled/'..readfile('newvape/profiles/commit.txt')..'/'..select(1, path:gsub('newvape/', '')), true)
		end)
		if not suc or res == '404: Not Found' then
			error(res)
		end
		if path:find('.lua') then
			res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..res
		end
		writefile(path, res)
	end
	return (func or readfile)(path)
end

local function finishLoading()
	vape.Init = nil
	vape:Load()
	task.spawn(function()
		repeat
			vape:Save()
			task.wait(10)
		until not vape.Loaded
	end)

	local teleportedServers
	vape:Clean(playersService.LocalPlayer.OnTeleport:Connect(function()
		if (not teleportedServers) and (not shared.VapeIndependent) then
			teleportedServers = true
			local teleportScript = [[
				shared.vapereload = true
				if shared.VapeDeveloper then
					loadstring(readfile('newvape/loader.lua'), 'loader')()
				else
					loadstring(game:HttpGet('https://raw.githubusercontent.com/nozory/VapeCompiled/'..readfile('newvape/profiles/commit.txt')..'/loader.lua', true), 'loader')()
				end
			]]
			if shared.VapeDeveloper then
				teleportScript = 'shared.VapeDeveloper = true\n'..teleportScript
			end
			if shared.VapeCustomProfile then
				teleportScript = 'shared.VapeCustomProfile = "'..shared.VapeCustomProfile..'"\n'..teleportScript
			end
			vape:Save()
			queue_on_teleport(teleportScript)
		end
	end))

	if not shared.vapereload then
		if not vape.Categories then return end
		if vape.Settings.GUI.Options['GUI bind indicator'].Enabled then
			vape:CreateNotification('Finished Loading', vape.VapeButton and 'Press the button in the top right to open GUI' or 'Press '..table.concat(vape.GUIBind.Keys, ' + '):upper()..' to open GUI', 5)
		end
	end
end

if not isfile('newvape/profiles/gui.txt') then
	writefile('newvape/profiles/gui.txt', 'new')
end
local gui = 'new'--readfile('newvape/profiles/gui.txt')

if not isfolder('newvape/assets/'..gui) then
	makefolder('newvape/assets/'..gui)
end

-- =============================================
--  Charge la GUI et remplace vape par l'objet réel
-- =============================================
vape = loadstring(downloadFile('newvape/guis/'..gui..'.lua'), 'gui')()
shared.vape = vape

-- =============================================
--  CHARGE entity.lua DANS vape.Libraries
--  (maintenant que vape existe vraiment)
-- =============================================
if not vape.Libraries then
	vape.Libraries = {}
end

if not vape.Libraries.entity then
	local entityPath = 'newvape/libraries/entity.lua'
	local entityScript
	
	if isfile(entityPath) then
		entityScript = loadstring(readfile(entityPath), 'entity')
	else
		local suc, res = pcall(function()
			return downloadFile(entityPath)
		end)
		if suc and res then
			entityScript = loadstring(res, 'entity')
		end
	end
	
	if entityScript then
		vape.Libraries.entity = entityScript()
		print("[Main] entity loaded into vape.Libraries")
	else
		warn("[Main] Failed to load entity.lua")
	end
end
-- =============================================
--  FIN CHARGEMENT entity
-- =============================================
-- =============================================
--  COMMANDES VIA CONSOLE ROBLOX (F9)
-- =============================================

local function setupConsoleCommands()
    -- Sauvegarde de l'ancien print
    local oldPrint = print

    -- Remplace print par notre version
    print = function(...)
        local args = {...}
        local msg = table.concat(args, " ")
        
        -- Vérifie si le message est une commande ';container'
        if type(msg) == "string" and msg:lower():match("^;container (.+)") then
            local newPath = msg:match("^;container (.+)")
            print("[Console] Container path updated to:", newPath)
            
            -- Met à jour la variable partagée
            shared.PlayerContainer = newPath
            
            -- Met à jour entity si disponible
            if vape.Libraries and vape.Libraries.entity then
                if vape.Libraries.entity.updateContainer then
                    vape.Libraries.entity.updateContainer(newPath)
                elseif vape.Libraries.entity.Running then
                    vape.Libraries.entity.stop()
                    vape.Libraries.entity.start()
                end
            else
                print("[Console] entity not loaded yet, value stored in shared.PlayerContainer")
            end
            
            -- Notification (si disponible)
            if vape.CreateNotification then
                vape:CreateNotification("Container", "Set to: " .. newPath, 2)
            end
            
            -- Ne pas afficher la commande dans la console (optionnel)
            return
        end
        
        -- Appelle l'ancien print pour tout le reste
        oldPrint(...)
    end
end

-- Lance l'écoute des commandes console
task.spawn(setupConsoleCommands)

print("[Main] Console commands ready. Type ';container <path>' in F9 console.")

if not shared.VapeIndependent then
	loadstring(downloadFile('newvape/games/universal.lua'), 'universal')()
	if isfile('newvape/games/'..game.PlaceId..'.lua') then
		loadstring(readfile('newvape/games/'..game.PlaceId..'.lua'), tostring(game.PlaceId))(...)
	else
		if not shared.VapeDeveloper then
			local suc, res = pcall(function()
				return game:HttpGet('https://raw.githubusercontent.com/nozory/VapeCompiled/'..readfile('newvape/profiles/commit.txt')..'/games/'..game.PlaceId..'.lua', true)
			end)
			if suc and res ~= '404: Not Found' then
				loadstring(downloadFile('newvape/games/'..game.PlaceId..'.lua'), tostring(game.PlaceId))(...)
			end
		end
	end
	finishLoading()
else
	vape.Init = finishLoading
	return vape
end