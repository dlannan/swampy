# SWAMPY 

SWAMPY is a simple multi-player game server.

It was intiially designed for a card game that Im trying to finish off. It was needed because
I wanted a game server that was _extremely_ simple in terms of joining and lobbies - a bit like 
party mode in many game servers.

Feature wise it is quite light, but it is also very capable. 

## Starting

To jump in and just run SWAMPY do the following:

1. Generate some SSL keys for the server. These are put into the keys folder (current keys are empty files!).
2. Run the command: ```./luvit /apps/httpserver.lua```

Thats it. When running in this mode you will see all the logging from the server.

The first time you access the admin, it will use your login and password credentials and create 
and admin account. At the moment, there is only 1 admin account, but it does support as many as 
you want, but there is no interface yet for it :)   (TBD!)

## Admin 

In the admin panel you wont be able to do much until you have a game module and players to examine. 
There is still dummy data in the summary (I know, I know!!)

There is a sample module in the create panel in the module tab. This is not complete yet, but will 
be available soon. This will allow any admin to create a new module for a game and then activate it. 

Game modules can be highly customizable. The api for them ise expected to expand. 

...more docs soon.
