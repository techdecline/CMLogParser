# Implement your module commands in this script.

class CMLogObject {
    [String]$Message
    [String]$Context
    [datetime]$Date
    [String]$File
    [string]$Thread
    [string]$Type
    [string]$Component
}

function Split-ValuePair {
    param (
        # Select input string
        [Parameter(Mandatory)]
        [string]
        $ValuePair
    )
    if ($ValuePair -match "^.*=.*$") {
        $ValuePairArr = $ValuePair -split "="
        $returnHash = @{
            Key = $ValuePairArr[0]
            Value = if ($ValuePairArr[1] -ne '""') {$ValuePairArr[1] -replace '"',"" } else {$ValuePairArr[1]}
        }
        return $returnHash
    }
    else {
        return $null
    }
}

function Optimize-LogFile {
    param (
        [string[]]$LogFileContent
    )

    $newArr = @()
    foreach ($line in $LogFileContent) {
        if ($residue) {
            $newline = $residue + $line
            $newArr += $newline
            $residue = $null
        }
        else {
            if ($line -match ".*>$") {
                $newArr += $line
            }
            else {
                Write-Verbose "Unsupported Line break detected: $line"
                $residue = $line
            }
        }
    }
    return $newArr
}

function Open-CMLog {
    [CmdletBinding()]
    [outputtype([System.Object[]])]
    param (
        # This parameter contains the path to a ConfigMgr Log File
        [Parameter(Mandatory,ValueFromPipeline)]
        [ValidateScript({Test-Path $_})]
        [String]$CmLogFilePath
    )

    process {
        try {
            $cmLogObj = Optimize-LogFile -LogFileContent (Get-Content $CmLogFilePath -ErrorAction Stop)
            return $cmLogObj
        }
        catch [System.Management.Automation.ActionPreferenceStopException] {
            Write-Error "Could not open Log File"
            return $null
        }
    }
}

function Resolve-CMLogItem {
    [CmdletBinding()]
    param (
        # This parameter contains a line that needs to be parsed
        [Parameter(Mandatory,ValueFromPipeline)]
        [String]$LogFileLine
    )

    process {
        $logRaw = $LogFileLine -split "><"
        $logMessage = ($logRaw[0] -replace "^.*\[","") -replace "\].*$"

        $cmLogItem = New-Object CMLogObject
        $cmLogItem.Message = $logMessage

        $logData = @{}
        foreach ($logMetaDataItem in ($logRaw[1] -split "\s+")) {
            $valuePair = Split-ValuePair -ValuePair $logMetaDataItem
            if ($valuePair.Key -eq "Time") {
                $offsetDirection = if ($valuePair.Value -match "\+") {"+"} else {"-"}
                $time = ($valuePair.Value -split "\+|\-")[0]
                $offset = $offsetDirection + "" + ($valuePair.Value -split "\+|\-")[1]
            }
            $logData.Add($valuePair.Key,$valuePair.Value)
        }
        $cmLogItem.Date = $logData.date + " " + $time
        $cmLogItem.Date = $cmLogItem.Date.AddMinutes($offset)
        $cmLogItem.Component = $logData.component
        $cmLogItem.context = $logData.context
        $cmLogItem.Type = $logData.type
        $cmLogItem.Thread = $logData.thread
        $cmLogItem.file = $logData.file -replace ">$",""
        return $cmLogItem
    }
}

# Export only the functions using PowerShell standard verb-noun naming.
# Be sure to list each exported functions in the FunctionsToExport field of the module manifest file.
# This improves performance of command discovery in PowerShell.
Export-ModuleMember -Function Open-CMLog,Resolve-CMLogItem
