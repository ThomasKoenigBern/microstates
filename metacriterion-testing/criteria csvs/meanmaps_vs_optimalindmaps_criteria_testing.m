clear variables

scriptPath = fileparts(mfilename('fullpath'));

[ALLEEG EEG CURRENTSET ALLCOM] = eeglab;

% CHANGE OUTPUT DIRECTORY HERE %
outputFolderPath = fullfile(scriptPath, 'meanmaps_from_indmaps_csvs');
% CHANGE INPUT DIRECTORY HERE %
meanInputFolderPath = fullfile(scriptPath, '../EEGLAB sets', 'TD_EC_EO_Mean_Sets');

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

    fprintf("~~~~Beginning criterion computations for dataset %i~~~~~\n", i);
    % Run with all GFP peaks
    tic
    criteria = generate_criteria_IndMaps(EEG.msinfo, EEG.data);
    toc
    for j=1:numel(criteria)
        criteria(j).run_no = 1;
        criteria(j).sample_size = size(maps.(mapName), 1);
    end

    fprintf("Generating csv for dataset %i\n", i);

    % Reorder struct
    criteria = orderfields(criteria, [9, 10, 1:8]);

    % make table
    outputTable = struct2table(criteria);

    % Rename cluster columns
    oldNames = arrayfun(@(x) sprintf("clust%i", x), 4:10);
    outputTable = renamevars(outputTable, oldNames, string(4:10));

    if contains(EEG.setname, 'EC')
        outputFileName = ['ECMaps_' metacriterionName '_criteria_results.csv'];
    elseif contains(EEG.setname, 'EO')
        outputFileName = ['EOMaps_' metacriterionName '_criteria_results.csv'];        
    end
    writetable(outputTable, fullfile(outputFolderPath, outputFileName));
end