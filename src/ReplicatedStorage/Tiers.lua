local Tiers = {}

local SPUtil = require(game.ReplicatedStorage.Shared.SPUtil)

local TierRatingMap = {
    { name = "Prism", minRating = 58.5 },
    { name = "Ultraviolet", minRating = 49 },
    { name = "Emerald", minRating = 43 },
    { name = "Diamond", minRating = 32 },
    { name = "Gold", minRating = 24 },
    { name = "Silver", minRating = 14 },
    { name = "Bronze", minRating = 7 },
    { name = "Tin", minRating = 0 }
}

function Tiers:GetTierFromRating(rating)
    for i, tier in ipairs(TierRatingMap) do
        if rating >= tier.minRating or i == #TierRatingMap then
            if i ~= 1 then
                local nextTier = TierRatingMap[i - 1]

                for x = 2, 0, -1 do
                    local divisionBorder = SPUtil:lerp(tier.minRating, nextTier.minRating, x / 3)

                    if rating >= divisionBorder then
                        local nextDivisionBorder = if x == 2 then nextTier.minRating else SPUtil:lerp(tier.minRating, nextTier.minRating, (x + 1) / 3)
                        
                        for y = 3, 0, -1 do
                            local subdivisionBorder = SPUtil:lerp(divisionBorder, nextDivisionBorder, y / 4)

                            if rating >= subdivisionBorder then
                                return {
                                    name = tier.name,
                                    division = x + 1,
                                    subdivision = y + 1
                                }
                            end
                        end
                    end
                end
            else
                return {
                    name = tier.name
                }
            end
        end
    end
end

return Tiers
