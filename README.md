# Luvit Docker Image Source

Luvit Docker Image is based on:

https://github.com/baleyko/docker-luvit

It's a source code of docker image with [Luvit](https://luvit.io/).

Luvit - it's a lightweight implementation of Lua programming language, using the event loop, distribute with a standard library that implements similiar to the Node.js standard library interface.
Read the official documentation to learn more.

Before starting swampy make sure you have installed your SSL keys in swampy/swampy/keys folder.
You should have a fullkeychain.pem, a cert.pem and a privkey.key. 
If you use letsencrypt you can easily generate these.

To start swampy using docker-compose:

```shell
$ git clone https://github.com/dlannan/swampy.git
$ cd swampy
$ docker-compose build
$ docker-compose up -d
```

## SWAMPY 

The Swampy source code is in swampy/swampy.

Being a luvit based system, SWAMPY is entirely built from Web pages (mostly static) and lua.

## License
  
It's distributed under [MIT License](LICENSE).
