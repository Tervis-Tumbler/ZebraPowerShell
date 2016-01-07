$PrintServer = "Disney"
$DriverNameMatchString = "ZDesigner*"
$DriverNamesToExcludeMatchString = "*ZDesigner LP 2844*"
$SavePath = "C:\Users\alozano\Documents\WindowsPowerShell\Scripts\Get-DisneyZebraConfig\ZebraConfigDump"
    
$PrinterObjects = Get-Printer -ComputerName "Disney" | where {$_.DriverName -like $DriverNameMatchString -and $_.DriverName -notlike $DriverNamesToExcludeMatchString}
$PortNames = $PrinterObjects.PortName
$PortObjects = Foreach ($PortName in $PortNames) {Get-WmiObject -Class Win32_TCPIPPrinterPort -ComputerName Disney -Filter "Name='$PortName'"}
$PortIPs = $PortObjects.hostaddress

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

        [Parameter(Mandatory)]
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

$Data = "^XA^HH^XZ"
Foreach ($PortIP in $PortIPs){
    $Date = Get-Date -Format yyyyMMdd_hhmmtt
    if (Test-Connection -ComputerName $PortIP -Count 1 -BufferSize 16 -Delay 1 -quiet -ErrorAction SilentlyContinue){
        Send-NetworkData -Data $Data -Computer $PortIP -Port 9100 | Out-File "$SavePath$PortIP`_ $Date.json" -Append
    }
}