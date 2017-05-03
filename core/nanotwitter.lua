module("nanotwitter", package.seeall)

local OAuth = require "OAuth"

local f = io.open(".nanotter", "rb")
	
if f then
	token = {}
	token.OAuthToken = f:lines()()
	token.OAuthTokenSecret = f:lines()()
end

local client = OAuth.new("Brbukpk7aHle3rIbSlpTvvleU", "PcoimOIhAhwHVK3SZ0NlSifX8PLjBcLT90FnKaiL5vgzVHG1hK", {
	RequestToken = "https://api.twitter.com/oauth/request_token", 
	AuthorizeUser = {"https://api.twitter.com/oauth/authorize", method = "GET"},
	AccessToken = "https://api.twitter.com/oauth/access_token"
}, token)

if not f then
	local callback_url = "oob"
	local values = client:RequestToken({ oauth_callback = callback_url })
	local oauth_token = values.oauth_token
	local oauth_token_secret = values.oauth_token_secret

	local tracking_code = "10090" --ておくれ(10 0 9 0)
	local new_url = client:BuildAuthorizationUrl({ oauth_callback = callback_url, state = tracking_code })

	print("認証の必要があります\n以下のURLにアクセスして認証をしてください。\n")
	print(new_url)
	print("\n認証が終わったらPINの入力をしてください\nPIN ? ")

	local oauth_verifier = assert(io.read("*n"))
	oauth_verifier = tostring(oauth_verifier)
	
	client = OAuth.new("Brbukpk7aHle3rIbSlpTvvleU", "PcoimOIhAhwHVK3SZ0NlSifX8PLjBcLT90FnKaiL5vgzVHG1hK", {
	RequestToken = "https://api.twitter.com/oauth/request_token", 
	AuthorizeUser = {"https://api.twitter.com/oauth/authorize", method = "GET"},
	AccessToken = "https://api.twitter.com/oauth/access_token"
	}, {
		OAuthToken = oauth_token,
		OAuthVerifier = oauth_verifier
	})
	client:SetTokenSecret(oauth_token_secret)
	
	local values, err, headers, status, body = client:GetAccessToken()
end

function update_status(string_status)
	local response_code, response_headers, response_status_line, response_body = 
		client:PerformRequest("POST", "https://api.twitter.com/1.1/statuses/update.json", {status = string_status})
end
