#!/usr/bin/env python3
"""Tải dữ liệu benchmark thật vào data/benchmark/ (Windows/Mac/Linux, chỉ dùng thư viện chuẩn).

    python scripts/download_data.py

Nguồn chính: SPMF Public Datasets (định dạng SPMF, item id dương nên SPMF đọc được).
Nguồn dự phòng: FIMI (site này đôi khi không truy cập được).
Lưu ý: mushrooms.txt của SPMF có 8416 giao dịch, khác bản FIMI (8124) trong bảng của đề;
hãy ghi chú điều này trong báo cáo.
"""
import gzip
import os
import shutil
import urllib.request

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
DEST = os.path.join(ROOT, "data", "benchmark")
SPMF = "https://www.philippe-fournier-viger.com/spmf/publicdatasets/"
SPMF_HTTP = "http://www.philippe-fournier-viger.com/spmf/publicdatasets/"
FIMI = "http://fimi.uantwerpen.be/data/"
# tên lưu -> danh sách URL thử lần lượt
SOURCES = {
    "chess.txt":      [SPMF + "chess.txt", SPMF_HTTP + "chess.txt", FIMI + "chess.dat"],
    "mushroom.txt":   [SPMF + "mushrooms.txt", SPMF_HTTP + "mushrooms.txt", FIMI + "mushroom.dat"],
    "retail.txt":     [SPMF + "retail.txt", SPMF_HTTP + "retail.txt", FIMI + "retail.dat.gz"],
    "T10I4D100K.txt": [SPMF + "T10I4D100K.txt", SPMF_HTTP + "T10I4D100K.txt", FIMI + "T10I4D100K.dat"],
    "accidents.txt":  [SPMF + "accidents.txt", SPMF_HTTP + "accidents.txt", FIMI + "accidents.dat.gz"],  # tuỳ chọn, lớn
}
OPTIONAL = {"accidents.txt"}
EXPECT = {"chess.txt": 3196, "mushroom.txt": "8416 (SPMF) hoặc 8124 (FIMI)", "retail.txt": 88162,
          "T10I4D100K.txt": 100000, "accidents.txt": 340183}


def looks_like_data(path):
    with open(path, "rb") as f:
        head = f.read(300)
    return head[:1].isdigit() or head[:1] in (b"@", b"#", b"%")   # không phải trang HTML lỗi


def fetch(name, out):
    for url in SOURCES[name]:
        tmp = out + ".part"
        try:
            print("  thử", url, flush=True)
            req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=60) as r, open(tmp, "wb") as f:
                shutil.copyfileobj(r, f)
            if url.endswith(".gz"):
                with gzip.open(tmp, "rb") as fi, open(out, "wb") as fo:
                    shutil.copyfileobj(fi, fo)
                os.remove(tmp)
            else:
                os.replace(tmp, out)
            if not looks_like_data(out):
                print("   file tải về không phải dữ liệu (có thể là trang lỗi), bỏ")
                os.remove(out)
                continue
            return True
        except Exception as e:  # noqa: BLE001
            print("   lỗi:", e)
            if os.path.exists(tmp):
                os.remove(tmp)
    return False


def main():
    os.makedirs(DEST, exist_ok=True)
    for name in SOURCES:
        out = os.path.join(DEST, name)
        if os.path.isfile(out) and os.path.getsize(out) > 0:
            print(name, "đã có, bỏ qua")
            continue
        print("Tải", name)
        if not fetch(name, out) and name not in OPTIONAL:
            print(f"!! Không tải được {name}. Mở trình duyệt tải tay: {SOURCES[name][0]}\n"
                  f"   rồi lưu vào {DEST} với tên {name}")
    print("\nSố dòng:")
    for name in SOURCES:
        p = os.path.join(DEST, name)
        if os.path.isfile(p):
            with open(p, "rb") as f:
                n = sum(1 for _ in f)
            print(f"  {name:16s} {n:>8d} dòng   (mong đợi ~ {EXPECT[name]})")
        else:
            print(f"  {name:16s} THIẾU")


if __name__ == "__main__":
    main()
