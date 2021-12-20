% Find spatial correlations of normative maps

% EEG = pop_loadset('filename',{'preprocessed-sample-data1.set','preprocessed-sample-data2.set'},'filepath','C:\\Program Files\\MATLAB\\R2021b\\eeglab2021.1\\sample_data\\data\\');
% [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, 2,'retrieve',1,'study',0); 
% [EEG,com] = pop_FindMSTemplates(EEG, struct('MinClasses', 4, 'MaxClasses', 4, 'GFPPeaks', 1, 'IgnorePolarity', 1, 'MaxMaps', 1000, 'Restarts', 25, 'UseAAHC', 0, 'Normalize', 1), 1, 0);

% [extracted from RunMicrostateAnalysis.m]
% First, we load a set of normative maps to orient us later

norms_templatepath = fullfile(fileparts(which('eegplugin_Microstates.m')),'Templates');
tmp_norms_EEG = pop_loadset('filename','Normative microstate template maps Neuroimage 2002.set','filepath',norms_templatepath);
norms_EEG = pop_select( tmp_norms_EEG,'channel',{ 'E22' 'E24' 'E33' 'E9' 'E122' 'E124' 'E36' 'E104' 'E45' 'E108' 'E52' 'E58' 'E92' 'E96' 'E70' 'E83' 'E11'  'E62'  'E129'});

[ALLEEG, norms_EEG, NORMSET] = pop_newset(ALLEEG, norms_EEG, 0,'gui','off'); % And make this a new set
% And we have a look at it
NormativeTemplateIndex = NORMSET;
pop_ShowIndMSMaps(ALLEEG(NormativeTemplateIndex), 4); 
% extract maps
norm_maps = norms_EEG.data(:,:,norms_EEG.trials);

tmp_curr_EEG = pop_loadset('filename','preprocessed-sample-data2.set','filepath','C:\\Program Files\\MATLAB\\R2021b\\eeglab2021.1\\sample_data\\data\\');

curr_EEG = pop_select( tmp_curr_EEG,'channel',{ 'E22' 'E24' 'E33' 'E9' 'E122' 'E124' 'E36' 'E104' 'E45' 'E108' 'E52' 'E58' 'E92' 'E96' 'E70' 'E83' 'E11'  'E62'  'E129'});
[ALLEEG, curr_EEG, CURRENTSET] = pop_newset(ALLEEG, curr_EEG, 0,'study',0); 
pop_ShowIndMSMaps(EEG, 3, 0, ALLEEG);
curr_maps = curr_EEG.data(:,:,tmpEEG.trials);

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
numCurrMaps = size(curr_maps, 2);
% fprintf("Number of maps: %d", numMaps);

correls = zeros(numNormMaps, numCurrMaps);

for i = 1:numNormMaps % iterate over normative maps     
    thisNormMap = norm_maps(:, i);  % grab all rows in the i'th column
    for j = 1:numCurrMaps 
        thisCurrMap = curr_maps(:, j);
        c = MyCorr(thisNormMap, thisCurrMap);
        correls(i, j) = c;
        correls(j, i) = c;
    end
end
writematrix(correls, 'spatial_correls.csv')
   