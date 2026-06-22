# This script redirects Gradle and Pub caches to Drive D (which has 235 GB free) 
# instead of Drive C (which has 0 GB free).

$env:GRADLE_USER_HOME="D:\.gradle"
$env:PUB_CACHE="D:\.pub-cache"

Write-Host "Redirecting Gradle home to: D:\.gradle" -ForegroundColor Green
Write-Host "Redirecting Pub cache to: D:\.pub-cache" -ForegroundColor Green
Write-Host "Building APK..." -ForegroundColor Cyan

flutter build apk --no-tree-shake-icons
