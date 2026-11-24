############################################################
# FP-Growth bản cơ bản (bám sát bài báo Han, Pei, Yin - SIGMOD 2000)
#
# Mục đích: làm mốc (baseline) để đo mức cải thiện của bản tối ưu.
# Node là object, con của node lưu trong Dict, header table là Dict
# item => danh sách node, kết quả là Vector các cặp (itemset, support).
############################################################

"""
    BNode

Node của FP-tree bản cơ bản. `children` ánh xạ item -> node con; `parent` là
node cha (`nothing` với root).
"""
mutable struct BNode
    item::Int
    count::Int
    parent::Union{BNode,Nothing}
    children::Dict{Int,BNode}
end

BNode(item::Int, parent::Union{BNode,Nothing}) = BNode(item, 0, parent, Dict{Int,BNode}())

"""
    BTree

FP-tree bản cơ bản: `root`, header table `header` (item -> các node mang item
đó, tức "node-link"), và `itemcount` (item -> tổng count trong cây).
"""
mutable struct BTree
    root::BNode
    header::Dict{Int,Vector{BNode}}
    itemcount::Dict{Int,Int}
end

BTree() = BTree(BNode(0, nothing), Dict{Int,Vector{BNode}}(), Dict{Int,Int}())

"""
    insert_path!(tree, items, count)

Chèn một đường đi `items` (đã sắp theo thứ tự toàn cục) với trọng số `count`
vào cây: dùng lại tiền tố chung, tăng count; tạo node mới khi cần và nối node
mới vào header table.
"""
function insert_path!(tree::BTree, items::Vector{Int}, count::Int)
    node = tree.root
    for it in items
        child = get(node.children, it, nothing)
        if child === nothing
            child = BNode(it, node)
            node.children[it] = child
            push!(get!(tree.header, it, BNode[]), child)
        end
        child.count += count
        tree.itemcount[it] = get(tree.itemcount, it, 0) + count
        node = child
    end
    return nothing
end

"""
    single_path(tree) -> Union{Vector{BNode},Nothing}

Nếu cây chỉ có một nhánh duy nhất, trả về các node theo thứ tự từ trên xuống,
ngược lại trả về `nothing`.
"""
function single_path(tree::BTree)
    path = BNode[]
    node = tree.root
    while !isempty(node.children)
        length(node.children) > 1 && return nothing
        node = first(values(node.children))
        push!(path, node)
    end
    return path
end

"""
    emit_single_path!(out, path, suffix, start, chosen, minsup)

Sinh mọi tổ hợp không rỗng các node trên đường đơn `path` kết hợp với `suffix`.
Support của tổ hợp là count của node sâu nhất được chọn (count không tăng
khi đi xuống).
"""
function emit_single_path!(out, path::Vector{BNode}, suffix::Vector{Int},
                           start::Int, chosen::Vector{Int}, minsup::Int)
    for j in start:length(path)
        path[j].count < minsup && continue
        push!(chosen, path[j].item)
        push!(out, (vcat(chosen, suffix), path[j].count))
        emit_single_path!(out, path, suffix, j + 1, chosen, minsup)
        pop!(chosen)
    end
    return nothing
end

"""
    mine_basic!(out, tree, suffix, minsup, rank)

Đệ quy FP-growth trên `tree` với hậu tố `suffix`. Với mỗi item (từ ít phổ biến
đến phổ biến nhất) trong header table: phát sinh itemset `{item} ∪ suffix`,
dựng conditional pattern base, dựng conditional FP-tree rồi đệ quy.
`rank` cho thứ tự toàn cục của item (rank nhỏ = tần suất cao).
"""
function mine_basic!(out, tree::BTree, suffix::Vector{Int}, minsup::Int,
                     rank::Dict{Int,Int})
    sp = single_path(tree)
    if sp !== nothing
        emit_single_path!(out, sp, suffix, 1, Int[], minsup)
        return nothing
    end
    items = sort!(collect(keys(tree.header)); by = it -> rank[it], rev = true)
    for it in items
        cnt = tree.itemcount[it]
        cnt < minsup && continue
        newsuffix = vcat(it, suffix)
        push!(out, (newsuffix, cnt))

        # conditional pattern base của `it`
        base = Tuple{Vector{Int},Int}[]
        counts = Dict{Int,Int}()
        for node in tree.header[it]
            path = Int[]
            p = node.parent
            while p !== nothing && p.parent !== nothing
                push!(path, p.item)
                p = p.parent
            end
            isempty(path) && continue
            reverse!(path)
            push!(base, (path, node.count))
            for x in path
                counts[x] = get(counts, x, 0) + node.count
            end
        end

        # conditional FP-tree: chỉ giữ item còn phổ biến
        ctree = BTree()
        for (path, c) in base
            filtered = [x for x in path if counts[x] >= minsup]
            isempty(filtered) || insert_path!(ctree, filtered, c)
        end
        isempty(ctree.root.children) || mine_basic!(out, ctree, newsuffix, minsup, rank)
    end
    return nothing
end

"""
    fpgrowth_basic(db, minsup) -> Vector{Tuple{Vector{Int},Int}}

FP-Growth bản cơ bản. `db` là CSDL giao dịch, `minsup` là ngưỡng support
tuyệt đối (số giao dịch). Trả về mọi frequent itemset cùng support.
"""
function fpgrowth_basic(db::Vector{Vector{Int}}, minsup::Int)
    out = Tuple{Vector{Int},Int}[]
    # Lần quét 1: đếm support của từng item
    freq = Dict{Int,Int}()
    for t in db, it in t
        freq[it] = get(freq, it, 0) + 1
    end
    filter!(p -> p.second >= minsup, freq)
    isempty(freq) && return out
    order = sort!(collect(keys(freq)); by = it -> (-freq[it], it))
    rank = Dict{Int,Int}(it => r for (r, it) in enumerate(order))

    # Lần quét 2: dựng FP-tree
    tree = BTree()
    for t in db
        f = [it for it in t if haskey(rank, it)]
        isempty(f) && continue
        sort!(f; by = it -> rank[it])
        insert_path!(tree, f, 1)
    end
    mine_basic!(out, tree, Int[], minsup, rank)
    return out
end
