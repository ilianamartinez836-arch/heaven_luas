local function get_team_prefix(player)
    if not player then return "(Unknown) " end

    local team = player:get_team()
    if team == 3 then return "(Infected) "
    elseif team == 2 then return "(Survivor) "
    elseif team == 1 then return "(Spectator) "
    else return "(Unknown) " end
end

local function get_curtime()
    return client.get_tick_count() * client.get_frame_time()
end

local phrases = {
    kill = {
       hentai = {          "S-Sorry onii-chan p-please d-do me harder ;w;",
            "Y-You got me all wet now Senpai!",
            "D-Don't t-touch me there Senpai",
            "P-Please l-love me harder oniichan ohh grrh aahhhh~!",
            "Give me all your cum Senpai ahhhhh~",
            "F-Fuck me harder chan!",
            "Oh my god I hate you so much Senpai but please k-keep fucking me harder! ahhh~",
            "D-Do you like my stripped panties getting soaked by you and your hard cock? ehhh master you're so lewd ^0^~",
            "Kun your cute little dick between my pussy lips looks really cute, I'm blushing",
            "M-Master does it feel good when I slide by tits up and down on your cute manly part?",
            "O-Oniichan my t-toes are so warm with your cum all over them uwu~",
            "Lets take this swimsuit off already <3 i'll drink your unknown melty juice",
            "S-Stop Senpai if we keep making these lewd sounds im going to cum~~",
            "You're such a pervert for filling me up with your baby batter Senpai~~",
            "Fill up my baby chamber with your semen kun ^-^",
            "M-Master d-dont spank my petite butt so hard ahhhH~~~ you're getting me so w-wet~",
            "Senpai your cock is already throbbing from my huge tits~",
            "Hey kun, Can I have some semen?",
            "M-My baby chamber is overflowing with your semen M-Master",
            "Fill my throat pussy with your semen kun",
            "It-It's not gay if you're wearing thigh highs M-Master",
            "I-I need somewhere to blow my load. Can i borrow your bussy?",
            "A-ah shit... Y-your cock is big and in my ass -- already~?!",
            "I'll swallow your sticky essence along with you~!",
            "B-Baka please let me be your femboy sissy cum slut!",
            "That's a penis UwU you towd me you wewe a giww!!",
            "Ahhhh... It's like a dream come true... I get to stick my dick inside your ass...!",
            "Hey, who wants a piece of this plump 19-year-old boy-pussy? Single file, boys, come get it while it's hot!",
            "M-Master, if you keep thrusting that hard, my boobs will fall off!",
            "When do you wanna meet up again? I've really taken a liking to your dick! (,,◠∇◠) I want you and only you to slam it into my pussy every day! (≧∇≦)",
            "All I did was crossplay 'cause I felt like it might be fun... But now I'm just a little girl that cums from big dicks!",
            "D-Don't get the wrong idea!!! I don't w-want you to fuck my b-bussy because I l-love you or anything! d-definitely not!",
            "I-I know I said you could be as rough as you want... But surprise fisting wasn't what I had in mind!!",
            "W-Why is it that lately... Y-You haven't been playing with my ass!!?", },
        lewd = {            "Oh do you wanna eat? Do you wanna take a bath? Or do you want me!",
            "It's not gay if you swallow the evidence!",
            "That's a penis UwU you towd me you wewe a giww!!",
            "You are cordially invited to fuck my ass!",
            "Grab them, squeeze them, pinch them, pull them, lick them, bite them, suck them!",
            "It feels like your dick is sliding into a slimy pile of macaroni!",
            "This is the cock block police! Hold it right there!",
            "Ohoo, getting creampied made you cum? What a lewd bitch you are!",
            "I've jerked off every single day... Given birth to countless snails... All while fantasizing about the day I'd get to fuck you!",
            "You're looking at porn when you could be using your little sister instead!",
            "Umm... I don't wanna sound rude, but have you had a bath? Your panties look a bit yellow...",
            "Papa you liar! How could you say that while having such a HUGE erection.",
            "I-I just wanna borrow y-your dick...",
            "If a man inserts his hose into another man's black hole, can they make a baby?",
            "I-I had a itch down there... and I-I just needed something to-to stick up in there!",
            "You have some tasty-looking panties there...",
            "You're my personal cum bucket!!",
            "I-I'm cumming, I'm cumming, CUM with me too!",
            "Your resistance only makes my penis harder!",
            "Cum, you naughty cock! Do it! Do it! DO IT!!!",
            "Boys just can't consider themselves an adult... Until they've had a chance to cum with a girl's ampit.",
            "We're both gonna fuck your pussy at the same time!",
            "When everyone's gone home for the day and the class-room's empty you have no choice but to expose yourself and jerk off, right?", },
        apologetic = { "Please forgive me","I didn't mean to.","I'm a failure","I will go easy on you next time.","That was my fault","Please excuse my behaviour" },
        edgy = {            "Let my K/D do the talking",
            "mad cuz bad",
            "No Aimware no talk",
            "Config error, user banned, thread locked.",
            "IQ error",
            "I'm the reason your dads gay faggot",
            "How's your mom doin after last night?",
            "Dead people can't talk nn",
            "Warmth, love, and affection. These are the things I have taken away from you.",
            "I’ve made a contract with the devil, so I can’t be friends with a god.",
            "Corpses are good. They don’t babble.",
            "The weak are destined to lie beneath the boots of the strong.",
            "Options -> How to play",
            "The world is better without you",
            "Life is endless suffering...",
            "I'm just killing the spiders to save the butterflies.",
            "Fear is what creates order.",
            "No matter how much you cry I won't stop.",
            "Deleted",
            "*DEAD*",
            "Re_solved",
            "De_stroyed",
            "If G-D wanted you to live he would not have created me.",
            "Earn your damnation",
            "Vengeance is mine",
            "If at first you do not succeed... try, try again.",
            "Watch your head",
            "When you are ready call for me",
            "I have become death destroyer of worlds",
            "Easy come easy go",
            "I stay you go",
            "End of the line for you",
            "Maybe tomorrow.",
            "I'm fucking invincible.",
            "See you in a couple of minutes.",
            "You are strong child, but I am beyond strength", },
        ezfrags = {             "Visit www.EZfrags.co.uk for the finest public & private CS:GO cheats",
            "Stop being a noob! Get good with www.EZfrags.co.uk",
            "I'm not using www.EZfrags.co.uk, you're just bad",
            "You just got pwned by EZfrags, the #1 CS:GO cheat",
            "If I was cheating, I'd use www.EZfrags.co.uk",
            "Think you could do better? Not without www.EZfrags.co.uk", },
        afk = { "I'm AFK. This is a bot. You died to a AFK", }
    },
    death = {
      hentai = {          "Hehe don't touch me there Onii-chann UwU",
            "Your cum is all over my wet clit M-Master",
            "It Feels like you're pounding me with the force of a thousand suns Senpai",
            "Y-Yes right there S-Sempai hooyah",
            "P-Please keep filling my baby chamber S-Sempai",
            "O-Onii-chan it felt so good when you punded my bussy",
            "P-Please Onii-chan keep filling my baby chamber with your melty juice",
            "O-Onii-chan you just one shot my baby chamber",
            "I-Im nothing but a f-fucktoy slut for your m-monster fuckmeat!",
            "Dominate my ovaries with your vicious swimmers!",
            "Y-Your meat septer has penetrated my tight boy hole",
            "Mnn FASTER... HARDER! Turn me into your femboy slut~!",
            "Mmmm- soothe me, caress me, Fuck me, breed me!",
            "Probe your thick, wet, throbbing cock deeper and deeper into my boipussy~!!",
            "Hya! Not my ears! Ah... It tickles! Ah!",
            "Kouta... I can't believe how BIG his... Wait! Forget about that!! Is Nyuu-chan really giving him a Tit-Fuck!?",
            "Senpai shove deeper your penis in m-my pussy (>ω<) please",
            "I'm coming fwom you fwuking my asshole mmyyy!",
            "P-Please be gentle, S-Senpai!",
            "D-Don't get the wrong idea!! I didn't give up my viginity to you because I like you or anything!!",
            "Let me taste your futa cock with my pussy~",},
        lewd = {            "Dominate my ovaries with your vicious swimmers!",
            "Impregnate me with your viral stud genes!",
            "M-My body yearns for your sweet dick milk",
            "My nipples are being tantalized",
            "Penetrate me until I bust!",
            "Mmmm- soothe me, caress me, Fuck me, breed me!",
            "I'm your personal cum bucket!!",
            "Can you really blame me for getting a boner after seeing that?",
            "The two of us will cover my sis with our cum!",
            "This... This is almost like... like somehow I'm the one raping him!",
            "You're impregnating my balls!?",
            "If you weren't a pervert, you wouldn't be getting off on having a girl do you in the butt, would you?",
            "Well, well... What a cutie you are! I will claim your virginity!",
            "Oh, yeahh! You wanna fuck?",
            "I'm getting pissed off and hormy right now!", },
        apologetic = { ":(" },
        edgy = {            "You only killed me because I ran out of health..",
            "I bet dead people are easier to get along with.",
            "The real hell is inside the person.",
            "The ones who kill should be prepared to be killed.",
            "I gave you that one",
            "Congratulations! You're on the scoarboard now.",
            "Emotions are a mental disorder",
            "Carpe Diem",
            "Gone but not forgotten",
            "I'll be back",
            "Deploying the counter measure",
            "There are no ends only new beginnings", },
        ezfrags = {             "You only killed me because I'm not using www.EZfrags.co.uk",
            "You're lucky I'm not using www.EZfrags.co.uk",
            "I would have destroyed you if I was using www.EZfrags.co.uk",
            "You only killed me because you're using www.EZfrags.co.uk the finest public & private CS:GO cheat", },
        afk = { "You only killed me because I'm AFK.", }
    }
}

local vars = {
    "ks_enabled", "ks_hentai", "ks_lewd", "ks_apologetic", "ks_edgy", "ks_ezfrags", "ks_afk",
    "ds_enabled", "ds_hentai", "ds_lewd", "ds_apologetic", "ds_edgy", "ds_ezfrags", "ds_afk"
}

if client.get_shared_bool("ts_initialized", nil) == nil then
    client.set_shared_bool("ts_initialized", true)
    for _, var in ipairs(vars) do client.set_shared_bool(var, false) end
end

menu.add_main_tab("ThighHighs Chat", function()
    imgui.text("Killsay (You Kill)")
    local ck, vk = imgui.checkbox("Enable Killsays##K", client.get_shared_bool("ks_enabled", false))
    if ck then client.set_shared_bool("ks_enabled", vk) end
    
    imgui.separator()
    local k_modes = {
        {"Hentai", "ks_hentai"}, {"Lewd", "ks_lewd"}, {"Apologetic", "ks_apologetic"},
        {"Edgy", "ks_edgy"}, {"EZFrags", "ks_ezfrags"}, {"AFK", "ks_afk"}
    }
    for _, m in ipairs(k_modes) do
        local c, v = imgui.checkbox(m[1] .. "##K", client.get_shared_bool(m[2], false))
        if c then client.set_shared_bool(m[2], v) end
    end

    imgui.next_column()

    imgui.text("Deathsay (You Die)")
    local cd, vd = imgui.checkbox("Enable Deathsays##D", client.get_shared_bool("ds_enabled", false))
    if cd then client.set_shared_bool("ds_enabled", vd) end

    imgui.separator()
    local d_modes = {
        {"Hentai", "ds_hentai"}, {"Lewd", "ds_lewd"}, {"Apologetic", "ds_apologetic"},
        {"Edgy", "ds_edgy"}, {"EZFrags", "ds_ezfrags"}, {"AFK", "ds_afk"}
    }
    for _, m in ipairs(d_modes) do
        local c, v = imgui.checkbox(m[1] .. "##D", client.get_shared_bool(m[2], false))
        if c then client.set_shared_bool(m[2], v) end
    end

    imgui.columns(1)
    imgui["end"]()
end)


function on_game_event(event_name, event)
    if not event or not engine.is_in_game() then return end
    
    if event_name ~= "player_death"then return end

    local local_player = client.get_local_player()
    if not local_player then return end
    local local_index = local_player:get_index()

    local userid = event:get_int("userid")
    local attacker = event:get_int("attacker")
    local weapon = event:get_string("weapon")
    local headshot = event:get_bool("headshot")

    local victim_idx = engine.get_player_for_userid(userid)
    local attacker_idx = engine.get_player_for_userid(attacker)

    if victim_idx and attacker_idx then
        local victim_name = "Unknown"
        local attacker_name = "Unknown"

        local victim_info = engine.get_player_info(victim_idx)
        if victim_info then victim_name = victim_info.name end

        local attacker_info = engine.get_player_info(attacker_idx)
        if attacker_info then attacker_name = attacker_info.name end

        local victim_entity = entity.get_by_index(victim_idx)
        local attacker_entity = entity.get_by_index(attacker_idx)

        local victim_prefix = get_team_prefix(victim_entity)
        local attacker_prefix = get_team_prefix(attacker_entity) 

    end

    local pool = {}

    if attacker_idx == local_index and victim_idx ~= local_index then
        if not client.get_shared_bool("ks_enabled", false) then return end
        
        if client.get_shared_bool("ks_hentai", false) then for _, v in ipairs(phrases.kill.hentai) do table.insert(pool, v) end end
        if client.get_shared_bool("ks_lewd", false) then for _, v in ipairs(phrases.kill.lewd) do table.insert(pool, v) end end
        if client.get_shared_bool("ks_apologetic", false) then for _, v in ipairs(phrases.kill.apologetic) do table.insert(pool, v) end end
        if client.get_shared_bool("ks_edgy", false) then for _, v in ipairs(phrases.kill.edgy) do table.insert(pool, v) end end
        if client.get_shared_bool("ks_ezfrags", false) then for _, v in ipairs(phrases.kill.ezfrags) do table.insert(pool, v) end end
        if client.get_shared_bool("ks_afk", false) then for _, v in ipairs(phrases.kill.afk) do table.insert(pool, v) end end

    elseif victim_idx == local_index and attacker_idx ~= local_index then
        if not client.get_shared_bool("ds_enabled", false) then return end

        if client.get_shared_bool("ds_hentai", false) then for _, v in ipairs(phrases.death.hentai) do table.insert(pool, v) end end
        if client.get_shared_bool("ds_lewd", false) then for _, v in ipairs(phrases.death.lewd) do table.insert(pool, v) end end
        if client.get_shared_bool("ds_apologetic", false) then for _, v in ipairs(phrases.death.apologetic) do table.insert(pool, v) end end
        if client.get_shared_bool("ds_edgy", false) then for _, v in ipairs(phrases.death.edgy) do table.insert(pool, v) end end
        if client.get_shared_bool("ds_ezfrags", false) then for _, v in ipairs(phrases.death.ezfrags) do table.insert(pool, v) end end
        if client.get_shared_bool("ds_afk", false) then for _, v in ipairs(phrases.death.afk) do table.insert(pool, v) end end
    end

    if #pool > 0 then
        local msg = pool[math.random(1, #pool)]
        msg = msg:gsub('"', "'") 
        client.execnormal('say "' .. msg .. '"')
        
    end
end

events.register("player_death")