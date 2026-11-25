# Đo một cấu hình (thuật toán, dataset, minsup) trong một tiến trình Julia mới để
# đo được RSS đỉnh chính xác. In ra đúng một dòng CSV.
#
#   julia --project scripts/bench_one.jl <opt|basic> <file> <minsup> [frac]
#
# Cột: algo,dataset,frac,minsup,minsup_abs,ntrans,n_itemsets,time_s,time_e2e_s,alloc_mb,rss_load_mb,peak_rss_mb
#  * time_s     : thời gian KHAI THÁC (không gồm đọc file, không gồm ghi file), lấy min của
#                 tối đa 3 lần chạy (sau 1 lần chạy khởi động để loại bỏ biên dịch JIT).
#  * time_e2e_s : đọc file + khai thác + ghi kết quả (một lần, đã khởi động JIT).
#  * alloc_mb   : tổng bộ nhớ cấp phát trong một lần khai thác.
#  * rss_load_mb: RSS ngay sau khi đọc CSDL (chi phí nền của dữ liệu).
#  * peak_rss_mb: RSS đỉnh của tiến trình.

using FPGrowthFIM
using Random

function main(args)
    length(args) >= 3 || error("cách dùng: bench_one.jl <opt|basic> <file> <minsup> [frac]")
    algo = Symbol(args[1])
    file = args[2]
    minsup = parse(Float64, args[3])
    frac = length(args) >= 4 ? parse(Float64, args[4]) : 1.0

    db = read_transactions(file)
    idx = Int[]
    if frac < 1.0
        rng = MersenneTwister(42)
        n = round(Int, frac * length(db))
        idx = sort!(randperm(rng, length(db))[1:n])
        db = db[idx]
    end
    ms = minsup_count(length(db), minsup)
    f = algo === :basic ? fpgrowth_basic : fpgrowth

    GC.gc()
    rss_load = current_rss_mb()

    # khởi động (biên dịch JIT) trên một CSDL nhỏ cố định, độc lập với dữ liệu thật
    # (không dùng một phần của dữ liệu thật vì minsup tuyệt đối nhỏ có thể gây bùng nổ tổ hợp)
    wr = MersenneTwister(7)
    warm = [sort!(unique!(rand(wr, 1:30, 6))) for _ in 1:200]
    f(warm, 20)

    GC.gc()
    st = @timed f(db, ms)
    nres = length(st.value)
    tmin = st.time
    alloc = st.bytes / 2^20
    st = nothing
    reps = 1
    while reps < 3 && tmin < 6.0
        GC.gc()
        s2 = @timed f(db, ms)
        tmin = min(tmin, s2.time)
        reps += 1
    end
    # thời gian end-to-end: đọc file + khai thác + ghi file kết quả (so sánh được với SPMF,
    # vốn tính cả đọc/ghi). Dùng toàn bộ CSDL gốc (không lấy mẫu) khi frac == 1.
    tmp = tempname()
    GC.gc()
    t_e2e = @elapsed begin
        db2 = read_transactions(file)
        if frac < 1.0
            db2 = db2[idx]
        end
        r2 = f(db2, minsup_count(length(db2), minsup))
        write_spmf(tmp, r2)
    end
    rm(tmp; force = true)
    peak = peak_rss_mb()
    name = splitext(basename(file))[1]
    println(join((algo, name, frac, minsup, ms, length(db), nres,
                  round(tmin; digits = 4), round(t_e2e; digits = 4), round(alloc; digits = 1),
                  round(rss_load; digits = 1), round(peak; digits = 1)), ','))
end

main(ARGS)
