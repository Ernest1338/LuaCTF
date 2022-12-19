<h1><p align=center>LuaCTF</p></h1>
<h3><p align=center>Lightweight & fast self made CTF platform built from scratch using Lua</p></h3>
<br><br>

## Deployment
Dependencies: `luajit`, `lua-http`

Instructions for installing dependencies:

Debian/Ubuntu Linux:
```
sudo apt install luajit lua-http
```
Alpine Linux:
```
sudo apk add luajit lua5.1-http
```
Arch Linux:
```
sudo pacman -S luajit lua51-http
```

Start the server using: ```./run.sh```

## Customization
To customize CTF looks/branding - modify the template files in LuaCTF/templates

To customize CTF challenges - modify the challenges.lua file or put files in the LuaCTF/static directory

You can enable/disable logging to stdout/file in the LuaCTF/src/main.lua file

## Note

This project was put together in a weekend. It is full of ugly code / hacks and is very likely not secure. Use with caution.
