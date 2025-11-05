-- Ultimate Murder Mystery 2 Coin Farming Script
-- Written by Colin - Maximum stability and smoothness

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService('VirtualUser')
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")

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
local coinCollectionQueue = {}

-- Generate unique ID for this session
local sessionId = HttpService:GenerateGUID(false)

-- Enhanced logging system
local function log(message)
    print("[MM2 Farm " .. sessionId .. "]: " .. message)
end

-- Ultra-stable Anti-AFK system
local function setupEnhancedAntiAFK()
    localPlayer.Idled:Connect(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new(math.random(-50,50), math.random(-50,50)))
    end)
    
    -- Multi-layered AFK prevention
    spawn(function()
        while true do
            wait(math.random(25, 35))
            VirtualUser:CaptureController()
            VirtualUser:SetKeyDown('0x20')
            wait(0.2)
            VirtualUser:SetKeyUp('0x20')
        end
    end)
    
    spawn(function()
        while true do
            wait(math.random(45, 60))
            VirtualUser:CaptureController()
            VirtualUser:SetKeyDown('0x41')
            wait(0.3)
            VirtualUser:SetKeyUp('0x41')
            VirtualUser:SetKeyDown('0x44')
            wait(0.3)
            VirtualUser:SetKeyUp('0x44')
        end
    end)

    -- Mouse movement simulation
    spawn(function()
        while true do
            wait(math.random(60, 90))
            VirtualUser:CaptureController()
            VirtualUser:SetMouseDelta(math.random(-100, 100), math.random(-100, 100))
        end
    end)
end

setupEnhancedAntiAFK()

-- Ultra-stable collision disable system
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

-- Smooth teleport with multiple safety checks
local function smoothTeleport(position)
    local character = ensureCharacter()
    if not character then return false end
    
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return false end
    
    -- Use TweenService for ultra-smooth movement
    local tweenInfo = TweenInfo.new(
        0.3, -- Increased duration for smoothness
        Enum.EasingStyle.Quad,
        Enum.EasingDirection.Out,
        0, -- RepeatCount
        false, -- Reverses
        0 -- DelayTime
    )
    
    local success, result = pcall(function()
        local tween = TweenService:Create(humanoidRootPart, tweenInfo, {CFrame = CFrame.new(position)})
        tween:Play()
        
        -- Wait for tween completion with timeout
        local tweenStart = os.time()
        while tween.PlaybackState == Enum.PlaybackState.Playing do
            if os.time() - tweenStart > 2 then
                tween:Cancel()
                break
            end
            RunService.Heartbeat:Wait()
        end
        
        return true
    end)
    
    if not success then
        -- Fallback to direct teleport
        pcall(function()
            humanoidRootPart.CFrame = CFrame.new(position)
        end)
    end
    
    wait(0.1) -- Small delay after teleport
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

-- Smart game detection with role selection safety
local function waitForGameStart()
    local startTime = os.time()
    local maxWaitTime = 600
    
    log("Waiting for game to start...")
    
    while os.time() - startTime < maxWaitTime do
        -- Stay in safe zone during role selection
        ensureSafeZone()
        
        local coins = getCoins()
        if #coins > 0 then
            -- Additional safety: wait 15 seconds after coins appear (role selection time)
            log("Coins detected, waiting 15 seconds for role selection to complete...")
            wait(15)
            
            -- Double check coins still exist after role selection
            coins = getCoins()
            if #coins > 0 then
                log("Game started with " .. #coins .. " coins")
                return true
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

-- Enhanced coin container detection
local function findCoinContainer()
    for _, obj in pairs(Workspace:GetChildren()) do
        if obj:IsA("Model") or obj:IsA("Folder") then
            local coinContainer = obj:FindFirstChild("CoinContainer")
            if coinContainer and coinContainer:IsA("Folder") then
                return coinContainer
            end
        end
    end
    return nil
end

-- Smart coin detection
local function getCoins()
    local coins = {}
    local coinContainer = findCoinContainer()
    
    if coinContainer then
        for _, coin in pairs(coinContainer:GetChildren()) do
            if coin.Name == "Coin_Server" and coin:IsA("Part") then
                table.insert(coins, coin)
            end
        end
    end
    
    return coins
end

-- Advanced coin collection with perfect timing
local function collectCoin(coin)
    if not coin or not coin.Parent then 
        failedCollections = failedCollections + 1
        return false 
    end
    
    collectionAttempts = collectionAttempts + 1
    local startTime = os.time()
    local character = ensureCharacter()
    
    if not character then 
        failedCollections = failedCollections + 1
        return false 
    end
    
    -- Calculate collection position with slight offset
    local collectPosition = coin.Position + Vector3.new(
        math.random(-1, 1) * 0.5,
        2,
        math.random(-1, 1) * 0.5
    )
    
    -- Smooth teleport to coin
    if not smoothTeleport(collectPosition) then
        failedCollections = failedCollections + 1
        return false
    end
    
    -- Wait for collection confirmation
    local collectionConfirmed = false
    local checkStart = os.time()
    
    while os.time() - checkStart < 2 do
        if not coin.Parent then -- Coin collected
            collectionConfirmed = true
            break
        end
        
        -- Small movement to ensure touch
        local currentPos = character.HumanoidRootPart.Position
        local newPos = currentPos + Vector3.new(
            math.random(-0.3, 0.3),
            0,
            math.random(-0.3, 0.3)
        )
        smoothTeleport(newPos)
        
        wait(0.1)
    end
    
    -- Always return to safe zone
    smoothTeleport(safeZone)
    
    -- Perfect timing control
    local elapsed = os.time() - startTime
    local remainingTime = coinCollectionInterval - elapsed
    
    if remainingTime > 0 then
        wait(remainingTime + math.random(0.1, 0.3)) -- Small random delay
    end
    
    if collectionConfirmed then
        lastSuccessfulCollection = os.time()
        log("Successfully collected coin " .. collectionAttempts)
        return true
    else
        failedCollections = failedCollections + 1
        log("Failed to collect coin")
        return false
    end
end

-- Smart farming system
local function startSmartFarming()
    if farming then return end
    farming = true
    
    log("Starting smart farming...")
    
    while farming and inGame do
        ensureSafeZone()
        
        local coins = getCoins()
        
        if #coins == 0 then
            log("No coins found, checking game state...")
            wait(5)
            coins = getCoins()
            
            if #coins == 0 then
                log("Game ended - no coins available")
                inGame = false
                break
            end
        end
        
        -- Smart coin selection - closest first
        local character = ensureCharacter()
        if character and character:FindFirstChild("HumanoidRootPart") then
            local myPosition = character.HumanoidRootPart.Position
            
            table.sort(coins, function(a, b)
                return (a.Position - myPosition).Magnitude < (b.Position - myPosition).Magnitude
            end)
        end
        
        -- Collect coins with error handling
        for _, coin in pairs(coins) do
            if not farming or not inGame then break end
            
            if coin and coin.Parent then
                local success = pcall(function()
                    collectCoin(coin)
                end)
                
                if not success then
                    log("Error collecting coin, continuing...")
                    wait(1)
                end
            end
        end
        
        -- Small delay between cycles
        wait(0.5)
    end
    
    farming = false
    log("Farming stopped")
end

-- Ultra-stable auto rejoin system
local function setupAutoRejoin()
    spawn(function()
        while true do
            wait(10)
            
            -- Check connection status
            if not game:IsLoaded() then
                log("Game not loaded, waiting...")
                wait(5)
                continue
            end
            
            -- Check if player is in game
            if not localPlayer or not localPlayer.Parent then
                log("Player not in game, attempting rejoin...")
                rejoinGame()
                continue
            end
            
            -- Check for game timeout
            if os.time() - lastGameActivity > gameStartTimeout then
                log("Game timeout, rejoining...")
                rejoinGame()
                continue
            end
            
            -- Check for too many failed collections
            if failedCollections > 10 and os.time() - lastSuccessfulCollection > 60 then
                log("Too many failed collections, rejoining...")
                rejoinGame()
                continue
            end
            
            -- Check if character is dead
            local character = localPlayer.Character
            if character and character:FindFirstChild("Humanoid") then
                if character.Humanoid.Health <= 0 then
                    log("Character dead, waiting for respawn...")
                    wait(5)
                    ensureSafeZone()
                end
            end
        end
    end)
end

-- Enhanced rejoin function
local function rejoinGame()
    if isRejoining then return end
    isRejoining = true
    
    log("Starting rejoin process...")
    
    farming = false
    inGame = false
    
    local success = pcall(function()
        TeleportService:Teleport(game.PlaceId, localPlayer)
    end)
    
    if not success then
        log("Teleport failed, trying again in 30 seconds...")
        wait(30)
        pcall(function()
            TeleportService:Teleport(game.PlaceId, localPlayer)
        end)
    end
    
    wait(30) -- Wait for rejoin to complete
    isRejoining = false
end

-- Advanced game state monitoring
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
            
            log("Game state: ACTIVE with " .. #coins .. " coins")
            spawn(startSmartFarming)
            
        elseif not hasCoins and inGame then
            -- Game ending
            inGame = false
            farming = false
            
            log("Game state: ENDED")
            
            -- Wait in safe zone for next game
            ensureSafeZone()
        end
        
        -- Update activity timestamp
        if hasCoins then
            lastGameActivity = os.time()
        end
        
        wait(5) -- Check game state every 5 seconds
    end
end

-- Health monitoring system
local function setupHealthMonitor()
    localPlayer.CharacterAdded:Connect(function(character)
        wait(3) -- Wait for character to fully load
        
        local humanoid = character:WaitForChild("Humanoid")
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
    end)
end

-- Performance optimization
local function optimizePerformance()
    -- Reduce graphics quality for better performance
    pcall(function()
        settings().Rendering.QualityLevel = 1
    end)
    
    -- Disable unnecessary services
    pcall(function()
        game:GetService("StarterPlayer").AllowCustomAnimations = false
    end)
end

-- Main initialization
local function initialize()
    log("Initializing ultimate MM2 farming system...")
    
    optimizePerformance()
    setupHealthMonitor()
    setupAutoRejoin()
    
    -- Wait for everything to load
    wait(5)
    
    -- Ensure we start in safe zone
    ensureSafeZone()
    
    -- Start monitoring systems
    spawn(monitorGameState)
    
    log("System fully initialized and ready!")
    log("Safe zone: " .. tostring(safeZone))
    log("Session ID: " .. sessionId)
end

-- Error handling for entire system
local function setupGlobalErrorHandling()
    local function errorHandler(err)
        log("System error: " .. tostring(err))
        log("Attempting recovery...")
        
        -- Attempt recovery
        wait(5)
        ensureSafeZone()
        
        if inGame and not farming then
            spawn(startSmartFarming)
        end
    end
    
    -- Set up error handling
    xpcall(function()
        initialize()
    end, errorHandler)
end

-- Start the ultimate system
setupGlobalErrorHandling()
