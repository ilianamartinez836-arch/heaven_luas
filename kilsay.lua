client.print("[KillSay] Loaded successfully")

local killsay = {
enabled = true,
messages = {
"sit dog",
"nice baunticheats L O L",
"clipped u while using big packets L M A O",
"u got owned by a user of https://veterancheats.com",
"imagine getting owned by a 10 lines public lua",
"u just lost against heavenhook. how sad",
"suck my dick bitch, ez lol",
"I think somebody has better hacks ;)",
"U JUST GOT FUCKED BY A NOSTALGIA.SOLUTIONS USER",
"Aimware? nah, aimjunkies",
"need some luas? or some new arms"
},
cooldown = 0.0,
next_allowed_time = 0.0
}

local function get_curtime()
return client.get_tick_count() * client.get_frame_time()
end

local function say(msg)
if not msg or msg == "" then return end
client.execnormal('say "' .. msg .. '"')
end

events.register("player_death")

function on_game_event(event_name, event)
if event_name ~= "player_death" then return end
if not killsay.enabled then return end
if not engine.is_in_game() then return end

local local_player = client.get_local_player()
if not local_player then return end

local userid = event:get_int("userid")
local attacker = event:get_int("attacker")

local victim_idx = engine.get_player_for_userid(userid)
local attacker_idx = engine.get_player_for_userid(attacker)

if not attacker_idx or attacker_idx <= 0 then return end
if attacker_idx ~= local_player:get_index() then return end

if victim_idx == attacker_idx then return end

local now = get_curtime()
if now < killsay.next_allowed_time then
    return
end
local msg = killsay.messages[math.random(1, #killsay.messages)]
say(msg)
killsay.next_allowed_time = now + killsay.cooldown

end

