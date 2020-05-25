
function [z,association]= nearest_neighbor(obj, z, params)

% number of features
num_of_extracted_features= size(z,1);

% initialize with zero, if SLAM --> initialize with (-1)
association= zeros(num_of_extracted_features, 1);

if num_of_extracted_features == 0, return, end

% initialize variables
spsi= sin(obj.XX(9));
cpsi= cos(obj.XX(9));
zHat= zeros(2,1);

PX= obj.Phi_k*obj.PX*obj.Phi_k'+obj.D_bar;

% select landmarks in the field of view
obj.FoV_landmarks_at_k= zeros(obj.num_landmarks, 1);
for i= 1:obj.num_landmarks
    
    dx= obj.landmark_map(i,1) - obj.XX(1);
    if abs(dx) > params.lidarRange, continue, end
    dy= obj.landmark_map(i,2) - obj.XX(2);
    if abs(dy) > params.lidarRange, continue, end
    
    if sqrt( dx^2 + dy^2 ) <= params.lidarRange
        obj.FoV_landmarks_at_k(i)= i;
    end
end
% remove the ones that are zeros
obj.FoV_landmarks_at_k( obj.FoV_landmarks_at_k == 0 )= [];

% Loop over extracted features
for i= 1:num_of_extracted_features
    min_y2= params.T_NN;
    
    % loop through landmarks
    for l= 1:length(obj.FoV_landmarks_at_k)
        lm_ind= obj.FoV_landmarks_at_k(l);
        landmark= obj.landmark_map( lm_ind,: );
        
        % TODO: I don't think this is needed, it has been checked before
        dx= landmark(1) - obj.XX(1);
        if abs(dx) > params.lidarRange, continue, end
        dy= landmark(2) - obj.XX(2);
        if abs(dy) > params.lidarRange, continue, end      
        
        % build innovation vector
        zHat(1)=  dx*cpsi + dy*spsi;
        zHat(2)= -dx*spsi + dy*cpsi;
        gamma= z(i,:)' - zHat;
        
        % quick check (10 m in X or Y)
        if abs(gamma(1)) > 10 || abs(gamma(2)) > 10, continue, end
        
        % Jacobian
        H= [-cpsi, -spsi, -dx*spsi + dy*cpsi;
             spsi, -cpsi, -dx*cpsi - dy*spsi ];
        
        % covariance matrix
        Y= H * PX([1:2,9],[1:2,9]) * H' + params.R_lidar;
        
        % IIN squared
        y2= gamma' / Y * gamma;
        
        if y2 < min_y2
            min_y2= y2;
            association(i)= lm_ind;
        end
    end
    
end
z(association == 0, :)= [];
association= association( association ~= 0);
% association_full = association;
end

