abstract type Node end

mutable struct NodeSymbol <: Node
    symbol::String
end

mutable struct NodeConcat <: Node
    left::Node
    right::Node
end

mutable struct NodeOR <: Node
    left::Node
    right::Node
end

mutable struct NodeKleeneStar <: Node
    val::Node
end

mutable struct NodeCatchGroup <: Node
    group_num::Int
    val::Node
end

mutable struct NodeNonCatchGroup <: Node
    val::Node
end

mutable struct NodeLinkString <: Node
    group_num::Int
end

mutable struct NodeLinkExpression <: Node
    group_num::Int
end