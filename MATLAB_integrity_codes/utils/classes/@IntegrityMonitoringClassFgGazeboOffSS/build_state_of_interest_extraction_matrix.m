function alpha= build_state_of_interest_extraction_matrix(obj, params, current_state)

if params.SWITCH_SIM
    % In the simulation mode
    alpha= [ zeros( obj.M * 9, 1 );... %Osama params.m
            -sin( current_state(params.ind_yaw) );...
            cos( current_state(params.ind_yaw) );...
            0 ];
else
    % In the experiment mode
    alpha= [ zeros( obj.M * (9), 1 );...
            -sin( current_state(params.ind_yaw) );...
            cos( current_state(params.ind_yaw) );...
            zeros( 9-2 , 1 ) ]; %Osama params.m
end
end