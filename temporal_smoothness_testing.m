% script to produce explained variance, duration, and occurence values for
% different temporal smoothness penalties
%
% DATASET: s1_TD_EC
%
% CLUSTER PARAMETERS
% GFPPeaks = 1
% 
% FITTING PARAMETERS
% PeakFit = 0
% nClasses = 4
% BControl (remove truncated microstates) = 0
% b (smoothness window) = 50 ms
% lambda (smoothness penalty) = 0-5 in increments of 0.1

PeakFit = 0;
nClasses = 4;
BControl = 0;
b = 50;
lambdas = 0:0.1:5;
path = "C:\Users\delar\Box\1_Core Clinical Team\1_Sahana Nagabhushan Kalburgi\" + ...
    "1_Data Science Projects\2_Microstate Toolbox Updates Project\Temporal Smoothness Testing\" + ...
    "s1_TD_EC_GFPpeaks_own_no truncate_50 ms window";

% % Load the dataset
% [ALLEEG EEG CURRENTSET ALLCOM] = eeglab;
% EEG = pop_loadset('filename','s1_TD_EC.set','filepath','C:\\Users\\delar\\Documents\\eeglab2021.1\\sample_data\\test_files\\');
% [ALLEEG, EEG, CURRENTSET] = eeg_store( ALLEEG, EEG, 0 );
% [ALLEEG, EEG, com] = pop_FindMSTemplates(ALLEEG, EEG, CURRENTSET, struct('MinClasses', 3, 'MaxClasses', 7, 'GFPPeaks', 1, 'IgnorePolarity', 1, 'MaxMaps', Inf, 'Restarts', 25, 'UseAAHC', 0, 'Normalize', 1), 0, 0, 1);
% [ALLEEG EEG] = eeg_store(ALLEEG, EEG, CURRENTSET);
% 
% % Quantify with increasing smoothness penalty and save all csvs
% for lambda=lambdas
%     filename = sprintf('GFPpeaks_own_no truncate_50 ms window_%1.1f lambda.csv', lambda);
%     [ALLEEG EEG com] = pop_QuantMSTemplates(ALLEEG, [1], 0, ...
%         struct('b',b,'lambda',lambda,'PeakFit',PeakFit,'nClasses',nClasses,'BControl',BControl,'Rectify',0,'Normalize',0), ...
%         [], fullfile(path, filename));
%     [ALLEEG EEG] = eeg_store(ALLEEG, EEG, CURRENTSET);
% end

% Combine the explained variance, duration, and occurence data into one csv
% combinedtable = table();
% for i=1:51
%     filename = sprintf('GFPpeaks_own_no truncate_50 ms window_%1.1f lambda.csv', lambdas((i)));
%     
%     % extract the variables we want
%     tbl = readtable(fullfile(path, filename));
%     tbl = tbl(:, [7:12, 18:21, 23:26]);
%     combinedtable = [combinedtable; tbl];
% end
% writetable(combinedtable, fullfile(path, 'combined.csv'));

combinedtable = readtable(fullfile(path, 'combined.csv'));

% Create plots for the explained variance
figure('name', 'Global Explained Variance');
tiledlayout(3,1);

% Individual
nexttile
plot(lambdas, combinedtable.IndExpVar_MS_A);
hold on
plot(lambdas, combinedtable.IndExpVar_MS_B);
hold on
plot(lambdas, combinedtable.IndExpVar_MS_C);
hold on
plot(lambdas, combinedtable.IndExpVar_MS_D);
title('Individual GEVs (new)')
xlabel('lambda');
ylabel('Individual GEV');
legend('MS A', 'MS B', 'MS C', 'MS D');

% Old total GEV
nexttile
plot(lambdas, combinedtable.ExpVar);
title('Total GEV (old)')
xlabel('lambda');
ylabel('GEV');

% New total GEV
nexttile
plot(lambdas, combinedtable.ExpVarTotal);
title('Total GEV (new)')
xlabel('lambda');
ylabel('GEV');

% Create plots for duration and occurence
figure('Name', 'Duration and Occurrence');
tiledlayout(2, 1);

% Duration
nexttile
plot(lambdas, combinedtable.Duration_MS_A*1000);
hold on
plot(lambdas, combinedtable.Duration_MS_B*1000);
hold on
plot(lambdas, combinedtable.Duration_MS_C*1000);
hold on
plot(lambdas, combinedtable.Duration_MS_D*1000);
title('Duration');
xlabel('lambda');
ylabel('Duration (ms)');
legend('MS A', 'MS B', 'MS C', 'MS D');

% Occurence
nexttile
plot(lambdas, combinedtable.Occurrence_MS_A);
hold on
plot(lambdas, combinedtable.Occurrence_MS_B);
hold on
plot(lambdas, combinedtable.Occurrence_MS_C);
hold on
plot(lambdas, combinedtable.Occurrence_MS_D);
title('Occurence');
xlabel('lambda');
ylabel('Occurence');
legend('MS A', 'MS B', 'MS C', 'MS D');