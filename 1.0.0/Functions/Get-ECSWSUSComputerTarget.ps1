Function Get-ECSWSUSComputerTarget
    {
    <#
    .SYNOPSIS
    This gets a computer target from the WSUS Database.  This object is needed for other commands, but can be used for standalone information.

    .DESCRIPTION
    This gets a computer target from the WSUS Database.  This object is needed for other commands, but can be used for standalone information. 

    .PARAMETER ComputerTarget
    This is the naming pattern of the systems you're querying.  Don't foget that WSUS stores the FQDN of most systems, so you might want to specificy computername*.

    You can also specificy other naming patterns like compu*Name*

    .EXAMPLE
    This example gets any computer with wks in the name with a timeout of 100 seconds and uses SQLAuth
    Get-ECSWSUSComputerTarget -ComputerTarget "*wks*"

    .EXAMPLE
    This example gets any computer with wks and pc in the name with not timeout and uses passthru auth
    Get-ECSWSUSComputerTarget -ComputerTarget @("*wks*","*pc-*")



    #>
    [CmdletBinding()]
    

    Param
	    (
        #############################################################
        #ComputerTarget

        [Parameter(
            ParameterSetName = "ComputerTarget",
            ValueFromPipeline = $true,
            Mandatory=$false
            )]
        [ValidateNotNullorEmpty()]
        $ComputerTarget = "*"

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

        
        #Loop through all computer targets
        Foreach ($ComputerTargetToProcess in $ComputerTarget)
            {
            #########################################################################
            #Replace any "*" for % in the computer target name

            If ($ComputerTargetToProcess -match "\*")
                {
                Write-Verbose -Message "We found an asterix, in the computer target name $($ComputerTargetToProcess), replacing with a percentage sign" 
                $ComputerTargetToProcess = $ComputerTargetToProcess -replace "\*","%"
                }

            #END Replace any "*" for % in the computer target name
            #########################################################################

            #########################################################################
            #Test if it's an int

            Try
                {
                $ComputerTargetToProcessInt = [int]$ComputerTargetToProcess
                }
            Catch
                {
                $ComputerTargetToProcessInt = ""
                }

            #END Test if it's an int
            #########################################################################

            #########################################################################
            #Define dynamic SQL query

            $SQLQueryDefinition = @"
--Your SUSDB Name
Use SUSDB

SELECT [dbo].[tbComputerTarget].[TargetID]
      ,[dbo].[tbComputerTarget].[ComputerID]
      ,[dbo].[tbComputerTarget].[SID]
      ,[dbo].[tbComputerTarget].[LastSyncTime]
      ,[dbo].[tbComputerTarget].[LastReportedStatusTime]
      ,[dbo].[tbComputerTarget].[LastReportedRebootTime]
      ,[dbo].[tbComputerTarget].[IPAddress]
      ,[dbo].[tbComputerTarget].[FullDomainName]
      ,[dbo].[tbComputerTarget].[IsRegistered]
      ,[dbo].[tbComputerTarget].[LastInventoryTime]
      ,[dbo].[tbComputerTarget].[LastNameChangeTime]
      ,[dbo].[tbComputerTarget].[EffectiveLastDetectionTime]
      ,[dbo].[tbComputerTarget].[ParentServerTargetID]
      ,[dbo].[tbComputerTarget].[LastSyncResult]

--Computer Target Details
	  ,[dbo].[tbComputerTargetDetail].[OSMajorVersion]
      ,[dbo].[tbComputerTargetDetail].[OSMinorVersion]
      ,[dbo].[tbComputerTargetDetail].[OSBuildNumber]
      ,[dbo].[tbComputerTargetDetail].[OSServicePackMajorNumber]
      ,[dbo].[tbComputerTargetDetail].[OSServicePackMinorNumber]
      ,[dbo].[tbComputerTargetDetail].[OSLocale]
      ,[dbo].[tbComputerTargetDetail].[ComputerMake]
      ,[dbo].[tbComputerTargetDetail].[ComputerModel]
      ,[dbo].[tbComputerTargetDetail].[BiosVersion]
      ,[dbo].[tbComputerTargetDetail].[BiosName]
      ,[dbo].[tbComputerTargetDetail].[BiosReleaseDate]
      ,[dbo].[tbComputerTargetDetail].[ProcessorArchitecture]
      ,[dbo].[tbComputerTargetDetail].[LastStatusRollupTime]
      ,[dbo].[tbComputerTargetDetail].[LastReceivedStatusRollupNumber]
      ,[dbo].[tbComputerTargetDetail].[LastSentStatusRollupNumber]
      ,[dbo].[tbComputerTargetDetail].[SamplingValue]
      ,[dbo].[tbComputerTargetDetail].[CreatedTime]
      ,[dbo].[tbComputerTargetDetail].[SuiteMask]
      ,[dbo].[tbComputerTargetDetail].[OldProductType]
      ,[dbo].[tbComputerTargetDetail].[NewProductType]
      ,[dbo].[tbComputerTargetDetail].[SystemMetrics]
      ,[dbo].[tbComputerTargetDetail].[ClientVersion]
      ,[dbo].[tbComputerTargetDetail].[TargetGroupMembershipChanged]
      ,[dbo].[tbComputerTargetDetail].[OSFamily]
      ,[dbo].[tbComputerTargetDetail].[OSDescription]
      ,[dbo].[tbComputerTargetDetail].[OEM]
      ,[dbo].[tbComputerTargetDetail].[DeviceType]
      ,[dbo].[tbComputerTargetDetail].[FirmwareVersion]
      ,[dbo].[tbComputerTargetDetail].[MobileOperator]

--Computer Target Group Name
	,[dbo].[tbTargetGroup].[Name] as TargetGroupName

  FROM [dbo].[tbComputerTarget]

--Computer Target Details
Inner Join [dbo].[tbComputerTargetDetail] on
[dbo].[tbComputerTargetDetail].[TargetID] = [dbo].[tbComputerTarget].[TargetID]

--Computer Target to Computer Target Group mapping (computer target group GUID only)
Inner Join [dbo].[tbTargetInTargetGroup] on
[dbo].[tbTargetInTargetGroup].[TargetID] = [dbo].[tbComputerTarget].[TargetID]

--Computer Target group GUID to Computer Target group name
Inner Join [dbo].[tbTargetGroup] on
[dbo].[tbTargetGroup].[TargetGroupID] = [dbo].[tbTargetInTargetGroup].[TargetGroupID]



Where [dbo].[tbTargetInTargetGroup].[IsExplicitMember] = 1
and
(
[dbo].[tbComputerTarget].[ComputerID] = '$($ComputerTargetToProcess)'
or
[dbo].[tbComputerTarget].[FullDomainName] like '$($ComputerTargetToProcess)'
or
[dbo].[tbComputerTarget].[TargetID] = '$($ComputerTargetToProcessInt)'
)


"@


            #END Define dynamic SQL query
            #########################################################################

            #########################################################################
            #Executing SQL query to get all computer targets
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
                    Throw "No results querying computer target $($ComputerTarget)"
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