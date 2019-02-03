$AllFunctions = Get-ChildItem -Path "$($PSScriptRoot)\Functions" -Filter *.ps1

Foreach ($Function in $AllFunctions)
    {
    . $($Function.FullName)
    }
