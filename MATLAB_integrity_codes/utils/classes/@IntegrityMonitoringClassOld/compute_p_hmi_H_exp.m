
function p_hmi_H= compute_p_hmi_H_exp(obj, alpha, fault_ind, params)

 
% build extraction matrix
if params.SWITCH_SIM
    if fault_ind == 0
        obj.compute_E_matrix_fg( 0, params.m_F);
    else
        obj.compute_E_matrix_fg( obj.inds_H{fault_ind}, params.m_F);
    end
else
    if fault_ind == 0
        obj.compute_E_matrix_fg_exp( 0, params);
    else
        obj.compute_E_matrix_fg_exp( obj.inds_H{fault_ind}, params);
    end
end

% Worst-case fault direction
f_M_dir= obj.E' / (obj.E * obj.M_M * obj.E') * obj.E * (obj.A_reduced /( obj.A_reduced' * obj.A_reduced )) * alpha;
f_M_dir= f_M_dir / norm(f_M_dir); % normalize

% worst-case fault magnitude
fx_hat_dir= abs( (alpha' /( obj.A_reduced' * obj.A_reduced )) * obj.A_reduced' * f_M_dir );
M_dir= abs( f_M_dir' * obj.M_M * f_M_dir );

% worst-case fault magnitude
f_mag_min= 0;
f_mag_max= 5;
f_mag_inc= 5;
p_hmi_H_prev= -1;
for k= 1:10
    if (~params.SWITCH_SIM) && (params.SWITCH_FACTOR_GRAPHS)
        [f_M_mag_out, p_hmi_H]= fminbnd( @(f_M_mag) obj.optimization_fn(...
            f_M_mag, fx_hat_dir, M_dir, obj.sigma_hat, params.alert_limit, obj.n_M + obj.n_M_gps ),...
            f_mag_min, f_mag_max);
    else
        [f_M_mag_out, p_hmi_H]= fminbnd( @(f_M_mag) obj.optimization_fn(...
            f_M_mag, fx_hat_dir, M_dir, obj.sigma_hat, params.alert_limit, obj.n_M ),...
            f_mag_min, f_mag_max);
    end
    
    % make it a positive number
    p_hmi_H= -p_hmi_H;
    
    % check if the new P(HMI|H) is smaller
    if k == 1 || p_hmi_H_prev < p_hmi_H
        p_hmi_H_prev= p_hmi_H;
        f_mag_min= f_mag_min + f_mag_inc;
        f_mag_max= f_mag_max + f_mag_inc;
    else
        p_hmi_H= p_hmi_H_prev;
        break
    end
end
end
