#!/usr/bin/env python3
"""Dauerhaft laufender Telegram-Bot fuer Daily Mindset – reagiert sofort auf
Button-Taps/Nachrichten (Status, Version, Sprueche, Bug melden), ohne auf
den stuendlichen Scheduled-Task zu warten. Rein mechanische Antworten,
keine KI-Logik noetig fuer diese vier Funktionen."""
import json, os, time, subprocess, urllib.request, urllib.parse
from datetime import datetime

TOKEN = "8892106768:AAFQa6ARtofQNeiGb-qKA7Xnl6FdjlYPRG0"
CHAT_ID = 2082081302
BASE = f"https://api.telegram.org/bot{TOKEN}"
PROJECT = os.path.expanduser("~/mnt/Downloads/DailyMindset")
AUTOMATION = os.path.join(PROJECT, ".automation")
OFFSET_FILE = os.path.join(AUTOMATION, "telegram_offset_live.txt")
BUGS_FILE = os.path.join(AUTOMATION, "bug_reports_from_max.md")
LOG_FILE = os.path.join(AUTOMATION, "telegram_bot.log")

def log(msg):
    ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    try:
        with open(LOG_FILE, "a") as f:
            f.write(f"[{ts}] {msg}\n")
    except Exception:
        pass

def api(method, timeout=60, **params):
    url = f"{BASE}/{method}"
    data = urllib.parse.urlencode(params).encode()
    with urllib.request.urlopen(url, data=data, timeout=timeout) as r:
        return json.loads(r.read())

def send(text):
    try:
        api("sendMessage", chat_id=CHAT_ID, text=text)
    except Exception as e:
        log(f"sendMessage failed: {e}")

def get_offset():
    try:
        return int(open(OFFSET_FILE).read().strip())
    except Exception:
        return 0

def set_offset(v):
    with open(OFFSET_FILE, "w") as f:
        f.write(str(v))

def count_quotes():
    counts = {}
    total = 0
    seed = os.path.join(PROJECT, "Shared/quotes_seed.json")
    if os.path.exists(seed):
        try:
            data = json.load(open(seed))
            for q in data:
                cat = q.get("category", "?")
                counts[cat] = counts.get(cat, 0) + 1
                total += 1
        except Exception as e:
            log(f"quotes_seed parse error: {e}")
    pipeline = os.path.join(PROJECT, "ContentPipeline/quotes.json")
    extra_total = 0
    if os.path.exists(pipeline):
        try:
            data2 = json.load(open(pipeline))
            extra_total = len(data2) if isinstance(data2, list) else 0
        except Exception as e:
            log(f"pipeline quotes parse error: {e}")
    if total == 0:
        return "Ich konnte gerade keine Sprüche zählen – die Datei scheint zu fehlen."
    lines = [f"{v}x {k}" for k, v in sorted(counts.items())]
    msg = f"Im Grundvorrat liegen {total} Sprüche ({', '.join(lines)})."
    if extra_total:
        msg += f" Dazu kommen {extra_total} KI-generierte Sprüche aus der Content-Pipeline."
    return msg

def get_version():
    proj_yml = os.path.join(PROJECT, "project.yml")
    version = None
    build = None
    if os.path.exists(proj_yml):
        for line in open(proj_yml):
            if "MARKETING_VERSION" in line and version is None:
                version = line.split(":", 1)[-1].strip().strip("\"'")
            if "CURRENT_PROJECT_VERSION" in line and build is None:
                build = line.split(":", 1)[-1].strip().strip("\"'")
    if version:
        msg = f"Die aktuelle Version ist {version}"
        if build:
            msg += f" (Build {build})"
        msg += "."
    else:
        msg = "Ich konnte die Versionsnummer gerade nicht finden."
    return msg

def status_summary():
    try:
        last_commit = subprocess.check_output(
            ["git", "-C", PROJECT, "log", "-1", "--date=format:%d.%m. %H:%M", "--pretty=%cd: %s"],
            text=True, stderr=subprocess.DEVNULL
        ).strip()
    except Exception:
        last_commit = "kein Git-Verlauf gefunden"
    pending = 0
    if os.path.exists(BUGS_FILE):
        pending = len([l for l in open(BUGS_FILE) if l.strip().startswith("- [")])
    msg = f"Letzter Code-Stand: {last_commit}."
    if pending:
        msg += f" Es warten noch {pending} von dir gemeldete Punkte auf den naechsten taeglichen Check."
    else:
        msg += " Keine offenen Meldungen von dir gerade."
    return msg

def log_bug(text):
    os.makedirs(os.path.dirname(BUGS_FILE), exist_ok=True)
    if not os.path.exists(BUGS_FILE):
        with open(BUGS_FILE, "w") as f:
            f.write("# Von Max per Telegram gemeldete Bugs/Hinweise (wird vom taeglichen Check gelesen und geleert)\n")
    ts = datetime.now().strftime("%d.%m.%Y %H:%M")
    with open(BUGS_FILE, "a") as f:
        f.write(f"- [{ts}] {text}\n")

def handle(text):
    t = text.strip()
    low = t.lower()
    if t == "\U0001F4CA Status" or "status" in low:
        send(status_summary())
    elif t == "\U0001F522 Version" or "version" in low:
        send(get_version())
    elif t == "\U0001F4AC Sprüche" or "sprüche" in low or "spruch" in low:
        send(count_quotes())
    elif t == "\U0001F41B Bug melden":
        send("Schreib mir einfach kurz, was dir aufgefallen ist, dann kuemmere ich mich beim naechsten Check darum.")
    else:
        log_bug(t)
        send("Notiert! Fliesst in den naechsten Check mit ein.")

def main():
    log("bot gestartet")
    offset = get_offset()
    while True:
        try:
            result = api("getUpdates", timeout=55, offset=offset + 1)
            for upd in result.get("result", []):
                offset = upd["update_id"]
                msg = upd.get("message")
                if not msg or msg.get("chat", {}).get("id") != CHAT_ID:
                    continue
                text = msg.get("text")
                if not text:
                    continue
                log(f"message: {text}")
                handle(text)
            set_offset(offset)
        except Exception as e:
            log(f"poll error: {e}")
            time.sleep(5)

if __name__ == "__main__":
    main()
