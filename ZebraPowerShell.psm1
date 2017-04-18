$Script:ModulePath = (Get-Module -ListAvailable ZebraPowerShell).ModuleBase

function Invoke-ProvisionZebraPrinter {
    param (
        
    )

}

function Send-NetworkData {
    [CmdletBinding()]
    param (
        [Alias("Computer")]
        [Parameter(Mandatory)]
        [string]
        $ComputerName,

        [Alias("Port")]
        [Parameter(Mandatory)]
        [ValidateRange(1, 65535)]
        [Int16]
        $TCPPort,

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
        $Client.Connect($ComputerName, $TCPPort)
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
        [Alias("Computer")][Parameter(Mandatory)][string]$ComputerName,
        [Parameter(Mandatory)]
        [Alias("Port")][ValidateRange(1, 65535)][Int16]$TCPPort,
        [Parameter(Mandatory)][string[]]$Data,
        [System.Text.Encoding]$Encoding = [System.Text.Encoding]::ASCII
    )
    begin {
        # establish the connection and a stream writer
        $Client = New-Object -TypeName System.Net.Sockets.TcpClient
        $Client.Connect($ComputerName, $TCPPort)
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

#function Get-ZebraPrinters {
#    [CmdletBinding()]
#    param ()
#    
#    $PrintServer = "Disney"
#    $DriverNameMatchString = "ZDesigner*"
#    $DriverNamesToExcludeMatchString = "*ZDesigner LP 2844*"
#    $DeviceTypesToExcludeMatchString = "Print3D"
#    $PrinterObjects = Get-Printer -ComputerName "Disney" | where {$_.DriverName -like $DriverNameMatchString -and $_.DriverName -notlike $DriverNamesToExcludeMatchString -and $_.DeviceType -notlike $DeviceTypesToExcludeMatchString}
#    $PortNames = $PrinterObjects.PortName
#    $PortObjects = Foreach ($PortName in $PortNames) {Get-WmiObject -Class Win32_TCPIPPrinterPort -ComputerName Disney -Filter "Name='$PortName'"}
#    $PortIPs = $PortObjects.hostaddress
#}

function Get-ZebraPrinterConfiguration {
    param(
        $ComputerName
    )
    process {
        if (Test-Connection -ComputerName $ComputerName -Count 1 -BufferSize 16 -Delay 1 -quiet -ErrorAction SilentlyContinue){
            $TemplateContent = Get-Content $ModulePath\ZebraPrinterConfiguration.template | Out-String

            Send-NetworkData -Data "^XA^HH^XZ" -Computer $ComputerName -Port 9100 |
            ConvertFrom-String -TemplateContent $TemplateContent
        }
    }
}

function Get-DisneyZebraConfigs{

    [CmdletBinding()]
    param ()
   
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
    $Data = "^XA^MNw^JUs^XZ"
    Send-NetworkDataNoReply -Computer $TwinPrintBottom -Port $Port -Data $Data

    Start-Sleep -Milliseconds 300

    #Power cycle
    $Data = "~JR"
    Send-NetworkDataNoReply -Computer $TwinPrintBottom -Port $Port -Data $Data

    Start-Sleep -Seconds 20

    #Wait for printer to be back online
    Wait-PrinterAVailable -PrinterName $TwinPrintBottom

    Start-Sleep -Milliseconds 300

    #CALIBRATE
    Send-TwinPrintCalibrationCommands -TwinPrintTop $TwinPrintTop -TwinPrintBottom $TwinPrintBottom

    Start-Sleep -Seconds 20

    #SET BOTTOM PRINTER SETTINGS TO MEDIA-TYPE "CONTINUOUS"
    $Data = "^XA^MNn^JUs^XZ"
    Send-NetworkDataNoReply -Computer $TwinPrintBottom -Port $Port -Data $Data

    Start-Sleep -Milliseconds 300

    #Power cycle
    $Data = "~JR"
    Send-NetworkDataNoReply -Computer $TwinPrintBottom -Port $Port -Data $Data
}
function Send-TwinPrintPostCalibrationTestPrint{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][string]$TwinPrintTop,
        [Parameter(Mandatory)][string]$TwinPrintBottom
        )
$TopData = "@^XA
^SZ2^JMA
^MCY^PMN
^PW812
~JSN
^JZY
^LH0,0^LRN
^XZ
^XA
^DFE:SSFMT000.ZPL^FS
^FT291,739
^CI0
^A0N,34,46^FDCALIBRATION^FS
^FT302,773
^A0N,34,46^FDCOMPLETED^FS
^FT270,808
^A0N,34,46^FDSUCCESSFULLY^FS
^FT291,1018
^A0N,34,46^FDCALIBRATION^FS
^FT302,1053
^A0N,34,46^FDCOMPLETED^FS
^FT270,1088
^A0N,34,46^FDSUCCESSFULLY^FS
^FT291,459
^A0N,34,46^FDCALIBRATION^FS
^FT302,494
^A0N,34,46^FDCOMPLETED^FS
^FT270,529
^A0N,34,46^FDSUCCESSFULLY^FS
^XZ
^XA
^XFE:SSFMT000.ZPL^FS
^PQ1,0,1,Y
^XZ
@"
$BottomData = "@^XA
^SZ2^JMA
^MCY^PMN
^PW812
~JSN
^JZY
^LH0,0^LRN
^XZ
^XA
^DFE:SSFMT000.ZPL^FS
^FT291,333
^CI0
^A0N,34,46^FDCALIBRATION^FS
^FT302,367
^A0N,34,46^FDCOMPLETED^FS
^FT270,402
^A0N,34,46^FDSUCCESSFULLY^FS
^FT291,612
^A0N,34,46^FDCALIBRATION^FS
^FT302,647
^A0N,34,46^FDCOMPLETED^FS
^FT270,682
^A0N,34,46^FDSUCCESSFULLY^FS
^FT291,53
^A0N,34,46^FDCALIBRATION^FS
^FT302,88
^A0N,34,46^FDCOMPLETED^FS
^FT270,123
^A0N,34,46^FDSUCCESSFULLY^FS
^XZ
^XA
^XFE:SSFMT000.ZPL^FS
^PQ1,0,1,Y
^XZ
@"
Send-NetworkDataNoReply -Computer $TwinPrintTop -Port 9100 -Data $TopData
Send-NetworkDataNoReply -Computer $TwinPrintBottom -Port 9100 -Data $BottomData
}
function Set-ZebraConfiguration_FoxIVTwinPrint_Top{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $TwinPrintTop,

        [Parameter(Mandatory)]
        [string]
        $TwinPrintBottom,

        [Parameter(Mandatory)]
        [ValidateRange(1, 65535)]
        [Int16]
        $Port,

        [Parameter(ValueFromPipeline)]
        [string[]]
        $Data
    )

    

}
function Send-ZebraTestShipLabel{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][string]$Printer
        )

$Data = @"

"@

Send-NetworkDataNoReply -Computer $Printer -Port 9100 -Data $Data
}
function Get-DisneyZebraSGDConfigs{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Destination
    )

  Get-ZebraPrinters
    $Data =
@"  
! U1 getvar "device.command_override.list"
! U1 getvar "device.command_override.active"
"@

    Foreach ($PortIP in $PortIPs){
        $Date = Get-Date -Format yyyyMMdd_hhmmtt
        if (Test-Connection -ComputerName $PortIP -Count 1 -BufferSize 16 -Delay 1 -quiet -ErrorAction SilentlyContinue){
        Send-NetworkData -Data $Data -Computer $PortIP -Port 9100 | Out-File -FilePath "$Destination$PortIP`_$Date.json" -Append
        }
    }
}
function Set-ZebraSetting{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $Printer,

        [Parameter(Mandatory)]
        [ValidateRange(1, 65535)]
        [Int16]
        $Setting,

        [Parameter(ValueFromPipeline)]
        [string[]]
        $NewValue
    )        
}
function Send-TwinPrintTestLabelsViaUSB{
    $PrinterNameTop = "ZDesigner 110Xi4 203 dpi"
    $PrinterNameBottom ="ZDesigner 110Xi4 203 dpi (Copy 1)"

    $ScriptBlockTop = {
        param($PrinterNameTop)
        $Data = @"

"@
        Out-Printer -Name $PrinterNameTop -InputObject $Data
    }

        $ScriptBlockBottom = {
        param($PrinterNameBottom)
        $Data = @"

"@
        Out-Printer -Name $PrinterNameBottom -InputObject $Data
    }

    Start-Job -Name "TwinPrintTop_TestLabel" -ScriptBlock $ScriptBlockTop -ArgumentList $PrinterNameTop -Verbose
    Start-Job -Name "TwinPrintBottom_TestLabel" -ScriptBlock $ScriptBlockBottom -ArgumentList $PrinterNameBottom -Verbose
}