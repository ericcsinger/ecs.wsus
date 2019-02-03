Function Test-ECSWSUSDatabaseConnected
    {
    <#
    .SYNOPSIS
    This tests that you are not only connected to the WSUS database, but also that we can query the wsus database

    .DESCRIPTION
    This tests that you are not only connected to the WSUS database, but also that we can query the wsus database

    .EXAMPLE
    There are no parameters, it's simply run the command as it is.

    Test-ECSWSUSDatabaseConnected
    #>
    [CmdletBinding()]
    

    Param
	    (

	    )

    Process
        {
        #########################################################################
        #Test connecton is defined

        Try
            {
            Write-Verbose "Testing if the global:ecswsusdatabaseconection var exists"
            $Shh = Get-Variable -Name ECSWSUSDatabaseConnection -ErrorAction Stop
            $VariableExists = $true
            $OverallStatus = $true
            }
        Catch
            {
            $VariableExists = $false
            $OverallStatus = $false
            }
        
        #END Test connecton is defined
        #########################################################################

        #########################################################################
        #Global Params

        $WSUSSQLServerName = $Global:ECSWSUSDatabaseConnection.WSUSSQLServerName
        Write-Verbose "WSUSSQLServerName = $($WSUSSQLServerName)"
        $WSUSDatabaseName = $Global:ECSWSUSDatabaseConnection.WSUSDatabaseName
        Write-Verbose "WSUSDatabaseName = $($WSUSDatabaseName)"
        $Credential = $Global:ECSWSUSDatabaseConnection.Credential
        
        #END Global Params
        #########################################################################

        #########################################################################
        #Executing SQL query to test the connection
        If ($OverallStatus -eq $true)
            {

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
                Write-Verbose "Testing the following query:"
                Write-Verbose "$($SQLQueryToRun)"
            
                Invoke-Expression -Command $($SQLCommandToRun)
                $ExecutedTestQueryWithNoErrors = $true
                $OverallStatus = $true
                }
            Catch
                {
                $ExecutedTestQueryWithNoErrors = $false
                $OverallStatus = $false
                }

            #Making sure you had results, if not we're throwing an error
            
            $MeaureSQLQueryCount = $SQLQuery | Measure-Object | Select-Object -ExpandProperty count
            If ($MeaureSQLQueryCount -eq 1)
                {
                $TestQueryHadResults = $true
                $OverallStatus = $true
                }
            Else
                {
                $TestQueryHadResults = $false
                $OverallStatus = $false
                }
            }
        #END Executing SQL query
        #########################################################################

        #########################################################################
        #Output results

        New-Object PSObject -Property @{
            VariableExists = $VariableExists
            ExecutedTestQueryWithNoErrors = $ExecutedTestQueryWithNoErrors
            TestQueryHadResults = $TestQueryHadResults
            OverallStatus = $OverallStatus
            }
        
        #END Output results
        #########################################################################

        }
    }