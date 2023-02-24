# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v0.93 - Unreleased

### Added 
- **NAnt.Contrib** is now part of NAnt2 project [NAnt2#77](https://github.com/NAnt2/NAnt2/issues/77)

#### Framework support
- NAnt2 builds now on .NET framework 4.5 that means Windows Vista SP2 and newer and any Linux distribution with Mono v3.0+
- NAnt2 can now be build on Mono 6.12 [NAnt2#68](https://github.com/NAnt2/NAnt2/issues/68), [NAnt2#93](https://github.com/NAnt2/NAnt2/issues/93), [NAnt2#94](https://github.com/NAnt2/NAnt2/issues/94)
- Added support for .NET framework 4.5+ [NAnt2#55](https://github.com/NAnt2/NAnt2/issues/55), [NAnt2#20]([NAnt2#93](https://github.com/NAnt2/NAnt2/issues/20)):
  - net-4.5, 
  - net-4.5.1, 
  - net-4.5.2, 
  - net-4.6, 
  - net-4.6.1, 
  - net-4.6.2, 
  - net-4.7, 
  - net-4.7.1, 
  - net-4.7.2
  - net-4.8
  - mono-4.5
  - mono-4.5.1
- Added support for .NET/Mono Framework 4.5 and VS2012 solution [NAnt2#62](https://github.com/NAnt2/NAnt2/issues/62)
- Updated NAnt to use the newer Windows SDKs by default when targeting net-2.0 before defaulting back to the old .NET 2.0 sdk


#### Core
- Various performance improvements to reduce memory usage, and overall performance during executions of long running tasks [NAnt#PR143](https://github.com/nant/nant/pull/143)
- Upgraded to NUnit 2.6.3
- Properties with null values are no longer allowed
- Implemented parallel execution of targets in the project. [NAnt#PR105](https://github.com/nant/nant/pull/105)
- Fixes builds when make runs multiple jobs simultaneously (`make -j`) [NAnt#PR115](https://github.com/nant/nant/pull/115)

#### Tasks
- Added `assembly::get-informational-version` function
- Added `assembly::get-attribute-property` function to retrieve any custom attribute from the assembly
- Add ability to add password to zip files and to unzip archives protected with passwords
- Added new attribute `expectedexitcode` to `<exec>` task that sets the expected 3rd party tool exit code and fails the build if its not met [NAnt2#63](https://github.com/NAnt2/NAnt2/issues/63)
- Added new function `nant::is-64bit` that checks if NAnt is running in a 64-bit process
- `path::combine` can now combine up to 4 paths [NAnt2#163](https://github.com/NAnt2/NAnt2/issues/163)
- `<trycatch>` task now includes all of the inner exception information in the `catch` property [NAnt#155](https://github.com/nant/nant/issues/155)
- Added new application setting `nant.externalprogram.output.timeout` to control the output/error timeout value for external programs in App.config [NAnt#PR132](https://github.com/nant/nant/pull/132)
- `<echo>Some Important Message</echo>` will not show warning in VS anymore when `nant.xsd` is used to enable build file support [NAnt#PR122](https://github.com/nant/nant/pull/122)
- Added `directory::get-name` function to retrieve directory names from a given path [NAnt#59](https://github.com/nant/nant/issues/59)
- Updated the `csc` task to handle the new compiler model introduced in [Mono 3.0.6](http://www.mono-project.com/Release_Notes_Mono_3.0.6#C.23_Compiler">Mono 3.0) [NAnt#91](https://github.com/nant/nant/issues/91)

### Fixed

#### Core
- Fixed `locatesdk` to read installed SDK information from Wow6432Node as well if NAnt runs as a 64bit process
- Fixed "NET1.1 not found" on x64 systems
- Fixed a null exception in `<locatesdk>` due to absent registry HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Microsoft SDKs\Windows on Windows 10 64bit [NAnt2#97](https://github.com/NAnt2/NAnt2/issues/97) 
- The dollar sign (`$`) can now be escaped by using two dollar signs. (e.g. `<echo message="$${my.prop}"/>` => `"${my.prop}"`) [NAnt#99](https://github.com/nant/nant/issues/99)

#### Tasks
- Fixed streams not being closed in `<mail>` task that could cause errors [NAnt2#66](https://github.com/NAnt2/NAnt2/issues/66)
- Fixed an issue with the `get` task when the request will timeout after the default read write timeout of 5 minutes which may be less than the Timeout value set on the task [NAnt#65](https://github.com/nant/nant/issues/65)
- Fixed code example for `version::get-major-version` function
- Fixed `<copy>` task to also check the `asis` count of a copy file set (next to other "includes") before defaulting to adding all files and subdirectories [NAnt#50](https://github.com/nant/nant/issues/50)
- Fixed a bug in `xmlpoke` task causing additional whitespace and newline character when poke empty value into element [NAnt2#61](https://github.com/NAnt2/NAnt2/issues/61)
- Fixed `<vb6>` task when parsing _ResFile32_ entries in .vbp file [NAnt#PR27](https://github.com/nant/nantcontrib/pull/27)
- Fixed issue where `<vb6>` was looking in the wrong path on x64 systems. [NAnt#PR35](https://github.com/nant/nantcontrib/pull/35)
- Fixed an issue with the `<sysinfo>` task when dealing  with environment property names which contains invalid characters like parentheses. E.g. `ProgramFiles(x86)` on Win7 64 bit will result in `sys.env.ProgramFiles.x86` [NAnt#83](https://github.com/nant/nant/issues/83)
- Fixed an issue with the `<mail>` task when dealing with email address lines ending with a semi-colon [NAnt#61](https://github.com/nant/nant/issues/61)
- `if` and `unless` attributes are evaluated now before trying to expand properties elsewhere within the task [NAnt#110](https://github.com/nant/nant/issues/110)
- Prevent `foreach` from adding properties with null values into the property dictionary [NAnt#84](https://github.com/nant/nant/issues/84)
- Fixed issues related to copying subdirectories that were introduced in NAnt 0.92. ([NAnt#64](https://github.com/nant/nant/issues/64), [NAnt#85](https://github.com/nant/nant/issues/85), and [NAnt#88](https://github.com/nant/nant/issues/88)) 
 

### Deprecated
- The following target frameworks will be removed in following versions:
  - net-1.0, 
  - net-1.1, 
  - net-2.0, 
  - netcf-1.0, 
  - netcf-2.0, 
  - silverlight-2.0, 
  - silverlight-3.0, 
  - silverlight-4.0, 
  - silverlight-5.0, 
  - mono-1.0, 
  - mono-2.0, 
  - moonlight-2.0, 
  - sscli-1.0

### Removed

### Security

## v0.92 - 2012-06-09