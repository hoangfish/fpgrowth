# Thực nghiệm kiểm tra tính đúng đắn (Chương 2).
#
#   julia --project scripts/correctness.jl <dataset_name> <minsup> [<minsup> ...]
#
# Với mỗi (dataset, minsup) in một dòng CSV:
#   dataset,minsup,n_basic,n_opt,basic_eq_opt,n_spmf,match_vs_spmf,match_rate_vs_spmf
# * basic_eq_opt: hai bản của nhóm cho cùng tập kết quả (itemset + support).
# * Nếu có data/spmf_expected/<dataset>__<minsup>.txt (sinh bởi scripts/run_spmf.py) thì
#   so khớp từng itemset và support với SPMF; tỉ lệ khớp = |giao| / |hợp|.
#   Nếu chưa có file SPMF, các cột *_spmf để trống.

using FPGrowthFIM

function main(args)
    ds = args[1]
    root = joinpath(@__DIR__, "..")
    path = joinpath(root, "data", "benchmark", ds * ".txt")
    db = read_transactions(path)
    for a in args[2:end]
        minsup = parse(Float64, a)
        ms = minsup_count(length(db), minsup)
        b = to_dict(fpgrowth_basic(db, ms))
        o = to_dict(fpgrowth(db, ms))
        eq = b == o
        n_spmf = ""; match = ""; rate = ""
        # tên file SPMF dùng đúng chuỗi minsup người dùng gõ (ví dụ chess__0.8.txt)
        sp = joinpath(root, "data", "spmf_expected", "$(ds)__$(a).txt")
        if isfile(sp)
            s = FPGrowthFIM.read_spmf_output(sp)
            same = count(p -> get(s, p.first, -1) == p.second, o)
            union_n = length(union(keys(s), keys(o)))
            n_spmf = length(s)
            match = (s == o)
            rate = round(same / max(1, union_n); digits = 6)
        end
        println(join((ds, a, length(b), length(o), eq, n_spmf, match, rate), ','))
        flush(stdout)
    end
end

main(ARGS)
