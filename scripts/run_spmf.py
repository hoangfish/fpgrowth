#!/usr/bin/env python3
"""Chạy SPMF (FPGrowth_itemsets) làm đối chứng, trên CÙNG dataset và lưới minsup với
scripts/run_experiments.py. Cần Java và spmf.jar (tải tại
https://www.philippe-fournier-viger.com/spmf/ , đặt ở thư mục gốc repo hoặc đặt biến
môi trường SPMF_JAR).

    python3 scripts/run_spmf.py

Kết quả:
  * data/spmf_expected/<dataset>__<minsup>.txt : đầu ra của SPMF (test/runtests.jl và
    scripts/correctness.jl sẽ tự so khớp với các file này).
  * results/spmf_times.csv : dataset,minsup,spmf_total_ms,spmf_wall_s,spmf_max_mem_mb
    (scripts/plot_results.py tự vẽ thêm đường cong SPMF nếu file này có).

SPMF được dùng CHỈ để lấy kết quả/thời gian tham chiếu; không đọc hay sao chép mã nguồn SPMF.
"""
import csv
import os
import re
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(__file__))
import run_experiments as ex  # noqa: E402  (dùng lại lưới minsup)

ROOT = ex.ROOT
JAR = os.environ.get("SPMF_JAR", os.path.join(ROOT, "spmf.jar"))
OUTDIR = os.path.join(ROOT, "data", "spmf_expected")
TIMEOUT = int(os.environ.get("EXP_TIMEOUT", "600"))


def main():
    if not os.path.isfile(JAR):
        sys.exit(f"Không thấy {JAR}. Tải spmf.jar rồi đặt ở thư mục gốc hoặc set SPMF_JAR.")
    os.makedirs(OUTDIR, exist_ok=True)
    rows = []
    for name in ["chess", "mushroom", "retail", "T10I4D100K"]:
        path, label, grid = ex.resolve(name)
        base = os.path.splitext(os.path.basename(path))[0]
        for ms in grid:
            out = os.path.join(OUTDIR, f"{base}__{ms}.txt")
            cmd = ["java", "-jar", JAR, "run", "FPGrowth_itemsets", path, out, f"{ms * 100:g}%"]
            t0 = time.time()
            try:
                p = subprocess.run(cmd, capture_output=True, text=True, timeout=TIMEOUT)
            except subprocess.TimeoutExpired:
                print(f"{base} {ms}: timeout")
                break
            wall = time.time() - t0
            m_t = re.search(r"Total time ~ (\d+) ms", p.stdout)
            m_m = re.search(r"Max memory usage:\s*([\d.]+)\s*mb", p.stdout, re.I)
            rows.append([base, ms, m_t.group(1) if m_t else "", round(wall, 3),
                         m_m.group(1) if m_m else ""])
            print(base, ms, rows[-1][2:], flush=True)
    with open(os.path.join(ex.RES, "spmf_times.csv"), "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["dataset", "minsup", "spmf_total_ms", "spmf_wall_s", "spmf_max_mem_mb"])
        w.writerows(rows)


if __name__ == "__main__":
    main()
