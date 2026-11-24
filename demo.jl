#!/usr/bin/env julia
# Giao diện dòng lệnh cho FP-Growth tự cài đặt.
#
# Cách dùng:
#   julia --project demo.jl [--minsup 0.01] [--output out.txt] [--algo opt|basic] input.txt
#
#   --minsup  ngưỡng support tương đối, ví dụ 0.4 hoặc 40%   (mặc định 0.4)
#   --output  đường dẫn file kết quả định dạng SPMF            (mặc định: không ghi)
#   --algo    opt (bản tối ưu, mặc định) hoặc basic (bản cơ bản)

using FPGrowthFIM

function usage()
    println("""
    Cách dùng: julia --project demo.jl [--minsup 0.01] [--output out.txt] [--algo opt|basic] input.txt
    """)
end

function main(args)
    minsup = 0.4
    output = nothing
    algo = :opt
    input = nothing
    i = 1
    while i <= length(args)
        a = args[i]
        if a == "--minsup"
            minsup = parse_minsup(args[i+1]); i += 2
        elseif a == "--output"
            output = args[i+1]; i += 2
        elseif a == "--algo"
            algo = Symbol(args[i+1]); i += 2
        elseif a in ("-h", "--help")
            usage(); return 0
        else
            input = a; i += 1
        end
    end
    if input === nothing
        usage(); return 1
    end
    algo in (:opt, :basic) || error("--algo phải là opt hoặc basic")

    t0 = time()
    res, n, ms = mine_file(input; minsup = minsup, algo = algo)
    dt = time() - t0
    println("Input         : $input")
    println("Transactions  : $n")
    println("minsup        : $minsup  (tuyệt đối = $ms)")
    println("Algorithm     : $algo")
    println("#Frequent sets: $(length(res))")
    println("Time (incl. I/O, incl. JIT): $(round(dt; digits = 3)) s")
    if output !== nothing
        write_spmf(output, res)
        println("Output written: $output")
    end
    return 0
end

exit(main(ARGS))
