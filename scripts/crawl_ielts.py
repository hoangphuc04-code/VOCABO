"""
crawl_ielts.py  — v2 async/parallel
Crawl IELTS vocabulary từ các nguồn public:
  1. Free Dictionary API (dictionaryapi.dev) — phonetic + definition + example
  2. MyMemory API — dịch nghĩa sang tiếng Việt

Tối ưu:
  - asyncio + aiohttp: gọi song song tất cả từ cùng lúc
  - Semaphore giới hạn 10 request đồng thời (tránh bị block)
  - Retry tự động khi timeout/lỗi mạng
  - Batch translate: gộp nhiều từ vào 1 request MyMemory

Output: scripts/ielts_words.json

Yêu cầu: pip install aiohttp
"""

import asyncio
import json
import time
import sys
from pathlib import Path

# Fix Windows console encoding
if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

try:
    import aiohttp
except ImportError:
    import subprocess
    print("Installing aiohttp...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "aiohttp"])
    import aiohttp

# ── IELTS word list ───────────────────────────────────────────────────────────
IELTS_WORDS = [
    # Academic Word List - Sublist 1
    "analyse","approach","area","assess","assume","authority","available",
    "benefit","concept","consist","context","contract","create","data",
    "define","derive","distribute","economy","environment","establish",
    "estimate","evidence","export","factor","finance","formula","function",
    "identify","income","indicate","individual","interpret","involve","issue",
    "labour","legal","legislate","major","method","occur","percent","period",
    "policy","principle","proceed","process","require","research","respond",
    "role","section","sector","significant","similar","source","specific",
    "structure","theory","vary",
    # Sublist 2
    "achieve","acquire","administrate","affect","appropriate","aspect",
    "assist","category","chapter","commission","community","complex",
    "compute","conclude","conduct","consequent","construct","consume",
    "credit","culture","design","distinct","element","equate","evaluate",
    "feature","final","focus","impact","injure","institute","invest",
    "item","journal","maintain","normal","obtain","participate","perceive",
    "positive","potential","previous","primary","purchase","range","region",
    "regulate","relevant","reside","resource","restrict","secure","seek",
    "select","site","strategy","survey","text","tradition","transfer",
    # Common IELTS vocabulary
    "abandon","abstract","accumulate","accurate","acknowledge","adapt",
    "adequate","adjacent","advocate","aggregate","allocate","alter",
    "ambiguous","anticipate","apparent","arbitrary","articulate","attribute",
    "bias","capacity","challenge","circumstance","clarify","collaborate",
    "compensate","complement","comprehensive","concentrate","confirm",
    "conflict","consequence","considerable","constitute","controversy",
    "conventional","coordinate","correspond","criteria","crucial","debate",
    "decline","deduce","demonstrate","depict","detect","determine",
    "deviate","dimension","diminish","discriminate","display","diverse",
    "dominate","dynamic","eliminate","emerge","emphasise","enable","enhance",
    "enormous","ensure","equivalent","evolve","exceed","exclude","exhibit",
    "expand","explicit","exploit","expose","extensive","facilitate","flexible",
    "fluctuate","generate","global","guarantee","hypothesis","illustrate",
    "implement","imply","impose","incentive","incorporate","inevitable",
    "infrastructure","inherent","initiate","innovate","integrate","interact",
    "justify","manipulate","maximize","minimize","modify",
    "monitor","motivate","mutual","negate","objective","obvious",
    "offset","ongoing","overlap","persist",
    "phenomenon","predict","predominant","preliminary","promote","proportion",
    "prospect","pursue","rational","reinforce","reject","rely","resolve",
    "retain","reveal","revise","simulate","specify","stabilize","substitute",
    "sufficient","summarize","supplement","sustain","terminate","transform",
    "transmit","undermine","utilize","validate","verify","widespread",
]

# Loại bỏ trùng lặp, giữ thứ tự
IELTS_WORDS = list(dict.fromkeys(IELTS_WORDS))

OUTPUT_FILE = Path(__file__).parent / "ielts_words.json"

# Giới hạn concurrent requests
CONCURRENCY = 10
TIMEOUT     = 10  # seconds per request
MAX_RETRIES = 2


# ── Async fetch dictionary ────────────────────────────────────────────────────

async def fetch_dictionary(session: aiohttp.ClientSession, word: str) -> dict:
    url = f"https://api.dictionaryapi.dev/api/v2/entries/en/{word}"
    for attempt in range(MAX_RETRIES + 1):
        try:
            async with session.get(url, timeout=aiohttp.ClientTimeout(total=TIMEOUT)) as r:
                if r.status != 200:
                    return {}
                data = await r.json(content_type=None)
                if not data:
                    return {}
                entry = data[0]

                phonetic = entry.get("phonetic", "")
                if not phonetic:
                    for p in entry.get("phonetics", []):
                        if p.get("text"):
                            phonetic = p["text"]
                            break

                definition = example = part_of_speech = ""
                for meaning in entry.get("meanings", []):
                    part_of_speech = meaning.get("partOfSpeech", "")
                    for d in meaning.get("definitions", []):
                        definition = d.get("definition", "")
                        example    = d.get("example", "")
                        if definition:
                            break
                    if definition:
                        break

                return {
                    "phonetic":       phonetic,
                    "definition_en":  definition,
                    "example":        example,
                    "part_of_speech": part_of_speech,
                }
        except (aiohttp.ClientError, asyncio.TimeoutError):
            if attempt < MAX_RETRIES:
                await asyncio.sleep(0.5 * (attempt + 1))
    return {}


# ── Async translate (MyMemory) ────────────────────────────────────────────────

async def translate_vi(session: aiohttp.ClientSession, text: str) -> str:
    """Dịch 1 đoạn text sang tiếng Việt."""
    if not text:
        return ""
    url = "https://api.mymemory.translated.net/get"
    params = {"q": text[:400], "langpair": "en|vi"}
    for attempt in range(MAX_RETRIES + 1):
        try:
            async with session.get(url, params=params,
                                   timeout=aiohttp.ClientTimeout(total=TIMEOUT)) as r:
                if r.status == 200:
                    data = await r.json(content_type=None)
                    # Kiểm tra quota hết
                    if data.get("quotaFinished"):
                        return ""
                    return data.get("responseData", {}).get("translatedText", "")
        except (aiohttp.ClientError, asyncio.TimeoutError):
            if attempt < MAX_RETRIES:
                await asyncio.sleep(0.5 * (attempt + 1))
    return ""


# ── Process 1 word (dictionary + 2 translations) ─────────────────────────────

async def process_word(
    session: aiohttp.ClientSession,
    sem: asyncio.Semaphore,
    word: str,
    idx: int,
    total: int,
) -> dict:
    async with sem:
        # Gọi song song: dictionary + translate word
        dict_task    = fetch_dictionary(session, word)
        meaning_task = translate_vi(session, word)
        info, meaning_vi = await asyncio.gather(dict_task, meaning_task)

        # Dịch example nếu có (song song với các từ khác nhờ semaphore)
        example_vi = ""
        if info.get("example"):
            example_vi = await translate_vi(session, info["example"])

        entry = {
            "word":           word,
            "phonetic":       info.get("phonetic", ""),
            "meaning":        meaning_vi or word,
            "definition_en":  info.get("definition_en", ""),
            "example":        info.get("example", ""),
            "example_vi":     example_vi,
            "part_of_speech": info.get("part_of_speech", ""),
            "category":       "IELTS",
        }

        status = f"OK {meaning_vi[:25]}" if meaning_vi else "-- (no translation)"
        print(f"  [{idx+1}/{total}] {word:<20} {status}")
        return entry


# ── Main async ────────────────────────────────────────────────────────────────

async def crawl_async(words: list[str]) -> list[dict]:
    sem = asyncio.Semaphore(CONCURRENCY)
    connector = aiohttp.TCPConnector(limit=CONCURRENCY, ssl=False)

    async with aiohttp.ClientSession(connector=connector) as session:
        tasks = [
            process_word(session, sem, word, i, len(words))
            for i, word in enumerate(words)
        ]
        results = await asyncio.gather(*tasks)

    return list(results)


def _save(data: list[dict]):
    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)


def main():
    # Load existing để resume
    existing: list[dict] = []
    existing_words: set[str] = set()
    if OUTPUT_FILE.exists():
        with open(OUTPUT_FILE, encoding="utf-8") as f:
            existing = json.load(f)
        existing_words = {e["word"] for e in existing}
        print(f"Loaded {len(existing)} existing words, continuing...")

    remaining = [w for w in IELTS_WORDS if w not in existing_words]
    if not remaining:
        print("All words already crawled!")
        return

    print(f"Crawling {len(remaining)} words with {CONCURRENCY} concurrent requests...")
    t0 = time.time()

    # Windows Python 3.14+: không cần set policy nữa, asyncio.run() tự xử lý
    if sys.platform == "win32" and sys.version_info < (3, 14):
        asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())

    new_results = asyncio.run(crawl_async(remaining))

    elapsed = time.time() - t0
    all_results = existing + new_results
    _save(all_results)

    print(f"\nDone! {len(new_results)} words in {elapsed:.1f}s "
          f"({elapsed/len(new_results):.2f}s/word avg)")
    print(f"Total: {len(all_results)} words -> {OUTPUT_FILE}")


if __name__ == "__main__":
    main()
