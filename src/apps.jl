############################################################
# Chuyển đổi dữ liệu thành giao dịch cho hai ứng dụng
#  - Ứng dụng 1 (giỏ hàng): CSV "mỗi dòng một giỏ, mặt hàng cách nhau dấu phẩy"
#  - Ứng dụng 2 (sinh học): chuỗi DNA splice-junction -> giao dịch (vị trí, nucleotide)
############################################################

# ---------------------------------------------------------------- giỏ hàng

"""
    load_basket_csv(path; delim=',') -> (db, names)

Đọc CSV giỏ hàng: mỗi dòng là một giao dịch, các tên mặt hàng cách nhau `delim`.
Gán id nguyên 1..K theo thứ tự xuất hiện đầu tiên; `names[id]` là tên mặt hàng.
Mỗi giao dịch được sắp xếp và loại mặt hàng trùng.
"""
function load_basket_csv(path::AbstractString; delim::Char = ',')
    names = String[]
    index = Dict{String,Int}()
    db = Vector{Vector{Int}}()
    for line in eachline(path)
        s = strip(line)
        isempty(s) && continue
        t = Int[]
        for w in split(s, delim)
            item = String(strip(w, ['"', ' ', '\t', '\r']))
            isempty(item) && continue
            id = get!(index, item) do
                push!(names, item)
                length(names)
            end
            push!(t, id)
        end
        sort!(t)
        unique!(t)
        isempty(t) || push!(db, t)
    end
    return db, names
end

# ---------------------------------------------------------------- sinh học

"Thứ tự nucleotide dùng để mã hoá item."
const BASES = ('A', 'C', 'G', 'T')

"Độ dài cửa sổ trong bộ dữ liệu splice-junction (vị trí -30..-1, +1..+30)."
const SPLICE_LEN = 60

base_index(c::Char) = c == 'A' ? 1 : c == 'C' ? 2 : c == 'G' ? 3 : c == 'T' ? 4 : 0

"""
    encode_sequence(seq) -> Vector{Int}

Mã hoá chuỗi DNA thành giao dịch: nucleotide `b` (A,C,G,T = 1..4) ở vị trí `p`
(1-based) là item `(p-1)*4 + b`. Ký tự mơ hồ (N, D, S, R, ...) không tạo item.
Kết quả đã sắp xếp tăng.
"""
function encode_sequence(seq::AbstractString)
    t = Int[]
    for (p, c) in enumerate(uppercase(seq))
        b = base_index(c)
        b == 0 && continue
        push!(t, (p - 1) * 4 + b)
    end
    return t
end

item_position(id::Integer) = (Int(id) - 1) ÷ 4 + 1
item_base(id::Integer) = BASES[(Int(id) - 1) % 4 + 1]

"Vị trí tương đối so với ranh giới: p=1..30 -> -30..-1, p=31..60 -> +1..+30."
relative_position(p::Integer, len::Integer = SPLICE_LEN) =
    p <= len ÷ 2 ? Int(p) - (len ÷ 2 + 1) : Int(p) - len ÷ 2

"Nhãn dễ đọc của item, ví dụ `+1:G` hoặc `-2:A`."
function item_label(id::Integer; len::Integer = SPLICE_LEN)
    r = relative_position(item_position(id), len)
    return string(r > 0 ? "+" : "", r, ":", item_base(id))
end

"Nhãn của một itemset (sắp theo vị trí), ví dụ `-2:A -1:G +1:G +2:T`."
pattern_label(items::AbstractVector{<:Integer}; len::Integer = SPLICE_LEN) =
    join((item_label(i; len = len) for i in sort(collect(items))), " ")

"""
    load_splice(path) -> (db, labels)

Đọc `splice.data` của UCI: mỗi dòng `lớp, tên, chuỗi 60 nucleotide`; lớp là
`EI`, `IE` hoặc `N`. Trả về CSDL giao dịch (qua `encode_sequence`) và nhãn lớp.
"""
function load_splice(path::AbstractString)
    labels = String[]
    db = Vector{Vector{Int}}()
    for line in eachline(path)
        s = strip(line)
        isempty(s) && continue
        f = split(s, ',')
        length(f) < 3 && continue
        seq = strip(f[end])
        isempty(seq) && continue
        push!(labels, uppercase(String(strip(f[1]))))
        push!(db, encode_sequence(seq))
    end
    return db, labels
end

"Tách CSDL theo nhãn lớp."
function split_by_class(db::Vector{Vector{Int}}, labels::Vector{String})
    out = Dict{String,Vector{Vector{Int}}}()
    for (t, l) in zip(db, labels)
        push!(get!(out, l, Vector{Vector{Int}}()), t)
    end
    return out
end
