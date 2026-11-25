# Sinh dữ liệu giao dịch tổng hợp (seed cố định) dùng khi chưa có dữ liệu FIMI thật.
#
#   julia --project scripts/gen_data.jl            # sinh các bộ "*_like" vào data/benchmark
#   julia --project scripts/gen_data.jl avglen     # sinh các bộ độ dài giao dịch tăng dần
#
# Các file sinh ra có đuôi `_like` để KHÔNG nhầm với dữ liệu benchmark thật. Khi có
# chess.txt, mushroom.txt, retail.txt, T10I4D100K.txt thật (từ FIMI/SPMF), đặt chúng
# vào data/benchmark/ và scripts/run_experiments.py sẽ ưu tiên dùng bản thật.

using Random

const OUT = joinpath(@__DIR__, "..", "data", "benchmark")
mkpath(OUT)

function write_db(path, db)
    open(path, "w") do io
        for t in db
            println(io, join(sort(t), ' '))
        end
    end
    println("wrote $path  ($(length(db)) giao dịch)")
end

"""
    quest_like(ntrans, nitems, avg_t, avg_i, npats; seed) -> db

Bộ sinh kiểu IBM Quest rút gọn (T{avg_t}I{avg_i}): tạo `npats` mẫu tiềm năng
(độ dài ~ Poisson(avg_i)), mỗi giao dịch (độ dài ~ Poisson(avg_t)) được ghép từ
các mẫu chọn theo trọng số mũ, mỗi item của mẫu bị bỏ với xác suất nhỏ.
"""
function quest_like(ntrans, nitems, avg_t, avg_i, npats; seed)
    rng = MersenneTwister(seed)
    poisson(λ) = begin
        L = exp(-λ); k = 0; p = 1.0
        while true
            k += 1; p *= rand(rng)
            p <= L && return k - 1
        end
    end
    pats = Vector{Vector{Int}}()
    w = Float64[]
    prev = Int[]
    for _ in 1:npats
        len = max(1, poisson(avg_i))
        s = Set{Int}()
        # một phần item lấy từ mẫu trước để tạo tương quan giữa các mẫu
        if !isempty(prev)
            for it in prev
                length(s) < len * 0.5 && rand(rng) < 0.5 && push!(s, it)
            end
        end
        while length(s) < len
            push!(s, rand(rng, 1:nitems))
        end
        p = collect(s)
        push!(pats, p); prev = p
        push!(w, -log(rand(rng)))
    end
    cw = cumsum(w ./ sum(w))
    pick() = pats[min(searchsortedfirst(cw, rand(rng)), npats)]
    db = Vector{Vector{Int}}()
    for _ in 1:ntrans
        len = max(1, poisson(avg_t))
        s = Set{Int}()
        guard = 0
        while length(s) < len && guard < 50
            guard += 1
            for it in pick()
                rand(rng) < 0.9 && push!(s, it)   # corruption nhẹ
                length(s) >= len && break
            end
        end
        isempty(s) && push!(s, rand(rng, 1:nitems))
        push!(db, collect(s))
    end
    return db
end

"""
    dense_like(ntrans, domains; seed, nclusters) -> db

CSDL dạng "bảng thuộc tính - giá trị" (như chess, mushroom): mỗi giao dịch có
đúng một giá trị cho mỗi thuộc tính. Giá trị phụ thuộc một cụm ẩn nên các
thuộc tính tương quan mạnh -> tạo nhiều itemset dài như dữ liệu dày thật.
`domains[j]` là số giá trị của thuộc tính j.
"""
function dense_like(ntrans, domains; seed, nclusters = 6, skew = 0.75)
    rng = MersenneTwister(seed)
    offs = cumsum([0; domains[1:end-1]])
    # mỗi cụm ưu tiên một giá trị cho từng thuộc tính
    fav = [[rand(rng, 1:d) for d in domains] for _ in 1:nclusters]
    cw = cumsum(fill(1 / nclusters, nclusters))
    db = Vector{Vector{Int}}()
    for _ in 1:ntrans
        c = min(searchsortedfirst(cw, rand(rng)), nclusters)
        t = Int[]
        for (j, d) in enumerate(domains)
            v = rand(rng) < skew ? fav[c][j] : rand(rng, 1:d)
            push!(t, offs[j] + v)
        end
        push!(db, t)
    end
    return db
end

"""
    retail_like(ntrans, nitems; seed) -> db

Giỏ hàng thưa: độ phổ biến item theo phân phối Zipf, độ dài giỏ ~ hình học
(trung bình ~10), kèm vài "combo" mua cùng nhau để có luật kết hợp thật.
"""
function retail_like(ntrans, nitems; seed)
    rng = MersenneTwister(seed)
    z = 1 ./ (1:nitems) .^ 0.9
    cz = cumsum(z ./ sum(z))
    zipf() = min(searchsortedfirst(cz, rand(rng)), nitems)
    combos = [unique([zipf() for _ in 1:rand(rng, 2:4)]) for _ in 1:40]
    db = Vector{Vector{Int}}()
    for _ in 1:ntrans
        len = 1 + floor(Int, -log(rand(rng)) * 9.3)
        s = Set{Int}()
        rand(rng) < 0.35 && union!(s, rand(rng, combos))
        while length(s) < len
            push!(s, zipf())
        end
        push!(db, collect(s))
    end
    return db
end

function main(args)
    if !isempty(args) && args[1] == "avglen"
        # Thực nghiệm độ dài giao dịch trung bình: N, số item cố định, T tăng dần
        for T in (5, 10, 15, 20, 25, 30)
            db = quest_like(20_000, 1000, T, 4, 500; seed = 100 + T)
            write_db(joinpath(OUT, "avglen_T$(T).txt"), db)
        end
        return
    end
    # ~ T10I4D100K
    write_db(joinpath(OUT, "T10I4D100K_like.txt"), quest_like(100_000, 870, 10, 4, 1000; seed = 1))
    # ~ chess: 3196 giao dịch, 75 item, độ dài 37 (36 thuộc tính nhị phân + 1 thuộc tính 3 giá trị)
    write_db(joinpath(OUT, "chess_like.txt"),
             dense_like(3196, vcat(fill(2, 36), 3); seed = 2, nclusters = 5, skew = 0.8))
    # ~ mushroom: 8124 giao dịch, 119 item, độ dài 23
    dom = [2, 6, 4, 10, 2, 9, 4, 3, 2, 12, 2, 5, 4, 4, 9, 9, 1, 4, 3, 8, 9, 6, 7][1:23]
    write_db(joinpath(OUT, "mushroom_like.txt"),
             dense_like(8124, dom; seed = 3, nclusters = 8, skew = 0.7))
    # ~ retail: 88162 giao dịch, ~16470 item, độ dài TB ~10
    write_db(joinpath(OUT, "retail_like.txt"), retail_like(88_162, 16_470; seed = 4))
end

main(ARGS)
