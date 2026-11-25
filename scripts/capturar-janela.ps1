# Captura a janela do Chrome/Edge aberta pela automação (título "Portal de Tarefas"), mesmo que esteja atrás de outras.
param([Parameter(Mandatory)][string]$Nome, [string]$Titulo = 'Portal de Tarefas')
Add-Type -AssemblyName System.Drawing
if (-not ('JanelaPrint' -as [type])) {
    Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class JanelaPrint {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
    [DllImport("dwmapi.dll")] public static extern int DwmGetWindowAttribute(IntPtr h, int attr, out RECT r, int size);
}
"@
}
[void][JanelaPrint]::SetProcessDPIAware()
$proc = Get-Process chrome, msedge -ErrorAction SilentlyContinue |
        Where-Object { $_.MainWindowHandle -ne 0 -and $_.MainWindowTitle -like "*$Titulo*" } |
        Sort-Object StartTime -Descending | Select-Object -First 1
if (-not $proc) { Write-Host "  janela '$Titulo' do navegador não encontrada" -ForegroundColor Red; exit 1 }
$h = $proc.MainWindowHandle
$r = New-Object JanelaPrint+RECT
[void][JanelaPrint]::GetWindowRect($h, [ref]$r)
$w = $r.Right - $r.Left; $a = $r.Bottom - $r.Top
$bmp = New-Object System.Drawing.Bitmap $w, $a
$g = [System.Drawing.Graphics]::FromImage($bmp)
$hdc = $g.GetHdc()
[void][JanelaPrint]::PrintWindow($h, $hdc, 2)      # PW_RENDERFULLCONTENT
$g.ReleaseHdc($hdc)
# recorta a borda invisível da janela maximizada (área real informada pelo DWM)
$v = New-Object JanelaPrint+RECT
if ([JanelaPrint]::DwmGetWindowAttribute($h, 9, [ref]$v, 16) -eq 0) {
    $rect = New-Object System.Drawing.Rectangle ($v.Left - $r.Left), ($v.Top - $r.Top), ($v.Right - $v.Left), ($v.Bottom - $v.Top)
    $rect.Intersect((New-Object System.Drawing.Rectangle 0, 0, $w, $a))
    $final = $bmp.Clone($rect, $bmp.PixelFormat)
} else { $final = $bmp }
$arq = Join-Path (Join-Path (Split-Path -Parent $PSScriptRoot) 'evidencias') "$Nome.png"
$final.Save($arq, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
Write-Host "  [print salvo: evidencias\$Nome.png]" -ForegroundColor DarkGray
