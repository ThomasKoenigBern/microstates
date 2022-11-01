[ALLEEG EEG CURRENTSET ALLCOM] = eeglab;

clusteredSetsPath = 'TD_EC_EO_3-11microstates_1020channels\';

% Load the selected datasets
files = dir(clusteredSetsPath);
filenames = {files(3:end).name};

EOindices = find(contains(filenames, 'EO'));

EEG = pop_loadset('filename', filenames(EOindices), 'filepath', clusteredSetsPath);
[ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET);

% Load mean sets
% EEG = pop_loadset('filename', 'ECMean_1020channels.set', 'filepath', 'TD_EC_EO_Mean_Sets');
% [ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET);
EEG = pop_loadset('filename', 'EOMean_1020channels.set', 'filepath', 'TD_EC_EO_Mean_Sets');
[ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET);

% Generate metacriteria
for i=1:numel(ALLEEG)-1

    [EEG ALLEEG CURRENTSET] = eeg_retrieve(ALLEEG, i);

    % Replace individal maps with mean maps
    if contains(EEG.setname, 'EC')
        EEG.msinfo.MSMaps = ALLEEG(numel(ALLEEG)-1).msinfo.MSMaps;
    elseif contains(EEG.setname, 'EO')
        EEG.msinfo.MSMaps = ALLEEG(numel(ALLEEG)).msinfo.MSMaps;
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

    fprintf("Generating csv for dataset %i", i);

    % Reorder struct
    criteria = orderfields(criteria, [9, 10, 1:8]);

    % make table
    outputTable = struct2table(criteria);

    % Rename cluster columns
    oldNames = arrayfun(@(x) sprintf("clust%i", x), 4:10);
    outputTable = renamevars(outputTable, oldNames, string(4:10));

    writetable(outputTable, ['meanmap_csvs_1020channels/' EEG.setname '_mean_criteria_results.csv']);
end