local Roact = require(game.ReplicatedStorage.Packages.Roact)
local Flipper = require(game.ReplicatedStorage.Packages.Flipper)
local RoactFlipper = require(game.ReplicatedStorage.Packages.RoactFlipper)
local e = Roact.createElement

local withInjection = require(game.ReplicatedStorage.UI.Components.HOCs.withInjection)

local RoundedFrame = require(game.ReplicatedStorage.UI.Components.Base.RoundedFrame)
local RoundedTextButton = require(game.ReplicatedStorage.UI.Components.Base.RoundedTextButton)
local RoundedTextLabel = require(game.ReplicatedStorage.UI.Components.Base.RoundedTextLabel)
local RoundedImageLabel = require(game.ReplicatedStorage.UI.Components.Base.RoundedImageLabel)
local ButtonLayout = require(game.ReplicatedStorage.UI.Components.Base.ButtonLayout)

local Tier = require(game.ReplicatedStorage.UI.Components.Tier)
local Tiers = require(game.ReplicatedStorage.Tiers)

local RankSlot = Roact.Component:extend("RankSlot")

RankSlot.defaultProps = {
    Size = UDim2.fromScale(1, 1),
    Data = {
        TotalMapsPlayed = 0,
        Rating = 0,
        PlayerName = "Player1",
        UserId = 0,
        Accuracy = 0,
        Place = 1
    },
    OnBan = function() end,
    OnView = function() end
}

function RankSlot:init()
    self.moderationService = self.props.moderationService

    self.motor = Flipper.SingleMotor.new(0)
    self.motorBinding = RoactFlipper.getBinding(self.motor)

    self:setState({
        dialogOpen = false
    })
end

function RankSlot:didUpdate()
    self.motor:setGoal(Flipper.Spring.new(self.state.dialogOpen and 1 or 0, {
        dampingRatio = 2.5,
        frequency = 12
    }))
end

function RankSlot:render()
    local buttons = {
        {
            Text = "View Scores",
            Color = Color3.fromRGB(21, 148, 180),
            OnClick = function()
                self.props.OnView(self.props.Data.UserId)
            end
        },
        {
            Text = "Back",
            Color = Color3.fromRGB(37, 37, 37),
            OnClick = function()
                self:setState(function(state)
                    return {
                        dialogOpen = not state.dialogOpen
                    }
                end)
            end
        }
    }

    if self.props.IsAdmin then
        table.insert(buttons, 1, {
            Text = "Ban user",
            Color = Color3.fromRGB(240, 184, 0),
            OnClick = function()
                self.props.OnBan(self.props.Data.UserId, self.props.Data.PlayerName)
            end
        })
    end

    local tier = Tiers:GetTierFromRating(self.props.Data.Rating.Overall)

    return Roact.createElement(RoundedTextButton, {
        BackgroundColor3 = Color3.fromRGB(15, 15, 15),
        BorderMode = Enum.BorderMode.Inset,
        BorderSizePixel = 0,
        Size = self.props.Size,
        HoldSize = self.props.HoldSize,
        Text = "",
        LayoutOrder = self.props.Data.Place,
        OnRightClick = function()
            self:setState(function(state)
                return {
                    dialogOpen = not state.dialogOpen
                }
            end)
        end;
        OnLongPress = function()
            if self.props.IsAdmin then
                self:setState(function(state)
                    return {
                        dialogOpen = not state.dialogOpen
                    }
                end)
            end
        end
    }, {
        Dialog = e(ButtonLayout, {
            Size = UDim2.fromScale(1, 1),
            Position = self.motorBinding:map(function(a)
                return UDim2.fromScale(1, 0):Lerp(UDim2.fromScale(0, 0), a)
            end),
            Padding = UDim.new(0, 8),
            DefaultSpace = 2,
            MaxTextSize = 15,
            Visible = self.motorBinding:map(function(a)
                return a > 0
            end),
            Buttons = buttons
        }),
        UserThumbnail = Roact.createElement(RoundedImageLabel, {
            AnchorPoint = Vector2.new(0, 0.5),
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            Position = UDim2.new(0.07, 0, 0.5, 0),
            Size = UDim2.new(0.07, 0, 0.75, 0),
            Image = string.format("https://www.roblox.com/headshot-thumbnail/image?userid=%d&width=420&height=420&format=png", self.props.Data.UserId)
        }, {
            Roact.createElement("UIAspectRatioConstraint", {
                AspectType = Enum.AspectType.ScaleWithParentSize,
                DominantAxis = Enum.DominantAxis.Height,
            }),
            Data = Roact.createElement(RoundedTextLabel, {
                BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Position = UDim2.new(1.25, 0, 0.6, 0),
                Size = UDim2.new(8, 0, 0.35, 0),
                Font = Enum.Font.GothamSemibold,
                Text = string.format("Rating: <font color = \"rgb(211, 214, 2)\"><b>%0.2f</b></font> | Overall Accuracy: %0.2f%% | Total Maps Played: %d", self.props.Data.Rating.Overall, self.props.Data.Accuracy, self.props.Data.TotalMapsPlayed),
                RichText = true,
                TextColor3 = Color3.fromRGB(80, 80, 80),
                TextScaled = true,
                TextXAlignment = Enum.TextXAlignment.Left,
            }, {
                Roact.createElement("UITextSizeConstraint", {
                    MaxTextSize = 29,
                    MinTextSize = 3,
                })
            }),
            Player = Roact.createElement(RoundedTextLabel, {
                BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Position = UDim2.new(1.25, 0, 0, 0),
                Size = UDim2.new(15.3, 0, 0.55, 0),
                Font = Enum.Font.GothamSemibold,
                Text = self.props.Data.PlayerName,
                TextColor3 = Color3.fromRGB(94, 94, 94),
                TextScaled = true,
                TextXAlignment = Enum.TextXAlignment.Left,
            }, {
                Roact.createElement("UITextSizeConstraint", {
                    MaxTextSize = 49,
                })
            })
        }),

        Place = Roact.createElement(RoundedTextLabel, {
            BackgroundColor3 = Color3.fromRGB(54, 54, 54),
            BorderSizePixel = 0,
            Position = UDim2.fromScale(0.0087, 0.1),
            Size = UDim2.fromScale(0.05, 0.755),
            Font = Enum.Font.GothamBold,
            Text = string.format("#%d", self.props.Data.Place),
            TextColor3 = Color3.fromRGB(71, 71, 70),
            TextScaled = true,
            BackgroundTransparency = 1;
        }, {
            Roact.createElement("UITextSizeConstraint", {
                MaxTextSize = 25,
                MinTextSize = 7,
            }),
        }),
        Tier = Roact.createElement(Tier, {
            imageLabelProps = {
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.fromScale(0.97, 0.5),
                Size = UDim2.fromScale(0.1, 0.7),
                BackgroundTransparency = 1
            },
            tier = tier.name,
            division = tier.division
        }, {
            TierName = Roact.createElement(RoundedTextLabel, {
                Position = UDim2.fromScale(-0.3, 0.5),
                Size = UDim2.fromScale(5.2, 0.9),
                AnchorPoint = Vector2.new(1, 0.5),
                Text = tier.name .. if tier.division then " " .. string.rep("I", tier.division) .. if tier.subdivision then "  " .. string.rep("🔲 ", tier.subdivision) .. string.rep("◼️ ", 4 - tier.subdivision) else "" else "",
                TextColor3 = Color3.fromRGB(153, 153, 153),
                TextXAlignment = Enum.TextXAlignment.Right,
                TextScaled = true,
                BackgroundTransparency = 1;
            }, {
                Roact.createElement("UITextSizeConstraint", {
                    MaxTextSize = 20,
                    MinTextSize = 7,
                }),
            }),
        }),
        UIAspectRatioConstraint = Roact.createElement("UIAspectRatioConstraint", {
            AspectRatio = 14,
            AspectType = Enum.AspectType.ScaleWithParentSize,
        })
    })
end

return withInjection(RankSlot, {
    moderationService = "ModerationService",
    tierService = "TierService"
})