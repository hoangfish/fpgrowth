using Test
using Random
using FPGrowthFIM

include("reference.jl")

const DATA = joinpath(@__DIR__, "..", "data", "toy")

"Sinh CSDL ngẫu nhiên có cấu trúc (một vài 'mẫu thói quen' + nhiễu), có seed."
function random_db(ntrans, nitems, avglen; seed, dense = false)
    rng = MersenneTwister(seed)
    pats = [sort!(randperm(rng, nitems)[1:rand(rng, 2:max(2, min(6, nitems)))]) for _ in 1:6]
    db = Vector{Vector{Int}}()
    for _ in 1:ntrans
        s = Set{Int}()
        rand(rng) < (dense ? 0.8 : 0.4) && union!(s, rand(rng, pats))
        while length(s) < avglen
            push!(s, rand(rng, 1:nitems))
        end
        push!(db, sort!(collect(s)))
    end
    return db
end

check_all(db, ms) = begin
    ref = length(unique!(sort(reduce(vcat, db; init = Int[])))) <= 16 ?
          brute_force(db, ms) : apriori_ref(db, ms)
    b = to_dict(fpgrowth_basic(db, ms))
    o = to_dict(fpgrowth(db, ms))
    (b == ref) && (o == ref)
end

@testset "FPGrowthFIM" begin

    @testset "Ví dụ SPMF contextPasquier99 (minsup 40%)" begin
        db = read_transactions(joinpath(DATA, "contextPasquier99.txt"))
        @test length(db) == 5
        ms = minsup_count(5, 0.4)
        @test ms == 2
        o = to_dict(fpgrowth(db, ms))
        @test length(o) == 15
        @test o[[1]] == 3 && o[[2]] == 4 && o[[3]] == 4 && o[[5]] == 4
        @test o[[1, 2]] == 2 && o[[1, 3]] == 3
        @test o[[1, 2, 3, 5]] == 2
        @test o == to_dict(fpgrowth_basic(db, ms))
        @test o == brute_force(db, ms)
    end

    @testset "Ví dụ trong bài báo Han et al. (minsup=3)" begin
        # f a c d g i m p / a b c f l m o / b f h j o / b c k s p / a f c e l p m n
        L = Dict(c => i for (i, c) in enumerate("abcdefghijklmnopqrs"))
        raw = ["facdgimp", "abcflmo", "bfhjo", "bcksp", "afcelpmn"]
        db = [sort!(unique([L[c] for c in s])) for s in raw]
        ms = 3
        o = to_dict(fpgrowth(db, ms))
        # item phổ biến theo bài báo: f:4 c:4 a:3 b:3 m:3 p:3
        for (c, s) in ("f" => 4, "c" => 4, "a" => 3, "b" => 3, "m" => 3, "p" => 3)
            @test o[[L[only(c)]]] == s
        end
        @test o[sort([L['f'], L['c'], L['a'], L['m']])] == 3   # {f,c,a,m}:3
        @test o == brute_force(db, ms)
        @test o == to_dict(fpgrowth_basic(db, ms))
    end

    @testset "5 CSDL: FP-Growth cơ bản và tối ưu == tham chiếu độc lập" begin
        dbs = [
            ("thưa 200x14",      random_db(200, 14, 4;  seed = 1), 6),
            ("dày 120x13",       random_db(120, 13, 8;  seed = 2, dense = true), 40),
            ("trung bình 300x40", random_db(300, 40, 6;  seed = 3), 12),
            ("dày 150x30",       random_db(150, 30, 10; seed = 4, dense = true), 60),
            ("thưa 500x60",      random_db(500, 60, 5;  seed = 5), 15),
        ]
        for (name, db, ms) in dbs
            @testset "$name (minsup=$ms)" begin
                ref = length(unique!(sort(reduce(vcat, db)))) <= 16 ?
                      brute_force(db, ms) : apriori_ref(db, ms)
                @test !isempty(ref)
                b = to_dict(fpgrowth_basic(db, ms))
                o = to_dict(fpgrowth(db, ms))
                @test b == ref
                @test o == ref
            end
        end
    end

    @testset "Nhiều ngưỡng minsup trên cùng CSDL" begin
        db = random_db(250, 16, 6; seed = 11, dense = true)
        for ms in (5, 20, 50, 100, 200)
            @test check_all(db, ms)
        end
    end

    @testset "Trường hợp biên" begin
        @test length(fpgrowth(Vector{Vector{Int}}(), 1)) == 0
        @test isempty(fpgrowth_basic(Vector{Vector{Int}}(), 1))
        @test length(fpgrowth([[1, 2, 3]], 2)) == 0                 # minsup > N
        o = to_dict(fpgrowth([[1, 2, 3]], 1))                        # một giao dịch
        @test length(o) == 7 && all(==(1), values(o))
        @test to_dict(fpgrowth([[5], [5], [5]], 3)) == Dict([5] => 3)
        @test check_all([[1, 2], [1, 2], [1, 2], [1, 2]], 2)         # cây một nhánh
        @test check_all([[1], [2], [3]], 1)                          # không item chung
        # id item lớn và không liên tục
        db = [[1000, 5, 99999], [1000, 5], [5, 99999], [1000, 99999, 5]]
        @test to_dict(fpgrowth(db, 2)) == to_dict(fpgrowth_basic(db, 2))
        @test to_dict(fpgrowth(db, 2))[[5, 1000, 99999]] == 2
    end

    @testset "Quy đổi minsup (quy ước SPMF: ceil)" begin
        @test minsup_count(5, 0.4) == 2
        @test minsup_count(5, 0.41) == 3
        @test minsup_count(100, 0.01) == 1
        @test minsup_count(10, 1.0) == 10
        @test parse_minsup("40%") == 0.4
        @test parse_minsup("0.25") == 0.25
        @test_throws ArgumentError parse_minsup("0")
    end

    @testset "I/O định dạng SPMF" begin
        mktempdir() do dir
            inp = joinpath(dir, "in.txt")
            write(inp, "# comment\n@CONVERTED\n3 1 2\n\n2 3 3\n1 2\n")
            db = read_transactions(inp)
            @test db == [[1, 2, 3], [2, 3], [1, 2]]           # sắp xếp, bỏ trùng, bỏ comment
            res = fpgrowth(db, 2)
            out = joinpath(dir, "out.txt")
            write_spmf(out, res)
            @test FPGrowthFIM.read_spmf_output(out) == to_dict(res)
            @test all(l -> occursin(" #SUP: ", l), eachline(out))
            out2 = joinpath(dir, "out2.txt")
            write_spmf(out2, fpgrowth_basic(db, 2))
            @test FPGrowthFIM.read_spmf_output(out2) == to_dict(res)
            r2, n, ms = mine_file(inp; minsup = 0.67)
            @test n == 3 && ms == 3 && to_dict(r2) == to_dict(fpgrowth(db, 3))
        end
    end

    @testset "CLI demo.jl" begin
        mktempdir() do dir
            out = joinpath(dir, "o.txt")
            demo = joinpath(@__DIR__, "..", "demo.jl")
            proj = joinpath(@__DIR__, "..")
            run(pipeline(`$(Base.julia_cmd()) --project=$proj $demo --minsup 40% --output $out $(joinpath(DATA, "contextPasquier99.txt"))`;
                         stdout = devnull))
            @test length(FPGrowthFIM.read_spmf_output(out)) == 15
        end
    end

    # Nếu người dùng đặt kết quả SPMF vào data/spmf_expected/<tên>_<minsup>.txt
    # (xem scripts/run_spmf.py) thì so khớp luôn với SPMF.
    @testset "So khớp với kết quả SPMF (nếu có)" begin
        exp_dir = joinpath(@__DIR__, "..", "data", "spmf_expected")
        files = isdir(exp_dir) ? filter(f -> endswith(f, ".txt"), readdir(exp_dir)) : String[]
        if isempty(files)
            @info "Chưa có data/spmf_expected/ -> bỏ qua so khớp trực tiếp với SPMF (chạy scripts/run_spmf.py)."
            @test true
        end
        for f in files
            # tên file: <dataset>__<minsup>.txt  ví dụ chess__0.8.txt
            m = match(r"^(.+)__([0-9.]+)\.txt$", f)
            m === nothing && continue
            ds = m.captures[1]
            ms_rel = parse(Float64, m.captures[2])
            inp = joinpath(@__DIR__, "..", "data", "benchmark", ds * ".txt")
            isfile(inp) || continue
            res, _, _ = mine_file(inp; minsup = ms_rel)
            spmf = FPGrowthFIM.read_spmf_output(joinpath(exp_dir, f))
            @test to_dict(res) == spmf
        end
    end
end

include("test_apps.jl")
