local minigameModule = {
gameRunning = false,
playersAlive = {},
currentMap = nil
}

local waitForChild = game.WaitForChild
local findFirstChild = game.FindFirstChild

-- Modulos

local settingsModule = require(waitForChild(script, "Settings"))
local onWin = (function()
local onWinModule = findFirstChild(script, "OnWin")
if onWinModule then
local onWinFunction = require(onWinModule)
if type(onWinFunction) == "function" then
return onWinFunction
end
end
end)()

local remoteEvent = waitForChild(game:GetService("ReplicatedStorage"), "Event")
local mapsStorage = waitForChild(game:GetService("ServerStorage"), "Maps"):GetChildren()

local playersService = game:GetService("Players")

function minigameModule.isPotentialGame()
return playersService.NumPlayers >= settingsModule.minimumPlayers
end

function minigameModule:chooseMap()
local chosenMap = mapsStorage[#mapsStorage]:Clone()
if findFirstChild(chosenMap, "Spawns") then
chosenMap.Parent = workspace
chosenMap:MakeJoints()
self.currentMap = chosenMap
return chosenMap
end
end

function minigameModule:spawnPlayers()
local playersAlive = self.playersAlive
local spawns = self.currentMap.Spawns:GetChildren()
for index = 1, #playersAlive do
local playerData = playersAlive[index]
playerData.playerHumanoidRoot.CFrame = spawns[math.random(#spawns)].CFrame
end
end

function minigameModule:runIntermission()
if settingsModule.intermissionTime > 0 then
for currentTime = math.floor(settingsModule.intermissionTime), 0, -1 do
remoteEvent:FireAllClients("Timer", currentTime)
wait(1)
end
end
remoteEvent:FireAllClients("CeaseGUIs")
end

function minigameModule:getAlivePlayers()
local playersAlive = {}
for index, currentPlayer in next, playersService:GetPlayers() do
local playerCharacter = currentPlayer.Character
if playerCharacter then
local playerHumanoidRoot = findFirstChild(playerCharacter, "HumanoidRootPart")
local playerHumanoid = findFirstChild(playerCharacter, "Humanoid")
if playerHumanoid and playerHumanoidRoot then
table.insert(playersAlive, {
player = currentPlayer,
playerHumanoid = playerHumanoid,
playerHumanoidRoot = playerHumanoidRoot
})
end
end
end
return playersAlive
end

function minigameModule:isLegalGame()
if #self:getAlivePlayers() >= settingsModule.minimumPlayers then
return true
end
end

function minigameModule:queryGameStart()
if self.gameRunning then
return
elseif self.isPotentialGame() then
self.gameRunning = true
remoteEvent:FireAllClients("CeaseGUIs")
self:runIntermission()
if self:isLegalGame() then
if settingsModule.roundDuration > 0 then
local currentMap = self:chooseMap()
local mapWeapons = findFirstChild(currentMap, "Weapons")
local playersAlive = self:getAlivePlayers()
self.playersAlive = playersAlive
for index = 1, #playersAlive do
local currentPlayer = playersAlive[index]
local backpack = findFirstChild(currentPlayer.player, "Backpack")
if backpack and mapWeapons then
for index, weapon in next, mapWeapons:GetChildren() do
weapon:Clone().Parent = backpack
end
end
local connection
connection = currentPlayer.playerHumanoid.Died:connect(function()
connection:disconnect()
table.remove(playersAlive, index)
if #playersAlive < 2 then
local winner = playersAlive[1]
if winner then
self:endGame(winner.player.Name .. " has won!", winner.player)
else
self:endGame("No one has won!")
end
end
end)
end
if mapWeapons then
mapWeapons:Destroy()
end
self:spawnPlayers() 
remoteEvent:FireAllClients("Message", currentMap.Name .. " was chosen!", 5)
for currentTime = settingsModule.roundDuration, 0, -1 do
if not self.gameRunning then
return
end
remoteEvent:FireAllClients("Timer", currentTime)
wait(1)
end
self:endGame("The timer ran out! No one has won!")
end
else
self:endGame("Not enough players alive to begin the round!")
end
else
local remainingPlayers = settingsModule.minimumPlayers - playersService.NumPlayers
remoteEvent:FireAllClients("Message", "Waiting for " .. remainingPlayers .. " player" .. (remainingPlayers > 1 and "s" or "") .. " to join.")
end
end

function minigameModule:endGame(outputMessage, winner)
if self.gameRunning then
self.gameRunning = false
self.currentMap:Destroy()
self.currentMap = nil
if winner and onWin then
onWin(winner)
end
for index, player in next, playersService:GetPlayers() do
player:LoadCharacter()
end
wait(1)
remoteEvent:FireAllClients("Message", outputMessage, 5)
wait(5)
self:queryGameStart()
end
end

function minigameModule:removePlayer(player)
if self.gameRunning then
for index = 1, #self.playersAlive do
if self.playersAlive[index].player == player then
table.remove(self.playersAlive, index)
if #self.playersAlive <= 1 then
self:endGame("Not enough players to continue the game.")
end
break
end
end 
end
end

playersService.PlayerAdded:connect(function()
minigameModule:queryGameStart()
end)

playersService.PlayerRemoving:connect(function(player)
minigameModule:removePlayer(player)
end)
