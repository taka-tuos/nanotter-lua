--require "core.plugin.ui"
--require "core.pluagin"

module("twitter", package.seeall)

function register()
	Pluagin:add_listener("spawn", initialize)
	Pluagin:add_listener("on_activate", on_activate)
	Pluagin:add_listener("native_context", native_context)
	Pluagin:add_listener("post_message", tweet)
end

local twitter = require "luatwit"
local util = require "luatwit.util"
local client
local stream

function initialize()
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

		local pin = Pluagin:notify_listeners("oauth_window", client:oauth_authorize_url())["text"]
		
		local token = assert(client:oauth_access_token{ oauth_verifier = pin })

		f = io.open(".nanotter", "wt")
		
		f:write(token.oauth_token..'\n')
		f:write(token.oauth_token_secret)
	end
	
	stream = client:stream_user{ _async = true }
end

function recieve_stream()
	while stream:is_active() and Pluagin:notify_listeners("is_alive")["is_alive"] do
	 	client.http:wait(10)
	 	
	 	Pluagin:notify_listeners("precess_event")
	
		-- iterate over the received items
		for data in stream:iter() do
		    local t_data = util.type(data)
		    -- tweet
		    if t_data == "tweet" then
		        if data.text then Pluagin:notify_listeners("append_tweet",nil,data) end
		    -- deleted tweet
		    elseif t_data == "tweet_deleted" then
		        Pluagin:notify_listeners("remove_tweet",nil,data)
		    -- stream events (blocks, favs, follows, list operations, profile updates)
		    elseif t_data == "stream_event" then
		        local desc = ""
		        local t_obj = util.type(data.target_object)
		        if t_obj == "tweet" then
		            if data.text then Pluagin:notify_listeners("append_tweet",nil,data) end
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

function update_timeline()
	local tl, err = client:get_home_timeline()
	assert(tl, tostring(err))
	
	for i = #tl, 1, -1 do
		Pluagin:notify_listeners("append_tweet",nil,tl[i]) 
	end
end


function native_context()
	return client, "client"
end

function on_activate()
	update_timeline()
	recieve_stream()
end

function tweet(string_status)
	client:tweet { status = string_status }
end
