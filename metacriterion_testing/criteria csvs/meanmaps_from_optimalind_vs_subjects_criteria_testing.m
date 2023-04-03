clear variables

scriptPath = fileparts(mfilename('fullpath'));

[ALLEEG EEG CURRENTSET ALLCOM] = eeglab;

% CHANGE OUTPUT DIRECTORY HERE %
outputFolderPath = fullfile(scriptPath, 'meanmaps_from_indmaps_csvs');
% CHANGE INPUT DIRECTORY HERE %
inputFolderPath = fullfile(scriptPath, '../EEGLAB sets', 'TD_EC_EO_3-11microstates');
meanInputFolderPath = fullfile(scriptPath, '../EEGLAB sets', 'TD_EC_EO_Mean_Sets');

% Load the selected datasets
files = dir(inputFolderPath);
filenames = {files(3:end).name};

EEG = pop_loadset('filename', filenames, 'filepath', inputFolderPath);
[ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET);

% Load mean sets - CHANGE MEAN SET NAMES HERE
EEG = pop_loadset('filename', 'EC Mean From Optimal Ind Maps_71 channels_IQMSNR.set', 'filepath', meanInputFolderPath);
[ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET);
EEG = pop_loadset('filename', 'EO Mean From Optimal Ind Maps_71 channels_IQMSNR.set', 'filepath', meanInputFolderPath);
[ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET);

% SET METACRITERION TYPE TO USE HERE %
useIQMSNR = 1;      % 1 = use IQM/SNR metacriterion, 0 = use median vote metacriterion
if useIQMSNR
    metacriterionName = 'IQMSNR';
else
    metacriterionName = 'Median Vote';
end

% Generate metacriteria
for i=1:numel(ALLEEG)

    [EEG ALLEEG CURRENTSET] = eeg_retrieve(ALLEEG, i);

    % Replace individal maps with mean maps
    if contains(EEG.setname, 'EC')
        EEG.msinfo.MSMaps = ALLEEG(numel(ALLEEG)-1).msinfo.MSMaps;
        subFolderPath = ['ECMaps_' metacriterionName];
    elseif contains(EEG.setname, 'EO')
        EEG.msinfo.MSMaps = ALLEEG(numel(ALLEEG)).msinfo.MSMaps;
        subFolderPath = ['EOMaps_' metacriterionName];        
    end

    fprintf("~~~~Beginning criterion computations for dataset %i~~~~~\n", i);
    % Run with all GFP peaks
    tic
    [criteria, numGFPPeaks] = generate_criteria_GFPpeaks(EEG, inf);
    toc
    for j=1:numel(criteria)
        criteria(j).run_no = 1;
        criteria(j).sample_size = numGFPPeaks;
    end

    fprintf("Generating csv for dataset %i\n", i);

    % Reorder struct
    criteria = orderfields(criteria, [9, 10, 1:8]);

    % make table
    outputTable = struct2table(criteria);

    % Rename cluster columns
    oldNames = arrayfun(@(x) sprintf("clust%i", x), 4:10);
    outputTable = renamevars(outputTable, oldNames, string(4:10));

    writetable(outputTable, fullfile(outputFolderPath, subFolderPath, [EEG.setname '_criteria_results.csv']));
end