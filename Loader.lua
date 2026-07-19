--[[
               
  ____ ________
_/ __ \\___   /
\  ___/ /    / 
 \___  >_____ \
     \/      \/

]]

if (getgenv().EZ_LOADED) then
	return;
end;
getgenv().EZ_LOADED = true;

loadstring(game:HttpGet("https://api.luarmor.net/files/v4/loaders/31283a1cc203e3f65710cffc683c3bee.lua"))()
