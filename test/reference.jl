# Cài đặt tham chiếu độc lập (CHỈ dùng trong test) để đối chiếu kết quả:
#  * brute_force : liệt kê mọi tập con (chỉ cho số item nhỏ)
#  * apriori_ref : Apriori đơn giản (cho CSDL cỡ vừa)
# Hai hàm này không dùng cấu trúc cây nào của FP-Growth nên là kiểm chứng độc lập.

"""
    brute_force(db, minsup) -> Dict{Vector{Int},Int}

Đếm support của mọi tập con không rỗng của tập item (≤ ~18 item).
"""
function brute_force(db::Vector{Vector{Int}}, minsup::Int)
    items = sort!(unique!(reduce(vcat, db; init = Int[])))
    n = length(items)
    n > 20 && error("brute_force chỉ dùng cho ≤ 20 item")
    idx = Dict(it => i for (i, it) in enumerate(items))
    masks = UInt32[]
    for t in db
        m = UInt32(0)
        for it in t
            m |= UInt32(1) << (idx[it] - 1)
        end
        push!(masks, m)
    end
    out = Dict{Vector{Int},Int}()
    for s in UInt32(1):UInt32((1 << n) - 1)
        c = 0
        for m in masks
            (m & s) == s && (c += 1)
        end
        if c >= minsup
            out[[items[i] for i in 1:n if (s >> (i - 1)) & 1 == 1]] = c
        end
    end
    return out
end

"""
    apriori_ref(db, minsup) -> Dict{Vector{Int},Int}

Apriori chuẩn (sinh ứng viên bằng join + tỉa, đếm bằng quét CSDL).
"""
function apriori_ref(db::Vector{Vector{Int}}, minsup::Int)
    out = Dict{Vector{Int},Int}()
    sets = [Set(t) for t in db]
    c1 = Dict{Int,Int}()
    for t in db, it in t
        c1[it] = get(c1, it, 0) + 1
    end
    level = sort!([[it] for (it, c) in c1 if c >= minsup])
    for l in level
        out[l] = c1[l[1]]
    end
    while !isempty(level)
        prev = Set(level)
        cand = Vector{Vector{Int}}()
        for i in 1:length(level), j in (i+1):length(level)
            a, b = level[i], level[j]
            if a[1:end-1] == b[1:end-1]
                c = vcat(a, b[end])
                # tỉa: mọi tập con kích thước k-1 phải phổ biến
                ok = true
                for d in 1:length(c)-2
                    sub = [c[x] for x in 1:length(c) if x != d]
                    sub in prev || (ok = false; break)
                end
                ok && push!(cand, c)
            end
        end
        counts = zeros(Int, length(cand))
        for (ci, c) in enumerate(cand), s in sets
            all(x -> x in s, c) && (counts[ci] += 1)
        end
        level = Vector{Vector{Int}}()
        for (ci, c) in enumerate(cand)
            if counts[ci] >= minsup
                out[c] = counts[ci]
                push!(level, c)
            end
        end
        sort!(level)
    end
    return out
end
