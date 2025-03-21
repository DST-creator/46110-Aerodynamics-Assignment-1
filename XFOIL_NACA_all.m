clear; clc;
xfoil_exe = fullfile('..','..', ...
                    '03_additional_material', 'Xfoil', 'xfoil.exe');  %Path to Xfoil executable

airfoils = [ ...
    struct('name','2312', 'xfoil', XFOIL_NACA('2312', xfoil_exe)),
    struct('name','2324', 'xfoil', XFOIL_NACA('2324', xfoil_exe)),
    struct('name','4412', 'xfoil', XFOIL_NACA('4412', xfoil_exe)),
    struct('name','4424', 'xfoil', XFOIL_NACA('4424', xfoil_exe))
    ];

%% Run Calculations
rerun_C_ld_calc = true;
rerun_C_p_calc = false;
rerun_dC_p_calc = false;
rerun_C_ld_max = false;

AoAs_c_ld = [-10, 15, .1];
AoA_c_p = 10;
numNodes_c_l = 160;
numNodes_c_p = 200;
max_iter = 400;
use_cached_input = false;

% If output file already exists, load it
fpath_res = 'xfoil_exports\XFOIL_results.mat';
if exist(fpath_res,'file')
    airfoils = load(fpath_res).airfoils;
end

%% Calculate C_l & C_d
if rerun_C_ld_calc
    for i = 1:size(airfoils)
        % Run calculation with free transition
        [alpha, C_l, C_d, xt_top, xt_bot] = airfoils(i).xfoil.calc_c_ld(true, ...
            use_cached_input, AoAs_c_ld, numNodes_c_l, max_iter);
        airfoils(i).C_ld_free = struct('alpha', alpha, 'C_l', C_l, ...
            'C_d', C_d, 'xt_top', xt_top, 'xt_bot', xt_bot);

        % Run calculation with fixed transition
        [alpha, C_l, C_d, xt_top, xt_bot] = airfoils(i).xfoil.calc_c_ld(false, ...
            use_cached_input, AoAs_c_ld, numNodes_c_l, max_iter);
        airfoils(i).C_ld_fixed = struct('alpha', alpha, 'C_l', C_l, ...
            'C_d', C_d, 'xt_top', xt_top, 'xt_bot', xt_bot);
    end

    save(fpath_res, 'airfoils');  % Save results
end

%% Calculate C_p
if rerun_C_p_calc
    for i = 1:size(airfoils)
        % Run calculation with free transition
        [x, y, C_p, x_trans] = airfoils(i).xfoil.calc_c_p(true, use_cached_input, ...
            AoA_c_p, numNodes_c_p, max_iter);
        airfoils(i).C_p_free = struct('x', x, 'y', y, 'C_p', C_p, 'x_trans', x_trans);

        % Run calculation with fixed transition
        [x, y, C_p, x_trans] = airfoils(i).xfoil.calc_c_p(false, use_cached_input, ...
            AoA_c_p, numNodes_c_p, max_iter);
        airfoils(i).C_p_fixed = struct('x', x, 'y', y, 'C_p', C_p, 'x_trans', x_trans);
    end

    save(fpath_res, 'airfoils');  % Save results
end

%% Calculate ΔC_p
if rerun_C_p_calc
    for i = 1:size(airfoils(:,1))
        % Run calculation with free transition
        [xc, dC_p] = airfoils(i).xfoil.calc_dc_p (airfoils(i).C_p_free.x, ...
            airfoils(i).C_p_free.y, airfoils(i).C_p_free.C_p);
        airfoils(i).C_p_free.xc = xc;
        airfoils(i).C_p_free.dC_p = dC_p;

        % Run calculation with fixed transition
        [xc, dC_p] = airfoils(i).xfoil.calc_dc_p (airfoils(i).C_p_fixed.x, ...
            airfoils(i).C_p_fixed.y, airfoils(i).C_p_fixed.C_p);
        airfoils(i).C_p_fixed.xc = xc;
        airfoils(i).C_p_fixed.dC_p = dC_p;
    end

    save(fpath_res, 'airfoils');  % Save results
end

%% Get max C_l / C_d

if rerun_C_ld_max
    for i = 1:size(airfoils(:,1))
        C_ld_free = airfoils(i).C_ld_free.C_l ./ airfoils(i).C_ld_free.C_d;
        [C_ld_free_max, i_free_max] = max(C_ld_free);
        airfoils(i).Max_eff_free = ...
            struct('alpha', airfoils(i).C_ld_free.alpha(i_free_max), ...
                   'C_ld', C_ld_free_max);
        
        C_ld_fixed = airfoils(i).C_ld_fixed.C_l ./ airfoils(i).C_ld_fixed.C_d;
        [C_ld_fixed_max, i_fixed_max] = max(C_ld_fixed);
        airfoils(i).Max_eff_fixed = ...
            struct('alpha', airfoils(i).C_ld_fixed.alpha(i_fixed_max), ...
                   'C_ld', C_ld_fixed_max);
    end
    
    save(fpath_res, 'airfoils');  % Save results
end