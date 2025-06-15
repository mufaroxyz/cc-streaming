-- Speaker Client for ComputerCraft iPod Streaming
local rednet_protocol = "MufaroSyncStream"
local speaker = peripheral.find("speaker")

if not speaker then
    error("No speaker attached! Please connect a speaker.", 0)
end

-- Attempt to open rednet on all connected modem sides
local sides = { "top", "bottom", "left", "right", "front", "back" }
local modem_opened = false
for _, side in ipairs(sides) do
    if peripheral.getType(side) == "modem" then
        rednet.open(side)
        modem_opened = true
        print("Rednet opened on: " .. side)
        break -- Open on the first modem found
    end
end

if not modem_opened then
    error("No modem attached or could not open Rednet.", 0)
end

print("Speaker client started. Waiting for audio data on protocol: " .. rednet_protocol)
term.setCursorPos(1, 2)
print("Listening...")

local current_song_id = nil
local current_volume = 1.0

while true do
    local sender_id, message, protocol = rednet.receive(rednet_protocol)

    if protocol == rednet_protocol then
        if message.type == "audio_chunk" then
            if message.id ~= current_song_id then
                -- New song detected (or first ever song, or song changed without explicit stop for old one)
                speaker.stop() -- Ensure any previous audio is stopped
                current_song_id = message.id
                term.setCursorPos(1, 3)
                term.clearLine()
                print("Playing new song: " .. (message.id or "Unknown ID"))
                -- The volume for the new song will be set from this first chunk if provided
            end

            -- Play the chunk if it belongs to the (now potentially updated) current_song_id
            if message.id == current_song_id then
                if message.volume then current_volume = message.volume end
                speaker.playAudio(message.buffer, current_volume)
            end
        elseif message.type == "stop_audio" then
            if message.id == current_song_id then
                speaker.stop()
                current_song_id = nil -- Ready for a new song
                term.setCursorPos(1, 3)
                term.clearLine()
                print("Playback stopped for: " .. (message.id or "Unknown ID"))
                term.setCursorPos(1, 2)
                term.clearLine()
                print("Listening...")
            end
        elseif message.type == "set_volume" then
            if message.volume then
                current_volume = message.volume
                -- No direct feedback on volume change needed unless speaker API supports setting volume independently
                -- For DFPWM, volume is applied per chunk, so this will take effect on the next audio_chunk
                term.setCursorPos(1, 4)
                term.clearLine()
                print("Volume set to: " .. math.floor(current_volume * 100 / 3) .. "%")
            end
        end
    end
end