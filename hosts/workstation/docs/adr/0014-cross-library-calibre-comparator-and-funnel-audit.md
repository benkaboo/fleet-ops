---
id: ADR-0014
title: Cross-Library Calibre Comparator, Multi-Stage Funnel Audit, and Throttled Staging Pipeline
date: 2026-10-08
status: Accepted
component: Applications & Media
tags: [calibre, calibre-web, opds, deduplication, wireguard, bandwidth-throttling, epub, python]
---

# ADR-0014: Cross-Library Calibre Comparator, Multi-Stage Funnel Audit, and Throttled Staging Pipeline

* **Status:** Accepted
* **Date:** 2026-10-08
* **Component:** Applications & Media
* **Deciders:** Operator (Ben Maslen), Antigravity AI Agent

---

## Context
1. **The Problem / Requirement:**
   The operator sought to identify books present in his brother's remote Calibre-Web library across WireGuard (`https://books2.dixon.home` / 12,274 books) that are missing from his primary local collection (`D:\Calibre_Library_Main` / 8,434 books) and transfer them safely. However:
   - Naive metadata matching flagged 4,331 books as missing, suffering from significant false positives caused by:
     - Compound / omnibus collections (e.g. *Admiral Hornblower*, *The Book of the New Sun*, *Beast Master's Planet*) where the operator already owns the individual component novels standalone.
     - Subtitle variations, edition tags, and prefix volume numbering (e.g. `1 Artemis Fowl`, `1 On Basilisk Station`, `: A Novel`, `: Book 1`).
     - Author name spelling variants (e.g. `C S Forester` vs `Cecil Scott Forester`, `George R. R. Martin` vs `George R.R. Martin`).
   - A local collection audit was needed first to benchmark internal duplicates, subtitle variants, and local omnibuses.
   - Remote transfers required strict bandwidth limits across WireGuard and zero credential exposure.

2. **Constraints & Trade-offs:**
   - **Zero Library Mutation:** Primary library (`D:\Calibre_Library_Main`) and remote server accessed strictly in read-only mode (`?mode=ro`); zero file modifications, deletions, or writes to library folders. All downloads stage strictly to `D:\Calibre_Imports\From_Brother`.
   - **Zero Credential Exposure:** Authentication prompt handled in-memory only via masked PowerShell prompts (`Read-Host -AsSecureString`); zero plaintext credentials logged or saved to disk.
   - **Bandwidth Throttling:** Network transfers rate-limited to $\le 2.0$ MB/s (~16 Mbps) with 0.5s inter-book pauses to prevent congestion.
   - **Token Economy:** Evaluated LLM full-text ingestion vs local algorithmic TOC inspection. Ingesting full books via LLM would consume 400M+ tokens; local Python stream extraction of EPUB Tables of Contents (`toc.ncx` / `nav.xhtml`) executes in ~15ms per book at 0 token cost.

## Action
1. **Implementation Steps:**
   - Developed `compare_calibre.py` equipped with an OPDS crawler targeting Calibre-Web master feeds (`/opds/books/letter/00`), atom link parsers, and local SQLite read-only ingest.
   - Developed `audit_local_library.py` to benchmark the operator's 8,434 books, identifying 30 ISBN duplicate clusters, 148 exact duplicate clusters, 736 subtitle variations, 19 local omnibuses containing local standalones, and 261 fragmented author spelling clusters.
   - Integrated a 5-Stage Non-Destructive Audit Funnel into `compare_calibre.py`:
     - **Stage 1 (Exact Overlaps):** Matched 7,355 books on full normalized title and author.
     - **Stage 2 (Subtitle & Prefix Variants):** Detected 843 books with subtitle/prefix discrepancies and mapped them to their local match.
     - **Stage 3 (Omnibus & Compound Title Cross-Match):** Detected 52 collections through two-way cross-referencing (remote omnibuses containing local standalones, and remote standalones contained inside local omnibuses via EPUB TOC stream inspection).
     - **Stage 4 (Fuzzy Title Matches):** Title similarity $\ge 85\%$ under normalized author surname/initial keys.
     - **Stage 5 (Truly Missing Candidates):** Isolated 4,024 genuine candidate books (down from 4,331), including 746 from favorite authors and 2 series gaps.
   - Built interactive dark-mode HTML dashboard (`reports/library-comparison.html`) featuring multi-tab views, search filtering, context boxes detailing omnibus contents, and batch download export.
   - Provisioned automation runners `run_compare.ps1` (with `-UseCache` and `-DownloadPureMissing`) and `stage_missing_books.ps1` (with `-Mode PureMissing` bandwidth throttling controls).

2. **Key Parameters:**
   - Local Library: `D:\Calibre_Library_Main\metadata.db` (8,434 books)
   - Remote OPDS: `https://books2.192.168.68.175.nip.io/opds` (12,274 books)
   - Staging Directory: `D:\Calibre_Imports\From_Brother`
   - Bandwidth Throttle: 2.0 MB/s (~16 Mbps)
   - Inter-Request Delay: 0.5s
   - Staging Engine: Atomic `.part` chunks with resume capability

## Consequences
* **Positive:** Reduced transfer queue by 307 false positives (843 variants + 52 omnibuses cleanly categorized); eliminated accidental duplication of multi-book omnibuses; generated persistent visual dashboard; zero credential leakage.
* **Operational:** Staging folder requires manual or CLI batch import (`calibredb add`) into Calibre GUI before the daily `\CalibreSyncDaily` task synchronizes new books to `S:\Media\Books`.
* **Security:** Read-only access guarantees no database lockups or file corruption; credentials isolated to transient process memory.
