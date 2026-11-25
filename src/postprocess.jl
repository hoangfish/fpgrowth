############################################################
# Hậu xử lý kết quả khai thác: luật kết hợp, tập đóng, tập tối đại
# (tất cả dựa trên kết quả của FP-Growth do nhóm cài đặt)
############################################################

"""
    Rule

Luật kết hợp `antecedent => consequent` (hai tập item rời nhau, đã sắp xếp).

* `count`      : số giao dịch chứa cả hai vế, supp(A ∪ C) tuyệt đối
* `support`    : supp(A ∪ C) / N
* `confidence` : supp(A ∪ C) / supp(A)
* `lift`       : confidence / (supp(C) / N)
* `leverage`   : P(A ∪ C) - P(A) P(C)
* `conviction` : (1 - P(C)) / (1 - confidence)  (Inf nếu confidence = 1)
"""
struct Rule
    antecedent::Vector{Int}
    consequent::Vector{Int}
    count::Int
    support::Float64
    confidence::Float64
    lift::Float64
    leverage::Float64
    conviction::Float64
end

"""
    association_rules(res, ntrans; minconf=0.5, minlift=0.0, max_len=12) -> Vector{Rule}

Sinh mọi luật kết hợp từ tập frequent itemset `res` (kết quả của `fpgrowth`) trên
CSDL có `ntrans` giao dịch. Do tính chất Apriori mọi tập con của một frequent
itemset cũng nằm trong `res`, nên supp(A) và supp(C) được tra từ chính `res`
(không quét lại CSDL). Chỉ xét itemset có độ dài 2..`max_len`. Kết quả sắp xếp
giảm dần theo lift, rồi confidence, rồi support (có thứ tự xác định).
"""
function association_rules(res::FIResult, ntrans::Integer; minconf::Real = 0.5,
                           minlift::Real = 0.0, max_len::Int = 12)
    sup = to_dict(res)
    rules = Rule[]
    A = Int[]
    C = Int[]
    n = float(ntrans)
    for (items, s) in sup
        k = length(items)
        (k < 2 || k > max_len) && continue
        for mask in 1:((1 << k) - 2)
            empty!(A)
            empty!(C)
            for j in 1:k
                if ((mask >> (j - 1)) & 1) == 1
                    push!(A, items[j])
                else
                    push!(C, items[j])
                end
            end
            sa = sup[A]
            conf = s / sa
            conf < minconf && continue
            sc = sup[C]
            lift = conf * n / sc
            lift < minlift && continue
            leverage = s / n - (sa / n) * (sc / n)
            conviction = conf >= 1 ? Inf : (1 - sc / n) / (1 - conf)
            push!(rules, Rule(copy(A), copy(C), s, s / n, conf, lift, leverage, conviction))
        end
    end
    sort!(rules; by = r -> (-r.lift, -r.confidence, -r.count, r.antecedent, r.consequent))
    return rules
end

"""
    closed_itemsets(res) -> Vector{Tuple{Vector{Int},Int}}

Các frequent itemset *đóng*: không có tập cha thật sự nào cùng support.
X không đóng khi và chỉ khi tồn tại frequent itemset X ∪ {y} có cùng support, nên
chỉ cần xét các tập cha hơn đúng một phần tử. Sắp xếp giảm dần theo support, độ dài.
"""
function closed_itemsets(res::FIResult)
    d = to_dict(res)
    nonclosed = Set{Vector{Int}}()
    for (items, s) in d
        k = length(items)
        k < 2 && continue
        for j in 1:k
            sub = Int[items[i] for i in 1:k if i != j]
            d[sub] == s && push!(nonclosed, sub)
        end
    end
    out = Tuple{Vector{Int},Int}[(its, s) for (its, s) in d if !(its in nonclosed)]
    sort!(out; by = p -> (-p[2], -length(p[1]), p[1]))
    return out
end

"""
    maximal_itemsets(res) -> Vector{Tuple{Vector{Int},Int}}

Các frequent itemset *tối đại*: không có tập cha thật sự nào cũng phổ biến.
X không tối đại khi và chỉ khi có frequent itemset hơn đúng một phần tử chứa X.
"""
function maximal_itemsets(res::FIResult)
    d = to_dict(res)
    nonmax = Set{Vector{Int}}()
    for items in keys(d)
        k = length(items)
        k < 2 && continue
        for j in 1:k
            push!(nonmax, Int[items[i] for i in 1:k if i != j])
        end
    end
    out = Tuple{Vector{Int},Int}[(its, s) for (its, s) in d if !(its in nonmax)]
    sort!(out; by = p -> (-p[2], -length(p[1]), p[1]))
    return out
end

"""
    contains_sorted(t, x) -> Bool

`x` có là tập con của `t` hay không (cả hai đã sắp xếp tăng, không trùng).
"""
function contains_sorted(t::Vector{Int}, x::Vector{Int})
    i = 1
    nt = length(t)
    @inbounds for v in x
        while i <= nt && t[i] < v
            i += 1
        end
        (i > nt || t[i] != v) && return false
        i += 1
    end
    return true
end

"""
    support_count(db, itemset) -> Int

Số giao dịch của `db` chứa `itemset` (quét trực tiếp; dùng để kiểm tra và để
tính support trong một CSDL khác).
"""
function support_count(db::Vector{Vector{Int}}, itemset::Vector{Int})
    c = 0
    for t in db
        contains_sorted(t, itemset) && (c += 1)
    end
    return c
end

"""
    EmergingPattern

Mẫu nổi bật của một lớp: support trong lớp (`support_in`) và ngoài lớp
(`support_out`), `growth` = support_in / support_out (Inf nếu support_out = 0).
"""
struct EmergingPattern
    items::Vector{Int}
    count_in::Int
    support_in::Float64
    support_out::Float64
    growth::Float64
end

"""
    emerging_patterns(db_in, db_out, res_in; min_growth=2.0, max_candidates=5000)

Xếp hạng các tập đóng của lớp (`res_in` = kết quả khai thác trên `db_in`) theo
growth rate so với `db_out`. Chỉ xét tối đa `max_candidates` tập đóng có support
cao nhất. Trả về các mẫu có growth ≥ `min_growth`, giảm dần theo growth rồi support.
"""
function emerging_patterns(db_in::Vector{Vector{Int}}, db_out::Vector{Vector{Int}},
                           res_in::FIResult; min_growth::Real = 2.0,
                           max_candidates::Int = 5000)
    cand = closed_itemsets(res_in)
    length(cand) > max_candidates && (cand = cand[1:max_candidates])
    nin = length(db_in)
    nout = length(db_out)
    out = EmergingPattern[]
    for (items, cin) in cand
        cout = support_count(db_out, items)
        sin = cin / nin
        sout = nout == 0 ? 0.0 : cout / nout
        g = sout == 0 ? Inf : sin / sout
        g >= min_growth && push!(out, EmergingPattern(items, cin, sin, sout, g))
    end
    sort!(out; by = e -> (-e.growth, -e.support_in, e.items))
    return out
end
