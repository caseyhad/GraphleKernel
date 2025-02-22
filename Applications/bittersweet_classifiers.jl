### A Pluto.jl notebook ###
# v0.19.25

using Markdown
using InteractiveUtils

# ╔═╡ 355935c0-e6c8-11ed-3d7f-b75711b208db
begin
	using DataFrames, CairoMakie, GraphMakie,PlutoUI,ProfileCanvas, JLD2, ScikitLearn, LinearAlgebra, Flux, Random, PyCall, Plots,Statistics, ProgressMeter
	TableOfContents(title="BitterSweet Classifiers")
end

# ╔═╡ 422d6864-d70d-4293-ab5d-ead3200b1e7b
begin
	using CSV, MolecularGraph, MetaGraphs, Graphs, MolecularGraphKernels
	import MolecularGraph:removehydrogens
end

# ╔═╡ 9a3b5873-ead9-48ed-a007-480254492d99
md"""
# Load data
"""

# ╔═╡ 52271d30-12db-4b0e-aa6e-c49f2ecc49bc
begin
	@load "C:\\Users\\dcase\\GraphletKernel\\gram_matrix.jld2" b

	@load "C:\\Users\\dcase\\GraphletKernel\\sweet_bitvector.jld2" sweet_bitvector
	@load "C:\\Users\\dcase\\GraphletKernel\\bitter_bitvector.jld2" bitter_bitvector
	@load "C:\\Users\\dcase\\GraphletKernel\\tasteless_bitvector.jld2" tasteless_bitvector
	removed_molecules_bitvector = [i∉ [265, 266, 267, 1063] for i in 1:1358]
	sweet_bitvector = sweet_bitvector[removed_molecules_bitvector]
	bitter_bitvector = bitter_bitvector[removed_molecules_bitvector]
	tasteless_bitvector = tasteless_bitvector[removed_molecules_bitvector]
end

# ╔═╡ 75e3a98b-44c2-4701-9886-31f211c0298d
removed_molecules_gram = [i∉[1137, 265, 266, 267, 1063] for i in 1:size(b)[1]]

# ╔═╡ ec880e78-db99-410b-b039-923895268335
cg_gram = b[removed_molecules_gram, removed_molecules_gram]; ##remove PF6, and others

# ╔═╡ 74d30a7a-5731-48d3-9a8c-3af70e22fb90
md"""
# SVM
"""

# ╔═╡ d05d720b-bf4c-4a87-9dfb-a1371cf7c58f
begin
	@sk_import svm : SVC
	@sk_import metrics: confusion_matrix
	@sk_import metrics: precision_score
	@sk_import metrics: accuracy_score
	@sk_import metrics: recall_score
	@sk_import metrics: f1_score
	@sk_import preprocessing: KernelCenterer
end

# ╔═╡ c14b4e51-cfa0-4fee-9f2f-2caf78825881
struct Scores
	acc::Float64
	pre::Float64
	rec::Float64
	f1::Float64
	cm::Matrix{Float64}
end

# ╔═╡ 433de812-d272-4a01-bb62-a1808f333065
function holdouts(size; validation_and_training = false, validation_size = 100, testing_size = 100) 
	if validation_and_training
		holdouts = collect(1:1354)[randperm(length(collect(1:1354)))][1:validation_size+testing_size]
		validation = holdouts[1:validation_size]
		testing = holdouts[validation_size+1:testing_size+validation_size]
		return validation,testing
	else
		return collect(1:1354)[randperm(length(collect(1:1354)))][1:size] 
	end
end

# ╔═╡ 2024c6b7-619b-410a-9824-e3cf3073a4a4
function train_svm(K_train::Matrix, y_train::Vector, C::Float64;kernel="precomputed")
	# determine centering of Gram matrix
	tf = KernelCenterer().fit(K_train)

	# center Gram matrix
	K_train_centered = tf.transform(K_train)

	# train suppor vector classifier
	svc = SVC(kernel=kernel, C=C, class_weight="balanced")
	svc.fit(K_train_centered, y_train)

	return svc, tf
end

# ╔═╡ de26db2f-a095-418f-8446-491fbf76462d
function train_and_score_params(C,class_bitvector,gram_matrix,split)
	test_split = holdouts(split)

	train_index = [i ∉ test_split for i ∈ eachindex(class_bitvector)]
	
	train_class = class_bitvector[train_index]
	test_class = class_bitvector[test_split]

	train_matrix = gram_matrix[train_index,train_index]
	test_matrix = gram_matrix[train_index,test_split]

	


	svc, tf = train_svm(train_matrix, train_class, Float64(C))
	
	K_test_centered = tf.transform(test_matrix')
	y_pred = svc.predict(K_test_centered)
	decisions = svc.decision_function(train_matrix)
	coef = svc.dual_coef_
	supports = svc.support_
	support_vectors = svc.support_vectors_
	int = svc.intercept_
	
	
	accuracy = sum([y_pred[i] == test_class[i] for i in 1:length(test_class)])/length(test_class)
	#return maximum([accuracy, 1-accuracy])
	return length(supports),Scores(
		  accuracy_score(test_class, y_pred),
		 length(unique(y_pred)) == 2 ? precision_score(test_class, y_pred) : 0.0,
		    recall_score(test_class, y_pred),
		        f1_score(test_class, y_pred),
		confusion_matrix(test_class, y_pred)
	)
end

# ╔═╡ 4023cc37-5e26-4101-95b0-131daa0129ab
md"""
### scores
"""

# ╔═╡ 0e391f1f-b091-4a76-966e-a94a4f3501ca
train_and_score_params(25,sweet_bitvector,cg_gram,400)

# ╔═╡ 996b6e7c-d5a7-4310-9497-9665ae46cf2c
train_and_score_params(25,bitter_bitvector,cg_gram,400)

# ╔═╡ 1c754230-e34a-4b7e-9ac1-8cbc728f250a
train_and_score_params(25,tasteless_bitvector,cg_gram,400)

# ╔═╡ 7156399b-0494-4d51-b625-b54666ec872b
md"""
### Decision visualizations
"""

# ╔═╡ ed4d8486-884e-4e92-92fb-48d1e8ed2610
begin
	transform = KernelCenterer().fit(cg_gram)
	
	cg_gram_centered = transform.transform(cg_gram)

	linear_svc = SVC(kernel="linear", C=25.0, class_weight="balanced")
	linear_svc.fit(cg_gram_centered, sweet_bitvector)
	linear_sweet_pred = linear_svc.predict(cg_gram_centered)
	
	coef = linear_svc.coef_
	decision_function_sweet = linear_svc.decision_function(cg_gram_centered)
	Intercept_sweet = linear_svc.intercept_[1]

	w_sweet = [coef[0,i] for i ∈ 1:1354]

	linear_svc.fit(cg_gram_centered, bitter_bitvector)
	coef_bitter = linear_svc.coef_
	Intercept_bitter = linear_svc.intercept_[1]
	decision_function_bitter = linear_svc.decision_function(cg_gram_centered)
	w_bitter = [coef_bitter[0,i] for i ∈ 1:1354]
end

# ╔═╡ 187b80b4-1495-4f36-be95-160311f5001b
function train_and_score_params_linear(C,class_bitvector,gram_matrix,split)
	test_split = holdouts(split)

	train_index = [i ∉ test_split for i ∈ eachindex(class_bitvector)]
	
	train_class = class_bitvector[train_index]
	test_class = class_bitvector[test_split]

	train_matrix = gram_matrix[train_index,train_index]
	test_matrix = gram_matrix[train_index,test_split]

	


	svc, tf = train_svm(train_matrix, train_class, Float64(C), kernel = "linear")
	
	K_test_centered = tf.transform(test_matrix')
	y_pred = svc.predict(K_test_centered)
	
	
	
	accuracy = sum([y_pred[i] == test_class[i] for i in 1:length(test_class)])/length(test_class)
	#return maximum([accuracy, 1-accuracy])
	return Scores(
		  accuracy_score(test_class, y_pred),
		 length(unique(y_pred)) == 2 ? precision_score(test_class, y_pred) : 0.0,
		    recall_score(test_class, y_pred),
		        f1_score(test_class, y_pred),
		confusion_matrix(test_class, y_pred)
	)
end

# ╔═╡ 0c949b00-ca82-4f31-a8bc-2b53793836d6
function Scoring(class_bitvector, prediction_bitvector)
	return Scores(
		  accuracy_score(
			vec(
				  Bool.(class_bitvector)
			  ), 
			vec(
				  Bool.(prediction_bitvector)
			  )
		  ),
		 length(unique(Bool.(class_bitvector))) == 2 ? 
		 precision_score(
			vec(
				  Bool.(class_bitvector)
			  ), 
			vec(
				  Bool.(prediction_bitvector)
			  )
		 ) : 0.0,
		recall_score(
			vec(
				  Bool.(class_bitvector)
			  ), 
			vec(
				  Bool.(prediction_bitvector)
			  )
		),
		f1_score(
			vec(
				  Bool.(class_bitvector)
			  ), 
			vec(
				  Bool.(prediction_bitvector)
			  )
		),
		confusion_matrix(
			vec(
				  Bool.(class_bitvector)
			  ), 
			vec(
				  Bool.(prediction_bitvector)
			  )
		)
	)
end

# ╔═╡ 5d64e523-4052-49da-b8e5-c77963d53c81
train_and_score_params_linear(25,sweet_bitvector,cg_gram,200)

# ╔═╡ 9716c04a-2ec7-4a28-a146-737fb33761e9
begin
	colorz = Vector{String}(undef,length(sweet_bitvector))
	for i in eachindex(sweet_bitvector)
		if sweet_bitvector[i] ==1
			colorz[i] = "green"
		elseif bitter_bitvector[i] ==1 
			colorz[i] = "blue"
		
		else 
			colorz[i] = "red"
		end
	end
end

# ╔═╡ 21669eb2-f6d2-4e2b-8b87-cd891824706f
begin
	colorz_classified = Vector{String}(undef,length(sweet_bitvector))
		for i in eachindex(sweet_bitvector)
			if decision_function_sweet[i] > 0
				colorz_classified[i] = "green"
				
			elseif decision_function_bitter[i] > 0
				colorz_classified[i] = "blue"
			else
				colorz_classified[i] = "red"
			end
		end
end

# ╔═╡ f117ea46-d75c-4808-b629-2b8e9d062bc6
begin
	proj_sweet = (w_sweet'*cg_gram_centered)
	proj_bitter = (w_bitter'*cg_gram_centered)
	proj_sweet_bitter = [proj_sweet' proj_bitter']
end

# ╔═╡ 95f8ef87-89fa-438d-bfd1-928414818f5d
begin
	Plots.scatter(w_sweet,sweet_bitvector+rand(1354,1), color = colorz, ms=2, ma=0.5)
	Plots.xlabel!("feature weight in sweet prediction")
	Plots.ylabel!("sweet>1, nonsweet<1, random noise")
end

# ╔═╡ 85bbc206-855d-40bf-a73e-57a87f6cbb08
Plots.scatter(w_sweet,sweet_bitvector+rand(1354,1), color = colorz_classified, ms=2, ma=0.5)

# ╔═╡ 6938b38c-c2c1-4f1d-9b1d-2190e4993377
Plots.scatter(proj_sweet_bitter[:,1],proj_sweet_bitter[:,2], color = colorz_classified, ms=2, ma=0.5)

# ╔═╡ bf680e73-a736-49ab-8a34-ee82574fb5e4
Plots.scatter(proj_sweet_bitter[:,1],proj_sweet_bitter[:,2], color = colorz, ms=2, ma=0.5)

# ╔═╡ 14f49fd7-9e08-4a61-84e6-8fafbc45a7d2
hist(w_sweet)

# ╔═╡ 3dc48e7c-4780-4dc1-8918-3112d66d9d6f
begin
	positive_count = 0
	sweet_examples = sum(sweet_bitvector)
	negative_count = 0
	negative_examples = length(sweet_bitvector)-sweet_examples
	for i ∈ eachindex(w_sweet)
		if sweet_bitvector[i]==1 && w_sweet[i]>=1.0
			positive_count = positive_count+1
		end
		if sweet_bitvector[i]==0 && w_sweet[i]<-1
			negative_count = negative_count+1
		end
	end
	
	positive_count/sum(w_sweet.>=1.0)
	negative_count/sum(w_sweet.<-1.0)
end

# ╔═╡ 291a0ac4-8ce8-4e7d-8007-7f66aa7e19f2
md"""
# Flux
"""

# ╔═╡ 00e8bcf2-4625-4421-9197-b7f8582c09ed
md"""
## Multiclass classifier
"""

# ╔═╡ 0f25afdd-384f-46e4-8adc-2788f98d7936
begin
	test_indices = holdouts(280, validation_and_training=false, validation_size = 200, testing_size = 200)

	train_indices = [i ∉ test_indices for i ∈ eachindex(sweet_bitvector)]
	
	training_classes_sweet = sweet_bitvector[train_indices]
	testing_classes_sweet = sweet_bitvector[test_indices]
	#validation_classes_sweet = sweet_bitvector[validation_indices]
	
	training_classes_bitter = bitter_bitvector[train_indices]
	testing_classes_bitter = bitter_bitvector[test_indices]
	#validation_classes_bitter = bitter_bitvector[validation_indices]

	testing_classes_tasteless = tasteless_bitvector[test_indices]
	training_classes_tasteless = tasteless_bitvector[train_indices]
	#validation_classes_tasteless = tasteless_bitvector[validation_indices]
	
	nnet_training_matrix = Float32.(cg_gram[:,train_indices])
	nnet_test_matrix = Float32.(cg_gram[:,test_indices])
	#nnet_validation_matrix = Float32.(cg_gram[:,validation_indices])

	svm_train_matrix = cg_gram[train_indices, train_indices]
	svm_teset_matrix = cg_gram[test_indices, train_indices]

	
	

end;

# ╔═╡ 6c9a6762-16f7-449d-9715-ff743af6a4b1


# ╔═╡ f0412864-798b-4512-906c-e556813bf773
begin

	
	model = Chain(
    Dense(1354 => 18, tanh),
	Dense(18 => 12, tanh), 
	Dense(12 => 12, tanh), 
	Dense(12 => 12, tanh), 
	Dropout(.1),
	Dense(12 => 3, σ),
	softmax);
		
	target = Flux.onehotbatch(training_classes_sweet+2*training_classes_bitter, [2,1,0])

	testing_target = Flux.onehotbatch(testing_classes_sweet+2*testing_classes_bitter, [2,1,0])
	
	loader = Flux.DataLoader((nnet_training_matrix, target), batchsize=200, shuffle=true)
	
	optim = Flux.setup(Flux.Adam(.00001), model)

	#validation_target = Flux.onehotbatch(validation_classes_sweet+2*validation_classes_bitter, [2,1,0])

	#validation = Flux.DataLoader((nnet_validation_matrix, validation_target), batchsize=200, shuffle=true)
	
	losses = []
	training_loss = []
	old_error = 0
	epoch_best = 1
	epoch_losses = []
	training_loss_avg = []

	testmode!(model, false)
	
	for epoch in 1:30000
	    for (x, y) in loader
	        loss, grads = Flux.withgradient(model) do m
	            # Evaluate model and loss inside gradient context:
	            y_hat = m(x)
	            Flux.crossentropy(y_hat, y)
				
	        end
	        Flux.update!(optim, model, grads[1])
	        push!(losses, loss)  # batch loss logging
			
	    end

		# loss logging by epoch
		epoch_loss = Flux.crossentropy(model(nnet_training_matrix), target)
		push!(epoch_losses, epoch_loss)

		# test set loss logging
		y_hat_v = model(nnet_test_matrix)
		error = Flux.crossentropy(y_hat_v, testing_target)
		push!(training_loss, error)

		# test set loss rolling average
		if epoch > 50
			rolling_average = sum(training_loss[epoch-50:epoch])/50
			push!(training_loss_avg, rolling_average)
		end

		#exit loop based on test set overfit
		if epoch > 300 && 
		(epoch-findlast(training_loss_avg.==minimum(training_loss_avg))-50) > epoch/10
			break
			
		end
	end
end

# ╔═╡ f5c7f438-c027-402d-a23a-be5e35739a53
out1 = model(nnet_training_matrix)

# ╔═╡ db0f1e11-6df2-4083-8d0f-db9797de6bba
Plots.plot(eachindex(losses),losses)

# ╔═╡ 9cc4b623-c0fa-4603-9308-47e15c0d4084
Plots.plot(eachindex(training_loss_avg), training_loss_avg)

# ╔═╡ 968bcb20-8937-4306-a14a-b5877b1b06d2
begin
	testmode!(model)
	# model output after training - in sample
	out2 = model(nnet_training_matrix) 
	c_n_sweet_hat = out2[2,:]
	c_n_bitter_hat = out2[1,:]
	c_n_tasteless_hat = out2[3,:]

	# model output after training - out of sample test
	out_test = model(nnet_test_matrix) 
	c_n_sweet_hat_os = out_test[2,:]
	c_n_bitter_hat_os = out_test[1,:]
	c_n_tasteless_hat_os = out_test[3,:]


	# most probable outputs - in sample prediction/training set reconstruction
	c_n_mp_sweet_hat = permutedims(hcat([out2[2,i].==maximum(out2[:,i]) for i in eachindex(out2[2,:])]...))'
	c_n_mp_bitter_hat = permutedims(hcat([out2[1,i].==maximum(out2[:,i]) for i in eachindex(out2[1,:])]...))'
	c_n_mp_tasteless_hat = permutedims(hcat([out2[3,i].==maximum(out2[:,i]) for i in eachindex(out2[3,:])]...))'

	# most probable outputs - out of sample test
	c_n_mp_sweet_hat_os = 
		permutedims(
			hcat(
				[out_test[2,i].==maximum(out_test[:,i]) for i in eachindex(out_test[2,:])]...
			)
		)'
	c_n_mp_bitter_hat_os = permutedims(hcat([out_test[1,i].==maximum(out_test[:,i]) for i in eachindex(out_test[1,:])]...))'
	c_n_mp_tasteless_hat_os = permutedims(hcat([out_test[3,i].==maximum(out_test[:,i]) for i in eachindex(out_test[3,:])]...))'

	

end;

# ╔═╡ 80691e93-d397-4efa-bea1-c97316e681e6
md"""
### scores
"""

# ╔═╡ 75eb906b-059d-4521-9d3f-a1eb97cb92af
Scoring(testing_classes_sweet, c_n_mp_sweet_hat_os)

# ╔═╡ e6b0558b-58b4-4151-9885-8f6ba6894c3e
Scoring(testing_classes_bitter, c_n_mp_bitter_hat_os)

# ╔═╡ d935f630-0e80-453e-9e90-feb54f8de122
Scoring(testing_classes_tasteless, c_n_mp_tasteless_hat_os)

# ╔═╡ 0d950e3f-c220-4f8e-906d-0c9204a1c705
md"""
## 1:1 Classifiers
"""

# ╔═╡ 0a4391b2-fbb7-4046-814c-42a4a7893877
md"""
### Sweet vs Non-sweet
"""

# ╔═╡ 20e20031-ee7c-4324-b411-c974b2bfc5f8
function nnet_sweet_c()
	model_sweet_c = Chain(
    Dense(1354 => 18, tanh),
    BatchNorm(18),
	Dense(18 => 12, tanh), 
	BatchNorm(12),
	Dense(12 => 12, tanh), 
	Dropout(.2),
	Dense(12 => 12, tanh), 
	BatchNorm(12),
	Dense(12 => 2, σ),
	softmax);
			
	target_sweet_c = Flux.onehotbatch(training_classes_sweet, [true, false])

	testing_target_sweet_c = Flux.onehotbatch(testing_classes_sweet, [true, false])
	
	loader_sweet_c = Flux.DataLoader((nnet_training_matrix, target_sweet_c), batchsize=200, shuffle=true)
	
	optim_sweet_c = Flux.setup(Flux.Adam(.00001), model_sweet_c)

	#validation_target = Flux.onehotbatch(validation_classes_sweet+2*validation_classes_bitter, [2,1,0])

	#validation = Flux.DataLoader((nnet_validation_matrix, validation_target), batchsize=200, shuffle=true)
	
	losses_sweet_c = []
	training_loss_sweet_c = []
	epoch_losses_sweet_c = []
	training_loss_avg_sweet_c = []
	
	testmode!(model_sweet_c, false)
	for epoch in 1:30000
	    for (x, y) in loader_sweet_c
	        loss, grads = Flux.withgradient(model_sweet_c) do m
	            # Evaluate model and loss inside gradient context:
	            y_hat = m(x)
	            Flux.mse(y_hat, y)
				
	        end
	        Flux.update!(optim_sweet_c, model_sweet_c, grads[1])
	        push!(losses_sweet_c, loss)  # batch loss logging
			
	    end

		# loss logging by epoch
		epoch_loss = Flux.mse(model_sweet_c(nnet_training_matrix), target_sweet_c)
		push!(epoch_losses_sweet_c, epoch_loss)

		# test set loss logging
		y_hat_v = model_sweet_c(nnet_test_matrix)
		error = Flux.mse(y_hat_v, testing_target_sweet_c)
		push!(training_loss_sweet_c, error)

		# test set loss rolling average
		if epoch > 50
			rolling_average = sum(training_loss_sweet_c[epoch-50:epoch])/50
			push!(training_loss_avg_sweet_c, rolling_average)
		end

		# saving model snapshot at global minimum
		#if epoch > 300 && training_loss_avg_sweet_c[end].==minimum(training_loss_avg_sweet_c)
		# 	model_save = Flux.state(model_sweet_c)
		#end
	
		# exit loop based on test set overfit
		if epoch > 300 && 
		(epoch-findlast(training_loss_avg_sweet_c.==minimum(training_loss_avg_sweet_c))-50) > 500
			break
			
		end
	end

	#Flux.loadmodel!(model_sweet_c, model_save)
	testmode!(model_sweet_c)
	return model_sweet_c(nnet_test_matrix), training_loss_avg_sweet_c, epoch_losses_sweet_c
end

# ╔═╡ e77c3fb4-b15b-48e3-9207-7867f724764b
out_sweet, training_loss_avg_sweet_c, epoch_losses_sweet_c = nnet_sweet_c();

# ╔═╡ b0243fea-02a2-48a7-8f04-436d0bf5f212
Plots.plot(eachindex(training_loss_avg_sweet_c), training_loss_avg_sweet_c)

# ╔═╡ a04dde28-4fc3-4630-8dbf-1fa7417df298
sweet_c_y_hat = permutedims(hcat([out_sweet[1,i].==maximum(out_sweet[:,i]) for i in eachindex(out_sweet[1,:])]...))';

# ╔═╡ 365270e9-c043-4752-b56d-aa141f0bd297
Scoring(testing_classes_sweet, sweet_c_y_hat)

# ╔═╡ c319887c-436c-42c1-b923-7c7e813f9cd6
md"""
### Bitter/non-bitter
"""

# ╔═╡ a3575c2e-e7a0-4d10-91ac-180a24084010
function nnet_bitter_c()
	model_bitter_c = Chain(
    Dense(1354 => 18, tanh),
    BatchNorm(18),
	Dense(18 => 12, tanh), 
	BatchNorm(12),
	Dense(12 => 12, tanh), 
	Dropout(.2),
	Dense(12 => 12, tanh), 
	BatchNorm(12),
	Dense(12 => 2, σ),
	softmax);
			
	target_bitter_c = Flux.onehotbatch(training_classes_bitter, [true, false])

	testing_target_bitter_c = Flux.onehotbatch(testing_classes_bitter, [true, false])
	
	loader_bitter_c = Flux.DataLoader((nnet_training_matrix, target_bitter_c), batchsize=200, shuffle=true)
	
	optim_bitter_c = Flux.setup(Flux.Adam(.0001), model_bitter_c)

	#validation_target = Flux.onehotbatch(validation_classes_sweet+2*validation_classes_bitter, [2,1,0])

	#validation = Flux.DataLoader((nnet_validation_matrix, validation_target), batchsize=200, shuffle=true)
	
	losses_bitter_c = []
	training_loss_bitter_c = []
	epoch_losses_bitter_c = []
	training_loss_avg_bitter_c = []
	
	testmode!(model_bitter_c, false)
	for epoch in 1:30000
	    for (x, y) in loader_bitter_c
	        loss, grads = Flux.withgradient(model_bitter_c) do m
	            # Evaluate model and loss inside gradient context:
	            y_hat = m(x)
	            Flux.mse(y_hat, y)
				
	        end
	        Flux.update!(optim_bitter_c, model_bitter_c, grads[1])
	        push!(losses_bitter_c, loss)  # batch loss logging
			
	    end

		# loss logging by epoch
		epoch_loss = Flux.mse(model_bitter_c(nnet_training_matrix), target_bitter_c)
		push!(epoch_losses_bitter_c, epoch_loss)

		# test set loss logging
		y_hat_v = model_bitter_c(nnet_test_matrix)
		error = Flux.mse(y_hat_v, testing_target_bitter_c)
		push!(training_loss_bitter_c, error)

		# test set loss rolling average
		if epoch > 50
			rolling_average = sum(training_loss_bitter_c[epoch-50:epoch])/50
			push!(training_loss_avg_bitter_c, rolling_average)
		end

		# saving model snapshot at global minimum
		#if epoch > 300 && training_loss_avg_sweet_c[end].==minimum(training_loss_avg_sweet_c)
		# 	model_save = Flux.state(model_sweet_c)
		#end
	
		# exit loop based on test set overfit
		if epoch > 300 && 
		(epoch-findlast(training_loss_avg_bitter_c.==minimum(training_loss_avg_bitter_c))-50) > 500
			break
			
		end
	end

	#Flux.loadmodel!(model_sweet_c, model_save)
	testmode!(model_bitter_c)
	return model_bitter_c(nnet_test_matrix), training_loss_avg_bitter_c, epoch_losses_bitter_c
end

# ╔═╡ 97251405-a573-496e-97dc-952cc7056b30
out_bitter, training_loss_avg_bitter_c, epoch_losses_bitter_c = nnet_bitter_c();

# ╔═╡ 17f0c2b6-6ab9-470a-bf97-ce14ed16f4b4
Plots.plot(eachindex(training_loss_avg_bitter_c), training_loss_avg_bitter_c)

# ╔═╡ 06df10ba-467a-44d6-b3ef-2cc202ed1fff
bitter_c_y_hat = permutedims(hcat([out_bitter[1,i].==maximum(out_bitter[:,i]) for i in eachindex(out_bitter[1,:])]...))';

# ╔═╡ 6f588e60-30d7-4951-a1fa-f9cabb641d83
Scoring(testing_classes_bitter, bitter_c_y_hat)

# ╔═╡ a0634263-9e74-469b-a07e-de48b22606b0
function train_neural_net(training_classes::Vector, training_feature_mx::Matrix, validation_classes::Vector, validation_feature_mx::Matrix)
	
	model = Chain(
    Dense(size(training_feature_mx)[1] => 18, tanh),
    BatchNorm(18),
	Dense(18 => 12, tanh), 
	BatchNorm(12),
	Dense(12 => 12, tanh), 
	Dropout(.2),
	Dense(12 => 12, tanh), 
	BatchNorm(12),
	Dense(12 => 2, σ),
	softmax);
			
	target  = Flux.onehotbatch(training_classes, [true, false])

	v_target = Flux.onehotbatch(validation_classes, [true, false])
	
	loader = Flux.DataLoader((training_feature_mx, target), batchsize=200, shuffle=true)
	
	optimizer = Flux.setup(Flux.Adam(.0001), model)
	
	losses = []
	validation_loss = []
	epoch_losses = []
	validation_loss_avg = []
	testmode!(model, false)

	for epoch in 1:30000
	    for (x, y) in loader
	        loss, grads = Flux.withgradient(model) do m
	            # Evaluate model and loss inside gradient context:
	            y_hat = m(x)
	            Flux.mse(y_hat, y)
				
	        end
	        Flux.update!(optimizer, model, grads[1])
	        push!(losses, loss)  # batch loss logging
			
	    end

		# loss logging by epoch
		epoch_loss = Flux.mse(model(training_feature_mx), target)
		push!(epoch_losses, epoch_loss)

		# test set loss logging
		y_hat_v = model(validation_feature_mx)
		error = Flux.mse(y_hat_v, v_target)
		push!(validation_loss, error)

		# test set loss rolling average
		if epoch > 50
			rolling_average = sum(validation_loss[epoch-50:epoch])/50
			push!(validation_loss_avg, rolling_average)
		end

		# saving model snapshot at global minimum
		#if epoch > 300 && training_loss_avg_sweet_c[end].==minimum(training_loss_avg_sweet_c)
		# 	model_save = Flux.state(model_sweet_c)
		#end
	
		# exit loop based on test set overfit
		if epoch > 300 && 
		(epoch-findlast(validation_loss_avg.==minimum(validation_loss_avg))-50) > 500
			break
			
		end
	end

	#Flux.loadmodel!(model_sweet_c, model_save)
	testmode!(model)
	return model, model(training_feature_mx), epoch_losses, validation_loss_avg
end

# ╔═╡ 7bcb767f-ad63-4ac7-bee0-1869b59e5a6d
res = train_neural_net(training_classes_bitter, nnet_training_matrix, testing_classes_bitter, nnet_test_matrix)

# ╔═╡ 13e239be-cf78-4fa1-bf2e-cc5618e7241b
res[1]

# ╔═╡ 4d0e660e-489d-47a9-8670-4cbcb63d713a
md"""
# Decision trees
"""

# ╔═╡ 53d30f62-ffbc-45c5-a6ee-b7702b79a6c8
begin
	@sk_import ensemble : RandomForestClassifier
	@sk_import ensemble : AdaBoostClassifier
end

# ╔═╡ 564e8a92-1a39-4318-acfe-75d4b52d21a1
md"""
## Random Forest Classifier
"""

# ╔═╡ fbeb1934-7184-4b56-90ed-13d496da6359
begin
	rfc_sweet = RandomForestClassifier();
	rfc_sweet.fit(nnet_training_matrix',training_classes_sweet);
	rf_sweet = rfc_sweet.predict(nnet_test_matrix');

	Scoring(testing_classes_sweet, rf_sweet)
end

# ╔═╡ 0b821654-1779-438a-b0aa-e54f7d6b3094
begin
	rfc_bitter = RandomForestClassifier();
	rfc_bitter.fit(nnet_training_matrix',training_classes_bitter);
	rf_bitter = rfc_bitter.predict(nnet_test_matrix');

	Scoring(testing_classes_bitter, rf_bitter)
end

# ╔═╡ 79cd8f69-244a-4d0d-bae9-e34cce93c741
md"""
## AdaBoost Classifier
"""

# ╔═╡ 280ddf4b-8f94-4f43-b7b6-98b4c02266b4
begin
	ab_sweet = AdaBoostClassifier()
	ab_sweet.fit(nnet_training_matrix',training_classes_sweet)
	ab_sweet_y_hat = ab_sweet.predict(nnet_test_matrix')

	Scoring(testing_classes_sweet, ab_sweet_y_hat)
end

# ╔═╡ 8b461b4b-58c9-429a-808e-2640b800555b
begin
	ab_bitter = AdaBoostClassifier()
	ab_bitter.fit(nnet_training_matrix',training_classes_bitter)
	ab_bitter_y_hat = ab_bitter.predict(nnet_test_matrix')

	Scoring(testing_classes_bitter, ab_bitter_y_hat)
end

# ╔═╡ 0a39ff49-2661-4fd0-ae15-79df01961de3
md"""
# Test sets
"""

# ╔═╡ bc2dd286-82ab-4f72-8fa4-728eeb595609
begin
	test_set_combined = Base.download("https://raw.githubusercontent.com/cosylabiiit/bittersweet/master/data/bitter-test.tsv")
	BitterSweet_test_sets = CSV.read(test_set_combined, DataFrame)
	
	errored_smiles_bittertest = []
	df_new_bittertest = DataFrame()
	allowed_atoms_bittertest = ['C','O','N','c','S','B','P','F','o','I','K']
	disallowed_features_bittertest = ['.','+']
	size_min_bittertest = 4
	size_max_bittertest = 30
	for z ∈ 1:length(BitterSweet_test_sets[!,5])
		smiles_string = BitterSweet_test_sets[z,5]
		if size_min_bittertest <= count(n ∈ allowed_atoms_bittertest for n ∈ smiles_string) <= size_max_bittertest && all([i ∉ disallowed_features_bittertest for i ∈ smiles_string])
			try 
				mol = smilestomol(smiles_string)
				push!(df_new_bittertest,BitterSweet_test_sets[z,:], promote=true)
			catch e
				push!(errored_smiles_bittertest, [z,smiles_string])
			end
		end
	end
end

# ╔═╡ c02aa62b-6ba0-4b71-8cb8-61964d4910f5
begin
	phyto_dictionary = df_new_bittertest[[occursin("Phyto",df_new_bittertest[i,3]) for i ∈ eachindex(df_new_bittertest[:,3])],:]

	bitter_new = df_new_bittertest[[occursin("Bitter-New",df_new_bittertest[i,3]) for i ∈ eachindex(df_new_bittertest[:,3])],:]

	unimi = df_new_bittertest[[occursin("UNIMI",df_new_bittertest[i,3]) for i ∈ eachindex(df_new_bittertest[:,3])],:]
end

# ╔═╡ 5c020120-cb40-47c6-91f7-2def55767dda
bitter_new

# ╔═╡ e5d6f4ff-ceb3-4caa-93f9-95e35903587d
@load "C:\\Users\\dcase\\GraphletKernel\\Metagraphs.jld2" metagraphs

# ╔═╡ 55d6691b-6bc2-4cbc-a476-1e694953e0db
function graphs_to_gram_vectors(smiles,gram_graph_vector; n=4)
	new_graphs = [MetaGraph(MolecularGraph.removehydrogens(smilestomol(i))) for i ∈ smiles]
	return_matrix = zeros(length(smiles),length(gram_graph_vector))
	for i ∈ eachindex(new_graphs)
		Gᵢ = new_graphs[i]
		k_ii = connected_graphlet(Gᵢ,Gᵢ, n=n)
		for j ∈ eachindex(gram_graph_vector)
			Gⱼ = gram_graph_vector[j]
			k_jj = connected_graphlet(Gⱼ,Gⱼ, n=n)
			k_ij = connected_graphlet(Gᵢ,Gⱼ, n=n)
			return_matrix[i,j] = k_ij/(k_ii*k_jj)^.5
		end
	end
	return return_matrix
end

# ╔═╡ fc0d8099-0871-4ff9-bb58-b237e635c287
begin
	@load "C:\\Users\\dcase\\GraphletKernel\\phyto_dictionary_mx_30.jld2" phyto_dictionary_mx 
	@load "C:\\Users\\dcase\\GraphletKernel\\unimi_mx_30.jld2" unimi_mx
	@load "C:\\Users\\dcase\\GraphletKernel\\bitter_new_mx_30.jld2" bitter_new_mx

	phyto_dictionary_mx = phyto_dictionary_mx[:,removed_molecules_bitvector]
	unimi_mx = unimi_mx[:,removed_molecules_bitvector]
	bitter_new_mx = bitter_new_mx[:,removed_molecules_bitvector]
end

# ╔═╡ c559248a-cf56-4fa1-a8d7-e58b6797cb82
begin
	phyto_bitter_bitvector = [i=="Bitter" for i in phyto_dictionary[:,2]]
	unimi_bitter_bitvector = [i=="Bitter" for i in unimi[:,2]]
	bitter_new_bitvector = [i=="Bitter" for i in bitter_new[:,2]]
end

# ╔═╡ e6e5a1cf-a993-4a49-830f-fa73d70fe164
begin
	phyto_bitter_yhat_abs = rfc_bitter.predict(phyto_dictionary_mx)
	unimi_bitter_yhat_abs = rfc_bitter.predict(unimi_mx)
	bitter_new_yhat_abs = rfc_bitter.predict(bitter_new_mx)
end

# ╔═╡ b6cec67b-8621-421a-baf1-297867b026f4
Scoring(phyto_bitter_bitvector, phyto_bitter_yhat_abs)

# ╔═╡ 02337422-dddc-456f-a1b0-7a47f618df72
Scoring(unimi_bitter_bitvector, unimi_bitter_yhat_abs)

# ╔═╡ f829e817-f9cf-4ebe-80ee-0491ae743895
Scoring(bitter_new_bitvector, bitter_new_yhat_abs)

# ╔═╡ 73f9805e-9385-4a78-9d5e-f9ddf5e82dcf
begin
	y_hat_nn_phyto = res[1](phyto_dictionary_mx')
	y_hat_nn_unimi = res[1](unimi_mx')
	y_hat_nn_bitter_new = res[1](bitter_new_mx')
end

# ╔═╡ 38fc7d09-6574-4dea-ab5e-4895db6126e2
y_hat_nn_phyto_mp = permutedims(hcat([y_hat_nn_phyto[1,i].==maximum(y_hat_nn_phyto[:,i]) for i in eachindex(y_hat_nn_phyto[1,:])]...))'

# ╔═╡ 302e348a-0ee2-4794-bd73-2637d36b53b0
y_hat_nn_unimi_mp = permutedims(hcat([y_hat_nn_unimi[1,i].==maximum(y_hat_nn_unimi[:,i]) for i in eachindex(y_hat_nn_unimi[1,:])]...))'

# ╔═╡ 3b4ada9d-d6ed-4bf7-aa99-601529378977
y_hat_nn_bitter_test_mp = permutedims(hcat([y_hat_nn_bitter_new[1,i].==maximum(y_hat_nn_bitter_new[:,i]) for i in eachindex(y_hat_nn_bitter_new[1,:])]...))'

# ╔═╡ a0023cf4-0b65-4fca-b55b-d46539ea057e
Scoring(phyto_bitter_bitvector, y_hat_nn_phyto_mp)

# ╔═╡ bac0722f-ee85-49ad-8ed2-12dde0784e68
Scoring(unimi_bitter_bitvector, y_hat_nn_unimi_mp)

# ╔═╡ 93ecf657-4baa-433e-abe2-12e19b5a36bd
Scoring(bitter_new_bitvector, y_hat_nn_bitter_test_mp)

# ╔═╡ 9e070647-f926-49b7-ae2c-7cf0f80fa919
function train_and_score_params_linear_specified(C,train_class,train_matrix,test_matrix, test_class)

	svc, tf = train_svm(train_matrix, train_class, Float64(C), kernel = "precomputed")
	
	K_test_centered = tf.transform(test_matrix)
	y_pred = svc.predict(K_test_centered)
	
	
	accuracy = sum([y_pred[i] == test_class[i] for i in 1:length(test_class)])/length(test_class)

	return Scores(
		  accuracy_score(test_class, y_pred),
		 length(unique(y_pred)) == 2 ? precision_score(test_class, y_pred) : 0.0,
		    recall_score(test_class, y_pred),
		        f1_score(test_class, y_pred),
		confusion_matrix(test_class, y_pred)
	)
end

# ╔═╡ 460fc5bf-630a-4575-882f-f9132559d6fe
train_and_score_params_linear_specified(25,training_classes_bitter,svm_train_matrix,phyto_dictionary_mx[:,train_indices], phyto_bitter_bitvector)

# ╔═╡ 0ba1d1e5-fd55-45cf-a776-edee2186fbd4
train_and_score_params_linear_specified(25,training_classes_bitter,svm_train_matrix,unimi_mx[:,train_indices], unimi_bitter_bitvector)

# ╔═╡ 002a236a-3ccc-47ee-a50a-73470725f20a
train_and_score_params_linear_specified(25,training_classes_bitter,svm_train_matrix,bitter_new_mx[:,train_indices], bitter_new_bitvector)

# ╔═╡ fdbc9c21-be48-417b-95da-ca7a27e896a3
md"""
## MACCS Kernel Comparison tests
"""

# ╔═╡ 0b94618b-8fb0-4c4d-9216-a63e2bf51f88
@load "C:\\Users\\dcase\\GraphletKernel\\bittersweet_maccs.jld2" bittersweet_maccs

# ╔═╡ fa63181b-704c-4e68-871a-3a982ea2e46b
md"""
### Constructing the gram matrix for SVM
"""

# ╔═╡ 965d1a4b-e317-4b4b-a372-e5b94aab355a
begin
	maccs_gram = zeros(length(bittersweet_maccs),length(bittersweet_maccs))
	for i ∈ eachindex(bittersweet_maccs)
		for j ∈ eachindex(bittersweet_maccs)
			maccs_gram[i,j] = bittersweet_maccs[i]'*bittersweet_maccs[j]
		end
	end
	maccs_gram_normalized = maccs_gram
	for i ∈ 1:size(maccs_gram_normalized)[1]
		k_ii = bittersweet_maccs[i]'*bittersweet_maccs[i]
		for j ∈ 1:size(maccs_gram_normalized)[1]
			k_jj = bittersweet_maccs[j]'*bittersweet_maccs[j]
			maccs_gram_normalized[i,j] = maccs_gram[i,j]/(k_ii*k_jj)^.5
		end
	end
			
end

# ╔═╡ fc872d9e-65bc-4467-80ce-16033d346984
begin
	maccs_train_svm = maccs_gram_normalized[train_indices, train_indices]
	maccs_test_svm = maccs_gram_normalized[test_indices, train_indices]
end

# ╔═╡ 87e1a41b-04df-46c2-9e0f-e32962c65f28
md"""
## SVM results
"""

# ╔═╡ 68087161-ef13-4446-a5aa-0a7ccd5f43a7
train_and_score_params_linear_specified(25,training_classes_bitter,maccs_train_svm,maccs_test_svm, testing_classes_bitter)

# ╔═╡ 52687bb4-43b1-4766-b589-9ffc6febe591
train_and_score_params_linear_specified(25,training_classes_sweet,maccs_train_svm,maccs_test_svm, testing_classes_sweet)

# ╔═╡ 27265b69-2088-47cb-b8a0-52266573a3f8
begin
	rfc_bitter_maccs = RandomForestClassifier();
	rfc_bitter_maccs.fit(bittersweet_maccs[train_indices],training_classes_bitter);
	rf_bitter_maccs = rfc_bitter_maccs.predict(bittersweet_maccs[test_indices]);

	Scoring(testing_classes_bitter, rf_bitter_maccs)
end

# ╔═╡ 99ef0080-b1ef-45f1-8047-80092751472b
begin
	rfc_sweet_maccs = RandomForestClassifier();
	rfc_sweet_maccs.fit(bittersweet_maccs[train_indices],training_classes_sweet);
	rf_sweet_maccs = rfc_sweet_maccs.predict(bittersweet_maccs[test_indices]);

	Scoring(testing_classes_sweet, rf_sweet_maccs)
end

# ╔═╡ 0368b202-6d35-43ce-8e7f-430cee6efa9c
md"""
# Model Variance Testing
"""

# ╔═╡ bf48d194-d96d-4cee-9ac6-0ce4d76d4f27
function variance_testing(n_trials)
	res = zeros(12,n_trials)
	for iteration = 1:n_trials
		test_indices = holdouts(280, validation_and_training=false, validation_size = 200, testing_size = 200)

		train_indices = [i ∉ test_indices for i ∈ eachindex(sweet_bitvector)]
		
		training_classes_sweet = sweet_bitvector[train_indices]
		testing_classes_sweet = sweet_bitvector[test_indices]
		#validation_classes_sweet = sweet_bitvector[validation_indices]
		
		training_classes_bitter = bitter_bitvector[train_indices]
		testing_classes_bitter = bitter_bitvector[test_indices]
		#validation_classes_bitter = bitter_bitvector[validation_indices]
		
		nnet_training_matrix = Float32.(cg_gram[:,train_indices])
		nnet_test_matrix = Float32.(cg_gram[:,test_indices])
		#nnet_validation_matrix = Float32.(cg_gram[:,validation_indices])
	
		svm_train_matrix = cg_gram[train_indices, train_indices]
		svm_test_matrix = cg_gram[test_indices, train_indices]

		maccs_train_svm = maccs_gram_normalized[train_indices, train_indices]
		maccs_test_svm = maccs_gram_normalized[test_indices, train_indices]

		# Bitter Neural Network
		nnet_model_bitter = train_neural_net(training_classes_bitter, nnet_training_matrix, testing_classes_bitter, nnet_test_matrix)[1]

		nnet_bitter_y_hat = nnet_model_bitter(nnet_test_matrix)
		nnet_bitter_y_hat_mp = permutedims(hcat([nnet_bitter_y_hat[1,i].==maximum(nnet_bitter_y_hat[:,i]) for i in eachindex(nnet_bitter_y_hat[1,:])]...))'
		
		res[1,iteration] = Scoring(testing_classes_bitter, nnet_bitter_y_hat_mp).f1

		# Sweet Neural Network
		nnet_model_sweet = train_neural_net(training_classes_sweet, nnet_training_matrix, testing_classes_sweet, nnet_test_matrix)[1]

		nnet_sweet_y_hat = nnet_model_sweet(nnet_test_matrix)
		nnet_sweet_y_hat_mp = permutedims(hcat([nnet_sweet_y_hat[1,i].==maximum(nnet_sweet_y_hat[:,i]) for i in eachindex(nnet_sweet_y_hat[1,:])]...))'
		
		res[2,iteration] = Scoring(testing_classes_sweet, nnet_sweet_y_hat_mp).f1

		# Bitter SVC
		res[3, iteration] = train_and_score_params_linear_specified(5,training_classes_bitter,svm_train_matrix,svm_test_matrix, testing_classes_bitter).f1
		
		# Sweet SVC
		res[4, iteration] = train_and_score_params_linear_specified( 5,training_classes_sweet,svm_train_matrix,svm_test_matrix, testing_classes_sweet).f1

		# Bitter Random Forest
		rfc_bitter = RandomForestClassifier();
		rfc_bitter.fit(nnet_training_matrix',training_classes_bitter);
		rf_bitter = rfc_bitter.predict(nnet_test_matrix');
	
		res[5, iteration] = Scoring(testing_classes_bitter, rf_bitter).f1

		# Sweet Random Forest
		rfc_sweet = RandomForestClassifier();
		rfc_sweet.fit(nnet_training_matrix',training_classes_sweet);
		rf_sweet = rfc_sweet.predict(nnet_test_matrix');
	
		res[6, iteration] = Scoring(testing_classes_sweet, rf_sweet).f1

		# Bitter AdaBoost
		ab_bitter = AdaBoostClassifier()
		ab_bitter.fit(nnet_training_matrix',training_classes_bitter)
		ab_bitter_y_hat = ab_bitter.predict(nnet_test_matrix')
	
		res[7, iteration] = Scoring(testing_classes_bitter, ab_bitter_y_hat).f1

		# Sweet AdaBoost
		ab_sweet = AdaBoostClassifier()
		ab_sweet.fit(nnet_training_matrix',training_classes_sweet)
		ab_sweet_y_hat = ab_sweet.predict(nnet_test_matrix')
	
		res[8, iteration] = Scoring(testing_classes_sweet, ab_sweet_y_hat).f1

		# MACCS svm - bitter
		res[9, iteration] = train_and_score_params_linear_specified(25,training_classes_bitter,maccs_train_svm,maccs_test_svm, testing_classes_bitter).f1

		# MACCS svm - sweet
		res[10, iteration] = train_and_score_params_linear_specified(25,training_classes_sweet,maccs_train_svm,maccs_test_svm, testing_classes_sweet).f1

		# MACCS random forrest - bitter
		rfc_bitter_maccs = RandomForestClassifier();
		rfc_bitter_maccs.fit(bittersweet_maccs[train_indices],training_classes_bitter);
		rf_bitter_maccs = rfc_bitter_maccs.predict(bittersweet_maccs[test_indices]);
	
		res[11, iteration] = Scoring(testing_classes_bitter, rf_bitter_maccs).f1

		# MACCS random forrest - sweet
		rfc_sweet_maccs = RandomForestClassifier();
		rfc_sweet_maccs.fit(bittersweet_maccs[train_indices],training_classes_sweet);
		rf_sweet_maccs = rfc_sweet_maccs.predict(bittersweet_maccs[test_indices]);
	
		res[12, iteration] = Scoring(testing_classes_sweet, rf_sweet_maccs).f1
		
	end
	return res
end
			
		

# ╔═╡ 8d721ffd-8023-4dbe-8476-6a011ee15efa
results = variance_testing(10)

# ╔═╡ 27c31f7a-8423-4bde-88c7-b27dbaba222a
sum.(results[i,:] for i ∈ 1:2:11)/10

# ╔═╡ a891c1c4-a2dc-48dd-8d9c-5005521ce558
sum.(results[i,:] for i ∈ 2:2:12)/10

# ╔═╡ e854f1c9-dd96-4081-9d5c-f2c0c212d02f
std.(results[i,:] for i ∈ 2:2:12)

# ╔═╡ 42ee1ede-95e7-484b-8670-5618e9445de6
std.(results[i,:] for i ∈ 1:2:12)

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
CSV = "336ed68f-0bac-5ca0-87d4-7b16caf5d00b"
CairoMakie = "13f3f980-e62b-5c42-98c6-ff1f3baf88f0"
DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
Flux = "587475ba-b771-5e3f-ad9e-33799f191a9c"
GraphMakie = "1ecd5474-83a3-4783-bb4f-06765db800d2"
Graphs = "86223c79-3864-5bf0-83f7-82e725a168b6"
JLD2 = "033835bb-8acc-5ee8-8aae-3f567f8a3819"
LinearAlgebra = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
MetaGraphs = "626554b9-1ddb-594c-aa3c-2596fe9399a5"
MolecularGraph = "6c89ec66-9cd8-5372-9f91-fabc50dd27fd"
MolecularGraphKernels = "bf3818bd-b6bb-4954-8baa-32c32282e633"
Plots = "91a5bcdd-55d7-5caf-9e0b-520d859cae80"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
ProfileCanvas = "efd6af41-a80b-495e-886c-e51b0c7d77a3"
ProgressMeter = "92933f4c-e287-5a05-a399-4b506db050ca"
PyCall = "438e738f-606a-5dbb-bf0a-cddfbfd45ab0"
Random = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"
ScikitLearn = "3646fa90-6ef7-5e7e-9f22-8aca16db6324"
Statistics = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[compat]
CSV = "~0.10.10"
CairoMakie = "~0.10.4"
DataFrames = "~1.5.0"
Flux = "~0.13.16"
GraphMakie = "~0.5.3"
Graphs = "~1.8.0"
JLD2 = "~0.4.31"
MetaGraphs = "~0.7.2"
MolecularGraph = "~0.13.0"
MolecularGraphKernels = "~0.9.0"
Plots = "~1.38.11"
PlutoUI = "~0.7.51"
ProfileCanvas = "~0.1.6"
ProgressMeter = "~1.7.2"
PyCall = "~1.95.1"
ScikitLearn = "~0.7.0"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.8.2"
manifest_format = "2.0"
project_hash = "f8f8567c92d2a894edf8cc2b8d94b8f014c54cef"

[[deps.AbstractFFTs]]
deps = ["ChainRulesCore", "LinearAlgebra"]
git-tree-sha1 = "16b6dbc4cf7caee4e1e75c49485ec67b667098a0"
uuid = "621f4979-c628-5d54-868e-fcf4e3e8185c"
version = "1.3.1"

[[deps.AbstractPlutoDingetjes]]
deps = ["Pkg"]
git-tree-sha1 = "8eaf9f1b4921132a4cff3f36a1d9ba923b14a481"
uuid = "6e696c72-6542-2067-7265-42206c756150"
version = "1.1.4"

[[deps.AbstractTrees]]
git-tree-sha1 = "faa260e4cb5aba097a73fab382dd4b5819d8ec8c"
uuid = "1520ce14-60c1-5f80-bbc7-55ef81b5835c"
version = "0.4.4"

[[deps.Accessors]]
deps = ["Compat", "CompositionsBase", "ConstructionBase", "Dates", "InverseFunctions", "LinearAlgebra", "MacroTools", "Requires", "StaticArrays", "Test"]
git-tree-sha1 = "a4f8669e46c8cdf68661fe6bb0f7b89f51dd23cf"
uuid = "7d9f7c33-5ae7-4f3b-8dc6-eff91059b697"
version = "0.1.30"

[[deps.Adapt]]
deps = ["LinearAlgebra", "Requires"]
git-tree-sha1 = "76289dc51920fdc6e0013c872ba9551d54961c24"
uuid = "79e6a3ab-5dfb-504d-930d-738a2a938a0e"
version = "3.6.2"

[[deps.Animations]]
deps = ["Colors"]
git-tree-sha1 = "e81c509d2c8e49592413bfb0bb3b08150056c79d"
uuid = "27a7e980-b3e6-11e9-2bcd-0b925532e340"
version = "0.4.1"

[[deps.ArgCheck]]
git-tree-sha1 = "a3a402a35a2f7e0b87828ccabbd5ebfbebe356b4"
uuid = "dce04be8-c92d-5529-be00-80e4d2c0e197"
version = "2.3.0"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.1"

[[deps.ArnoldiMethod]]
deps = ["LinearAlgebra", "Random", "StaticArrays"]
git-tree-sha1 = "62e51b39331de8911e4a7ff6f5aaf38a5f4cc0ae"
uuid = "ec485272-7323-5ecc-a04f-4719b315124d"
version = "0.2.0"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[deps.Atomix]]
deps = ["UnsafeAtomics"]
git-tree-sha1 = "c06a868224ecba914baa6942988e2f2aade419be"
uuid = "a9b6321e-bd34-4604-b9c9-b65b8de01458"
version = "0.1.0"

[[deps.Automa]]
deps = ["Printf", "ScanByte", "TranscodingStreams"]
git-tree-sha1 = "d50976f217489ce799e366d9561d56a98a30d7fe"
uuid = "67c07d97-cdcb-5c2c-af73-a7f9c32a568b"
version = "0.8.2"

[[deps.AxisAlgorithms]]
deps = ["LinearAlgebra", "Random", "SparseArrays", "WoodburyMatrices"]
git-tree-sha1 = "66771c8d21c8ff5e3a93379480a2307ac36863f7"
uuid = "13072b0f-2c55-5437-9ae7-d433b7a33950"
version = "1.0.1"

[[deps.AxisArrays]]
deps = ["Dates", "IntervalSets", "IterTools", "RangeArrays"]
git-tree-sha1 = "1dd4d9f5beebac0c03446918741b1a03dc5e5788"
uuid = "39de3d68-74b9-583c-8d2d-e117c070f3a9"
version = "0.4.6"

[[deps.BFloat16s]]
deps = ["LinearAlgebra", "Printf", "Random", "Test"]
git-tree-sha1 = "dbf84058d0a8cbbadee18d25cf606934b22d7c66"
uuid = "ab4f0b2a-ad5b-11e8-123f-65d77653426b"
version = "0.4.2"

[[deps.BangBang]]
deps = ["Compat", "ConstructionBase", "Future", "InitialValues", "LinearAlgebra", "Requires", "Setfield", "Tables", "ZygoteRules"]
git-tree-sha1 = "7fe6d92c4f281cf4ca6f2fba0ce7b299742da7ca"
uuid = "198e06fe-97b7-11e9-32a5-e1d131e6ad66"
version = "0.3.37"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[deps.Baselet]]
git-tree-sha1 = "aebf55e6d7795e02ca500a689d326ac979aaf89e"
uuid = "9718e550-a3fa-408a-8086-8db961cd8217"
version = "0.1.1"

[[deps.BitFlags]]
git-tree-sha1 = "43b1a4a8f797c1cddadf60499a8a077d4af2cd2d"
uuid = "d1d4a3ce-64b1-5f1a-9ba4-7e7e69966f35"
version = "0.1.7"

[[deps.Bzip2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "19a35467a82e236ff51bc17a3a44b69ef35185a2"
uuid = "6e34b625-4abd-537c-b88f-471c36dfa7a0"
version = "1.0.8+0"

[[deps.CEnum]]
git-tree-sha1 = "eb4cb44a499229b3b8426dcfb5dd85333951ff90"
uuid = "fa961155-64e5-5f13-b03f-caf6b980ea82"
version = "0.4.2"

[[deps.CRC32c]]
uuid = "8bf52ea8-c179-5cab-976a-9e18b702a9bc"

[[deps.CSV]]
deps = ["CodecZlib", "Dates", "FilePathsBase", "InlineStrings", "Mmap", "Parsers", "PooledArrays", "PrecompileTools", "SentinelArrays", "Tables", "Unicode", "WeakRefStrings", "WorkerUtilities"]
git-tree-sha1 = "ed28c86cbde3dc3f53cf76643c2e9bc11d56acc7"
uuid = "336ed68f-0bac-5ca0-87d4-7b16caf5d00b"
version = "0.10.10"

[[deps.CUDA]]
deps = ["AbstractFFTs", "Adapt", "BFloat16s", "CEnum", "CUDA_Driver_jll", "CUDA_Runtime_Discovery", "CUDA_Runtime_jll", "CompilerSupportLibraries_jll", "ExprTools", "GPUArrays", "GPUCompiler", "KernelAbstractions", "LLVM", "LazyArtifacts", "Libdl", "LinearAlgebra", "Logging", "Preferences", "Printf", "Random", "Random123", "RandomNumbers", "Reexport", "Requires", "SparseArrays", "SpecialFunctions", "UnsafeAtomicsLLVM"]
git-tree-sha1 = "280893f920654ebfaaaa1999fbd975689051f890"
uuid = "052768ef-5323-5732-b1bb-66c8b64840ba"
version = "4.2.0"

[[deps.CUDA_Driver_jll]]
deps = ["Artifacts", "JLLWrappers", "LazyArtifacts", "Libdl", "Pkg"]
git-tree-sha1 = "498f45593f6ddc0adff64a9310bb6710e851781b"
uuid = "4ee394cb-3365-5eb0-8335-949819d2adfc"
version = "0.5.0+1"

[[deps.CUDA_Runtime_Discovery]]
deps = ["Libdl"]
git-tree-sha1 = "bcc4a23cbbd99c8535a5318455dcf0f2546ec536"
uuid = "1af6417a-86b4-443c-805f-a4643ffb695f"
version = "0.2.2"

[[deps.CUDA_Runtime_jll]]
deps = ["Artifacts", "CUDA_Driver_jll", "JLLWrappers", "LazyArtifacts", "Libdl", "TOML"]
git-tree-sha1 = "5248d9c45712e51e27ba9b30eebec65658c6ce29"
uuid = "76a88914-d11a-5bdc-97e0-2f5a05c973a2"
version = "0.6.0+0"

[[deps.CUDNN_jll]]
deps = ["Artifacts", "CUDA_Runtime_jll", "JLLWrappers", "LazyArtifacts", "Libdl", "TOML"]
git-tree-sha1 = "2918fbffb50e3b7a0b9127617587afa76d4276e8"
uuid = "62b44479-cb7b-5706-934f-f13b2eb2e645"
version = "8.8.1+0"

[[deps.Cairo]]
deps = ["Cairo_jll", "Colors", "Glib_jll", "Graphics", "Libdl", "Pango_jll"]
git-tree-sha1 = "d0b3f8b4ad16cb0a2988c6788646a5e6a17b6b1b"
uuid = "159f3aea-2a34-519c-b102-8c37f9878175"
version = "1.0.5"

[[deps.CairoMakie]]
deps = ["Base64", "Cairo", "Colors", "FFTW", "FileIO", "FreeType", "GeometryBasics", "LinearAlgebra", "Makie", "SHA", "SnoopPrecompile"]
git-tree-sha1 = "2aba202861fd2b7603beb80496b6566491229855"
uuid = "13f3f980-e62b-5c42-98c6-ff1f3baf88f0"
version = "0.10.4"

[[deps.Cairo_jll]]
deps = ["Artifacts", "Bzip2_jll", "CompilerSupportLibraries_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "JLLWrappers", "LZO_jll", "Libdl", "Pixman_jll", "Pkg", "Xorg_libXext_jll", "Xorg_libXrender_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "4b859a208b2397a7a623a03449e4636bdb17bcf2"
uuid = "83423d85-b0ee-5818-9007-b63ccbeb887a"
version = "1.16.1+1"

[[deps.Calculus]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "f641eb0a4f00c343bbc32346e1217b86f3ce9dad"
uuid = "49dc2e85-a5d0-5ad3-a950-438e2897f1b9"
version = "0.5.1"

[[deps.ChainRules]]
deps = ["Adapt", "ChainRulesCore", "Compat", "Distributed", "GPUArraysCore", "IrrationalConstants", "LinearAlgebra", "Random", "RealDot", "SparseArrays", "Statistics", "StructArrays"]
git-tree-sha1 = "8bae903893aeeb429cf732cf1888490b93ecf265"
uuid = "082447d4-558c-5d27-93f4-14fc19e9eca2"
version = "1.49.0"

[[deps.ChainRulesCore]]
deps = ["Compat", "LinearAlgebra", "SparseArrays"]
git-tree-sha1 = "e30f2f4e20f7f186dc36529910beaedc60cfa644"
uuid = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
version = "1.16.0"

[[deps.ChangesOfVariables]]
deps = ["LinearAlgebra", "Test"]
git-tree-sha1 = "f84967c4497e0e1955f9a582c232b02847c5f589"
uuid = "9e997f8a-9a97-42d5-a9f1-ce6bfc15e2c0"
version = "0.1.7"

[[deps.CodecZlib]]
deps = ["TranscodingStreams", "Zlib_jll"]
git-tree-sha1 = "9c209fb7536406834aa938fb149964b985de6c83"
uuid = "944b1d66-785c-5afd-91f1-9de20f533193"
version = "0.7.1"

[[deps.ColorBrewer]]
deps = ["Colors", "JSON", "Test"]
git-tree-sha1 = "61c5334f33d91e570e1d0c3eb5465835242582c4"
uuid = "a2cac450-b92f-5266-8821-25eda20663c8"
version = "0.4.0"

[[deps.ColorSchemes]]
deps = ["ColorTypes", "ColorVectorSpace", "Colors", "FixedPointNumbers", "PrecompileTools", "Random"]
git-tree-sha1 = "be6ab11021cd29f0344d5c4357b163af05a48cba"
uuid = "35d6a980-a343-548e-a6ea-1d62b119f2f4"
version = "3.21.0"

[[deps.ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "eb7f0f8307f71fac7c606984ea5fb2817275d6e4"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.11.4"

[[deps.ColorVectorSpace]]
deps = ["ColorTypes", "FixedPointNumbers", "LinearAlgebra", "SpecialFunctions", "Statistics", "TensorCore"]
git-tree-sha1 = "600cc5508d66b78aae350f7accdb58763ac18589"
uuid = "c3611d14-8923-5661-9e6a-0046d554d3a4"
version = "0.9.10"

[[deps.Colors]]
deps = ["ColorTypes", "FixedPointNumbers", "Reexport"]
git-tree-sha1 = "fc08e5930ee9a4e03f84bfb5211cb54e7769758a"
uuid = "5ae59095-9a9b-59fe-a467-6f913c188581"
version = "0.12.10"

[[deps.Combinatorics]]
git-tree-sha1 = "08c8b6831dc00bfea825826be0bc8336fc369860"
uuid = "861a8166-3701-5b0c-9a16-15d98fcdc6aa"
version = "1.0.2"

[[deps.CommonSubexpressions]]
deps = ["MacroTools", "Test"]
git-tree-sha1 = "7b8a93dba8af7e3b42fecabf646260105ac373f7"
uuid = "bbf7d656-a473-5ed7-a52c-81e309532950"
version = "0.3.0"

[[deps.Compat]]
deps = ["Dates", "LinearAlgebra", "UUIDs"]
git-tree-sha1 = "7a60c856b9fa189eb34f5f8a6f6b5529b7942957"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "4.6.1"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
version = "0.5.2+0"

[[deps.Compose]]
deps = ["Base64", "Colors", "DataStructures", "Dates", "IterTools", "JSON", "LinearAlgebra", "Measures", "Printf", "Random", "Requires", "Statistics", "UUIDs"]
git-tree-sha1 = "bf6570a34c850f99407b494757f5d7ad233a7257"
uuid = "a81c6b42-2e10-5240-aca2-a61377ecd94b"
version = "0.9.5"

[[deps.CompositionsBase]]
git-tree-sha1 = "802bb88cd69dfd1509f6670416bd4434015693ad"
uuid = "a33af91c-f02d-484b-be07-31d278c5ca2b"
version = "0.1.2"

[[deps.ConcurrentUtilities]]
deps = ["Serialization", "Sockets"]
git-tree-sha1 = "96d823b94ba8d187a6d8f0826e731195a74b90e9"
uuid = "f0e56b4a-5159-44fe-b623-3e5288b988bb"
version = "2.2.0"

[[deps.Conda]]
deps = ["Downloads", "JSON", "VersionParsing"]
git-tree-sha1 = "e32a90da027ca45d84678b826fffd3110bb3fc90"
uuid = "8f4d0f93-b110-5947-807f-2305c1781a2d"
version = "1.8.0"

[[deps.ConstructionBase]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "738fec4d684a9a6ee9598a8bfee305b26831f28c"
uuid = "187b0558-2788-49d3-abe0-74a17ed4e7c9"
version = "1.5.2"

[[deps.ContextVariablesX]]
deps = ["Compat", "Logging", "UUIDs"]
git-tree-sha1 = "25cc3803f1030ab855e383129dcd3dc294e322cc"
uuid = "6add18c4-b38d-439d-96f6-d6bc489c04c5"
version = "0.1.3"

[[deps.Contour]]
git-tree-sha1 = "d05d9e7b7aedff4e5b51a029dced05cfb6125781"
uuid = "d38c429a-6771-53c6-b99e-75d170b6e991"
version = "0.6.2"

[[deps.Crayons]]
git-tree-sha1 = "249fe38abf76d48563e2f4556bebd215aa317e15"
uuid = "a8cc5b0e-0ffa-5ad4-8c14-923d3ee1735f"
version = "4.1.1"

[[deps.DataAPI]]
git-tree-sha1 = "e8119c1a33d267e16108be441a287a6981ba1630"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.14.0"

[[deps.DataFrames]]
deps = ["Compat", "DataAPI", "Future", "InlineStrings", "InvertedIndices", "IteratorInterfaceExtensions", "LinearAlgebra", "Markdown", "Missings", "PooledArrays", "PrettyTables", "Printf", "REPL", "Random", "Reexport", "SentinelArrays", "SnoopPrecompile", "SortingAlgorithms", "Statistics", "TableTraits", "Tables", "Unicode"]
git-tree-sha1 = "aa51303df86f8626a962fccb878430cdb0a97eee"
uuid = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
version = "1.5.0"

[[deps.DataStructures]]
deps = ["Compat", "InteractiveUtils", "OrderedCollections"]
git-tree-sha1 = "d1fff3a548102f48987a52a2e0d114fa97d730f0"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.18.13"

[[deps.DataValueInterfaces]]
git-tree-sha1 = "bfc1187b79289637fa0ef6d4436ebdfe6905cbd6"
uuid = "e2d170a0-9d28-54be-80f0-106bbe20a464"
version = "1.0.0"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[deps.DefineSingletons]]
git-tree-sha1 = "0fba8b706d0178b4dc7fd44a96a92382c9065c2c"
uuid = "244e2a9f-e319-4986-a169-4d1fe445cd52"
version = "0.1.2"

[[deps.DelimitedFiles]]
deps = ["Mmap"]
uuid = "8bb1440f-4735-579b-a4ab-409b98df4dab"

[[deps.DensityInterface]]
deps = ["InverseFunctions", "Test"]
git-tree-sha1 = "80c3e8639e3353e5d2912fb3a1916b8455e2494b"
uuid = "b429d917-457f-4dbc-8f4c-0cc954292b1d"
version = "0.4.0"

[[deps.DiffResults]]
deps = ["StaticArraysCore"]
git-tree-sha1 = "782dd5f4561f5d267313f23853baaaa4c52ea621"
uuid = "163ba53b-c6d8-5494-b064-1a9d43ac40c5"
version = "1.1.0"

[[deps.DiffRules]]
deps = ["IrrationalConstants", "LogExpFunctions", "NaNMath", "Random", "SpecialFunctions"]
git-tree-sha1 = "a4ad7ef19d2cdc2eff57abbbe68032b1cd0bd8f8"
uuid = "b552c78f-8df3-52c6-915a-8e097449b14b"
version = "1.13.0"

[[deps.Distributed]]
deps = ["Random", "Serialization", "Sockets"]
uuid = "8ba89e20-285c-5b6f-9357-94700520ee1b"

[[deps.Distributions]]
deps = ["ChainRulesCore", "DensityInterface", "FillArrays", "LinearAlgebra", "PDMats", "Printf", "QuadGK", "Random", "SparseArrays", "SpecialFunctions", "Statistics", "StatsAPI", "StatsBase", "StatsFuns", "Test"]
git-tree-sha1 = "eead66061583b6807652281c0fbf291d7a9dc497"
uuid = "31c24e10-a181-5473-b8eb-7969acd0382f"
version = "0.25.90"

[[deps.DocStringExtensions]]
deps = ["LibGit2"]
git-tree-sha1 = "2fb1e02f2b635d0845df5d7c167fec4dd739b00d"
uuid = "ffbed154-4ef7-542d-bbb7-c09d3a79fcae"
version = "0.9.3"

[[deps.Downloads]]
deps = ["ArgTools", "FileWatching", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"
version = "1.6.0"

[[deps.DualNumbers]]
deps = ["Calculus", "NaNMath", "SpecialFunctions"]
git-tree-sha1 = "5837a837389fccf076445fce071c8ddaea35a566"
uuid = "fa6b7ba4-c1ee-5f82-b5fc-ecf0adba8f74"
version = "0.6.8"

[[deps.EarCut_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "e3290f2d49e661fbd94046d7e3726ffcb2d41053"
uuid = "5ae413db-bbd1-5e63-b57d-d24a61df00f5"
version = "2.2.4+0"

[[deps.Expat_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "bad72f730e9e91c08d9427d5e8db95478a3c323d"
uuid = "2e619515-83b5-522b-bb60-26c02a35a201"
version = "2.4.8+0"

[[deps.ExprTools]]
git-tree-sha1 = "c1d06d129da9f55715c6c212866f5b1bddc5fa00"
uuid = "e2ba6199-217a-4e67-a87a-7c52f15ade04"
version = "0.1.9"

[[deps.Extents]]
git-tree-sha1 = "5e1e4c53fa39afe63a7d356e30452249365fba99"
uuid = "411431e0-e8b7-467b-b5e0-f676ba4f2910"
version = "0.1.1"

[[deps.FFMPEG]]
deps = ["FFMPEG_jll"]
git-tree-sha1 = "b57e3acbe22f8484b4b5ff66a7499717fe1a9cc8"
uuid = "c87230d0-a227-11e9-1b43-d7ebe4e7570a"
version = "0.4.1"

[[deps.FFMPEG_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "JLLWrappers", "LAME_jll", "Libdl", "Ogg_jll", "OpenSSL_jll", "Opus_jll", "PCRE2_jll", "Pkg", "Zlib_jll", "libaom_jll", "libass_jll", "libfdk_aac_jll", "libvorbis_jll", "x264_jll", "x265_jll"]
git-tree-sha1 = "74faea50c1d007c85837327f6775bea60b5492dd"
uuid = "b22a6f82-2f65-5046-a5b2-351ab43fb4e5"
version = "4.4.2+2"

[[deps.FFTW]]
deps = ["AbstractFFTs", "FFTW_jll", "LinearAlgebra", "MKL_jll", "Preferences", "Reexport"]
git-tree-sha1 = "f9818144ce7c8c41edf5c4c179c684d92aa4d9fe"
uuid = "7a1cc6ca-52ef-59f5-83cd-3a7055c09341"
version = "1.6.0"

[[deps.FFTW_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "c6033cc3892d0ef5bb9cd29b7f2f0331ea5184ea"
uuid = "f5851436-0d7a-5f13-b9de-f02708fd171a"
version = "3.3.10+0"

[[deps.FLoops]]
deps = ["BangBang", "Compat", "FLoopsBase", "InitialValues", "JuliaVariables", "MLStyle", "Serialization", "Setfield", "Transducers"]
git-tree-sha1 = "ffb97765602e3cbe59a0589d237bf07f245a8576"
uuid = "cc61a311-1640-44b5-9fba-1b764f453329"
version = "0.2.1"

[[deps.FLoopsBase]]
deps = ["ContextVariablesX"]
git-tree-sha1 = "656f7a6859be8673bf1f35da5670246b923964f7"
uuid = "b9860ae5-e623-471e-878b-f6a53c775ea6"
version = "0.1.1"

[[deps.FileIO]]
deps = ["Pkg", "Requires", "UUIDs"]
git-tree-sha1 = "299dc33549f68299137e51e6d49a13b5b1da9673"
uuid = "5789e2e9-d7fb-5bc7-8068-2c6fae9b9549"
version = "1.16.1"

[[deps.FilePathsBase]]
deps = ["Compat", "Dates", "Mmap", "Printf", "Test", "UUIDs"]
git-tree-sha1 = "e27c4ebe80e8699540f2d6c805cc12203b614f12"
uuid = "48062228-2e41-5def-b9a4-89aafe57970f"
version = "0.9.20"

[[deps.FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"

[[deps.FillArrays]]
deps = ["LinearAlgebra", "Random", "SparseArrays", "Statistics"]
git-tree-sha1 = "fc86b4fd3eff76c3ce4f5e96e2fdfa6282722885"
uuid = "1a297f60-69ca-5386-bcde-b61e274b549b"
version = "1.0.0"

[[deps.FixedPointNumbers]]
deps = ["Statistics"]
git-tree-sha1 = "335bfdceacc84c5cdf16aadc768aa5ddfc5383cc"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.4"

[[deps.Flux]]
deps = ["Adapt", "CUDA", "ChainRulesCore", "Functors", "LinearAlgebra", "MLUtils", "MacroTools", "NNlib", "NNlibCUDA", "OneHotArrays", "Optimisers", "Preferences", "ProgressLogging", "Random", "Reexport", "SparseArrays", "SpecialFunctions", "Statistics", "Zygote", "cuDNN"]
git-tree-sha1 = "64005071944bae14fc145661f617eb68b339189c"
uuid = "587475ba-b771-5e3f-ad9e-33799f191a9c"
version = "0.13.16"

[[deps.FoldsThreads]]
deps = ["Accessors", "FunctionWrappers", "InitialValues", "SplittablesBase", "Transducers"]
git-tree-sha1 = "eb8e1989b9028f7e0985b4268dabe94682249025"
uuid = "9c68100b-dfe1-47cf-94c8-95104e173443"
version = "0.1.1"

[[deps.Fontconfig_jll]]
deps = ["Artifacts", "Bzip2_jll", "Expat_jll", "FreeType2_jll", "JLLWrappers", "Libdl", "Libuuid_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "21efd19106a55620a188615da6d3d06cd7f6ee03"
uuid = "a3f928ae-7b40-5064-980b-68af3947d34b"
version = "2.13.93+0"

[[deps.Formatting]]
deps = ["Printf"]
git-tree-sha1 = "8339d61043228fdd3eb658d86c926cb282ae72a8"
uuid = "59287772-0a20-5a39-b81b-1366585eb4c0"
version = "0.4.2"

[[deps.ForwardDiff]]
deps = ["CommonSubexpressions", "DiffResults", "DiffRules", "LinearAlgebra", "LogExpFunctions", "NaNMath", "Preferences", "Printf", "Random", "SpecialFunctions", "StaticArrays"]
git-tree-sha1 = "00e252f4d706b3d55a8863432e742bf5717b498d"
uuid = "f6369f11-7733-5829-9624-2563aa707210"
version = "0.10.35"

[[deps.FreeType]]
deps = ["CEnum", "FreeType2_jll"]
git-tree-sha1 = "cabd77ab6a6fdff49bfd24af2ebe76e6e018a2b4"
uuid = "b38be410-82b0-50bf-ab77-7b57e271db43"
version = "4.0.0"

[[deps.FreeType2_jll]]
deps = ["Artifacts", "Bzip2_jll", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "87eb71354d8ec1a96d4a7636bd57a7347dde3ef9"
uuid = "d7e528f0-a631-5988-bf34-fe36492bcfd7"
version = "2.10.4+0"

[[deps.FreeTypeAbstraction]]
deps = ["ColorVectorSpace", "Colors", "FreeType", "GeometryBasics"]
git-tree-sha1 = "38a92e40157100e796690421e34a11c107205c86"
uuid = "663a7486-cb36-511b-a19d-713bb74d65c9"
version = "0.10.0"

[[deps.FriBidi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "aa31987c2ba8704e23c6c8ba8a4f769d5d7e4f91"
uuid = "559328eb-81f9-559d-9380-de523a88c83c"
version = "1.0.10+0"

[[deps.FunctionWrappers]]
git-tree-sha1 = "d62485945ce5ae9c0c48f124a84998d755bae00e"
uuid = "069b7b12-0de2-55c6-9aab-29f3d0a68a2e"
version = "1.1.3"

[[deps.Functors]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "478f8c3145bb91d82c2cf20433e8c1b30df454cc"
uuid = "d9f16b24-f501-4c13-a1f2-28368ffc5196"
version = "0.4.4"

[[deps.Future]]
deps = ["Random"]
uuid = "9fa8497b-333b-5362-9e8d-4d0656e87820"

[[deps.GLFW_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libglvnd_jll", "Pkg", "Xorg_libXcursor_jll", "Xorg_libXi_jll", "Xorg_libXinerama_jll", "Xorg_libXrandr_jll"]
git-tree-sha1 = "d972031d28c8c8d9d7b41a536ad7bb0c2579caca"
uuid = "0656b61e-2033-5cc2-a64a-77c0f6c09b89"
version = "3.3.8+0"

[[deps.GPUArrays]]
deps = ["Adapt", "GPUArraysCore", "LLVM", "LinearAlgebra", "Printf", "Random", "Reexport", "Serialization", "Statistics"]
git-tree-sha1 = "9ade6983c3dbbd492cf5729f865fe030d1541463"
uuid = "0c68f7d7-f131-5f86-a1c3-88cf8149b2d7"
version = "8.6.6"

[[deps.GPUArraysCore]]
deps = ["Adapt"]
git-tree-sha1 = "1cd7f0af1aa58abc02ea1d872953a97359cb87fa"
uuid = "46192b85-c4d5-4398-a991-12ede77f4527"
version = "0.1.4"

[[deps.GPUCompiler]]
deps = ["ExprTools", "InteractiveUtils", "LLVM", "Libdl", "Logging", "Scratch", "TimerOutputs", "UUIDs"]
git-tree-sha1 = "e9a9173cd77e16509cdf9c1663fda19b22a518b7"
uuid = "61eb1bfa-7361-4325-ad38-22787b887f55"
version = "0.19.3"

[[deps.GR]]
deps = ["Artifacts", "Base64", "DelimitedFiles", "Downloads", "GR_jll", "HTTP", "JSON", "Libdl", "LinearAlgebra", "Pkg", "Preferences", "Printf", "Random", "Serialization", "Sockets", "TOML", "Tar", "Test", "UUIDs", "p7zip_jll"]
git-tree-sha1 = "efaac003187ccc71ace6c755b197284cd4811bfe"
uuid = "28b8d3ca-fb5f-59d9-8090-bfdbd6d07a71"
version = "0.72.4"

[[deps.GR_jll]]
deps = ["Artifacts", "Bzip2_jll", "Cairo_jll", "FFMPEG_jll", "Fontconfig_jll", "GLFW_jll", "JLLWrappers", "JpegTurbo_jll", "Libdl", "Libtiff_jll", "Pixman_jll", "Qt5Base_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "4486ff47de4c18cb511a0da420efebb314556316"
uuid = "d2c73de3-f751-5644-a686-071e5b155ba9"
version = "0.72.4+0"

[[deps.GeoInterface]]
deps = ["Extents"]
git-tree-sha1 = "bb198ff907228523f3dee1070ceee63b9359b6ab"
uuid = "cf35fbd7-0cd7-5166-be24-54bfbe79505f"
version = "1.3.1"

[[deps.GeometryBasics]]
deps = ["EarCut_jll", "GeoInterface", "IterTools", "LinearAlgebra", "StaticArrays", "StructArrays", "Tables"]
git-tree-sha1 = "659140c9375afa2f685e37c1a0b9c9a60ef56b40"
uuid = "5c1252a2-5f33-56bf-86c9-59e7332b4326"
version = "0.4.7"

[[deps.Gettext_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Libiconv_jll", "Pkg", "XML2_jll"]
git-tree-sha1 = "9b02998aba7bf074d14de89f9d37ca24a1a0b046"
uuid = "78b55507-aeef-58d4-861c-77aaff3498b1"
version = "0.21.0+0"

[[deps.Glib_jll]]
deps = ["Artifacts", "Gettext_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Libiconv_jll", "Libmount_jll", "PCRE2_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "d3b3624125c1474292d0d8ed0f65554ac37ddb23"
uuid = "7746bdde-850d-59dc-9ae8-88ece973131d"
version = "2.74.0+2"

[[deps.GraphMakie]]
deps = ["GeometryBasics", "Graphs", "LinearAlgebra", "Makie", "NetworkLayout", "PolynomialRoots", "StaticArrays"]
git-tree-sha1 = "72882a1584f367cfecc83e3e8a232c7720c262cd"
uuid = "1ecd5474-83a3-4783-bb4f-06765db800d2"
version = "0.5.3"

[[deps.GraphPlot]]
deps = ["ArnoldiMethod", "ColorTypes", "Colors", "Compose", "DelimitedFiles", "Graphs", "LinearAlgebra", "Random", "SparseArrays"]
git-tree-sha1 = "5cd479730a0cb01f880eff119e9803c13f214cab"
uuid = "a2cc645c-3eea-5389-862e-a155d0052231"
version = "0.5.2"

[[deps.Graphics]]
deps = ["Colors", "LinearAlgebra", "NaNMath"]
git-tree-sha1 = "d61890399bc535850c4bf08e4e0d3a7ad0f21cbd"
uuid = "a2bd30eb-e257-5431-a919-1863eab51364"
version = "1.1.2"

[[deps.Graphite2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "344bf40dcab1073aca04aa0df4fb092f920e4011"
uuid = "3b182d85-2403-5c21-9c21-1e1f0cc25472"
version = "1.3.14+0"

[[deps.Graphs]]
deps = ["ArnoldiMethod", "Compat", "DataStructures", "Distributed", "Inflate", "LinearAlgebra", "Random", "SharedArrays", "SimpleTraits", "SparseArrays", "Statistics"]
git-tree-sha1 = "1cf1d7dcb4bc32d7b4a5add4232db3750c27ecb4"
uuid = "86223c79-3864-5bf0-83f7-82e725a168b6"
version = "1.8.0"

[[deps.GridLayoutBase]]
deps = ["GeometryBasics", "InteractiveUtils", "Observables"]
git-tree-sha1 = "678d136003ed5bceaab05cf64519e3f956ffa4ba"
uuid = "3955a311-db13-416c-9275-1d80ed98e5e9"
version = "0.9.1"

[[deps.Grisu]]
git-tree-sha1 = "53bb909d1151e57e2484c3d1b53e19552b887fb2"
uuid = "42e2da0e-8278-4e71-bc24-59509adca0fe"
version = "1.0.2"

[[deps.HTTP]]
deps = ["Base64", "CodecZlib", "ConcurrentUtilities", "Dates", "Logging", "LoggingExtras", "MbedTLS", "NetworkOptions", "OpenSSL", "Random", "SimpleBufferStream", "Sockets", "URIs", "UUIDs"]
git-tree-sha1 = "877b7bc42729aa2c90bbbf5cb0d4294bd6d42e5a"
uuid = "cd3eb016-35fb-5094-929b-558a96fad6f3"
version = "1.9.1"

[[deps.HarfBuzz_jll]]
deps = ["Artifacts", "Cairo_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "Graphite2_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Pkg"]
git-tree-sha1 = "129acf094d168394e80ee1dc4bc06ec835e510a3"
uuid = "2e76f6c2-a576-52d4-95c1-20adfe4de566"
version = "2.8.1+1"

[[deps.HypergeometricFunctions]]
deps = ["DualNumbers", "LinearAlgebra", "OpenLibm_jll", "SpecialFunctions"]
git-tree-sha1 = "84204eae2dd237500835990bcade263e27674a93"
uuid = "34004b35-14d8-5ef3-9330-4cdb6864b03a"
version = "0.3.16"

[[deps.Hyperscript]]
deps = ["Test"]
git-tree-sha1 = "8d511d5b81240fc8e6802386302675bdf47737b9"
uuid = "47d2ed2b-36de-50cf-bf87-49c2cf4b8b91"
version = "0.0.4"

[[deps.HypertextLiteral]]
deps = ["Tricks"]
git-tree-sha1 = "c47c5fa4c5308f27ccaac35504858d8914e102f9"
uuid = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
version = "0.9.4"

[[deps.IOCapture]]
deps = ["Logging", "Random"]
git-tree-sha1 = "f7be53659ab06ddc986428d3a9dcc95f6fa6705a"
uuid = "b5f81e59-6552-4d32-b1f0-c071b021bf89"
version = "0.2.2"

[[deps.IRTools]]
deps = ["InteractiveUtils", "MacroTools", "Test"]
git-tree-sha1 = "eac00994ce3229a464c2847e956d77a2c64ad3a5"
uuid = "7869d1d1-7146-5819-86e3-90919afe41df"
version = "0.4.10"

[[deps.ImageAxes]]
deps = ["AxisArrays", "ImageBase", "ImageCore", "Reexport", "SimpleTraits"]
git-tree-sha1 = "c54b581a83008dc7f292e205f4c409ab5caa0f04"
uuid = "2803e5a7-5153-5ecf-9a86-9b4c37f5f5ac"
version = "0.6.10"

[[deps.ImageBase]]
deps = ["ImageCore", "Reexport"]
git-tree-sha1 = "b51bb8cae22c66d0f6357e3bcb6363145ef20835"
uuid = "c817782e-172a-44cc-b673-b171935fbb9e"
version = "0.1.5"

[[deps.ImageCore]]
deps = ["AbstractFFTs", "ColorVectorSpace", "Colors", "FixedPointNumbers", "Graphics", "MappedArrays", "MosaicViews", "OffsetArrays", "PaddedViews", "Reexport"]
git-tree-sha1 = "acf614720ef026d38400b3817614c45882d75500"
uuid = "a09fc81d-aa75-5fe9-8630-4744c3626534"
version = "0.9.4"

[[deps.ImageIO]]
deps = ["FileIO", "IndirectArrays", "JpegTurbo", "LazyModules", "Netpbm", "OpenEXR", "PNGFiles", "QOI", "Sixel", "TiffImages", "UUIDs"]
git-tree-sha1 = "342f789fd041a55166764c351da1710db97ce0e0"
uuid = "82e4d734-157c-48bb-816b-45c225c6df19"
version = "0.6.6"

[[deps.ImageMetadata]]
deps = ["AxisArrays", "ImageAxes", "ImageBase", "ImageCore"]
git-tree-sha1 = "36cbaebed194b292590cba2593da27b34763804a"
uuid = "bc367c6b-8a6b-528e-b4bd-a4b897500b49"
version = "0.9.8"

[[deps.Imath_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "3d09a9f60edf77f8a4d99f9e015e8fbf9989605d"
uuid = "905a6f67-0a94-5f89-b386-d35d92009cd1"
version = "3.1.7+0"

[[deps.IndirectArrays]]
git-tree-sha1 = "012e604e1c7458645cb8b436f8fba789a51b257f"
uuid = "9b13fd28-a010-5f03-acff-a1bbcff69959"
version = "1.0.0"

[[deps.Inflate]]
git-tree-sha1 = "5cd07aab533df5170988219191dfad0519391428"
uuid = "d25df0c9-e2be-5dd7-82c8-3ad0b3e990b9"
version = "0.1.3"

[[deps.InitialValues]]
git-tree-sha1 = "4da0f88e9a39111c2fa3add390ab15f3a44f3ca3"
uuid = "22cec73e-a1b8-11e9-2c92-598750a2cf9c"
version = "0.3.1"

[[deps.InlineStrings]]
deps = ["Parsers"]
git-tree-sha1 = "9cc2baf75c6d09f9da536ddf58eb2f29dedaf461"
uuid = "842dd82b-1e85-43dc-bf29-5d0ee9dffc48"
version = "1.4.0"

[[deps.IntelOpenMP_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "0cb9352ef2e01574eeebdb102948a58740dcaf83"
uuid = "1d5cc7b8-4909-519e-a0f8-d0f5ad9712d0"
version = "2023.1.0+0"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[deps.Interpolations]]
deps = ["Adapt", "AxisAlgorithms", "ChainRulesCore", "LinearAlgebra", "OffsetArrays", "Random", "Ratios", "Requires", "SharedArrays", "SparseArrays", "StaticArrays", "WoodburyMatrices"]
git-tree-sha1 = "721ec2cf720536ad005cb38f50dbba7b02419a15"
uuid = "a98d9a8b-a2ab-59e6-89dd-64a1c18fca59"
version = "0.14.7"

[[deps.IntervalSets]]
deps = ["Dates", "Random", "Statistics"]
git-tree-sha1 = "16c0cc91853084cb5f58a78bd209513900206ce6"
uuid = "8197267c-284f-5f27-9208-e0e47529a953"
version = "0.7.4"

[[deps.InverseFunctions]]
deps = ["Test"]
git-tree-sha1 = "6667aadd1cdee2c6cd068128b3d226ebc4fb0c67"
uuid = "3587e190-3f89-42d0-90ee-14403ec27112"
version = "0.1.9"

[[deps.InvertedIndices]]
git-tree-sha1 = "0dc7b50b8d436461be01300fd8cd45aa0274b038"
uuid = "41ab1584-1d38-5bbf-9106-f11c6c58b48f"
version = "1.3.0"

[[deps.IrrationalConstants]]
git-tree-sha1 = "630b497eafcc20001bba38a4651b327dcfc491d2"
uuid = "92d709cd-6900-40b7-9082-c6be49f344b6"
version = "0.2.2"

[[deps.Isoband]]
deps = ["isoband_jll"]
git-tree-sha1 = "f9b6d97355599074dc867318950adaa6f9946137"
uuid = "f1662d9f-8043-43de-a69a-05efc1cc6ff4"
version = "0.1.1"

[[deps.IterTools]]
git-tree-sha1 = "fa6287a4469f5e048d763df38279ee729fbd44e5"
uuid = "c8e1da08-722c-5040-9ed9-7db0dc04731e"
version = "1.4.0"

[[deps.IteratorInterfaceExtensions]]
git-tree-sha1 = "a3f24677c21f5bbe9d2a714f95dcd58337fb2856"
uuid = "82899510-4779-5014-852e-03e436cf321d"
version = "1.0.0"

[[deps.JLD2]]
deps = ["FileIO", "MacroTools", "Mmap", "OrderedCollections", "Pkg", "Printf", "Reexport", "Requires", "TranscodingStreams", "UUIDs"]
git-tree-sha1 = "42c17b18ced77ff0be65957a591d34f4ed57c631"
uuid = "033835bb-8acc-5ee8-8aae-3f567f8a3819"
version = "0.4.31"

[[deps.JLFzf]]
deps = ["Pipe", "REPL", "Random", "fzf_jll"]
git-tree-sha1 = "f377670cda23b6b7c1c0b3893e37451c5c1a2185"
uuid = "1019f520-868f-41f5-a6de-eb00f4b6a39c"
version = "0.1.5"

[[deps.JLLWrappers]]
deps = ["Preferences"]
git-tree-sha1 = "abc9885a7ca2052a736a600f7fa66209f96506e1"
uuid = "692b3bcd-3c85-4b1f-b108-f13ce0eb3210"
version = "1.4.1"

[[deps.JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "31e996f0a15c7b280ba9f76636b3ff9e2ae58c9a"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.4"

[[deps.JpegTurbo]]
deps = ["CEnum", "FileIO", "ImageCore", "JpegTurbo_jll", "TOML"]
git-tree-sha1 = "106b6aa272f294ba47e96bd3acbabdc0407b5c60"
uuid = "b835a17e-a41a-41e7-81f0-2f016b05efe0"
version = "0.1.2"

[[deps.JpegTurbo_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "6f2675ef130a300a112286de91973805fcc5ffbc"
uuid = "aacddb02-875f-59d6-b918-886e6ef4fbf8"
version = "2.1.91+0"

[[deps.JuliaVariables]]
deps = ["MLStyle", "NameResolution"]
git-tree-sha1 = "49fb3cb53362ddadb4415e9b73926d6b40709e70"
uuid = "b14d175d-62b4-44ba-8fb7-3064adc8c3ec"
version = "0.2.4"

[[deps.KernelAbstractions]]
deps = ["Adapt", "Atomix", "InteractiveUtils", "LinearAlgebra", "MacroTools", "PrecompileTools", "SparseArrays", "StaticArrays", "UUIDs", "UnsafeAtomics", "UnsafeAtomicsLLVM"]
git-tree-sha1 = "47be64f040a7ece575c2b5f53ca6da7b548d69f4"
uuid = "63c18a36-062a-441e-b654-da1e3ab1ce7c"
version = "0.9.4"

[[deps.KernelDensity]]
deps = ["Distributions", "DocStringExtensions", "FFTW", "Interpolations", "StatsBase"]
git-tree-sha1 = "90442c50e202a5cdf21a7899c66b240fdef14035"
uuid = "5ab0869b-81aa-558d-bb23-cbf5423bbe9b"
version = "0.6.7"

[[deps.LAME_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "f6250b16881adf048549549fba48b1161acdac8c"
uuid = "c1c5ebd0-6772-5130-a774-d5fcae4a789d"
version = "3.100.1+0"

[[deps.LERC_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "bf36f528eec6634efc60d7ec062008f171071434"
uuid = "88015f11-f218-50d7-93a8-a6af411a945d"
version = "3.0.0+1"

[[deps.LLVM]]
deps = ["CEnum", "LLVMExtra_jll", "Libdl", "Printf", "Unicode"]
git-tree-sha1 = "26a31cdd9f1f4ea74f649a7bf249703c687a953d"
uuid = "929cbde3-209d-540e-8aea-75f648917ca0"
version = "5.1.0"

[[deps.LLVMExtra_jll]]
deps = ["Artifacts", "JLLWrappers", "LazyArtifacts", "Libdl", "TOML"]
git-tree-sha1 = "09b7505cc0b1cee87e5d4a26eea61d2e1b0dcd35"
uuid = "dad2f222-ce93-54a1-a47d-0025e8a3acab"
version = "0.0.21+0"

[[deps.LZO_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "e5b909bcf985c5e2605737d2ce278ed791b89be6"
uuid = "dd4b983a-f0e5-5f8d-a1b7-129d4a5fb1ac"
version = "2.10.1+0"

[[deps.LaTeXStrings]]
git-tree-sha1 = "f2355693d6778a178ade15952b7ac47a4ff97996"
uuid = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
version = "1.3.0"

[[deps.Latexify]]
deps = ["Formatting", "InteractiveUtils", "LaTeXStrings", "MacroTools", "Markdown", "OrderedCollections", "Printf", "Requires"]
git-tree-sha1 = "099e356f267354f46ba65087981a77da23a279b7"
uuid = "23fbe1c1-3f47-55db-b15f-69d7ec21a316"
version = "0.16.0"

[[deps.LazyArtifacts]]
deps = ["Artifacts", "Pkg"]
uuid = "4af54fe1-eca0-43a8-85a7-787d91b784e3"

[[deps.LazyJSON]]
deps = ["JSON", "OrderedCollections", "PropertyDicts"]
git-tree-sha1 = "ce08411caa70e0c9e780f142f59debd89a971738"
uuid = "fc18253b-5e1b-504c-a4a2-9ece4944c004"
version = "0.2.2"

[[deps.LazyModules]]
git-tree-sha1 = "a560dd966b386ac9ae60bdd3a3d3a326062d3c3e"
uuid = "8cdb02fc-e678-4876-92c5-9defec4f444e"
version = "0.3.1"

[[deps.LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"
version = "0.6.3"

[[deps.LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"
version = "7.84.0+0"

[[deps.LibGit2]]
deps = ["Base64", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"
version = "1.10.2+0"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

[[deps.Libffi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "0b4a5d71f3e5200a7dff793393e09dfc2d874290"
uuid = "e9f186c6-92d2-5b65-8a66-fee21dc1b490"
version = "3.2.2+1"

[[deps.Libgcrypt_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libgpg_error_jll", "Pkg"]
git-tree-sha1 = "64613c82a59c120435c067c2b809fc61cf5166ae"
uuid = "d4300ac3-e22c-5743-9152-c294e39db1e4"
version = "1.8.7+0"

[[deps.Libglvnd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll", "Xorg_libXext_jll"]
git-tree-sha1 = "6f73d1dd803986947b2c750138528a999a6c7733"
uuid = "7e76a0d4-f3c7-5321-8279-8d96eeed0f29"
version = "1.6.0+0"

[[deps.Libgpg_error_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "c333716e46366857753e273ce6a69ee0945a6db9"
uuid = "7add5ba3-2f88-524e-9cd5-f83b8a55f7b8"
version = "1.42.0+0"

[[deps.Libiconv_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "c7cb1f5d892775ba13767a87c7ada0b980ea0a71"
uuid = "94ce4f54-9a6c-5748-9c1c-f9c7231a4531"
version = "1.16.1+2"

[[deps.Libmount_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "9c30530bf0effd46e15e0fdcf2b8636e78cbbd73"
uuid = "4b2f31a3-9ecc-558c-b454-b3730dcb73e9"
version = "2.35.0+0"

[[deps.Libtiff_jll]]
deps = ["Artifacts", "JLLWrappers", "JpegTurbo_jll", "LERC_jll", "Libdl", "Pkg", "Zlib_jll", "Zstd_jll"]
git-tree-sha1 = "3eb79b0ca5764d4799c06699573fd8f533259713"
uuid = "89763e89-9b03-5906-acba-b20f662cd828"
version = "4.4.0+0"

[[deps.Libuuid_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "7f3efec06033682db852f8b3bc3c1d2b0a0ab066"
uuid = "38a345b3-de98-5d2b-a5d3-14cd9215e700"
version = "2.36.0+0"

[[deps.LinearAlgebra]]
deps = ["Libdl", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[deps.LogExpFunctions]]
deps = ["ChainRulesCore", "ChangesOfVariables", "DocStringExtensions", "InverseFunctions", "IrrationalConstants", "LinearAlgebra"]
git-tree-sha1 = "0a1b7c2863e44523180fdb3146534e265a91870b"
uuid = "2ab3a3ac-af41-5b50-aa03-7779005ae688"
version = "0.3.23"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[deps.LoggingExtras]]
deps = ["Dates", "Logging"]
git-tree-sha1 = "cedb76b37bc5a6c702ade66be44f831fa23c681e"
uuid = "e6f89c97-d47a-5376-807f-9c37f3926c36"
version = "1.0.0"

[[deps.MIMEs]]
git-tree-sha1 = "65f28ad4b594aebe22157d6fac869786a255b7eb"
uuid = "6c6e2e6c-3030-632d-7369-2d6c69616d65"
version = "0.1.4"

[[deps.MKL_jll]]
deps = ["Artifacts", "IntelOpenMP_jll", "JLLWrappers", "LazyArtifacts", "Libdl", "Pkg"]
git-tree-sha1 = "2ce8695e1e699b68702c03402672a69f54b8aca9"
uuid = "856f044c-d86e-5d09-b602-aeab76dc8ba7"
version = "2022.2.0+0"

[[deps.MLStyle]]
git-tree-sha1 = "bc38dff0548128765760c79eb7388a4b37fae2c8"
uuid = "d8e11817-5142-5d16-987a-aa16d5891078"
version = "0.4.17"

[[deps.MLUtils]]
deps = ["ChainRulesCore", "Compat", "DataAPI", "DelimitedFiles", "FLoops", "FoldsThreads", "NNlib", "Random", "ShowCases", "SimpleTraits", "Statistics", "StatsBase", "Tables", "Transducers"]
git-tree-sha1 = "ca31739905ddb08c59758726e22b9e25d0d1521b"
uuid = "f1d291b0-491e-4a28-83b9-f70985020b54"
version = "0.4.2"

[[deps.MacroTools]]
deps = ["Markdown", "Random"]
git-tree-sha1 = "42324d08725e200c23d4dfb549e0d5d89dede2d2"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.10"

[[deps.Makie]]
deps = ["Animations", "Base64", "ColorBrewer", "ColorSchemes", "ColorTypes", "Colors", "Contour", "Distributions", "DocStringExtensions", "Downloads", "FFMPEG", "FileIO", "FixedPointNumbers", "Formatting", "FreeType", "FreeTypeAbstraction", "GeometryBasics", "GridLayoutBase", "ImageIO", "InteractiveUtils", "IntervalSets", "Isoband", "KernelDensity", "LaTeXStrings", "LinearAlgebra", "MakieCore", "Markdown", "Match", "MathTeXEngine", "MiniQhull", "Observables", "OffsetArrays", "Packing", "PlotUtils", "PolygonOps", "Printf", "Random", "RelocatableFolders", "Setfield", "Showoff", "SignedDistanceFields", "SnoopPrecompile", "SparseArrays", "StableHashTraits", "Statistics", "StatsBase", "StatsFuns", "StructArrays", "TriplotBase", "UnicodeFun"]
git-tree-sha1 = "74657542dc85c3b72b8a5a9392d57713d8b7a999"
uuid = "ee78f7c6-11fb-53f2-987a-cfe4a2b5a57a"
version = "0.19.4"

[[deps.MakieCore]]
deps = ["Observables"]
git-tree-sha1 = "9926529455a331ed73c19ff06d16906737a876ed"
uuid = "20f20a25-4f0e-4fdf-b5d1-57303727442b"
version = "0.6.3"

[[deps.MappedArrays]]
git-tree-sha1 = "e8b359ef06ec72e8c030463fe02efe5527ee5142"
uuid = "dbb5928d-eab1-5f90-85c2-b9b0edb7c900"
version = "0.4.1"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[deps.Match]]
git-tree-sha1 = "1d9bc5c1a6e7ee24effb93f175c9342f9154d97f"
uuid = "7eb4fadd-790c-5f42-8a69-bfa0b872bfbf"
version = "1.2.0"

[[deps.MathTeXEngine]]
deps = ["AbstractTrees", "Automa", "DataStructures", "FreeTypeAbstraction", "GeometryBasics", "LaTeXStrings", "REPL", "RelocatableFolders", "Test", "UnicodeFun"]
git-tree-sha1 = "8f52dbaa1351ce4cb847d95568cb29e62a307d93"
uuid = "0a4f8689-d25c-4efe-a92b-7142dfc1aa53"
version = "0.5.6"

[[deps.MbedTLS]]
deps = ["Dates", "MbedTLS_jll", "MozillaCACerts_jll", "Random", "Sockets"]
git-tree-sha1 = "03a9b9718f5682ecb107ac9f7308991db4ce395b"
uuid = "739be429-bea8-5141-9913-cc70e7f3736d"
version = "1.1.7"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"
version = "2.28.0+0"

[[deps.Measures]]
git-tree-sha1 = "c13304c81eec1ed3af7fc20e75fb6b26092a1102"
uuid = "442fdcdd-2543-5da2-b0f3-8c86c306513e"
version = "0.3.2"

[[deps.Memoization]]
deps = ["MacroTools"]
git-tree-sha1 = "2f6913923a0cb8046134f5cbf8b4d7ba3c856a1d"
uuid = "6fafb56a-5788-4b4e-91ca-c0cea6611c73"
version = "0.2.0"

[[deps.MetaGraphs]]
deps = ["Graphs", "JLD2", "Random"]
git-tree-sha1 = "1130dbe1d5276cb656f6e1094ce97466ed700e5a"
uuid = "626554b9-1ddb-594c-aa3c-2596fe9399a5"
version = "0.7.2"

[[deps.MicroCollections]]
deps = ["BangBang", "InitialValues", "Setfield"]
git-tree-sha1 = "629afd7d10dbc6935ec59b32daeb33bc4460a42e"
uuid = "128add7d-3638-4c79-886c-908ea0c25c34"
version = "0.1.4"

[[deps.MiniQhull]]
deps = ["QhullMiniWrapper_jll"]
git-tree-sha1 = "9dc837d180ee49eeb7c8b77bb1c860452634b0d1"
uuid = "978d7f02-9e05-4691-894f-ae31a51d76ca"
version = "0.4.0"

[[deps.Missings]]
deps = ["DataAPI"]
git-tree-sha1 = "f66bdc5de519e8f8ae43bdc598782d35a25b1272"
uuid = "e1d29d7a-bbdc-5cf2-9ac0-f12de2c33e28"
version = "1.1.0"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[deps.MolecularGraph]]
deps = ["DelimitedFiles", "JSON", "LinearAlgebra", "Printf", "Requires", "Statistics", "Unmarshal", "YAML", "coordgenlibs_jll", "libinchi_jll"]
git-tree-sha1 = "53627235a06cb26256be397069e376ff0c4d3c25"
uuid = "6c89ec66-9cd8-5372-9f91-fabc50dd27fd"
version = "0.13.0"

[[deps.MolecularGraphKernels]]
deps = ["Cairo", "Colors", "Combinatorics", "Compose", "Distributed", "GraphPlot", "Graphs", "JLD2", "Memoization", "MetaGraphs", "MolecularGraph", "PeriodicTable", "PrecompileSignatures", "ProgressMeter", "RDKitMinimalLib", "SharedArrays"]
git-tree-sha1 = "0dd82aad3a567451096ac0fc239b2ce4da4759f6"
uuid = "bf3818bd-b6bb-4954-8baa-32c32282e633"
version = "0.9.0"

[[deps.MosaicViews]]
deps = ["MappedArrays", "OffsetArrays", "PaddedViews", "StackViews"]
git-tree-sha1 = "7b86a5d4d70a9f5cdf2dacb3cbe6d251d1a61dbe"
uuid = "e94cdb99-869f-56ef-bcf0-1ae2bcbe0389"
version = "0.3.4"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"
version = "2022.2.1"

[[deps.NNlib]]
deps = ["Adapt", "Atomix", "ChainRulesCore", "GPUArraysCore", "KernelAbstractions", "LinearAlgebra", "Pkg", "Random", "Requires", "Statistics"]
git-tree-sha1 = "99e6dbb50d8a96702dc60954569e9fe7291cc55d"
uuid = "872c559c-99b0-510c-b3b7-b6c96a88d5cd"
version = "0.8.20"

[[deps.NNlibCUDA]]
deps = ["Adapt", "CUDA", "LinearAlgebra", "NNlib", "Random", "Statistics", "cuDNN"]
git-tree-sha1 = "f94a9684394ff0d325cc12b06da7032d8be01aaf"
uuid = "a00861dc-f156-4864-bf3c-e6376f28a68d"
version = "0.2.7"

[[deps.NaNMath]]
deps = ["OpenLibm_jll"]
git-tree-sha1 = "0877504529a3e5c3343c6f8b4c0381e57e4387e4"
uuid = "77ba4419-2d1f-58cd-9bb1-8ffee604a2e3"
version = "1.0.2"

[[deps.NameResolution]]
deps = ["PrettyPrint"]
git-tree-sha1 = "1a0fa0e9613f46c9b8c11eee38ebb4f590013c5e"
uuid = "71a1bf82-56d0-4bbc-8a3c-48b961074391"
version = "0.1.5"

[[deps.Netpbm]]
deps = ["FileIO", "ImageCore", "ImageMetadata"]
git-tree-sha1 = "5ae7ca23e13855b3aba94550f26146c01d259267"
uuid = "f09324ee-3d7c-5217-9330-fc30815ba969"
version = "1.1.0"

[[deps.NetworkLayout]]
deps = ["GeometryBasics", "LinearAlgebra", "Random", "Requires", "SparseArrays", "StaticArrays"]
git-tree-sha1 = "2bfd8cd7fba3e46ce48139ae93904ee848153660"
uuid = "46757867-2c16-5918-afeb-47bfcb05e46a"
version = "0.4.5"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"
version = "1.2.0"

[[deps.Nullables]]
git-tree-sha1 = "8f87854cc8f3685a60689d8edecaa29d2251979b"
uuid = "4d1e1d77-625e-5b40-9113-a560ec7a8ecd"
version = "1.0.0"

[[deps.Observables]]
git-tree-sha1 = "6862738f9796b3edc1c09d0890afce4eca9e7e93"
uuid = "510215fc-4207-5dde-b226-833fc4488ee2"
version = "0.5.4"

[[deps.OffsetArrays]]
deps = ["Adapt"]
git-tree-sha1 = "82d7c9e310fe55aa54996e6f7f94674e2a38fcb4"
uuid = "6fe1bfb0-de20-5000-8ca7-80f57d26f881"
version = "1.12.9"

[[deps.Ogg_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "887579a3eb005446d514ab7aeac5d1d027658b8f"
uuid = "e7412a2a-1a6e-54c0-be00-318e2571c051"
version = "1.3.5+1"

[[deps.OneHotArrays]]
deps = ["Adapt", "ChainRulesCore", "Compat", "GPUArraysCore", "LinearAlgebra", "NNlib"]
git-tree-sha1 = "f511fca956ed9e70b80cd3417bb8c2dde4b68644"
uuid = "0b1bfda6-eb8a-41d2-88d8-f5af5cad476f"
version = "0.2.3"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"
version = "0.3.20+0"

[[deps.OpenEXR]]
deps = ["Colors", "FileIO", "OpenEXR_jll"]
git-tree-sha1 = "327f53360fdb54df7ecd01e96ef1983536d1e633"
uuid = "52e1d378-f018-4a11-a4be-720524705ac7"
version = "0.3.2"

[[deps.OpenEXR_jll]]
deps = ["Artifacts", "Imath_jll", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "a4ca623df1ae99d09bc9868b008262d0c0ac1e4f"
uuid = "18a262bb-aa17-5467-a713-aee519bc75cb"
version = "3.1.4+0"

[[deps.OpenLibm_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "05823500-19ac-5b8b-9628-191a04bc5112"
version = "0.8.1+0"

[[deps.OpenSSL]]
deps = ["BitFlags", "Dates", "MozillaCACerts_jll", "OpenSSL_jll", "Sockets"]
git-tree-sha1 = "51901a49222b09e3743c65b8847687ae5fc78eb2"
uuid = "4d8831e6-92b7-49fb-bdf8-b643e874388c"
version = "1.4.1"

[[deps.OpenSSL_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "9ff31d101d987eb9d66bd8b176ac7c277beccd09"
uuid = "458c3c95-2e84-50aa-8efc-19380b2a3a95"
version = "1.1.20+0"

[[deps.OpenSpecFun_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "13652491f6856acfd2db29360e1bbcd4565d04f1"
uuid = "efe28fd5-8261-553b-a9e1-b2916fc3738e"
version = "0.5.5+0"

[[deps.Optimisers]]
deps = ["ChainRulesCore", "Functors", "LinearAlgebra", "Random", "Statistics"]
git-tree-sha1 = "6a01f65dd8583dee82eecc2a19b0ff21521aa749"
uuid = "3bd65402-5787-11e9-1adc-39752487f4e2"
version = "0.2.18"

[[deps.Opus_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "51a08fb14ec28da2ec7a927c4337e4332c2a4720"
uuid = "91d4177d-7536-5919-b921-800302f37372"
version = "1.3.2+0"

[[deps.OrderedCollections]]
git-tree-sha1 = "d321bf2de576bf25ec4d3e4360faca399afca282"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.6.0"

[[deps.PCRE2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "efcefdf7-47ab-520b-bdef-62a2eaa19f15"
version = "10.40.0+0"

[[deps.PDMats]]
deps = ["LinearAlgebra", "SparseArrays", "SuiteSparse"]
git-tree-sha1 = "67eae2738d63117a196f497d7db789821bce61d1"
uuid = "90014a1f-27ba-587c-ab20-58faa44d9150"
version = "0.11.17"

[[deps.PNGFiles]]
deps = ["Base64", "CEnum", "ImageCore", "IndirectArrays", "OffsetArrays", "libpng_jll"]
git-tree-sha1 = "f809158b27eba0c18c269cf2a2be6ed751d3e81d"
uuid = "f57f5aa1-a3ce-4bc8-8ab9-96f992907883"
version = "0.3.17"

[[deps.Packing]]
deps = ["GeometryBasics"]
git-tree-sha1 = "ec3edfe723df33528e085e632414499f26650501"
uuid = "19eb6ba3-879d-56ad-ad62-d5c202156566"
version = "0.5.0"

[[deps.PaddedViews]]
deps = ["OffsetArrays"]
git-tree-sha1 = "0fac6313486baae819364c52b4f483450a9d793f"
uuid = "5432bcbf-9aad-5242-b902-cca2824c8663"
version = "0.5.12"

[[deps.Pango_jll]]
deps = ["Artifacts", "Cairo_jll", "Fontconfig_jll", "FreeType2_jll", "FriBidi_jll", "Glib_jll", "HarfBuzz_jll", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "84a314e3926ba9ec66ac097e3635e270986b0f10"
uuid = "36c8627f-9965-5494-a995-c6b170f724f3"
version = "1.50.9+0"

[[deps.Parameters]]
deps = ["OrderedCollections", "UnPack"]
git-tree-sha1 = "34c0e9ad262e5f7fc75b10a9952ca7692cfc5fbe"
uuid = "d96e819e-fc66-5662-9728-84c9c7592b0a"
version = "0.12.3"

[[deps.Parsers]]
deps = ["Dates", "PrecompileTools", "UUIDs"]
git-tree-sha1 = "7302075e5e06da7d000d9bfa055013e3e85578ca"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.5.9"

[[deps.PeriodicTable]]
deps = ["Base64", "Test", "Unitful"]
git-tree-sha1 = "5ed1e2691eb13b6e955aff1b7eec0b2401df208c"
uuid = "7b2266bf-644c-5ea3-82d8-af4bbd25a884"
version = "1.1.3"

[[deps.Pipe]]
git-tree-sha1 = "6842804e7867b115ca9de748a0cf6b364523c16d"
uuid = "b98c9c47-44ae-5843-9183-064241ee97a0"
version = "1.3.0"

[[deps.Pixman_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "b4f5d02549a10e20780a24fce72bea96b6329e29"
uuid = "30392449-352a-5448-841d-b1acce4e97dc"
version = "0.40.1+0"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
version = "1.8.0"

[[deps.PkgVersion]]
deps = ["Pkg"]
git-tree-sha1 = "f6cf8e7944e50901594838951729a1861e668cb8"
uuid = "eebad327-c553-4316-9ea0-9fa01ccd7688"
version = "0.3.2"

[[deps.PlotThemes]]
deps = ["PlotUtils", "Statistics"]
git-tree-sha1 = "1f03a2d339f42dca4a4da149c7e15e9b896ad899"
uuid = "ccf2f8ad-2431-5c83-bf29-c5338b663b6a"
version = "3.1.0"

[[deps.PlotUtils]]
deps = ["ColorSchemes", "Colors", "Dates", "PrecompileTools", "Printf", "Random", "Reexport", "Statistics"]
git-tree-sha1 = "f92e1315dadf8c46561fb9396e525f7200cdc227"
uuid = "995b91a9-d308-5afd-9ec6-746e21dbc043"
version = "1.3.5"

[[deps.Plots]]
deps = ["Base64", "Contour", "Dates", "Downloads", "FFMPEG", "FixedPointNumbers", "GR", "JLFzf", "JSON", "LaTeXStrings", "Latexify", "LinearAlgebra", "Measures", "NaNMath", "Pkg", "PlotThemes", "PlotUtils", "PrecompileTools", "Preferences", "Printf", "REPL", "Random", "RecipesBase", "RecipesPipeline", "Reexport", "RelocatableFolders", "Requires", "Scratch", "Showoff", "SparseArrays", "Statistics", "StatsBase", "UUIDs", "UnicodeFun", "Unzip"]
git-tree-sha1 = "6c7f47fd112001fc95ea1569c2757dffd9e81328"
uuid = "91a5bcdd-55d7-5caf-9e0b-520d859cae80"
version = "1.38.11"

[[deps.PlutoUI]]
deps = ["AbstractPlutoDingetjes", "Base64", "ColorTypes", "Dates", "FixedPointNumbers", "Hyperscript", "HypertextLiteral", "IOCapture", "InteractiveUtils", "JSON", "Logging", "MIMEs", "Markdown", "Random", "Reexport", "URIs", "UUIDs"]
git-tree-sha1 = "b478a748be27bd2f2c73a7690da219d0844db305"
uuid = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
version = "0.7.51"

[[deps.PolygonOps]]
git-tree-sha1 = "77b3d3605fc1cd0b42d95eba87dfcd2bf67d5ff6"
uuid = "647866c9-e3ac-4575-94e7-e3d426903924"
version = "0.1.2"

[[deps.PolynomialRoots]]
git-tree-sha1 = "5f807b5345093487f733e520a1b7395ee9324825"
uuid = "3a141323-8675-5d76-9d11-e1df1406c778"
version = "1.0.0"

[[deps.PooledArrays]]
deps = ["DataAPI", "Future"]
git-tree-sha1 = "a6062fe4063cdafe78f4a0a81cfffb89721b30e7"
uuid = "2dfb63ee-cc39-5dd5-95bd-886bf059d720"
version = "1.4.2"

[[deps.PrecompileSignatures]]
git-tree-sha1 = "18ef344185f25ee9d51d80e179f8dad33dc48eb1"
uuid = "91cefc8d-f054-46dc-8f8c-26e11d7c5411"
version = "3.0.3"

[[deps.PrecompileTools]]
deps = ["Preferences"]
git-tree-sha1 = "259e206946c293698122f63e2b513a7c99a244e8"
uuid = "aea7be01-6a6a-4083-8856-8a6e6704d82a"
version = "1.1.1"

[[deps.Preferences]]
deps = ["TOML"]
git-tree-sha1 = "7eb1686b4f04b82f96ed7a4ea5890a4f0c7a09f1"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.4.0"

[[deps.PrettyPrint]]
git-tree-sha1 = "632eb4abab3449ab30c5e1afaa874f0b98b586e4"
uuid = "8162dcfd-2161-5ef2-ae6c-7681170c5f98"
version = "0.2.0"

[[deps.PrettyTables]]
deps = ["Crayons", "Formatting", "LaTeXStrings", "Markdown", "Reexport", "StringManipulation", "Tables"]
git-tree-sha1 = "213579618ec1f42dea7dd637a42785a608b1ea9c"
uuid = "08abe8d2-0d0c-5749-adfa-8a2ac140af0d"
version = "2.2.4"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[deps.Profile]]
deps = ["Printf"]
uuid = "9abbd945-dff8-562f-b5e8-e1ebf5ef1b79"

[[deps.ProfileCanvas]]
deps = ["Base64", "JSON", "Pkg", "Profile", "REPL"]
git-tree-sha1 = "e42571ce9a614c2fbebcaa8aab23bbf8865c624e"
uuid = "efd6af41-a80b-495e-886c-e51b0c7d77a3"
version = "0.1.6"

[[deps.ProgressLogging]]
deps = ["Logging", "SHA", "UUIDs"]
git-tree-sha1 = "80d919dee55b9c50e8d9e2da5eeafff3fe58b539"
uuid = "33c8b6b6-d38a-422a-b730-caa89a2f386c"
version = "0.1.4"

[[deps.ProgressMeter]]
deps = ["Distributed", "Printf"]
git-tree-sha1 = "d7a7aef8f8f2d537104f170139553b14dfe39fe9"
uuid = "92933f4c-e287-5a05-a399-4b506db050ca"
version = "1.7.2"

[[deps.PropertyDicts]]
git-tree-sha1 = "8cf3b5cea994cfa9f238e19c3946a39cf051896c"
uuid = "f8a19df8-e894-5f55-a973-672c1158cbca"
version = "0.1.2"

[[deps.PyCall]]
deps = ["Conda", "Dates", "Libdl", "LinearAlgebra", "MacroTools", "Serialization", "VersionParsing"]
git-tree-sha1 = "62f417f6ad727987c755549e9cd88c46578da562"
uuid = "438e738f-606a-5dbb-bf0a-cddfbfd45ab0"
version = "1.95.1"

[[deps.QOI]]
deps = ["ColorTypes", "FileIO", "FixedPointNumbers"]
git-tree-sha1 = "18e8f4d1426e965c7b532ddd260599e1510d26ce"
uuid = "4b34888f-f399-49d4-9bb3-47ed5cae4e65"
version = "1.0.0"

[[deps.QhullMiniWrapper_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Qhull_jll"]
git-tree-sha1 = "607cf73c03f8a9f83b36db0b86a3a9c14179621f"
uuid = "460c41e3-6112-5d7f-b78c-b6823adb3f2d"
version = "1.0.0+1"

[[deps.Qhull_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "be2449911f4d6cfddacdf7efc895eceda3eee5c1"
uuid = "784f63db-0788-585a-bace-daefebcd302b"
version = "8.0.1003+0"

[[deps.Qt5Base_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Fontconfig_jll", "Glib_jll", "JLLWrappers", "Libdl", "Libglvnd_jll", "OpenSSL_jll", "Pkg", "Xorg_libXext_jll", "Xorg_libxcb_jll", "Xorg_xcb_util_image_jll", "Xorg_xcb_util_keysyms_jll", "Xorg_xcb_util_renderutil_jll", "Xorg_xcb_util_wm_jll", "Zlib_jll", "xkbcommon_jll"]
git-tree-sha1 = "0c03844e2231e12fda4d0086fd7cbe4098ee8dc5"
uuid = "ea2cea3b-5b76-57ae-a6ef-0a8af62496e1"
version = "5.15.3+2"

[[deps.QuadGK]]
deps = ["DataStructures", "LinearAlgebra"]
git-tree-sha1 = "6ec7ac8412e83d57e313393220879ede1740f9ee"
uuid = "1fd47b50-473d-5c70-9696-f719f8f3bcdc"
version = "2.8.2"

[[deps.RDKitMinimalLib]]
deps = ["JSON", "RDKit_jll"]
git-tree-sha1 = "56837668e23c773b2537aceae7f3588ad4227077"
uuid = "44044271-7623-48dc-8250-42433c44e4b7"
version = "1.2.0"

[[deps.RDKit_jll]]
deps = ["Artifacts", "FreeType2_jll", "JLLWrappers", "Libdl", "Zlib_jll", "boost_jll"]
git-tree-sha1 = "37ebe7296ae1e018be4cc1abb53518bbd58a3c7a"
uuid = "03d1d220-30e6-562a-9e1a-3062d7b56d75"
version = "2022.9.5+0"

[[deps.REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[deps.Random]]
deps = ["SHA", "Serialization"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[deps.Random123]]
deps = ["Random", "RandomNumbers"]
git-tree-sha1 = "552f30e847641591ba3f39fd1bed559b9deb0ef3"
uuid = "74087812-796a-5b5d-8853-05524746bad3"
version = "1.6.1"

[[deps.RandomNumbers]]
deps = ["Random", "Requires"]
git-tree-sha1 = "043da614cc7e95c703498a491e2c21f58a2b8111"
uuid = "e6cf234a-135c-5ec9-84dd-332b85af5143"
version = "1.5.3"

[[deps.RangeArrays]]
git-tree-sha1 = "b9039e93773ddcfc828f12aadf7115b4b4d225f5"
uuid = "b3c3ace0-ae52-54e7-9d0b-2c1406fd6b9d"
version = "0.3.2"

[[deps.Ratios]]
deps = ["Requires"]
git-tree-sha1 = "6d7bb727e76147ba18eed998700998e17b8e4911"
uuid = "c84ed2f1-dad5-54f0-aa8e-dbefe2724439"
version = "0.4.4"

[[deps.RealDot]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "9f0a1b71baaf7650f4fa8a1d168c7fb6ee41f0c9"
uuid = "c1ae055f-0cd5-4b69-90a6-9a35b1a98df9"
version = "0.1.0"

[[deps.RecipesBase]]
deps = ["PrecompileTools"]
git-tree-sha1 = "5c3d09cc4f31f5fc6af001c250bf1278733100ff"
uuid = "3cdcf5f2-1ef4-517c-9805-6587b60abb01"
version = "1.3.4"

[[deps.RecipesPipeline]]
deps = ["Dates", "NaNMath", "PlotUtils", "PrecompileTools", "RecipesBase"]
git-tree-sha1 = "45cf9fd0ca5839d06ef333c8201714e888486342"
uuid = "01d81517-befc-4cb6-b9ec-a95719d0359c"
version = "0.6.12"

[[deps.Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[deps.RelocatableFolders]]
deps = ["SHA", "Scratch"]
git-tree-sha1 = "90bc7a7c96410424509e4263e277e43250c05691"
uuid = "05181044-ff0b-4ac5-8273-598c1e38db00"
version = "1.0.0"

[[deps.Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "838a3a4188e2ded87a4f9f184b4b0d78a1e91cb7"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.3.0"

[[deps.Rmath]]
deps = ["Random", "Rmath_jll"]
git-tree-sha1 = "f65dcb5fa46aee0cf9ed6274ccbd597adc49aa7b"
uuid = "79098fc4-a85e-5d69-aa6a-4863f24498fa"
version = "0.7.1"

[[deps.Rmath_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "6ed52fdd3382cf21947b15e8870ac0ddbff736da"
uuid = "f50d1b31-88e8-58de-be2c-1cc44531875f"
version = "0.4.0+0"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "0.7.0"

[[deps.SIMD]]
deps = ["PrecompileTools"]
git-tree-sha1 = "0e270732477b9e551d884e6b07e23bb2ec947790"
uuid = "fdea26ae-647d-5447-a871-4b548cad5224"
version = "3.4.5"

[[deps.ScanByte]]
deps = ["Libdl", "SIMD"]
git-tree-sha1 = "2436b15f376005e8790e318329560dcc67188e84"
uuid = "7b38b023-a4d7-4c5e-8d43-3f3097f304eb"
version = "0.3.3"

[[deps.ScikitLearn]]
deps = ["Compat", "Conda", "DataFrames", "Distributed", "IterTools", "LinearAlgebra", "MacroTools", "Parameters", "Printf", "PyCall", "Random", "ScikitLearnBase", "SparseArrays", "StatsBase", "VersionParsing"]
git-tree-sha1 = "3df098033358431591827bb86cada0bed744105a"
uuid = "3646fa90-6ef7-5e7e-9f22-8aca16db6324"
version = "0.7.0"

[[deps.ScikitLearnBase]]
deps = ["LinearAlgebra", "Random", "Statistics"]
git-tree-sha1 = "7877e55c1523a4b336b433da39c8e8c08d2f221f"
uuid = "6e75b9c4-186b-50bd-896f-2d2496a4843e"
version = "0.5.0"

[[deps.Scratch]]
deps = ["Dates"]
git-tree-sha1 = "30449ee12237627992a99d5e30ae63e4d78cd24a"
uuid = "6c6a2e73-6563-6170-7368-637461726353"
version = "1.2.0"

[[deps.SentinelArrays]]
deps = ["Dates", "Random"]
git-tree-sha1 = "77d3c4726515dca71f6d80fbb5e251088defe305"
uuid = "91c51154-3ec4-41a3-a24f-3f23e20d615c"
version = "1.3.18"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[deps.Setfield]]
deps = ["ConstructionBase", "Future", "MacroTools", "StaticArraysCore"]
git-tree-sha1 = "e2cc6d8c88613c05e1defb55170bf5ff211fbeac"
uuid = "efcf1570-3423-57d1-acb7-fd33fddbac46"
version = "1.1.1"

[[deps.SharedArrays]]
deps = ["Distributed", "Mmap", "Random", "Serialization"]
uuid = "1a1011a3-84de-559e-8e89-a11a2f7dc383"

[[deps.ShowCases]]
git-tree-sha1 = "7f534ad62ab2bd48591bdeac81994ea8c445e4a5"
uuid = "605ecd9f-84a6-4c9e-81e2-4798472b76a3"
version = "0.1.0"

[[deps.Showoff]]
deps = ["Dates", "Grisu"]
git-tree-sha1 = "91eddf657aca81df9ae6ceb20b959ae5653ad1de"
uuid = "992d4aef-0814-514b-bc4d-f2e9a6c4116f"
version = "1.0.3"

[[deps.SignedDistanceFields]]
deps = ["Random", "Statistics", "Test"]
git-tree-sha1 = "d263a08ec505853a5ff1c1ebde2070419e3f28e9"
uuid = "73760f76-fbc4-59ce-8f25-708e95d2df96"
version = "0.4.0"

[[deps.SimpleBufferStream]]
git-tree-sha1 = "874e8867b33a00e784c8a7e4b60afe9e037b74e1"
uuid = "777ac1f9-54b0-4bf8-805c-2214025038e7"
version = "1.1.0"

[[deps.SimpleTraits]]
deps = ["InteractiveUtils", "MacroTools"]
git-tree-sha1 = "5d7e3f4e11935503d3ecaf7186eac40602e7d231"
uuid = "699a6c99-e7fa-54fc-8d76-47d257e15c1d"
version = "0.9.4"

[[deps.Sixel]]
deps = ["Dates", "FileIO", "ImageCore", "IndirectArrays", "OffsetArrays", "REPL", "libsixel_jll"]
git-tree-sha1 = "8fb59825be681d451c246a795117f317ecbcaa28"
uuid = "45858cf5-a6b0-47a3-bbea-62219f50df47"
version = "0.1.2"

[[deps.SnoopPrecompile]]
deps = ["Preferences"]
git-tree-sha1 = "e760a70afdcd461cf01a575947738d359234665c"
uuid = "66db9d55-30c0-4569-8b51-7e840670fc0c"
version = "1.0.3"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[deps.SortingAlgorithms]]
deps = ["DataStructures"]
git-tree-sha1 = "a4ada03f999bd01b3a25dcaa30b2d929fe537e00"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.1.0"

[[deps.SparseArrays]]
deps = ["LinearAlgebra", "Random"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[deps.SpecialFunctions]]
deps = ["ChainRulesCore", "IrrationalConstants", "LogExpFunctions", "OpenLibm_jll", "OpenSpecFun_jll"]
git-tree-sha1 = "ef28127915f4229c971eb43f3fc075dd3fe91880"
uuid = "276daf66-3868-5448-9aa4-cd146d93841b"
version = "2.2.0"

[[deps.SplittablesBase]]
deps = ["Setfield", "Test"]
git-tree-sha1 = "e08a62abc517eb79667d0a29dc08a3b589516bb5"
uuid = "171d559e-b47b-412a-8079-5efa626c420e"
version = "0.1.15"

[[deps.StableHashTraits]]
deps = ["CRC32c", "Compat", "Dates", "SHA", "Tables", "TupleTools", "UUIDs"]
git-tree-sha1 = "0b8b801b8f03a329a4e86b44c5e8a7d7f4fe10a3"
uuid = "c5dd0088-6c3f-4803-b00e-f31a60c170fa"
version = "0.3.1"

[[deps.StackViews]]
deps = ["OffsetArrays"]
git-tree-sha1 = "46e589465204cd0c08b4bd97385e4fa79a0c770c"
uuid = "cae243ae-269e-4f55-b966-ac2d0dc13c15"
version = "0.1.1"

[[deps.StaticArrays]]
deps = ["LinearAlgebra", "Random", "StaticArraysCore", "Statistics"]
git-tree-sha1 = "c262c8e978048c2b095be1672c9bee55b4619521"
uuid = "90137ffa-7385-5640-81b9-e52037218182"
version = "1.5.24"

[[deps.StaticArraysCore]]
git-tree-sha1 = "6b7ba252635a5eff6a0b0664a41ee140a1c9e72a"
uuid = "1e83bf80-4336-4d27-bf5d-d5a4f845583c"
version = "1.4.0"

[[deps.Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[[deps.StatsAPI]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "45a7769a04a3cf80da1c1c7c60caf932e6f4c9f7"
uuid = "82ae8749-77ed-4fe6-ae5f-f523153014b0"
version = "1.6.0"

[[deps.StatsBase]]
deps = ["DataAPI", "DataStructures", "LinearAlgebra", "LogExpFunctions", "Missings", "Printf", "Random", "SortingAlgorithms", "SparseArrays", "Statistics", "StatsAPI"]
git-tree-sha1 = "d1bf48bfcc554a3761a133fe3a9bb01488e06916"
uuid = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"
version = "0.33.21"

[[deps.StatsFuns]]
deps = ["ChainRulesCore", "HypergeometricFunctions", "InverseFunctions", "IrrationalConstants", "LogExpFunctions", "Reexport", "Rmath", "SpecialFunctions"]
git-tree-sha1 = "f625d686d5a88bcd2b15cd81f18f98186fdc0c9a"
uuid = "4c63d2b9-4356-54db-8cca-17b64c39e42c"
version = "1.3.0"

[[deps.StringEncodings]]
deps = ["Libiconv_jll"]
git-tree-sha1 = "33c0da881af3248dafefb939a21694b97cfece76"
uuid = "69024149-9ee7-55f6-a4c4-859efe599b68"
version = "0.3.6"

[[deps.StringManipulation]]
git-tree-sha1 = "46da2434b41f41ac3594ee9816ce5541c6096123"
uuid = "892a3eda-7b42-436c-8928-eab12a02cf0e"
version = "0.3.0"

[[deps.StructArrays]]
deps = ["Adapt", "DataAPI", "GPUArraysCore", "StaticArraysCore", "Tables"]
git-tree-sha1 = "521a0e828e98bb69042fec1809c1b5a680eb7389"
uuid = "09ab397b-f2b6-538f-b94a-2f83cf4a842a"
version = "0.6.15"

[[deps.SuiteSparse]]
deps = ["Libdl", "LinearAlgebra", "Serialization", "SparseArrays"]
uuid = "4607b0f0-06f3-5cda-b6b1-a6196a1729e9"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"
version = "1.0.0"

[[deps.TableTraits]]
deps = ["IteratorInterfaceExtensions"]
git-tree-sha1 = "c06b2f539df1c6efa794486abfb6ed2022561a39"
uuid = "3783bdb8-4a98-5b6b-af9a-565f29a5fe9c"
version = "1.0.1"

[[deps.Tables]]
deps = ["DataAPI", "DataValueInterfaces", "IteratorInterfaceExtensions", "LinearAlgebra", "OrderedCollections", "TableTraits", "Test"]
git-tree-sha1 = "1544b926975372da01227b382066ab70e574a3ec"
uuid = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
version = "1.10.1"

[[deps.Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"
version = "1.10.1"

[[deps.TensorCore]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "1feb45f88d133a655e001435632f019a9a1bcdb6"
uuid = "62fd8b95-f654-4bbd-a8a5-9c27f68ccd50"
version = "0.1.1"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[deps.TiffImages]]
deps = ["ColorTypes", "DataStructures", "DocStringExtensions", "FileIO", "FixedPointNumbers", "IndirectArrays", "Inflate", "Mmap", "OffsetArrays", "PkgVersion", "ProgressMeter", "UUIDs"]
git-tree-sha1 = "8621f5c499a8aa4aa970b1ae381aae0ef1576966"
uuid = "731e570b-9d59-4bfa-96dc-6df516fadf69"
version = "0.6.4"

[[deps.TimerOutputs]]
deps = ["ExprTools", "Printf"]
git-tree-sha1 = "f548a9e9c490030e545f72074a41edfd0e5bcdd7"
uuid = "a759f4b9-e2f1-59dc-863e-4aeb61b1ea8f"
version = "0.5.23"

[[deps.TranscodingStreams]]
deps = ["Random", "Test"]
git-tree-sha1 = "9a6ae7ed916312b41236fcef7e0af564ef934769"
uuid = "3bb67fe8-82b1-5028-8e26-92a6c54297fa"
version = "0.9.13"

[[deps.Transducers]]
deps = ["Adapt", "ArgCheck", "BangBang", "Baselet", "CompositionsBase", "DefineSingletons", "Distributed", "InitialValues", "Logging", "Markdown", "MicroCollections", "Requires", "Setfield", "SplittablesBase", "Tables"]
git-tree-sha1 = "25358a5f2384c490e98abd565ed321ffae2cbb37"
uuid = "28d57a85-8fef-5791-bfe6-a80928e7c999"
version = "0.4.76"

[[deps.Tricks]]
git-tree-sha1 = "aadb748be58b492045b4f56166b5188aa63ce549"
uuid = "410a4b4d-49e4-4fbc-ab6d-cb71b17b3775"
version = "0.1.7"

[[deps.TriplotBase]]
git-tree-sha1 = "4d4ed7f294cda19382ff7de4c137d24d16adc89b"
uuid = "981d1d27-644d-49a2-9326-4793e63143c3"
version = "0.1.0"

[[deps.TupleTools]]
git-tree-sha1 = "3c712976c47707ff893cf6ba4354aa14db1d8938"
uuid = "9d95972d-f1c8-5527-a6e0-b4b365fa01f6"
version = "1.3.0"

[[deps.URIs]]
git-tree-sha1 = "074f993b0ca030848b897beff716d93aca60f06a"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.4.2"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[deps.UnPack]]
git-tree-sha1 = "387c1f73762231e86e0c9c5443ce3b4a0a9a0c2b"
uuid = "3a884ed6-31ef-47d7-9d2a-63182c4928ed"
version = "1.0.2"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[deps.UnicodeFun]]
deps = ["REPL"]
git-tree-sha1 = "53915e50200959667e78a92a418594b428dffddf"
uuid = "1cfade01-22cf-5700-b092-accc4b62d6e1"
version = "0.4.1"

[[deps.Unitful]]
deps = ["ConstructionBase", "Dates", "LinearAlgebra", "Random"]
git-tree-sha1 = "ba4aa36b2d5c98d6ed1f149da916b3ba46527b2b"
uuid = "1986cc42-f94f-5a68-af5c-568840ba703d"
version = "1.14.0"

[[deps.Unmarshal]]
deps = ["JSON", "LazyJSON", "Missings", "Nullables", "Requires"]
git-tree-sha1 = "ee46863309f8f942249e1df1b74ba3088ff0f151"
uuid = "cbff2730-442d-58d7-89d1-8e530c41eb02"
version = "0.4.4"

[[deps.UnsafeAtomics]]
git-tree-sha1 = "6331ac3440856ea1988316b46045303bef658278"
uuid = "013be700-e6cd-48c3-b4a1-df204f14c38f"
version = "0.2.1"

[[deps.UnsafeAtomicsLLVM]]
deps = ["LLVM", "UnsafeAtomics"]
git-tree-sha1 = "ea37e6066bf194ab78f4e747f5245261f17a7175"
uuid = "d80eeb9a-aca5-4d75-85e5-170c8b632249"
version = "0.1.2"

[[deps.Unzip]]
git-tree-sha1 = "ca0969166a028236229f63514992fc073799bb78"
uuid = "41fe7b60-77ed-43a1-b4f0-825fd5a5650d"
version = "0.2.0"

[[deps.VersionParsing]]
git-tree-sha1 = "58d6e80b4ee071f5efd07fda82cb9fbe17200868"
uuid = "81def892-9a0e-5fdd-b105-ffc91e053289"
version = "1.3.0"

[[deps.Wayland_jll]]
deps = ["Artifacts", "Expat_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Pkg", "XML2_jll"]
git-tree-sha1 = "ed8d92d9774b077c53e1da50fd81a36af3744c1c"
uuid = "a2964d1f-97da-50d4-b82a-358c7fce9d89"
version = "1.21.0+0"

[[deps.Wayland_protocols_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4528479aa01ee1b3b4cd0e6faef0e04cf16466da"
uuid = "2381bf8a-dfd0-557d-9999-79630e7b1b91"
version = "1.25.0+0"

[[deps.WeakRefStrings]]
deps = ["DataAPI", "InlineStrings", "Parsers"]
git-tree-sha1 = "b1be2855ed9ed8eac54e5caff2afcdb442d52c23"
uuid = "ea10d353-3f73-51f8-a26c-33c1cb351aa5"
version = "1.4.2"

[[deps.WoodburyMatrices]]
deps = ["LinearAlgebra", "SparseArrays"]
git-tree-sha1 = "de67fa59e33ad156a590055375a30b23c40299d3"
uuid = "efce3f68-66dc-5838-9240-27a6d6f5f9b6"
version = "0.5.5"

[[deps.WorkerUtilities]]
git-tree-sha1 = "cd1659ba0d57b71a464a29e64dbc67cfe83d54e7"
uuid = "76eceee3-57b5-4d4a-8e66-0e911cebbf60"
version = "1.6.1"

[[deps.XML2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libiconv_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "93c41695bc1c08c46c5899f4fe06d6ead504bb73"
uuid = "02c8fc9c-b97f-50b9-bbe4-9be30ff0a78a"
version = "2.10.3+0"

[[deps.XSLT_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libgcrypt_jll", "Libgpg_error_jll", "Libiconv_jll", "Pkg", "XML2_jll", "Zlib_jll"]
git-tree-sha1 = "91844873c4085240b95e795f692c4cec4d805f8a"
uuid = "aed1982a-8fda-507f-9586-7b0439959a61"
version = "1.1.34+0"

[[deps.Xorg_libX11_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libxcb_jll", "Xorg_xtrans_jll"]
git-tree-sha1 = "5be649d550f3f4b95308bf0183b82e2582876527"
uuid = "4f6342f7-b3d2-589e-9d20-edeb45f2b2bc"
version = "1.6.9+4"

[[deps.Xorg_libXau_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4e490d5c960c314f33885790ed410ff3a94ce67e"
uuid = "0c0b7dd1-d40b-584c-a123-a41640f87eec"
version = "1.0.9+4"

[[deps.Xorg_libXcursor_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXfixes_jll", "Xorg_libXrender_jll"]
git-tree-sha1 = "12e0eb3bc634fa2080c1c37fccf56f7c22989afd"
uuid = "935fb764-8cf2-53bf-bb30-45bb1f8bf724"
version = "1.2.0+4"

[[deps.Xorg_libXdmcp_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4fe47bd2247248125c428978740e18a681372dd4"
uuid = "a3789734-cfe1-5b06-b2d0-1dd0d9d62d05"
version = "1.1.3+4"

[[deps.Xorg_libXext_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "b7c0aa8c376b31e4852b360222848637f481f8c3"
uuid = "1082639a-0dae-5f34-9b06-72781eeb8cb3"
version = "1.3.4+4"

[[deps.Xorg_libXfixes_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "0e0dc7431e7a0587559f9294aeec269471c991a4"
uuid = "d091e8ba-531a-589c-9de9-94069b037ed8"
version = "5.0.3+4"

[[deps.Xorg_libXi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXext_jll", "Xorg_libXfixes_jll"]
git-tree-sha1 = "89b52bc2160aadc84d707093930ef0bffa641246"
uuid = "a51aa0fd-4e3c-5386-b890-e753decda492"
version = "1.7.10+4"

[[deps.Xorg_libXinerama_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXext_jll"]
git-tree-sha1 = "26be8b1c342929259317d8b9f7b53bf2bb73b123"
uuid = "d1454406-59df-5ea1-beac-c340f2130bc3"
version = "1.1.4+4"

[[deps.Xorg_libXrandr_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXext_jll", "Xorg_libXrender_jll"]
git-tree-sha1 = "34cea83cb726fb58f325887bf0612c6b3fb17631"
uuid = "ec84b674-ba8e-5d96-8ba1-2a689ba10484"
version = "1.5.2+4"

[[deps.Xorg_libXrender_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "19560f30fd49f4d4efbe7002a1037f8c43d43b96"
uuid = "ea2f1a96-1ddc-540d-b46f-429655e07cfa"
version = "0.9.10+4"

[[deps.Xorg_libpthread_stubs_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "6783737e45d3c59a4a4c4091f5f88cdcf0908cbb"
uuid = "14d82f49-176c-5ed1-bb49-ad3f5cbd8c74"
version = "0.1.0+3"

[[deps.Xorg_libxcb_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "XSLT_jll", "Xorg_libXau_jll", "Xorg_libXdmcp_jll", "Xorg_libpthread_stubs_jll"]
git-tree-sha1 = "daf17f441228e7a3833846cd048892861cff16d6"
uuid = "c7cfdc94-dc32-55de-ac96-5a1b8d977c5b"
version = "1.13.0+3"

[[deps.Xorg_libxkbfile_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "926af861744212db0eb001d9e40b5d16292080b2"
uuid = "cc61e674-0454-545c-8b26-ed2c68acab7a"
version = "1.1.0+4"

[[deps.Xorg_xcb_util_image_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "0fab0a40349ba1cba2c1da699243396ff8e94b97"
uuid = "12413925-8142-5f55-bb0e-6d7ca50bb09b"
version = "0.4.0+1"

[[deps.Xorg_xcb_util_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libxcb_jll"]
git-tree-sha1 = "e7fd7b2881fa2eaa72717420894d3938177862d1"
uuid = "2def613f-5ad1-5310-b15b-b15d46f528f5"
version = "0.4.0+1"

[[deps.Xorg_xcb_util_keysyms_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "d1151e2c45a544f32441a567d1690e701ec89b00"
uuid = "975044d2-76e6-5fbe-bf08-97ce7c6574c7"
version = "0.4.0+1"

[[deps.Xorg_xcb_util_renderutil_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "dfd7a8f38d4613b6a575253b3174dd991ca6183e"
uuid = "0d47668e-0667-5a69-a72c-f761630bfb7e"
version = "0.3.9+1"

[[deps.Xorg_xcb_util_wm_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "e78d10aab01a4a154142c5006ed44fd9e8e31b67"
uuid = "c22f9ab0-d5fe-5066-847c-f4bb1cd4e361"
version = "0.4.1+1"

[[deps.Xorg_xkbcomp_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libxkbfile_jll"]
git-tree-sha1 = "4bcbf660f6c2e714f87e960a171b119d06ee163b"
uuid = "35661453-b289-5fab-8a00-3d9160c6a3a4"
version = "1.4.2+4"

[[deps.Xorg_xkeyboard_config_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xkbcomp_jll"]
git-tree-sha1 = "5c8424f8a67c3f2209646d4425f3d415fee5931d"
uuid = "33bec58e-1273-512f-9401-5d533626f822"
version = "2.27.0+4"

[[deps.Xorg_xtrans_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "79c31e7844f6ecf779705fbc12146eb190b7d845"
uuid = "c5fb5394-a638-5e4d-96e5-b29de1b5cf10"
version = "1.4.0+3"

[[deps.YAML]]
deps = ["Base64", "Dates", "Printf", "StringEncodings"]
git-tree-sha1 = "dbc7f1c0012a69486af79c8bcdb31be820670ba2"
uuid = "ddb6d928-2868-570f-bddf-ab3f9cf99eb6"
version = "0.4.8"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"
version = "1.2.12+3"

[[deps.Zstd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "49ce682769cd5de6c72dcf1b94ed7790cd08974c"
uuid = "3161d3a3-bdf6-5164-811a-617609db77b4"
version = "1.5.5+0"

[[deps.Zygote]]
deps = ["AbstractFFTs", "ChainRules", "ChainRulesCore", "DiffRules", "Distributed", "FillArrays", "ForwardDiff", "GPUArrays", "GPUArraysCore", "IRTools", "InteractiveUtils", "LinearAlgebra", "LogExpFunctions", "MacroTools", "NaNMath", "Random", "Requires", "SnoopPrecompile", "SparseArrays", "SpecialFunctions", "Statistics", "ZygoteRules"]
git-tree-sha1 = "987ae5554ca90e837594a0f30325eeb5e7303d1e"
uuid = "e88e6eb3-aa80-5325-afca-941959d7151f"
version = "0.6.60"

[[deps.ZygoteRules]]
deps = ["ChainRulesCore", "MacroTools"]
git-tree-sha1 = "977aed5d006b840e2e40c0b48984f7463109046d"
uuid = "700de1a5-db45-46bc-99cf-38207098b444"
version = "0.2.3"

[[deps.boost_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "7a89efe0137720ca82f99e8daa526d23120d0d37"
uuid = "28df3c45-c428-5900-9ff8-a3135698ca75"
version = "1.76.0+1"

[[deps.coordgenlibs_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "8a0fdb746dfc75758d0abea3196f5edfcbbebd79"
uuid = "f6050b86-aaaf-512f-8549-0afff1b4d57f"
version = "3.0.1+0"

[[deps.cuDNN]]
deps = ["CEnum", "CUDA", "CUDNN_jll"]
git-tree-sha1 = "ec954b59f6b0324543f2e3ed8118309ac60cb75b"
uuid = "02a925ec-e4fe-4b08-9a7e-0d78e3d38ccd"
version = "1.0.3"

[[deps.fzf_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "868e669ccb12ba16eaf50cb2957ee2ff61261c56"
uuid = "214eeab7-80f7-51ab-84ad-2988db7cef09"
version = "0.29.0+0"

[[deps.isoband_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "51b5eeb3f98367157a7a12a1fb0aa5328946c03c"
uuid = "9a68df92-36a6-505f-a73e-abb412b6bfb4"
version = "0.2.3+0"

[[deps.libaom_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "3a2ea60308f0996d26f1e5354e10c24e9ef905d4"
uuid = "a4ae2306-e953-59d6-aa16-d00cac43593b"
version = "3.4.0+0"

[[deps.libass_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "HarfBuzz_jll", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "5982a94fcba20f02f42ace44b9894ee2b140fe47"
uuid = "0ac62f75-1d6f-5e53-bd7c-93b484bb37c0"
version = "0.15.1+0"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl", "OpenBLAS_jll"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.1.1+0"

[[deps.libfdk_aac_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "daacc84a041563f965be61859a36e17c4e4fcd55"
uuid = "f638f0a6-7fb0-5443-88ba-1cc74229b280"
version = "2.0.2+0"

[[deps.libinchi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "034ee07d3b387a4ca1a153a43a0c46549b6749ba"
uuid = "172afb32-8f1c-513b-968f-184fcd77af72"
version = "1.5.1+0"

[[deps.libpng_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "94d180a6d2b5e55e447e2d27a29ed04fe79eb30c"
uuid = "b53b4c65-9356-5827-b1ea-8c7a1a84506f"
version = "1.6.38+0"

[[deps.libsixel_jll]]
deps = ["Artifacts", "JLLWrappers", "JpegTurbo_jll", "Libdl", "Pkg", "libpng_jll"]
git-tree-sha1 = "d4f63314c8aa1e48cd22aa0c17ed76cd1ae48c3c"
uuid = "075b6546-f08a-558a-be8f-8157d0f608a5"
version = "1.10.3+0"

[[deps.libvorbis_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Ogg_jll", "Pkg"]
git-tree-sha1 = "b910cb81ef3fe6e78bf6acee440bda86fd6ae00c"
uuid = "f27f6e37-5d2b-51aa-960f-b287f2bc3b7a"
version = "1.3.7+1"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"
version = "1.48.0+0"

[[deps.p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
version = "17.4.0+0"

[[deps.x264_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4fea590b89e6ec504593146bf8b988b2c00922b2"
uuid = "1270edf5-f2f9-52d2-97e9-ab00b5d0237a"
version = "2021.5.5+0"

[[deps.x265_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "ee567a171cce03570d77ad3a43e90218e38937a9"
uuid = "dfaa095f-4041-5dcd-9319-2fabd8486b76"
version = "3.5.0+0"

[[deps.xkbcommon_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Wayland_jll", "Wayland_protocols_jll", "Xorg_libxcb_jll", "Xorg_xkeyboard_config_jll"]
git-tree-sha1 = "9ebfc140cc56e8c2156a15ceac2f0302e327ac0a"
uuid = "d8fb68d0-12a3-5cfd-a85a-d49703b185fd"
version = "1.4.1+0"
"""

# ╔═╡ Cell order:
# ╠═355935c0-e6c8-11ed-3d7f-b75711b208db
# ╠═9a3b5873-ead9-48ed-a007-480254492d99
# ╠═52271d30-12db-4b0e-aa6e-c49f2ecc49bc
# ╠═75e3a98b-44c2-4701-9886-31f211c0298d
# ╠═ec880e78-db99-410b-b039-923895268335
# ╠═74d30a7a-5731-48d3-9a8c-3af70e22fb90
# ╠═d05d720b-bf4c-4a87-9dfb-a1371cf7c58f
# ╠═c14b4e51-cfa0-4fee-9f2f-2caf78825881
# ╠═433de812-d272-4a01-bb62-a1808f333065
# ╠═2024c6b7-619b-410a-9824-e3cf3073a4a4
# ╠═de26db2f-a095-418f-8446-491fbf76462d
# ╟─4023cc37-5e26-4101-95b0-131daa0129ab
# ╠═0e391f1f-b091-4a76-966e-a94a4f3501ca
# ╠═996b6e7c-d5a7-4310-9497-9665ae46cf2c
# ╠═1c754230-e34a-4b7e-9ac1-8cbc728f250a
# ╠═7156399b-0494-4d51-b625-b54666ec872b
# ╠═ed4d8486-884e-4e92-92fb-48d1e8ed2610
# ╠═187b80b4-1495-4f36-be95-160311f5001b
# ╠═0c949b00-ca82-4f31-a8bc-2b53793836d6
# ╠═5d64e523-4052-49da-b8e5-c77963d53c81
# ╠═9716c04a-2ec7-4a28-a146-737fb33761e9
# ╠═21669eb2-f6d2-4e2b-8b87-cd891824706f
# ╠═f117ea46-d75c-4808-b629-2b8e9d062bc6
# ╠═95f8ef87-89fa-438d-bfd1-928414818f5d
# ╠═85bbc206-855d-40bf-a73e-57a87f6cbb08
# ╠═6938b38c-c2c1-4f1d-9b1d-2190e4993377
# ╠═bf680e73-a736-49ab-8a34-ee82574fb5e4
# ╠═14f49fd7-9e08-4a61-84e6-8fafbc45a7d2
# ╠═3dc48e7c-4780-4dc1-8918-3112d66d9d6f
# ╠═291a0ac4-8ce8-4e7d-8007-7f66aa7e19f2
# ╠═00e8bcf2-4625-4421-9197-b7f8582c09ed
# ╠═0f25afdd-384f-46e4-8adc-2788f98d7936
# ╠═6c9a6762-16f7-449d-9715-ff743af6a4b1
# ╠═f5c7f438-c027-402d-a23a-be5e35739a53
# ╠═f0412864-798b-4512-906c-e556813bf773
# ╠═db0f1e11-6df2-4083-8d0f-db9797de6bba
# ╠═9cc4b623-c0fa-4603-9308-47e15c0d4084
# ╠═968bcb20-8937-4306-a14a-b5877b1b06d2
# ╠═80691e93-d397-4efa-bea1-c97316e681e6
# ╠═75eb906b-059d-4521-9d3f-a1eb97cb92af
# ╠═e6b0558b-58b4-4151-9885-8f6ba6894c3e
# ╠═d935f630-0e80-453e-9e90-feb54f8de122
# ╠═0d950e3f-c220-4f8e-906d-0c9204a1c705
# ╟─0a4391b2-fbb7-4046-814c-42a4a7893877
# ╠═20e20031-ee7c-4324-b411-c974b2bfc5f8
# ╠═b0243fea-02a2-48a7-8f04-436d0bf5f212
# ╠═e77c3fb4-b15b-48e3-9207-7867f724764b
# ╠═a04dde28-4fc3-4630-8dbf-1fa7417df298
# ╠═365270e9-c043-4752-b56d-aa141f0bd297
# ╟─c319887c-436c-42c1-b923-7c7e813f9cd6
# ╠═a3575c2e-e7a0-4d10-91ac-180a24084010
# ╠═97251405-a573-496e-97dc-952cc7056b30
# ╠═17f0c2b6-6ab9-470a-bf97-ce14ed16f4b4
# ╠═06df10ba-467a-44d6-b3ef-2cc202ed1fff
# ╠═6f588e60-30d7-4951-a1fa-f9cabb641d83
# ╠═a0634263-9e74-469b-a07e-de48b22606b0
# ╠═7bcb767f-ad63-4ac7-bee0-1869b59e5a6d
# ╠═13e239be-cf78-4fa1-bf2e-cc5618e7241b
# ╟─4d0e660e-489d-47a9-8670-4cbcb63d713a
# ╠═53d30f62-ffbc-45c5-a6ee-b7702b79a6c8
# ╠═564e8a92-1a39-4318-acfe-75d4b52d21a1
# ╠═fbeb1934-7184-4b56-90ed-13d496da6359
# ╠═0b821654-1779-438a-b0aa-e54f7d6b3094
# ╠═79cd8f69-244a-4d0d-bae9-e34cce93c741
# ╠═280ddf4b-8f94-4f43-b7b6-98b4c02266b4
# ╠═8b461b4b-58c9-429a-808e-2640b800555b
# ╠═0a39ff49-2661-4fd0-ae15-79df01961de3
# ╠═422d6864-d70d-4293-ab5d-ead3200b1e7b
# ╠═bc2dd286-82ab-4f72-8fa4-728eeb595609
# ╠═c02aa62b-6ba0-4b71-8cb8-61964d4910f5
# ╠═5c020120-cb40-47c6-91f7-2def55767dda
# ╠═e5d6f4ff-ceb3-4caa-93f9-95e35903587d
# ╠═55d6691b-6bc2-4cbc-a476-1e694953e0db
# ╠═4d165ece-51e6-4186-8edc-5a3f1fe9e177
# ╠═fc0d8099-0871-4ff9-bb58-b237e635c287
# ╠═c559248a-cf56-4fa1-a8d7-e58b6797cb82
# ╠═e6e5a1cf-a993-4a49-830f-fa73d70fe164
# ╠═b6cec67b-8621-421a-baf1-297867b026f4
# ╠═02337422-dddc-456f-a1b0-7a47f618df72
# ╠═f829e817-f9cf-4ebe-80ee-0491ae743895
# ╠═73f9805e-9385-4a78-9d5e-f9ddf5e82dcf
# ╠═38fc7d09-6574-4dea-ab5e-4895db6126e2
# ╠═302e348a-0ee2-4794-bd73-2637d36b53b0
# ╠═3b4ada9d-d6ed-4bf7-aa99-601529378977
# ╠═a0023cf4-0b65-4fca-b55b-d46539ea057e
# ╠═bac0722f-ee85-49ad-8ed2-12dde0784e68
# ╠═93ecf657-4baa-433e-abe2-12e19b5a36bd
# ╠═9e070647-f926-49b7-ae2c-7cf0f80fa919
# ╠═460fc5bf-630a-4575-882f-f9132559d6fe
# ╠═0ba1d1e5-fd55-45cf-a776-edee2186fbd4
# ╠═002a236a-3ccc-47ee-a50a-73470725f20a
# ╠═fdbc9c21-be48-417b-95da-ca7a27e896a3
# ╠═0b94618b-8fb0-4c4d-9216-a63e2bf51f88
# ╠═fa63181b-704c-4e68-871a-3a982ea2e46b
# ╠═965d1a4b-e317-4b4b-a372-e5b94aab355a
# ╠═fc872d9e-65bc-4467-80ce-16033d346984
# ╠═87e1a41b-04df-46c2-9e0f-e32962c65f28
# ╠═68087161-ef13-4446-a5aa-0a7ccd5f43a7
# ╠═52687bb4-43b1-4766-b589-9ffc6febe591
# ╠═27265b69-2088-47cb-b8a0-52266573a3f8
# ╠═99ef0080-b1ef-45f1-8047-80092751472b
# ╠═0368b202-6d35-43ce-8e7f-430cee6efa9c
# ╠═bf48d194-d96d-4cee-9ac6-0ce4d76d4f27
# ╠═8d721ffd-8023-4dbe-8476-6a011ee15efa
# ╠═27c31f7a-8423-4bde-88c7-b27dbaba222a
# ╠═a891c1c4-a2dc-48dd-8d9c-5005521ce558
# ╠═e854f1c9-dd96-4081-9d5c-f2c0c212d02f
# ╠═42ee1ede-95e7-484b-8670-5618e9445de6
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
