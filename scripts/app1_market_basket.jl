# Ứng dụng 1: phân tích giỏ hàng (Market Basket Analysis) bằng FP-Growth tự cài đặt.
#
#   julia --project scripts/app1_market_basket.jl <retail|groceries> [minsup] [minconf]
#
# retail    : data/benchmark/retail.txt (định dạng SPMF, item là mã số ẩn danh)
# groceries : data/apps/groceries.csv   (mỗi dòng một giỏ, tên mặt hàng cách nhau dấu phẩy)
#
# Quy trình: đọc giao dịch -> fpgrowth (của nhóm) -> sinh luật kết hợp (src/postprocess.jl)
# -> lọc lift > 1 -> top-10 theo lift. Ghi kết quả vào results/apps/.
using FPGrowthFIM
using Printf

const ROOT = normpath(joinpath(@__DIR__, ".."))
const OUT = joinpath(ROOT, "results", "apps")

item_name(names::Vector{String}, id::Int) = isempty(names) ? "#" * string(id) : names[id]
set_name(names::Vector{String}, s::Vector{Int}) =
    "{" * join((replace(item_name(names, i), ',' => ';') for i in s), " | ") * "}"

function load_dataset(which::AbstractString)
    if which == "retail"
        path = joinpath(ROOT, "data", "benchmark", "retail.txt")
        isfile(path) || error("Không thấy $path (chạy scripts/download_data.py)")
        return read_transactions(path), String[], 0.001, 0.3
    elseif which == "groceries"
        path = joinpath(ROOT, "data", "apps", "groceries.csv")
        isfile(path) || error("Không thấy $path (chạy scripts/download_app_data.py)")
        db, names = load_basket_csv(path)
        return db, names, 0.005, 0.25
    else
        error("dataset phải là retail hoặc groceries")
    end
end

"Chọn top-k luật, mỗi itemset (A ∪ C) chỉ lấy một hướng (lift đối xứng nên hai hướng trùng lift)."
function top_distinct(rules::Vector{Rule}, k::Int; min_count::Int = 0)
    seen = Set{Vector{Int}}()
    out = Rule[]
    for r in rules
        r.count < min_count && continue
        key = sort(vcat(r.antecedent, r.consequent))
        key in seen && continue
        push!(seen, key)
        push!(out, r)
        length(out) >= k && break
    end
    return out
end

function write_rules(path, rules, names)
    open(path, "w") do io
        println(io, "antecedent,consequent,count,support,confidence,lift,leverage,conviction")
        for r in rules
            @printf(io, "\"%s\",\"%s\",%d,%.6f,%.4f,%.4f,%.6f,%s\n",
                    set_name(names, r.antecedent), set_name(names, r.consequent),
                    r.count, r.support, r.confidence, r.lift, r.leverage,
                    isinf(r.conviction) ? "Inf" : @sprintf("%.4f", r.conviction))
        end
    end
end

function main(args)
    which = isempty(args) ? "retail" : args[1]
    db, names, ms_def, mc_def = load_dataset(which)
    minsup = length(args) >= 2 ? parse(Float64, args[2]) : ms_def
    minconf = length(args) >= 3 ? parse(Float64, args[3]) : mc_def
    mkpath(OUT)
    n = length(db)
    st = database_stats(db)
    println("== Ứng dụng 1: giỏ hàng trên ", which, " ==")
    println("Giao dịch: ", n, "   số mặt hàng: ", st.nitems, "   độ dài TB: ", round(st.avglen; digits = 2))

    ms = minsup_count(n, minsup)
    fpgrowth(db[1:min(n, 200)], 20)                      # khởi động JIT
    t_mine = @elapsed res = fpgrowth(db, ms)
    t_rules = @elapsed rules = association_rules(res, n; minconf = minconf, minlift = 0.0)
    @printf("minsup = %.4f (%d giao dịch), minconf = %.2f\n", minsup, ms, minconf)
    @printf("Frequent itemset: %d (%.3f s)   Luật: %d (%.3f s)\n",
            length(res), t_mine, length(rules), t_rules)

    pos = filter(r -> r.lift > 1.0, rules)
    println("Luật có lift > 1: ", length(pos))
    write_rules(joinpath(OUT, "app1_$(which)_rules.csv"), pos, names)

    # Top-10 theo lift. Lift rất cao thường đến từ mặt hàng hiếm, nên báo cáo thêm
    # bản có support tối thiểu (>= 2 * ngưỡng) để loại luật dựa trên rất ít giao dịch.
    top = top_distinct(pos, 10)
    top_robust = top_distinct(pos, 10; min_count = 2 * ms)
    write_rules(joinpath(OUT, "app1_$(which)_top10.csv"), top, names)
    write_rules(joinpath(OUT, "app1_$(which)_top10_robust.csv"), top_robust, names)

    # Luật "mua A thì gợi ý mua b": vế phải một mặt hàng, vế trái <= 2 mặt hàng (dễ áp dụng)
    single = filter(r -> length(r.consequent) == 1 && length(r.antecedent) <= 2, pos)
    top_single = top_distinct(single, 10; min_count = 2 * ms)
    write_rules(joinpath(OUT, "app1_$(which)_top10_single.csv"), top_single, names)

    println("\nTop-10 luật theo lift:")
    for (i, r) in enumerate(top)
        @printf("%2d. %s => %s  sup=%.4f conf=%.3f lift=%.2f\n", i,
                set_name(names, r.antecedent), set_name(names, r.consequent),
                r.support, r.confidence, r.lift)
    end
    println("\nTop-10 luật theo lift (count >= ", 2 * ms, "):")
    for (i, r) in enumerate(top_robust)
        @printf("%2d. %s => %s  sup=%.4f conf=%.3f lift=%.2f\n", i,
                set_name(names, r.antecedent), set_name(names, r.consequent),
                r.support, r.confidence, r.lift)
    end

    # Độ nhạy theo (minsup, minconf): số itemset và số luật
    open(joinpath(OUT, "app1_$(which)_sweep.csv"), "w") do io
        println(io, "minsup,minconf,n_itemsets,n_rules,n_rules_lift_gt1,t_mine_s,t_rules_s")
        for s in (minsup * 4, minsup * 2, minsup, minsup / 2), c in (0.2, 0.4, 0.6, 0.8)
            m = minsup_count(n, s)
            tm = @elapsed r1 = fpgrowth(db, m)
            tr = @elapsed rr = association_rules(r1, n; minconf = c)
            @printf(io, "%.5f,%.2f,%d,%d,%d,%.4f,%.4f\n", s, c, length(r1), length(rr),
                    count(r -> r.lift > 1.0, rr), tm, tr)
        end
    end
    println("\nTop-10 luật gợi ý (vế phải một mặt hàng, count >= ", 2 * ms, "):")
    for (i, r) in enumerate(top_single)
        @printf("%2d. %s => %s  sup=%.4f conf=%.3f lift=%.2f\n", i,
                set_name(names, r.antecedent), set_name(names, r.consequent),
                r.support, r.confidence, r.lift)
    end
    println("\nĐã ghi kết quả vào ", OUT)
end

main(ARGS)
