% EEGLAB history file generated on the 02-Dec-2021
% ------------------------------------------------
[ALLEEG EEG CURRENTSET ALLCOM] = eeglab;
EEG = pop_loadset('filename','preprocessed-sample-data1.set','filepath','C:\\Program Files\\MATLAB\\R2021b\\eeglab2021.1\\sample_data\\data\\');
[ALLEEG, EEG, CURRENTSET] = eeg_store( ALLEEG, EEG, 0 );
[EEG,com] = pop_FindMSTemplates(EEG, struct('MinClasses', 3, 'MaxClasses', 6, 'GFPPeaks', 1, 'IgnorePolarity', 1, 'MaxMaps', 1000, 'Restarts', 5, 'UseAAHC', 0, 'Normalize', 1), 0, 0);
[ALLEEG EEG] = eeg_store(ALLEEG, EEG, CURRENTSET);
com = pop_QuantMSTemplates(ALLEEG, [1], 0, struct('b',0,'lambda',3.000000e-01,'PeakFit',1,'nClasses',3,'BControl',1,'Rectify',0,'Normalize',0), , 1, 'C:\Users\Anjali\Documents\projects\chlaLab\quantify-results3.csv');
[ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, 1,'gui','off'); 
[AllEEG,EEG,com] = pop_ShowIndMSMaps(EEG, 3, 0, ALLEEG);
eeglab redraw;
