clear variables

ClusterNumbers = 4:10;

scriptPath = fileparts(mfilename('fullpath'));

[ALLEEG EEG CURRENTSET ALLCOM] = eeglab;

clusteredSetsPath = fullfile(scriptPath, '../EEGLAB sets', 'TD_EC_EO_3-11microstates_1020channels');
meanClusteredSetsPath = fullfile(scriptPath, '../EEGLAB sets', 'TD_EC_EO_Mean_Sets');

% Load the selected datasets
files = dir(clusteredSetsPath);
filenames = {files(3:end).name};

EEG = pop_loadset('filename', filenames, 'filepath', clusteredSetsPath);
[ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET);

% Get EC and EO indices
ECindices = find(contains({ALLEEG.setname}, 'EC'));
EOindices = find(contains({ALLEEG.setname}, 'EO'));

% Load mean sets
EEG = pop_loadset('filename', 'ECMean_1020channels.set', 'filepath', meanClusteredSetsPath);
[ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET);
EEG = pop_loadset('filename', 'EOMean_1020channels.set', 'filepath', meanClusteredSetsPath);
[ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET);
   
FitPar.PeakFit = 1;
FitPar.b = 0;
FitPar.lambda = 0;
FitPar.BControl = 0;
FitPar.Normalize = 0;
FitPar.Rectify = 0;

% Quantify EC sets
for c=ClusterNumbers
    FitPar.nClasses = c;
    csvName = sprintf('quantify_results/EC/quantify_ECMean_%iclasses.csv', c);
    [EEG CURRENTSET] = pop_QuantMSTemplates(ALLEEG, ECindices, 1, FitPar, numel(ALLEEG)-1, 'ECMean_1020channels', csvName);
end

% Quantify EC sets
for c=ClusterNumbers
    FitPar.nClasses = c;
    csvName = sprintf('quantify_results/EO/quantify_EOMean_%iclasses.csv', c);
    [EEG CURRENTSET] = pop_QuantMSTemplates(ALLEEG, EOindices, 1, FitPar, numel(ALLEEG), 'EOMean_1020channels', csvName);
end