%% Import dataset
clear;
clc;
close all;
%load('P_I_regdepth_PR.mat');
load('testrun4.mat');
%load('plattform3_hivroll.mat');

%% Filter fusion gyro and accelerometer
% Initialize vectors
dataset_length = length(ax);
delta_pitch_acc = zeros(1, dataset_length);
delta_roll_acc = zeros(1, dataset_length);
delta_pitch_gyro = zeros(1, dataset_length);
delta_roll_gyro = zeros(1, dataset_length);
delta_yaw_gyro = zeros(1, dataset_length);
est_delta_pitch = zeros(1, dataset_length);
est_delta_roll = zeros(1, dataset_length);
est_pitch = zeros(1, dataset_length);
est_roll = zeros(1, dataset_length);
weight_acc = zeros(1, dataset_length);
weight_acc_roll = zeros(1, dataset_length);
weight_acc_pitch = zeros(1, dataset_length);
weight_gyro_pitch = zeros(1, dataset_length);
weight_gyro_roll = zeros(1, dataset_length);
weight_gyro_yaw = zeros(1, dataset_length);

% Initial condition
pitch_k_1 = 0;
roll_k_1 = 0;
timestep = 0.1; % 10 Hz sampling frequency.

for i=1:dataset_length
    
   % ----------------------------------------------------------------------
   % ACCELEROMETER
   % ----------------------------------------------------------------------
   ax_k = ax(i)/1000;
   ay_k = ay(i)/1000;
   az_k = az(i)/1000;
   
   % Normalize measurements.
   abs_k = sqrt(ax_k^2 + ay_k^2 + az_k^2);
   ax_k = ax_k/abs_k;
   ay_k = ay_k/abs_k;
   az_k = az_k/abs_k;
   
   % Calculate pitch, roll
   pitch_k = atan2(ax_k, sqrt(ay_k^2 + az_k^2));
   roll_k = atan2(ay_k, az_k);
   
   % Rad -> deg
   pitch_k = pitch_k * 180 / pi;
   roll_k = roll_k * 180 / pi;
   
   % Calculate delta_pitch, delta_roll
   if(i>1)      
      delta_pitch_acc(i) = pitch_k - est_pitch(i-1);
      delta_roll_acc(i) = roll_k - est_roll(i-1);
   else 
      delta_pitch_acc(i) = pitch_k;
      delta_roll_acc(i) = roll_k;
   end
   
   
   % Calculate accelerometer weight
   abs_diff = abs(abs_k - 1);
   
   % Thruster compensation
   th1(i) = th1(i)*3;
   th2(i) = th2(i)*3;
   th3(i) = th3(i)*3;
   th4(i) = th4(i)*3;
   th5(i) = th5(i)*3;
   th6(i) = th6(i)*3;
   th7(i) = th7(i)*3;
   th8(i) = th8(i)*3;
   %th_abs_k = sqrt(th1(i)^2 + th2(i)^2 + th3(i)^2 + th4(i)^2 + th5(i)^2 + th6(i)^2 ...
   % + th7(i)^2 + th8(i)^2);
   %th_abs_k = th_abs_k/200;
   th_abs_k = abs(th1(i)) + abs(th2(i)) + abs(th3(i)) + abs(th4(i)) + ...
       abs(th5(i)) + abs(th6(i)) + abs(th7(i)) + abs(th8(i));
   th_abs_k = th_abs_k/800;
   weight_acc(i) = 1;%/(abs_diff + 1);
   
   if(th_abs_k < 0.25)
       weight_acc(i) = weight_acc(i) - 3*th_abs_k;
   else 
       weight_acc(i) = weight_acc(i) - 0.75;
   end
   delta_pitch_k = pitch_k - pitch_k_1;
   delta_roll_k = roll_k - roll_k_1;
   pitch_k_1 = pitch_k;
   roll_k_1 = roll_k;
   
   if (delta_pitch_k > 1)
       weight_acc_pitch(i) = weight_acc(i)/delta_pitch_k;
   elseif (delta_pitch_k < -1)
       weight_acc_pitch(i) = - weight_acc(i)/delta_pitch_k;
   else
       weight_acc_pitch(i) = weight_acc(i);
   end
   
   if (delta_roll_k > 1)
       weight_acc_roll(i) = weight_acc(i)/delta_roll_k;
   elseif (delta_roll_k < -1)
       weight_acc_roll(i) = - weight_acc(i)/delta_roll_k;
   else
       weight_acc_roll(i) = weight_acc(i);
   end
   
   
   % ----------------------------------------------------------------------
   % GYROSCOPE
   % ----------------------------------------------------------------------
   % Convert to degrees per second
%    gx_k = gx(i)*1000/(2^15-1);
%    gy_k = gy(i)*1000/(2^15-1);
%    gz_k = gz(i)*1000/(2^15-1);
   gx_k = gx(i)*0.00875;
   gy_k = gy(i)*0.00875;
   gz_k = gz(i)*0.00875;
   % Platform:
%    gx_k = gx(i)/0.30517;
%    gy_k = gy(i)/0.30517;
%    gz_k = gz(i)/0.30517;
   
   % Calculate delta_pitch, delta_roll, delta_yaw
   delta_pitch_gyro(i) = timestep*gy_k;
   delta_roll_gyro(i) = timestep*gx_k;
   delta_yaw_gyro(i) = timestep*gz_k;
   
   % Calculate gyroscope weights
   gain_pitch = 1/4;
   gain_roll = 1/9;
   weight_gyro_pitch(i) = abs(gain_pitch*gy_k);
   weight_gyro_roll(i) = abs(gain_roll*gx_k);
   weight_gyro_yaw(i) = abs(sqrt(gz_k)/4);
   
   if(weight_gyro_pitch(i)>1); weight_gyro_pitch(i) = 1; end;
   if(weight_gyro_roll(i)>1); weight_gyro_roll(i) = 1; end;
   
   % ----------------------------------------------------------------------
   % FUSION
   % ----------------------------------------------------------------------
   % Combine gyroscope and accelerometer estimates:
   est_delta_pitch(i) = delta_pitch_acc(i) * weight_acc_pitch(i) + ...
                            delta_pitch_gyro(i) * weight_gyro_pitch(i);
   est_delta_roll(i) = delta_roll_acc(i) * weight_acc_roll(i) + ...
                        delta_roll_gyro(i) * weight_gyro_roll(i);
   % Divide by sum of weights:
   est_delta_pitch(i) = est_delta_pitch(i)/(weight_acc_pitch(i) + weight_gyro_pitch(i));
   est_delta_roll(i) = est_delta_roll(i)/(weight_acc_roll(i) + weight_gyro_roll(i));
   
   % Calculate new estimate:
   if(i>1)
        est_pitch(i) = est_pitch(i-1) + est_delta_pitch(i);
        est_roll(i) = est_roll(i-1) + est_delta_roll(i);
   else
       est_pitch(i) = est_delta_pitch(i);
       est_roll(i) = est_delta_roll(i);
   end;
end

%% Plot before and after gyro/accelerometer fusion
% 1/10 degrees -> degrees
pitch_acc_plot = (pitch./10)';
roll_acc_plot = (roll./10)';

pitch_fus_plot = est_pitch;
roll_fus_plot = est_roll;
time = 0:timestep:(timestep*dataset_length - timestep);

% Sine wave for Stewart platform test
% sine_wave = 20*sin(0.25*2*pi*time-10.4);

 subplot(2,1,1);
plot(time, pitch_acc_plot);hold on; plot(time, pitch_fus_plot,'LineWidth', 1);
legend('Akselerometer stamp' ,'Filtrert stamp');
xlabel('Tid [s]'); ylabel('Vinkel [grader]');
%axis([45 55 -6 6]);

% plot(time, pitch./10, 'LineWidth', 1);
% legend('Stamp');
% xlabel('Tid [s]'); ylabel('Vinkel [grader]');
% axis([0 120 -5 5]);

subplot(2,1,2);

% plot(time, roll./10, 'LineWidth', 1);
% legend('Rull');
% xlabel('Tid [s]'); ylabel('Vinkel [grader]');
% axis([0 120 -5 5]);

% % Roll
plot(time, roll_acc_plot); hold on; plot(time, roll_fus_plot, 'LineWidth', 1);
legend('Akselerometer rull' ,'Filtrert rull');
xlabel('Tid [x100 ms]'); ylabel('Vinkel [grader]');
% axis([20 50 -30 10]);

% Weights
% plot(time, weight_acc_roll, time, weight_gyro_roll, 'LineWidth', 1);
% legend('Vekt akselerometer', 'Vekt gyroskop'); xlabel('Tid [x100 ms]');
%axis([30 40 -0.2 1.2]);

% subplot(3,1,3);

% plot(time, depth./1000, 'LineWidth', 1);
% legend('Dybde');
% xlabel('Tid [s]'); ylabel('Dybde [m]');

% Thrusters
% th_abs = sqrt(th1.^2 + th2.^2 + th3.^2 + th4.^2 + th5.^2 + th6.^2 ...
%     + th7.^2 + th8.^2);
% th_abs = th_abs./200;
% plot(time, th_abs, 'LineWidth', 1.5);
% legend('Absolutt thrusterp�drag');
% xlabel('Tid [s]');
%axis([45 55 0.23 0.27]);


% foer = std(pitch(200:1200))/10;
% etter = std(est_pitch(200:1200));
% fprintf('Standardavvik f�r var: %.3f \nStandardavvik etter var: %.3f \nDifferansen var: %.3f%%', ...
%     foer, etter, (foer-etter)*100/foer);

% Find bigggest derivatives
d_pitch_unfiltered = zeros(1, 1000);
d_pitch_filtered = zeros(1, 1000);
for i=200:length(pitch)
    d_pitch_unfiltered(i-199) = (pitch(i) - pitch(i-1)) * 10;
    d_pitch_filtered(i-199) = (est_pitch(i) - est_pitch(i-1)) * 10;
    
    d_roll_unfiltered(i-199) = (roll(i) - roll(i-1)) * 10;
    d_roll_filtered(i-199) = (est_roll(i) - est_roll(i-1)) * 10;
    
    % 0.1 deg -> 1 deg
    d_pitch_unfiltered(i-199) = d_pitch_unfiltered(i-199)/10;
    d_roll_unfiltered(i-199) = d_roll_unfiltered(i-199)/10;

end

%Plot measurement noise
% time2 = 20:0.1:(length(pitch)/10); figure(2); subplot(2,1,1); 
% plot(time2, d_pitch_unfiltered, 'LineWidth', 1);
% legend('Ufiltrert stampvinkel');
% xlabel('Tid [s]'); ylabel('dx/dt');
% axis([20 120 -100 100]);
% 
% 
% subplot(2,1,2);
% plot(time2, d_pitch_filtered, 'LineWidth',1)
% legend('Filtrert stampvinkel');
% xlabel('Tid [s]'); ylabel('dx/dt');
% axis([20 120 -100 100]);

