# ============================================================
# Shared logging helpers   v1.32
#
# This file is NOT what gets shipped. src/build/inline_shared.py inlines its
# content into every entry script while the .bat payloads are built, so the
# released launchers stay self-contained single files (the self-extracting bat
# has no way to reference an external module at run time).
#
# Rule: edit here, never copy-paste these functions back into an entry script.
# ============================================================

function Say {
    param([string]$Text, [string]$Color = 'Gray')
    Write-Host $Text -ForegroundColor $Color
}
