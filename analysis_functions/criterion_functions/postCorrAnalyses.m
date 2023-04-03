 eeglab
 
 sampleSizes = [1000 2000 4000 16000 inf];
 nRuns = 1000;
 datasetSizes = nan(nRuns*length(sampleSizes),1);
 all_mcVotes = nan(nRuns*length(sampleSizes),1);     % single linear array d
 
 for dataset = 1:24
    
    fprintf("Beginning work on dataset %d \n", dataset); 
    
    d = int2str(dataset);
    % Load dataset
    % Change this to your path
    EEG = pop_loadset('filename', strcat(d,'.set'), 'filepath','../../sample_data/Metacriterion_Testing_Data/');
    [ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, 0,'study',0); 
    
    % grab sizes
%     datasetSizes(dataset) = EEG.trials;
%     thisDatasetSize = EEG.trials
    % Clustering
    disp("Beginning clustering");
    tic
    [EEG,com] = pop_FindMSTemplates(EEG, struct('MinClasses', 4, 'MaxClasses', 10, 'GFPPeaks', 1, 'IgnorePolarity', 1, 'MaxMaps', inf, 'Restarts', 15, 'UseAAHC', 0, 'Normalize', 1), 0, 0);
    [ALLEEG EEG] = eeg_store(ALLEEG, EEG, CURRENTSET);
    disp("Finished clustering");
    toc
   
    
    tic
    idx = find(EEG.setname == '/') + 1;
    setname = EEG.setname(idx:length(EEG.setname)-4);
  
    % metacriteria
%     MC1 = zeros(nRuns*length(sampleSizes), 7);
    NumSamples = zeros(nRuns*length(sampleSizes), 1);
    NumRuns = zeros(nRuns*length(sampleSizes), 1);
    MC2votes = zeros(nRuns*length(sampleSizes), 1);
    toc
    
    tic
    for s = 1:length(sampleSizes)
        
        fprintf("Beginning calculating metacriteria for %d samples\n", sampleSizes(s)); 

        for i = 1:nRuns
            [metacriteria, criteria, GEVs, mcVotes, ~] = clustNumSelection(ALLEEG, EEG, CURRENTSET, sampleSizes(s));
            datasetSizes(((s-1)*nRuns+i) + (nRuns*length(sampleSizes)*(dataset-1))) = EEG.trials;
            all_mcVotes(((s-1)*nRuns+i) + (nRuns*length(sampleSizes)*(dataset-1))) = mcVotes.MC2;
            fprintf('run #: %d\n', i);
        end
    end
    
    fprintf("Done calculating metacriteria for all %d samples\n", sampleSizes(s));
    toc

 end
corr = corrcoef(datasetSizes, all_mcVotes);
fprintf("Correlation between dataset sizes and optimal number of microstates: %5d\n",corr)
