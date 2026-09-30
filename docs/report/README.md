# Informe LaTeX

1. Completar nombres y CUI en `informe.tex`.
2. Desplegar y ejecutar `scripts/capture-evidence.ps1` desde la raíz.
3. Compilar dos veces para generar el índice:

```powershell
Set-Location docs/report
pdflatex -interaction=nonstopmode informe.tex
pdflatex -interaction=nonstopmode informe.tex
```

Las evidencias de texto se incorporan automáticamente desde `evidence/`.
