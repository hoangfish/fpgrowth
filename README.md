# FP-Growth bằng Julia — Đồ án Khai thác tập phổ biến

Tự cài đặt thuật toán **FP-Growth** (Han, Pei, Yin — *Mining Frequent Patterns without Candidate Generation*, SIGMOD 2000)
bằng Julia thuần (không dùng gói ngoài), đối chiếu kết quả với SPMF, thực nghiệm trên 4 tập benchmark
và áp dụng vào hai bài toán thực tế (phân tích giỏ hàng, mẫu trong chuỗi DNA).

## Thành viên

| Họ tên | MSSV | Lớp |
|---|---|---|
| Phạm Hoàng Phúc | 24127502 | 24KHMT1 |

Đồ án do một mình thực hiện, nên toàn bộ công việc dưới đây đều do Phạm Hoàng Phúc đảm nhiệm (đóng góp 100%).

## Phân công và tiến độ

| Chương | Công việc | Người làm | Tiến độ |
|---|---|---|---|
| Chương 1: Cài đặt | Đọc bài báo gốc, cài đặt FP-Growth bản cơ bản (FP-tree, conditional pattern base, cây một nhánh) | Phúc | 100% |
| | Bản tối ưu: cây dạng mảng `Int32`, bảng băm, đánh lại nhãn item, `Workspace`, kết quả dạng phẳng; đo mức cải thiện | Phúc | 100% |
| | Đọc/ghi định dạng SPMF, tham số dòng lệnh (`--minsup`, `--output`, `--algo`) | Phúc | 100% |
| | Bộ kiểm thử tự động (brute-force, Apriori độc lập, 5 CSDL ngẫu nhiên, so khớp SPMF) | Phúc | 100% |
| Chương 2: Thực nghiệm và đánh giá | Chuẩn bị 4 tập benchmark, chạy SPMF đối chứng, kiểm tra correctness | Phúc | 100% |
| | Thời gian chạy và số lượng itemset theo minsup (có đường SPMF) | Phúc | 100% |
| | Bộ nhớ, khả năng mở rộng (10–100% giao dịch), ảnh hưởng độ dài giao dịch | Phúc | 100% |
| | Phân tích điểm mạnh/yếu và đề xuất 3 hướng tối ưu tiếp theo | Phúc | 100% |
| Chương 3: Ứng dụng thực tế | Ứng dụng 1 (giỏ hàng): Retail và Groceries, sinh luật kết hợp, top-10 theo lift, diễn giải | Phúc | 100% |
| | Ứng dụng 2 (sinh học): splice-junction, tập đóng/tối đại, emerging pattern, luật mẫu → lớp, kiểm chứng trên tập test | Phúc | 100% |
| Sản phẩm nộp | Notebook demo trên Google Colab, README, kho GitHub công khai | Phúc | 100% |
| | Báo cáo theo mẫu IEEE (`docs/Report.pdf`) | Phúc | 100% |

## Liên kết

- Kho mã: <https://github.com/hoangfish/fpgrowth>
- Demo notebook Google Colab: _(dán link public tại đây)_
- Dữ liệu benchmark lớn (Hugging Face / Kaggle): _(dán link tại đây)_
- Báo cáo: [`docs/Report.pdf`](docs/Report.pdf)

## Cấu trúc repo

```
├── Project.toml              # gói Julia FPGrowthFIM (không có phụ thuộc ngoài; chỉ dùng stdlib)
├── demo.jl                   # giao diện dòng lệnh
├── src/
│   ├── FPGrowthFIM.jl        # module chính
│   ├── structures.jl         # FIResult: bộ đệm kết quả dạng phẳng
│   ├── fpgrowth_basic.jl     # FP-Growth bản cơ bản (đúng mô tả bài báo, dùng làm mốc)
│   ├── fpgrowth_opt.jl       # FP-Growth bản tối ưu
│   ├── io.jl                 # đọc/ghi định dạng SPMF
│   ├── postprocess.jl        # luật kết hợp, tập đóng/tối đại, mẫu nổi bật (Chương 3)
│   ├── apps.jl               # chuyển dữ liệu thành giao dịch cho hai ứng dụng (Chương 3)
│   └── utils.jl              # minsup, thống kê CSDL, đo RSS
├── test/
│   ├── runtests.jl           # unit test tự động (Chương 1)
│   ├── test_apps.jl          # unit test cho luật kết hợp, tập đóng/tối đại, mã hoá DNA
│   └── reference.jl          # brute-force và Apriori độc lập (chỉ dùng trong test)
├── scripts/
│   ├── gen_data.jl           # sinh dữ liệu tổng hợp (*_like.txt, avglen_T*.txt)
│   ├── bench_one.jl          # đo một cấu hình (thời gian, cấp phát, RSS đỉnh)
│   ├── correctness.jl        # so khớp basic vs opt vs SPMF
│   ├── run_experiments.py    # chạy toàn bộ thực nghiệm Chương 2 → results/*.csv
│   ├── run_spmf.py           # chạy SPMF để lấy kết quả/thời gian đối chứng
│   ├── plot_results.py       # vẽ biểu đồ Chương 2 → docs/figures/
│   ├── app1_market_basket.jl # Ứng dụng 1 (giỏ hàng)
│   ├── app2_splice.jl        # Ứng dụng 2 (sinh học)
│   ├── download_data.py / download_app_data.py   # tải dữ liệu
│   ├── plot_apps.py          # biểu đồ Chương 3
│   └── reproduce_all.py      # chạy lại toàn bộ (test, thực nghiệm, ứng dụng, biểu đồ)
├── data/toy/                 # CSDL nhỏ để test nhanh
├── data/benchmark/           # CSDL benchmark (bản lớn host trên Hugging Face/Kaggle)
├── data/spmf_expected/       # đầu ra của SPMF (do scripts/run_spmf.py sinh ra)
├── notebooks/demo.ipynb      # demo chạy trên Colab (Chương 1, 2, 3)
├── results/                  # CSV kết quả thực nghiệm
└── docs/                     # Report.pdf và figures/
```

## Cài đặt môi trường

Cần **Julia ≥ 1.9** (đã thử với 1.13). Không cần cài gói Julia nào thêm.

```bash
git clone https://github.com/hoangfish/fpgrowth.git
cd fpgrowth
julia --project -e 'using FPGrowthFIM'     # kiểm tra nạp được
```

Để vẽ biểu đồ và chạy thực nghiệm tự động cần thêm Python ≥ 3.9 với `pandas`, `matplotlib`
(chỉ là công cụ điều khiển/vẽ hình, **toàn bộ thuật toán nằm trong Julia**).
Để so với SPMF cần Java và `spmf.jar` (tải tại <https://www.philippe-fournier-viger.com/spmf/>).

## Cách chạy

```bash
# Khai thác từ file định dạng SPMF (mỗi dòng một giao dịch, item cách nhau bởi dấu cách)
julia --project demo.jl --minsup 0.4 --output out.txt data/toy/contextPasquier99.txt
#   --minsup  0.4 hoặc 40%  (tỉ lệ trên tổng số giao dịch, ngưỡng tuyệt đối = ceil(minsup * N) như SPMF)
#   --output  file kết quả theo định dạng SPMF: "1 2 3 #SUP: 5"
#   --algo    opt (mặc định) | basic

# Gọi như thư viện
julia --project -e '
using FPGrowthFIM
db  = read_transactions("data/toy/contextPasquier99.txt")
res = fpgrowth(db, minsup_count(length(db), 0.4))   # FIResult
println(length(res), " frequent itemsets")
d = to_dict(res)                                    # Dict(itemset => support)
write_spmf("out.txt", res)'
```

Ví dụ trên `contextPasquier99` với minsup 40% cho 15 frequent itemset (khớp ví dụ trong tài liệu SPMF).

### Kiểm thử

```bash
python scripts/run_spmf.py                 # sinh data/spmf_expected/ (cần Java + spmf.jar), để so khớp trực tiếp với SPMF
julia --project test/runtests.jl
```

Test kiểm tra (a) ví dụ SPMF và ví dụ trong bài báo, (b) 5 CSDL ngẫu nhiên có cấu trúc, so với
brute-force (≤16 item) hoặc Apriori độc lập, (c) nhiều mức minsup, (d) các trường hợp biên
(CSDL rỗng, minsup > N, một giao dịch, id item thưa), (e) quy đổi minsup, (f) I/O SPMF và CLI,
(g) nếu có `data/spmf_expected/*.txt` thì so khớp trực tiếp với đầu ra SPMF (28 cấu hình: 4 benchmark × 7 mức minsup),
(h) phần hậu xử lý cho Chương 3 (luật kết hợp, tập đóng/tối đại, mẫu nổi bật, mã hoá DNA).

**Kết quả lần chạy cuối:**

```
Test Summary: | Pass  Total   Time
FPGrowthFIM   |   87     87  33.5s
Test Summary:                             | Pass  Total  Time
Ứng dụng: hậu xử lý và chuyển đổi dữ liệu |   56     56  7.1s
```

Nếu chưa chạy `scripts/run_spmf.py` (chưa có `data/spmf_expected/`) thì phần so khớp trực tiếp với SPMF được bỏ qua
và nhóm đầu chỉ còn 60 test.

### Tái lập thực nghiệm Chương 2

```bash
python scripts/download_data.py                # tải 4 tập benchmark (+ accidents) từ SPMF vào data/benchmark/
julia --project scripts/gen_data.jl avglen     # sinh dữ liệu độ dài giao dịch (T5..T30)
python scripts/run_spmf.py                     # đối chứng SPMF (cần Java + spmf.jar)
python scripts/run_experiments.py              # main | scal | avglen | correct (chạy lâu, khoảng 15 phút)
python scripts/plot_results.py                 # → docs/figures/*.png, results/*_table.csv
```

Dữ liệu thật (chess, mushroom, retail, T10I4D100K) đặt vào `data/benchmark/` với tên
`chess.txt`, `mushroom.txt`, `retail.txt`, `T10I4D100K.txt` (lấy từ SPMF, cùng định dạng).
Nếu có file thật, scripts ưu tiên dùng; nếu không, dùng bản tổng hợp `*_like.txt` (thống kê gần giống nhưng
**không phải dữ liệu thật**, nên số liệu tuyệt đối khác với báo cáo).

Lưu ý: bản Mushroom của SPMF có **8416** giao dịch, không phải 8124 như bản UCI/FIMI gốc.

## Chạy trên Google Colab

Mở `notebooks/demo.ipynb` trên Colab (Colab chỉ hỗ trợ kernel Python nên notebook tự tải Julia chính thức,
rồi gọi Julia qua lệnh shell). Chạy toàn bộ bằng **Runtime → Run all**. Notebook gồm: cài Julia, clone repo,
chạy test, chạy demo CLI, tải dữ liệu benchmark, thực nghiệm và biểu đồ Chương 2, hai ứng dụng Chương 3.

Trước khi chạy, sửa biến `REPO_URL` ở cell thứ hai thành `https://github.com/hoangfish/fpgrowth.git`.

## Hai bản cài đặt

| | `fpgrowth_basic` | `fpgrowth` (tối ưu) |
|---|---|---|
| Node cây | object `BNode` | chỉ số nguyên trong mảng `Int32` (struct-of-arrays) |
| Con của node | `Dict{Int,BNode}` | first-child / next-sibling cho duyệt; tra "con theo nhãn" bằng bảng băm địa chỉ mở dùng chung (O(1)) |
| Header table | `Dict{Int,Vector{BNode}}` | mảng `head` + `link` |
| Nhãn item | id gốc | rank tần suất; conditional tree đánh nhãn cục bộ 1..k |
| Buffer | cấp phát mới mỗi lần | `Workspace` dùng lại |
| Kết quả | `Vector{Tuple{Vector{Int},Int}}` | `FIResult` phẳng (items/offsets/supports) |

Cả hai đều xử lý riêng trường hợp cây một nhánh (sinh tổ hợp trực tiếp, không đệ quy) như bài báo.

## Kết quả chính

- **Đúng đắn:** khớp SPMF 100% trên 28 cấu hình (4 benchmark × 7 mức minsup).
- **Tối ưu:** bản tối ưu nhanh hơn bản cơ bản từ 0,58× đến 6,56× (trung vị 2,5×), cấp phát ít hơn tối đa 10,4×.
- **So với SPMF** (end-to-end, cùng máy): bản tối ưu nhanh hơn ở 26/28 cấu hình.
- **Mở rộng:** thời gian tăng gần tuyến tính theo số giao dịch (số mũ 0,90 trên Retail, 1,16 trên T10I4D100K).
- **Ứng dụng 2:** tìm lại tín hiệu cắt nối đã biết (GT ở EI, AG ở IE, polypyrimidine tract); accuracy 0,887 trên tập kiểm tra.

Chi tiết và biểu đồ xem trong [`docs/Report.pdf`](docs/Report.pdf).

## Ghi chú

- Mã nguồn tự viết từ mô tả trong bài báo; **không** sao chép hay đọc mã của SPMF/GitHub.
  SPMF chỉ dùng làm đáp án đối chiếu (chạy `scripts/run_spmf.py`).
- Có dùng trợ lý AI (Claude) hỗ trợ viết mã và tài liệu; tác giả đã đọc, chạy kiểm thử và có thể giải thích toàn bộ bài làm.
- Seed ngẫu nhiên cố định (`MersenneTwister`) cho dữ liệu tổng hợp, lấy mẫu scalability và test.
- Thời gian "khai thác" không tính I/O; thời gian "end-to-end" gồm đọc file, khai thác và ghi file
  (tương đương cách SPMF tính) — dùng cột này khi so với SPMF.
- `.gitignore` loại `data/benchmark/*.txt`, `data/apps/` và `data/spmf_expected/` (dữ liệu lớn); các script
  trên sẽ tải/sinh lại khi cần.

## Chương 3: hai ứng dụng

Cả hai ứng dụng dùng `fpgrowth` của nhóm; luật kết hợp, tập đóng/tối đại và mẫu nổi bật nằm trong `src/postprocess.jl`, phần chuyển đổi dữ liệu trong `src/apps.jl`. Notebook: phần 7 của `notebooks/demo.ipynb`.

```bash
python scripts/download_data.py        # Retail (đã có từ Chương 2)
python scripts/download_app_data.py    # splice.data (UCI) và groceries.csv

julia --project scripts/app1_market_basket.jl retail     # Ứng dụng 1 (luật kết hợp, top-10 theo lift)
julia --project scripts/app1_market_basket.jl groceries
julia --project scripts/app2_splice.jl                   # Ứng dụng 2 (splice-junction)
python scripts/plot_apps.py                              # biểu đồ -> docs/figures/app*.png
```

Kết quả CSV nằm trong `results/apps/`.

Chạy lại toàn bộ bằng một lệnh: `python scripts/reproduce_all.py` (thêm `--skip-experiments` để bỏ qua
thực nghiệm Chương 2, vốn chạy lâu).