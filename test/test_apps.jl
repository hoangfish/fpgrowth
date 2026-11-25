# Kiểm thử phần hậu xử lý và chuyển đổi dữ liệu của hai ứng dụng.
# (được include từ runtests.jl; dùng lại random_db định nghĩa ở đó)

"Luật kết hợp theo định nghĩa: duyệt mọi itemset và mọi cách tách, đếm support bằng quét CSDL."
function brute_rules(db, ms, minconf)
    items = sort(unique(reduce(vcat, db)))
    n = length(db)
    k = length(items)
    out = Dict{Tuple{Vector{Int},Vector{Int}},Tuple{Int,Float64,Float64}}()
    for mask in 1:((1 << k) - 1)
        I = Int[items[j] for j in 1:k if ((mask >> (j - 1)) & 1) == 1]
        length(I) < 2 && continue
        sI = support_count(db, I)
        sI < ms && continue
        m = length(I)
        for sm in 1:((1 << m) - 2)
            A = Int[I[j] for j in 1:m if ((sm >> (j - 1)) & 1) == 1]
            C = Int[I[j] for j in 1:m if ((sm >> (j - 1)) & 1) == 0]
            conf = sI / support_count(db, A)
            conf < minconf && continue
            out[(A, C)] = (sI, conf, conf * n / support_count(db, C))
        end
    end
    return out
end

@testset "Ứng dụng: hậu xử lý và chuyển đổi dữ liệu" begin

    @testset "association_rules khớp định nghĩa (brute force)" begin
        for seed in 1:3
            db = random_db(100, 8, 4; seed = seed)
            ms = 12
            res = fpgrowth(db, ms)
            got = association_rules(res, length(db); minconf = 0.4)
            ref = brute_rules(db, ms, 0.4)
            @test length(got) == length(ref)
            ok = true
            for r in got
                v = get(ref, (r.antecedent, r.consequent), nothing)
                if v === nothing || v[1] != r.count || !isapprox(v[2], r.confidence) ||
                   !isapprox(v[3], r.lift)
                    ok = false
                end
            end
            @test ok
            @test issorted(got; by = r -> -r.lift)
        end
    end

    @testset "luật trên ví dụ nhỏ tính tay" begin
        # 4 giao dịch: {1,2},{1,2},{1,3},{2}; supp{1}=3, supp{2}=3, supp{1,2}=2
        db = [[1, 2], [1, 2], [1, 3], [2]]
        res = fpgrowth(db, 2)
        rules = association_rules(res, 4; minconf = 0.0)
        r = first(filter(x -> x.antecedent == [1] && x.consequent == [2], rules))
        @test r.count == 2
        @test r.support ≈ 0.5
        @test r.confidence ≈ 2 / 3
        @test r.lift ≈ (2 / 3) / (3 / 4)
        @test r.leverage ≈ 0.5 - (3 / 4) * (3 / 4)
        @test r.conviction ≈ (1 - 3 / 4) / (1 - 2 / 3)
    end

    @testset "tập đóng và tập tối đại khớp định nghĩa" begin
        for seed in 1:3
            db = random_db(80, 8, 4; seed = 10 + seed)
            ms = 8
            res = fpgrowth(db, ms)
            d = to_dict(res)
            isclosed(x, s) = !any(y -> length(y) > length(x) && issubset(x, y) && d[y] == s, keys(d))
            ismax(x) = !any(y -> length(y) > length(x) && issubset(x, y), keys(d))
            ref_closed = Set(x for (x, s) in d if isclosed(x, s))
            ref_max = Set(x for x in keys(d) if ismax(x))
            @test Set(first.(closed_itemsets(res))) == ref_closed
            @test Set(first.(maximal_itemsets(res))) == ref_max
            @test all(d[x] == s for (x, s) in closed_itemsets(res))
        end
    end

    @testset "contains_sorted / support_count" begin
        @test contains_sorted([1, 3, 5, 9], [3, 9])
        @test contains_sorted([1, 3, 5, 9], Int[])
        @test !contains_sorted([1, 3, 5, 9], [3, 4])
        @test !contains_sorted([1, 3], [3, 5])
        @test support_count([[1, 2], [1, 3], [2, 3]], [1]) == 2
    end

    @testset "mẫu nổi bật" begin
        db_in = [[1, 2], [1, 2, 3], [1, 2]]
        db_out = [[1], [3], [1, 3]]
        eps = emerging_patterns(db_in, db_out, fpgrowth(db_in, 2); min_growth = 2.0)
        @test length(eps) == 1
        @test eps[1].items == [1, 2]
        @test eps[1].support_in ≈ 1.0
        @test eps[1].support_out == 0.0
        @test isinf(eps[1].growth)
    end

    @testset "mã hoá chuỗi DNA" begin
        @test encode_sequence("ACGT") == [1, 6, 11, 16]
        @test encode_sequence("acgt") == [1, 6, 11, 16]
        @test encode_sequence("ANGT") == [1, 11, 16]            # N (mơ hồ) bị bỏ qua
        @test issorted(encode_sequence("GATTACAGATTACA"))
        @test item_position(1) == 1 && item_base(1) == 'A'
        @test item_position(240) == 60 && item_base(240) == 'T'
        @test relative_position(1) == -30
        @test relative_position(30) == -1
        @test relative_position(31) == 1
        @test relative_position(60) == 30
        @test item_label((31 - 1) * 4 + 3) == "+1:G"
        @test item_label((30 - 1) * 4 + 1) == "-1:A"
        @test pattern_label([(31 - 1) * 4 + 3, (32 - 1) * 4 + 4]) == "+1:G +2:T"
    end

    @testset "đọc splice.data và CSV giỏ hàng" begin
        mktempdir() do dir
            sp = joinpath(dir, "splice.data")
            seq = repeat("ACGT", 15)                           # 60 nucleotide
            open(sp, "w") do io
                println(io, "EI,ATRINS-DONOR-1,  ", seq)
                println(io, "N,NAME-2,  ", seq[1:59] * "N")
                println(io)
            end
            db, labels = load_splice(sp)
            @test labels == ["EI", "N"]
            @test length(db[1]) == 60
            @test length(db[2]) == 59
            by = split_by_class(db, labels)
            @test length(by["EI"]) == 1 && length(by["N"]) == 1

            cs = joinpath(dir, "g.csv")
            write(cs, "milk,bread\n\"bread, butter\"\nmilk,bread,milk\n")
            db2, names = load_basket_csv(cs)
            @test names == ["milk", "bread", "butter"]
            @test db2 == [[1, 2], [2, 3], [1, 2]]
        end
    end

    @testset "end-to-end: luật 'mẫu => lớp' trên dữ liệu DNA tổng hợp có cài sẵn mẫu" begin
        rng = MersenneTwister(2024)
        seqs = String[]
        labs = String[]
        for i in 1:400
            s = Char[rand(rng, collect("ACGT")) for _ in 1:60]
            if i <= 200                                        # lớp EI: GT tại +1,+2
                s[31] = 'G'; s[32] = 'T'
                push!(labs, "EI")
            else
                push!(labs, "N")
            end
            push!(seqs, String(s))
        end
        db = [encode_sequence(s) for s in seqs]
        cdb = [vcat(t, l == "EI" ? 1001 : 1003) for (t, l) in zip(db, labs)]
        res = fpgrowth(cdb, 100)
        rules = association_rules(res, length(cdb); minconf = 0.8, max_len = 4)
        gt = sort([(31 - 1) * 4 + 3, (32 - 1) * 4 + 4])
        hit = filter(r -> r.consequent == [1001] && r.antecedent == gt, rules)
        @test length(hit) == 1
        @test hit[1].count == 200
        @test hit[1].confidence > 0.85
    end
end
