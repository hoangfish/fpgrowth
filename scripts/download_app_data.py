#!/usr/bin/env python3
"""Tải dữ liệu cho hai ứng dụng vào data/apps/ (Windows/Mac/Linux, chỉ dùng thư viện chuẩn).

    python scripts/download_app_data.py

* splice.data   : UCI Molecular Biology (Splice-junction Gene Sequences), 3190 chuỗi.
                  Trang dữ liệu: https://archive.ics.uci.edu/dataset/69
* groceries.csv : giỏ hàng Groceries (9835 giỏ, 169 mặt hàng, có TÊN mặt hàng).

Retail (ứng dụng 1) đã được tải bởi scripts/download_data.py.
Nếu một link lỗi, tải tay từ trình duyệt và đặt đúng tên vào data/apps/.
"""
import io
import os
import urllib.request
import zipfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
DEST = os.path.join(ROOT, "data", "apps")
UA = {"User-Agent": "Mozilla/5.0"}

SPLICE_URLS = [
    "https://archive.ics.uci.edu/ml/machine-learning-databases/molecular-biology/"
    "splice-junction-gene-sequences/splice.data",
    "https://archive.ics.uci.edu/static/public/69/molecular+biology+splice+junction+gene+sequences.zip",
]
GROCERIES_URLS = [
    "https://raw.githubusercontent.com/stedy/Machine-Learning-with-R-datasets/master/groceries.csv",
]


def get(url):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read()


def fetch(urls, out, member=None):
    for url in urls:
        try:
            print("  thử", url, flush=True)
            data = get(url)
            if url.endswith(".zip"):
                with zipfile.ZipFile(io.BytesIO(data)) as z:
                    name = next(n for n in z.namelist() if n.endswith(member))
                    data = z.read(name)
            with open(out, "wb") as f:
                f.write(data)
            return True
        except Exception as e:  # noqa: BLE001
            print("   lỗi:", e)
    return False


def main():
    os.makedirs(DEST, exist_ok=True)
    for name, urls, member in (("splice.data", SPLICE_URLS, "splice.data"),
                               ("groceries.csv", GROCERIES_URLS, None)):
        out = os.path.join(DEST, name)
        if os.path.isfile(out) and os.path.getsize(out) > 0:
            print(name, "đã có, bỏ qua")
            continue
        print("Tải", name)
        if not fetch(urls, out, member):
            print(f"!! Không tải được {name}. Tải tay rồi đặt vào {DEST}")
    for name, expect in (("splice.data", 3190), ("groceries.csv", 9835)):
        p = os.path.join(DEST, name)
        if os.path.isfile(p):
            with open(p, "rb") as f:
                n = sum(1 for line in f if line.strip())
            print(f"  {name:14s} {n} dòng (mong đợi ~ {expect})")
        else:
            print(f"  {name:14s} THIẾU")


if __name__ == "__main__":
    main()
