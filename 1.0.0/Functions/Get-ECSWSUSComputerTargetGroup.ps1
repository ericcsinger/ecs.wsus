Function Get-ECSWSUSComputerTargetGroup
    {
    <#
    .SYNOPSIS
    This gets a computer target group from the WSUS Database.  

    .DESCRIPTION
    This gets a computer target group from the WSUS Database. 

    .PARAMETER ComputerTargetGroupName
    This is the naming pattern of the groups you're querying.  

    .EXAMPLE
    This example gets any computer with wks in the name with a timeout of 100 seconds and uses SQLAuth
    Get-ECSWSUSComputerTargetGroup -ComputerTargetGroupName "*wks*"

    .EXAMPLE
    This example gets any computer with wks and pc in the name with not timeout and uses passthru auth
    Get-ECSWSUSComputerTargetGroup -ComputerTargetGroupName @("*wks*","*pc-*")



    #>
    [CmdletBinding()]
    

    Param
	    (
        #############################################################
        #ComputerTargetGroupName

        [Parameter(
            ValueFromPipeline = $true,
            Mandatory=$false
            )]
        [ValidateNotNullorEmpty()]
        $ComputerTargetGroupName = "*"
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

SELECT [dbo].[tbTargetGroup].[TargetGroupTypeID]
      ,[dbo].[tbTargetGroup].[Name]
      ,[dbo].[tbTargetGroup].[Description]
      ,[TargetGroupID]
      ,[OrderValue]
      ,[IsBuiltin]
      ,[ParentGroupID]
      ,[GroupPriority]

--Target Group type info
	  ,[dbo].[tbTargetGroupType].[Name] as FriendlyGroupType

  FROM [dbo].[tbTargetGroup]

  Inner join [dbo].[tbTargetGroupType] on
  [dbo].[tbTargetGroupType].[TargetGroupTypeID] = [dbo].[tbTargetGroup].[TargetGroupTypeID]

  where [dbo].[tbTargetGroup].[Name] like @TargetGroupName

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
                    $SQLQuery
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