# PowerShell script to replace BudgetlyTheme.xxx static color references
# with context.colors.xxx in all screen files.

$screenDir = "d:\git\budgetly\app\lib\screens"

# Color property mappings: BudgetlyTheme.X -> context.colors.X
$colorMappings = @{
    'BudgetlyTheme.background' = 'context.colors.background'
    'BudgetlyTheme.backgroundAlt' = 'context.colors.backgroundAlt'
    'BudgetlyTheme.cardSurface' = 'context.colors.cardSurface'
    'BudgetlyTheme.surfaceHighlight' = 'context.colors.surfaceHighlight'
    'BudgetlyTheme.primary' = 'context.colors.primary'
    'BudgetlyTheme.primaryDark' = 'context.colors.primaryDark'
    'BudgetlyTheme.primaryLight' = 'context.colors.primaryLight'
    'BudgetlyTheme.accentMint' = 'context.colors.accentMint'
    'BudgetlyTheme.accentMintDark' = 'context.colors.accentMintDark'
    'BudgetlyTheme.accentCoral' = 'context.colors.accentCoral'
    'BudgetlyTheme.accentCoralDark' = 'context.colors.accentCoralDark'
    'BudgetlyTheme.textMain' = 'context.colors.textMain'
    'BudgetlyTheme.textMuted' = 'context.colors.textMuted'
    'BudgetlyTheme.textDim' = 'context.colors.textDim'
    'BudgetlyTheme.borderSubtle' = 'context.colors.borderSubtle'
    'BudgetlyTheme.borderLight' = 'context.colors.borderLight'
    'BudgetlyTheme.categoryGroceries' = 'context.colors.categoryGroceries'
    'BudgetlyTheme.categoryDining' = 'context.colors.categoryDining'
    'BudgetlyTheme.categoryTransport' = 'context.colors.categoryTransport'
    'BudgetlyTheme.categoryHousing' = 'context.colors.categoryHousing'
    'BudgetlyTheme.categoryBills' = 'context.colors.categoryBills'
    'BudgetlyTheme.categoryHealth' = 'context.colors.categoryHealth'
    'BudgetlyTheme.categoryEntertainment' = 'context.colors.categoryEntertainment'
    'BudgetlyTheme.categoryShopping' = 'context.colors.categoryShopping'
}

$files = Get-ChildItem -Path $screenDir -Filter "*.dart" -Recurse

foreach ($file in $files) {
    $content = Get-Content $file.FullName -Raw
    $modified = $false
    
    foreach ($key in $colorMappings.Keys) {
        if ($content.Contains($key)) {
            $content = $content.Replace($key, $colorMappings[$key])
            $modified = $true
        }
    }
    
    if ($modified) {
        Set-Content -Path $file.FullName -Value $content -NoNewline
        Write-Host "Fixed: $($file.FullName)"
    }
}

Write-Host "Done!"
