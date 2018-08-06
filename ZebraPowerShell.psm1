$Script:ModulePath = (Get-Module -ListAvailable ZebraPowerShell).ModuleBase

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

function Send-TCPtoZebra{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $PrinterName,

        [Parameter()]
        [ValidateRange(1, 65535)]
        [Int16]
        $Port = 9100,

        [Parameter(ValueFromPipeline)]
        [string[]]
        $Data
    )
        
    if (Test-Connection -ComputerName $PrinterName -Count 1 -BufferSize 16 -Delay 1 -quiet -ErrorAction SilentlyContinue)
        {
        Send-NetworkData -Data $Data -Computer $PrinterName -Port $Port
        }
}

function Send-TCPtoZebraNoReply{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $PrinterName,

        [Parameter()]
        [ValidateRange(1, 65535)]
        [Int16]
        $Port = 9100,

        [Parameter(ValueFromPipeline)]
        [string[]]
        $Data
    )
    
if (Test-Connection -ComputerName $PrinterName -Count 1 -BufferSize 16 -Delay 1 -quiet -ErrorAction SilentlyContinue)
        {
        Send-NetworkDataNoReply -Data $Data -Computer $PrinterName -Port $Port
        }
}

<#
function Get-ZebraPrinters {
    [CmdletBinding()]
    param ()
    
    $PrintServer = "Disney"
    $DriverNameMatchString = "ZDesigner*"
    $DriverNamesToExcludeMatchString = "*ZDesigner LP 2844*"
    $DeviceTypesToExcludeMatchString = "Print3D"
    $PrinterObjects = Get-Printer -ComputerName "Disney" | where {$_.DriverName -like $DriverNameMatchString -and $_.DriverName -notlike $DriverNamesToExcludeMatchString -and $_.DeviceType -notlike $DeviceTypesToExcludeMatchString}
    $PortNames = $PrinterObjects.PortName
    $PortObjects = Foreach ($PortName in $PortNames) {Get-WmiObject -Class Win32_TCPIPPrinterPort -ComputerName Disney -Filter "Name='$PortName'"}
    $PortIPs = $PortObjects.hostaddress
}
#>

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

<#
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
#>
function Send-ZebraTwinPrintTestPrint{
    [cmdletbinding()]
    param(
        [parameter(mandatory)]$ZebraPrinterTop,
        [parameter(mandatory)]$ZebraPrinterBottom
    )

    $DataTop =
@"
^XA
^SZ2^JMA
^MCY^PMN
^PW812
~JSN
^JZY
^LH0,0^LRN
^XZ
~DGR:SSGFX000.GRF,1428,7,:Z64:eJyVlLFuFDEQhn/fJmck7tZUZAXLJm/AliuBiBAFDQUlBcV1dGi7BJLoLESN8gg8AmWKKPITwFGR7lwg6C6WKC4o4czM+C65IApYWfrO9tzMeDy/0YF8fScoBoK19wK9gYyB+vE+cO1RiOfA6qfPP6e0uvVlcJewu2W1BQ520HFQ9jXUAJnbBTzhOUPZJ4AjL7TYEraXkDNqlHhGsQlPKQyhBRraWyCzDXoI2jUoVdC+RJG5VUKZeZ6V3bTXbTVZltprVzD6ybIvls64Er2ON+ysMxAoZ8A+bSnRaZQJHJZGzbgpeaJK4BxXgPvwK2vAA4QYLV4i7Hy3mKjg3wFv0PqK69ckFAmtzwWDfHn275ZfK7y98bAZz1SM8TjOsB5jOJsgOzkK6EJNwCljmLDuBSoIMEvYtGRJP4PMVAKO0fccHTpwIGQzASovMKcCFfk6xHMBWaVF3POCM7tkuenEcmqXfBqLdO9I934RXftFZowoeWaH4Dy1kxltMXblYHpbYJzgNnvtSlo0m6O4guU9nTD/wyrf9QW0FWT2VsJ1hnKcA4zXw3iKXsDe9BjmHOWPeelaqef8RAs0CcWVxf+xNIcwdEeGgmQET+17SrlQpzpGxeKyMASqp0llzRf9WSewZMhSBGQuQTri1i/V6I5jWYxKUccHgW57XnSUi47qnmcd1aXoaD9ZyqzstH3SWK8T+qyjLBjR5midfZJryzpqU/S6l1L68+wtVR7pZaAv8IkY80aRC24XjblcpXnN6lRPdh34gcgx3qOUcjX+5YqVCnFoi+EMZye22ZkQ0Lz6BhpNDXG2kdAKmoT6CtpkWSfLUVr0f4F2YvnCVo362ExBYSM9lRL2gNttkHrQC5RbgokJR/4SvwECJwLQ:F3B6
^XA
^FT753,1604
^CI0
^A0B,23,16^FDOrder Number:^FS
^FT778,1604
^A0B,23,16^FDShipment Date:^FS
^FT804,1604
^A0B,23,16^FDShipment No:^FS
^FT753,1299
^A0B,23,16^FDShip Agent:^FS
^FT778,1299
^A0B,23,16^FDShip Service:^FS
^FT71,1082
^A0B,23,16^FDBill To:^FS
^FT71,774
^A0B,23,16^FDShip To:^FS
^FT217,1604
^A0B,23,16^FDItem No.^FS
^FT217,1471
^A0B,23,16^FDDescription^FS
^FT217,741
^A0B,23,16^FDOrdered^FS
^FO245,394
^GB0,1218,3^FS
^FO727,394
^GB0,1218,3^FS
^FT804,1299
^A0B,23,16^FDPiece Count^FS
^FO181,394
^GB0,1218,3^FS
^FT69,1361
^A0B,23,16^FDTervis Tumbler Company^FS
^FT94,1361
^A0B,23,16^FD201 Triple Diamond Blvd^FS
^FT119,1361
^A0B,23,16^FDNorth Venice, FL 34275^FS
^FT145,1361
^A0B,23,16^FDToll Free: 800-237-6688^FS
^FT170,1361
^A0B,23,16^FDcustomercare@tervis.com^FS
^FT138,1539
^A0B,23,16^FDtervis.com^FS
^FO728,977
^GB84,0,3^FS
^FT217,635
^A0B,23,16^FDShipped^FS
^FT217,528
^A0B,23,16^FDB/O^FS
^FO50,1408
^XGR:SSGFX000.GRF,1,1^FS
^ISR:SS_TEMP.GRF,N^XZ
^XA
^ILR:SS_TEMP.GRF^FS
^FT753,1439
^A0B,23,16^FD8738322^FS
^FT778,1439
^A0B,23,16^FD03/02/16^FS
^FT804,1439
^A0B,23,16^FD1^FS
^FT753,1160
^A0B,23,16^FDFDEG^FS
^FT778,1160
^A0B,23,16^FDGround^FS
^FT804,1160
^A0B,23,16^FD5^FS
^FT97,1063
^A0B,23,16^FDCarol Trent^FS
^FT122,1063
^A0B,23,16^FD104 Rocky Dr^FS
^FT173,1063
^A0B,23,16^FDGREENSBURG, PA 15601^FS
^FT98,745
^A0B,23,16^FDCarol Trent^FS
^FT124,745
^A0B,23,16^FD104 Rocky Dr^FS
^FT175,745
^A0B,23,16^FDGREENSBURG, PA 15601^FS
^FT277,1604
^A0B,23,16^FD1036042^FS
^FT302,1604
^A0B,23,16^FD1036651^FS
^FT328,1604
^A0B,23,16^FD1097252^FS
^FT353,1604
^A0B,23,16^FD1027823^FS
^FT379,1604
^A0B,23,16^FD1097251^FS
^FT277,1471
^A0B,23,16^FDBEACH CHAIR AST.DWT.CL1.EMB.16.OZ.0^FS
^FT302,1471
^A0B,23,16^FDTRAVEL LID NOPKG.16.OZ.EA.OR2^FS
^FT328,1471
^A0B,23,16^FDTRAVEL LID NOPKG.16.OZ.EA.GN6^FS
^FT353,1471
^A0B,23,16^FDTRAVEL LID NOPKG.16.OZ.EA.BL3^FS
^FT379,1471
^A0B,23,16^FDTRAVEL LID NOPKG.16.OZ.EA.BL10^FS
^FT277,563
^A0B,23,16^FD1^FS
^FT302,563
^A0B,23,16^FD1^FS
^FT328,563
^A0B,23,16^FD1^FS
^FT353,563
^A0B,23,16^FD1^FS
^FT379,563
^A0B,23,16^FD1^FS
^FT753,965
^A0B,23,16^FD ^FS
^FT277,664
^A0B,23,16^FD1^FS
^FT302,664
^A0B,23,16^FD1^FS
^FT328,664
^A0B,23,16^FD1^FS
^FT353,664
^A0B,23,16^FD1^FS
^FT379,664
^A0B,23,16^FD1^FS
^FT277,490
^A0B,23,16^FD0^FS
^FT302,490
^A0B,23,16^FD0^FS
^FT328,490
^A0B,23,16^FD0^FS
^FT353,490
^A0B,23,16^FD0^FS
^FT379,490
^A0B,23,16^FD0^FS
^PQ1,0,1,Y
^XZ
^XA
^IDR:SSGFX000.GRF^XZ
^XA
^IDR:SS_TEMP.GRF^XZ
"@
    $DataBottom =
@"
....CT~~CD,~CC^~CT~
^XA~TA000~JSN^LT0^MNW^MTT^PON^PMN^LH0,0^JMA^PR8,8~SD15^JUS^LRN^CI0^XZ
^XA
^MMT
^PW831
^LL1827
^LS0
^FO0,0^GFA,193024,193024,00104,:Z64:
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:0163
^PQ1,0,1,Y^XZ

"@
    $TCPPort = 9100

    Send-NetworkDataNoReply -ComputerName $ZebraPrinterTop -TCPPort $TCPPort -Data $DataTop
    Send-NetworkDataNoReply -ComputerName $ZebraPrinterBottom -TCPPort $TCPPort -Data $DataBottom
}
<#
function Send-ZebraSingleSidedTestShipLabel{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][string]$Printer
        )

$Data = @"

"@

Send-NetworkDataNoReply -Computer $Printer -Port 9100 -Data $Data
}
#>

function Invoke-ProvisionZebraPrinter {
    param (
        
    )

}

function Get-ZebraCommandOverrideActive{
    [cmdletbinding()]
    param(
        [cmdletbinding()]
        [parameter(mandatory)][string]$PrinterName
    )
    $Data =
'@
! U1 getvar "device.command_override.active"
@'

    Send-TCPtoZebra -PrinterName $PrinterName -Data $Data -Verbose
}

function Get-ZebraCommandOverrideList{
    [cmdletbinding()]
    param(
        [cmdletbinding()]
        [parameter(mandatory)][string]$PrinterName
    )
    $Data =
'@
! U1 getvar "device.command_override.list"
@'

    Send-TCPtoZebra -PrinterName $PrinterName -Data $Data -Verbose
}

function Set-ZebraFactoryDefaultSettings{
    [cmdletbinding()]
    param(
        [parameter(mandatory)][string]$PrinterName
    )
    $Data = 
'@
^xa^juf^xz
@'
    
    Send-TCPtoZebraNoReply -PrinterName $PrinterName -Data $Data -Verbose
}

function Set-ZebraCommandOverrideStandard{
    [cmdletbinding()]
    param(
        [parameter(mandatory)][string]$PrinterName
    )
    $Data = 
'@
! U1 setvar "device.command_override.add" "^JJ"
! U1 setvar "device.command_override.add" "^JS"
! U1 setvar "device.command_override.add" "^LL"
! U1 setvar "device.command_override.add" "^LT"
! U1 setvar "device.command_override.add" "^MD"
! U1 setvar "device.command_override.add" "^MM"
! U1 setvar "device.command_override.add" "^MN"
! U1 setvar "device.command_override.add" "^MT"
! U1 setvar "device.command_override.add" "^PH"
! U1 setvar "device.command_override.add" "^PR"
! U1 setvar "device.command_override.add" "^PW"
! U1 setvar "device.command_override.add" "~JS"
! U1 setvar "device.command_override.add" "~SD"
! U1 setvar "device.command_override.add" "~TA"
@'
   
    Send-TCPtoZebraNoReply -PrinterName $PrinterName -Data $Data -Verbose
}

function Set-ZebraCommandOverrideActive{
    [cmdletbinding()]
    param(
        [cmdletbinding()]
        [parameter(mandatory)][string]$PrinterName,
        [parameter(mandatory)][validateset("Yes","No")][string]$CommandOverrideSetting
    )
    
    if ($CommandOverrideSetting -eq "Yes"){
        $Data = '! U1 setvar "device.command_override.active" "yes"'
    }
    elseif ($CommandOverrideSetting -eq "No"){
        $Data = '! U1 setvar "device.command_override.active" "no"'
    }

    Send-TCPtoZebraNoReply -PrinterName $PrinterName -Data $Data -Verbose
}

function Set-ZebraCommandOverrideClear{
    [cmdletbinding()]
    param(
        [parameter(mandatory)][string]$PrinterName
    )
    $Data = '! U1 setvar "device.command_override.clear"'
    
    Send-TCPtoZebraNoReply -PrinterName $PrinterName -Data $Data -Verbose
}

function Set-ZebraMenuMode{
    [cmdletbinding()]
    param(
        [parameter(mandatory)][string]$PrinterName
    )
    $Data = "^XA^Mpe^MPm^XZ"

    Send-TCPtoZebraNoReply -PrinterName $PrinterName -Data $Data
}

function Set-ZebraStandardConfiguration{
    [cmdletbinding()]
    param(
        [parameter(mandatory)]
            [string]$PrinterName,
        [parameter(mandatory)]
            [validateset("UPC","GS1","Shipping")]
            [string]$PrinterType,
        [parameter(mandatory)]
            [validateset("110Xi4","FoxIV TwinPrint","FoxIV TwinPrint Mod6")]
            [string]$PrinterModel
    )
    
    Set-ZebraCommandOverrideActive -PrinterName $PrinterName -CommandOverrideSetting No
    Set-ZebraCommandOverrideClear -PrinterName $PrinterName
    sleep -Milliseconds 500

    if ($PrinterType -eq "UPC"){
        $Data = "^XA~SD15^PR8,6,6^MMt^MNw^MTt^ML11700^MFs,f~JSn^LT0^JJ,0,0,p,f,d,e^KP9627^PW750^XZ"
        $NameAndTypeData = "^XA^KN$PrinterName,$PrinterType Small_UPC^XZ"
        
        Send-TCPtoZebraNoReply -PrinterName $PrinterName -Data $Data -Verbose
        sleep -Milliseconds 500
        Send-TCPtoZebraNoReply -PrinterName $PrinterName -Data $NameAndTypeData -Verbose
    }
    elseif ($PrinterType -eq "GS1"){
        $Data = "^XA~SD15^PR8,6,6^MMt^MNw^MTt^ML11700^MFs,f~JSn^LT0^JJ,0,0,p,f,d,e^KP9627^PW750^XZ"
        $NameAndTypeData = "^XA^KN$PrinterName,$PrinterType Small_UPC^XZ"
        
        Send-TCPtoZebraNoReply -PrinterName $PrinterName -Data $Data -Verbose
        sleep -Milliseconds 500
        Send-TCPtoZebraNoReply -PrinterName $PrinterName -Data $NameAndTypeData -Verbose
    }
    elseif ($PrinterType -eq "Shipping"){
        $Data = "^XA~SD15^PR8,8,6^MMt^MNw^MTd^ML7967^MFs,n~JSn^LT0^JJ,0,0,p,f,d,e^KP9627^XZ"
        $NameAndTypeData = "^XA^KN$PrinterName,$PrinterType Small_UPC^XZ"
        
        Send-TCPtoZebraNoReply -PrinterName $PrinterName -Data $Data -Verbose
        sleep -Milliseconds 300
        Send-TCPtoZebraNoReply -PrinterName $PrinterName -Data $NameAndTypeData -Verbose
    }

    sleep -Milliseconds 300
    Set-ZebraMenuMode -PrinterName $PrinterName
    sleep -Milliseconds 300
    Set-ZebraCommandOverrideStandard -PrinterName $PrinterName
    sleep -Milliseconds 300
    Set-ZebraCommandOverrideActive -PrinterName $PrinterName -CommandOverrideSetting Yes
}

function Send-PrinterData {
    param (
        [Parameter(Mandatory)]$Data,
        [Parameter(Mandatory,ValueFromPipelineByPropertyName)]$ComputerName
    )
    $Client = New-TCPClient
    $Stream = $Client | 
    Connect-TCPClient -ComputerName $ComputerName -Port 9100 -Passthru | 
    New-TCPClientStream

    Write-TCPStream -Client $Client -Stream $Stream -Data $Data

    #$Stream | Read-TCPStream -Client $Client

    $Client | Disconnect-TCPClient
}