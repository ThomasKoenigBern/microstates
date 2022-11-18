clear variables

scriptPath = fileparts(mfilename('fullpath'));

%% Load the 71 channel datasets
[ALLEEG EEG CURRENTSET ALLCOM] = eeglab;

inputFolderPath = fullfile(scriptPath, '../EEGLAB sets', 'TD_EC_EO_3-11microstates');
files = dir(fullfile(scriptPath, '../EEGLAB sets', 'TD_EC_EO_3-11microstates'));
filenames = {files(3:end).name};

EEG = pop_loadset('filename', filenames, 'filepath', inputFolderPath);
[ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET);

%% Compute spatial complexity for the 71 channel datasets
sigma71 = nan(1, numel(filenames));
phi71 = nan(1, numel(filenames));
omega71 = nan(1, numel(filenames));
for i=1:numel(ALLEEG)

    [EEG ALLEEG CURRENTSET] = eeg_retrieve(ALLEEG, i);
    [sigma71(i) phi71(i) omega71(i)] = eeglab_sphio(EEG);

end

%% Load the 10-20 channel datasets
[ALLEEG EEG CURRENTSET ALLCOM] = eeglab;

inputFolderPath = fullfile(scriptPath, '../EEGLAB sets', 'TD_EC_EO_3-11microstates_1020channels');
files = dir(fullfile(scriptPath, '../EEGLAB sets', 'TD_EC_EO_3-11microstates_1020channels'));
filenames = {files(3:end).name};

EEG = pop_loadset('filename', filenames, 'filepath', inputFolderPath);
[ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET);

%% Compute spatial complexity for the 10-20 channel datasets
sigma1020 = nan(1, numel(filenames));
phi1020 = nan(1, numel(filenames));
omega1020 = nan(1, numel(filenames));
for i=1:numel(ALLEEG)

    [EEG ALLEEG CURRENTSET] = eeg_retrieve(ALLEEG, i);
    [sigma1020(i) phi1020(i) omega1020(i)] = eeglab_sphio(EEG);

end

%% Plot spatial complexity 71 channels vs. 10-20 channels
tiledlayout(3,1);

nexttile
scatter(1:numel(filenames), [sigma71; sigma1020], 'filled');
legend('71 channels', '10-20 channels');
title('Sigma');

nexttile
scatter(1:numel(filenames), [phi71; phi1020], 'filled');
legend('71 channels', '10-20 channels');
title('Phi');

nexttile
scatter(1:numel(filenames), [omega71; omega1020], 'filled');
legend('71 channels', '10-20 channels');
title('Omega');
saveas(gcf, fullfile(scriptPath, 'spatial complexity plots', 'spatial_complexity_scatterplots.fig'));
