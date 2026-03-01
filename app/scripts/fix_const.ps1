# Fix invalid_constant errors by removing "const " before widget constructors
# that now contain context.colors.xxx

$screenDir = "d:\git\budgetly\app\lib\screens"
$files = Get-ChildItem -Path $screenDir -Filter "*.dart" -Recurse

foreach ($file in $files) {
    $content = Get-Content $file.FullName -Raw
    $original = $content
    
    # Remove "const " before any constructor call on a line that contains "context.colors."
    # Pattern: const SomeWidget( where the following block contains context.colors
    # Simpler approach: just remove all "const " prefix before known widget types 
    # that commonly wrap context-dependent colors
    
    # Strategy: Look for "const Icon(" and similar, followed by context.colors
    # We'll be more aggressive: replace "const Icon(" -> "Icon(" etc if the file has context.colors
    # This is safe since these small const savings are negligible
    
    if ($content.Contains('context.colors.')) {
        # Remove const before constructors that may contain context.colors
        $content = $content -replace 'const (Icon\()', '$1'
        $content = $content -replace 'const (CircleAvatar\()', '$1'
        $content = $content -replace 'const (Text\()', '$1'
        $content = $content -replace 'const (TextStyle\()', '$1'
        $content = $content -replace 'const (BoxDecoration\()', '$1'
        $content = $content -replace 'const (EdgeInsets\.)', '$1'
        $content = $content -replace 'const (SizedBox\()', '$1'
        $content = $content -replace 'const (Divider\()', '$1'
        $content = $content -replace 'const (Border\.)', '$1'
        $content = $content -replace 'const (BorderSide\()', '$1'
        $content = $content -replace 'const (InputDecoration\()', '$1'
        $content = $content -replace 'const (Padding\()', '$1'
        $content = $content -replace 'const (Container\()', '$1'
    }
    
    if ($content -ne $original) {
        Set-Content -Path $file.FullName -Value $content -NoNewline
        Write-Host "Fixed const: $($file.FullName)"
    }
}

Write-Host "Done fixing const issues!"
