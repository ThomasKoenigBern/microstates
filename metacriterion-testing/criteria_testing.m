function criteria_testing(SetIndices)
    [ALLEEG EEG CURRENTSET ALLCOM] = eeglab;

    clusteredSetsPath = 'TD_EC_EO_3-11microstates\';

    % Load the selected datasets
%     filepath = '..\..\..\sample_data\test_files\';
    files = dir(clusteredSetsPath);
    filenames = {files(3:end).name};
    filenames = filenames(SetIndices);

    EEG = pop_loadset('filename', filenames, 'filepath', clusteredSetsPath);
    [ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET);

    % Clustering
%     MinClust = 3;
%     MaxClust = 11;
%     NumRestarts = 10;
%     ClustType = 0; %k-means = 0, AAHC = 1
%     ClustPars = struct('MinClasses',MinClust,'MaxClasses',MaxClust,'GFPPeaks',true,'IgnorePolarity',true,'MaxMaps',inf,'Restarts',NumRestarts, 'UseAAHC', ClustType,'Normalize',true);
% 
%     [EEG,CURRENTSET] = pop_FindMSTemplates(ALLEEG, 1:numel(ALLEEG), ClustPars, 0, 0);
%     [ALLEEG EEG CURRENTSET] = eeg_store(ALLEEG, EEG, CURRENTSET);
% 
%     % Save clustered datasets
%     for i=1:numel(ALLEEG)
%         [EEG ALLEEG CURRENTSET] = eeg_retrieve(ALLEEG, i);
%         EEG = pop_saveset(EEG, 'filename', EEG.setname, 'savemode', 'onefile');
%     end

    % Generate metacriteria
    sampleSizes = [1000 2000 4000];
    nRuns = 5;

    for i=1:numel(ALLEEG)

        [EEG ALLEEG CURRENTSET] = eeg_retrieve(ALLEEG, i);
        criteria = [];
        break2 = false;

        fprintf("~~~~Beginning criterion computations for dataset %i~~~~~\n", i);

        for s=1:numel(sampleSizes)

            nSamples = sampleSizes(s);

            for run=1:nRuns
                fprintf("Samples: %i, Run no: %i/%i\n", nSamples, run, nRuns);
                tic
                newCriteria = generate_criteria_GFPpeaks(EEG, nSamples);
                toc
                if isempty(newCriteria)
                    break2 = true;
                    break;
                end
                for j=1:numel(newCriteria)
                    newCriteria(j).run_no = run;
                    newCriteria(j).sample_size = nSamples;
                end

                criteria = [criteria newCriteria];
            end

            if break2
                break;
            end
        end

        % Run with all GFP peaks
        fprintf("Running with all samples\n");
        tic
        [newCriteria, numGFPPeaks] = generate_criteria_GFPpeaks(EEG, inf);
        toc
        for j=1:numel(newCriteria)
            newCriteria(j).run_no = 1;
            newCriteria(j).sample_size = numGFPPeaks;
        end
        criteria = [criteria newCriteria];

        fprintf("Generating csv for dataset %i", i);

        % Reorder struct
        criteria = orderfields(criteria, [9, 10, 1:8]);
    
        % make table
        outputTable = struct2table(criteria);
    
        % Rename cluster columns
        oldNames = arrayfun(@(x) sprintf("clust%i", x), 4:10);
        outputTable = renamevars(outputTable, oldNames, string(4:10));
    
        writetable(outputTable, ['second_run/' EEG.setname '_criteria_results.csv']);
    end

end