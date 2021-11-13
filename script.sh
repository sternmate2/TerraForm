#!/bin/bash

sudo snap install dotnet-sdk --classic --channel=3.1
sudo snap alias dotnet-sdk.dotnet dotnet
sudo snap install dotnet-runtime-31 --classic
