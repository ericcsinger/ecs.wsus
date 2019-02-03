Function Get-ECSWSUSComputerTargetReport
    {
    <#
    .SYNOPSIS
    This provides a report of data similar to what you might find in the web console of WSUS

    .DESCRIPTION
    This provides a report of data similar to what you might find in the web console of WSUS

    .PARAMETER ComputerTargetObject
    This is the computer target object that you'll pipe from a command such as Get-ECSWSUSComputerTarget

    .PARAMETER IncludeNonApplicableUpdates
    By default, we only grab applicable updates.  There may be a reason i can't forsee thatto see ALL updates for a given computer, using this switch if that's the case.

    .PARAMETER UpdateApprovalAction
    This is to influence whether you only want to report on updates that are approved, not approved or any status.  We default to any.

    .PARAMETER DetailedReport
    By default, we only show a high level summary, which does not include the updates themselves.  If you want to see the individual updates installation state, use this switch.


    .EXAMPLE
    This example gets any computer with adm in the name, shows applicable updates only, that were set to install and we'll see details as well.
    Get-ECSWSUSComputerTarget -ComputerTargetName *adm* | Get-ECSWSUSComputerTargetReport -UpdateApprovalAction Install -DetailedReport

    .EXAMPLE
    This example, we'll get any adm computer, any approval action, and we'll also include the update status of ALL updates for this system.  We'll only show a summary report.
    Get-ECSWSUSComputerTarget -ComputerTargetName *adm* | Get-ECSWSUSComputerTargetReport -IncludeNonApplicableUpdates 



    #>
    [CmdletBinding()]
    

    Param
	    (
        #############################################################
        #ComputerTargetObject


        [Parameter(
            ValueFromPipeline = $true,
            Mandatory=$true
            )]

        [ValidateNotNullorEmpty()]
        $ComputerTargetObject,

        #############################################################
        #IncludeNonApplicableUpdates

        [Parameter(Mandatory=$false)]  
        [Switch]$IncludeNonApplicableUpdates = $false,


        #############################################################
        #UpdateApprovalAction
        [Parameter(Mandatory=$false)]
        [ValidateSet("All","Install","NotApproved")] 
        [String]$UpdateApprovalAction = "All",

        #############################################################
        #ReportDetailLevel

        [Parameter(Mandatory=$false)]
        [switch]$DetailedReport = $false

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

        Write-Verbose "Testing the WSUS database connectivity before querying WSUS"
        $TestWSUSConnectionState = Test-ECSWSUSDatabaseConnected
        If ($TestWSUSConnectionState.OverallStatus -eq $false)
            {
            Throw "Either you are not connected to the WSUS database, or we had an error.  Please run Test-ECSWSUSDatabaseConnected to determine the detailed status"
            }

        #END Test connection state
        #########################################################################


        Foreach ($ComputerTarget in $ComputerTargetObject)

            {

            #########################################################################
            #Define dynamic SQL query

            #Creating two different base queries based on whether we're doing a detailed report or a summary report only
            If ($DetailedReport -eq $true)
                {
                $SQLQueryToRun = @"
Use $($WSUSDatabaseName)

DECLARE @ComputerTargetId nvarchar(256);
SET @ComputerTargetId = '$($ComputerTarget.ComputerID)';

SELECT [PUBLIC_VIEWS].[vUpdateEffectiveApprovalPerComputer].[UpdateId]
      ,[PUBLIC_VIEWS].[vUpdateEffectiveApprovalPerComputer].[ComputerTargetId]
      ,[PUBLIC_VIEWS].[vUpdateEffectiveApprovalPerComputer].[UpdateApprovalId]

	  ,[PUBLIC_VIEWS].[vUpdateApproval].[Action]

	  ,[PUBLIC_VIEWS].[vUpdateInstallationInfo].[State] 
      ,CASE 
		WHEN State = 0 THEN 'Unknown'
		WHEN State = 1 THEN 'NotApplicable'
		When State = 2 THEN 'NotInstalled'
		WHEN State = 3 THEN 'Downloaded'
		WHEN State = 4 THEN 'Installed'
		WHEN State = 5 THEN 'Failed'
		WHEN State = 6 THEN 'InstalledPendingReboot'
		Else 'No Match'
		end as FriendlyState

	  ,[PUBLIC_VIEWS].[vUpdate].[ArrivalDate]
	  ,[PUBLIC_VIEWS].[vUpdate].[CreationDate]
	  ,[PUBLIC_VIEWS].[vUpdate].[DefaultDescription]
	  ,[PUBLIC_VIEWS].[vUpdate].[DefaultTitle]
	  ,[PUBLIC_VIEWS].[vUpdate].[InstallationCanRequestUserInput]
	  ,[PUBLIC_VIEWS].[vUpdate].[InstallationImpact]
	  ,[PUBLIC_VIEWS].[vUpdate].[InstallationRebootBehavior]
	  ,[PUBLIC_VIEWS].[vUpdate].[InstallationRequiresNetworkConnectivity]
	  ,[PUBLIC_VIEWS].[vUpdate].[IsDeclined]
	  ,[PUBLIC_VIEWS].[vUpdate].[IsWsusInfrastructureUpdate]
	  ,[PUBLIC_VIEWS].[vUpdate].[KnowledgebaseArticle]
	  ,[PUBLIC_VIEWS].[vUpdate].[MsrcSeverity]
	  ,[PUBLIC_VIEWS].[vUpdate].[PublicationState]
	  ,[PUBLIC_VIEWS].[vUpdate].[RevisionNumber]
	  ,[PUBLIC_VIEWS].[vUpdate].[SecurityBulletin]
	  ,[PUBLIC_VIEWS].[vUpdate].[UpdateSource]
	  ,[PUBLIC_VIEWS].[vUpdate].[UpdateType]
	  

  FROM [PUBLIC_VIEWS].[vUpdateEffectiveApprovalPerComputer]


--Bring in update approval state
Inner join [PUBLIC_VIEWS].[vUpdateApproval] on
(
[PUBLIC_VIEWS].[vUpdateApproval].[UpdateApprovalId] = [PUBLIC_VIEWS].[vUpdateEffectiveApprovalPerComputer].[UpdateApprovalId]
)

--Bring in the installation state
Inner join [PUBLIC_VIEWS].[vUpdateInstallationInfo] on
(
[PUBLIC_VIEWS].[vUpdateInstallationInfo].[ComputerTargetId] = [PUBLIC_VIEWS].[vUpdateEffectiveApprovalPerComputer].[ComputerTargetId]
and
[PUBLIC_VIEWS].[vUpdateInstallationInfo].[UpdateId] = [PUBLIC_VIEWS].[vUpdateEffectiveApprovalPerComputer].[UpdateId]
)

--Bring in update information
Inner Join [PUBLIC_VIEWS].[vUpdate] on
(
[PUBLIC_VIEWS].[vUpdate].[UpdateId] = [PUBLIC_VIEWS].[vUpdateEffectiveApprovalPerComputer].[UpdateId]
)


Where
[PUBLIC_VIEWS].[vUpdateEffectiveApprovalPerComputer].[ComputerTargetId] = @ComputerTargetId 
"@
            }
        Else
            {
            $SQLQueryToRun = @"
Use $($WSUSDatabaseName)

DECLARE @ComputerTargetId nvarchar(256);
SET @ComputerTargetId = '$($ComputerTarget.ComputerID)';

SELECT [PUBLIC_VIEWS].[vUpdateApproval].[Action]
	  ,[PUBLIC_VIEWS].[vUpdateInstallationInfo].[State] 


  FROM [PUBLIC_VIEWS].[vUpdateEffectiveApprovalPerComputer]


--Bring in update approval state
Inner join [PUBLIC_VIEWS].[vUpdateApproval] on
(
[PUBLIC_VIEWS].[vUpdateApproval].[UpdateApprovalId] = [PUBLIC_VIEWS].[vUpdateEffectiveApprovalPerComputer].[UpdateApprovalId]
)

--Bring in the installation state
Inner join [PUBLIC_VIEWS].[vUpdateInstallationInfo] on
(
[PUBLIC_VIEWS].[vUpdateInstallationInfo].[ComputerTargetId] = [PUBLIC_VIEWS].[vUpdateEffectiveApprovalPerComputer].[ComputerTargetId]
and
[PUBLIC_VIEWS].[vUpdateInstallationInfo].[UpdateId] = [PUBLIC_VIEWS].[vUpdateEffectiveApprovalPerComputer].[UpdateId]
)


Where
[PUBLIC_VIEWS].[vUpdateEffectiveApprovalPerComputer].[ComputerTargetId] = @ComputerTargetId 
"@

            }

            #Applicable Updates only
            If ($IncludeNonApplicableUpdates -eq $true)
                {
                Write-Verbose "IncludeNonApplicableUpdates = $true"
                }
            Else
                {
                Write-Verbose "IncludeNonApplicableUpdates = $false"
                                 
                $SQLQueryToRun += @"
and
[PUBLIC_VIEWS].[vUpdateInstallationInfo].[State] != 1
"@
                }


            #Approved Updates only
            Write-Verbose "UpdateApprovalAction = $($UpdateApprovalAction)"
            If ($UpdateApprovalAction -ne "All")
                {
                $SQLQueryToRun += @"
and 
[PUBLIC_VIEWS].[vUpdateApproval].[Action] = '$($UpdateApprovalAction)'
"@
                }


            #END Define dynamic SQL query
            #########################################################################

            #########################################################################
            #Executing SQL query
            Try
                {
                #Formulating base command
                $SQLCommandToRun = '$SQLQuery' + " = Invoke-Sqlcmd -ServerInstance $WSUSSQLServerName -Database $WSUSDatabaseName -AbortOnError" + ' -Query $SQLQueryToRun' + ' -ErrorAction "Stop"'

                #Executing command
                Write-Verbose "Executing the following command: $($SQLCommandToRun)"
                Write-Verbose "The following query is being executed:"
                Write-Verbose $SQLQueryToRun

                #Running query
                Invoke-Expression -Command $($SQLCommandToRun)

                #Making sure you had results, if not we're throwing an error
                $MeaureSQLQueryCount = $SQLQuery | Measure-Object | Select-Object -ExpandProperty count
                If ($MeaureSQLQueryCount -eq 0)
                    {
                    Throw "No results querying computer target $($ComputerTarget.FullDomainName)"
                    }

                }
            Catch
                {
                Throw "Something went wrong with the SQL query, exception message = $($_.Exception.Message)"
                }

            #END Executing SQL query
            #########################################################################

            #########################################################################
            #Summarizing results

            #Documenting what the values mean for "state"
            <#
            #Computer installation state from fnUpdateInstallationStateMap function
            0 = Unknown
            1 = NotApplicable
            2 = NotInstalled
            3 = Downloaded
            4 = Installed
            5 = Failed
            6 = InstalledPendingReboot
            #>

            


            #Getting a count of all the installation states for all applicable updates
            $AllUpdatesCount = $SQLQuery | Measure-Object | Select-Object -ExpandProperty count
            $AllApplicableUpdatesCount = $SQLQuery | Where-Object {$_.state -ne 1} | Measure-Object | Select-Object -ExpandProperty count
            $AllApplicableUnknown = $SQLQuery | Where-Object {$_.state -eq 0} | Measure-Object | Select-Object -ExpandProperty count
            $AllApplicableNotApplicable = $SQLQuery | Where-Object {$_.state -eq 1} | Measure-Object | Select-Object -ExpandProperty count
            $AllApplicableNotInstalled = $SQLQuery | Where-Object {$_.state -eq 2} | Measure-Object | Select-Object -ExpandProperty count
            $AllApplicableDownloaded = $SQLQuery | Where-Object {$_.state -eq 3} | Measure-Object | Select-Object -ExpandProperty count
            $AllApplicableInstalled = $SQLQuery | Where-Object {$_.state -eq 4} | Measure-Object | Select-Object -ExpandProperty count
            $AllApplicableFailed = $SQLQuery | Where-Object {$_.state -eq 5} | Measure-Object | Select-Object -ExpandProperty count
            $AllApplicableInstalledPendingReboot = $SQLQuery | Where-Object {$_.state -eq 6} | Measure-Object | Select-Object -ExpandProperty count

            #Summarize the status of the updates
            $AllApplicableUpdatesMissingCount = $AllApplicableUpdatesCount - $AllApplicableInstalled
            If ($AllApplicableUpdatesMissingCount -eq 0)
                {
                $AllUpdatesInstalled = $True
                }
            Else
                {
                $AllUpdatesInstalled = $false
                }

            #Let's create an object to organize the results a bit
            $Report = New-Object PSObject -Property @{
                ComputerTagetName = $($ComputerTarget.FullDomainName)
                ComputerLastSyncTime = $($ComputerTarget.LastSyncTime)
                ComputerLastReportedStatusTime = $($ComputerTarget.LastReportedStatusTime)
                ComputerLastEffectiveLastDetectionTime = $($ComputerTarget.EffectiveLastDetectionTime)
                ComputerTagetDetails = $ComputerTarget
                UpdatesSummaryCount = New-Object PSObject -Property @{
                    Unknown = $AllApplicableUnknown
                    NotApplicable = $AllApplicableNotApplicable 
                    NotInstalled = $AllApplicableNotInstalled
                    Downloaded = $AllApplicableDownloaded
                    Installed = $AllApplicableInstalled
                    Failed = $AllApplicableFailed 
                    InstalledPendingReboot = $AllApplicableInstalledPendingReboot
                    }
                MissingUpdatesCount = $AllApplicableUpdatesMissingCount
                AllUpdatesInstalled = $AllUpdatesInstalled
                }

            #End Summarizing results
            #########################################################################

            #########################################################################
            #Add details to the report if desired

            If ($DetailedReport -eq $true)
                {
                $Report | Add-Member -MemberType NoteProperty -Name UpdateDetails -Value $SQLQuery
                }

            #End Add details to the report if desired
            #########################################################################

            #########################################################################
            #Output Report

            $Report

            #End Output Report
            #########################################################################

            }
        }
    }