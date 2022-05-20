% EEGLAB history file generated on the 20-May-2022
% ------------------------------------------------
[ALLEEG EEG CURRENTSET ALLCOM] = eeglab;
EEG = pop_loadset('filename','02_S019_02mo_20161220_034924 copy_KA_completed_fil_seg_bcr_ref_rej.set','filepath','C:\\Program Files\\MATLAB\\R2021b\\eeglab2021.1\\sample_data\\clean_data_good\\');
[ALLEEG, EEG, CURRENTSET] = eeg_store( ALLEEG, EEG, 0 );
[EEG,com] = pop_FindMSTemplates(EEG, struct('MinClasses', 3, 'MaxClasses', 6, 'GFPPeaks', 1, 'IgnorePolarity', 1, 'MaxMaps', 1000, 'Restarts', 5, 'UseAAHC', 0, 'Normalize', 1), 0, 0);
[ALLEEG EEG] = eeg_store(ALLEEG, EEG, CURRENTSET);
[ALLEEG EEG CURRENTSET ALLCOM] = eeglab('rebuild');
eeglab('redraw');
pop_saveh( ALLCOM, 'eeglabhist.m', 'C:\Program Files\MATLAB\R2021b\eeglab2021.1\plugins\microstates\');
eeglab redraw;
