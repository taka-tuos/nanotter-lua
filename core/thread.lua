module("thread", package.seeall)

local llthreads = require "llthreads2.ex"

function new(func)
	llthreads.new(func):start():join()
end

