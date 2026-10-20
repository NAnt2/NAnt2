#!/usr/bin/env bash
# Checks that the bootstrap sources compile for the old framework targets,
# without needing those frameworks or Windows.
#
# Makefile.nmake builds the bootstrap (NAnt.Core, NAnt.DotNet,
# NAnt.Compression, NAnt.Win32 and NAnt.Console) with the csc of the target
# framework. For net-3.5 that is the C# 3 compiler, against the 3.5 class
# library. This script compiles the same source sets with the same -define
# list, using the Roslyn compiler of the installed .NET SDK restricted to
# that C# version, against the framework's reference assemblies (downloaded
# from nuget.org). It catches the two ways the old targets break: an API that
# is newer than the framework, and syntax that is newer than the compiler.
#
# It is not the real compiler, does not generate resources, and does not run
# anything, so it complements rather than replaces a build on the framework.
#
# usage: scripts/check-bootstrap-compile.sh [target...]
#   targets: net-3.5 net-4.0 (default: both)
#   REFS_CACHE=<dir> keeps the downloaded reference assemblies between runs
set -euo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd)
TARGETS=("$@")
[ ${#TARGETS[@]} -gt 0 ] || TARGETS=(net-3.5 net-4.0)
REFS_CACHE=${REFS_CACHE:-$(mktemp -d)}

SDK_DIR=$(dotnet --list-sdks | tail -1 | sed -E 's/^([^ ]+) \[(.*)\]$/\2\/\1/')
CSC_DLL="$SDK_DIR/Roslyn/bincore/csc.dll"
[ -f "$CSC_DLL" ] || { echo "Roslyn compiler not found at $CSC_DLL" >&2; exit 2; }

# downloads the reference assemblies for a framework version (35, 40, ...)
# and prints the directory that holds them
reference_assemblies() {
    local version=$1 dir="$REFS_CACHE/net$1"
    if [ ! -d "$dir/build" ]; then
        local package="microsoft.netframework.referenceassemblies.net$version"
        mkdir -p "$dir"
        curl -sSfL -o "$dir/package.nupkg" \
            "https://api.nuget.org/v3-flatcontainer/$package/1.0.3/$package.1.0.3.nupkg"
        unzip -q -o "$dir/package.nupkg" -d "$dir"
    fi
    find "$dir/build/.NETFramework" -mindepth 1 -maxdepth 1 -type d | head -1
}

check_target() {
    local target=$1 langversion refs
    # mirrors the DEFINE lines of Makefile.nmake
    local define="NET,NET_1_0,NET_1_1,NET_2_0,NET11_OR_GREATER,NET20_OR_GREATER"
    case $target in
        net-3.5)
            define+=",NET_3_5,ONLY_3_5,NET35_OR_GREATER,NET35_OR_LESSER"
            langversion=3
            refs=$(reference_assemblies 35) ;;
        net-4.0)
            define+=",NET_3_5,NET_4_0,ONLY_4_0,NET35_OR_GREATER,NET40_OR_GREATER"
            langversion=4
            refs=$(reference_assemblies 40) ;;
        *)
            echo "unsupported target $target" >&2
            return 2 ;;
    esac
    define+=",NET451_OR_LESSER"

    # the default references csc takes from its csc.rsp
    local rsp=() assembly
    for assembly in Accessibility System System.Configuration System.Configuration.Install \
            System.Core System.Data System.Data.DataSetExtensions System.Data.Linq \
            System.Data.OracleClient System.Deployment System.Design System.DirectoryServices \
            System.Drawing System.Drawing.Design System.EnterpriseServices System.Management \
            System.Messaging System.Runtime.Remoting System.Runtime.Serialization \
            System.Runtime.Serialization.Formatters.Soap System.Security System.ServiceModel \
            System.ServiceProcess System.Transactions System.Web System.Web.Extensions \
            System.Web.Mobile System.Web.RegularExpressions System.Web.Services \
            System.Windows.Forms System.Xml System.Xml.Linq Microsoft.CSharp; do
        [ -f "$refs/$assembly.dll" ] && rsp+=("-r:$refs/$assembly.dll")
    done

    local out failed=0
    out=$(mktemp -d)
    compile() {
        local name=$1
        shift
        if ! (cd "$REPO" && dotnet "$CSC_DLL" -nologo -noconfig -nostdlib -warn:0 \
                -r:"$refs/mscorlib.dll" "${rsp[@]}" -langversion:"$langversion" \
                -define:"$define" -out:"$out/$name" "$@"); then
            echo "FAILED: $name"
            failed=1
        fi
    }

    echo "== $target (C# $langversion)"
    local lib=lib/common/neutral
    compile NAnt.Core.dll -target:library -r:$lib/log4net.dll \
        -recurse:'src/NAnt.Core/*.cs' src/SolutionInfo.cs
    compile NAnt.DotNetTasks.dll -target:library -r:"$out/NAnt.Core.dll" -r:$lib/NDoc.Core.dll \
        -recurse:'src/NAnt.DotNet/*.cs' src/SolutionInfo.cs
    compile NAnt.CompressionTasks.dll -target:library -r:"$out/NAnt.Core.dll" \
        -r:$lib/ICSharpCode.SharpZipLib.dll -recurse:'src/NAnt.Compression/*.cs' src/SolutionInfo.cs
    compile NAnt.Win32Tasks.dll -target:library -r:"$out/NAnt.Core.dll" \
        -r:"$out/NAnt.DotNetTasks.dll" -recurse:'src/NAnt.Win32/*.cs' src/SolutionInfo.cs
    compile NAnt.exe -target:exe -r:$lib/log4net.dll \
        -recurse:'src/NAnt.Console/*.cs' src/SolutionInfo.cs
    rm -rf "$out"

    if [ $failed -eq 0 ]; then
        echo "$target: OK"
    else
        echo "$target: FAILED"
    fi
    return $failed
}

status=0
for target in "${TARGETS[@]}"; do
    check_target "$target" || status=1
done
exit $status
