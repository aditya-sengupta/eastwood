"""
Command Line INTegrator. 
Basically just stitching together a few packages into something that's easy to use from the command line
to save me the trouble of "can I analytically integrate that, should I do this numerically, 
should I look up the QuadGK docs", etc
"""
module eastwood
    using Symbolics
    using SymbolicNumericIntegration
    using QuadGK
    using PackageCompiler

    """
    Converts a LaTeX \frac to a bracketed division expression.
    """
    function frac_to_brackets(expr)
        expr = " " * expr * " "
        m = match(r"(.+)\frac{(.+)}{(.+)}(.+)", expr)
        if isnothing(m)
            return strip(expr)
        else
            return strip(m[1] * "($(frac_to_brackets(m[2])))/($(frac_to_brackets(m[3])))" * m[4])
        end
    end

    function evaluate_num(expr)
        parse_expr_to_symbolic(Meta.parse(frac_to_brackets(expr)), @__MODULE__)
    end

    function find_integrating_variable(integrand)
        vars = Symbolics.get_variables(integrand)
        @assert length(vars) == 1 "Integrating variable ambiguous: found $vars"
        return vars[1]
    end

    """
    The limits will have gone through evaluate_num, and are either a Num (if there's a symbolic element)
    or a regular number (if there isn't).
    """
    function limits_are_symbolic(lower, upper)
        return lower isa Num || upper isa Num
    end

    function definite_integral(integrand, iv, lower, upper)
        if !limits_are_symbolic(lower, upper)
            integ_function = v -> substitute(integrand, [iv => v])
            result, error = invokelatest(quadgk, integ_function, lower, upper)
            println("Result: $result")
            println("Error:  $error")
        else
            println(integrate(integrand, (iv, lower, upper); symbolic=true, detailed=false))
        end
    end

    function main(a)
        args = evaluate_num.(a) # integrand, integrating variable, and lower/upper limits if present
        if length(args) == 1 # 1 or 3: implicit integrating variable
            iv = find_integrating_variable(args[1])
            println(integrate(args[1], iv; symbolic=true, detailed=false))
        # 2 or 4: explicit integrating variable and we'll possibly have extra symbols in there
        elseif length(args) == 2 # integrand and variable
            println(integrate(args[1], args[2]; symbolic=true, detailed=false))
        elseif length(args) == 3 # integrand and limits
            iv = find_integrating_variable(args[1])
            # here, we want to check if the limits are symbolic, or numerical
            # if they're numerical, we can just use QuadGK and save time
            definite_integral(args[1], iv, args[2], args[3])
        elseif length(args) == 4 # symbolic integrand, need to check if it's reducible to numeric
            if length(Symbolics.get_variables(args[1])) > 1
                # no parameters in the integrand, can either do it numerically
                # or symbolically on just the limits
                definite_integral(args[1], args[2], args[3], args[4])
            else
                # fall back to the full symbolic integral
                println(integrate(args[1], (args[2], args[3], args[4]); symbolic=true, detailed=false))
            end
        else
            println("Malformed input, please try again with 1-4 arguments.")
        end
    end

    function julia_main()::Cint
        main(ARGS)
        return 0
    end

    if ccall(:jl_generating_output, Cint, ()) == 1   # if we're precompiling the package
        let
            main(["x^2"])
            main(["x^2", "x"])
            main(["x^2", "0", "1"])
            main(["x^2", "x", "0", "1"])
        end
    end

    export evaluate_num, integrate, main
end # module Eastwood
