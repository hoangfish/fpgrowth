############################################################
# Cấu trúc dữ liệu dùng chung: kết quả khai thác dạng phẳng
############################################################

"""
    FIResult

Tập kết quả frequent itemset lưu dạng phẳng để tiết kiệm bộ nhớ khi số lượng
itemset lên tới hàng triệu:

* `items`    : nối tất cả itemset (id item gốc).
* `offsets`  : `offsets[k]` là vị trí bắt đầu của itemset thứ `k` trong `items`;
  phần tử cuối là `length(items)+1` (sentinel) nên `length(offsets) == n+1`.
* `supports` : support tuyệt đối của từng itemset.
"""
mutable struct FIResult
    items::Vector{Int32}
    offsets::Vector{Int}
    supports::Vector{Int32}
end

FIResult() = FIResult(Int32[], Int[1], Int32[])

Base.length(r::FIResult) = length(r.supports)

"""
    to_dict(res) -> Dict{Vector{Int},Int}

Chuyển kết quả (của bản cơ bản hoặc bản tối ưu) thành từ điển
`itemset (đã sắp xếp) => support` để so sánh không phụ thuộc thứ tự.
"""
function to_dict(r::FIResult)
    d = Dict{Vector{Int},Int}()
    sizehint!(d, length(r))
    for k in 1:length(r)
        its = Int[r.items[j] for j in r.offsets[k]:(r.offsets[k+1]-1)]
        sort!(its)
        d[its] = r.supports[k]
    end
    return d
end

function to_dict(r::Vector{Tuple{Vector{Int},Int}})
    d = Dict{Vector{Int},Int}()
    sizehint!(d, length(r))
    for (its, s) in r
        d[sort(its)] = s
    end
    return d
end
