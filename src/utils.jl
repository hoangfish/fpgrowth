"""
    parse_minsup(s::AbstractString) -> Float64

Chuyển chuỗi ngưỡng support thành tỉ lệ trong (0, 1]. Chấp nhận `"40%"`, `"0.4"`.
Giá trị lớn hơn 1 không có `%` bị coi là phần trăm (ví dụ `"40"` -> 0.4).
"""
function parse_minsup(s::AbstractString)
    t = strip(s)
    v = endswith(t, "%") ? parse(Float64, t[1:end-1]) / 100 : parse(Float64, t)
    v > 1 && (v /= 100)
    (0 < v <= 1) || throw(ArgumentError("minsup phải nằm trong (0, 1], nhận được $s"))
    return v
end

"""
    minsup_count(ntrans::Integer, minsup::Real) -> Int

Đổi ngưỡng tương đối thành ngưỡng tuyệt đối theo quy ước của SPMF:
`ceil(minsup * ntrans)` (luôn ít nhất 1).
"""
minsup_count(ntrans::Integer, minsup::Real) = max(1, ceil(Int, minsup * ntrans - 1e-9))

"""
    database_stats(db) -> NamedTuple

Thống kê cơ bản của CSDL giao dịch: số giao dịch, số item phân biệt,
độ dài trung bình và độ dài tối đa.
"""
function database_stats(db::Vector{Vector{Int}})
    seen = Set{Int}()
    total = 0
    maxlen = 0
    for t in db
        union!(seen, t)
        total += length(t)
        maxlen = max(maxlen, length(t))
    end
    n = length(db)
    return (ntrans = n, nitems = length(seen),
            avglen = n == 0 ? 0.0 : total / n, maxlen = maxlen)
end

"""
    current_rss_mb() -> Float64

RSS hiện tại của tiến trình (MB), đọc từ `/proc/self/status` (Linux). Trả về
Nếu không có `/proc` (Windows/macOS) thì dùng `Sys.maxrss()` (RSS đỉnh) làm xấp xỉ.
"""
current_rss_mb() = (v = _proc_status_mb("VmRSS"); isnan(v) ? Sys.maxrss() / 2^20 : v)

"""
    peak_rss_mb() -> Float64

RSS đỉnh (high-water mark) của tiến trình (MB), đọc `VmHWM`. `NaN` nếu không có.
"""
peak_rss_mb() = (v = _proc_status_mb("VmHWM"); isnan(v) ? Sys.maxrss() / 2^20 : v)

function _proc_status_mb(key::AbstractString)
    try
        for line in eachline("/proc/self/status")
            if startswith(line, key * ":")
                kb = parse(Int, split(line)[2])
                return kb / 1024
            end
        end
    catch
    end
    return NaN
end
