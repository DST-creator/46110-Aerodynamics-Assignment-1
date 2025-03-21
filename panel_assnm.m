%% ASSIGNMENT 1 46110: AIRFOIL CHARACTERISTICS USING DIFFERENT ANALYSIS METHODS

clear
clc
close all

%% DATA: NACA 2312 // NACA 2324 // NACA 4412 // NACA 4424

num = [1 2 3 4]; % Airfoil selection numbers
n = 50; % Number of panels
c = 1; % Chord length [m]
aoa_deg = linspace(-10,15,n); % Angle of attack range [deg]
aoa = deg2rad(aoa_deg); % Convert to radians

%% PANEL METHOD CALCULATION FOR LIFT COEFFICIENT PLOT

for i = 1:length(num) 
    [m, p, t] = airfoil_selection(num(i)); % Get airfoil parameters
    [x, y] = naca_airfoil(m, p, t, c, n); % Generate airfoil geometry
    
    % Calculate lift coefficients for all angles of attack
    for j = 1:length(aoa)
        [cl_temp, ~, ~] = panel_method(x, y, aoa(j));
        cl(i,j) = cl_temp;
    end
end

%% PLOTTING LIFT COEFFICIENT VS ANGLE OF ATTACK
figure(1)
plot(aoa_deg, cl, 'LineWidth', 2)
grid on
xlabel('Angle of Attack [deg]')
ylabel('Lift Coefficient [-]')
legend('NACA 2312', 'NACA 2324', 'NACA 4412', 'NACA 4424', 'Location', 'best')

%% PANEL METHOD CALCULATION FOR ΔCp PLOT
% Use fixed angle of attack for pressure distribution
fixed_aoa_deg = 10;
fixed_aoa = deg2rad(fixed_aoa_deg);

figure(2)
hold on
for i = 1:length(num) 
    [m, p, t] = airfoil_selection(num(i)); % Get airfoil parameters
    [x, y] = naca_airfoil(m, p, t, c, n); % Generate airfoil geometry
    [~, xp, Cp] = panel_method(x, y, fixed_aoa); % Compute Cl and Cp using panel method
    
    % Calculate and plot ΔCp
    [xc, Delta_Cp] = compute_delta_cp(xp, x, y, Cp);
    plot(xc / c, Delta_Cp, 'LineWidth', 2)
end
hold off
grid on
xlabel('x/c')
ylabel('\Delta C_p')
title(['Pressure Difference Distribution \Delta C_p at ', num2str(fixed_aoa_deg), '° (Panel Method)'])
legend('NACA 2312', 'NACA 2324', 'NACA 4412', 'NACA 4424', 'Location', 'best')

%% FUNCTIONS

function [m, p, t] = airfoil_selection(number)
    % Returns the airfoil parameters (m, p, t) for given NACA 4-digit code
    max_camber = [0.02 0.02 0.04 0.04];
    location_max_camber = [0.3 0.3 0.4 0.4];
    max_thickness = [0.12 0.24 0.12 0.24];

    if number >= 1 && number <= 4 && mod(number,1) == 0
        m = max_camber(number);
        p = location_max_camber(number);
        t = max_thickness(number);
    else
        error('Invalid airfoil selection. Choose a number between 1 and 4.')
    end
end

function [x, y] = naca_airfoil(m, p, t, c, n)
    % Generates NACA 4-digit airfoil coordinates
    
    x = linspace(0, c, n);
    yt = (t/0.2) * (0.2969*sqrt(x) - 0.1260*x - 0.3516*x.^2 + 0.2843*x.^3 - 0.1015*x.^4);

    yc = zeros(size(x));
    dyc_dx = zeros(size(x));

    for i = 1:length(x)
        if x(i) < p*c
            yc(i) = (m/p^2) * (2*p*x(i)/c - (x(i)/c)^2);
            dyc_dx(i) = (2*m/p^2) * (p - x(i)/c);
        else
            yc(i) = (m/(1-p)^2) * ((1-2*p) + 2*p*x(i)/c - (x(i)/c)^2);
            dyc_dx(i) = (2*m/(1-p)^2) * (p - x(i)/c);
        end
    end

    theta = atan(dyc_dx);
    xu = x - yt .* sin(theta);
    xl = x + yt .* sin(theta);
    yu = yc + yt .* cos(theta);
    yl = yc - yt .* cos(theta);

    x = [flip(xu), xl(2:end)];
    y = [flip(yu), yl(2:end)];
end

function [cl, xp, Cp] = panel_method(x, y, aoa)
    % Computes lift coefficient and pressure coefficient using the panel method
    
    n = length(x) - 1;
    
    % Calculate panel properties
    for j = 1:n
        plength(j) = sqrt((x(j+1) - x(j))^2 + (y(j+1) - y(j))^2);
        xp(j) = 0.5 * (x(j+1) + x(j));
        yp(j) = 0.5 * (y(j+1) + y(j));
        Tx(j) = -(x(j+1) - x(j)) / plength(j);
        Ty(j) = -(y(j+1) - y(j)) / plength(j);
        Nx(j) = -Ty(j);
        Ny(j) = Tx(j);
    end

    % Initialize influence coefficient matrices
    A = zeros(n, n);
    B = zeros(n, n);

    % Calculate influence coefficients
    for i = 1:n
        for j = 1:n
            if i == j
                A(i, j) = 0.5;
                B(i, j) = 0;
            else
                sx = (xp(i) - xp(j)) * Tx(j) + (yp(i) - yp(j)) * Ty(j);
                sy = (xp(i) - xp(j)) * Nx(j) + (yp(i) - yp(j)) * Ny(j);
                
                % Handle special case to avoid division by zero
                if abs(sy) < 1e-10
                    sy = 1e-10;
                end
                
                Ux1 = log(((sx + 0.5 * plength(j))^2 + sy^2) / ((sx - 0.5 * plength(j))^2 + sy^2)) / (4 * pi);
                Uy1 = (atan((sx + 0.5 * plength(j)) / sy) - atan((sx - 0.5 * plength(j)) / sy)) / (2 * pi);
                
                Ux2 = Ux1 * Tx(j) - Uy1 * Ty(j);
                Uy2 = Ux1 * Ty(j) + Uy1 * Tx(j);
                
                Ux(i, j) = Ux2 * Tx(i) + Uy2 * Ty(i);
                Uy(i, j) = Ux2 * Nx(i) + Uy2 * Ny(i);
                
                A(i, j) = Uy(i, j);
                B(i, j) = Ux(i, j);
            end
        end
    end

    % Calculate right-hand side vector
    F = -(Nx .* cos(aoa) + Ny .* sin(aoa));
    
    % Solve for vortex strengths
    M = A \ F';

    % Calculate tangential velocities
    for i = 1:n
        Vt(i) = sum(B(i, :) .* M') + Tx(i) * cos(aoa) + Ty(i) * sin(aoa);
    end

    % Calculate circulation for Kutta condition
    sumVort = sum((0:n-1) .* (n-1:-1:0) .* plength);
    vort = ((0:n-1) .* (n-1:-1:0)) / sumVort;

    C = A \ B;
    D = B * C;
    Vrt = (A + D) * vort';
    Gamma = -(Vt(1) + Vt(end) + dot([cos(aoa), sin(aoa)], ([Tx(1), Ty(1)] + [Tx(end), Ty(end)]))) / (Vrt(1) + Vrt(end));

    % Calculate lift coefficient using Kutta-Joukowski theorem
    cl = 2 * Gamma / (max(x) - min(x));

    % Calculate pressure coefficient
    for i = 1:n
        Urt(i) = Gamma * Vrt(i) + Vt(i);  % Tangential velocity including circulation
        Cp(i) = 1 - Urt(i)^2;             % Pressure coefficient
    end
end

function [xc, Delta_Cp] = compute_delta_cp(xp, x, y, Cp)
    % Compute ΔCp (Cp_lower - Cp_upper)
    
    % Find the trailing edge and leading edge index
    [~, te_idx] = max(x);
    [~, le_idx] = min(x);
    
    % Determine which points are on upper and lower surface based on y values
    % For each x-coordinate, the point with larger y is on upper surface
    upper_points = zeros(1, length(xp));
    lower_points = zeros(1, length(xp));
    upper_count = 0;
    lower_count = 0;
    
    for i = 1:length(xp)
        % Check if this point is closer to upper or lower surface
        if xp(i) < 0.5  % Front half of airfoil
            if y(i) > 0  % Above x-axis
                upper_count = upper_count + 1;
                upper_points(upper_count) = i;
            else  % Below x-axis
                lower_count = lower_count + 1;
                lower_points(lower_count) = i;
            end
        else  % Back half of airfoil
            if y(i) >= 0  % Above or on x-axis
                upper_count = upper_count + 1;
                upper_points(upper_count) = i;
            else  % Below x-axis
                lower_count = lower_count + 1;
                lower_points(lower_count) = i;
            end
        end
    end
    
    % Clean up arrays
    upper_points = upper_points(1:upper_count);
    lower_points = lower_points(1:lower_count);
    
    % Get coordinates and pressure coefficients for upper and lower surfaces
    x_upper = xp(upper_points);
    Cp_upper = Cp(upper_points);
    
    x_lower = xp(lower_points);
    Cp_lower = Cp(lower_points);
    
    % Sort data points by x-coordinate
    [x_upper, idx_upper] = sort(x_upper);
    Cp_upper = Cp_upper(idx_upper);
    
    [x_lower, idx_lower] = sort(x_lower);
    Cp_lower = Cp_lower(idx_lower);
    
    % Create common x-coordinates for interpolation
    xc = linspace(min(min(x_upper), min(x_lower)), max(max(x_upper), max(x_lower)), 100);
    
    % Interpolate pressure coefficients to common x-coordinates
    Cp_upper_interp = interp1(x_upper, Cp_upper, xc, 'linear', 'extrap');
    Cp_lower_interp = interp1(x_lower, Cp_lower, xc, 'linear', 'extrap');
    
    % Calculate ΔCp = Cp_lower - Cp_upper, as the denominator reduces to 1/2
    Delta_Cp = 2*(Cp_lower_interp - Cp_upper_interp);
end




