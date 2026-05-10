# echo_8051 Synthesis with OpenLane
$ProjectRoot = "D:\work\qpwork\github\TargetIt\echo_8051"
$PDKCache = "$env:USERPROFILE\.volare"

Write-Host "=== echo_8051 Synthesis (OpenLane + Sky130A) ==="

New-Item -ItemType Directory -Force -Path $PDKCache | Out-Null

docker run --rm `
    -v "${ProjectRoot}:/work" `
    -v "${PDKCache}:/root/.volare" `
    -e PDK_ROOT=/root/.volare `
    -w /work/openlane/echo_8051 `
    efabless/openlane:latest `
    bash -c "run_synthesis 2>&1"

Write-Host "=== Complete ==="
