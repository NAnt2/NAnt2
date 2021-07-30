NAnt2
====
* Windows [![Build status](https://ci.appveyor.com/api/projects/status/jf9itaqnhmjf4aw8/branch/master?svg=true)](https://ci.appveyor.com/project/savornicesei/nant2/branch/master)

* Linux [![Build Status](https://travis-ci.org/savornicesei/NAnt2.svg?branch=master)](https://travis-ci.org/savornicesei/NAnt2)

[![Maintainability Rating](https://sonarcloud.io/api/project_badges/measure?project=nant2&metric=sqale_rating)](https://sonarcloud.io/dashboard?id=nant2) [![Coverage](https://sonarcloud.io/api/project_badges/measure?project=nant2&metric=coverage)](https://sonarcloud.io/dashboard?id=nant2)
[![CodeScene general](https://codescene.io/images/analyzed-by-codescene-badge.svg)](https://codescene.io/projects/10108)


What is it? 
-----------
NAnt2 is an updated and enhanced fork of [NAnt](https://github.com/nant/nant) - a .NET-based build tool and [NAnt.Contrib](https://github.com/nant/nantcontrib) - NAnt extension. 

It is intended as a drop-in replacement of NAnt, and it is licensed as free and open-source software under the GNU General Public License.

Why NAnt2?
---------
Because people still use it and because it still works great, even if the last release was long time ago (on 9th June 2012).

License
-------
NAnt2 is provided under included GPL license.

NAnt and NAnt.Contrib
=====================

What is NAnt?
-------------
In theory it is kind of like `make` without `make`'s wrinkles. In practice it's a lot like Ant.
If you are not familiar with Jakarta Ant you can get more information at the [Ant project web site](http://ant.apache.org/).


Why NAnt?
---------
Because Ant was too Java-specific.

Because Ant needed the Java runtime. NAnt only needs the .NET or Mono runtime.


The Latest Version
------------------
* NAnt - Details of the latest version can be found on the [NAnt sourceforge web site](http://nant.sourceforge.net/)
* Nant.Contrib - Details of the latest version can be found on the [NAnt sourceforge web site](http://nantcontrib.sourceforge.net/)


Files
-----
|  File           |  Purpose                                        |
| --------------- | ----------------------------------------------- |
|  README.md/txt  |  This file                                      |
|  Makefile       |  Makefile for compilation with GNU Make         |
|  Makefile.nmake |  Makefile for compilation with Microsoft NMake  |


Compilation and Installation
-----------------------------
* Windows (net-2.0): [![TeamCity CodeBetter](https://img.shields.io/teamcity/codebetter/bt387.svg)](http://teamcity.codebetter.com/project.html?projectId=NAnt&guest=1)
* Windows (mono-2.0): [![TeamCity CodeBetter](https://img.shields.io/teamcity/codebetter/bt175.svg)](http://teamcity.codebetter.com/project.html?projectId=NAnt&guest=1)
* Linux: [![Travis-ci.org](https://travis-ci.org/nant/nant.svg)](https://travis-ci.org/nant/nant) [![Join the chat at https://gitter.im/NAnt2/NAnt2](https://badges.gitter.im/NAnt2/NAnt2.svg)](https://gitter.im/NAnt2/NAnt2?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)
 
Overview
--------
The compilation process uses NAnt to build NAnt.

The approach is to first compile a copy of NAnt (using `make`/`nmake`) for
bootstrapping purpose. Next, the bootstrapped version of NAnt is used in
conjunction with NAnt build file (`NAnt.build`) to build the full version.


Prerequisites
-------------
To build NAnt, you will need the following components:

Windows
-------

* A version of the Microsoft .NET Framework.

  Available from http://msdn.microsoft.com/netframework/
  
  You will need the .NET Framework SDK as well as the runtime 
  components if you intend to compile programs.

  Note: NAnt currently supports versions 1.0, 1.1, 2.0, 3.5, and 4.0 
  of the Microsoft .NET Framework. 

or

* Mono for Windows (version 2.0 or higher)

  Available from http://www.mono-project.com/downloads/

Linux/Unix
----------

* GNU toolchain - including GNU `make`

* `pkg-config`

    Available from: http://www.freedesktop.org/Software/pkgconfig

* A working Mono installation and development libraries (version 2.0 or higher)

    Available from: http://www.mono-project.com/downloads/

        
Building the Software
---------------------
   
Build NAnt using Microsoft .NET:     

* GNU Make

        make install MONO= MCS=csc prefix=<installation path> [DESTDIR=<staging path>] [TARGET=<nant target>]

    eg. `make install MONO= MCS=csc prefix="c:\Program Files" TARGET=net-2.0`

* NMake

        nmake -f Makefile.nmake install prefix=<installation path> [DESTDIR=<staging path>] [TARGET=<nant target>]

    eg. `nmake -f Makefile.nmake install prefix="c:\Program Files" TARGET=net-4.0`


Building NAnt using Mono:

* GNU Make

        make install prefix=<installation path> [DESTDIR=<staging path>] [TARGET=<nant target>]

    eg. `make install prefix="c:\Program Files" TARGET=mono-4.0`

* NMake

        nmake -f Makefile.nmake install MONO=mono CSC=mcs prefix=<installation path> [DESTDIR=<staging path>] [TARGET=<nant target>]

    eg. `nmake -f Makefile.nmake install MONO=mono CSC=mcs prefix=/usr/local/`

Note: These instructions only apply to the source distribution of NAnt, as the
binary distribution contains pre-built assemblies.


Documentation
-------------
Documentation is available in HTML format, in the `doc/` directory.


License
========
NAnt is provided under included GPL license.
NAntContrib is provided under included LGPL license.
NAnt Copyright (C) 2001-2012 Gerry Shaw
NAntContrib Copyright (C) 2002 Tomas Restrepo (tomasr@mvps.org)

Contributors
================
NAnt (2001 - 2018)
------------------
**Lead Developers**
* Gerry Shaw (gerry_shaw -at- yahoo.com)
* Ian MacLean (ian_maclean -at- another.com)
* Scott Hernandez (scotthernandez -at- hotmail.com)
* Gert Driesen (gert.driesen -at- ardatis.com)

**Developers**
* Eric V. Smith
* Bernard Vander Beken (bvb -at- iname.com)
* Jason Diamond (jason -at- injektilo.org)
* Jay Turpin (jayturpin -at- hotmail.com)
* Matthew Mastracci (matt -at- aclaro.com)
* John Barstow (John_Barstow -at- gfsg.co.nz )
* Clayton Harbour (claytonharbour -at- sporadicism.com)


**Contributors**
* Aaron A. Anderson (aaron -at- skypoint.com)
* Arjen Poutsma (Arjen -at- ZyLAB.COM)
* Ari Hännikäinen
* Ben Lowery (b3low -at- hotmail.com)
* Bill Baker (bill.baker -at- epigraph.com)
* Brad Wilson (dotnetguy -at- pobox.com)
* Jason Reimer (jason.reimer -at- diversant.net)
* Jeroen Witmond (jnw -at- paralax.nl)
* Joe Jones (joejo -at- microsoft.com)
* Justin Rudd
* Mike Krueger (mike -at- icsharpcode.net)
* Philippe Lavoie
* Sergey Chaban (serge -at- wildwestsoftware.com)
* Shawn Van Ness
* Giuseppe Greco (giuseppe.greco -at- agamura.com)
* John Lam (http://www.iunknown.com/) 

...And more, please see list archives for additional contributors 


NAntContrib (2003 - 2018)
--------------------------
**Lead Developers**
* Gerry Shaw (gerry_shaw -at- yahoo.com)
* Ian MacLean (ian_maclean -at- another.com)
* Scott Hernandez (scotthernandez -at- hotmail.com)
* Gert Driesen (gert.driesen -at- ardatis.com)

**Contributors**
* Dominik Guder 
* Clayton Harbour
* Richard Birkby
* Nikhil Gupta 
* Bryce
