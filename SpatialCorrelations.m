% not using this file currently
function correls = SpatialCorrelations(nClasses, nEpochs)
    correls = zeros(1, nClasses, nEpochs);
    
    % Find spatial correlations of normative maps
        
    % EEG = pop_loadset('filename',{'preprocessed-sample-data1.set','preprocessed-sample-data2.set'},'filepath','C:\\Program Files\\MATLAB\\R2021b\\eeglab2021.1\\sample_data\\data\\');
    % [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, 2,'retrieve',1,'study',0); 
    % [EEG,com] = pop_FindMSTemplates(EEG, struct('MinClasses', 4, 'MaxClasses', 4, 'GFPPeaks', 1, 'IgnorePolarity', 1, 'MaxMaps', 1000, 'Restarts', 25, 'UseAAHC', 0, 'Normalize', 1), 1, 0);
    
    % [extracted from RunMicrostateAnalysis.m]
    % First, we load a set of normative maps to orient us later
    
    norms_templatepath = fullfile(fileparts(which('eegplugin_Microstates.m')),'Templates');
    tmp_norms_EEG = pop_loadset('filename','Normative microstate template maps Neuroimage 2002.set','filepath',norms_templatepath);
    tmp_norms_EEG = pop_select( tmp_norms_EEG,'nochannel',{ 'A1' 'A2' 'Cz'});
    norm_maps = tmp_norms_EEG.msinfo.MSMaps(nClasses).Maps;
%         norm_maps = tmp_norms_EEG.data(:,:,tmp_norms_EEG.trials);
    
    tmp_curr_EEG = pop_loadset('filename','Subject 1 raw data - filtered 0.01-30 Hz - bad channels interpolated - bad segments rejected - average referenced - baseline corrected.set','filepath','C:\\Program Files\\MATLAB\\R2021b\\eeglab2021.1\\sample_data\\clean_data\\');
    tmp_curr_EEG = pop_select( tmp_curr_EEG,'channel',{ 'E22' 'E24' 'E33' 'E9' 'E122' 'E124' 'E36' 'E104' 'E45' 'E108' 'E52' 'E58' 'E92' 'E96' 'E70' 'E83' 'E11'  'E62'});
    if ~isfield(tmp_curr_EEG,'msinfo')
        errordlg2('The data does not contain microstate maps','Show microstate dynamics');
        return;
    end
    
    % curr_EEG = pop_select( tmp_curr_EEG,'channel',{ 'E22' 'E24' 'E33' 'E9' 'E122' 'E124' 'E36' 'E104' 'E45' 'E108' 'E52' 'E58' 'E92' 'E96' 'E70' 'E83' 'E11'  'E62'  'E129'});

%         selectIdx = cell2mat({tmp_curr_EEG.chanlocs.urchan});
%         disp("list of locs");
%         disp(class(selectIdx));
%         disp(selectIdx);
    
%     EEG.msinfo.MSMaps(6).Maps  
    disp("tmp_curr_EEG:");
    disp(tmp_curr_EEG(:));
    % INCORRECT: selecting indices 1:18 in the next line just for testing!
    curr_maps = tmp_curr_EEG.msinfo.MSMaps(nClasses).Maps(:,1:18);
%     curr_maps = tmp_curr_EEG
    disp("curr_maps size");
    disp(size(curr_maps));
    % curr_maps = cell2mat(curr_maps);
    % curr_maps = curr_maps(:,selectIdx);
    
    % need to find a dataset with only 21 rows to match the number of rows in
    % the normative maps dataset.
    % temporarily calculating correlations with itself.
    
    % select specific 19 electrodes from curr_maps
    % create dummy
    % curr_maps = norm_maps;
    
    disp("Size of Normative Maps Matrix:")
    disp(size(norm_maps))
    
    disp("Size of current Maps Matrix:")
    disp(size(curr_maps))
    
    % times = norms_EEG.times;
    
    numNormMaps = size(norm_maps, 2);
    numCurrMaps = size(curr_maps, 1);
    % fprintf("Number of maps: %d", numMaps);
    disp("numNormMaps:");
    disp(numNormMaps);
    disp("numCurrMaps:");
    disp(numCurrMaps);
    
%     correls = zeros(numNormMaps, numCurrMaps);
    for i = 1:numNormMaps % iterate over normative maps     
        thisNormMap = norm_maps(:, i);  % grab all rows in the i'th column
%         for j = 1:numCurrMaps 
        thisCurrMap = curr_maps(i, :).';
    
        disp("Okay,Size of Normative Maps Matrix:")
        disp(size(thisNormMap))
        disp("Size of current Maps Matrix:")
        disp(size(thisCurrMap))
        
        c = MyCorr(thisNormMap, thisCurrMap);
        correls(1, i) = c;
    end
%     writematrix(correls, 'spatial_correls.csv')
    disp("Resulting correlations:");
    disp(correls);

end