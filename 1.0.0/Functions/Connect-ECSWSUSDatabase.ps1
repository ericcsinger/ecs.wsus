Function Connect-ECSWSUSDatabase
    {
    <#
    .SYNOPSIS
    This establishes a global connection variable to be used by other ECSWSUS cmdlets. This to reduce the amount of parameters needed per command

    .DESCRIPTION
    This establishes a global connection variable to be used by other ECSWSUS cmdlets. This to reduce the amount of parameters needed per command

    .PARAMETER WSUSSQLServerName
    This is the name of the SQL server and SQL instance your WSUS database is hosted on.

    .PARAMETER WSUSDatabaseName
    This is the name of the WSUS database you're querying.

    .PARAMETER Credential
    If you want to connect using SQL auth, use "Get-Credential" to store your SQL auth username and password in a PS object

    .EXAMPLE
    This example gets any computer with wks in the name with a timeout of 100 seconds and uses SQLAuth

    Connect-ECSWSUSDatabase -WSUSSQLServerName asi-sql-01 -Credential $cred

    .EXAMPLE
    This example gets any computer with wks and pc in the name with not timeout and uses passthru auth
    Connect-ECSWSUSDatabase -WSUSSQLServerName asi-sql-01 



    #>
    [CmdletBinding()]
    

    Param
	    (
        #############################################################
        #WSUSSQLServerName

        [Parameter(
            ParameterSetName = "PassthruAuth",
            Mandatory = $True,
            HelpMessage="Enter the name of your WSUS SQL server or SQLServer\Instance name"
            )]

        [Parameter(
            ParameterSetName = "SQLAuth",
            Mandatory = $True,
            HelpMessage="Enter the name of your WSUS SQL server or SQLServer\Instance name"
            )]

        [ValidateNotNullorEmpty()]
        [String]$WSUSSQLServerName,

        #############################################################
        #WSUSDatabaseName

        [Parameter(
            ParameterSetName = "PassthruAuth",
            Mandatory=$false
            )]

        [Parameter(
            ParameterSetName = "SQLAuth",
            Mandatory=$false
            )]

        [ValidateNotNullorEmpty()]
        [String]$WSUSDatabaseName = "SUSDB",


        #############################################################
        #Credential

        [Parameter(
            ParameterSetName = "SQLAuth",
            Mandatory=$True
            )]
        [ValidateNotNullorEmpty()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = $null
	    )

    Process
        {
        
        #########################################################################
        #Dynamic Parameters

        #$ModuleRootPath = Split-Path -Path $PSScriptRoot 
        
        #END Dynamic Parameters
        #########################################################################

        #########################################################################
        #Executing SQL query to test the connection
        Try
            {
            #Simple test SQL query to run
            $SQLQueryToRun = "SELECT TOP (1) fileid FROM [$($WSUSDatabaseName)].[sys].[sysfiles]"

            #Formulating base command
            $SQLCommandToRun = '$SQLQuery' + " = Invoke-Sqlcmd -ServerInstance $WSUSSQLServerName -Database $WSUSDatabaseName -AbortOnError" + ' -Query $SQLQueryToRun' + ' -ErrorAction "Stop"'

            #Checking if you wanted PassThru or SQL Auth
            If ($Credential -ne $null)
                {
                Write-Verbose "AuthenticationType = SQLAuth"
                $SQLCommandToRun = $SQLCommandToRun  + ' -Credential $Credential'
                }
            Else
                {
                Write-Verbose "AuthenticationType = Passthru"
                }

            #Running test query
            Invoke-Expression -Command $($SQLCommandToRun)

            #Making sure you had results, if not we're throwing an error
            $MeaureSQLQueryCount = $SQLQuery | Measure-Object | Select-Object -ExpandProperty count
            If ($MeaureSQLQueryCount -ge 1)
                {
                $Global:ECSWSUSDatabaseConnection = New-Object PSObject -Property @{
                    WSUSSQLServerName = $($WSUSSQLServerName)
                    WSUSDatabaseName = $($WSUSDatabaseName)
                    Credential = $Credential
                    }
                }
            Else
                {
                Throw "No test query results, it's likely the connection failed"
                }

            }
        Catch
            {
            Throw "Something went wrong with the SQL query, exception message = $($_.Exception.Message)"
            }

        #END Executing SQL query
        #########################################################################
        }
    }