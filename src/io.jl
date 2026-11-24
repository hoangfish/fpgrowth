"""
    read_transactions(path) -> Vector{Vector{Int}}

Đọc CSDL giao dịch định dạng SPMF `.txt`: mỗi dòng một giao dịch, các item là
số nguyên cách nhau bởi dấu cách. Bỏ qua dòng trống và dòng bắt đầu bằng `#`,
`%`, `@`. Mỗi giao dịch được sắp xếp và loại item trùng.
"""
function read_transactions(path::AbstractString)
    db = Vector{Vector{Int}}()
    open(path, "r") do io
        for line in eachline(io)
            s = strip(line)
            (isempty(s) || s[1] in ('#', '%', '@')) && continue
            t = Int[parse(Int, w) for w in split(s)]
            sort!(t)
            unique!(t)
            push!(db, t)
        end
    end
    return db
end

"""
    write_spmf(path, result)

Ghi kết quả theo định dạng đầu ra của SPMF: `item1 item2 ... #SUP: s`,
mỗi dòng một frequent itemset. `result` là `FIResult` hoặc
`Vector{Tuple{Vector{Int},Int}}` (kết quả của `fpgrowth_basic`).
"""
function write_spmf(path::AbstractString, res::FIResult)
    open(path, "w") do io
        tmp = Int32[]
        for k in 1:length(res)
            empty!(tmp)
            append!(tmp, @view res.items[res.offsets[k]:(res.offsets[k+1]-1)])
            sort!(tmp)
            for it in tmp
                print(io, it, ' ')
            end
            print(io, "#SUP: ", res.supports[k], '\n')
        end
    end
    return path
end

function write_spmf(path::AbstractString, res::Vector{Tuple{Vector{Int},Int}})
    open(path, "w") do io
        for (items, s) in res
            for it in sort(items)
                print(io, it, ' ')
            end
            print(io, "#SUP: ", s, '\n')
        end
    end
    return path
end

"""
    read_spmf_output(path) -> Dict{Vector{Int},Int}

Đọc file kết quả định dạng SPMF (`1 2 3 #SUP: 4`) thành từ điển
`itemset đã sắp xếp => support`. Dùng để đối chiếu với đầu ra của SPMF.
"""
function read_spmf_output(path::AbstractString)
    d = Dict{Vector{Int},Int}()
    for line in eachline(path)
        s = strip(line)
        (isempty(s) || s[1] in ('#', '%', '@')) && continue
        left, right = split(s, "#SUP:")
        items = sort!(Int[parse(Int, w) for w in split(left)])
        d[items] = parse(Int, strip(right))
    end
    return d
end
