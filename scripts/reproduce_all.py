#!/usr/bin/env python3
"""Chạy lại toàn bộ đồ án theo thứ tự: test -> dữ liệu -> SPMF -> thực nghiệm -> ứng dụng -> biểu đồ.

    python scripts/reproduce_all.py [--skip-experiments] [--skip-spmf]

Cần Julia trong PATH; SPMF cần Java và spmf.jar ở thư mục gốc (bỏ qua nếu không có).
"""
import os
import subprocess
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
PY = sys.executable


def run(cmd):
    print("\n$", " ".join(cmd), flush=True)
    r = subprocess.run(cmd, cwd=ROOT)
    if r.returncode != 0:
        print(f"!! lệnh thất bại (mã {r.returncode}), dừng.")
        sys.exit(r.returncode)


def main():
    skip_exp = "--skip-experiments" in sys.argv
    skip_spmf = "--skip-spmf" in sys.argv or not os.path.isfile(os.path.join(ROOT, "spmf.jar"))
    run([PY, "scripts/download_data.py"])
    run([PY, "scripts/download_app_data.py"])
    if not skip_spmf:
        run([PY, "scripts/run_spmf.py"])
    else:
        print("\n(bỏ qua SPMF: thiếu spmf.jar hoặc --skip-spmf)")
    run(["julia", "--project", "test/runtests.jl"])
    if not skip_exp:
        run(["julia", "--project", "scripts/gen_data.jl", "avglen"])
        run([PY, "scripts/run_experiments.py"])
        run([PY, "scripts/plot_results.py"])
    run(["julia", "--project", "scripts/app1_market_basket.jl", "retail"])
    run(["julia", "--project", "scripts/app1_market_basket.jl", "groceries"])
    run(["julia", "--project", "scripts/app2_splice.jl"])
    run([PY, "scripts/plot_apps.py"])
    print("\nXong. Kết quả: results/, results/apps/, docs/figures/")


if __name__ == "__main__":
    main()
