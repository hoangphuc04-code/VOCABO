import json, sys
sys.stdout.reconfigure(encoding="utf-8", errors="replace")
from pathlib import Path

data = json.load(open(Path(__file__).parent / "ielts_words.json", encoding="utf-8"))
print(f"Total words: {len(data)}")
print("Sample (first 3):")
for w in data[:3]:
    print(f"  {w['word']}: {w['meaning']} | phonetic={w['phonetic']} | pos={w['part_of_speech']}")
has_meaning  = sum(1 for w in data if w["meaning"] and w["meaning"] != w["word"])
has_phonetic = sum(1 for w in data if w["phonetic"])
has_example  = sum(1 for w in data if w["example"])
print(f"Has meaning:  {has_meaning}/{len(data)}")
print(f"Has phonetic: {has_phonetic}/{len(data)}")
print(f"Has example:  {has_example}/{len(data)}")
