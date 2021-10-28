# SWAMPY 

**WARNING** : SWAMPY is now split into two repos. One for docker: https://github.com/dlannan/swampy-docker and this repo which is used for submodules and Heroku.

SWAMPY is a simple multi-player game server.

It was intiially designed for a card game that Im trying to finish off. It was needed because
I wanted a game server that was _extremely_ simple in terms of joining and lobbies - a bit like 
party mode in many game servers.

Feature wise it is quite light, but it is also very capable. 

## Starting

To jump in and just run SWAMPY do the following:

1. Generate some SSL keys for the server. These are put into the keys folder (current keys are empty files!).
2. Run the command: ```./luvit app/httpsserver.lua```

Thats it. When running in this mode you will see all the logging from the server.

### Errors

If you see this message then your keys are not correct, not named properly or are missing.
```
Uncaught exception:
[string "bundle:/init.lua"]:49: /home/user1/repos/swampy/swampy/deps/tls/common.lua:146: system lib
stack traceback:
        [builtin#37]: at 0x004f7cd0
        [string "bundle:/init.lua"]:49: in function <[string "bundle:/init.lua"]:47>
        [C]: in function 'xpcall'
        [string "bundle:/init.lua"]:47: in function 'fn'
        [string "bundle:deps/require.lua"]:310: in function <[string "bundle:deps/require.lua"]:266>
```

## Admin 

The first time you access the admin, it will use your login and password credentials and create 
and admin account. At the moment, there is only 1 admin account. It does support as many as 
you want, but there is no interface yet for it :)   (TBD!)

In the admin panel you wont be able to do much until you have a game module and players to examine. 
There is still dummy data in the summary (I know, I know!!)

There is a sample module in the create panel in the module tab. This is not complete yet, but will 
be available soon. This will allow any admin to create a new module for a game and then activate it. 

Game modules can be highly customizable. The api for them ise expected to expand. 

...more docs soon.
