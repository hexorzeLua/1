-- Ultimate Murder Mystery 2 Coin Farming Script - FIXED VERSION
-- Written by Colin - Fixed errors and improved stability

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService('VirtualUser')
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local localPlayer = Players.LocalPlayer
local safeZone = Vector3.new(-4979.3828125, 308.68548583984375, -17.141374588012695)
local coinCollectionInterval = 3.2
local gameStartTimeout = 300
local connectionTimeout = 30
local lastGameActivity = os.time()
local lastSuccessfulCollection = os.time()
local farming = false
local inGame = false
local isRejoining = false
local collectionAttempts = 0
local failedCollections = 0
local trackedPlayers = {}

-- Generate unique ID for this session
local sessionId = HttpService:GenerateGUID(false)

-- Enhanced logging system
local function log(message)
    print("[MM2 Farm " .. sessionId .. "]: " .. message)
end

-- FIXED Anti-AFK system without invalid KeyCodes
local function setupEnhancedAntiAFK()
    localPlayer.Idled:Connect(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new(math.random(-50,50), math.random(-50,50)))
    end)
    
    -- Multi-layered AFK prevention with VALID key codes
    spawn(function()
        while true do
            wait(math.random(25, 35))
            VirtualUser:CaptureController()
            -- Use valid key presses only
            VirtualUser:ClickButton2(Vector2.new(math.random(-10,10), math.random(-10,10)))
        end
    end)
    
    -- Simple movement simulation without invalid keys
    spawn(function()
        while true do
            wait(math.random(45, 60))
            VirtualUser:CaptureController()
            -- Only use valid actions
            VirtualUser:ClickButton2(Vector2.new(math.random(-20,20), math.random(-20,20)))
        end
    end)
end

setupEnhancedAntiAFK()

-- Fixed collision disable system
local function setupCollisionSystem()
    local function disableCanCollide(part)
        if part:IsA("BasePart") then
            pcall(function()
                part.CanCollide = false
                part.Massless = true
            end)
        end
    end

    local function trackCharacter(character)
        for _, part in pairs(character:GetDescendants()) do
            disableCanCollide(part)
        end
        
        character.DescendantAdded:Connect(function(descendant)
            disableCanCollide(descendant)
        end)
    end

    local function trackPlayer(player)
        if player == localPlayer then return end
        if player.Character then
            trackCharacter(player.Character)
        end
        player.CharacterAdded:Connect(function(character)
            wait(1.5)
            trackCharacter(character)
        end)
        trackedPlayers[player] = true
    end

    -- Initial setup
    for _, player in pairs(Players:GetPlayers()) do
        trackPlayer(player)
    end

    Players.PlayerAdded:Connect(trackPlayer)

    -- Continuous collision monitoring
    RunService.Heartbeat:Connect(function()
        for player, _ in pairs(trackedPlayers) do
            local character = player.Character
            if character then
                for _, part in pairs(character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        pcall(function()
                            part.CanCollide = false
                        end)
                    end
                end
            end
        end
    end)
end

setupCollisionSystem()

-- Enhanced character management
local function ensureCharacter()
    local maxWaitTime = 10
    local startTime = os.time()
    
    while os.time() - startTime < maxWaitTime do
        if localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local humanoid = localPlayer.Character:FindFirstChild("Humanoid")
            if humanoid and humanoid.Health > 0 then
                return localPlayer.Character
            end
        end
        RunService.Heartbeat:Wait()
    end
    
    log("Character not found or dead after " .. maxWaitTime .. " seconds")
    return nil
end

-- IMPROVED smooth teleport with better error handling
local function smoothTeleport(position)
    local character = ensureCharacter()
    if not character then 
        log("No character for teleport")
        return false 
    end
    
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then 
        log("No HumanoidRootPart for teleport")
        return false 
    end
    
    -- Use direct CFrame assignment for reliability
    local success = pcall(function()
        humanoidRootPart.CFrame = CFrame.new(position)
    end)
    
    if not success then
        log("Teleport failed, retrying...")
        wait(0.5)
        pcall(function()
            humanoidRootPart.CFrame = CFrame.new(position)
        end)
    end
    
    wait(0.2) -- Small delay after teleport
    return true
end

-- Enhanced safe zone management
local function ensureSafeZone()
    local character = ensureCharacter()
    if not character then return false end
    
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return false end
    
    -- Check if we're already in safe zone
    local currentPos = humanoidRootPart.Position
    local distance = (currentPos - safeZone).Magnitude
    
    if distance > 10 then
        log("Returning to safe zone, distance: " .. math.floor(distance))
        return smoothTeleport(safeZone)
    end
    
    return true
end

-- IMPROVED coin container detection - searches deeper
local function findCoinContainer()
    -- First try direct children
    for _, obj in pairs(Workspace:GetChildren()) do
        local coinContainer = obj:FindFirstChild("CoinContainer")
        if coinContainer then
            return coinContainer
        end
    end
    
    -- If not found, search deeper (2 levels)
    for _, obj in pairs(Workspace:GetChildren()) do
        for _, child in pairs(obj:GetChildren()) do
            local coinContainer = child:FindFirstChild("CoinContainer")
            if coinContainer then
                return coinContainer
            end
        end
    end
    
    -- Last resort: recursive search but limited depth
    local function searchRecursive(parent, depth)
        if depth > 3 then return nil end
        
        for _, child in pairs(parent:GetChildren()) do
            if child.Name == "CoinContainer" then
                return child
            end
            
            local found = searchRecursive(child, depth + 1)
            if found then return found end
        end
        return nil
    end
    
    return searchRecursive(Workspace, 0)
end

-- Smart coin detection
local function getCoins()
    local coins = {}
    local coinContainer = findCoinContainer()
    
    if coinContainer then
        log("Found coin container with " .. #coinContainer:GetChildren() .. " children")
        for _, coin in pairs(coinContainer:GetChildren()) do
            if coin.Name == "Coin_Server" and coin:IsA("Part") then
                table.insert(coins, coin)
            end
        end
    else
        log("No coin container found")
    end
    
    log("Found " .. #coins .. " coins")
    return coins
end

-- FIXED game detection with better timing
local function waitForGameStart()
    local startTime = os.time()
    local maxWaitTime = 600
    
    log("Waiting for game to start...")
    
    while os.time() - startTime < maxWaitTime do
        -- Stay in safe zone during role selection
        ensureSafeZone()
        
        local coins = getCoins()
        if #coins > 0 then
            log("Coins detected, waiting 12 seconds for role selection to complete...")
            
            -- Wait for role selection with progress updates
            for i = 1, 12 do
                wait(1)
                log("Role selection: " .. i .. "/12 seconds")
                ensureSafeZone()
            end
            
            -- Double check coins still exist after role selection
            coins = getCoins()
            if #coins > 0 then
                log("Game confirmed started with " .. #coins .. " coins")
                return true
            else
                log("Coins disappeared after role selection wait")
            end
        end
        
        -- Check if we should rejoin due to timeout
        if os.time() - lastGameActivity > gameStartTimeout then
            log("No game activity for " .. gameStartTimeout .. " seconds")
            return false
        end
        
        wait(3)
    end
    
    log("Game start wait timeout after " .. maxWaitTime .. " seconds")
    return false
end

-- IMPROVED coin collection with better error handling
local function collectCoin(coin)
    if not coin or not coin.Parent then 
        failedCollections = failedCollections + 1
        log("Coin invalid or no parent")
        return false 
    end
    
    collectionAttempts = collectionAttempts + 1
    local startTime = os.time()
    local character = ensureCharacter()
    
    if not character then 
        failedCollections = failedCollections + 1
        log("No character for collection")
        return false 
    end
    
    -- Calculate collection position
    local collectPosition = coin.Position + Vector3.new(0, 3, 0)
    
    log("Attempting to collect coin at " .. tostring(coin.Position))
    
    -- Teleport to coin
    if not smoothTeleport(collectPosition) then
        failedCollections = failedCollections + 1
        log("Failed to teleport to coin")
        return false
    end
    
    -- Wait a moment and check if coin was collected
    wait(0.5)
    
    local collectionConfirmed = false
    if not coin.Parent then -- Coin collected
        collectionConfirmed = true
        log("Coin collection confirmed - coin removed")
    else
        -- Try one more time with different position
        local retryPosition = coin.Position + Vector3.new(2, 3, 0)
        smoothTeleport(retryPosition)
        wait(0.3)
        
        if not coin.Parent then
            collectionConfirmed = true
            log("Coin collected on retry")
        end
    end
    
    -- Always return to safe zone
    smoothTeleport(safeZone)
    
    -- Timing control
    local elapsed = os.time() - startTime
    local remainingTime = coinCollectionInterval - elapsed
    
    if remainingTime > 0 then
        wait(remainingTime)
    end
    
    if collectionConfirmed then
        lastSuccessfulCollection = os.time()
        log("Successfully collected coin " .. collectionAttempts)
        return true
    else
        failedCollections = failedCollections + 1
        log("Failed to collect coin - still exists")
        return false
    end
end

-- IMPROVED farming system with better state management
local function startSmartFarming()
    if farming then 
        log("Already farming")
        return 
    end
    
    farming = true
    log("Starting smart farming...")
    
    while farming and inGame do
        ensureSafeZone()
        
        local coins = getCoins()
        
        if #coins == 0 then
            log("No coins found, checking if game ended...")
            wait(5)
            coins = getCoins()
            
            if #coins == 0 then
                log("Game ended - no coins available")
                inGame = false
                break
            end
        end
        
        log("Starting collection cycle with " .. #coins .. " coins")
        
        -- Collect coins with error handling
        for _, coin in pairs(coins) do
            if not farming or not inGame then 
                log("Farming stopped during collection cycle")
                break 
            end
            
            if coin and coin.Parent then
                local success = pcall(function()
                    return collectCoin(coin)
                end)
                
                if not success then
                    log("Error collecting coin, continuing...")
                    wait(1)
                end
            else
                log("Coin invalid during collection loop")
            end
        end
        
        -- Small delay between cycles
        wait(1)
    end
    
    farming = false
    log("Farming stopped")
end

-- IMPROVED game state monitoring
local function monitorGameState()
    while true do
        ensureSafeZone()
        
        local coins = getCoins()
        local hasCoins = #coins > 0
        
        if hasCoins and not inGame then
            -- Game starting
            inGame = true
            lastGameActivity = os.time()
            failedCollections = 0
            collectionAttempts = 0
            
            log("Game state changed: INACTIVE -> ACTIVE with " .. #coins .. " coins")
            spawn(startSmartFarming)
            
        elseif not hasCoins and inGame then
            -- Game ending
            inGame = false
            farming = false
            
            log("Game state changed: ACTIVE -> INACTIVE")
            
            -- Wait in safe zone for next game
            ensureSafeZone()
        elseif hasCoins and inGame then
            -- Game still active, update timestamp
            lastGameActivity = os.time()
        end
        
        wait(5) -- Check game state every 5 seconds
    end
end

-- FIXED auto rejoin system
local function setupAutoRejoin()
    spawn(function()
        while true do
            wait(15) -- Check less frequently to reduce load
            
            -- Check if player is in game
            if not localPlayer or not localPlayer.Parent then
                log("Player not in game, attempting rejoin...")
                rejoinGame()
                wait(30)
                continue
            end
            
            -- Check for game timeout
            if os.time() - lastGameActivity > gameStartTimeout then
                log("Game timeout (" .. gameStartTimeout .. "s), rejoining...")
                rejoinGame()
                wait(30)
                continue
            end
            
            -- Check for too many failed collections
            if failedCollections > 15 and os.time() - lastSuccessfulCollection > 120 then
                log("Too many failed collections (" .. failedCollections .. "), rejoining...")
                rejoinGame()
                wait(30)
                continue
            end
        end
    end)
end

-- FIXED rejoin function
local function rejoinGame()
    if isRejoining then 
        log("Already rejoining...")
        return 
    end
    
    isRejoining = true
    farming = false
    inGame = false
    
    log("Starting rejoin process...")
    
    local success = pcall(function()
        TeleportService:Teleport(game.PlaceId, localPlayer)
    end)
    
    if not success then
        log("Teleport failed, trying again in 10 seconds...")
        wait(10)
        pcall(function()
            TeleportService:Teleport(game.PlaceId, localPlayer)
        end)
    end
    
    wait(30) -- Wait for rejoin to complete
    isRejoining = false
end

-- Health monitoring system
local function setupHealthMonitor()
    localPlayer.CharacterAdded:Connect(function(character)
        log("New character added")
        wait(3) -- Wait for character to fully load
        
        local humanoid = character:WaitForChild("Humanoid", 5)
        if humanoid then
            ensureSafeZone()
            
            humanoid.Died:Connect(function()
                log("Character died, waiting for respawn...")
                wait(5)
                ensureSafeZone()
                
                if inGame then
                    wait(2)
                    spawn(startSmartFarming)
                end
            end)
        end
    end)
end

-- Main initialization
local function initialize()
    log("Initializing ULTIMATE MM2 farming system...")
    log("Session ID: " .. sessionId)
    log("Safe zone: " .. tostring(safeZone))
    
    setupHealthMonitor()
    setupAutoRejoin()
    
    -- Wait for everything to load
    wait(5)
    
    -- Ensure we start in safe zone
    ensureSafeZone()
    
    -- Start monitoring systems
    spawn(monitorGameState)
    
    log("System fully initialized and ready!")
    log("Waiting for game to start...")
end

-- Start the system with error handling
local success, err = pcall(initialize)
if not success then
    log("Initialization error: " .. tostring(err))
    log("Attempting recovery...")
    wait(5)
    pcall(initialize)
end
