
function monitor_integrity(obj, estimator, counters, data,  params)


% calculate the current number of LMs in PH; only before starting integrity monitoring
if params.SWITCH_FIXED_LM_SIZE_PH && isempty(obj.p_hmi)
    
    % current horizon measurements
    obj.n_M= sum( obj.n_ph(1:obj.M) ) + estimator.n_k;
    % current horizon LMs
    obj.n_L_M= obj.n_M / params.m_F;
    estimator.n_L_M= obj.n_L_M;
    % update the length of PH
    obj.M= obj.M +1; 
    
end

% monitor integrity if the number of abs msmts in PH is more than threshold,...
% Or if the number of LMs in PH is more than threshold, ...
% Or if the num of epochs in PH equals to a specific value
if  ( params.SWITCH_FIXED_LM_SIZE_PH ...
      && obj.n_L_M + ((estimator.n_gps_k + sum(obj.n_gps_ph))/6) >= params.min_n_L_M ...
      && (( (estimator.n_gps_k + sum(obj.n_gps_ph) ~= 0) ...
      && params.SWITCH_FIXED_ABS_MSMT_PH_WITH_min_GPS_msmt)...
      || (~params.SWITCH_FIXED_ABS_MSMT_PH_WITH_min_GPS_msmt)) ) ||...
    ( ~params.SWITCH_FIXED_LM_SIZE_PH && counters.k_im > obj.M )

    % Modify PH to have enough landmarks (in case of Fixed LM or abs msmts)
    if params.SWITCH_FIXED_LM_SIZE_PH
        
        obj.compute_required_epochs_for_min_LMs(params, estimator)
        
    else
        
        % number of lidar msmts over the horizon
        obj.n_M= estimator.n_k + sum( obj.n_ph(1:obj.M - 1) );

        % number of landmarks over the horizon
        obj.n_L_M= obj.n_M / params.m_F;
        estimator.n_L_M= obj.n_L_M;
    end
    
    % compute extraction vector
    alpha= obj.build_state_of_interest_extraction_matrix(params, estimator.XX);
    
    % number of GPS msmts over the horizon
    obj.n_M_gps= estimator.n_gps_k + sum( obj.n_gps_ph(1:obj.M - 1) );
    
    % total number of msmts (prior + relative + abs)
    obj.n_total= obj.n_M + obj.n_M_gps + (obj.M + 1) * (params.m);
    
    % number of states to estimate
    obj.m_M= (obj.M + 1) * (params.m);
    
    % compute the whiten Jacobian matrix A
    obj.compute_whiten_jacobian_A(estimator, params);
    
    % construct the information matrix
    obj.Gamma_fg= obj.A' * obj.A;
    
    % full covarince matrix
    obj.PX_M= inv(obj.Gamma_fg);
    
    % extract covarince matrix at time k
    estimator.PX= obj.PX_M( end - params.m + 1 : end, end - params.m + 1 : end );
    
    % find the prior covarince matrix for time k+1
    obj.PX_prior= obj.PX_M( params.m + 1 : 2*params.m, params.m + 1 : 2*params.m );
    obj.Gamma_prior= inv(obj.PX_prior);
    
    % set detector threshold from the continuity req
    obj.T_d= chi2inv( 1 - obj.C_req, obj.n_M + obj.n_M_gps );
    
    obj.n_max= 1;%estimator.n_L_k-1;
    fprintf('n_max: %d\n', obj.n_max);
    
    %obj.prob_of_MA( estimator, params);
    
    %obj.P_MA_M = [ obj.P_MA_k ; cell2mat(obj.P_MA_ph(1:obj.M-1)') ];
    
    % fault probability of each association in the preceding horizon
    obj.P_F_M= ones(obj.n_L_M + (obj.n_M_gps/6) , 1) * params.P_UA;% + [obj.P_MA_M;zeros(obj.n_M_gps/6,1)];
    
    obj.P_F_M(obj.P_F_M>=1)=0.99999999999999*ones(sum(obj.P_F_M>=1),1);
    
    obj.I_H= 0;%sum(obj.P_F_M)^(obj.n_max+1)  / factorial(obj.n_max+1);
    
    if obj.I_H>1
        obj.I_H=1;
    end
    
    % compute the hypotheses (n_H, n_max, inds_H)
    obj.compute_hypotheses(params)
    
    % initialization of p_hmi
    obj.p_hmi= obj.I_H;
    
    % Least squares residual matrix
    obj.M_M= eye( obj.n_total ) - (obj.A / obj.Gamma_fg) * obj.A';
    rank_M_M= obj.n_M + obj.n_M_gps;

    % fix the symmetry and the semi-positive def of the matrix
    if rank(obj.M_M) > rank_M_M
        [U, D, ~]= svd(obj.M_M);
        obj.M_M= U(:, 1:rank_M_M) * D(1:rank_M_M,1:rank_M_M) * U(:, 1:rank_M_M)';
        obj.M_M= (obj.M_M + obj.M_M')/2;
    end

    % standard deviation in the state of interest
    obj.sigma_hat= sqrt( (alpha' * obj.PX_M) * alpha );

    % initializing P_H vector
    obj.P_H= ones(obj.n_H, 1) * inf;

    for i= 0:obj.n_H   

        if i == 0
            if obj.n_M+obj.n_M_gps < params.m
                % compute P(HMI | H) for the worst-case fault
                p_hmi_H= 1;
                % Add P(HMI | H0) to the integrity risk
                obj.P_H_0= prod( 1 - obj.P_F_M );
                obj.p_hmi= obj.p_hmi + p_hmi_H * obj.P_H_0 * (1-obj.I_H);
                if obj.p_hmi>=1
                    obj.p_hmi=1;
                    break;
                end
            else
                % compute P(HMI | H) for the worst-case fault
                p_hmi_H= obj.compute_p_hmi_H(alpha, 0, params);
                % Add P(HMI | H0) to the integrity risk
                obj.P_H_0= prod( 1 - obj.P_F_M );
                obj.p_hmi= obj.p_hmi + p_hmi_H * obj.P_H_0 * (1-obj.I_H);
                if obj.p_hmi>=1
                    obj.p_hmi=1;
                    break;
                end
            end
        else
            if obj.n_M+obj.n_M_gps < params.m + sum(obj.inds_H{i}<=obj.n_L_M)*params.m_F + sum(obj.inds_H{i}>obj.n_L_M)*6
                % if we don't have enough landmarks --> P(HMI)= 1
                p_hmi_H= 1;
                % Add P(HMI | H) to the integrity risk
                obj.P_H(i)= prod( obj.P_F_M( obj.inds_H{i} ) );% obj.P_H_0* prod( obj.P_F_M( obj.inds_H{i} ) ) / prod( 1 - obj.P_F_M( obj.inds_H{i} ) );
                if isnan(obj.P_H(i))
                    obj.P_H(i)=0;
                end
                obj.p_hmi= obj.p_hmi + p_hmi_H * obj.P_H(i) * (1-obj.I_H);
                if obj.p_hmi>=1
                    obj.p_hmi=1;
                    break;
                end
            else
                % compute P(HMI | H) for the worst-case fault
                p_hmi_H= obj.compute_p_hmi_H(alpha, obj.inds_H{i}, params);
                % Add P(HMI | H) to the integrity risk
                obj.P_H(i)= prod( obj.P_F_M( obj.inds_H{i} ) );% obj.P_H_0* prod( obj.P_F_M( obj.inds_H{i} ) ) / prod( 1 - obj.P_F_M( obj.inds_H{i} ) );
                if isnan(obj.P_H(i))
                    obj.P_H(i)=0;
                end
                obj.p_hmi= obj.p_hmi + p_hmi_H * obj.P_H(i) * (1-obj.I_H);
                if obj.p_hmi>=1
                    obj.p_hmi=1;
                    break;
                end
            end
        end
    end
    
    % store integrity related data
    data.store_integrity_data(obj, estimator, counters, params)
else
    
    obj.prob_of_MA(estimator, params);

end

% update the preceding horizon
update_preceding_horizon(obj, estimator)

end