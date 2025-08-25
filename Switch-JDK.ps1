param(
  [Parameter(Mandatory=$true)]
  [ValidateSet(8,11,17,21,24)]
  [int]$Version,

  [ValidateSet('Auto','Machine','User')]
  [string]$Scope = 'Auto',

  [ValidateSet('Any','Oracle')]
  [string]$Vendor = 'Any'
)

function Test-Admin {
  $id=[Security.Principal.WindowsIdentity]::GetCurrent()
  (New-Object Security.Principal.WindowsPrincipal $id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
function Resolve-Scope($s){ if($s -eq 'Auto'){ if(Test-Admin){'Machine'} else {'User'} } else { $s } }

function Remove-JavaBinsFromPath([string]$path){
  if(-not $path){ return '' }
  $parts = $path -split ';' | Where-Object { $_ -and $_.Trim() -ne '' }
  $filtered = foreach($p in $parts){
    if($p -match '(?i)\\(jdk|jre)[^\\]*\\bin\\?$'){ continue }
    if(-not (Test-Path $p)){ continue }
    $p
  }
  $seen=@{}
  ($filtered | Where-Object { if(-not $seen.ContainsKey($_)){ $seen[$_]=$true; $true } }) -join ';'
}

function Get-JavaMajor([string]$jdkHome){
  $exe = Join-Path $jdkHome 'bin\java.exe'
  if(-not (Test-Path $exe)){ return $null }
  $line = & $exe -version 2>&1 | Select-Object -First 1
  if($line -match '"1\.8'){ return 8 }
  if($line -match '"(\d+)\.'){ return [int]$matches[1] }
  return $null
}

function Broadcast-Env {
  try {
    Add-Type -ErrorAction SilentlyContinue -TypeDefinition @"
using System; using System.Runtime.InteropServices;
public static class EnvBcast {
  [DllImport("user32.dll", SetLastError=true, CharSet=CharSet.Auto)]
  public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, IntPtr wParam, string lParam, uint flags, uint timeout, out IntPtr result);
}
"@
    [void][EnvBcast]::SendMessageTimeout([IntPtr]0xffff,0x1A,[IntPtr]::Zero,"Environment",0,2000,[ref]([IntPtr]::Zero))
  } catch {}
}

function Find-OracleJdkMajor([int]$major){
  $regPaths = @(
    "HKLM:\SOFTWARE\JavaSoft\JDK\$major",
    "HKLM:\SOFTWARE\WOW6432Node\JavaSoft\JDK\$major"
  )
  foreach($rp in $regPaths){
    try{
      $jh = (Get-ItemProperty -Path $rp -ErrorAction Stop).JavaHome
      if($jh -and (Test-Path (Join-Path $jh 'bin\java.exe')) -and (Get-JavaMajor $jh) -eq $major){ return $jh }
    } catch {}
  }

  $roots = @('C:\Program Files\Java','C:\Program Files (x86)\Java')
  $cands=@()
  foreach($r in $roots){
    if(-not (Test-Path $r)){ continue }
    $lvl1 = @(Get-ChildItem -Directory $r -ErrorAction SilentlyContinue)
    $lvl2 = @()
    foreach($d in $lvl1){ $lvl2 += Get-ChildItem -Directory $d.FullName -ErrorAction SilentlyContinue }

    $combined = @(); $combined += $lvl1; $combined += $lvl2
    foreach($d in $combined){
      $name = $d.Name
      if($name -match '^(jdk-)?' + [regex]::Escape("$major") + '(\.\d+)*'){
        $jh = $d.FullName
        $exe = Join-Path $jh 'bin\java.exe'
	$ok1 = Test-Path $exe
	$ok2 = (Get-JavaMajor $jh) -eq $major
	if($ok1 -and $ok2){ $cands += $jh }
      }
    }
  }
  if($cands.Count){ return ($cands | Sort-Object { $_ } -Descending | Select-Object -First 1) }
  return $null
}

function Find-JdkGeneric([int]$major){
  $roots = @(
    'C:\Program Files\Eclipse Adoptium',
    'C:\Program Files\AdoptOpenJDK',
    'C:\Program Files\Java',
    'C:\Program Files\Microsoft',
    'C:\Program Files\Zulu'
  )
  $dirs = @()
  foreach($r in $roots){ if(Test-Path $r){ $dirs += Get-ChildItem -Directory -Path $r -ErrorAction SilentlyContinue } }
  $snapshot = @($dirs)
  foreach($d in $snapshot){ try { $dirs += Get-ChildItem -Directory -Path $d.FullName -ErrorAction SilentlyContinue } catch {} }

  $cands=@()
  foreach($d in $dirs){
    $jdkHome = $d.FullName
    if(Test-Path (Join-Path $jdkHome 'bin\java.exe')){
      $m = Get-JavaMajor $jdkHome
      if($m -eq $major){ $cands += $jdkHome }
    }
  }
  if($cands.Count){
    return ($cands | Sort-Object {
      $n = Split-Path $_ -Leaf
      if($n -match '(\d+(\.\d+)*)(\+\d+)?'){ (($matches[1] + ($matches[3] -replace '\+','.')) -as [version]) } else { [version]'0.0.0.0' }
    } -Descending | Select-Object -First 1)
  }
  return $null
}

function Set-Jdk([string]$jdkHome, [string]$scope){
  if(-not (Test-Path (Join-Path $jdkHome 'bin\java.exe'))){ throw "java.exe not found in $jdkHome\bin" }

  [Environment]::SetEnvironmentVariable('JAVA_HOME', $jdkHome, $scope)
  [Environment]::SetEnvironmentVariable('JDK_HOME',  $jdkHome, $scope)

  $old = [Environment]::GetEnvironmentVariable('Path', $scope); if(-not $old){ $old='' }
  $clean = Remove-JavaBinsFromPath $old
  [Environment]::SetEnvironmentVariable('Path', "$jdkHome\bin;$clean", $scope)

  $env:JAVA_HOME = $jdkHome
  $env:JDK_HOME  = $jdkHome
  $env:Path = "$jdkHome\bin;" + (Remove-JavaBinsFromPath $env:Path)

  Broadcast-Env

  $mj = Get-JavaMajor $jdkHome
  if($mj -ge 9){ & "$jdkHome\bin\java.exe" --version } else { & "$jdkHome\bin\java.exe" -version }
}

# main
$resolvedScope = Resolve-Scope $Scope
$jdkHome = $null
if($Version -eq 24 -or $Vendor -eq 'Oracle'){ $jdkHome = Find-OracleJdkMajor $Version }
if(-not $jdkHome){ $jdkHome = Find-JdkGeneric $Version }
if(-not $jdkHome){ throw "JDK $Version not found. Check installations." }

Set-Jdk -jdkHome $jdkHome -scope $resolvedScope
Write-Host "Activated JDK $Version at $jdkHome (Scope=$resolvedScope)"
