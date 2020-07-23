#requires -version 6
using namespace System.Collections
using namespace System.Collections.Generic
using module Leet.Build.Common
using module Leet.Build.Extensibility

Set-StrictMode -Version 2
Import-LocalizedData -BindingVariable LocalizedData -FileName Leet.Build.Resources.psd1

$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = {
    Remove-Module Leet.Build.* -Force
}


##################################################################################################################
# Public Commands
##################################################################################################################


function Build-Repository {
    <#
    .SYNOPSIS
    Performs a build operation on all projects located in the specified repository.
    #>
    [CmdletBinding(PositionalBinding = $False)]

    param (
        # The path to the repository root folder.
        [Parameter(HelpMessage = "Provide path to the repository's root directory.",
                   Position = 0,
                   Mandatory = $True,
                   ValueFromPipeline = $False,
                   ValueFromPipelineByPropertyName = $True)]
        [ValidateContainerPathAttribute()]
        [String]
        $RepositoryRoot,

        # Name of the build task to invoke.
        [Parameter(Position = 1,
                   Mandatory = $True,
                   ValueFromPipeline = $False,
                   ValueFromPipelineByPropertyName = $True)]
        [ValidateIdentifierOrEmptyAttribute()]
        [AllowEmptyString()]
        [String]
        $TaskName,

        # Dictionary of buildstrapper arguments (including dynamic ones) that have been successfully bound.
        [Parameter(Position = 2,
                   Mandatory = $False,
                   ValueFromPipeline = $False,
                   ValueFromPipelineByPropertyName = $True)]
        [IDictionary]
        $NamedArguments,

        # Arguments to be passed to the target.
        [Parameter(Position = 3,
                   Mandatory = $False,
                   ValueFromPipeline = $False,
                   ValueFromPipelineByPropertyName = $True)]
        [String[]]
        $UnknownArguments)

    begin {
        Leet.Build.Common\Import-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
    }

    process {
        Leet.Build.Logging\Write-Invocation -Invocation $MyInvocation
        Leet.Build.Arguments\Set-CommandArgumentSet -RepositoryRoot $RepositoryRoot -NamedArguments $NamedArguments -UnknownArguments $UnknownArguments
        Initialize-WellKnownParameters -RepositoryRoot $RepositoryRoot
        Import-RepositoryExtension -RepositoryRoot $RepositoryRoot

        $TaskName = Leet.Build.Arguments\Find-CommandArgument -ParameterName TaskName -DefaultValue $TaskName
        $projectPath = Leet.Build.Arguments\Find-CommandArgument -ParameterName SourceRoot

        Leet.Build.Extensibility\Resolve-Project $projectPath $LeetBuildRepository $TaskName | ForEach-Object {
            $projectPath, $extensionName = $_
            Leet.Build.Extensibility\Invoke-BuildTask $extensionName $TaskName $projectPath
        }
    }
}


##################################################################################################################
# Private Commands
##################################################################################################################


function Initialize-WellKnownParameters {
    <#
    .SYNOPSIS
    Initializes a set of well known parameters with its default values.
    #>
    [CmdletBinding(PositionalBinding = $False)]

    param (
        # The directory to the repository's root directory path.
        [Parameter(HelpMessage = "Provide path to the repository's root directory.",
                   Position = 0,
                   Mandatory = $True,
                   ValueFromPipeline = $False,
                   ValueFromPipelineByPropertyName = $False)]
        [String]
        $RepositoryRoot)

    process {
        Leet.Build.Arguments\Set-CommandArgument 'ArtifactsRoot' (Join-Path $RepositoryRoot 'artifacts') -ErrorAction SilentlyContinue
        Leet.Build.Arguments\Set-CommandArgument 'SourceRoot' (Join-Path $RepositoryRoot 'src') -ErrorAction SilentlyContinue
        Leet.Build.Arguments\Set-CommandArgument 'TestRoot' (Join-Path $RepositoryRoot 'test') -ErrorAction SilentlyContinue
    }
}


function Import-RepositoryExtension {
    <#
    .SYNOPSIS
    Imports Leet.Build.Repository extension module from the specified repository.
    #>
    [CmdletBinding(PositionalBinding = $False)]

    param (
        # The directory to the repository's root directory path.
        [Parameter(HelpMessage = "Provide path to the repository's root directory.",
                   Position = 0,
                   Mandatory = $True,
                   ValueFromPipeline = $False,
                   ValueFromPipelineByPropertyName = $False)]
        [String]
        $RepositoryRoot)

    process {
        Get-ChildItem -Path $RepositoryRoot -Filter "$LeetBuildRepository.ps1" -Recurse | ForEach-Object {
            . "$_"
        }
    }
}


Export-ModuleMember -Function '*' -Variable '*' -Alias '*' -Cmdlet '*'
