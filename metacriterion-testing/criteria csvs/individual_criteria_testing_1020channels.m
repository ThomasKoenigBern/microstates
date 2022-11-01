[ALLEEG EEG CURRENTSET ALLCOM] = eeglab;

clusteredSetsPath = 'TD_EC_EO_3-11microstates\';

% Load the selected datasets
filepath = '..\..\..\sample_data\test_files\';
files = dir(clusteredSetsPath);
filenames = {files(3:end).name};

EEG = pop_loadset('filename', filenames, 'filepath', filepath);
[ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET);

% Select only 10-20 channels
[EEG ALLEEG CURRENTSET] = eeg_retrieve(ALLEEG, 1:numel(ALLEEG));
EEG = pop_select(EEG, 'channel',{'E9','E11','E22','E24','E33','E36','E45','E52','E58','E62','E70','E75','E83','E92','E96','E104','E108','E122','E124','Cz'});
EEG = eeg_checkset( EEG );
[ALLEEG EEG CURRENTSET] = eeg_store(ALLEEG, EEG, CURRENTSET);    

% Clustering
MinClust = 3;
MaxClust = 11;
NumRestarts = 10;
ClustType = 0; %k-means = 0, AAHC = 1
ClustPars = struct('MinClasses',MinClust,'MaxClasses',MaxClust,'GFPPeaks',true,'IgnorePolarity',true,'MaxMaps',inf,'Restarts',NumRestarts, 'UseAAHC', ClustType,'Normalize',true);

[EEG,CURRENTSET] = pop_FindMSTemplates(ALLEEG, 1:numel(ALLEEG), ClustPars, 0, 0);
[ALLEEG EEG CURRENTSET] = eeg_store(ALLEEG, EEG, CURRENTSET);

% Save clustered datasets
for i=1:numel(ALLEEG)
    [EEG ALLEEG CURRENTSET] = eeg_retrieve(ALLEEG, i);
    EEG = pop_saveset(EEG, 'filename', EEG.setname, 'savemode', 'onefile');
end

% Generate metacriteria (only all GFP peaks)
for i=1:numel(ALLEEG)

    [EEG ALLEEG CURRENTSET] = eeg_retrieve(ALLEEG, i);
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

    writetable(outputTable, ['individual_csvs_1020channels/' EEG.setname '_1020_criteria_results.csv']);
end