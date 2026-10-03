$ErrorActionPreference = "Stop"

& "$PSScriptRoot\..\.venv\Scripts\python.exe" -m uvicorn smartalert.main:app --app-dir "$PSScriptRoot\..\src" --reload
