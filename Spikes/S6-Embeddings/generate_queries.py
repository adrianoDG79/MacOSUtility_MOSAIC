"""Spike S6: writes one Italian and one English search query per corpus document.

Uses a local model through Ollama (127.0.0.1); nothing leaves the Mac.
Usage: python3 generate_queries.py .data/corpus.jsonl .data/queries.jsonl
"""
import json
import sys
import time
import urllib.request

MODEL = "qwen2.5:7b"
PROMPT = """You help evaluate a desktop search engine.
Below is the beginning of a document stored on someone's Mac. Write the two short queries
(4 to 9 words each) that this person could type into the search box to find it again:
one in Italian and one in English. Describe the subject in your own words. Do not copy long
phrases, file names, codes, reference numbers or dates from the text.
Answer only with JSON: {{"it": "...", "en": "..."}}

Document:
{text}
"""


def generate(text: str) -> dict:
    body = json.dumps({
        "model": MODEL,
        "prompt": PROMPT.format(text=text[:1500]),
        "format": "json",
        "stream": False,
        "options": {"temperature": 0.3},
    }).encode()
    request = urllib.request.Request("http://127.0.0.1:11434/api/generate", data=body,
                                     headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(request, timeout=180) as response:
        return json.loads(json.loads(response.read())["response"])


def main(corpus_path: str, output_path: str) -> None:
    documents = [json.loads(line) for line in open(corpus_path, encoding="utf-8")]
    started = time.time()
    with open(output_path, "w", encoding="utf-8") as output:
        for index, document in enumerate(documents):
            try:
                queries = generate(" ".join(document["chunks"]))
            except Exception as error:  # a failed document is skipped, not fatal
                print(f"doc {document['id']}: {error}", file=sys.stderr)
                continue
            row = {"doc": document["id"], "it": str(queries.get("it", "")).strip(), "en": str(queries.get("en", "")).strip()}
            output.write(json.dumps(row, ensure_ascii=False) + "\n")
            if index % 25 == 0:
                print(f"{index + 1}/{len(documents)} in {time.time() - started:.0f} s", file=sys.stderr)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
