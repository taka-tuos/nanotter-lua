require "core.ui"

module("nanotwitter", package.seeall)

local twitter = require "luatwit"
local util = require "luatwit.util"
local client
local stream

function init()
	local f = io.open(".nanotter", "rt")
	
	local token = {}
	
	token.consumer_key = "Brbukpk7aHle3rIbSlpTvvleU"
	token.consumer_secret = "PcoimOIhAhwHVK3SZ0NlSifX8PLjBcLT90FnKaiL5vgzVHG1hK"
	
	if f then
		token.oauth_token = f:lines()()
		token.oauth_token_secret = f:lines()()
		
		f:close()
	end

	client = twitter.api.new(token)

	if not f then
		assert(client:oauth_request_token())

		local pin = ui.pin_window(client:oauth_authorize_url())
		
		local token = assert(client:oauth_access_token{ oauth_verifier = pin })

		f = io.open(".nanotter", "wt")
		
		f:write(token.oauth_token..'\n')
		f:write(token.oauth_token_secret)
	end
	
	stream = client:stream_user{ _async = true }
end

function stream_recieve()
	while stream:is_active() and ui.is_alive() do
	 	client.http:wait(10)
	 	
	 	ui.precess_event()
	
		-- iterate over the received items
		for data in stream:iter() do
		    local t_data = util.type(data)
		    -- tweet
		    if t_data == "tweet" then
		        if data.text then ui.append_tweet(nil,data) end
		    -- deleted tweet
		    elseif t_data == "tweet_deleted" then
		        ui.remove_tweet(nil,data)
		    -- stream events (blocks, favs, follows, list operations, profile updates)
		    elseif t_data == "stream_event" then
		        local desc = ""
		        local t_obj = util.type(data.target_object)
		        if t_obj == "tweet" then
		            if data.text then ui.append_tweet(nil,data) end
		        end
		        print(string.format("[%s] %s -> %s %s", data.event, data.source.screen_name, data.target.screen_name, desc))
		    -- list of following user ids
		    elseif t_data == "friend_list_str" then
		        print(string.format("[friend list] (%d users)", #data.friends_str))
		    -- number sent when the option delimited = "length" is set
		    elseif t_data == "number" then
		        print("[size delimiter] " .. data)
		    -- everything else
		    else
		        printf(string.format("[%s] %s", t_data, pretty.write(data)))
		    end
		end
	end
end

function native_context()
	return client
end

function timeline_update()
	local tl, err = client:get_home_timeline()
	assert(tl, tostring(err))
	
	for i = #tl, 1, -1 do
		ui.append_tweet(nil,tl[i])
	end
end

function tweet(string_status)
	client:tweet { status = string_status }
end
