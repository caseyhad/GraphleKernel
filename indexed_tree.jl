### A Pluto.jl notebook ###
# v0.19.20

using Markdown
using InteractiveUtils

# ╔═╡ 663d2953-6de3-435b-9924-c757b0dcd43c
begin
	mutable struct Node
		node::Int
		vertex::Int
		new::Bool
		children::Vector{Node}
	
		Node(vertex::Int, node::Int) = new(node, vertex, true, Node[])
	end
	
	struct Tree
		root::Int
		nodes::Dict{Int, Node}
	
		Tree(root::Int, vertex::Int) = new(root, Dict(root => Node(1, vertex)))
	end
end

# ╔═╡ eb87bad1-8d2f-4f18-a334-447b51d59404
begin
	import Base.getindex
	Base.getindex(tree::Tree, idx::Int) = tree.nodes[idx]
end

# ╔═╡ b01a0fc0-1b2f-48e1-a86b-2643be6e9624
# add a child of tree[node] corresponding to vertex
function add_node!(tree::Tree, node::Int, vertex::Int)
	# create node
	new_node = Node(length(tree.nodes) + 1, vertex)
	# link to parent
	tree[node].children = vcat(tree[node].children, [Node(vertex, node)])
	# update dictionary
	tree.nodes[new_node.node] = new_node
end;

# ╔═╡ 5d9b383c-091c-4a73-ba34-bd2d18eb231e
begin
	tree = Tree(1, 1)
	add_node!(tree, 1, 2)
	tree
end

# ╔═╡ 5b634680-b48b-4f68-b537-956f5aea34f6
tree[1]

# ╔═╡ e8c3738a-3306-4d11-af82-19ac86718b77
tree[2]

# ╔═╡ Cell order:
# ╠═663d2953-6de3-435b-9924-c757b0dcd43c
# ╠═eb87bad1-8d2f-4f18-a334-447b51d59404
# ╠═b01a0fc0-1b2f-48e1-a86b-2643be6e9624
# ╠═5d9b383c-091c-4a73-ba34-bd2d18eb231e
# ╠═5b634680-b48b-4f68-b537-956f5aea34f6
# ╠═e8c3738a-3306-4d11-af82-19ac86718b77
