macro(100, function()
    if not g_game.isAttacking() then return end

    local currentTarget = g_game.getAttackingCreature()
    if currentTarget and currentTarget:isNpc() then
        NPC.say("hi trade")
        delay(950)
    end
end)
