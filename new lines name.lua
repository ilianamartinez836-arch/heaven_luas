local chat_spam = {
    advertise = "\rO  H  Z  A   Z",
    advertise2 = "",
    advertise3 = "",
    advertise4 = "",
    advertise5 = "",
    newline_count = 0,
    key = keys.END
}

local function build_message()
    local newline = string.rep("\r", chat_spam.newline_count)
    return newline
        .. chat_spam.advertise  .. newline
        .. chat_spam.advertise2 .. newline
        .. chat_spam.advertise3 .. newline
        .. chat_spam.advertise4 .. newline
        .. chat_spam.advertise5
end

function on_cl_move_pre()
    local local_player = client.get_local_player()
    if not local_player then
        return
    end

    if not input.is_key_down(chat_spam.key) then
        return
    end

    local message = build_message()
    client.execnormal('setinfo name "' .. message .. '"')
end







































