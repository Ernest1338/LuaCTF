<h1><p align=center>LuaCTF</p></h1>
<h3><p align=center>From scratch CTF platform, put together in a weekend, very likely not secure.</p></h3>
<br><br>

## Deployment
Dependencies: `luajit`, `lua-http`

Instructions on installing dependencies:

For debian/ubuntu linux:
```
sudo apt install luajit lua-http
```
For alpine linux:
```
sudo apk add luajit lua5.1-http
```
For arch linux:
```
sudo pacman -S luajit lua51-http
```

Start server using: ```./run.sh```

## Customization
To customize CTF looks/branding - modify the template files in LuaCTF/templates

To customize CTF challenges - modify the challenges.lua file or put files in the LuaCTF/static directory
