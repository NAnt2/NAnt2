// NAnt - A .NET build tool
// Copyright (C) 2001 Gerry Shaw
//
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
//
// Gerry Shaw (gerry_shaw@yahoo.com)
// Scott Hernandez (ScottHernandez@hotmail.com)
// Gert Driesen (drieseng@users.sourceforge.net)

using System.Reflection;

// Configure log4net using the application configuration file 
// (AppDomain.CurrentDomain.SetupInformation.ConfigurationFile).
// The application configuration file will be directly accessed 
// by log4net (not using the System.Configuration namespace).
// The log4net configuration will be reloaded whenever the
// configuration file is changed.
[assembly: log4net.Config.XmlConfigurator(Watch=true)]

[assembly: AssemblyTitleAttribute("NAnt")]
[assembly: AssemblyDescriptionAttribute("A .NET Build Tool")]
