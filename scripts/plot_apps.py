#!/usr/bin/env python3
"""Vẽ biểu đồ cho hai ứng dụng từ results/apps/*.csv  ->  docs/figures/app*.png

    python scripts/plot_apps.py
"""
import os

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
RES = os.path.join(ROOT, "results", "apps")
FIG = os.path.join(ROOT, "docs", "figures")
os.makedirs(FIG, exist_ok=True)


def have(name):
    return os.path.isfile(os.path.join(RES, name))


def app1(which):
    top = f"app1_{which}_top10.csv"
    sweep = f"app1_{which}_sweep.csv"
    rules = f"app1_{which}_rules.csv"
    if have(top):
        d = pd.read_csv(os.path.join(RES, top))
        fig, ax = plt.subplots(figsize=(7.5, 3.8))
        lab = [f"{a} → {c}" for a, c in zip(d["antecedent"], d["consequent"])]
        lab = [s if len(s) <= 46 else s[:43] + "..." for s in lab]
        ax.barh(range(len(d))[::-1], d["lift"], color="#3b6ea5")
        ax.set_yticks(range(len(d))[::-1])
        ax.set_yticklabels(lab, fontsize=6.5)
        ax.set_xlabel("lift")
        ax.set_title(f"Top-10 luật theo lift ({which})", fontsize=9)
        fig.tight_layout()
        fig.savefig(os.path.join(FIG, f"app1_{which}_top10.png"), dpi=200)
        plt.close(fig)
    if have(rules):
        d = pd.read_csv(os.path.join(RES, rules))
        if len(d):
            fig, ax = plt.subplots(figsize=(5, 3.6))
            sc = ax.scatter(d["support"], d["confidence"], c=d["lift"], s=8, cmap="viridis")
            ax.set_xscale("log")
            ax.set_xlabel("support")
            ax.set_ylabel("confidence")
            fig.colorbar(sc, label="lift")
            ax.set_title(f"Support - confidence - lift ({which})", fontsize=9)
            fig.tight_layout()
            fig.savefig(os.path.join(FIG, f"app1_{which}_scatter.png"), dpi=200)
            plt.close(fig)
    if have(sweep):
        d = pd.read_csv(os.path.join(RES, sweep))
        fig, ax = plt.subplots(1, 2, figsize=(8, 3.2))
        for ms, g in d.groupby("minsup"):
            ax[0].plot(g["minconf"], g["n_rules"], "o-", ms=3, label=f"minsup={ms:g}")
        ax[0].set_yscale("log")
        ax[0].set_xlabel("minconf")
        ax[0].set_ylabel("số luật")
        ax[0].legend(fontsize=6)
        g = d.drop_duplicates("minsup").sort_values("minsup")
        ax[1].plot(g["minsup"], g["n_itemsets"], "s-", color="#c0392b")
        ax[1].set_xscale("log")
        ax[1].set_yscale("log")
        ax[1].set_xlabel("minsup")
        ax[1].set_ylabel("số frequent itemset")
        fig.suptitle(f"Độ nhạy theo ngưỡng ({which})", fontsize=9)
        fig.tight_layout()
        fig.savefig(os.path.join(FIG, f"app1_{which}_sweep.png"), dpi=200)
        plt.close(fig)


def app2():
    if have("app2_position_freq.csv"):
        d = pd.read_csv(os.path.join(RES, "app2_position_freq.csv"))
        classes = ["EI", "IE", "N"]
        fig, axes = plt.subplots(3, 1, figsize=(8, 5.6), sharex=True)
        for ax, c in zip(axes, classes):
            g = d[d["class"] == c]
            mat = np.zeros((4, 60))
            pos = sorted(g["rel_pos"].unique())
            for j, p in enumerate(pos):
                for i, b in enumerate("ACGT"):
                    mat[i, j] = g[(g["rel_pos"] == p) & (g["base"] == b)]["freq"].iloc[0]
            im = ax.imshow(mat, aspect="auto", cmap="magma", vmin=0, vmax=1)
            ax.set_yticks(range(4))
            ax.set_yticklabels(list("ACGT"), fontsize=7)
            ax.set_ylabel(f"lớp {c}", fontsize=8)
            ax.axvline(29.5, color="white", lw=0.8, ls="--")
        axes[-1].set_xticks(range(0, 60, 5))
        axes[-1].set_xticklabels([str(pos[i]) for i in range(0, 60, 5)], fontsize=6)
        axes[-1].set_xlabel("vị trí so với ranh giới (đường nét đứt)")
        fig.colorbar(im, ax=axes, label="tần suất", shrink=0.8)
        fig.suptitle("Tần suất nucleotide theo vị trí và lớp", fontsize=9)
        fig.savefig(os.path.join(FIG, "app2_position_freq.png"), dpi=200, bbox_inches="tight")
        plt.close(fig)
    if have("app2_minsup_sweep.csv"):
        d = pd.read_csv(os.path.join(RES, "app2_minsup_sweep.csv"))
        fig, ax = plt.subplots(1, 2, figsize=(8, 3.2))
        for c, g in d.groupby("class"):
            ax[0].plot(g["minsup"], g["n_itemsets"], "o-", ms=3, label=f"{c} frequent")
            ax[0].plot(g["minsup"], g["n_maximal"], "x--", ms=3, label=f"{c} maximal")
            ax[1].plot(g["minsup"], g["t_mine_s"], "o-", ms=3, label=c)
        ax[0].set_yscale("log")
        ax[0].invert_xaxis()
        ax[1].invert_xaxis()
        ax[0].set_xlabel("minsup (trong lớp)")
        ax[0].set_ylabel("số itemset")
        ax[0].legend(fontsize=6)
        ax[1].set_xlabel("minsup (trong lớp)")
        ax[1].set_ylabel("thời gian khai thác (s)")
        ax[1].legend(fontsize=6)
        fig.tight_layout()
        fig.savefig(os.path.join(FIG, "app2_minsup_sweep.png"), dpi=200)
        plt.close(fig)
    if have("app2_class_rules.csv"):
        d = pd.read_csv(os.path.join(RES, "app2_class_rules.csv"))
        fig, axes = plt.subplots(1, 3, figsize=(10, 3.4))
        for ax, c in zip(axes, ["EI", "IE", "N"]):
            g = d[d["class"] == c].head(8)
            ax.barh(range(len(g))[::-1], g["lift"], color="#2e8b57")
            ax.set_yticks(range(len(g))[::-1])
            ax.set_yticklabels([s if len(s) <= 28 else s[:25] + "..." for s in g["antecedent"]], fontsize=6)
            ax.set_title(f"mẫu → {c}", fontsize=8)
            ax.set_xlabel("lift")
        fig.tight_layout()
        fig.savefig(os.path.join(FIG, "app2_class_rules.png"), dpi=200)
        plt.close(fig)


if __name__ == "__main__":
    for w in ("retail", "groceries"):
        app1(w)
    app2()
    print("Đã vẽ biểu đồ vào", FIG)
