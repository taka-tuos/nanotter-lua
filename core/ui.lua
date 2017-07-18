module("ui", package.seeall)

local lgi = require 'lgi'
local Gtk = lgi.require('Gtk', '3.0')
local GdkPixbuf = lgi.GdkPixbuf

local tweetbox = Gtk.TextView()

local client,module_twitter

local lstHome
local lstMentions
local lstFavs

local alive = true

function is_alive()
	return alive
end

function kill()
	alive = false
end

function init(ctxA,ctxB,app)
	local window = Gtk.Window {
		application = app,
		title = 'nanotter',
		default_width = 640,
		default_height = 480,
		on_destroy = kill
	}

	window.has_resize_grip = true
	
	window:set_icon_from_file("core/res/logo.png")
	
	local nbkPages = Gtk.Notebook { vexpand = true }
	
	local scrolA = Gtk.ScrolledWindow()
	local scrolB = Gtk.ScrolledWindow()
	local scrolC = Gtk.ScrolledWindow()
	
	lstHome = Gtk.ListBox{ selection_mode = "SINGLE" }
	lstMentions = Gtk.ListBox{ selection_mode = "NONE" }
	lstFavs = Gtk.ListBox{ selection_mode = "NONE" }
	
	scrolA:add(lstHome)
	scrolB:add(lstMentions)
	scrolC:add(lstFavs)
	
	nbkPages:append_page(scrolA,Gtk.Label { label = "ホーム" })
	nbkPages:append_page(scrolB,Gtk.Label { label = "メンション" })
	nbkPages:append_page(scrolC,Gtk.Label { label = "ふぁぼ" })
	
	local hbox = Gtk.HBox()
	local vbox = Gtk.VBox()
	local box = Gtk.Box()
	local button = Gtk.Button { label = 'ついーと', on_clicked = tweetbox_send }
	
	hbox:pack_start(tweetbox, true, true, 2)
	hbox:pack_start(button, false, true, 2)
	vbox:pack_start(hbox, false, true, 2)
	
	vbox:pack_start(nbkPages, true, true, 2)
	
	window:add(vbox)
	
	window:show_all()
	
	client = ctxA
	module_twitter = ctxB
end

function tweetbox_send()
	local starts = Gtk.TextIter()
	local ends = Gtk.TextIter()
	starts,ends = tweetbox:get_buffer():get_bounds()
	module_twitter.tweet(tweetbox:get_buffer():get_text(starts,ends))
	tweetbox:get_buffer():set_text(starts,ends,"")
end

function pin_window(tokenuri)
	local window = Gtk.Window {
	   title = 'PIN認証',
	   default_width = 320,
	   default_height = 200,
	   on_destroy = Gtk.main_quit
	}
	
	local vbox = Gtk.VBox()
	local label = Gtk.Label()
	local button = Gtk.Button { label = "OK", on_clicked = Gtk.main_quit }
	local entry = Gtk.Entry()
	
	local uri = "以下のページにアクセスして、\n" ..
				"表示されたPINコードを入力してください。\n" ..
				"<a href=\"" ..
				tokenuri ..
				"\">連携アプリ設定ページ</a>"
	label:set_markup(uri)
	
	vbox:pack_start(label,true,true,10)
	vbox:pack_start(entry,true,true,10)
	vbox:pack_start(button,true,true,10)
	
	window:add(vbox)
	
	window:show_all()
	
	Gtk.main()
	
	window:close()
	
	return tonumber(entry:get_text())
end

local seen_tweets = {}

local avatar_store = {}
local avatar_pending = {}

local added_to_list = {}
local replying_tweet

function escape_amp(text)
    return text:gsub("&", "&amp;")
end

function user_tooltip(user)
    local fmt = [[
<big><b>$screen_name</b></big>
<small>$statuses_count Tweets</small>

<b>Name:</b> $name
<b>Location:</b> $location
<b>Bio:</b> $description
<b>Followers:</b> $followers_count <b>Following:</b> $friends_count <b>Listed:</b> $listed_count]]
    return escape_amp(fmt:gsub("$([%w_]+)", user))
end

-- pango processes HTML entities before anything else, so must escape all the &'s, even in the URL
function pango_link(text, url)
    return ('<a href="%s">%s</a>'):format(escape_amp(url), escape_amp(text))
end

function pixbuf_from_image_data(data)
    local loader = GdkPixbuf.PixbufLoader()
    loader:write(data)
    loader:close()
    return loader:get_pixbuf()
end

function request_avatar(item, user)
    local url = user.profile_image_url
    local image = avatar_store[url]
    if image then
        item.child.icon:set_from_pixbuf(image)
        return
    end
    item.child.icon:set_from_icon_name("image-loading", Gtk.IconSize.DIALOG)
    -- request already sent
    if image == false then
        local pending = avatar_pending[url]
        pending[#pending + 1] = item
        return
    end
    -- first request
    avatar_store[url] = false
    avatar_pending[url] = { item }
    
    function request_callback(data, code)
        if data == nil then return nil, code end
        if code == 200 then
            local pb = pixbuf_from_image_data(data)
            avatar_store[url] = pb
            for _, w in ipairs(avatar_pending[url]) do
                w.child.icon:set_from_pixbuf(pb)
            end
        else
            avatar_store[url] = nil
            for _, w in ipairs(avatar_pending[url]) do
                w.child.icon:set_from_icon_name("image-missing", Gtk.IconSize.DIALOG)
            end
        end
        avatar_pending[url] = nil
        return true
    end
    
    local retA,retB = client:http_request{ url = url, _async = false }
    
    request_callback(retA,retB)
end

function ui_set_reply_to(tweet)
    replying_tweet = tweet
    tweetbox:set_text("@" .. tweet.user.screen_name .. " ")
    tweetbox:grab_focus()
end

function copy_to_clipboard(text)
    local clipboard = Gtk.Clipboard.get(Gdk.SELECTION_CLIPBOARD)
    clipboard:set_text(text, -1)
end

function build_tweet_item(id, header, text, footer)
    local w = Gtk.Box{
        id = id,
        spacing = 10,
        Gtk.Image{ id = "icon", width = 48, valign = "START", margin_top = 3 },
        Gtk.EventBox{
            id = "content",
            Gtk.Box{
                orientation = Gtk.Orientation.VERTICAL,
                hexpand = true,
                spacing = 5,
                Gtk.Label{ label = header, use_markup = true, xalign = 0, ellipsize = "END" },
                Gtk.Label{ label = text, use_markup = true, xalign = 0, vexpand = true, wrap = true, wrap_mode = "WORD_CHAR" },
                Gtk.Label{ label = footer, use_markup = true, xalign = 0, wrap = true, wrap_mode = "WORD_CHAR" },
            },
        },
    }
    w:show_all()
    return w
end


function build_tweet_menu(tweet)
    local menu = Gtk.Menu{
        Gtk.MenuItem{ id = "reply", label = "返信" },
        Gtk.MenuItem{ id = "fav", label = tweet.favorited and "あんふぁぼ" or "ふぁぼふぁぼする" },
        Gtk.MenuItem{ id = "rt", label = "リツイートする" },
        Gtk.SeparatorMenuItem(),
        Gtk.MenuItem{ id = "copy", label = "本文をコピー" },
        Gtk.MenuItem{ id = "dump", label = "JSONをコピー" },
    }

    function menu.child.reply.on_activate()
        ui_set_reply_to(tweet)
    end
    function menu.child.fav.on_activate()
        if tweet.favorievents_pendingted then
            local tw,err = tweet:unset_favorite{ _async = true }
            if tw == nil then return nil, err end
            remove_tweet(lstFavs, tweet)
            seen_tweets[tweet.id_str] = tw
        else
            local tw,err = tweet:set_favorite{ _async = true }
            if tw == nil then return nil, err end
            append_tweet(lstFavs, tweet)
        end
    end
    function menu.child.rt.on_activate()
        local tw,err = tweet:retweet{ _async = true }
        if tw == nil then return nil, err end
    end
    function menu.child.copy.on_activate()
        copy_to_clipboard(parse_tweet(tweet, true))
    end
    function menu.child.dump.on_activate()
        copy_to_clipboard(pretty.write(tweet))
    end

    menu:show_all()
    return menu
end

function parse_entities(tweet, with_links)
    local urls = {}
    local fmt = with_links and pango_link or function(x) return x end
    for _, item in ipairs(tweet.entities.urls) do
        local key = item.url:match "https?://t%.co/(%w+)"
        urls[key] = fmt(item.display_url, item.expanded_url)
    end
    if tweet.entities.media then
        for _, item in ipairs(tweet.entities.media) do
            local key = item.url:match "https?://t%.co/(%w+)"
            urls[key] = fmt(item.display_url, item.expanded_url)
        end
    end
    return tweet.text:gsub("https?://t%.co/(%w+)", urls)
end

function parse_tweet(tweet, text_only)
    local header, footer = {}, {}
    if tweet.retweeted_status then
        if not text_only then
            header[1] = "🔃"
            local f = "@" .. tweet.user.screen_name .. "(" .. tweet.user.name .. ")" .." がリツイート"
            if tweet.retweet_count > 1 then
                f = f .. " その他 " .. tweet.retweet_count .. " 人がリツイート"
            end
            footer[1] = f
        end
        tweet = tweet.retweeted_status
    end
    if text_only then
        return "<" .. tweet.user.screen_name .. "> " .. parse_entities(tweet)
    end
    header[#header + 1] = "<b>" .. tweet.user.screen_name .. "</b>"
    if tweet.user.protected then
        header[#header + 1] = "🔒"
    end
    header[#header + 1] = '<span color="gray">' .. escape_amp(tweet.user.name) .. '</span>'
    if tweet.in_reply_to_screen_name then
        footer[#footer + 1] = "@" .. tweet.in_reply_to_screen_name .. " への返信"
    end
    footer[#footer + 1] = "via " .. tweet.source:gsub('rel=".*"', '') 
    return table.concat(header, " "),
           parse_entities(tweet, true),
           '<small><span color="gray">' .. table.concat(footer, ", ") .. '</span></small>'
end

function event_tweet_clicked(self, ev)
    if ev:triggers_context_menu() then
        local item = self:get_parent()   -- content -> main
        local tweet = seen_tweets[item.id]
        local menu = build_tweet_menu(tweet)
        menu:popup(nil, nil, nil, nil, ev.button, ev.time)
    end
end

function append_tweet(list,tweet)
	if not list then list = lstHome end
	
	for k, v in pairs(tweet) do
		print( k, v )
	end
	
	print('\n')
	print('\n')
	print('\n')
	
    local id_str = tweet.id_str
    seen_tweets[id_str] = tweet
    if not added_to_list[list] then
        added_to_list[list] = {}
    end
    if not added_to_list[list][id_str] then
        added_to_list[list][id_str] = true
        local item = build_tweet_item(id_str, parse_tweet(tweet))
        tweet._row = item
        item.child.content.on_button_press_event = event_tweet_clicked
        local user = tweet.retweeted_status and tweet.retweeted_status.user or tweet.user
        item.child.icon:set_tooltip_markup(user_tooltip(user))
        request_avatar(item, user)
        list:insert(item,0)
    end
end

function remove_tweet(list,tweet)
	if not list then list = lstHome end
	
    local id_str = tweet.id_str
    for id, tw in pairs(seen_tweets) do
        if id == id_str then
            if added_to_list[list][id] then
                tw._row:get_parent():destroy() -- delete the ListBoxRow
                tw._row = nil
                added_to_list[list][id] = nil
                return true
            end
        end
    end
end

function precess_event()
	while Gtk.events_pending() do
    	Gtk.main_iteration()
    end
end

function main()
	Gtk.main()
end

