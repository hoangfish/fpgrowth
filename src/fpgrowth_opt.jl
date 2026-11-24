############################################################
# FP-Growth bản tối ưu
#
# Các kỹ thuật tối ưu so với bản cơ bản:
#  1. FP-tree lưu dạng struct-of-arrays (Vector{Int32}); node là chỉ số nguyên,
#     không có object/Dict -> ít cấp phát, cache tốt, GC nhẹ.
#  2. Con của node lưu bằng danh sách first-child/next-sibling, node-link bằng
#     mảng `link` -> không cần Dict.
#  3. Item được đánh lại nhãn thành rank tần suất (1 = phổ biến nhất).
#     Mỗi conditional tree lại đánh nhãn cục bộ 1..k nên kích thước mọi mảng
#     chỉ tỉ lệ với cây, không phụ thuộc số item toàn cục.
#  4. Buffer làm việc (`Workspace`) được dùng lại giữa các lần đệ quy.
#  5. Trường hợp cây một nhánh được sinh tổ hợp trực tiếp (không đệ quy).
#  6. Kết quả ghi thẳng vào bộ đệm phẳng `FIResult`.
############################################################

"""
    FPTree

FP-tree dạng mảng. Node 1 là root. Với node `n`:
`item[n]` nhãn cục bộ, `count[n]` số đếm, `parent[n]` cha, `child[n]` con đầu,
`sibling[n]` anh em kế, `link[n]` node kế tiếp cùng item (node-link).
`head[i]` là node đầu của item cục bộ `i`, `total[i]` là tổng count của `i`,
`orig[i]` là rank toàn cục tương ứng với nhãn cục bộ `i`.
"""
mutable struct FPTree
    item::Vector{Int32}
    count::Vector{Int32}
    parent::Vector{Int32}
    child::Vector{Int32}
    sibling::Vector{Int32}
    link::Vector{Int32}
    head::Vector{Int32}
    total::Vector{Int}
    orig::Vector{Int32}
end

"""
    new_tree(orig; sizehint=0) -> FPTree

Tạo cây rỗng (chỉ có root) cho các item có rank toàn cục `orig` (đã tăng dần).
"""
function new_tree(orig::Vector{Int32}; sizehint::Int = 0)
    k = length(orig)
    t = FPTree(Int32[0], Int32[0], Int32[0], Int32[0], Int32[0], Int32[0],
               zeros(Int32, k), zeros(Int, k), orig)
    if sizehint > 0
        for v in (t.item, t.count, t.parent, t.child, t.sibling, t.link)
            sizehint!(v, sizehint + 1)
        end
    end
    return t
end

"""
    Workspace

Bộ đệm làm việc dùng chung cho toàn bộ quá trình đệ quy: `cnt` (đếm item cục
bộ), `map` (nhãn cục bộ cũ -> mới), `touched` (item có cnt khác 0), `buf`
(đường đi tạm), `suffix` (hậu tố hiện tại, rank toàn cục), `chosen`
(tổ hợp đang chọn trên đường đơn), `rank2item` (rank -> id item gốc).
"""
struct Workspace
    cnt::Vector{Int}
    map::Vector{Int32}
    touched::Vector{Int32}
    buf::Vector{Int32}
    suffix::Vector{Int32}
    chosen::Vector{Int32}
    rank2item::Vector{Int}
    # Bảng băm (địa chỉ mở, dò tuyến tính) tra "con của node với nhãn it" trong O(1),
    # dùng chung cho mọi lần dựng cây (mỗi lúc chỉ dựng một cây, dựng xong thì xoá).
    # Khoá = (node << 32) | item, 0 = ô trống. `used` ghi các ô đã dùng để xoá nhanh.
    hkeys::Vector{UInt64}
    hvals::Vector{Int32}
    hshift::Int
    hmask::Int
    used::Vector{Int32}
end

"""
    make_workspace(m, rank2item, max_nodes) -> Workspace

`max_nodes` là cận trên số node của mọi cây sẽ dựng (= số lần xuất hiện item
phổ biến trong CSDL); bảng băm có kích thước lũy thừa 2 ≥ 2*max_nodes.
"""
function make_workspace(m::Int, rank2item::Vector{Int}, max_nodes::Int)
    bits = 6
    while (1 << bits) < 2 * (max_nodes + 16)
        bits += 1
    end
    sz = 1 << bits
    ws = Workspace(zeros(Int, m), zeros(Int32, m), Int32[], Vector{Int32}(undef, m),
                   Int32[], Int32[], rank2item,
                   zeros(UInt64, sz), zeros(Int32, sz), 64 - bits, sz - 1, Int32[])
    sizehint!(ws.touched, m)
    return ws
end

# Xoá các ô bảng băm đã dùng sau khi dựng xong một cây.
function clear_hash!(ws::Workspace)
    keys = ws.hkeys
    @inbounds for h in ws.used
        keys[h] = 0
    end
    empty!(ws.used)
    return nothing
end

"""
    insert_rev!(tree, ws, buf, k, w)

Chèn đường đi gồm `k` item đã lưu trong `buf[1:k]` theo thứ tự GIẢM dần của
nhãn (tức đi từ lá lên gốc) với trọng số `w`. Chèn từ `buf[k]` về `buf[1]` để
đi từ gốc xuống lá.
"""
function insert_rev!(t::FPTree, ws::Workspace, buf::Vector{Int32}, k::Int, w::Int32)
    keys = ws.hkeys
    vals = ws.hvals
    shift = ws.hshift
    mask = ws.hmask
    node = Int32(1)
    @inbounds for idx in k:-1:1
        it = buf[idx]
        key = (UInt64(node) << 32) | UInt64(it)
        h = Int((key * 0x9e3779b97f4a7c15) >> shift) + 1
        c = Int32(0)
        while true
            kk = keys[h]
            if kk == key
                c = vals[h]
                break
            elseif kk == 0
                break
            end
            h = (h & mask) + 1
        end
        if c == 0
            push!(t.item, it)
            push!(t.count, Int32(0))
            push!(t.parent, node)
            push!(t.child, Int32(0))
            push!(t.sibling, t.child[node])
            push!(t.link, t.head[it])
            c = Int32(length(t.item))
            t.child[node] = c
            t.head[it] = c
            keys[h] = key
            vals[h] = c
            push!(ws.used, Int32(h))
        end
        t.count[c] += w
        t.total[it] += w
        node = c
    end
    return nothing
end


"""
    emit!(res, ws, support)

Ghi itemset hiện tại (`ws.suffix` ∪ `ws.chosen`, đổi sang id gốc) vào `res`.
"""
function emit!(res::FIResult, ws::Workspace, support::Integer)
    @inbounds begin
        for x in ws.suffix
            push!(res.items, ws.rank2item[x])
        end
        for x in ws.chosen
            push!(res.items, ws.rank2item[x])
        end
    end
    push!(res.offsets, length(res.items) + 1)
    push!(res.supports, support)
    return nothing
end

"""
    single_path_nodes(t) -> Bool

Cây có đúng một nhánh (mỗi node có tối đa một con) hay không.
"""
function is_single_path(t::FPTree)
    node = t.child[1]
    @inbounds while node != 0
        t.sibling[node] != 0 && return false
        node = t.child[node]
    end
    return true
end

# Sinh mọi tổ hợp không rỗng của đường đơn (các node n = child chain)
function emit_single_path!(res::FIResult, ws::Workspace, t::FPTree,
                           pitems::Vector{Int32}, pcounts::Vector{Int32},
                           start::Int)
    @inbounds for j in start:length(pitems)
        push!(ws.chosen, pitems[j])
        emit!(res, ws, pcounts[j])
        emit_single_path!(res, ws, t, pitems, pcounts, j + 1)
        pop!(ws.chosen)
    end
    return nothing
end

"""
    build_conditional(t, r, minsup, ws) -> Union{FPTree,Nothing}

Dựng conditional FP-tree của item cục bộ `r` trong cây `t`.
Lượt 1 duyệt node-link của `r`, đi ngược lên gốc để đếm support của các item
trong conditional pattern base. Lượt 2 chèn các đường đi đã lọc (chỉ giữ item
còn phổ biến), nhãn được đánh lại cục bộ 1..k. Trả về `nothing` nếu cây rỗng.
"""
function build_conditional(t::FPTree, r::Int, minsup::Int, ws::Workspace)
    cnt = ws.cnt
    touched = ws.touched
    empty!(touched)
    # ---- lượt 1: đếm
    n = t.head[r]
    plen = 0                      # tổng độ dài các đường đi (cận trên số node cần thêm)
    @inbounds while n != 0
        w = Int(t.count[n])
        p = t.parent[n]
        while p != 1
            plen += 1
            it = t.item[p]
            if cnt[it] == 0
                push!(touched, it)
            end
            cnt[it] += w
            p = t.parent[p]
        end
        n = t.link[n]
    end
    # ---- chọn item phổ biến và đánh nhãn cục bộ (giữ thứ tự tăng dần)
    freq = Int32[]
    @inbounds for it in touched
        cnt[it] >= minsup && push!(freq, it)
    end
    if isempty(freq)
        @inbounds for it in touched
            cnt[it] = 0
        end
        return nothing
    end
    sort!(freq)
    k = length(freq)
    orig = Vector{Int32}(undef, k)
    @inbounds for j in 1:k
        it = freq[j]
        orig[j] = t.orig[it]
        ws.map[it] = Int32(j)
    end
    # Lưu ý: KHÔNG dùng t.total[r] (là tổng support, có thể hàng nghìn) làm sizehint:
    # nó làm mỗi conditional tree cấp phát dư rất nhiều bộ nhớ trên dữ liệu dày.
    ct = new_tree(orig; sizehint = min(max(plen, 16), 128))
    # ---- lượt 2: chèn các đường đi đã lọc
    buf = ws.buf
    n = t.head[r]
    @inbounds while n != 0
        w = t.count[n]
        p = t.parent[n]
        m = 0
        while p != 1
            it = t.item[p]
            if cnt[it] >= minsup
                m += 1
                buf[m] = ws.map[it]
            end
            p = t.parent[p]
        end
        m > 0 && insert_rev!(ct, ws, buf, m, w)
        n = t.link[n]
    end
    @inbounds for it in touched
        cnt[it] = 0
    end
    clear_hash!(ws)
    return ct
end

"""
    mine!(res, t, minsup, ws)

Đệ quy FP-growth trên cây `t` với hậu tố là `ws.suffix`.
"""
function mine!(res::FIResult, t::FPTree, minsup::Int, ws::Workspace)
    if is_single_path(t)
        # thu thập node trên đường đơn rồi sinh tổ hợp
        pitems = Int32[]
        pcounts = Int32[]
        node = t.child[1]
        @inbounds while node != 0
            push!(pitems, t.orig[t.item[node]])
            push!(pcounts, t.count[node])
            node = t.child[node]
        end
        emit_single_path!(res, ws, t, pitems, pcounts, 1)
        return nothing
    end
    # duyệt item từ ít phổ biến nhất (nhãn lớn nhất) đến phổ biến nhất
    @inbounds for r in length(t.head):-1:1
        t.head[r] == 0 && continue
        cnt = t.total[r]
        cnt < minsup && continue
        push!(ws.suffix, t.orig[r])
        emit!(res, ws, cnt)
        ct = build_conditional(t, r, minsup, ws)
        ct === nothing || mine!(res, ct, minsup, ws)
        pop!(ws.suffix)
    end
    return nothing
end

"""
    fpgrowth(db, minsup) -> FIResult

FP-Growth bản tối ưu. `db` là CSDL giao dịch (mỗi giao dịch là `Vector{Int}`),
`minsup` là ngưỡng support tuyệt đối (số giao dịch). Trả về `FIResult` chứa
mọi frequent itemset cùng support.
"""
function fpgrowth(db::Vector{Vector{Int}}, minsup::Int)
    res = FIResult()
    # Lần quét 1: đếm item. Dùng Dict một lần (chi phí nhỏ) rồi chuyển sang mảng.
    freq = Dict{Int,Int}()
    for t in db, it in t
        freq[it] = get(freq, it, 0) + 1
    end
    filter!(p -> p.second >= minsup, freq)
    isempty(freq) && return res
    order = sort!(collect(keys(freq)); by = it -> (-freq[it], it))
    m = length(order)
    rank = Dict{Int,Int32}(it => Int32(r) for (r, it) in enumerate(order))

    # Lần quét 2: dựng FP-tree gốc (nhãn cục bộ = rank toàn cục)
    total_items = 0
    for t in db, it in t
        haskey(rank, it) && (total_items += 1)
    end
    ws = make_workspace(m, order, total_items)
    tree = new_tree(collect(Int32, 1:m); sizehint = total_items)
    buf = ws.buf
    tmp = Vector{Int32}()
    for t in db
        empty!(tmp)
        for it in t
            r = get(rank, it, Int32(0))
            r != 0 && push!(tmp, r)
        end
        isempty(tmp) && continue
        sort!(tmp; rev = true)               # giảm dần để insert_rev! đi từ gốc xuống
        copyto!(buf, 1, tmp, 1, length(tmp))
        insert_rev!(tree, ws, buf, length(tmp), Int32(1))
    end
    clear_hash!(ws)

    mine!(res, tree, minsup, ws)
    return res
end

"""
    mine_file(path; minsup, algo=:opt) -> (result, ntrans, minsup_abs)

Đọc file SPMF `path` và khai thác frequent itemset với ngưỡng tương đối
`minsup` (0 < minsup <= 1). `algo` là `:opt` hoặc `:basic`.
"""
function mine_file(path::AbstractString; minsup::Real, algo::Symbol = :opt)
    db = read_transactions(path)
    ms = minsup_count(length(db), minsup)
    res = algo === :basic ? fpgrowth_basic(db, ms) : fpgrowth(db, ms)
    return res, length(db), ms
end
