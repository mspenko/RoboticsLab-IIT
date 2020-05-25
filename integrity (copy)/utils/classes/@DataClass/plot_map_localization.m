
function plot_map_localization(obj, estimator, gps, num_readings, params)

% Plot GPS+IMU estimated path

figure; hold on; grid on;
plot3(obj.pred.XX(1,:), obj.pred.XX(2,:), obj.pred.XX(3,:), 'b.');
plot3(obj.update.XX(1,:), obj.update.XX(2,:), obj.update.XX(3,:),...
    'b.','markersize', 7);

if (~params.SWITCH_SM)
    plot3(gps.msmt(1,:),gps.msmt(2,:),gps.msmt(3,:),'r*');
end

% create a map of landmarks
lm_map= [estimator.landmark_map(:,1),...
    estimator.landmark_map(:,2),...
    zeros(estimator.num_landmarks,1)];
plot3(lm_map(:,1), lm_map(:,2), lm_map(:,3), 'g+', 'markersize',20);
if params.SWITCH_LIDAR_UPDATE
    plot3(obj.msmts(:,1), obj.msmts(:,2), zeros(size(obj.msmts,1),1), 'k.');
end

% plot attitude every 100 IMU readings
for i= 1:num_readings
    if rem(i,100) == 0
        R_NB= R_NB_rot(obj.pred.XX(7,i), obj.pred.XX(8,i), obj.pred.XX(9,i));
        xyz_N= R_NB*params.xyz_B + obj.pred.XX(1:3,i);
        plot3(xyz_N(1,:), xyz_N(2,:), xyz_N(3,:), 'g-', 'linewidth', 2);
    end
end
xlabel('x [m]'); ylabel('y [m]'); zlabel('z [m]');
axis equal

end