"""
    FPGrowthFIM

Tự cài đặt thuật toán FP-Growth (Han, Pei, Yin, SIGMOD 2000) bằng Julia thuần
(không phụ thuộc gói ngoài). Có hai bản:

* `fpgrowth_basic`  : bản cơ bản, bám sát mô tả trong bài báo (node là object,
  con của node lưu trong `Dict`, kết quả là `Vector` của cặp (itemset, support)).
* `fpgrowth`        : bản tối ưu (cây lưu dạng struct-of-arrays với `Int32`,
  đánh lại nhãn item theo rank tần suất, cây điều kiện dùng nhãn cục bộ,
  buffer dùng lại, kết quả lưu dạng phẳng).

Cả hai đều nhận `Vector{Vector{Int}}` và ngưỡng support tuyệt đối.
"""
module FPGrowthFIM

include("utils.jl")
include("structures.jl")
include("io.jl")
include("fpgrowth_basic.jl")
include("fpgrowth_opt.jl")
include("postprocess.jl")
include("apps.jl")

export read_transactions, write_spmf, parse_minsup, minsup_count,
       fpgrowth_basic, fpgrowth, FIResult, to_dict, mine_file,
       database_stats, peak_rss_mb, current_rss_mb,
       # hậu xử lý
       Rule, association_rules, closed_itemsets, maximal_itemsets,
       contains_sorted, support_count, EmergingPattern, emerging_patterns,
       # chuyển đổi dữ liệu cho hai ứng dụng
       load_basket_csv, encode_sequence, item_label, pattern_label,
       item_position, item_base, relative_position, load_splice, split_by_class,
       BASES, SPLICE_LEN

end # module
