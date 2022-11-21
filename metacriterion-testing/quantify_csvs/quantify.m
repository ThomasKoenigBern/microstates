clear variables

dataType = 'Subject-level 71 channels';
scriptPath = fileparts(mfilename('fullpath'));

if strcmp(dataType, 'Subject-level 71 channels')
    folderName = fullfile(scriptPath, '../criteria csvs', 'individual_csvs_71channels');
    clusteredSetsPath = fullfile(scriptPath, '../EEGLAB sets', 'TD_EC_EO_3-11microstates');
elseif strcmp(dataType, 'Subject-level 10-20 channels')
    folderName = fullfile(scriptPath, '../criteria csvs', 'individual_csvs_1020channels');
    clusteredSetsPath = fullfile(scriptPath, '../EEGLAB sets', 'TD_EC_EO_3-11microstates_1020channels');
elseif strcmp(dataType, 'ECEO Mean 71 channels')
    folderName = fullfile(scriptPath, '../criteria csvs', 'meanmap_csvs_71channels');
    clusteredSetsPath = fullfile(scriptPath, '../EEGLAB sets', 'TD_EC_EO_3-11microstates');
elseif strcmp(dataType, 'ECEO Mean 10-20 channels')
    folderName = fullfile(scriptPath, '../criteria csvs', 'meanmap_csvs_1020channels');
    clusteredSetsPath = fullfile(scriptPath, '../EEGLAB sets', 'TD_EC_EO_3-11microstates_1020channels');
end

[ALLEEG EEG CURRENTSET ALLCOM] = eeglab;

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
if contains(dataType, '10-20')
    ECMeanSet = 'ECMean_1020channels';
    EOMeanSet = 'EOMean_1020channels';
elseif contains(dataType, '71')
    ECMeanSet = 'ECMean';
    EOMeanSet = 'EOMean';
end

EEG = pop_loadset('filename', [ECMeanSet '.set'], 'filepath', meanClusteredSetsPath);
[ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET);
EEG = pop_loadset('filename', [EOMeanSet '.set'], 'filepath', meanClusteredSetsPath);
[ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET);
   
FitPar.PeakFit = 1;
FitPar.b = 0;
FitPar.lambda = 0;
FitPar.BControl = 0;
FitPar.Normalize = 0;
FitPar.Rectify = 0;

ClusterNumbers = 4:10;

mkdir(fullfile(scriptPath, dataType, 'EC'))
mkdir(fullfile(scriptPath, dataType, 'EO'))

% Quantify EC sets
for c=ClusterNumbers
    FitPar.nClasses = c;
    csvName = fullfile(scriptPath, dataType, 'EC', sprintf('quantify_%i classes.csv', c));
    [EEG CURRENTSET] = pop_QuantMSTemplates(ALLEEG, ECindices, 1, FitPar, numel(ALLEEG)-1, ECMeanSet, csvName);
end

% Quantify EC sets
for c=ClusterNumbers
    FitPar.nClasses = c;
    csvName = fullfile(scriptPath, dataType, 'EO', sprintf('quantify_%i classes.csv', c));
    [EEG CURRENTSET] = pop_QuantMSTemplates(ALLEEG, EOindices, 1, FitPar, numel(ALLEEG), EOMeanSet, csvName);
end