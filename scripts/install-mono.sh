#!/bin/sh

 curl -sLo /tmp/mono.gpg http://download.mono-project.com/repo/xamarin.gpg
sudo apt-key add /tmp/mono.gpg
sudo sh -c "echo 'deb http://download.mono-project.com/repo/debian wheezy main' >> /etc/apt/sources.list.d/mono-xamarin.list"
sudo apt-get update -qq
sudo apt-get install -qq mono-devel mono-vbnc nuget libgdiplus=2.10-3