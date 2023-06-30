### A Pluto.jl notebook ###
# v0.19.26

using Markdown
using InteractiveUtils

# ╔═╡ a8e9eeae-161d-11ee-016d-1138b7066ff5
using PlutoUI, TableIO, DataFrames, CSV, Plots, StatsPlots

# ╔═╡ 088b8ea7-29c5-498c-8e1d-6aa50da357ed
using Statistics, LinearAlgebra, Random, Distributions

# ╔═╡ 75ab20ce-9203-4caa-86d3-1264706877eb
md"## TCC - Método de Ising com correlações de vizinho mais próximo (INNC)"

# ╔═╡ aa8332a4-69a2-419a-acdd-de4485b12d74
html"""<style>
main {
    max-width: 1000px;
}
"""

# ╔═╡ 3485eb23-79c5-4ec7-9201-f3c8c89581b8
md"### Pacotes Utilizados"

# ╔═╡ 146d17b8-e26b-4353-bb58-dac8b7d4e7d3
plotly(fontfamily = "Times", size = (900,600))

# ╔═╡ 1e1f17bd-f55e-4b6e-ad3b-aa64aaf86e30
md"### Implementação das funções do INNC"

# ╔═╡ d79d54ba-d528-4ec1-8625-505030c48670
function discr_ising(z, zc)
    N = length(z)
    id = zeros(N)

    for i in 1:N
        if isfinite(z[i])
            if z[i] > zc
                id[i] = 1
            else
                id[i] = -1
            end
        elseif isnan(z[i])
            id[i] = NaN
        end
    end

    return id
end

# ╔═╡ 491cadcf-77c8-4f6d-a688-146f1a05d085
function discr_potts(z, zc)
    z = z[:]
    M = length(zc)
    N = length(z)
    sv = zeros(N)

    for k = M:-1:1
        sv[z .<= zc[k]] .= k
    end

    sv[z .> zc[M]] .= size(zc,1)
    sv[sv .== 0] .= NaN

    sv2 = []
	for i in sv
		if isnan(i)
			push!(sv2,i)
		else
			push!(sv2,Int(i))
		end
	end
	return sv2
end

# ╔═╡ 1c3c5b52-d380-46da-a6b1-a879cddb712e
function init_ising(Ind, Lx::Int64, Ly::Int64, Km::Vector{Int64}, Kp::Vector{Int64}, SD::Matrix{Int64}, m_min::Int64, m_max::Int64)::Vector{Int64}

	new_size = Lx*Ly + 1
	new_Ind = Vector{Float64}(undef, new_size)
	new_Ind[1:Lx*Ly] = Ind
	new_Ind[new_size] = 0
	Ind = new_Ind    # Values with index N+1 (points in SD exceeding lattice size) assigned zero

    # Initializing spin_rng to store initial values based on different stencil sizes rng by majority vote
    spin_rng = zeros(Int64, length(Km), m_max)

    # Assigning initial values based on different stencil sizes rng by majority vote
    for rng in m_min:2:m_max
        spin_rng[:, rng] = sign.(sum(Ind[SD[Km, 1:rng^2-1]] .== 1, dims=2) .- sum(Ind[SD[Km, 1:rng^2-1]] .== -1, dims=2))
    end

    # Final initial values are selected based on the smallest stencil where
    # majority was reached, i.e. first non-zero value of spin_rng from each row

    if (m_min==m_max)
        spin_0 = spin_rng[:, m_max]
    else
        spin_0 = spin_rng[:, m_min]
        for rng in m_min:2:m_max-2
            ff = findall(spin_0 .== 0)
            spin_0[ff] .= spin_rng[ff, rng+2]
        end
    end

    # Assigning random value +/-1 to the cases where no majority was reached
    # for the considered stencil sizes
    spin_0[spin_0 .== 0] .= sign.(0.5 .- rand(length(findall(spin_0 .== 0))))

    return spin_0
end

# ╔═╡ b1d027e1-4932-4877-8db1-79153bd2c505
function neighb(m_min::Int, m_max::Int, Lx::Int, Ly::Int)
    
		N = Lx * Ly
	    ni = collect(1:N)
		SD3= []
	    for m = m_min:2:m_max
	        w2 = (m-1)/2
			del_d = repeat(w2 .+ (-w2:w2) .* Ly, N, 1)
			del_u = repeat(-w2 .+ (-w2:w2) .* Ly, N, 1)
			del_r = repeat(Ly .* w2 .+ (-w2+1:w2-1), N, 1)
			del_l = repeat(-Ly .* w2 .+ (-w2+1:w2-1), N, 1)

			del_d = reshape(del_d,N,size(-w2:w2)[1])
			del_u = reshape(del_u,N,size(-w2:w2)[1])
			del_r = reshape(del_r,N,size(-w2+1:w2-1)[1])
			del_l = reshape(del_l,N,size(-w2+1:w2-1)[1])

	        down = zeros(Int64, N, size(del_d, 2))
	        up = zeros(Int64, N, size(del_u, 2))
	        
	        for k1 in range(1,size(del_d, 2))
				down[:, k1] = ni .+ del_d[:, k1]
	            up[:, k1] = ni .+ del_u[:, k1]
	        end
	        right = zeros(Int64, N, size(del_r, 2))
	        left = zeros(Int64, N, size(del_l, 2))
	        
	        for k2 in range(1,size(del_r, 2))
	            right[:, k2] = ni .+ del_r[:, k2]
	            left[:, k2] = ni .+ del_l[:, k2]
	        end
	        
	        mo = mod.(ni, Ly)
	        mor = mod.(right, Ly)
	        
	        sd1 = zeros(Int64, N, size(del_d, 2))
	        sd2 = zeros(Int64, N, size(del_d, 2))
	        
	        for k3 = 1:size(del_d, 2)
	            sd1[:, k3] = down[:, k3] .*((mo .<= Ly - w2) .& (mo .!= 0)) .*((down[:, k3] .> 0) .& (down[:, k3] .<= N))
	            sd2[:, k3] = up[:, k3] .*((mo .> w2) .| (mo .== 0)) .*((up[:, k3] .> 0) .& (up[:, k3] .<= N))
	        end
	        
	        sd3 = zeros(Int64, N, size(del_r, 2))
	        sd4 = zeros(Int64, N, size(del_r, 2))
	        
			kk4 = findall((mo .<= Ly/2) .& (mo .!= 0))
			kk5 = setdiff(1:N, kk4)
			
			for k4 = 1:size(del_r, 2)
			    sd3[kk4, k4] = right[kk4, k4] .* (((mor[kk4, k4] .> 0) .& (mor[kk4, k4] .< Ly-w2+1)) .& (right[kk4, k4] .> 0) .& (right[kk4, k4] .<= N))
			    sd3[kk5, k4] = right[kk5, k4] .* (((mor[kk5, k4] .== 0) .| (mor[kk5, k4] .> Ly/2)) .& (right[kk5, k4] .> 0) .& (right[kk5, k4] .<= N))
			    sd4[kk4, k4] = left[kk4, k4] .* (((mor[kk4, k4] .> 0) .& (mor[kk4, k4] .< Ly-w2+1)) .& (left[kk4, k4] .> 0) .& (left[kk4, k4] .<= N))
			    sd4[kk5, k4] = left[kk5, k4] .* (((mor[kk5, k4] .== 0) .| (mor[kk5, k4] .> Ly/2)) .& (left[kk5, k4] .> 0) .& (left[kk5, k4] .<= N))
			end
			
			d1 = Int64(median(1:m))
			restd = setdiff(1:m, d1)
			r1 = Int64(median(1:m-2))
			restr = setdiff(1:m-2, r1)
			
			SDm = hcat(sd1[:,d1], sd3[:,r1], sd2[:,d1], sd4[:,r1], sd1[:,restd], sd2[:,restd], sd3[:,restr], sd4[:,restr])
			
			SDm[SDm .== 0] .= N+1 # zeros are assigned index N+1
			push!(SD3,SDm)
		end
	return hcat(SD3[1],SD3[2])
end

# ╔═╡ 4a025285-0270-42e9-9fc2-28deaab9ab7a
function cost_f_ising_2D(Ind, N, Kp, Lp, SD)
    VN = 0
    np = 0
    
    tf = [k in Kp for k in SD[:, 1:2]]  # identifies present neareast neighbors in the neighborhood SD
    np = sum(sum(tf[Kp, 1:2]))  # number of bonds between present neareast neighbors
    
    SD[tf .== 0,:] .= N + 1
    new_size = N + 1
	new_Ind = Vector{Float64}(undef, new_size)
	new_Ind[1:N] = Ind
	new_Ind[N + 1] = 0
	Ind = new_Ind
    
    VN = dot(sum(Ind[SD[Kp, 1:2]], dims=2), Ind[Kp])
    VN = VN / np
end

# ╔═╡ 72708bc5-249c-4d50-b728-3224852866c3
function cost_vect_2D(Indc, N, VN, SD, sp)
    SN = 0
    
    Indc[N+1] = 0
    
    SN = dot(sum(Indc[SD[1:N-1, 1:2], :], dims=2), Indc[1:N-1])
    
    SN = SN / sp
    
    cf = (1 - SN/VN)^2
    
    return cf, SN, sp
end

# ╔═╡ f4045405-0317-4129-98d2-8c945594d346
function optim_innc(Ind, N, Lx, Ly, Lm, Lp, Km, Kp, SD3, sp, mcs, m_min, m_max0, qxLm)
    # Sample correlation energy
    if size(Ind, 2) == 1
        Ind = Ind'
    end
    VN = cost_f_ising_2D(Ind, N, Kp, Lp, SD3)

    cf = zeros(1, mcs) # initial cost function
    m_max = m_max0 # initial value of maximum stencil size

    Indm_pres = init_ising(Ind, Lx, Ly, Km, Kp, SD3, m_min, m_max)
    Indc_pres = zeros(N + 1)
    Indc_pres[Kp] = Ind[Kp]
    Indc_pres[Km] = Indm_pres
	
    # Calculation of initial values of cost function and simulation correlation energy
    cf_pres, SN_pres, sp = cost_vect_2D(Indc_pres, N, VN, SD3, sp)

	# Splitting the entire grid into 2 interpenetrating subgrids j1 and j2
	if Ly % 2 == 0
	    j1 = findall(((mod.(collect(1:N), 2) .== 1) .& (mod.(ceil.(collect(1:N) ./ Ly), 2) .== 1)) .| ((mod.(collect(1:N), 2) .== 0) .& (mod.(ceil.(collect(1:N) ./ Ly), 2) .== 0)))
	    j2 = setdiff(1:N, j1)
	else
	    j1 = findall(((mod.(collect(1:N), 2) .== 1) .& (mod.(ceil.((collect(1:N) ./ Ly)), 2) .== 1)) .| ((mod.(collect(1:N), 2) .== 1) .& (mod.(ceil.((collect(1:N) ./ Ly)), 2) .== 0)))
	    j2 = setdiff(1:N, j1)
	end

	# Subgrids on prediction points
	jp1 = intersect(j1, Km)
	jp2 = intersect(j2, Km)

    cf_bsf = cf_pres  # best-so-far value of cost function
    Indc_bsf = Indc_pres  # best so far configuration
    j_bsf = 0  # MC time of best so far configuration
    nac1 = 0  # number of non-accepted iterations on subgrid jp1 in a row
    nac2 = 0  # number of non-accepted iterations on subgrid jp2 in a row

	if SN_pres < VN
	    ii = 1
	    while (ii <= mcs) && ((nac1 == 0) || (nac2 == 0)) && (SN_pres - VN < 0)
	        # Update on subgrid jp1
	        if !isempty(jp1)
	            del_SN1 = zeros(length(jp1))
	            if length(jp1) > 1
				    aa = vcat(2 * sum(Indc_pres[SD3[jp1, 1:4]], dims=2)...)
				elseif length(jp1) == 1
				    aa = vcat(2 * sum(Indc_pres[SD3[jp1, 1:4]])...)
				end
				
				del_SN1 = del_SN1 + aa .* Indc_pres[jp1]
				del_SN1 = 2 * del_SN1 / sp
				if sum(del_SN1 .< 0) > 0
				    nac1 = 0
				    Indc_pres[jp1[del_SN1 .< 0]] = -Indc_pres[jp1[del_SN1 .< 0]]
				    D1 = sum(del_SN1[del_SN1 .< 0])
				    SN_pres = SN_pres - D1
				    cf_pres = (1 - SN_pres / VN)^2
				else
	                nac1 += 1
	            end
	        end
	        
	        # Update on subgrid jp2
	        
	        if !isempty(jp2)
	            del_SN2 = zeros(length(jp2))
	            if length(jp2) > 1
	                aa = 2 .* sum(Indc_pres[SD3[jp2, 1:4]], dims=2)
	            elseif length(jp2) == 1
	                aa = 2 .* sum(Indc_pres[SD3[jp2, 1:4]])
	            end
	            del_SN2 .= aa .* Indc_pres[jp2]
	            del_SN2 = 2 .* del_SN2 ./ sp
	
	            if sum(del_SN2 .< 0) > 0
	                nac2 = 0
	                Indc_pres[jp2[del_SN2 .< 0]] .= -Indc_pres[jp2[del_SN2 .< 0]]
	                D2 = sum(del_SN2[del_SN2 .< 0])
	                SN_pres -= D2
	                cf_pres = (1 - SN_pres / VN) ^ 2
	            else
	                nac2 += 1
	            end
	        end 
	        
	        # Saving best-so-far result
	        if cf_pres < cf_bsf
	            cf_bsf = cf_pres
	            Indc_bsf = Indc_pres
	            j_bsf = ii
	        end
	
	        cf[ii] = cf_pres
	
	        ii += 1
	    end
	
	else
	
	    ii = 1
	    while (ii <= mcs) && ((nac1 == 0) || (nac2 == 0)) && (SN_pres - VN > 0)
	        # Update on subgrid jp1
	        del_SN1 = zeros(length(jp1))
	        del_SN1 .= 2 .* sum(Indc_pres[SD3[jp1, 1:4]], dims=2) .* Indc_pres[jp1]
	        del_SN1 = 2 .* del_SN1 ./ sp
	
	        if sum(del_SN1 .> 0) > 0
	            nac1 = 0
	            Indc_pres[jp1[del_SN1 .> 0]] .= -Indc_pres[jp1[del_SN1 .> 0]]
	            D1 = sum(del_SN1[del_SN1 .> 0])
	            SN_pres -= D1
	            cf_pres = (1 - SN_pres / VN) ^ 2
	        else
	            nac1 += 1
	        end
	
	        # Update on subgrid jp2
	        del_SN2 = zeros(length(jp2))
	        del_SN2 .= 2 .* sum(Indc_pres[SD3[jp2, 1:4]], dims=2) .* Indc_pres[jp2]
	        del_SN2 = 2 .* del_SN2 ./ sp
	
	        if sum(del_SN2 .> 0) > 0
	            nac2 = 0
	            Indc_pres[jp2[del_SN2 .> 0]] .= -Indc_pres[jp2[del_SN2 .> 0]]
	            D2 = sum(del_SN2[del_SN2 .> 0])
	            SN_pres -= D2
	            cf_pres = (1 - SN_pres / VN) ^ 2
	        else
	            nac2 += 1
	        end
	
	        # Saving best so far result
	        if cf_pres < cf_bsf
	            cf_bsf = cf_pres
	            Indc_bsf = Indc_pres
	            j_bsf = ii
	        end
	
	        cf[ii] = cf_pres
	
	        ii += 1
	    end
	
	end
    return Indc_bsf, cf_bsf, j_bsf
end

# ╔═╡ c5efebe5-5032-41d9-b891-2e6166bf8079
function est_innc(zm=[]::Matrix{Float64}, q=0::Int, zo=[]::Matrix{Float64}, options=0)
    # Pelo menos os valores de zm e q devem ser informados
	if zm==[] && q==0
	    error("Pelo menos os valores de zm e q devem ser informados.")
	end
	
	if !(typeof(zm)==Matrix{Float64})
	    error("A entrada deve ser uma matriz numérica real.")
	end
	
	if any(isnan.(vec(zm))) == false
	    error("Nenhum ponto de previsão (NaN) encontrado.")
	end
	
	if !(q >= 2 && round(q) == q)
	    error("Q deve ser um inteiro positivo maior ou igual a 2.")
	end
	
	if zo==[]
	    zo = []
	end
	
	if options==0
	    options = (5,5,5,"regular")
	end
	m_max = options[1]
	nn = options[2]
	alp = options[3]
	qxLm = options[4]

	# Quantidades auxiliares
	m_min = 3 # Tamanho mínimo do stencil; NÃO ALTERAR!
	mcs = 1000 # Número máximo de sweeps MC
	Ly, Lx = size(zm) # Tamanhos do grid nas direções x e y
	N = Lx * Ly # Número total de pontos no grid
	sp = 2 * N - Lx - Ly # Número de vínculos com vizinhos mais próximos na grade completa
	
	# *************************************************************************
	# Gerando localizações de vizinhos do nó ni dentro do stencil M_MAX x M_MAX
	SD3 = neighb(m_min, m_max, Lx, Ly)
	
	# *************************************************************************
	# Encontrando valores ausentes (NaN) e de amostra
	Km0 = findall(isnan.(vec(zm))) # índices dos dados ausentes
	Kp0 = findall(isfinite.(vec(zm))) # índices dos dados de amostra
	Lm0 = length(Km0) # número de dados ausentes
	Lp0 = length(Kp0) # número de dados de amostra
	# *************************************************************************
	# Definindo os limiares de desqualificação zc dividindo as amostras em Q bins
	Mn = minimum(zm[Kp0])  # mínimo valor das amostras
	Mx = maximum(zm[Kp0])  # máximo valor das amostras
	R = Mx - Mn  # faixa de valores das amostras
	bin = R / q

	zc = similar(Vector{eltype(zm)}, q)  # vetor para armazenar os limiares de discretização

	for i in 1:q
	    zc[i] = Mn + i*bin
	end
	
	# Estatísticas zeradas
	INDZ = zeros(N, nn)
	INDS = zeros(N, nn)
	TT = zeros(1, nn)
	MCSbsf = zeros(q-1, nn)
	CFbsf = zeros(q-1, nn)
	
	if isempty(zo) == false
	    PRM = zeros(1, nn)
	    MAE = zeros(1, nn)
	    MRE = zeros(1, nn)
	    MARE = zeros(1, nn)
	    RMSE = zeros(1, nn)
	    COR = zeros(1, nn)
	end
	
	# discretização de dados reais (se disponíveis) com respeito ao vetor ZC
	if !isempty(zo)
	    so = discr_potts(zo, zc)
	end
	
	# Sample values with missing data
	sm = discr_potts(zm, zc)
	

	# Monte Carlo simulations
	for rfr in 1:nn
	    
	    zr = NaN .* ones(length(zm))
	    
	    for j in Kp0
	        zr[j] = zc[sm[j]] - 0.5 * bin
	    end
	    sr = sm[:]
	    kr = Km0

	    for i in 1:q-1
	        # Finding missing (NaN) and known values at each discretization level I={1,...,Q}
	        # The missing values estimated at each level are being gradually
	        # filled, thus decreasing number of (NaN) points
	        Km = findall(isnan.(zr))  # indices of missing data at level I
	        Kp = findall(isfinite.(zr))  # indices of known data at level I
	        Lm = length(Km)  # number of missing data at level I
	        Lp = length(Kp)  # number of present data at level I
	        
	        # Returns binary Ising data
	        Indr = discr_ising(zr, zc[i])
	        
	        if size(Indr, 2) == 1
	            Indr = Indr'
	        end

			# Optimization
			if Lm > 0
			    global Indri, mcs_bsf, cf_bsf = optim_innc(Indr, N, Lx, Ly, Lm, Lp, Km, Kp, SD3, sp, mcs, m_min, m_max, qxLm)
				
			    # INDRI - reconstructed Ising data at level I (estimates and samples)
			    CFbsf[i, rfr] = cf_bsf
			    MCSbsf[i, rfr] = mcs_bsf
			else
			    continue
			end

			# Back-transformation of estimated spin data to the original scale
			for j in kr
			    if Indri[j] == -1
			        Indr[j] = -1
			        zr[j] = zc[i] - 0.5 * bin
			        sr[j] = i
			    end
			end
			kr = findall(isnan.(zr))
			
			if i == q - 1
			    Indr[kr] .= 1
			    zr[kr] .= zc[i] + 0.5 * bin
			    sr[kr] .= q
			end
		end
	
		if length(findall(isnan.(zr))) > 0
		    zr[findall(isnan.(zr))] = zc[q]
		    sr[findall(isnan.(zr))] = q
		end
		
		INDZ[:, rfr] = zr
		INDS[:, rfr] = sr
		
		# Optimization indicators
		CFbsf[rfr] = cf_bsf
		MCSbsf[rfr] = mcs_bsf
	end
	# STATISTICS COLLECTED FROM NN REALIZATIONS

	if nn > 1
    	n = size(INDS', 2)  # número de colunas em INDS
		sr = similar(INDS', (3, n))  # matriz para armazenar os percentis
		
		for i in 1:n
		    sr[:, i] = quantile(INDS'[:, i], [alp/100, 0.5, 1 - alp/100])
		end
		
		sr = permutedims(sr)'
	else
	    sr = repeat(INDS', inner = (3, 1))
	end
	
	sr_med = round.(Int,sr[2, :] .+ 0.5 .* ones(size(sr[2, :])) .- rand(Float64,size(sr[2, :])))
	sr_low = round.(Int,sr[1, :] .+ 0.5 .* ones(size(sr[1, :])) .- rand(Float64,size(sr[1, :])))
	sr_up = round.(Int,sr[3, :] .+ 0.5 .* ones(size(sr[3, :])) .- rand(Float64,size(sr[3, :])))
	
	sr_med = reshape(sr_med, Ly, Lx)
	sr_low = reshape(sr_low, Ly, Lx)
	sr_up = reshape(sr_up, Ly, Lx)

	zr_med = similar(zc, N)
	zr_low = similar(zc, N)
	zr_up = similar(zc, N)
	for j in 1:N
		zr_med[j] = zc[sr_med[j]] - 0.5 * bin
		zr_low[j] = zc[sr_low[j]] - 0.5 * bin
		zr_up[j] = zc[sr_up[j]] - 0.5 * bin
	end
	
	zr_med = reshape(zr_med, Ly, Lx)
	zr_low = reshape(zr_low, Ly, Lx)
	zr_up = reshape(zr_up, Ly, Lx)
	
	sweeps = mean(sum(MCSbsf, dims=1))  # mean number of MC sweeps needed for reaching optimum
	cost = mean(mean(CFbsf, dims=(1, 2)))  # mean residual value of the cost function
	return zr_med, zr_low, zr_up, sweeps, cost
end

# ╔═╡ 7a7987bc-6ce3-4d50-8ffd-7d988739f947
function df2matrix(data, X, Y, var, pointsize=1)
	# Valores máximos das coordenadas X e Y
	max_X = round(Int, data[:,X] |> maximum)
	max_Y = round(Int, data[:,Y] |> maximum)
	# Valores mínimos das coordenadas X e Y
	
	# Tamanho dos metros (resolução)
	tamanho_metro = pointsize
	
	# Calcular as dimensões da matriz
	dim_X = round(Int,((max_X) / tamanho_metro),RoundUp)
	dim_Y = round(Int,((max_Y) / tamanho_metro),RoundUp)
	
	# Criar a matriz preenchida com zeros
	matriz = zeros(dim_X, dim_Y)*NaN
	
	# Percorrer os dados e atribuir os valores de Cu à matriz
	for i = 1:size(data, 1)
	    x = data[i, X]
	    y = data[i, Y]
	    value = data[i, var]
	    # Calcular as coordenadas na matriz
	    col = round(Int, (x / tamanho_metro),RoundUp)
	    row = round(Int, (y / tamanho_metro),RoundUp)
		if col > 0 && row > 0
		    # Atribuir o valor de Cu à matriz
		    matriz[col, row] = value
		end
	end
	return matriz
end

# ╔═╡ cabd97ba-a3a0-400d-a788-75a2aa8aabb0
md"### Importando os dados utilizados"

# ╔═╡ b16f0882-61e1-4be7-ade1-3618b061af55
begin
	z = CSV.File("dataset_HRISTROPULOS_1.csv", header = false)|> DataFrame |> Matrix
	zo = CSV.File("dataset_HRISTROPULOS_2.csv", header = false) |> DataFrame |> Matrix
	z_matlab = CSV.File("dataset_HRISTROPULOS_3.csv", header = false) |> DataFrame |> Matrix
end;

# ╔═╡ b4b0fc38-bb7a-44fa-9de6-0f613a904c12
begin
	dh_10 = DataFrame(CSV.File("dataset_DIAMANTINO_2.csv"))
	local x = []
	local y = []
	dh_10.X = round.(dh_10.X, RoundUp)
	dh_10.Y = round.(dh_10.Y, RoundUp)
	for i in dh_10.X
		if i == 1
			append!(x,1)
		else
			push!(x,(round(i/10,RoundUp)))
		end
	end
	for j in dh_10.Y
		if j == 1
			push!(y,1)
		else
			push!(y,(round(j/10,RoundUp)))
		end
	end
	dh_10 = DataFrame(Z= dh_10.Z, X= Int.(x), Y= Int.(y))
end

# ╔═╡ abfd6a59-7e59-43ef-ab70-1de70ab477fd
begin
	dh_30 = DataFrame(CSV.File("dataset_DIAMANTINO_1.csv"))
	local x = []
	local y = []
	dh_30.X = round.(dh_30.X, RoundUp)
	dh_30.Y = round.(dh_30.Y, RoundUp)
	for i in dh_30.X
		if i == 1
			append!(x,1)
		else
			push!(x,(round(i/30,RoundUp)+1))
		end
	end
	for j in dh_30.Y
		if j == 1
			push!(y,1)
		else
			push!(y,(round(j/30,RoundUp)+1))
		end
	end
	dh_30 = DataFrame(Z= dh_30.Z, X= Int.(x), Y= Int.(y))
end

# ╔═╡ 5f4412c5-e6d5-4deb-875f-496fc79fdf4d
md"### Definição de funções para aplicação"

# ╔═╡ acb3b817-38aa-4653-9842-7b9d75269229
function erro(real, modelo)
	MAE = round(sum(abs.(real.-modelo))/length(real),digits=2)
	MSE = round(sum((real .- modelo).^2)/length(real), digits=2)
	SMSE = round(sqrt(MSE), digits = 2)
	return MAE,MSE,SMSE
end

# ╔═╡ d83f4168-6044-4c54-ac27-bd22fb387858
function replace_with_nan(matrix, n_nan)
    total_elements = length(matrix)
    num_elements_to_replace = Int64(round(n_nan * total_elements))

	# Cria uma cópia da matriz original
    new_matrix = copy(matrix)

    # Gera uma lista aleatória de índices únicos
    indices_to_replace = randperm(total_elements)[1:num_elements_to_replace]

    # Substitui os elementos correspondentes por NaN
    new_matrix[indices_to_replace] .= NaN

    return new_matrix
end

# ╔═╡ e148391d-d8af-4a94-b231-f78668ac8bad
z_med = est_innc(z,50,zo)[1]

# ╔═╡ bf23da55-5cb8-4bee-8c7d-d7766048f030
dh_30m = df2matrix(dh_30,:X,:Y,:Z)

# ╔═╡ ae91c093-95ea-4258-8e28-849746f70b74
dh_10m = df2matrix(dh_10,:X,:Y,:Z)

# ╔═╡ 7eff5ba1-603e-4b8d-9bcf-fc4305cffba0
md"### Verificação da funcionalidade do código"

# ╔═╡ 45c49de8-75ef-40fd-ab06-838deb27e123
begin
	p1 = contourf(zo, title = "Dados Inicias sem elementos faltantes")
	p2 = contourf(z_med, title = "Resultado da função")
	plot(p1,p2)
end

# ╔═╡ 8547d7c3-e03c-4fba-9d05-043e07c37c2d
begin
	test_zo = isnan.(z);
	mae_zo,mse_zo,smse_zo = erro(zo[test_zo], z_med[test_zo])
	
	scatter(zo[test_zo],z_med[test_zo], title = "ZO vs Z_MED",label = "MAE = $(mae_zo), MSE = $(mse_zo)", leg = :right)
	plot!(zo[test_zo],zo[test_zo], label = false)
end

# ╔═╡ 4bd2a0ee-b1e8-4b84-859b-b6f3f9052345
begin
	mae_mat,mse_mat,smse_mat = erro(z_matlab[test_zo], z_med[test_zo])
	qqplot(vec(round.(z_matlab,digits=2)), vec(round.(z_med,digits=2)), xlabel = "Estivativa Matlab", ylabel = "Estimativa Julia")
end

# ╔═╡ b3b15f54-0528-49f3-a84e-02ffd4da62c8
md"##### $(count(vec(round.(z_matlab,digits=2)) .== vec(round.(z_med,digits=2)))) valores idênticos, de 2500"

# ╔═╡ 4d0c1cdf-9a86-47ea-9a33-5ce8b883f148
md"### Estimativas INNC"

# ╔═╡ 299a4158-9d9d-43fd-a73f-39d433c18edd
function evaluate_ising(dh_m)
	med = []
	plots = []
	p_erro = []
	local results = []
	for i in range(start=0.9,stop=0.4,step=-0.1)
		m = replace_with_nan(dh_m,i)
		ising = est_innc(m,100,dh_m)[1]
		test = isnan.(m)
		n = length(m[isfinite.(m)])
		p_estimados = length(m[test])
		mae_ising, mse_ising,smse_ising = erro(dh_m[test], ising[test])
		push!(results, (AMOSTRAS = "$(round(Int,(1-i)*100))%",
					    N_AMOSTRAS = n,
						N_ESTIMADOS = p_estimados,
						MAE = mae_ising,
						MSE = mse_ising,
						SMSE = smse_ising)
		)
		push!(med,ising)
		pl = qqplot(vec(dh_m[test]), vec(ising[test]), title = "$(round(Int,(1-i)*100))%")
		push!(plots,pl)
		p_e = contourf(abs.(dh_m .- ising), title = "$(round(Int,(1-i)*100))%", c = :viridis)
		push!(p_erro,p_e)
	end
	df_dh = DataFrame(results)
	return df_dh,med,plots,p_erro
end

# ╔═╡ 1f40de7c-0cb6-4bd2-902f-be360eec5106
df_30m, ising_30m, qqplot_30m, p_erro30m = evaluate_ising(dh_30m);

# ╔═╡ 9b6b4c5e-e532-4a26-93c2-55dbb15c631e
df_10m, ising_10m, qqplot_10m, p_erro10m = evaluate_ising(dh_10m);

# ╔═╡ 0466b3c8-eeb5-4c7b-961b-406f885ebc11
md"#### Blocos 30x30"

# ╔═╡ 01122926-9af4-48f6-953a-87170920d5c5
begin
	@df dh_30 histogram(:Z, bins = 30, label = false, color = :gray90, alpha  = 0.75, xlabel = "Z", ylabel = "Frequência Absoluta", xticks = range(start=0, step=1,stop=15))
	@df dh_30 vline!([mean(:Z)], lw = 3, label = "Média")
	@df dh_30 vline!([median(:Z)], lw = 3, label = "Mediana")
	@df dh_30 vline!([quantile(:Z,0.1)], lw = 3, label = "P10", ls = :dashdot, c = :gray)
	@df dh_30 vline!([quantile(:Z,0.9)], lw = 3, label = "P90", ls = :dashdot, c = :gray)
end

# ╔═╡ a59bba9b-34f0-4cbc-8f5a-253f5f00770b
df_30m

# ╔═╡ 1e79d08c-bb10-49f2-b960-ae1710c5e725
plot(df_30m[:,:AMOSTRAS], df_30m[:,:MAE], xlabel = "% de Amostras", ylabel = "MAE", label = false)

# ╔═╡ e34ed282-c15c-4562-bcb9-0d9271130621
plot(qqplot_30m..., layout=(2,3))

# ╔═╡ a550cb39-2d05-4208-a123-84cc2f36967f
plot(p_erro30m..., layout=(2,3))

# ╔═╡ a30b8bd8-2a00-4276-8e80-b8438ab3569c
md"### Blocos 10x10"

# ╔═╡ df47c019-c8e0-4b2e-8eb3-0cbb0df2b5e3
begin
	@df dh_10 histogram(:Z, bins = 30, label = false, color = :gray90, alpha  = 0.75, xlabel = "Z", ylabel = "Frequência Absoluta", xticks = range(start=0, step=1,stop=15))
	@df dh_10 vline!([mean(:Z)], lw = 3, label = "Média")
	@df dh_10 vline!([median(:Z)], lw = 3, label = "Mediana")
	@df dh_10 vline!([quantile(:Z,0.1)], lw = 3, label = "P10", ls = :dashdot, c = :gray)
	@df dh_10 vline!([quantile(:Z,0.9)], lw = 3, label = "P90", ls = :dashdot, c = :gray)
end

# ╔═╡ e5869534-483b-4b37-8ff2-28f74cf3497b
df_10m

# ╔═╡ c4b66ff3-a44e-4ee5-aa5f-73fc8903214d
plot(df_10m[:,:AMOSTRAS], df_10m[:,:MAE], xlabel = "% de Amostras", ylabel = "MAE", label = false)

# ╔═╡ f547b374-cdc9-4bbe-a110-58723d74e9db
plot(qqplot_10m..., layout=(2,3))

# ╔═╡ 1e8448a4-3ff1-4424-97a3-2bfc116db2b1
plot(p_erro10m..., layout=(2,3))

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
CSV = "336ed68f-0bac-5ca0-87d4-7b16caf5d00b"
DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
Distributions = "31c24e10-a181-5473-b8eb-7969acd0382f"
LinearAlgebra = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
Plots = "91a5bcdd-55d7-5caf-9e0b-520d859cae80"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
Random = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"
Statistics = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
StatsPlots = "f3b207a7-027a-5e70-b257-86293d7955fd"
TableIO = "8545f849-0b94-433a-9b3f-37e40367303d"

[compat]
CSV = "~0.10.11"
DataFrames = "~1.5.0"
Distributions = "~0.25.97"
Plots = "~1.38.16"
PlutoUI = "~0.7.51"
StatsPlots = "~0.15.5"
TableIO = "~0.4.1"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.9.1"
manifest_format = "2.0"
project_hash = "6f00277453a0c52c1527eb5686ddcd3d328638cc"

[[deps.AbstractFFTs]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "8bc0aaec0ca548eb6cf5f0d7d16351650c1ee956"
uuid = "621f4979-c628-5d54-868e-fcf4e3e8185c"
version = "1.3.2"
weakdeps = ["ChainRulesCore"]

    [deps.AbstractFFTs.extensions]
    AbstractFFTsChainRulesCoreExt = "ChainRulesCore"

[[deps.AbstractPlutoDingetjes]]
deps = ["Pkg"]
git-tree-sha1 = "8eaf9f1b4921132a4cff3f36a1d9ba923b14a481"
uuid = "6e696c72-6542-2067-7265-42206c756150"
version = "1.1.4"

[[deps.Adapt]]
deps = ["LinearAlgebra", "Requires"]
git-tree-sha1 = "76289dc51920fdc6e0013c872ba9551d54961c24"
uuid = "79e6a3ab-5dfb-504d-930d-738a2a938a0e"
version = "3.6.2"
weakdeps = ["StaticArrays"]

    [deps.Adapt.extensions]
    AdaptStaticArraysExt = "StaticArrays"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.1"

[[deps.Arpack]]
deps = ["Arpack_jll", "Libdl", "LinearAlgebra", "Logging"]
git-tree-sha1 = "9b9b347613394885fd1c8c7729bfc60528faa436"
uuid = "7d9fca2a-8960-54d3-9f78-7d1dccf2cb97"
version = "0.5.4"

[[deps.Arpack_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "OpenBLAS_jll", "Pkg"]
git-tree-sha1 = "5ba6c757e8feccf03a1554dfaf3e26b3cfc7fd5e"
uuid = "68821587-b530-5797-8361-c406ea357684"
version = "3.5.1+1"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[deps.AxisAlgorithms]]
deps = ["LinearAlgebra", "Random", "SparseArrays", "WoodburyMatrices"]
git-tree-sha1 = "66771c8d21c8ff5e3a93379480a2307ac36863f7"
uuid = "13072b0f-2c55-5437-9ae7-d433b7a33950"
version = "1.0.1"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[deps.BitFlags]]
git-tree-sha1 = "43b1a4a8f797c1cddadf60499a8a077d4af2cd2d"
uuid = "d1d4a3ce-64b1-5f1a-9ba4-7e7e69966f35"
version = "0.1.7"

[[deps.Bzip2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "19a35467a82e236ff51bc17a3a44b69ef35185a2"
uuid = "6e34b625-4abd-537c-b88f-471c36dfa7a0"
version = "1.0.8+0"

[[deps.CSV]]
deps = ["CodecZlib", "Dates", "FilePathsBase", "InlineStrings", "Mmap", "Parsers", "PooledArrays", "PrecompileTools", "SentinelArrays", "Tables", "Unicode", "WeakRefStrings", "WorkerUtilities"]
git-tree-sha1 = "44dbf560808d49041989b8a96cae4cffbeb7966a"
uuid = "336ed68f-0bac-5ca0-87d4-7b16caf5d00b"
version = "0.10.11"

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

[[deps.ChainRulesCore]]
deps = ["Compat", "LinearAlgebra", "SparseArrays"]
git-tree-sha1 = "e30f2f4e20f7f186dc36529910beaedc60cfa644"
uuid = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
version = "1.16.0"

[[deps.Clustering]]
deps = ["Distances", "LinearAlgebra", "NearestNeighbors", "Printf", "Random", "SparseArrays", "Statistics", "StatsBase"]
git-tree-sha1 = "42fe66dbc8f1d09a44aa87f18d26926d06a35f84"
uuid = "aaaa29a8-35af-508c-8bc3-b662a17a0fe5"
version = "0.15.3"

[[deps.CodecZlib]]
deps = ["TranscodingStreams", "Zlib_jll"]
git-tree-sha1 = "9c209fb7536406834aa938fb149964b985de6c83"
uuid = "944b1d66-785c-5afd-91f1-9de20f533193"
version = "0.7.1"

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

[[deps.Compat]]
deps = ["UUIDs"]
git-tree-sha1 = "4e88377ae7ebeaf29a047aa1ee40826e0b708a5d"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "4.7.0"
weakdeps = ["Dates", "LinearAlgebra"]

    [deps.Compat.extensions]
    CompatLinearAlgebraExt = "LinearAlgebra"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
version = "1.0.2+0"

[[deps.ConcurrentUtilities]]
deps = ["Serialization", "Sockets"]
git-tree-sha1 = "96d823b94ba8d187a6d8f0826e731195a74b90e9"
uuid = "f0e56b4a-5159-44fe-b623-3e5288b988bb"
version = "2.2.0"

[[deps.ConstructionBase]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "738fec4d684a9a6ee9598a8bfee305b26831f28c"
uuid = "187b0558-2788-49d3-abe0-74a17ed4e7c9"
version = "1.5.2"

    [deps.ConstructionBase.extensions]
    ConstructionBaseIntervalSetsExt = "IntervalSets"
    ConstructionBaseStaticArraysExt = "StaticArrays"

    [deps.ConstructionBase.weakdeps]
    IntervalSets = "8197267c-284f-5f27-9208-e0e47529a953"
    StaticArrays = "90137ffa-7385-5640-81b9-e52037218182"

[[deps.Contour]]
git-tree-sha1 = "d05d9e7b7aedff4e5b51a029dced05cfb6125781"
uuid = "d38c429a-6771-53c6-b99e-75d170b6e991"
version = "0.6.2"

[[deps.Crayons]]
git-tree-sha1 = "249fe38abf76d48563e2f4556bebd215aa317e15"
uuid = "a8cc5b0e-0ffa-5ad4-8c14-923d3ee1735f"
version = "4.1.1"

[[deps.DataAPI]]
git-tree-sha1 = "8da84edb865b0b5b0100c0666a9bc9a0b71c553c"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.15.0"

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

[[deps.DelimitedFiles]]
deps = ["Mmap"]
git-tree-sha1 = "9e2f36d3c96a820c678f2f1f1782582fcf685bae"
uuid = "8bb1440f-4735-579b-a4ab-409b98df4dab"
version = "1.9.1"

[[deps.Distances]]
deps = ["LinearAlgebra", "SparseArrays", "Statistics", "StatsAPI"]
git-tree-sha1 = "49eba9ad9f7ead780bfb7ee319f962c811c6d3b2"
uuid = "b4f34e82-e78d-54a5-968a-f98e89d6e8f7"
version = "0.10.8"

[[deps.Distributed]]
deps = ["Random", "Serialization", "Sockets"]
uuid = "8ba89e20-285c-5b6f-9357-94700520ee1b"

[[deps.Distributions]]
deps = ["FillArrays", "LinearAlgebra", "PDMats", "Printf", "QuadGK", "Random", "SparseArrays", "SpecialFunctions", "Statistics", "StatsAPI", "StatsBase", "StatsFuns", "Test"]
git-tree-sha1 = "db40d3aff76ea6a3619fdd15a8c78299221a2394"
uuid = "31c24e10-a181-5473-b8eb-7969acd0382f"
version = "0.25.97"

    [deps.Distributions.extensions]
    DistributionsChainRulesCoreExt = "ChainRulesCore"
    DistributionsDensityInterfaceExt = "DensityInterface"

    [deps.Distributions.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    DensityInterface = "b429d917-457f-4dbc-8f4c-0cc954292b1d"

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

[[deps.ExceptionUnwrapping]]
deps = ["Test"]
git-tree-sha1 = "e90caa41f5a86296e014e148ee061bd6c3edec96"
uuid = "460bff9d-24e4-43bc-9d9f-a8973cb893f4"
version = "0.1.9"

[[deps.Expat_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "4558ab818dcceaab612d1bb8c19cee87eda2b83c"
uuid = "2e619515-83b5-522b-bb60-26c02a35a201"
version = "2.5.0+0"

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
git-tree-sha1 = "b4fbdd20c889804969571cc589900803edda16b7"
uuid = "7a1cc6ca-52ef-59f5-83cd-3a7055c09341"
version = "1.7.1"

[[deps.FFTW_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "c6033cc3892d0ef5bb9cd29b7f2f0331ea5184ea"
uuid = "f5851436-0d7a-5f13-b9de-f02708fd171a"
version = "3.3.10+0"

[[deps.FilePathsBase]]
deps = ["Compat", "Dates", "Mmap", "Printf", "Test", "UUIDs"]
git-tree-sha1 = "e27c4ebe80e8699540f2d6c805cc12203b614f12"
uuid = "48062228-2e41-5def-b9a4-89aafe57970f"
version = "0.9.20"

[[deps.FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"

[[deps.FillArrays]]
deps = ["LinearAlgebra", "Random", "SparseArrays", "Statistics"]
git-tree-sha1 = "0b3b52afd0f87b0a3f5ada0466352d125c9db458"
uuid = "1a297f60-69ca-5386-bcde-b61e274b549b"
version = "1.2.1"

[[deps.FixedPointNumbers]]
deps = ["Statistics"]
git-tree-sha1 = "335bfdceacc84c5cdf16aadc768aa5ddfc5383cc"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.4"

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

[[deps.FreeType2_jll]]
deps = ["Artifacts", "Bzip2_jll", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "87eb71354d8ec1a96d4a7636bd57a7347dde3ef9"
uuid = "d7e528f0-a631-5988-bf34-fe36492bcfd7"
version = "2.10.4+0"

[[deps.FriBidi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "aa31987c2ba8704e23c6c8ba8a4f769d5d7e4f91"
uuid = "559328eb-81f9-559d-9380-de523a88c83c"
version = "1.0.10+0"

[[deps.Future]]
deps = ["Random"]
uuid = "9fa8497b-333b-5362-9e8d-4d0656e87820"

[[deps.GLFW_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libglvnd_jll", "Pkg", "Xorg_libXcursor_jll", "Xorg_libXi_jll", "Xorg_libXinerama_jll", "Xorg_libXrandr_jll"]
git-tree-sha1 = "d972031d28c8c8d9d7b41a536ad7bb0c2579caca"
uuid = "0656b61e-2033-5cc2-a64a-77c0f6c09b89"
version = "3.3.8+0"

[[deps.GR]]
deps = ["Artifacts", "Base64", "DelimitedFiles", "Downloads", "GR_jll", "HTTP", "JSON", "Libdl", "LinearAlgebra", "Pkg", "Preferences", "Printf", "Random", "Serialization", "Sockets", "TOML", "Tar", "Test", "UUIDs", "p7zip_jll"]
git-tree-sha1 = "8b8a2fd4536ece6e554168c21860b6820a8a83db"
uuid = "28b8d3ca-fb5f-59d9-8090-bfdbd6d07a71"
version = "0.72.7"

[[deps.GR_jll]]
deps = ["Artifacts", "Bzip2_jll", "Cairo_jll", "FFMPEG_jll", "Fontconfig_jll", "GLFW_jll", "JLLWrappers", "JpegTurbo_jll", "Libdl", "Libtiff_jll", "Pixman_jll", "Qt5Base_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "19fad9cd9ae44847fe842558a744748084a722d1"
uuid = "d2c73de3-f751-5644-a686-071e5b155ba9"
version = "0.72.7+0"

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

[[deps.Graphite2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "344bf40dcab1073aca04aa0df4fb092f920e4011"
uuid = "3b182d85-2403-5c21-9c21-1e1f0cc25472"
version = "1.3.14+0"

[[deps.Grisu]]
git-tree-sha1 = "53bb909d1151e57e2484c3d1b53e19552b887fb2"
uuid = "42e2da0e-8278-4e71-bc24-59509adca0fe"
version = "1.0.2"

[[deps.HTTP]]
deps = ["Base64", "CodecZlib", "ConcurrentUtilities", "Dates", "ExceptionUnwrapping", "Logging", "LoggingExtras", "MbedTLS", "NetworkOptions", "OpenSSL", "Random", "SimpleBufferStream", "Sockets", "URIs", "UUIDs"]
git-tree-sha1 = "2613d054b0e18a3dea99ca1594e9a3960e025da4"
uuid = "cd3eb016-35fb-5094-929b-558a96fad6f3"
version = "1.9.7"

[[deps.HarfBuzz_jll]]
deps = ["Artifacts", "Cairo_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "Graphite2_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Pkg"]
git-tree-sha1 = "129acf094d168394e80ee1dc4bc06ec835e510a3"
uuid = "2e76f6c2-a576-52d4-95c1-20adfe4de566"
version = "2.8.1+1"

[[deps.HypergeometricFunctions]]
deps = ["DualNumbers", "LinearAlgebra", "OpenLibm_jll", "SpecialFunctions"]
git-tree-sha1 = "0ec02c648befc2f94156eaef13b0f38106212f3f"
uuid = "34004b35-14d8-5ef3-9330-4cdb6864b03a"
version = "0.3.17"

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
git-tree-sha1 = "d75853a0bdbfb1ac815478bacd89cd27b550ace6"
uuid = "b5f81e59-6552-4d32-b1f0-c071b021bf89"
version = "0.2.3"

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

[[deps.InvertedIndices]]
git-tree-sha1 = "0dc7b50b8d436461be01300fd8cd45aa0274b038"
uuid = "41ab1584-1d38-5bbf-9106-f11c6c58b48f"
version = "1.3.0"

[[deps.IrrationalConstants]]
git-tree-sha1 = "630b497eafcc20001bba38a4651b327dcfc491d2"
uuid = "92d709cd-6900-40b7-9082-c6be49f344b6"
version = "0.2.2"

[[deps.IteratorInterfaceExtensions]]
git-tree-sha1 = "a3f24677c21f5bbe9d2a714f95dcd58337fb2856"
uuid = "82899510-4779-5014-852e-03e436cf321d"
version = "1.0.0"

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

[[deps.JpegTurbo_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "6f2675ef130a300a112286de91973805fcc5ffbc"
uuid = "aacddb02-875f-59d6-b918-886e6ef4fbf8"
version = "2.1.91+0"

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

[[deps.LLVMOpenMP_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "f689897ccbe049adb19a065c495e75f372ecd42b"
uuid = "1d63c593-3942-5779-bab2-d838dc0a180e"
version = "15.0.4+0"

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
git-tree-sha1 = "f428ae552340899a935973270b8d98e5a31c49fe"
uuid = "23fbe1c1-3f47-55db-b15f-69d7ec21a316"
version = "0.16.1"

    [deps.Latexify.extensions]
    DataFramesExt = "DataFrames"
    SymEngineExt = "SymEngine"

    [deps.Latexify.weakdeps]
    DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
    SymEngine = "123dc426-2d89-5057-bbad-38513e3affd8"

[[deps.LazyArtifacts]]
deps = ["Artifacts", "Pkg"]
uuid = "4af54fe1-eca0-43a8-85a7-787d91b784e3"

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
deps = ["Libdl", "OpenBLAS_jll", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[deps.LogExpFunctions]]
deps = ["DocStringExtensions", "IrrationalConstants", "LinearAlgebra"]
git-tree-sha1 = "c3ce8e7420b3a6e071e0fe4745f5d4300e37b13f"
uuid = "2ab3a3ac-af41-5b50-aa03-7779005ae688"
version = "0.3.24"

    [deps.LogExpFunctions.extensions]
    LogExpFunctionsChainRulesCoreExt = "ChainRulesCore"
    LogExpFunctionsChangesOfVariablesExt = "ChangesOfVariables"
    LogExpFunctionsInverseFunctionsExt = "InverseFunctions"

    [deps.LogExpFunctions.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    ChangesOfVariables = "9e997f8a-9a97-42d5-a9f1-ce6bfc15e2c0"
    InverseFunctions = "3587e190-3f89-42d0-90ee-14403ec27112"

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
git-tree-sha1 = "154d7aaa82d24db6d8f7e4ffcfe596f40bff214b"
uuid = "856f044c-d86e-5d09-b602-aeab76dc8ba7"
version = "2023.1.0+0"

[[deps.MacroTools]]
deps = ["Markdown", "Random"]
git-tree-sha1 = "42324d08725e200c23d4dfb549e0d5d89dede2d2"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.10"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[deps.MbedTLS]]
deps = ["Dates", "MbedTLS_jll", "MozillaCACerts_jll", "Random", "Sockets"]
git-tree-sha1 = "03a9b9718f5682ecb107ac9f7308991db4ce395b"
uuid = "739be429-bea8-5141-9913-cc70e7f3736d"
version = "1.1.7"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"
version = "2.28.2+0"

[[deps.Measures]]
git-tree-sha1 = "c13304c81eec1ed3af7fc20e75fb6b26092a1102"
uuid = "442fdcdd-2543-5da2-b0f3-8c86c306513e"
version = "0.3.2"

[[deps.Missings]]
deps = ["DataAPI"]
git-tree-sha1 = "f66bdc5de519e8f8ae43bdc598782d35a25b1272"
uuid = "e1d29d7a-bbdc-5cf2-9ac0-f12de2c33e28"
version = "1.1.0"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"
version = "2022.10.11"

[[deps.MultivariateStats]]
deps = ["Arpack", "LinearAlgebra", "SparseArrays", "Statistics", "StatsAPI", "StatsBase"]
git-tree-sha1 = "68bf5103e002c44adfd71fea6bd770b3f0586843"
uuid = "6f286f6a-111f-5878-ab1e-185364afe411"
version = "0.10.2"

[[deps.NaNMath]]
deps = ["OpenLibm_jll"]
git-tree-sha1 = "0877504529a3e5c3343c6f8b4c0381e57e4387e4"
uuid = "77ba4419-2d1f-58cd-9bb1-8ffee604a2e3"
version = "1.0.2"

[[deps.NearestNeighbors]]
deps = ["Distances", "StaticArrays"]
git-tree-sha1 = "2c3726ceb3388917602169bed973dbc97f1b51a8"
uuid = "b8a86587-4115-5ab1-83bc-aa920d37bbce"
version = "0.4.13"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"
version = "1.2.0"

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

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"
version = "0.3.21+4"

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
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "1aa4b74f80b01c6bc2b89992b861b5f210e665b5"
uuid = "458c3c95-2e84-50aa-8efc-19380b2a3a95"
version = "1.1.21+0"

[[deps.OpenSpecFun_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "13652491f6856acfd2db29360e1bbcd4565d04f1"
uuid = "efe28fd5-8261-553b-a9e1-b2916fc3738e"
version = "0.5.5+0"

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
version = "10.42.0+0"

[[deps.PDMats]]
deps = ["LinearAlgebra", "SparseArrays", "SuiteSparse"]
git-tree-sha1 = "67eae2738d63117a196f497d7db789821bce61d1"
uuid = "90014a1f-27ba-587c-ab20-58faa44d9150"
version = "0.11.17"

[[deps.Parsers]]
deps = ["Dates", "PrecompileTools", "UUIDs"]
git-tree-sha1 = "4b2e829ee66d4218e0cef22c0a64ee37cf258c29"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.7.1"

[[deps.Pipe]]
git-tree-sha1 = "6842804e7867b115ca9de748a0cf6b364523c16d"
uuid = "b98c9c47-44ae-5843-9183-064241ee97a0"
version = "1.3.0"

[[deps.Pixman_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "LLVMOpenMP_jll", "Libdl"]
git-tree-sha1 = "64779bc4c9784fee475689a1752ef4d5747c5e87"
uuid = "30392449-352a-5448-841d-b1acce4e97dc"
version = "0.42.2+0"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "FileWatching", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
version = "1.9.0"

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
deps = ["Base64", "Contour", "Dates", "Downloads", "FFMPEG", "FixedPointNumbers", "GR", "JLFzf", "JSON", "LaTeXStrings", "Latexify", "LinearAlgebra", "Measures", "NaNMath", "Pkg", "PlotThemes", "PlotUtils", "PrecompileTools", "Preferences", "Printf", "REPL", "Random", "RecipesBase", "RecipesPipeline", "Reexport", "RelocatableFolders", "Requires", "Scratch", "Showoff", "SparseArrays", "Statistics", "StatsBase", "UUIDs", "UnicodeFun", "UnitfulLatexify", "Unzip"]
git-tree-sha1 = "75ca67b2c6512ad2d0c767a7cfc55e75075f8bbc"
uuid = "91a5bcdd-55d7-5caf-9e0b-520d859cae80"
version = "1.38.16"

    [deps.Plots.extensions]
    FileIOExt = "FileIO"
    GeometryBasicsExt = "GeometryBasics"
    IJuliaExt = "IJulia"
    ImageInTerminalExt = "ImageInTerminal"
    UnitfulExt = "Unitful"

    [deps.Plots.weakdeps]
    FileIO = "5789e2e9-d7fb-5bc7-8068-2c6fae9b9549"
    GeometryBasics = "5c1252a2-5f33-56bf-86c9-59e7332b4326"
    IJulia = "7073ff75-c697-5162-941a-fcdaad2a7d2a"
    ImageInTerminal = "d8c32880-2388-543b-8c61-d9f865259254"
    Unitful = "1986cc42-f94f-5a68-af5c-568840ba703d"

[[deps.PlutoUI]]
deps = ["AbstractPlutoDingetjes", "Base64", "ColorTypes", "Dates", "FixedPointNumbers", "Hyperscript", "HypertextLiteral", "IOCapture", "InteractiveUtils", "JSON", "Logging", "MIMEs", "Markdown", "Random", "Reexport", "URIs", "UUIDs"]
git-tree-sha1 = "b478a748be27bd2f2c73a7690da219d0844db305"
uuid = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
version = "0.7.51"

[[deps.PooledArrays]]
deps = ["DataAPI", "Future"]
git-tree-sha1 = "a6062fe4063cdafe78f4a0a81cfffb89721b30e7"
uuid = "2dfb63ee-cc39-5dd5-95bd-886bf059d720"
version = "1.4.2"

[[deps.PrecompileTools]]
deps = ["Preferences"]
git-tree-sha1 = "9673d39decc5feece56ef3940e5dafba15ba0f81"
uuid = "aea7be01-6a6a-4083-8856-8a6e6704d82a"
version = "1.1.2"

[[deps.Preferences]]
deps = ["TOML"]
git-tree-sha1 = "7eb1686b4f04b82f96ed7a4ea5890a4f0c7a09f1"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.4.0"

[[deps.PrettyTables]]
deps = ["Crayons", "Formatting", "LaTeXStrings", "Markdown", "Reexport", "StringManipulation", "Tables"]
git-tree-sha1 = "213579618ec1f42dea7dd637a42785a608b1ea9c"
uuid = "08abe8d2-0d0c-5749-adfa-8a2ac140af0d"
version = "2.2.4"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

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

[[deps.REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[deps.Random]]
deps = ["SHA", "Serialization"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[deps.Ratios]]
deps = ["Requires"]
git-tree-sha1 = "1342a47bf3260ee108163042310d26f2be5ec90b"
uuid = "c84ed2f1-dad5-54f0-aa8e-dbefe2724439"
version = "0.4.5"
weakdeps = ["FixedPointNumbers"]

    [deps.Ratios.extensions]
    RatiosFixedPointNumbersExt = "FixedPointNumbers"

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

[[deps.Scratch]]
deps = ["Dates"]
git-tree-sha1 = "30449ee12237627992a99d5e30ae63e4d78cd24a"
uuid = "6c6a2e73-6563-6170-7368-637461726353"
version = "1.2.0"

[[deps.SentinelArrays]]
deps = ["Dates", "Random"]
git-tree-sha1 = "04bdff0b09c65ff3e06a05e3eb7b120223da3d39"
uuid = "91c51154-3ec4-41a3-a24f-3f23e20d615c"
version = "1.4.0"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[deps.SharedArrays]]
deps = ["Distributed", "Mmap", "Random", "Serialization"]
uuid = "1a1011a3-84de-559e-8e89-a11a2f7dc383"

[[deps.Showoff]]
deps = ["Dates", "Grisu"]
git-tree-sha1 = "91eddf657aca81df9ae6ceb20b959ae5653ad1de"
uuid = "992d4aef-0814-514b-bc4d-f2e9a6c4116f"
version = "1.0.3"

[[deps.SimpleBufferStream]]
git-tree-sha1 = "874e8867b33a00e784c8a7e4b60afe9e037b74e1"
uuid = "777ac1f9-54b0-4bf8-805c-2214025038e7"
version = "1.1.0"

[[deps.SnoopPrecompile]]
deps = ["Preferences"]
git-tree-sha1 = "e760a70afdcd461cf01a575947738d359234665c"
uuid = "66db9d55-30c0-4569-8b51-7e840670fc0c"
version = "1.0.3"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[deps.SortingAlgorithms]]
deps = ["DataStructures"]
git-tree-sha1 = "c60ec5c62180f27efea3ba2908480f8055e17cee"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.1.1"

[[deps.SparseArrays]]
deps = ["Libdl", "LinearAlgebra", "Random", "Serialization", "SuiteSparse_jll"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[deps.SpecialFunctions]]
deps = ["IrrationalConstants", "LogExpFunctions", "OpenLibm_jll", "OpenSpecFun_jll"]
git-tree-sha1 = "7beb031cf8145577fbccacd94b8a8f4ce78428d3"
uuid = "276daf66-3868-5448-9aa4-cd146d93841b"
version = "2.3.0"
weakdeps = ["ChainRulesCore"]

    [deps.SpecialFunctions.extensions]
    SpecialFunctionsChainRulesCoreExt = "ChainRulesCore"

[[deps.StaticArrays]]
deps = ["LinearAlgebra", "Random", "StaticArraysCore", "Statistics"]
git-tree-sha1 = "832afbae2a45b4ae7e831f86965469a24d1d8a83"
uuid = "90137ffa-7385-5640-81b9-e52037218182"
version = "1.5.26"

[[deps.StaticArraysCore]]
git-tree-sha1 = "6b7ba252635a5eff6a0b0664a41ee140a1c9e72a"
uuid = "1e83bf80-4336-4d27-bf5d-d5a4f845583c"
version = "1.4.0"

[[deps.Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
version = "1.9.0"

[[deps.StatsAPI]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "45a7769a04a3cf80da1c1c7c60caf932e6f4c9f7"
uuid = "82ae8749-77ed-4fe6-ae5f-f523153014b0"
version = "1.6.0"

[[deps.StatsBase]]
deps = ["DataAPI", "DataStructures", "LinearAlgebra", "LogExpFunctions", "Missings", "Printf", "Random", "SortingAlgorithms", "SparseArrays", "Statistics", "StatsAPI"]
git-tree-sha1 = "75ebe04c5bed70b91614d684259b661c9e6274a4"
uuid = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"
version = "0.34.0"

[[deps.StatsFuns]]
deps = ["HypergeometricFunctions", "IrrationalConstants", "LogExpFunctions", "Reexport", "Rmath", "SpecialFunctions"]
git-tree-sha1 = "f625d686d5a88bcd2b15cd81f18f98186fdc0c9a"
uuid = "4c63d2b9-4356-54db-8cca-17b64c39e42c"
version = "1.3.0"

    [deps.StatsFuns.extensions]
    StatsFunsChainRulesCoreExt = "ChainRulesCore"
    StatsFunsInverseFunctionsExt = "InverseFunctions"

    [deps.StatsFuns.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    InverseFunctions = "3587e190-3f89-42d0-90ee-14403ec27112"

[[deps.StatsPlots]]
deps = ["AbstractFFTs", "Clustering", "DataStructures", "Distributions", "Interpolations", "KernelDensity", "LinearAlgebra", "MultivariateStats", "NaNMath", "Observables", "Plots", "RecipesBase", "RecipesPipeline", "Reexport", "StatsBase", "TableOperations", "Tables", "Widgets"]
git-tree-sha1 = "14ef622cf28b05e38f8af1de57bc9142b03fbfe3"
uuid = "f3b207a7-027a-5e70-b257-86293d7955fd"
version = "0.15.5"

[[deps.StringManipulation]]
git-tree-sha1 = "46da2434b41f41ac3594ee9816ce5541c6096123"
uuid = "892a3eda-7b42-436c-8928-eab12a02cf0e"
version = "0.3.0"

[[deps.SuiteSparse]]
deps = ["Libdl", "LinearAlgebra", "Serialization", "SparseArrays"]
uuid = "4607b0f0-06f3-5cda-b6b1-a6196a1729e9"

[[deps.SuiteSparse_jll]]
deps = ["Artifacts", "Libdl", "Pkg", "libblastrampoline_jll"]
uuid = "bea87d4a-7f5b-5778-9afe-8cc45184846c"
version = "5.10.1+6"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"
version = "1.0.3"

[[deps.TableIO]]
deps = ["DataFrames", "Requires", "TableIOInterface", "Tables"]
git-tree-sha1 = "f8844cb81b0c3a2d5c96c1387abebe61f18e619e"
uuid = "8545f849-0b94-433a-9b3f-37e40367303d"
version = "0.4.1"

[[deps.TableIOInterface]]
git-tree-sha1 = "9a0d3ab8afd14f33a35af7391491ff3104401a35"
uuid = "d1efa939-5518-4425-949f-ab857e148477"
version = "0.1.6"

[[deps.TableOperations]]
deps = ["SentinelArrays", "Tables", "Test"]
git-tree-sha1 = "e383c87cf2a1dc41fa30c093b2a19877c83e1bc1"
uuid = "ab02a1b2-a7df-11e8-156e-fb1833f50b87"
version = "1.2.0"

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
version = "1.10.0"

[[deps.TensorCore]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "1feb45f88d133a655e001435632f019a9a1bcdb6"
uuid = "62fd8b95-f654-4bbd-a8a5-9c27f68ccd50"
version = "0.1.1"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[deps.TranscodingStreams]]
deps = ["Random", "Test"]
git-tree-sha1 = "9a6ae7ed916312b41236fcef7e0af564ef934769"
uuid = "3bb67fe8-82b1-5028-8e26-92a6c54297fa"
version = "0.9.13"

[[deps.Tricks]]
git-tree-sha1 = "aadb748be58b492045b4f56166b5188aa63ce549"
uuid = "410a4b4d-49e4-4fbc-ab6d-cb71b17b3775"
version = "0.1.7"

[[deps.URIs]]
git-tree-sha1 = "074f993b0ca030848b897beff716d93aca60f06a"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.4.2"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

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

    [deps.Unitful.extensions]
    InverseFunctionsUnitfulExt = "InverseFunctions"

    [deps.Unitful.weakdeps]
    InverseFunctions = "3587e190-3f89-42d0-90ee-14403ec27112"

[[deps.UnitfulLatexify]]
deps = ["LaTeXStrings", "Latexify", "Unitful"]
git-tree-sha1 = "e2d817cc500e960fdbafcf988ac8436ba3208bfd"
uuid = "45397f5d-5981-4c77-b2b3-fc36d6e9b728"
version = "1.6.3"

[[deps.Unzip]]
git-tree-sha1 = "ca0969166a028236229f63514992fc073799bb78"
uuid = "41fe7b60-77ed-43a1-b4f0-825fd5a5650d"
version = "0.2.0"

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

[[deps.Widgets]]
deps = ["Colors", "Dates", "Observables", "OrderedCollections"]
git-tree-sha1 = "fcdae142c1cfc7d89de2d11e08721d0f2f86c98a"
uuid = "cc8bc4a8-27d6-5769-a93b-9d913e69aa62"
version = "0.6.6"

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

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"
version = "1.2.13+0"

[[deps.Zstd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "49ce682769cd5de6c72dcf1b94ed7790cd08974c"
uuid = "3161d3a3-bdf6-5164-811a-617609db77b4"
version = "1.5.5+0"

[[deps.fzf_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "868e669ccb12ba16eaf50cb2957ee2ff61261c56"
uuid = "214eeab7-80f7-51ab-84ad-2988db7cef09"
version = "0.29.0+0"

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
deps = ["Artifacts", "Libdl"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.8.0+0"

[[deps.libfdk_aac_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "daacc84a041563f965be61859a36e17c4e4fcd55"
uuid = "f638f0a6-7fb0-5443-88ba-1cc74229b280"
version = "2.0.2+0"

[[deps.libpng_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "94d180a6d2b5e55e447e2d27a29ed04fe79eb30c"
uuid = "b53b4c65-9356-5827-b1ea-8c7a1a84506f"
version = "1.6.38+0"

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
# ╟─75ab20ce-9203-4caa-86d3-1264706877eb
# ╟─aa8332a4-69a2-419a-acdd-de4485b12d74
# ╠═3485eb23-79c5-4ec7-9201-f3c8c89581b8
# ╠═a8e9eeae-161d-11ee-016d-1138b7066ff5
# ╠═088b8ea7-29c5-498c-8e1d-6aa50da357ed
# ╠═146d17b8-e26b-4353-bb58-dac8b7d4e7d3
# ╠═1e1f17bd-f55e-4b6e-ad3b-aa64aaf86e30
# ╠═d79d54ba-d528-4ec1-8625-505030c48670
# ╟─491cadcf-77c8-4f6d-a688-146f1a05d085
# ╠═1c3c5b52-d380-46da-a6b1-a879cddb712e
# ╠═b1d027e1-4932-4877-8db1-79153bd2c505
# ╠═4a025285-0270-42e9-9fc2-28deaab9ab7a
# ╠═72708bc5-249c-4d50-b728-3224852866c3
# ╠═f4045405-0317-4129-98d2-8c945594d346
# ╟─c5efebe5-5032-41d9-b891-2e6166bf8079
# ╠═7a7987bc-6ce3-4d50-8ffd-7d988739f947
# ╠═cabd97ba-a3a0-400d-a788-75a2aa8aabb0
# ╟─b16f0882-61e1-4be7-ade1-3618b061af55
# ╟─b4b0fc38-bb7a-44fa-9de6-0f613a904c12
# ╠═abfd6a59-7e59-43ef-ab70-1de70ab477fd
# ╠═5f4412c5-e6d5-4deb-875f-496fc79fdf4d
# ╠═acb3b817-38aa-4653-9842-7b9d75269229
# ╟─d83f4168-6044-4c54-ac27-bd22fb387858
# ╟─e148391d-d8af-4a94-b231-f78668ac8bad
# ╠═bf23da55-5cb8-4bee-8c7d-d7766048f030
# ╠═ae91c093-95ea-4258-8e28-849746f70b74
# ╟─7eff5ba1-603e-4b8d-9bcf-fc4305cffba0
# ╟─45c49de8-75ef-40fd-ab06-838deb27e123
# ╟─8547d7c3-e03c-4fba-9d05-043e07c37c2d
# ╠═4bd2a0ee-b1e8-4b84-859b-b6f3f9052345
# ╠═b3b15f54-0528-49f3-a84e-02ffd4da62c8
# ╠═4d0c1cdf-9a86-47ea-9a33-5ce8b883f148
# ╠═299a4158-9d9d-43fd-a73f-39d433c18edd
# ╠═1f40de7c-0cb6-4bd2-902f-be360eec5106
# ╠═9b6b4c5e-e532-4a26-93c2-55dbb15c631e
# ╠═0466b3c8-eeb5-4c7b-961b-406f885ebc11
# ╠═01122926-9af4-48f6-953a-87170920d5c5
# ╠═a59bba9b-34f0-4cbc-8f5a-253f5f00770b
# ╠═1e79d08c-bb10-49f2-b960-ae1710c5e725
# ╠═e34ed282-c15c-4562-bcb9-0d9271130621
# ╠═a550cb39-2d05-4208-a123-84cc2f36967f
# ╠═a30b8bd8-2a00-4276-8e80-b8438ab3569c
# ╠═df47c019-c8e0-4b2e-8eb3-0cbb0df2b5e3
# ╠═e5869534-483b-4b37-8ff2-28f74cf3497b
# ╠═c4b66ff3-a44e-4ee5-aa5f-73fc8903214d
# ╠═f547b374-cdc9-4bbe-a110-58723d74e9db
# ╠═1e8448a4-3ff1-4424-97a3-2bfc116db2b1
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
