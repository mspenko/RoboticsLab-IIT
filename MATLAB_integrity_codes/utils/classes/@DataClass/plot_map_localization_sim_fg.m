
function plot_map_localization_sim_fg(obj, estimator, params)

% Plot GPS+IMU estimated path
figure; hold on; grid on;

% plot waypoints
%plot(params.way_points(1,:), params.way_points(2,:), 'gp', 'markersize', 12, 'MarkerFaceColor', 'r');
plot(params.way_points(1,:), params.way_points(2,:), 'ro', 'markersize', 7);

% plot true path
% plot(obj.update.x_true(1,:), obj.update.x_true(2,:), 'k-','markersize', 7);

% if online --> plot estimated path as well
if ~params.SWITCH_OFFLINE
    plot(obj.update.XX(1,:), obj.update.XX(2,:), 'k.','markersize', 7);
    %plot(obj.update.XX(1,:), obj.update.XX(2,:), '.-','markersize', 7);
end

% plot GPS msmts
if ~isempty(obj.gps_msmts)
    plot(obj.gps_msmts(:,1), obj.gps_msmts(:,2), 'r*', 'markersize', 4);
end

% create a map of landmarks
lm_map= [estimator.landmark_map(:,1),...
    estimator.landmark_map(:,2),...
    zeros(estimator.num_landmarks,1)];
plot(lm_map(:,1), lm_map(:,2), 'b+', 'markersize', 5);%2.5);

% plot lidar msmts 
if ~isempty(obj.msmts)
    plot(obj.msmts(:,1), obj.msmts(:,2), 'k.');
end

plot(obj.update.XX(1,1), obj.update.XX(2,1), 'x', 'Color',[0.9290 0.6940 0.1250], 'linewidth', 6);%2);
plot(obj.update.XX(1,1), obj.update.XX(2,1), '.', 'Color',[0.9290 0.6940 0.1250], 'linewidth', 2);%3);

% plot attitude every 10 readings
%for i= 1:length(obj.update.XX)
%    if rem(i,10) == 0
%        R_NB= R_NB_rot( 0, 0, obj.update.XX(3,i));
%        xyz_N= R_NB*params.xyz_B + obj.update.XX(:,i);
%        plot(xyz_N(1,:), xyz_N(2,:), 'g.', 'linewidth', 40);
%    end
%end
set(gca,'FontSize',12)
xlabel('X [m]','FontSize',12); ylabel('Y [m]','FontSize',12); zlabel('Z [m]','FontSize',12);
%axis equal

end