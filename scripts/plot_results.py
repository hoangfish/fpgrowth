#!/usr/bin/env python3
"""Vẽ biểu đồ Chương 2 từ results/*.csv vào docs/figures/ và sinh bảng tóm tắt.

    python3 scripts/plot_results.py

Nếu có results/spmf_times.csv (từ scripts/run_spmf.py) sẽ vẽ thêm đường cong SPMF.
Cần: pandas, matplotlib.
"""
import os

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
RES = os.path.join(ROOT, "results")
FIG = os.path.join(ROOT, "docs", "figures")
os.makedirs(FIG, exist_ok=True)

C = {"basic": "#c0504d", "opt": "#1f6fb4", "spmf": "#2e8b57"}
LBL = {"basic": "FP-Growth cơ bản (Julia)", "opt": "FP-Growth tối ưu (Julia)",
       "spmf": "SPMF (Java)"}
plt.rcParams.update({"font.size": 9, "axes.grid": True, "grid.alpha": 0.3,
                     "axes.spines.top": False, "axes.spines.right": False})


def load(name):
    p = os.path.join(RES, name)
    if not os.path.isfile(p):
        return None
    df = pd.read_csv(p)
    return df[df["status"] == "ok"].copy() if "status" in df else df


def datasets_in(df):
    order = ["chess", "mushroom", "retail", "T10I4D100K"]
    return sorted(df["dataset"].unique(), key=lambda d: next((i for i, o in enumerate(order) if d.startswith(o)), 9))


def fig_time_and_count(main, spmf):
    ds = datasets_in(main)
    fig, ax = plt.subplots(2, len(ds), figsize=(3.3 * len(ds), 5.6), squeeze=False)
    for j, d in enumerate(ds):
        g = main[main["dataset"] == d]
        for algo in ["basic", "opt"]:
            h = g[g["algo"] == algo].sort_values("minsup", ascending=False)
            ax[0][j].plot(h["minsup"] * 100, h["time_e2e_s"], "o-", color=C[algo], label=LBL[algo] + " (end-to-end)", ms=4)
        if spmf is not None:
            s = spmf[spmf["dataset"] == d].sort_values("minsup", ascending=False)
            if len(s):
                ax[0][j].plot(s["minsup"] * 100, s["spmf_total_ms"] / 1000, "s--", color=C["spmf"], label=LBL["spmf"], ms=4)
        ax[0][j].set_title(d)
        ax[0][j].set_xscale("log"); ax[0][j].set_yscale("log")
        ax[0][j].invert_xaxis()
        ax[0][j].set_xlabel("minsup (%)"); ax[0][j].set_ylabel("thời gian (s)")
        h = g[g["algo"] == "opt"].sort_values("minsup", ascending=False)
        ax[1][j].plot(h["minsup"] * 100, h["n_itemsets"], "o-", color=C["opt"], ms=4)
        ax[1][j].set_xscale("log"); ax[1][j].set_yscale("log"); ax[1][j].invert_xaxis()
        ax[1][j].set_xlabel("minsup (%)"); ax[1][j].set_ylabel("số frequent itemset")
        ticks = sorted(g["minsup"].unique() * 100, reverse=True)
        ticks = ticks[::2] if len(ticks) > 5 else ticks
        for a in (ax[0][j], ax[1][j]):
            a.set_xticks(ticks)
            a.set_xticklabels([f"{t:g}" for t in ticks], rotation=45)
            a.minorticks_off()
    ax[0][0].legend(fontsize=7)
    fig.suptitle("Thời gian chạy và số lượng frequent itemset theo minsup", y=1.0)
    fig.tight_layout()
    fig.savefig(os.path.join(FIG, "time_and_count_vs_minsup.png"), dpi=200)
    plt.close(fig)


def fig_memory(main):
    ds = datasets_in(main)
    rows = []
    for d in ds:
        g = main[main["dataset"] == d]
        grid = sorted(g["minsup"].unique(), reverse=True)
        mid = grid[len(grid) // 2]
        for algo in ["basic", "opt"]:
            r = g[(g["algo"] == algo) & (g["minsup"] == mid)]
            if len(r):
                r = r.iloc[0]
                rows.append(dict(dataset=d, minsup=mid, algo=algo, alloc_mb=r["alloc_mb"],
                                 peak_delta_mb=r["peak_rss_mb"] - r["rss_load_mb"],
                                 peak_rss_mb=r["peak_rss_mb"], n=r["n_itemsets"]))
    t = pd.DataFrame(rows)
    t.to_csv(os.path.join(RES, "memory_table.csv"), index=False)
    fig, ax = plt.subplots(1, 2, figsize=(8, 3.2))
    x = range(len(ds)); w = 0.38
    for k, algo in enumerate(["basic", "opt"]):
        s = t[t["algo"] == algo].set_index("dataset").reindex(ds)
        ax[0].bar([i + (k - .5) * w for i in x], s["alloc_mb"], w, color=C[algo], label=LBL[algo])
        ax[1].bar([i + (k - .5) * w for i in x], s["peak_delta_mb"].fillna(0.1).clip(lower=0.1), w, color=C[algo])
    for a, tt in zip(ax, ["Bộ nhớ cấp phát trong lần khai thác (MB)", "RSS đỉnh trừ RSS sau khi đọc CSDL (MB)"]):
        a.set_xticks(list(x)); a.set_xticklabels(ds, rotation=15); a.set_yscale("log"); a.set_title(tt, fontsize=8)
    ax[0].legend(fontsize=7)
    fig.suptitle("Sử dụng bộ nhớ tại minsup trung bình của lưới", y=1.02)
    fig.tight_layout()
    fig.savefig(os.path.join(FIG, "memory.png"), dpi=200)
    plt.close(fig)
    return t


def fig_scal(scal):
    ds = datasets_in(scal)
    fig, ax = plt.subplots(1, len(ds), figsize=(3.6 * len(ds), 3.2), squeeze=False)
    for j, d in enumerate(ds):
        g = scal[scal["dataset"] == d]
        for algo in ["basic", "opt"]:
            h = g[g["algo"] == algo].sort_values("frac")
            ax[0][j].plot(h["frac"] * 100, h["time_s"], "o-", color=C[algo], label=LBL[algo], ms=4)
        ax[0][j].set_title(f"{d} (minsup = {g['minsup'].iloc[0] * 100:g}%)")
        ax[0][j].set_xlabel("% giao dịch"); ax[0][j].set_ylabel("thời gian khai thác (s)")
    ax[0][0].legend(fontsize=7)
    fig.tight_layout()
    fig.savefig(os.path.join(FIG, "scalability.png"), dpi=200)
    plt.close(fig)


def fig_avglen(av):
    av = av.copy()
    av["T"] = av["dataset"].str.extract(r"T(\d+)").astype(int)
    fig, ax = plt.subplots(1, 2, figsize=(7.2, 3.2))
    for algo in ["basic", "opt"]:
        h = av[av["algo"] == algo].sort_values("T")
        ax[0].plot(h["T"], h["time_s"], "o-", color=C[algo], label=LBL[algo], ms=4)
    h = av[av["algo"] == "opt"].sort_values("T")
    ax[1].plot(h["T"], h["n_itemsets"], "o-", color=C["opt"], ms=4)
    ax[0].set_xlabel("độ dài giao dịch trung bình T"); ax[0].set_ylabel("thời gian khai thác (s)")
    ax[0].set_yscale("log"); ax[0].legend(fontsize=7)
    ax[1].set_xlabel("độ dài giao dịch trung bình T"); ax[1].set_ylabel("số frequent itemset"); ax[1].set_yscale("log")
    fig.suptitle("Ảnh hưởng của độ dài giao dịch (N=20000, minsup=1%)", y=1.02)
    fig.tight_layout()
    fig.savefig(os.path.join(FIG, "avglen.png"), dpi=200)
    plt.close(fig)


def speedup_table(main):
    p = main.pivot_table(index=["dataset", "minsup"], columns="algo", values=["time_s", "alloc_mb", "n_itemsets"])
    out = pd.DataFrame({
        "n_itemsets": p[("n_itemsets", "opt")],
        "t_basic_s": p[("time_s", "basic")], "t_opt_s": p[("time_s", "opt")],
        "speedup": p[("time_s", "basic")] / p[("time_s", "opt")],
        "alloc_basic_mb": p[("alloc_mb", "basic")], "alloc_opt_mb": p[("alloc_mb", "opt")],
        "alloc_ratio": p[("alloc_mb", "basic")] / p[("alloc_mb", "opt")],
    }).reset_index()
    out.to_csv(os.path.join(RES, "speedup_table.csv"), index=False)
    return out


def main():
    m = load("main.csv")
    if m is None:
        raise SystemExit("chưa có results/main.csv, chạy scripts/run_experiments.py trước")
    sp = None
    p = os.path.join(RES, "spmf_times.csv")
    if os.path.isfile(p):
        sp = pd.read_csv(p)
    fig_time_and_count(m, sp)
    fig_memory(m)
    s = speedup_table(m)
    print(s.round(3).to_string(index=False))
    for name, fn in [("scalability.csv", fig_scal), ("avglen.csv", fig_avglen)]:
        d = load(name)
        if d is not None and len(d):
            fn(d)


if __name__ == "__main__":
    main()
