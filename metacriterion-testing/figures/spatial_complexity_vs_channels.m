% clear variables
% 
% scriptPath = fileparts(mfilename('fullpath'));
% 
% %% Load the 71 channel datasets
% [ALLEEG EEG CURRENTSET ALLCOM] = eeglab;
% 
% inputFolderPath = fullfile(scriptPath, '../EEGLAB sets', 'TD_EC_EO_3-11microstates');
% files = dir(fullfile(scriptPath, '../EEGLAB sets', 'TD_EC_EO_3-11microstates'));
% filenames = {files(3:end).name};
% 
% EEG = pop_loadset('filename', filenames, 'filepath', inputFolderPath);
% [ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET);
% 
% %% Compute spatial complexity for random subsets of channels for each dataset
% sigma = nan(numel(filenames), 62);
% phi = nan(numel(filenames), 62);
% omega = nan(numel(filenames), 62);
% channelNumbers = 10:71;
% 
% for i=1:numel(filenames)
%     [EEG ALLEEG CURRENTSET] = eeg_retrieve(ALLEEG, i);
% 
%     for j=1:62
%         index = randperm(channelNumbers(j));
%         tmpEEG = pop_select(EEG, 'channel', index(1:channelNumbers(j)));
%         [sigma(i,j), phi(i,j), omega(i,j)] = eeglab_sphio(tmpEEG);
%     end
% 
% end

clear variables
load(fullfile(scriptPath, 'spatial complexity plots', 'sigma.mat'));
load(fullfile(scriptPath, 'spatial complexity plots', 'phi.mat'));
load(fullfile(scriptPath, 'spatial complexity plots', 'omega.mat'));

%% Create scatterplots of spatial complexity vs. number of channels
tiledlayout(1,3);
nexttile;
scatter(10:71, sigma, 20, 'filled');
xlabel('Number of channels');
ylabel('Sigma');
title('Sigma');

nexttile;
scatter(10:71, phi, 20, 'filled');
xlabel('Number of channels');
ylabel('Phi');
title('Phi');

nexttile;
scatter(10:71, omega, 20, 'filled');
xlabel('Number of channels');
ylabel('Omega');
title('Omega');

saveas(gcf, fullfile(scriptPath, 'spatial complexity plots', 'spatial_complexity_vs_channels'));