[ALLEEG EEG CURRENTSET ALLCOM] = eeglab;

clusteredSetsPath = 'TD_EC_EO_3-11microstates\';

% Load the selected datasets
files = dir(clusteredSetsPath);
filenames = {files(3:end).name};

EEG = pop_loadset('filename', filenames, 'filepath', clusteredSetsPath);
[ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET);

% Find EC and EO indices
ECindices = find(contains(filenames, 'EC'));
EOindices = find(contains(filenames, 'EO'));

% Generate metacriteria
for i=34:numel(ALLEEG)

    [EEG ALLEEG CURRENTSET] = eeg_retrieve(ALLEEG, i);
    
    fprintf("~~~~Beginning criterion computations for dataset %i~~~~~\n", i);

    msinfoNames = fieldnames(msinfo);
    if contains(filenames{i}, 'EC')
        msinfoNames = msinfoNames(contains(msinfoNames, 'EC'));
    else
        msinfoNames = msinfoNames(contains(msinfoNames, 'EO'));
    end

    % Replace individal maps with mean maps for both cases
    for j=1:numel(msinfoNames)
        msinfoName = msinfoNames{j};

        EEG.msinfo = msinfo.(msinfoName);
    
        % Run with all GFP peaks
        tic
        [criteria, numGFPpeaks] = generate_criteria_GFPpeaks(EEG, inf);
        toc
        for k=1:numel(criteria)
            criteria(k).run_no = 1;
            criteria(k).sample_size = numGFPpeaks;
        end
    
        fprintf("Generating csv %i for dataset %i\n", j, i);
    
        % Reorder struct
        criteria = orderfields(criteria, [9, 10, 1:8]);
    
        % make table
        outputTable = struct2table(criteria);
    
        % Rename cluster columns
        oldNames = arrayfun(@(x) sprintf("clust%i", x), 4:10);
        outputTable = renamevars(outputTable, oldNames, string(4:10));
    
        writetable(outputTable, ['meanmaps_from_indmaps_csvs/' msinfoName '/' EEG.setname '_criteria_results.csv']);
    end

end