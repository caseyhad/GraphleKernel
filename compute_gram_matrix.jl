import Pkg; Pkg.add("JLD2")
import Pkg; Pkg.add("MolecularGraph")
using JLD2, MolecularGraphKernels, MolecularGraph

@load "C:\\Users\\dcase\\GraphletKernel\\BBB_metagraphs.jld2" BBB_metagraphs

BBB_cg_4 = gram_matrix(connected_graphlet, BBB_metagraphs; n=4)

@save "C:\\Users\\dcase\\GraphletKernel\\BBB_cg_4.jld2" BBB_cg_4