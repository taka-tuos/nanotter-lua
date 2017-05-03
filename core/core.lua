require "core.nanotwitter"
require "core.ui"
require "core.thread"

require "alarm"

module("core", package.seeall)

local lgi = require 'lgi'
local Gtk = lgi.require('Gtk', '3.0')
local GLib = lgi.require('GLib', '2.0')

local client = _G["nanotwitter"]

local app = Gtk.Application { application_id = 'org.kagura.nanotter' }

function timer_handler()
	io.write("TIMEOUT")
	client.stream_recieve()
end

function boot()
	client.init()
	
	ui.init(client.native_context(),app)
	
	app:run()
end

function app:on_activate()
	client.timeline_update()
	client.stream_recieve()
end
