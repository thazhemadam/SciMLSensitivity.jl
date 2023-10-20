using SciMLSensitivity, Zygote, Flux, OrdinaryDiffEq, Test # , Plots

p = [1.5 1.0; 3.0 1.0]
function lotka_volterra(du, u, p, t)
    du[1] = p[1, 1] * u[1] - p[1, 2] * u[1] * u[2]
    du[2] = -p[2, 1] * u[2] + p[2, 2] * u[1] * u[2]
end

u0 = [1.0, 1.0]
tspan = (0.0, 10.0)

prob = ODEProblem(lotka_volterra, u0, tspan, p)
sol = solve(prob, Tsit5())

# plot(sol)

p = [2.2 1.0; 2.0 0.4] # Tweaked Initial Parameter Array
ps = Flux.params(p)

function predict_adjoint() # Our 1-layer neural network
    Array(solve(prob, Tsit5(), p = p, saveat = 0.0:0.1:10.0))
end

loss_adjoint() = sum(abs2, x - 1 for x in predict_adjoint())

data = Iterators.repeated((), 100)
opt = ADAM(0.1)
cb = function () #callback function to observe training
    display(loss_adjoint())
end

predict_adjoint()

# Display the ODE with the initial parameter values.
cb()
Flux.train!(loss_adjoint, ps, data, opt, cb = cb)

@test loss_adjoint() < 1

tspan = (0, 1)
tran = collect(0:0.1:1)
p0 = rand(2)
f0 = randn(30, 50)

function rhs!(df, f, p, t)
    for j in axes(f, 2)
        for i in axes(f, 1)
            df[i, j] = p[1] * i + p[2] * j
        end
    end
    return nothing
end

function loss(p; vjp)
    prob = ODEProblem(rhs!, f0, tspan, p)
    sol = solve(prob, Midpoint(), saveat = tran, sensealg=InterpolatingAdjoint(autojacvec=vjp)) |> Array
    l = sum(abs2, sol)

    return l
end

dp1 = Zygote.pullback(x -> loss(x; vjp = EnzymeVJP()), p0)[2](1)[1]
dp2 = Zygote.pullback(x -> loss(x; vjp = ReverseDiffVJP()), p0)[2](1)[1]
dp3 = Zygote.pullback(x -> loss(x; vjp = TrackerVJP()), p0)[2](1)[1]
dp4 = Zygote.pullback(x -> loss(x; vjp = EnzymeVJP()), p0)[2](1)[1]
dp5 = Zygote.pullback(x -> loss(x; vjp = true), p0)[2](1)[1]
dp6 = Zygote.pullback(x -> loss(x; vjp = false), p0)[2](1)[1]

@test dp1 ≈ dp2
@test dp1 ≈ dp3
@test dp1 ≈ dp4
@test dp1 ≈ dp5
@test dp1 ≈ dp6