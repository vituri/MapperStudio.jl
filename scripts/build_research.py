"""Rebuild the static research page after editing its Markdown source.

Optional development dependency: pip install markdown. No Python is required
to run the application; the generated HTML is checked in.
"""
from pathlib import Path
import markdown

root = Path(__file__).resolve().parents[1]
body = markdown.markdown((root / "docs/ayasdi-research.md").read_text(), extensions=["tables", "fenced_code"])
html = '<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Pesquisa Ayasdi · MapperStudio</title><link rel="stylesheet" href="/style.css"></head><body><main class="research-content" style="max-width:950px;margin:40px auto;padding:24px"><a href="/">Voltar ao Studio</a>' + body + '</main></body></html>'
(root / "web/research.html").write_text(html)
