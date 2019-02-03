#
# Module manifest for module 'ASI.LogicMonitor'
#
# Generated by: "Eric C. Singer"
#

@{

# Script module or binary module file associated with this manifest
#ModuleToProcess = ''

# Version number of this module.
ModuleVersion = '1.0.0'

# ID used to uniquely identify this module
GUID = '51417b24-760a-4595-81ed-3676b091a6b3'

# Author of this module
Author = 'Eric C. Singer and Jason Woerner'

# Company or vendor of this module
CompanyName = 'Eric C. Singer'

# Copyright statement for this module
Copyright = 'Copyright (c) Eric C. Singer, Inc. All rights reserved.'

# Description of the functionality provided by this module
Description = 'This Windows PowerShell module contains ECS.WSUS funtions'

# Minimum version of the Windows PowerShell engine required by this module
PowerShellVersion = '3.0'

# Name of the Windows PowerShell host required by this module
PowerShellHostName = ''

# Minimum version of the Windows PowerShell host required by this module
PowerShellHostVersion = ''

# Minimum version of the .NET Framework required by this module
DotNetFrameworkVersion = '4.5'

# Minimum version of the common language runtime (CLR) required by this module
CLRVersion = '4.0'

# Processor architecture (None, X86, Amd64, IA64) required by this module
ProcessorArchitecture = ''

# Modules that must be imported into the global environment prior to importing this module
RequiredModules = @(
@{"ModuleName"="SqlServer";"ModuleVersion"="21.1.18068"}
)

# Assemblies that must be loaded prior to importing this module
RequiredAssemblies = @()

# Script files (.ps1) that are run in the caller's environment prior to importing this module
ScriptsToProcess = @()

# Type files (.ps1xml) to be loaded when importing this module
TypesToProcess = @()

# Format files (.ps1xml) to be loaded when importing this module
#FormatsToProcess = ''

# Modules to import as nested modules of the module specified in ModuleToProcess
NestedModules= @('ECS.WSUS.ps1')

# Functions to export from this module
FunctionsToExport = '*'

# Cmdlets to export from this module
CmdletsToExport = ''

# Variables to export from this module
VariablesToExport = '*'

# Aliases to export from this module
AliasesToExport = '*'

# List of all modules packaged with this module
ModuleList = @()

# List of all files packaged with this module
FileList =	''

# Private data to pass to the module specified in ModuleToProcess
PrivateData = ''

}
