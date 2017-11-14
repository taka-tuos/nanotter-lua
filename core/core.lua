require "lfs"

require "core.pluagin"

module("core", package.seeall)

local lgi = require 'lgi'
local Gtk = lgi.require('Gtk', '3.0')
local GLib = lgi.require('GLib', '2.0')

local app = Gtk.Application { application_id = 'org.kagura.nanotter' }

local spawn_table

function boot()
	Pluagin:load_all()
	
	spawn_table = Pluagin:notify_listeners("spawn", app)
	
	app:run()
end

function app:on_activate()
	Pluagin:notify_listeners("on_activate")
end
