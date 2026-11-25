# Ứng dụng 2: khai thác mẫu trong dữ liệu sinh học (splice-junction gene sequences, UCI).
#
#   julia --project scripts/app2_splice.jl [đường_dẫn/splice.data]
#
# Mỗi chuỗi DNA 60 nucleotide (vị trí -30..-1, +1..+30 quanh ranh giới) -> một giao dịch gồm
# 60 item "vị trí:nucleotide" (240 item). Lớp: EI (donor: exon -> intron), IE (acceptor:
# intron -> exon), N (không phải ranh giới). Dùng fpgrowth của nhóm để:
#   1. đếm tần suất (vị trí, nucleotide) theo lớp (ma trận tần suất),
#   2. khai thác frequent / closed / maximal itemset trong từng lớp theo nhiều minsup,
#   3. tìm mẫu nổi bật (emerging patterns) của từng lớp so với phần còn lại,
#   4. sinh luật kết hợp "mẫu => lớp" (class association rules) và so với kiến thức sinh học,
#   5. kiểm chứng: học luật trên 70% chuỗi, dự đoán lớp của 30% còn lại (seed cố định).
using FPGrowthFIM
using Printf
using Random

const ROOT = normpath(joinpath(@__DIR__, ".."))
const OUT = joinpath(ROOT, "results", "apps")
const CLASSES = ["EI", "IE", "N"]
const CLASS_ITEM = Dict("EI" => 1001, "IE" => 1002, "N" => 1003)   # id item đại diện cho lớp
const ITEM_CLASS = Dict(v => k for (k, v) in CLASS_ITEM)

fmt_float(x::Float64) = isinf(x) ? "Inf" : @sprintf("%.4f", x)

function position_frequency(dbc::Vector{Vector{Int}})
    cnt = zeros(Int, SPLICE_LEN * 4)
    for t in dbc, it in t
        cnt[it] += 1
    end
    return cnt
end

"""
Học luật "mẫu => lớp" trên tập huấn luyện (70%, seed cố định) rồi dự đoán lớp của tập kiểm tra:
mỗi chuỗi cộng điểm (confidence) cho lớp của các luật mà nó thoả; lớp điểm cao nhất thắng,
không luật nào khớp thì gán N. Ghi ma trận nhầm lẫn và precision/recall theo lớp.
"""
function evaluate_split(db::Vector{Vector{Int}}, labels::Vector{String}; seed::Int = 42,
                        train_frac::Float64 = 0.7)
    n = length(db)
    rng = MersenneTwister(seed)
    perm = randperm(rng, n)
    ntr = round(Int, train_frac * n)
    train = Vector{Vector{Int}}()
    for i in perm[1:ntr]
        haskey(CLASS_ITEM, labels[i]) && push!(train, vcat(db[i], CLASS_ITEM[labels[i]]))
    end
    res = fpgrowth(train, minsup_count(length(train), 0.05))
    rules = association_rules(res, length(train); minconf = 0.9, max_len = 8)
    chosen = Dict(c => Rule[] for c in CLASSES)
    for r in rules
        (length(r.consequent) == 1 && haskey(ITEM_CLASS, r.consequent[1])) || continue
        r.count >= 30 || continue
        push!(chosen[ITEM_CLASS[r.consequent[1]]], r)
    end
    for c in CLASSES
        sort!(chosen[c]; by = r -> (-r.confidence, -r.count, r.antecedent))
        length(chosen[c]) > 40 && resize!(chosen[c], 40)
    end
    conf = Dict((a, p) => 0 for a in CLASSES, p in CLASSES)
    for i in perm[(ntr + 1):end]
        t = db[i]
        score = Dict(c => 0.0 for c in CLASSES)
        for c in CLASSES, r in chosen[c]
            contains_sorted(t, r.antecedent) && (score[c] += r.confidence)
        end
        best = "N"
        bs = 0.0
        for c in CLASSES
            if score[c] > bs
                bs = score[c]
                best = c
            end
        end
        conf[(labels[i], best)] += 1
    end
    ntest = n - ntr
    correct = sum(conf[(c, c)] for c in CLASSES)
    open(joinpath(OUT, "app2_eval.csv"), "w") do io
        println(io, "class,precision,recall,f1,test_size,n_rules_used")
        println("\nĐánh giá luật trên tập kiểm tra (", ntest, " chuỗi, train ", length(train), "):")
        for c in CLASSES
            tp = conf[(c, c)]
            fp = sum(conf[(a, c)] for a in CLASSES if a != c)
            fn = sum(conf[(c, p)] for p in CLASSES if p != c)
            prec = tp + fp == 0 ? 0.0 : tp / (tp + fp)
            rec = tp + fn == 0 ? 0.0 : tp / (tp + fn)
            f1 = prec + rec == 0 ? 0.0 : 2 * prec * rec / (prec + rec)
            @printf(io, "%s,%.4f,%.4f,%.4f,%d,%d\n", c, prec, rec, f1, tp + fn, length(chosen[c]))
            @printf("   %-2s precision=%.3f recall=%.3f f1=%.3f (n=%d, %d luật)\n", c, prec, rec, f1,
                    tp + fn, length(chosen[c]))
        end
        @printf(io, "accuracy,%.4f,,,%d,\n", correct / ntest, ntest)
        @printf("   accuracy = %.4f\n", correct / ntest)
    end
    open(joinpath(OUT, "app2_eval_confusion.csv"), "w") do io
        println(io, "true_class," * join(CLASSES, ","))
        for a in CLASSES
            println(io, a, ",", join((conf[(a, p)] for p in CLASSES), ","))
        end
    end
    open(joinpath(OUT, "app2_eval_rules.csv"), "w") do io
        println(io, "class,antecedent,count,confidence,lift")
        for c in CLASSES, r in chosen[c]
            @printf(io, "%s,%s,%d,%.4f,%.3f\n", c, pattern_label(r.antecedent), r.count,
                    r.confidence, r.lift)
        end
    end
    return nothing
end

function main(args)
    path = isempty(args) ? joinpath(ROOT, "data", "apps", "splice.data") : args[1]
    isfile(path) || error("Không thấy $path (chạy: python scripts/download_app_data.py)")
    mkpath(OUT)
    db, labels = load_splice(path)
    byclass = split_by_class(db, labels)
    println("== Ứng dụng 2: splice-junction ==")
    println("Chuỗi: ", length(db), "   lớp: ",
            join(("$c=$(length(get(byclass, c, Vector{Vector{Int}}())))" for c in CLASSES), "  "))
    for c in CLASSES
        haskey(byclass, c) || error("Thiếu lớp $c trong dữ liệu")
    end
    fpgrowth(byclass["EI"][1:50], 30)                       # khởi động JIT

    # 1. Ma trận tần suất vị trí x nucleotide theo lớp
    open(joinpath(OUT, "app2_position_freq.csv"), "w") do io
        println(io, "class,rel_pos,base,count,freq")
        for c in CLASSES
            dbc = byclass[c]
            cnt = position_frequency(dbc)
            for it in 1:(SPLICE_LEN * 4)
                @printf(io, "%s,%d,%s,%d,%.4f\n", c, relative_position(item_position(it)),
                        item_base(it), cnt[it], cnt[it] / length(dbc))
            end
        end
    end

    # 2. Quét minsup trong từng lớp: số frequent / closed / maximal itemset
    open(joinpath(OUT, "app2_minsup_sweep.csv"), "w") do io
        println(io, "class,minsup,n_itemsets,n_closed,n_maximal,max_len,t_mine_s")
        for c in CLASSES, ms in (0.5, 0.4, 0.3, 0.2, 0.1)
            dbc = byclass[c]
            t = @elapsed res = fpgrowth(dbc, minsup_count(length(dbc), ms))
            nclosed = length(closed_itemsets(res))
            nmax = length(maximal_itemsets(res))
            maxlen = length(res) == 0 ? 0 : maximum(res.offsets[k+1] - res.offsets[k] for k in 1:length(res))
            @printf(io, "%s,%.2f,%d,%d,%d,%d,%.4f\n", c, ms, length(res), nclosed, nmax, maxlen, t)
            @printf("  %-2s minsup=%.2f  itemsets=%d  closed=%d  maximal=%d  maxlen=%d  (%.3f s)\n",
                    c, ms, length(res), nclosed, nmax, maxlen, t)
        end
    end

    # 3. Mẫu đóng phổ biến nhất và mẫu nổi bật của từng lớp
    pat_ms = 0.3
    ep_ms = 0.2
    open(joinpath(OUT, "app2_patterns.csv"), "w") do iop
        println(iop, "class,kind,support,count,length,pattern")
        open(joinpath(OUT, "app2_emerging.csv"), "w") do ioe
            println(ioe, "class,support_in,support_out,growth,length,pattern")
            for c in CLASSES
                dbc = byclass[c]
                dbo = Vector{Vector{Int}}()
                for o in CLASSES
                    o == c || append!(dbo, byclass[o])
                end
                res = fpgrowth(dbc, minsup_count(length(dbc), pat_ms))
                closed = filter(p -> length(p[1]) >= 2, closed_itemsets(res))
                for (its, s) in first(closed, 30)
                    @printf(iop, "%s,closed,%.4f,%d,%d,%s\n", c, s / length(dbc), s, length(its), pattern_label(its))
                end
                for (its, s) in first(maximal_itemsets(res), 30)
                    @printf(iop, "%s,maximal,%.4f,%d,%d,%s\n", c, s / length(dbc), s, length(its), pattern_label(its))
                end
                res2 = fpgrowth(dbc, minsup_count(length(dbc), ep_ms))
                eps = emerging_patterns(dbc, dbo, res2; min_growth = 2.0)
                println("\n[", c, "] mẫu nổi bật (support trong lớp >= ", ep_ms, "), top 8:")
                for e in first(eps, 200)
                    @printf(ioe, "%s,%.4f,%.4f,%s,%d,%s\n", c, e.support_in, e.support_out,
                            fmt_float(e.growth), length(e.items), pattern_label(e.items))
                end
                for e in first(eps, 8)
                    @printf("   %-34s in=%.2f out=%.3f growth=%s\n", pattern_label(e.items),
                            e.support_in, e.support_out, fmt_float(e.growth))
                end
            end
        end
    end

    # 4. Luật kết hợp theo lớp: mẫu => lớp
    cdb = Vector{Vector{Int}}()
    for (t, l) in zip(db, labels)
        haskey(CLASS_ITEM, l) || continue
        push!(cdb, vcat(t, CLASS_ITEM[l]))                 # id lớp > 240 nên vẫn tăng dần
    end
    n = length(cdb)
    cr_ms = 0.05
    t_mine = @elapsed res = fpgrowth(cdb, minsup_count(n, cr_ms))
    t_rules = @elapsed rules = association_rules(res, n; minconf = 0.6, max_len = 8)
    crules = filter(r -> length(r.consequent) == 1 && haskey(ITEM_CLASS, r.consequent[1]), rules)
    @printf("\nLuật kết hợp: %d itemset (minsup=%.2f, %.3f s), %d luật (%.3f s), %d luật có vế phải là lớp\n",
            length(res), cr_ms, t_mine, length(rules), t_rules, length(crules))
    open(joinpath(OUT, "app2_class_rules.csv"), "w") do io
        println(io, "class,antecedent,count,support,confidence,lift")
        for c in CLASSES
            sel = filter(r -> ITEM_CLASS[r.consequent[1]] == c && r.count >= 50, crules)
            sort!(sel; by = r -> (-r.lift, -r.confidence, -r.count, r.antecedent))
            println("\n[", c, "] luật 'mẫu => ", c, "' có lift cao nhất (count >= 50):")
            for (i, r) in enumerate(first(sel, 40))
                @printf(io, "%s,%s,%d,%.4f,%.4f,%.3f\n", c, pattern_label(r.antecedent), r.count,
                        r.support, r.confidence, r.lift)
                i <= 8 && @printf("   %-34s => %s  count=%d conf=%.3f lift=%.2f\n",
                                  pattern_label(r.antecedent), c, r.count, r.confidence, r.lift)
            end
        end
    end
    evaluate_split(db, labels)
    println("\nĐã ghi kết quả vào ", OUT)
end

main(ARGS)
