local Roact = require(game.ReplicatedStorage.Packages.Roact)
local RoactRodux = require(game.ReplicatedStorage.Packages.RoactRodux)
local Llama = require(game.ReplicatedStorage.Packages.Llama)
local e = Roact.createElement
local f = Roact.createFragment

local SPUtil = require(game.ReplicatedStorage.Shared.SPUtil)
local CurveUtil = require(game.ReplicatedStorage.Shared.CurveUtil)
local RobeatsGame = require(game.ReplicatedStorage.RobeatsGameCore.RobeatsGame)
local EnvironmentSetup = require(game.ReplicatedStorage.RobeatsGameCore.EnvironmentSetup)
local GameSlot = require(game.ReplicatedStorage.RobeatsGameCore.Enums.GameSlot)
local Rating = require(game.ReplicatedStorage.RobeatsGameCore.Enums.Rating)
local SongDatabase = require(game.ReplicatedStorage.RobeatsGameCore.SongDatabase)
local DebugOut = require(game.ReplicatedStorage.Shared.DebugOut)
local NoteResult= require(game.ReplicatedStorage.RobeatsGameCore.Enums.NoteResult)
local FlashEvery = require(game.ReplicatedStorage.Shared.FlashEvery)
local InputUtil = require(game.ReplicatedStorage.Shared.InputUtil)

local Leaderboard = require(script.Leaderboard)
local MultiplayerLeaderboard = require(script.MultiplayerLeaderboard)
local StatCard = require(script.StatCard)
local Divider = require(script.Divider)
local Loading = require(script.OtherLoading)

local AnimatedNumberLabel = require(game.ReplicatedStorage.UI.Components.Base.AnimatedNumberLabel)
local RoundedTextLabel = require(game.ReplicatedStorage.UI.Components.Base.RoundedTextLabel)
local RoundedFrame = require(game.ReplicatedStorage.UI.Components.Base.RoundedFrame)
local RoundedTextButton = require(game.ReplicatedStorage.UI.Components.Base.RoundedTextButton)

local ComboPositions = require(game.ReplicatedStorage.ComboPositions)
local LeaderboardPositions = require(game.ReplicatedStorage.LeaderboardPositions)

local withHitDeviancePoint = require(script.Decorators.withHitDeviancePoint)

local Trove = require(game.ReplicatedStorage.Packages.Trove)

local withInjection = require(game.ReplicatedStorage.UI.Components.HOCs.withInjection)

local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")

local Gameplay = Roact.Component:extend("Gameplay")

Gameplay.SpreadString = "<font color=\"rgb(125, 125, 125)\">%d</font> <font color=\"rgb(55, 55, 55)\">/</font> <font color=\"rgb(99, 91, 15)\">%d</font> <font color=\"rgb(55, 55, 55)\">/</font> <font color=\"rgb(23, 99, 15)\">%d</font> <font color=\"rgb(55, 55, 55)\">/</font> <font color=\"rgb(15, 39, 99)\">%d</font> <font color=\"rgb(55, 55, 55)\">/</font> <font color=\"rgb(91, 15, 99)\">%d</font> <font color=\"rgb(55, 55, 55)\">/</font> <font color=\"rgb(99, 15, 21)\">%d</font> | %0.1f M/P"

function Gameplay:init()
    self.trove = Trove.new()

    -- Set gameplay state
    
    self:setState({
        accuracy = 0,
        score = 0,
        chain = 0,
        maxChain = 0,
        marvelouses = 0,
        perfects = 0,
        greats = 0,
        goods = 0,
        bads = 0,
        misses = 0,
        loaded = false,
        dividerPresses = { false, false, false, false },
        isMobile = UserInputService.TouchEnabled,
        secondsLeft = 10
    })
    
    -- Set up time left bib
    
    self.timeLeft, self.setTimeLeft = Roact.createBinding(0)

    self.kps, self.setKps = Roact.createBinding(0)
    
    -- Set up hit deviance parent reference
    
    self.hitDevianceRef = Roact.createRef()
    
    if not self.props.options.Use2DLane then
        local stagePlat = EnvironmentSetup:get_element_protos_folder().NoteTrackSystemProto.TrackBG.Union
        stagePlat.Transparency = self.props.options.BaseTransparency
    end

    --Is the player on mobile
    self.numLanes = 4

    -- Set FOV and Time of Day
    
    workspace.CurrentCamera.FieldOfView = self.props.options.FOV
    Lighting.TimeOfDay = self.props.options.TimeOfDay
    
    -- Turn PlayerList & Chat off
    game.StarterGui:SetCoreGuiEnabled("PlayerList", not self.props.options.HidePlayerList)
    game.StarterGui:SetCoreGuiEnabled("Chat", not self.props.options.HideChat)

    EnvironmentSetup:set_gui_inset(true);
    
    -- 2D Properties
    local lane_2d = self.props.options.Use2DLane
    
    -- Create the game instance
    
    local _game = RobeatsGame:new(EnvironmentSetup:get_game_environment_center_position())
    _game._input:set_keybinds({
        self.props.options.Keybind1,
        self.props.options.Keybind2,
        self.props.options.Keybind3,
        self.props.options.Keybind4
    })
    _game:set_hit_lighting(self.props.options.HitLighting)
    _game:set_ln_tails(self.props.options.HideLNTails)
    _game:set_judgement_visibility(self.props.options.JudgementVisibility)
    _game:set_note_color(self.props.options.NoteColor)
    _game:set_ln_transparent(self.props.options.TransparentHeldNote)
    _game:set_2d_mode(lane_2d)
    if lane_2d then
        _game:set_upscroll_mode(self.props.options.Upscroll);
    end
    
    -- Load the map

    self.songKey = if self.props.room then self.props.room.selectedSongKey else self.props.options.SongKey
    self.songRate = if self.props.room then self.props.room.songRate else self.props.options.SongRate

    _game:load(self.songKey, GameSlot.SLOT_1, Llama.Dictionary.join(self.props.options, {
        SongRate = self.songRate
    }))

    -- Bind the game loop to every frame

    self.onMultiplayerGameEnded = Instance.new("BindableEvent")

    local hits = {}

    self.onKeybindPressedConnection = _game.keybind_pressed.Event:Connect(function()
        table.insert(hits, tick())
    end)

    local _send_every = FlashEvery:new(0.5)
    local _update_text = FlashEvery:new(1)

    self.everyFrameConnection = SPUtil:bind_to_frame(function(dt)
        if _game._audio_manager:get_just_finished() then
            _game:set_mode(RobeatsGame.Mode.GameEnded)
        end
        
        -- Handle starting the game if the audio and its data has loaded!

        if not self.state.loaded and _game._audio_manager:is_ready_to_play() and self:allPlayersLoaded() then
            if self.props.room then
                self.props.multiplayerService:SetLoaded(self.props.roomId, true)
            end
            
            self:setState({
                loaded = true
            })
            
            _game:start_game()
        end

        -- If we have reached the end of the game, trigger cleanup
        
        if _game:get_mode() == RobeatsGame.Mode.GameEnded then
            self.everyFrameConnection:Disconnect()
            self:onGameplayEnd()
            return
        end
        
        local dt_scale = CurveUtil:DeltaTimeToTimescale(dt)
        _game:update(dt_scale)
        
        _update_text:update(dt_scale)
        _send_every:update(dt_scale)

        if not self.state.loaded and _update_text:do_flash() then
            self:setState(function(state)
                return {
                    secondsLeft = state.secondsLeft - 1
                }
            end)

            if self.state.secondsLeft <= 0 then
                if self.props.room then
                    self.props.multiplayerService:SetLoaded(self.props.roomId, true)
                end

                self:setState({
                    loaded = true
                })
                
                _game:start_game()
            end
        end

        local i = 1
        while i <= #hits do
            if tick() - hits[i] > 1 then
                table.remove(hits, i)
            else
                i = i + 1
            end
        end

        self.setKps(#hits)

        -- Every second, send match stats to the server

        if self.props.room and _send_every:do_flash() then
            self.props.multiplayerService:SetMatchStats(self.props.roomId, {
                score = self.state.score,
                rating = Rating:get_rating_from_song_key(self.songKey, self.state.accuracy, self.songRate / 100).Overall,
                accuracy = self.state.accuracy,
                marvelouses = self.state.marvelouses,
                perfects = self.state.perfects,
                greats = self.state.greats,
                goods = self.state.goods,
                bads = self.state.bads,
                misses = self.state.misses,
                maxChain = self.state.maxChain,
            })
        end

        -- If the match no longer exists, quit the game

        if not self.props.room and self.props.roomId then
            _game:set_mode(RobeatsGame.Mode.GameEnded)
        end

        self.setTimeLeft(_game._audio_manager:get_song_length_ms() - _game._audio_manager:get_current_time_ms())
    end)

    -- Hook into onStatsChanged to monitor when stats change in ScoreManager

    self.onStatsChangedConnection = _game._score_manager:get_on_change():Connect(function(...)
        local args = {...}

        local hit = args[10]

        if hit then
            local bar = Instance.new("Frame")
            bar.AnchorPoint = Vector2.new(0.5, 0)
            bar.Position = UDim2.fromScale(SPUtil:inverse_lerp(150, -150, hit.time_left), 0)
            bar.Size = UDim2.fromScale(0.005, 1)
            bar.BorderSizePixel = 0
            bar.ZIndex = 20
            bar.BackgroundTransparency = 1
            bar.BackgroundColor3 = NoteResult:result_to_color(hit.judgement)

            bar.Parent = self.hitDevianceRef:getValue()

            withHitDeviancePoint(bar)
        end

        self:setState({
            score = _game._score_manager:get_score(),
            accuracy = _game._score_manager:get_accuracy() * 100,
            chain = _game._score_manager:get_chain(),
            maxChain = args[7],
            marvelouses = args[1],
            perfects = args[2],
            greats = args[3],
            goods = args[4],
            bads = args[5],
            misses = args[6]
        })
    end)

    self.trove:Connect(UserInputService.LastInputTypeChanged, function(inputType)
        if inputType == Enum.UserInputType.Touch and not self.state.isMobile then
            self:setState({
                isMobile = true
            })
        elseif inputType == Enum.UserInputType.Keyboard or inputType == Enum.UserInputType.MouseMovement or inputType == Enum.UserInputType.MouseButton1 or inputType == Enum.UserInputType.MouseButton2 and self.state.isMobile then
            self:setState({
                isMobile = false
            })
        end
    end)

    -- Expose the game instance to the rest of the component

    self._game = _game
end

function Gameplay:didMount()
    local _input = self._game._input

    self.trove:Construct(function()
        return _input.InputBegan.Event:Connect(function(keycode)
            local track

            if InputUtil.KEYCODE_TOUCH_TRACK1 == keycode then
                track = 1
            elseif InputUtil.KEYCODE_TOUCH_TRACK2 == keycode then
                track = 2
            elseif InputUtil.KEYCODE_TOUCH_TRACK3 == keycode then
                track = 3
            elseif InputUtil.KEYCODE_TOUCH_TRACK4 == keycode then
                track = 4
            end

            if track then
                self:setState({
                    dividerPresses = Llama.List.set(self.state.dividerPresses, track, true)
                })
            end
        end)
    end)

    self.trove:Construct(function()
        return _input.InputEnded.Event:Connect(function(keycode)
            local track

            if InputUtil.KEYCODE_TOUCH_TRACK1 == keycode then
                track = 1
            elseif InputUtil.KEYCODE_TOUCH_TRACK2 == keycode then
                track = 2
            elseif InputUtil.KEYCODE_TOUCH_TRACK3 == keycode then
                track = 3
            elseif InputUtil.KEYCODE_TOUCH_TRACK4 == keycode then
                track = 4
            end

            if track then
                self:setState({
                    dividerPresses = Llama.List.set(self.state.dividerPresses, track, false)
                })
            end
        end)
    end)
end

function Gameplay:didUpdate()
    if self.props.room and not self.props.room.inProgress then
        self.onMultiplayerGameEnded:Fire()
    end
end

function Gameplay:onGameplayEnd()
    if self.props.options.Use2DLane then
        EnvironmentSetup:teardown_2d_environment()
    end

    local records = self._game._score_manager:get_end_records()

    local hits = self._game._score_manager:get_hits()
    local mean = self._game._score_manager:get_mean()
    local rating = Rating:get_rating_from_song_key(self.songKey, self.state.accuracy, self.songRate / 100)

    local finalRecords = Llama.Dictionary.join(records, {
        Mean = mean,
        Rating = rating,
        Mods = self.props.options.Mods,
        SongMD5Hash = SongDatabase:get_hash_for_key(self.songKey),
        Rate = self.songRate
    })

    if (not self.forcedQuit) and (self.props.options.TimingPreset == "Standard") then
        self:submitScore(finalRecords, hits)
    end
    
    local resultsRecords = Llama.Dictionary.join(finalRecords, {
        Hits = hits,
        SongKey = self.songKey,
        PlayerName = game.Players.LocalPlayer.Name,
        TimePlayed = DateTime.now().UnixTimestamp,
        Match = self.props.room,
        RoomId = self.props.roomId
    })

    if self.forcedQuit and self.props.room then
        self.props.multiplayerService:LeaveRoom(self.props.roomId):andThen(function()
            self.props.history:push("/multiplayer", {
                goToHome = true
            })
        end)
    elseif self.props.room then
        local multiRecords = {}

        for k, v in pairs(finalRecords) do
            local firstCharacter = string.sub(k, 1, 1):lower()
            local newKey = firstCharacter .. string.sub(k, 2, k:len())

            multiRecords[newKey] = v
        end

        self.props.multiplayerService:SetMatchStats(self.props.roomId, multiRecords)
            :andThen(function()
                self.props.multiplayerService:SetFinished(self.props.roomId, true)

                task.spawn(function()
                    self.onMultiplayerGameEnded.Event:Wait()
                    self.props.history:push("/results", resultsRecords)
                end)
            end)
    else
        self.props.history:push("/results", resultsRecords)
    end
end

function Gameplay:allPlayersLoaded()
    return self.props.room and #Llama.Dictionary.filter(self.props.room.players, function(player)
        return not player.loaded
    end) == 0 or true
end

function Gameplay:submitScore(records, hits)
    self.props.scoreService:SubmitScore(records)
        :andThen(function()
            local moment = DateTime.now():ToLocalTime()
            DebugOut:puts("Score submitted at %d:%d:%d", moment.Hour, moment.Minute, moment.Second)
        end)
        :andThen(function()
            self.props.scoreService:SubmitGraph(records.SongMD5Hash, hits)
        end)
end

function Gameplay:render()
    if not self.state.loaded then
        return e(Loading, {
            SecondsLeft = self.state.secondsLeft,
            OnBack = function()
                self.forcedQuit = true
                self._game:set_mode(RobeatsGame.Mode.GameEnded)
            end,
            OnSkipClicked = function()
                self.state.secondsLeft = -1 -- the condition inside the init method checks for the seconds left, not loaded
            end
        })
    end

    local laneCoverY
    local laneCoverPosY
    local laneCoverRotation

    if self.props.options.LaneCover > 0 then
        laneCoverY = SPUtil:lerp(0.32, 0.8, self.props.options.LaneCover / 100)

        if self.props.options.Use2DLane and self.props.options.Upscroll then
            laneCoverPosY = 0.6
            laneCoverRotation = 180
        else
            laneCoverPosY = 0
            laneCoverRotation = 0
        end
    else
        laneCoverY = 0
        laneCoverPosY = 0
        laneCoverRotation = 0
    end

    local leaderboard

    if not self.props.options.HideLeaderboard then
        if self.props.room then
            leaderboard = e(MultiplayerLeaderboard, {
                Scores = self.props.room.players,
                Position = LeaderboardPositions[self.props.options.InGameLeaderboardPosition]
            })
        else
            leaderboard = e(Leaderboard, {
                SongKey = self.songKey,
                LocalRating = Rating:get_rating_from_song_key(self.songKey, self.state.accuracy, self.props.options.SongRate / 100).Overall,
                LocalAccuracy = self.state.accuracy, 
                Position = LeaderboardPositions[self.props.options.InGameLeaderboardPosition]
            })
        end
    end

    local statCardPosition = UDim2.fromScale(0.7, 0.2)

    if self.props.options.Use2DLane then
        statCardPosition =  UDim2.fromScale((self.props.options.PlayfieldWidth / 100 / 2) + 0.53, 0.2)
    end
    
    local sections = {}

    if self.state.isMobile and self.props.options.DividersEnabled then
        for i = 0, self.numLanes - 1 do
            local el = e(Divider, {
                Lane = i,
                LaneCount = self.numLanes,
                Pressed = self.state.dividerPresses[i + 1]
            })

            table.insert(sections, el)
        end
    end

    local songProgress

    if self.props.options.ShowProgressBar then
        songProgress = e(RoundedFrame, {
            Size = self.timeLeft:map(function(val)
                return UDim2.fromScale((self._game._audio_manager:get_song_length_ms() - val) / self._game._audio_manager:get_song_length_ms(), 0.0125) + UDim2.fromOffset(5, 0)
            end),
            Position = UDim2.fromScale(0, 1) - UDim2.fromOffset(5, 0),
            AnchorPoint = Vector2.new(0, 1),
            BackgroundColor3 = self.props.options.ProgressBarColor,
            BackgroundTransparency = 0
        })
    end

    return Roact.createFragment({
        Score = e(AnimatedNumberLabel, {
            Size = UDim2.fromScale(0.2, 0.12),
            TextColor3 = Color3.fromRGB(240, 240, 240),
            Position = UDim2.fromScale(0.98, 0),
            TextXAlignment = Enum.TextXAlignment.Right,
            AnchorPoint = Vector2.new(1, 0),
            BackgroundTransparency = 1,
            Value = self.state.score,
            FormatValue = function(a)
                return string.format("%07d", a)
            end,
            TextScaled = true
        }, {
            UITextSizeConstraint = Roact.createElement("UITextSizeConstraint", {
                MaxTextSize = 40
            })
        }),
        StatCard = e(StatCard, {
            Position = statCardPosition,
            Marvelouses = self.state.marvelouses,
            Perfects = self.state.perfects,
            Greats = self.state.greats,
            Goods = self.state.goods,
            Bads = self.state.bads,
            Misses = self.state.misses,
            Accuracy = self.state.accuracy
        }),
        TimeLeft = e(RoundedTextLabel, {
            Size = UDim2.fromScale(0.115, 0.035),
            TextXAlignment = Enum.TextXAlignment.Left,
            TextColor3 = Color3.fromRGB(255, 255, 255),
            Position = UDim2.fromScale(0.02, 0.98),
            AnchorPoint = Vector2.new(0, 1),
            BackgroundTransparency = 1,
            TextScaled = true,
            Text = self.timeLeft:map(function(a)
                return SPUtil:format_ms_time(math.clamp(a, 0, math.huge))
            end)
        }),
        KPS = e(RoundedTextLabel, {
            Size = UDim2.fromScale(0.115, 0.035),
            TextXAlignment = Enum.TextXAlignment.Right,
            TextColor3 = Color3.fromRGB(255, 255, 255),
            Position = UDim2.fromScale(0.98, 0.94),
            AnchorPoint = Vector2.new(1, 1),
            BackgroundTransparency = 1,
            TextScaled = true,
            Text = self.kps:map(function(a)
                return "KPS: " .. a
            end)
        }),
        Combo = e(RoundedTextLabel, {
            Size = UDim2.fromScale(0.13, 0.07),
            TextColor3 = Color3.fromRGB(255, 255, 255),
            Position = ComboPositions[self.props.options.ComboPosition],
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundTransparency = 1,
            TextScaled = true,
            Text = "x"..self.state.chain,
            ZIndex = 2
        }),
        Back = e(RoundedTextButton, {
            Size = UDim2.fromScale(0.1, 0.05),
            HoldSize = UDim2.fromScale(0.08, 0.05),
            TextColor3 = Color3.fromRGB(255, 255, 255),
            BackgroundColor3 = Color3.fromRGB(230, 19, 19),
            HighlightBackgroundColor3 = Color3.fromRGB(187, 53, 53),
            Position = UDim2.fromScale(0.02, 0.09),
            Text = "Back (No save)",
            TextSize = 11,
            OnClick = function()
                self.forcedQuit = true
                self._game:set_mode(RobeatsGame.Mode.GameEnded)
            end
        }),
        Leaderboard = leaderboard,
        Sections = f(sections),
        HitDeviance = e(RoundedFrame, {
           Position = self.props.options.Use2DLane and UDim2.fromScale(0.5, 0.635) or UDim2.fromScale(0.5, 0.95),
           Size = self.props.options.Use2DLane and UDim2.fromScale(0.15, 0.014) or UDim2.fromScale(0.15, 0.05),
           BackgroundTransparency = self.props.options.Use2DLane and 1,
           AnchorPoint = Vector2.new(0.5, 1),
           ZIndex = 5, -- This needed to overlap the 2D Lane's ZIndex
           [Roact.Ref] = self.hitDevianceRef
        }),
        LaneCover = e(RoundedFrame, {
            Size = UDim2.fromScale(1, laneCoverY),
            Position = UDim2.fromScale(0, laneCoverPosY),
            ZIndex = 0,
            Rotation = laneCoverRotation or 0,
            BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        }, {
            UIGradient = e("UIGradient", {
                Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 0),
                    NumberSequenceKeypoint.new(0.87, 0),
                    NumberSequenceKeypoint.new(0.93, 0.85),
                    NumberSequenceKeypoint.new(1, 1),
                }),
                Rotation = 90
            })
        }),
        SongProgress = songProgress,
        TimingPreset = e(RoundedTextLabel, {
            Size = UDim2.fromScale(0.2, 0.055),
            Position = UDim2.new(1, -5, 1, -10),
            AnchorPoint = Vector2.new(1, 1),
            Text = "Timing Preset: " .. self.props.options.TimingPreset,
            TextColor3 = Color3.new(1, 1, 1),
            BackgroundTransparency = 1,
        })
    })
end

function Gameplay:willUnmount()
    EnvironmentSetup:set_gui_inset(false);
    self._game:teardown()
    self.onKeybindPressedConnection:Disconnect()
    self.everyFrameConnection:Disconnect()
    self.onMultiplayerGameEnded:Destroy()

    self.trove:Destroy()
end

local Injected = withInjection(Gameplay, {
    scoreService = "ScoreService",
    multiplayerService = "MultiplayerService"
})

return RoactRodux.connect(function(state, props)
    local roomId = props.location.state.roomId

    return {
        options = Llama.Dictionary.join(state.options.persistent, state.options.transient),
        room = if roomId then state.multiplayer.rooms[roomId] else nil,
        roomId = roomId
    }
end)(Injected)