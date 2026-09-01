$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$backendPath = Join-Path $projectRoot 'backend'
$readyUrl = 'http://127.0.0.1:3000/ready'

if (-not (Test-Path (Join-Path $backendPath 'package.json'))) {
  throw 'No se encontró MasiTrack API.'
}

function Test-FastifyReady {
  try {
    $response = Invoke-RestMethod -Uri $readyUrl -Method Get -TimeoutSec 2 -ErrorAction Stop
    return $response.status -eq 'ready'
  } catch {
    return $false
  }
}

$isReady = Test-FastifyReady
if ($isReady) {
  Write-Host 'Fastify existente reutilizado en el puerto 3000.'
} else {
  Start-Process powershell -WorkingDirectory $backendPath -ArgumentList '-NoExit', '-Command', 'pnpm run dev' -WindowStyle Hidden
  for ($attempt = 0; $attempt -lt 20; $attempt++) {
    Start-Sleep -Seconds 1
    if (Test-FastifyReady) { break }
  }
  if (-not (Test-FastifyReady)) {
    throw 'Fastify no pudo quedar listo en el puerto 3000.'
  }
  Write-Host 'Fastify listo en el puerto 3000.'
}

Set-Location -LiteralPath $projectRoot
flutter run -d chrome --web-port 8080 --dart-define=BACKEND_API_BASE_URL=http://127.0.0.1:3000
