"""Spike S6: scores embedding models, BM25 and a hybrid on the local corpus.

Known-item retrieval: each query was written from one document, which is the
only relevant answer. Models run locally through Ollama; Apple's
NLContextualEmbedding vectors come from `S6Embeddings nlembed`.
Usage: python3 evaluate.py .data/corpus.jsonl .data/queries.jsonl [.data/nl-vectors.json]
Prints aggregate metrics only and writes .data/s6-results.json.
"""
import json
import re
import sqlite3
import sys
import time
import urllib.request

import mlx.core as mx

MODELS = [
    # name, Ollama id, query prefix, passage prefix, parameters, license
    ("bge-m3", "bge-m3", "", "", "568M", "MIT"),
    ("embeddinggemma", "embeddinggemma", "task: search result | query: ", "title: none | text: ", "308M", "Gemma Terms of Use"),
    ("qwen3-embedding-0.6b", "qwen3-embedding:0.6b",
     "Instruct: Given a search query, retrieve the document it refers to\nQuery: ", "", "596M", "Apache-2.0"),
    ("granite-embedding-278m", "granite-embedding:278m", "", "", "278M", "Apache-2.0"),
    ("nomic-embed-text-v1.5", "nomic-embed-text", "search_query: ", "search_document: ", "137M", "Apache-2.0"),
]


def embed(model: str, texts: list[str], batch: int = 16) -> list[list[float]]:
    vectors = []
    for start in range(0, len(texts), batch):
        body = json.dumps({"model": model, "input": texts[start:start + batch], "truncate": True}).encode()
        request = urllib.request.Request("http://127.0.0.1:11434/api/embed", data=body,
                                         headers={"Content-Type": "application/json"})
        with urllib.request.urlopen(request, timeout=600) as response:
            vectors.extend(json.loads(response.read())["embeddings"])
    return vectors


def rankings(query_vectors, passage_vectors, passage_docs, document_count: int) -> list[list[int]]:
    queries = mx.array(query_vectors)
    passages = mx.array(passage_vectors)
    queries = queries / mx.linalg.norm(queries, axis=1, keepdims=True)
    passages = passages / mx.linalg.norm(passages, axis=1, keepdims=True)
    similarities = (queries @ passages.T).tolist()
    ranked = []
    for row in similarities:
        best = [-2.0] * document_count  # a document scores as its best chunk
        for value, document in zip(row, passage_docs):
            if value > best[document]:
                best[document] = value
        ranked.append(sorted(range(document_count), key=lambda d: -best[d])[:10])
    return ranked


def bm25_rankings(documents, queries) -> list[list[int]]:
    database = sqlite3.connect(":memory:")
    database.execute("CREATE VIRTUAL TABLE doc USING fts5(text, tokenize='unicode61 remove_diacritics 2')")
    database.executemany("INSERT INTO doc(rowid, text) VALUES (?, ?)",
                         [(d["id"] + 1, " ".join(d["chunks"])) for d in documents])
    ranked = []
    for query in queries:
        terms = [t for t in re.findall(r"\w+", query["text"].lower()) if len(t) >= 3]
        if not terms:
            ranked.append([])
            continue
        expression = " OR ".join('"' + t.replace('"', "") + '"' for t in terms)
        rows = database.execute("SELECT rowid FROM doc WHERE doc MATCH ? ORDER BY bm25(doc) LIMIT 10", (expression,)).fetchall()
        ranked.append([r[0] - 1 for r in rows])
    return ranked


def reciprocal_rank_fusion(*lists: list[int], k: int = 60) -> list[int]:
    scores: dict[int, float] = {}
    for ranking in lists:
        for position, document in enumerate(ranking):
            scores[document] = scores.get(document, 0.0) + 1.0 / (k + position + 1)
    return sorted(scores, key=lambda d: -scores[d])[:10]


def metrics(ranked: list[list[int]], queries: list[dict], languages: dict[int, str]) -> dict:
    def score(subset):
        if not subset:
            return {}
        hits = {1: 0, 5: 0, 10: 0}
        reciprocal = 0.0
        for ranking, query in subset:
            if query["doc"] in ranking:
                position = ranking.index(query["doc"]) + 1
                reciprocal += 1.0 / position
                for cutoff in hits:
                    hits[cutoff] += position <= cutoff
        n = len(subset)
        return {"n": n, "R@1": hits[1] / n, "R@5": hits[5] / n, "R@10": hits[10] / n, "MRR@10": reciprocal / n}

    pairs = list(zip(ranked, queries))
    return {
        "all": score(pairs),
        "query_it": score([p for p in pairs if p[1]["lang"] == "it"]),
        "query_en": score([p for p in pairs if p[1]["lang"] == "en"]),
        "same_language": score([p for p in pairs if p[1]["lang"] == languages[p[1]["doc"]]]),
        "cross_language": score([p for p in pairs if p[1]["lang"] != languages[p[1]["doc"]]]),
    }


def main(corpus_path: str, queries_path: str, nl_path: str | None) -> None:
    documents = [json.loads(line) for line in open(corpus_path, encoding="utf-8")]
    languages = {d["id"]: d["language"] for d in documents}
    rows = [json.loads(line) for line in open(queries_path, encoding="utf-8")]
    queries = [{"doc": r["doc"], "lang": lang, "text": r[lang]} for r in rows for lang in ("it", "en") if r.get(lang)]
    passages = [(d["id"], chunk) for d in documents for chunk in d["chunks"]]
    passage_docs = [p[0] for p in passages]
    results: dict = {"documents": len(documents), "queries": len(queries), "passages": len(passages), "models": {}}

    bm25 = bm25_rankings(documents, queries)
    results["models"]["BM25 (FTS5)"] = {"metrics": metrics(bm25, queries, languages)}

    best_name, best_mrr, best_ranked = None, -1.0, None
    for name, model, query_prefix, passage_prefix, parameters, license_name in MODELS:
        started = time.time()
        passage_vectors = embed(model, [passage_prefix + p[1] for p in passages])
        passage_seconds = time.time() - started
        query_vectors = embed(model, [query_prefix + q["text"] for q in queries])
        ranked = rankings(query_vectors, passage_vectors, passage_docs, len(documents))
        scored = metrics(ranked, queries, languages)
        results["models"][name] = {
            "metrics": scored, "dimension": len(passage_vectors[0]), "parameters": parameters, "license": license_name,
            "passages_per_second_ollama_metal": len(passages) / passage_seconds,
        }
        if scored["all"]["MRR@10"] > best_mrr:
            best_name, best_mrr, best_ranked = name, scored["all"]["MRR@10"], ranked
        print(f"{name}: done", file=sys.stderr)

    if nl_path:
        nl = json.load(open(nl_path))
        nl_queries = {(q["doc"], q["lang"]): q["vector"] for q in nl["queries"]}
        ranked = rankings([nl_queries[(q["doc"], q["lang"])] for q in queries],
                          [p["vector"] for p in nl["passages"]], [p["doc"] for p in nl["passages"]], len(documents))
        results["models"]["NLContextualEmbedding (Apple)"] = {
            "metrics": metrics(ranked, queries, languages), "dimension": nl["dimension"], "parameters": "sistema",
            "license": "Apple (API di sistema)", "passages_per_second_native": len(nl["passages"]) / nl["passage_seconds"],
        }

    hybrid = [reciprocal_rank_fusion(b, e) for b, e in zip(bm25, best_ranked)]
    results["models"][f"Ibrido RRF (BM25 + {best_name})"] = {"metrics": metrics(hybrid, queries, languages)}

    json.dump(results, open(".data/s6-results.json", "w"), indent=2, ensure_ascii=False)
    print(f"{'modello':42s} {'R@1':>6} {'R@10':>6} {'MRR':>6} {'IT':>6} {'EN':>6} {'cross':>6} {'pass/s':>8}")
    for name, entry in results["models"].items():
        m = entry["metrics"]
        speed = entry.get("passages_per_second_ollama_metal") or entry.get("passages_per_second_native") or 0
        print(f"{name:42s} {m['all']['R@1']:6.3f} {m['all']['R@10']:6.3f} {m['all']['MRR@10']:6.3f} "
              f"{m['query_it']['MRR@10']:6.3f} {m['query_en']['MRR@10']:6.3f} {m['cross_language']['MRR@10']:6.3f} {speed:8.1f}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else None)
