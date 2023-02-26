# Overview

This `tools` folder contains development tools / executables (for build and/or tests).


Tool         | Version     | License    | Download url
-------------|-------------|------------|--------------
 cvs.exe     | 1.11.22     | GNU GPL    | [gnu.org](https://ftp.gnu.org/non-gnu/cvs/binary/stable/)
 nuget.exe   | 6.4.0.123   | Apache 2.0 | [nuget.org](https://www.nuget.org/downloads)
 vswhere.exe | 3.1.1.61428 | MIT        | [GitHub](https://github.com/microsoft/vswhere)

 ## CVS client
 Required for running SourceControl tests on Windows. On Linux, it should be available in official repositories.

 ## NuGet client
 Required for downloading packages and/or tools from NuGet. Currently not used in the build process.

 ## vswhere
 Required for locating Visual Studio 2017 and newer installations. It has a fixed path on Windows `%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe` but is more safe to have it locally to project.

