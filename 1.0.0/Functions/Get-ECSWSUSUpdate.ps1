Function Get-ECSWSUSUpdate
    {
    <#
    .SYNOPSIS
    This gets a update from the WSUS Database.  This object is needed for other commands, but can be used for standalone information.

    .DESCRIPTION
    This gets a update from the WSUS Database.  This object is needed for other commands, but can be used for standalone information. 

    .PARAMETER Update
    This is the naming pattern of the update you're querying.  

    It can be the updateid, the kb number, a security builitin,  or a pattern of general text in the default title of a given update

    .EXAMPLE
    This example gets any update with KB3150513 in the default title or the specific update with the id 423E965F-7870-457C-8C29-18D74EAC29B0
    Get-ECSWSUSUpdate -Update @("*KB3150513*","423E965F-7870-457C-8C29-18D74EAC29B0")

    #>
    [CmdletBinding()]
    

    Param
	    (
        #############################################################
        #Update

        [Parameter(
            ParameterSetName = "Update",
            ValueFromPipeline = $true,
            Mandatory=$false
            )]
        [ValidateNotNullorEmpty()]
        $Update = "%"

	    )

    Process
        {
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
        #Test connection state

        Try
            {
            Write-Verbose "Testing the WSUS database connectivity before querying WSUS"
            $TestWSUSConnectionState = Test-ECSWSUSDatabaseConnected
            If ($TestWSUSConnectionState.OverallStatus -eq $false)
                {
                Throw "Either you are not connected to the WSUS database, or we had an error.  Please run Test-ECSWSUSDatabaseConnected to determine the detailed status"
                }
            }
        Catch
            {
            Throw "Something went wrong with the testing your WSUS connection, exception message = $($_.Exception.Message)"

            }

        #END Test connection state
        #########################################################################

        
        #Loop through all updates
        Foreach ($UpdateToProcess in $Update)
            {
            #########################################################################
            #Replace any "*" for % in the update name

            If ($UpdateToProcess -match "\*")
                {
                Write-Verbose -Message "We found an asterix, in the update name $($UpdateToProcess), replacing with a percentage sign" 
                $UpdateToProcess = $UpdateToProcess -replace "\*","%"
                }

            #END Replace any "*" for % in the update name
            #########################################################################

            #########################################################################
            #Define dynamic SQL query

            $SQLQueryDefinition = @"
--Your SUSDB Name
Use SUSDB

SELECT [UpdateId]
      ,[RevisionNumber]
      ,[DefaultTitle]
      ,[DefaultDescription]
      ,[ClassificationId]
      ,[ArrivalDate]
      ,[CreationDate]
      ,[IsDeclined]
      ,[IsWsusInfrastructureUpdate]
      ,[MsrcSeverity]
      ,[PublicationState]
      ,[UpdateType]
      ,[UpdateSource]
      ,[KnowledgebaseArticle]
      ,[SecurityBulletin]
      ,[InstallationCanRequestUserInput]
      ,[InstallationRequiresNetworkConnectivity]
      ,[InstallationImpact]
      ,[InstallationRebootBehavior]
  FROM [SUSDB].[PUBLIC_VIEWS].[vUpdate]
  where
   (
   SecurityBulletin like '$($UpdateToProcess)'
   or
   DefaultTitle like '$($UpdateToProcess)'


"@

            #########################################################################
            #Test if the desired update pattern is a GUID

            Try
                {
                $UpdateToProcessInt = [GUID]$UpdateToProcess
                Write-Verbose "We identified a GUID"
                $SQLQueryDefinition += @"
 or
 UpdateId = '$($UpdateToProcessInt)'
"@

                }
            Catch
                {

                }

            #END Test if the desired update pattern is a GUID
            #########################################################################

            #########################################################################
            #Test if the desired update pattern is an int

            Try
                {
                $UpdateToProcessInt = [int]$UpdateToProcess
                Write-Verbose "We identified an int"
                $SQLQueryDefinition += @"
or
KnowledgebaseArticle = $($UpdateToProcess)
"@

                }
            Catch
                {
                }

            #END Test if the desired update pattern is an int
            #########################################################################

            #Adding the closing parentheses

$SQLQueryDefinition += @"
)
"@


            #END Define dynamic SQL query
            #########################################################################

            #########################################################################
            #Executing SQL query to get all updates
            Try
                {
                #Formulating base command
                $SQLCommandToRun = '$SQLQuery' + " = Invoke-Sqlcmd -ServerInstance $WSUSSQLServerName -Database $WSUSDatabaseName -AbortOnError" + ' -Query $SQLQueryDefinition' + ' -ErrorAction "Stop"'

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

                #Executing command
                Write-Verbose "Executing the following command: $($SQLCommandToRun)"
                Write-Verbose "The following query is being executed:"
                Write-Verbose $SQLQueryDefinition

                Invoke-Expression -Command $($SQLCommandToRun)

                #Making sure you had results, if not we're throwing an error
                $MeaureSQLQueryCount = $SQLQuery | Measure-Object | Select-Object -ExpandProperty count
                If ($MeaureSQLQueryCount -ge 1)
                    {
                    $SQLQuery
                    }
                Else
                    {
                    Throw "No results querying update $($Update)"
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
    }