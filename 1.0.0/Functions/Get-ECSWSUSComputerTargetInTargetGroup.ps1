Function Get-ECSWSUSComputerTargetInTargetGroup
    {
    <#
    .SYNOPSIS
    This gets a computer target that is located in a given computer target group(s)

    .DESCRIPTION
    This gets a computer target that is located in a given computer target group(s)

    .PARAMETER ComputerTargetGroupName
    This is the naming pattern of the groups you're querying.  

    .PARAMETER TargetIsExplicitMember
    This is used to determine if you want to get computers that are inderect or direct members of a given group.

    1 = direct member
    0 = indirect member.

    Example of a direct member would be ".\Production\SQL\app1", would only show computer groups that are located in the app1 group.

    Example of an indirect member would be if you specified ".\Production\SQL\app1", you would get all computer in production + SQL + app1

    .EXAMPLE
    This example gets a direct membership for all computers that are members of a group name wks-p*
    Get-ECSWSUSComputerTargetInTargetGroup -ComputerTargetGroupName "wks-p*" -TargetIsExplicitMember 1

    .EXAMPLE
    This example gets any computer with wks and pc in the name with not timeout and uses passthru auth
    Get-ECSWSUSComputerTargetInTargetGroup -ComputerTargetGroupName "production\wks-p*" -TargetIsExplicitMember 0
    
    This would get all computers that have a group name of wks-p* + anything in production as well.


    #>
    [CmdletBinding()]
    

    Param
	    (
        #############################################################
        #ComputerTargetInTargetGroupName

        [Parameter(
            ValueFromPipeline = $true,
            Mandatory=$false
            )]
        [ValidateNotNullorEmpty()]
        $ComputerTargetGroupName = "*",

        [Parameter(
            Mandatory=$false
            )]
        [ValidateSet(0,1)] 
        $TargetIsExplicitMember = 1
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

        Foreach ($ComputerTargetGroup in $ComputerTargetGroupName)
            {
            #########################################################################
            #Replace any "*" for % in the computer target name

            If ($ComputerTargetGroup -match "\*")
                {
                Write-Verbose -Message "We found an asterix, in the computer target name $($ComputerTargetGroup), replacing with a percentage sign" 
                $ComputerTargetGroup = $ComputerTargetGroup -replace "\*","%"
                }

            #Replace any "*" for % in the computer target name
            #########################################################################

            #########################################################################
            #Define dynamic SQL query

            $SQLQueryDefinition = @"
--Your SUSDB Name
Use $($WSUSDatabaseName)

--Your Computer Name pattern
DECLARE @TargetGroupName nvarchar(256);
SET @TargetGroupName = '$($ComputerTargetGroup)';

--Your Computer Name pattern
DECLARE @TargetIsExplicitMember nvarchar(256);
SET @TargetIsExplicitMember = '$($TargetIsExplicitMember)';



SELECT [dbo].[tbTargetInTargetGroup].[TargetGroupID]
      ,[dbo].[tbTargetInTargetGroup].[TargetID]
      ,[dbo].[tbTargetInTargetGroup].[IsExplicitMember]

	  ,[dbo].[tbComputerTarget].[FullDomainName]

	  ,[dbo].[tbTargetGroup].[Name] as GroupName

  FROM [dbo].[tbTargetInTargetGroup]

  --Join Target to Target ID
  inner join [dbo].[tbComputerTarget] on
  [dbo].[tbComputerTarget].[TargetID] = [dbo].[tbTargetInTargetGroup].[TargetID]

  --Join TargetGroup id to Target Group 
  inner join [dbo].[tbTargetGroup] on
  [dbo].[tbTargetGroup].[TargetGroupID] = [dbo].[tbTargetInTargetGroup].[TargetGroupID]

  Where [dbo].[tbTargetInTargetGroup].[IsExplicitMember] = @TargetIsExplicitMember and [dbo].[tbTargetGroup].[Name] like @TargetGroupName

"@

            #END Define dynamic SQL query
            #########################################################################

            #########################################################################
            #Executing SQL query
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
                    Get-ECSWSUSComputerTarget -ComputerTarget $($SQLQuery.FullDomainName) 
                    }
                Else
                    {
                    Throw "No results querying computer target $($ComputerTargetGroup)"
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