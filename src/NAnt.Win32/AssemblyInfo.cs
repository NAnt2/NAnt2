using System.Reflection;
using System.Security.Permissions;

[assembly: AssemblyTitleAttribute("NAnt.Win32Tasks")]
[assembly: AssemblyDescriptionAttribute("")]

#if NET35_OR_LESSER
[assembly: RegistryPermissionAttribute(SecurityAction.RequestMinimum , Unrestricted=true)]
#endif