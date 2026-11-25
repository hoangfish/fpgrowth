#!/usr/bin/env python3
"""Chạy toàn bộ thực nghiệm Chương 2 và ghi kết quả vào results/*.csv.

Công cụ điều khiển (driver) viết bằng Python chỉ để gọi các tiến trình Julia riêng lẻ
(đo RSS đỉnh chính xác, có timeout). TOÀN BỘ thuật toán nằm trong Julia (src/).

    python3 scripts/run_experiments.py            # chạy tất cả
    python3 scripts/run_experiments.py main       # chỉ thời gian/minsup, số itemset, bộ nhớ
    python3 scripts/run_experiments.py scal       # scalability
    python3 scripts/run_experiments.py avglen     # ảnh hưởng độ dài giao dịch
    python3 scripts/run_experiments.py correct    # correctness

Ưu tiên dữ liệu thật nếu có data/benchmark/<name>.txt (chess, mushroom, retail,
T10I4D100K); nếu không dùng bản tổng hợp <name>_like.txt.
"""
import csv
import os
import subprocess
import sys
import time

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
BENCH = os.path.join(ROOT, "data", "benchmark")
RES = os.path.join(ROOT, "results")
JULIA = os.environ.get("JULIA", "julia")
TIMEOUT = int(os.environ.get("EXP_TIMEOUT", "300"))
os.makedirs(RES, exist_ok=True)

# Lưới minsup (giảm dần). Dữ liệu thật dày hơn nên cần ngưỡng cao hơn bản _like.
GRIDS_REAL = {
    "chess":       [0.95, 0.9, 0.85, 0.8, 0.75, 0.7, 0.65],
    "mushroom":    [0.5, 0.4, 0.3, 0.25, 0.2, 0.15, 0.1],
    "retail":      [0.02, 0.01, 0.005, 0.003, 0.002, 0.001, 0.0005],
    "T10I4D100K":  [0.02, 0.01, 0.005, 0.003, 0.002, 0.001, 0.0005],
}
GRIDS_LIKE = {
    "chess":       [0.9, 0.8, 0.7, 0.6, 0.5, 0.45, 0.4],
    "mushroom":    [0.3, 0.2, 0.15, 0.1, 0.08, 0.05, 0.04],
    "retail":      [0.02, 0.01, 0.006, 0.004, 0.003, 0.002, 0.001],
    "T10I4D100K":  [0.02, 0.01, 0.005, 0.003, 0.002, 0.001, 0.0005],
}
ALGOS = ["opt", "basic"]
HEADER = ["algo", "dataset", "frac", "minsup", "minsup_abs", "ntrans", "n_itemsets",
          "time_s", "time_e2e_s", "alloc_mb", "rss_load_mb", "peak_rss_mb", "status"]


def resolve(name):
    """Trả về (đường dẫn file, nhãn dataset, lưới minsup)."""
    real = os.path.join(BENCH, name + ".txt")
    like = os.path.join(BENCH, name + "_like.txt")
    if os.path.isfile(real):
        return real, name, GRIDS_REAL[name]
    if os.path.isfile(like):
        return like, name + "_like", GRIDS_LIKE[name]
    raise FileNotFoundError(f"thiếu {real} và {like}; chạy scripts/gen_data.jl hoặc tải dữ liệu FIMI")


def run_one(algo, path, minsup, frac=1.0):
    cmd = [JULIA, "--project=" + ROOT, os.path.join(ROOT, "scripts", "bench_one.jl"),
           algo, path, str(minsup), str(frac)]
    t0 = time.time()
    try:
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=TIMEOUT)
    except subprocess.TimeoutExpired:
        return None, "timeout"
    if p.returncode != 0:
        return None, "error"
    line = [l for l in p.stdout.strip().splitlines() if "," in l][-1]
    return line.split(","), "ok"


def log(msg):
    print(time.strftime("%H:%M:%S"), msg, flush=True)


def sweep(out_name, jobs):
    """jobs: danh sách (algo, path, label, frac, minsup). Bỏ qua các minsup thấp hơn sau khi
    một thuật toán đã timeout/lỗi ở cùng (dataset, frac) vì chi phí chỉ tăng khi minsup giảm."""
    out = os.path.join(RES, out_name)
    with open(out, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(HEADER)
        dead = set()
        for algo, path, label, frac, minsup in jobs:
            key = (algo, label, frac)
            if key in dead:
                w.writerow([algo, label, frac, minsup, "", "", "", "", "", "", "", "skipped"])
                f.flush()
                continue
            row, status = run_one(algo, path, minsup, frac)
            if row is None:
                dead.add(key)
                w.writerow([algo, label, frac, minsup, "", "", "", "", "", "", "", status])
                log(f"{out_name}: {algo} {label} minsup={minsup} -> {status}")
            else:
                row[1] = label
                w.writerow(row + ["ok"])
                log(f"{out_name}: {','.join(row)}")
            f.flush()


def exp_main():
    jobs = []
    for name in ["chess", "mushroom", "retail", "T10I4D100K"]:
        path, label, grid = resolve(name)
        for ms in grid:
            for algo in ALGOS:
                jobs.append((algo, path, label, 1.0, ms))
    sweep("main.csv", jobs)


def exp_scal():
    # Scalability: một CSDL lớn, các tập con 10/25/50/75/100% giao dịch, minsup tương đối cố định
    jobs = []
    for name, ms in [("retail", None), ("T10I4D100K", None)]:
        path, label, grid = resolve(name)
        ms = grid[3] if name == "retail" else grid[3]   # mức trung bình của lưới
        for frac in [0.1, 0.25, 0.5, 0.75, 1.0]:
            for algo in ALGOS:
                jobs.append((algo, path, label, frac, ms))
    sweep("scalability.csv", jobs)


def exp_avglen():
    jobs = []
    for T in [5, 10, 15, 20, 25, 30]:
        path = os.path.join(BENCH, f"avglen_T{T}.txt")
        if not os.path.isfile(path):
            raise FileNotFoundError("chạy: julia --project scripts/gen_data.jl avglen")
        for algo in ALGOS:
            jobs.append((algo, path, f"avglen_T{T}", 1.0, 0.01))
    sweep("avglen.csv", jobs)


def exp_correct():
    out = os.path.join(RES, "correctness.csv")
    rows = []
    for name in ["chess", "mushroom", "retail", "T10I4D100K"]:
        path, label, grid = resolve(name)
        # 3 mức minsup (cao, vừa, thấp trong phần dễ) để kiểm tra nhanh
        sel = [str(grid[0]), str(grid[2]), str(grid[4])]
        p = subprocess.run([JULIA, "--project=" + ROOT, os.path.join(ROOT, "scripts", "correctness.jl"),
                            os.path.splitext(os.path.basename(path))[0], *sel],
                           capture_output=True, text=True, timeout=TIMEOUT * 3)
        for line in p.stdout.strip().splitlines():
            if "," in line:
                rows.append(line.split(","))
                log("correctness: " + line)
        if p.returncode != 0:
            log("correctness lỗi: " + p.stderr[-300:])
    with open(out, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["dataset", "minsup", "n_basic", "n_opt", "basic_eq_opt", "n_spmf",
                    "match_vs_spmf", "match_rate_vs_spmf"])
        w.writerows(rows)


def main():
    what = sys.argv[1:] or ["main", "scal", "avglen", "correct"]
    env = os.path.join(RES, "env.txt")
    with open(env, "w") as f:
        f.write(subprocess.run([JULIA, "--version"], capture_output=True, text=True).stdout)
        f.write(subprocess.run("nproc; grep -m1 'model name' /proc/cpuinfo; free -m | head -2",
                               shell=True, capture_output=True, text=True).stdout)
    for w in what:
        {"main": exp_main, "scal": exp_scal, "avglen": exp_avglen, "correct": exp_correct}[w]()


if __name__ == "__main__":
    main()
