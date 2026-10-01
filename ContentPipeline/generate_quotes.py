#!/usr/bin/env python3
"""
Generiert einen Batch KI-generierter Mindset-/Motivationssprüche und schreibt
sie als quotes.json im Format, das die Swift-App (QuoteBatch/Quote) erwartet.

Nutzung:
    pip install -r requirements.txt
    export ANTHROPIC_API_KEY=sk-ant-...
    python generate_quotes.py --days 30 --per-category-per-day 1 --out ./quotes.json

Die Datei quotes.json muss anschließend irgendwo gehostet werden (z.B. via
GitHub Pages/raw.githubusercontent.com, siehe ../.github/workflows/generate-quotes.yml
für eine fertige Automatisierung), damit RemoteQuoteService.swift in der App
sie abrufen kann.
"""
import argparse
import json
import os
import sys
from datetime import date, timedelta

import anthropic

CATEGORIES = {
    "mindset": "Mindset & mentale Stärke",
    "business": "Business, Unternehmertum, Produktivität",
    "discipline": "Disziplin & Durchhaltevermögen",
    "fitness": "Fitness & körperliche Energie",
    "gratitude": "Dankbarkeit & Zufriedenheit",
}

PROMPT_TEMPLATE = """Du schreibst kurze, prägnante deutsche Motivations- und Mindset-Sprüche \
für eine Homescreen-Widget-App. Zielgruppe: ambitionierte, produktivitätsorientierte \
junge Erwachsene (ähnlich der Tonalität von Finance-/Productivity-Content auf TikTok).

Schreibe {count} ORIGINELLE, noch nie gehörte Sprüche zur Kategorie "{category_label}".

Regeln:
- Jeder Spruch: maximal 120 Zeichen, auf Deutsch, ohne Anführungszeichen.
- Kein Klischee-Recycling ("Der frühe Vogel..."), sondern frisch und direkt formuliert.
- Kein Autor nötig (author darf null sein), außer es ist ein bekanntes, korrekt zugeordnetes Zitat.
- Antworte AUSSCHLIESSLICH mit validem JSON: einer Liste von Objekten {{"text": "...", "author": null}}.
"""


def generate_for_category(client: "anthropic.Anthropic", category: str, label: str, count: int) -> list[dict]:
    message = client.messages.create(
        model="claude-sonnet-5",
        max_tokens=8000,
        messages=[{"role": "user", "content": PROMPT_TEMPLATE.format(count=count, category_label=label)}],
    )
    raw_text = "".join(block.text for block in message.content if hasattr(block, "text"))
    raw_text = raw_text.strip()
    # Falls das Modell Markdown-Codefences liefert, diese entfernen.
    if raw_text.startswith("```"):
        raw_text = raw_text.split("```")[1]
        if raw_text.startswith("json"):
            raw_text = raw_text[4:]
    try:
        parsed = json.loads(raw_text)
    except json.JSONDecodeError as exc:
        print(f"WARNUNG: Konnte Antwort für '{category}' nicht parsen: {exc}", file=sys.stderr)
        return []
    return parsed


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--days", type=int, default=30, help="Für wie viele Tage vorausplanen")
    parser.add_argument("--per-category-per-day", type=int, default=1)
    parser.add_argument("--out", type=str, default="quotes.json")
    args = parser.parse_args()

    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        print("Fehler: ANTHROPIC_API_KEY ist nicht gesetzt.", file=sys.stderr)
        sys.exit(1)

    client = anthropic.Anthropic(api_key=api_key)

    all_quotes = []
    today = date.today()

    for category, label in CATEGORIES.items():
        needed = args.days * args.per_category_per_day
        raw_quotes = generate_for_category(client, category, label, needed)

        for i, raw in enumerate(raw_quotes[:needed]):
            day_index = i // args.per_category_per_day
            quote_date = today + timedelta(days=day_index)
            all_quotes.append({
                "id": f"{category}-{quote_date.isoformat()}-{i}",
                "text": raw.get("text", "").strip(),
                "author": raw.get("author"),
                "category": category,
                "dateKey": quote_date.isoformat(),
            })
        print(f"{category}: {len(raw_quotes)} Sprüche generiert")

    batch = {
        "generatedAt": date.today().isoformat(),
        "quotes": all_quotes,
    }

    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(batch, f, ensure_ascii=False, indent=2)

    print(f"\n{len(all_quotes)} Sprüche insgesamt -> {args.out}")


if __name__ == "__main__":
    main()
