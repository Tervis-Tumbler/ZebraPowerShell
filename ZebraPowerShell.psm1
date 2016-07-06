# CTRL + M to Expand or Collapse all

function Send-NetworkData {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $Computer,

        [Parameter(Mandatory)]
        [ValidateRange(1, 65535)]
        [Int16]
        $Port,

        [Parameter(ValueFromPipeline)]
        [string[]]
        $Data,

        [System.Text.Encoding]
        $Encoding = [System.Text.Encoding]::ASCII,

        [TimeSpan]
        $Timeout = [System.Threading.Timeout]::InfiniteTimeSpan
    ) 

    begin {
        # establish the connection and a stream writer
        $Client = New-Object -TypeName System.Net.Sockets.TcpClient
        $Client.Connect($Computer, $Port)
        $Stream = $Client.GetStream()
        $Writer = New-Object -Type System.IO.StreamWriter -ArgumentList $Stream, $Encoding, $Client.SendBufferSize, $true
    }

    process {
        # send all the input data
        foreach ($Line in $Data) {
            $Writer.WriteLine($Line)
        }
    }

    end {
        # flush and close the connection send
        $Writer.Flush()
        #
        sleep 1

        # read the response
        $Stream.ReadTimeout = [System.Threading.Timeout]::Infinite
        if ($Timeout -ne [System.Threading.Timeout]::InfiniteTimeSpan) {
            $Stream.ReadTimeout = $Timeout.TotalMilliseconds
        }

        $Result = ''
        $Buffer = New-Object -TypeName System.Byte[] -ArgumentList $Client.ReceiveBufferSize
        do {
            try {
                $ByteCount = $Stream.Read($Buffer, 0, $Buffer.Length)
            } catch [System.IO.IOException] {
                $ByteCount = 0
            }
            if ($ByteCount -gt 0) {
                $Result += $Encoding.GetString($Buffer, 0, $ByteCount)
            }
        } while ($Stream.DataAvailable) 

        Write-Output $Result
        
        # cleanup
        $Writer.Dispose()
        $Client.Client.Shutdown('Send')

        $Stream.Dispose()
        $Client.Dispose()
    }

}
function Send-NetworkDataNoReply {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][string]$Computer,
        [Parameter(Mandatory)]
        [ValidateRange(1, 65535)][Int16]$Port,
        [Parameter(Mandatory)][string[]]$Data,
        [System.Text.Encoding]$Encoding = [System.Text.Encoding]::ASCII
    ) 

    begin {
        # establish the connection and a stream writer
        $Client = New-Object -TypeName System.Net.Sockets.TcpClient
        $Client.Connect($Computer, $Port)
        $Stream = $Client.GetStream()
        $Writer = New-Object -Type System.IO.StreamWriter -ArgumentList $Stream, $Encoding, $Client.SendBufferSize, $true
    }

    process {
        # send all the input data
        foreach ($Line in $Data) {
            $Writer.WriteLine($Line)
        }
    }

    end {
        # flush and close the connection send
        $Writer.Flush()
        #
        sleep 1
        # cleanup
        $Writer.Dispose()
        $Client.Client.Shutdown('Send')

        $Stream.Dispose()
        $Client.Dispose()
    }

}
function Wait-PrinterAVailable{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][string]$PrinterName
    )

    While (Test-NetConnection $PrinterName -Port 9100| ? { $_.TcpTestSucceeded -eq $false } ){
      Write-Verbose "waiting"
      Start-Sleep -Milliseconds 100
    }
}
function Get-ZebraPrinters {
$PrintServer = "Disney"
$DriverNameMatchString = "ZDesigner*"
$DriverNamesToExcludeMatchString = "*ZDesigner LP 2844*"
$DeviceTypesToExcludeMatchString = "Print3D"
    
$PrinterObjects = Get-Printer -ComputerName "Disney" | where {$_.DriverName -like $DriverNameMatchString -and $_.DriverName -notlike $DriverNamesToExcludeMatchString -and $_.DeviceType -notlike $DeviceTypesToExcludeMatchString}
$PortNames = $PrinterObjects.PortName
$PortObjects = Foreach ($PortName in $PortNames) {Get-WmiObject -Class Win32_TCPIPPrinterPort -ComputerName Disney -Filter "Name='$PortName'"}
$PortIPs = $PortObjects.hostaddress
}
function Get-DisneyZebraConfigs{
    Get-ZebraPrinters
    $SavePath="C:\Users\alozano\Documents\WindowsPowerShell\Scripts\Zebra\Get-DisneyZebraConfigs File Dump\"
    $Data = "^XA^HH^XZ"

    Foreach ($PortIP in $PortIPs){
        $Date = Get-Date -Format yyyyMMdd_hhmmtt
        if (Test-Connection -ComputerName $PortIP -Count 1 -BufferSize 16 -Delay 1 -quiet -ErrorAction SilentlyContinue){
        Send-NetworkData -Data $Data -Computer $PortIP -Port 9100 | Out-File -FilePath "$SavePath$PortIP`_$Date.json" -Append
        }
    }
}
function Send-TCPtoZebra{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $Computer,

        [Parameter(Mandatory)]
        [ValidateRange(1, 65535)]
        [Int16]
        $Port,

        [Parameter(ValueFromPipeline)]
        [string[]]
        $Data
    )
    $Port=9100
    
if (Test-Connection -ComputerName $PortIP -Count 1 -BufferSize 16 -Delay 1 -quiet -ErrorAction SilentlyContinue)
        {
        Send-NetworkData -Data $Data -Computer $PortIP -Port $Port
        }
}
function Send-TCPtoZebraNoReply{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $Computer,

        [Parameter(Mandatory)]
        [ValidateRange(1, 65535)]
        [Int16]
        $Port,

        [Parameter(ValueFromPipeline)]
        [string[]]
        $Data
    )
    $Port=9100
    
if (Test-Connection -ComputerName $PortIP -Count 1 -BufferSize 16 -Delay 1 -quiet -ErrorAction SilentlyContinue)
        {
        Send-NetworkDataNoReply -Data $Data -Computer $PortIP -Port $Port
        }
}
function Send-TwinPrintCalibrationCommands{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][string]$TwinPrintTop,
        [Parameter(Mandatory)][string]$TwinPrintBottom
        )

    $Port = 9100
    $Data = "~JC"

    $ScriptBlock = {
        param($Port, $Data, $PrintEngineName)

        Send-NetworkDataNoReply -Computer $PrintEngineName -Port $Port -Data $Data
    }

    Start-Job -Name "TwinPrintTop_Calibration" -ScriptBlock $ScriptBlock -ArgumentList $Port, $Data, $TwinPrintTop -Verbose
    Start-Job -Name "TwinPrintBottom_Calibration" -ScriptBlock $ScriptBlock -ArgumentList $Port, $Data, $TwinPrintBottom -Verbose
}
function Start-TwinPrintCalibration{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][string]$TwinPrintTop,
        [Parameter(Mandatory)][string]$TwinPrintBottom
        )

    $Port = 9100

    #SET BOTTOM PRINT SETTINGS TO MEDIA-TYPE "NON-CONTINUOUS"
    $Data = "^XA^MNw^XZ"
    Send-NetworkDataNoReply -Computer $TwinPrintBottom -Port $Port -Data $Data

    Start-Sleep -Milliseconds 300

    #Clear Buffer
    $Data = "~JA"
    Send-NetworkDataNoReply -Computer $TwinPrintBottom -Port $Port -Data $Data

    Start-Sleep -Milliseconds 300

    #Save configuration
    $Data = "^XA^JUs^XZ"
    Send-NetworkDataNoReply -Computer $TwinPrintBottom -Port $Port -Data $Data

    Start-Sleep -Milliseconds 300

    #Power cycle
    $Data = "~JR"
    Send-NetworkDataNoReply -Computer $TwinPrintBottom -Port $Port -Data $Data

    Start-Sleep -Milliseconds 3000

    #Wait for printer to be back online
    Wait-PrinterAVailable

    Start-Sleep -Milliseconds 300

    #CALIBRATE
    Send-TwinPrintCalibrationCommands -TwinPrintTop $TwinPrintTop -TwinPrintBottom $TwinPrintBottom

    Start-Sleep -Seconds 60

    #SET BOTTOM PRINTER SETTINGS TO MEDIA-TYPE "CONTINUOUS"
    $Data = "^XA^MNn^XZ"
    Send-NetworkDataNoReply -Computer $TwinPrintBottom -Port $Port -Data $Data

    #TEST FEED
    $Data = "^XA^PH^XZ"
}