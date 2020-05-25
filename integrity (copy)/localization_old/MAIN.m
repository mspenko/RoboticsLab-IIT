
clear; format short; clc; close all;

dbstop if error

configureFile;

% Initial discretization for cov. propagation
[Phi,D_bar]= linearize_discretize(u(:,1),S,taua,tauw,dT_IMU);

% ----------------------------------------------------------
% -------------------------- LOOP --------------------------
for k= 1:N_IMU-1
    disp(strcat('Epoch -> ', num2str(k)));
    
    
    % Turn off calibration updates if start moving
    if k == numEpochStatic
        SWITCH_CALIBRATION= 0; 
        PX(7,7)= sig_phi0^2;
        PX(8,8)= sig_phi0^2;
        PX(9,9)= sig_yaw0^2;
        taua= taua0;
        tauw= tauw0;
    end
        
    % Increase time count
    timeSim= T_IMU(k) - 0.75;
%     timeSim= timeSim + dT_IMU;
    timeSum= timeSum + dT_IMU;
    timeSumVirt_Z= timeSumVirt_Z + dT_IMU;
    timeSumVirt_Y= timeSumVirt_Y + dT_IMU;
    
    % ------------- IMU -------------
    IMU_update( u(:,k), g_N, taua, tauw, dT_IMU ); % only updates pose mean
    PX(1:15,1:15)= Phi*PX(1:15,1:15)*Phi' + D_bar; 
    % -------------------------------
    
    % Store data
    DATA.pred.XX(:,k)= XX(1:15);
    DATA.pred.time(k)= timeSim;
    
    % ------------- Calibration -------------
    if timeSum >= dT_cal && SWITCH_CALIBRATION
        
        z= [zeros(6,1); phi0; theta0; yaw0];
        calibration(z,H_cal,R_cal);
        
        [Phi,D_bar]= linearize_discretize(u(:,k),S_cal,taua,tauw,dT_IMU);
        
        % If GPS is calibrating initial biases, increse bias variance
        D_bar(10:12,10:12)= D_bar(10:12,10:12) + diag( [sig_ba,sig_ba,sig_ba] ).^2;
        D_bar(13:15,13:15)= D_bar(13:15,13:15) + diag( [sig_bw,sig_bw,sig_bw] ).^2;
        
        % Store data
        k_update= storeData(timeSim,k_update);

        % Reset counter
        timeSum= 0;
    end
    % ------------------------------------
    
%     % ------------- virtual msmt update >> Z vel  -------------  
%     if timeSumVirt_Z >= dT_virt_Z && SWITCH_VIRT_UPDATE_Z && ~SWITCH_CALIBRATION
%         [XX,PX]= zVelocityUpdate(XX,PX,R_virt_Z);
%         
%         % Reset counter
%         timeSumVirt_Z= 0;
%     end
%     % ---------------------------------------------------------
%     
%     % ------------- virtual msmt update >> Y vel  -------------  
%     if timeSumVirt_Y >= dT_virt_Y && SWITCH_VIRT_UPDATE_Y && ~SWITCH_CALIBRATION        
%          
%         % Yaw update
%         if SWITCH_YAW_UPDATE && norm(XX(4:6)) > minVelocityYaw
%             disp('yaw udpate');
%             yawUpdate(u(4:6,k), R_yaw_fn(norm(XX(4:6))),r_IMU2rearAxis);
%         else
%             disp('--------no yaw update------');
%         end
%         
%         % Reset counter
%         timeSumVirt_Y= 0;
%     end
%     % ---------------------------------------------------------
%     
%     % ------------------- GPS -------------------
%     if (timeSim + dT_IMU) > timeGPS
%         
%         if ~SWITCH_CALIBRATION && SWITCH_GPS_UPDATE
%             % GPS update -- only use GPS vel if it's fast
%             GPS_update(z_GPS(:,k_GPS),R_GPS(:,k_GPS),minVelocityGPS,SWITCH_GPS_VEL_UPDATE);
%             
%             % Yaw update
%             if SWITCH_YAW_UPDATE && norm(XX(4:6)) > minVelocityYaw
%                 disp('yaw udpate');
%                 yawUpdate(u(4:6,k), R_yaw_fn(norm(XX(4:6))),r_IMU2rearAxis);
%             else
%                 disp('--------no yaw update------');
%             end
%             [Phi,D_bar]= linearize_discretize(u(:,k),S,taua,tauw,dT_IMU);
% 
%             % Store data
%             k_update= storeData(timeSim,k_update);
%         end
%         
%         % Time GPS counter
%         k_GPS= k_GPS + 1;
%         timeGPS= T_GPS(k_GPS);
%     end
%     % ----------------------------------------
    
    
    
    
    
    
    % ------------- LIDAR -------------
    if (timeSim + dT_IMU) > timeLIDAR && SWITCH_LIDAR_UPDATE
        epochLIDAR= T_LIDAR(k_LIDAR,1);
        
        if ~SWITCH_CALIBRATION 
            
            
            % Read the lidar features
            z= dataReadLIDAR(fileLIDAR, lidarRange, epochLIDAR, SWITCH_REMOVE_FAR_FEATURES);
            
            % Remove people-features
            z= removeFeatureInArea(XX(1:9), z, 0,8,0,15);
            z= removeFeatureInArea(XX(1:9), z, -28,15,-24,-18);
            z= removeFeatureInArea(XX(1:9), z, -35,-27,27,30);
                        
            % NN data association
            [idf,appearances]= nearestNeighbor(z(:,1:2),appearances,R_lidar,T_NN, LM);
            
            % Lidar update
            P_bar= PX; % save the value for STORE
            XX_bar= XX;
            [gamma_k, H_k, L_k, Y_k]= lidarUpdate(z(:,1:2),idf,appearances,R_lidar,SWITCH_CALIBRATION);
            q_D_k= gamma_k' * (Y_k \ gamma_k);

            % Add to landmarks
            z= body2nav(z,XX(1:9));
            lidar_msmts= [lidar_msmts; z];
            
            % Lineariza and discretize
            [Phi,D_bar]= linearize_discretize(u(:,k),S,taua,tauw,dT_IMU);
            
            % Store data
            k_update= storeData(timeSim,k_update);
            
           
            
            if  ~isempty(gamma_k)
                
                n_k= size(gamma_k);
                Phi_k= Phi^12; % create the state evolution matrix
                Lk_pp= Phi_k - L_k*H_k*Phi_k; % Kalman gain prime-prime
                idx_to_save= [1:2,9];
                
                % store matrices while the horizon increases
                if k_IM <= PARAMS.M + 1
                    
                    % Increase preceding horizon -- Using Cells
                    if length(q_D_M) == PARAMS.M + 1
                        q_D_M(end)= [];
                    end
                    q_D_M= [q_D_k, q_D_M];
                    
                    
                    if length(Phi_M_cell) == PARAMS.M + 1
                        Phi_M_cell(end)= [];
                    end
                    Phi_M_cell= [{Phi_k(idx_to_save,idx_to_save)}, Phi_M_cell];
                    
                    
                    if length(gamma_M_cell) == PARAMS.M + 1
                        gamma_M_cell(end)= [];
                    end
                    gamma_M_cell= [{gamma_k}, gamma_M_cell];
                    
                    if length(Y_M_cell) == PARAMS.M + 1
                        Y_M_cell(end)= [];
                    end
                    Y_M_cell= [ {Y_k} ,Y_M_cell];
                    
                    if length(L_M_cell) == PARAMS.M + 1
                        L_M_cell(end)= [];
                    end
                    L_M_cell= [ {L_k(idx_to_save,:)} ,L_M_cell];
                    
                    if length(Lpp_M_cell) == PARAMS.M + 1
                        Lpp_M_cell(end)= [];
                    end
                    Lpp_M_cell= [ {Lk_pp(idx_to_save,idx_to_save)} ,Lpp_M_cell];
                    
                    if length(H_M_cell) == PARAMS.M + 1
                        H_M_cell(end)= [];
                    end
                    H_M_cell= [ {H_k(:,idx_to_save)}, H_M_cell];
                    
                    
                    % store matrices in steady state
                else
                    STORE.Phi_M{k_store}= Phi_M_cell;
                    STORE.gamma_M{k_store}= gamma_M_cell;
                    STORE.Y_M{k_store}= Y_M_cell;
                    STORE.L_M{k_store}= L_M_cell;
                    STORE.Lpp_M{k_store}= Lpp_M_cell;
                    STORE.H_M{k_store}= H_M_cell;
                    STORE.P_bar{k_store}= P_bar(idx_to_save,idx_to_save);
                    STORE.XX{k_store}= XX_bar(idx_to_save);
                    STORE.q_D{k_store}= sum( q_D_M );
                    
                    q_D_M= [q_D_k, q_D_M];
                    q_D_M(end)= [];
                    Phi_M_cell= [ {Phi_k(idx_to_save,idx_to_save)} , Phi_M_cell];
                    Phi_M_cell(end)= [];
                    gamma_M_cell= [ {gamma_k} , gamma_M_cell];
                    gamma_M_cell(end)= [];
                    Y_M_cell= [ {Y_k} ,Y_M_cell];
                    Y_M_cell(end)= [];
                    L_M_cell= [ {L_k(idx_to_save,:)} ,L_M_cell];
                    L_M_cell(end)= [];
                    Lpp_M_cell= [ {Lk_pp(idx_to_save,idx_to_save)} ,Lpp_M_cell];
                    Lpp_M_cell(end)= [];
                    H_M_cell= [ {H_k(:,idx_to_save)}, H_M_cell];
                    H_M_cell(end)= [];
                    
                    
                    k_store= k_store + 1;
                end
                
                % counter for the IM
                k_IM= k_IM + 1;
            end
        end
        
        % Increase counters
        k_LIDAR= k_LIDAR + 1;
        timeLIDAR= T_LIDAR(k_LIDAR,2);
    end
    % ---------------------------------    
end


% extra stuff to STORE
STORE.R_lidar= R_lidar;









% Store data for last epoch
storeData(timeSim,k_update);
% ------------------------- END LOOP -------------------------
% ------------------------------------------------------------


% ------------- PLOTS -------------
numEpochInitPlot= numEpochStatic;
timeComplete= 0:dT_IMU:timeSim+dT_IMU/2;
timeMove= timeComplete(numEpochInitPlot:end);

% Plot GPS+IMU estimated path
figPath= figure; hold on; grid on;
plot3(DATA.pred.XX(1,:), DATA.pred.XX(2,:), DATA.pred.XX(3,:), 'b.');
plot3(DATA.update.XX(1,1:k_update), DATA.update.XX(2,1:k_update), DATA.update.XX(3,1:k_update),...
            'b.','markersize', 7);
plot3(z_GPS(1,:),z_GPS(2,:),z_GPS(3,:),'r*');
if SWITCH_LIDAR_UPDATE % Plot landmarks
    plot3(lidar_msmts(:,1),lidar_msmts(:,2),zeros(size(lidar_msmts,1),1),'k.'); 
    plot3(LM(:,1), LM(:,2), LM(:,3), 'g+', 'markersize',20);
end 


for i= 1:N_IMU
    if rem(i,100) == 0
        R_NB= R_NB_rot(DATA.pred.XX(7,i),DATA.pred.XX(8,i),DATA.pred.XX(9,i));
        xyz_N= R_NB*xyz_B + DATA.pred.XX(1:3,i);
        plot3(xyz_N(1,:), xyz_N(2,:), xyz_N(3,:), 'g-', 'linewidth', 2);
    end
end
xlabel('x [m]'); ylabel('y [m]'); zlabel('z [m]');
axis equal

% Plot variance estimates
SD= sqrt( DATA.update.PX(:,1:k_update) );
update_time= DATA.update.time(1:k_update);

% Plot SD -- pose
figure; hold on; title('Standard Deviations');

subplot(3,3,1); hold on; grid on;
plot(update_time, SD(1,:),'b-','linewidth',2);
ylabel('x [m]');

subplot(3,3,2); hold on; grid on;
plot(update_time, SD(2,:),'r-','linewidth',2);
ylabel('y [m]');

subplot(3,3,3); hold on; grid on;
plot(update_time, SD(3,:),'g-','linewidth',2);
ylabel('z [m]');

subplot(3,3,4); hold on; grid on;
plot(update_time, SD(4,:),'b-','linewidth',2);
ylabel('v_x [m/s]');

subplot(3,3,5); hold on; grid on;
plot(update_time, SD(5,:),'r-','linewidth',2);
ylabel('v_y [m/s]');

subplot(3,3,6); hold on; grid on;
plot(update_time, SD(6,:),'g-','linewidth',2);
ylabel('v_z [m/s]');

subplot(3,3,7); hold on; grid on;
plot(update_time, rad2deg(SD(7,:)),'b-','linewidth',2);
ylabel('\phi [deg]'); xlabel('Time [s]');

subplot(3,3,8); hold on; grid on;
plot(update_time, rad2deg(SD(8,:)),'r-','linewidth',2);
ylabel('\theta [deg]'); xlabel('Time [s]');

subplot(3,3,9); hold on; grid on;
plot(update_time, rad2deg(SD(9,:)),'g-','linewidth',2);
ylabel('\psi [deg]'); xlabel('Time [s]');
