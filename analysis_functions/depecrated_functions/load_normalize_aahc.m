% EEGLAB history file generated on the 28-Dec-2021
% ------------------------------------------------
[ALLEEG EEG CURRENTSET ALLCOM] = eeglab;
EEG = pop_loadset('filename','Subject 1 raw data - filtered 0.01-30 Hz - bad channels interpolated - bad segments rejected - average referenced - baseline corrected.set','filepath','C:\\Program Files\\MATLAB\\R2021b\\eeglab2021.1\\sample_data\\clean_data\\');
[ALLEEG, EEG, CURRENTSET] = eeg_store( ALLEEG, EEG, 0 );
[EEG,com] = pop_FindMSMaps(EEG, struct('MinClasses', 3, 'MaxClasses', 6, 'GFPPeaks', 1, 'IgnorePolarity', 1, 'MaxMaps', 1000, 'Restarts', 5, 'UseAAHC', 0, 'Normalize', 0), 0, 0);
[ALLEEG EEG] = eeg_store(ALLEEG, EEG, CURRENTSET);
[EEG,com] = pop_FindMSMaps(EEG, struct('MinClasses', 3, 'MaxClasses', 6, 'GFPPeaks', 1, 'IgnorePolarity', 1, 'MaxMaps', 1000, 'Restarts', 5, 'UseAAHC', 1, 'Normalize', 0), 0, 0);
[ALLEEG EEG] = eeg_store(ALLEEG, EEG, CURRENTSET);
[EEG,com] = pop_FindMSMaps(EEG, struct('MinClasses', 3, 'MaxClasses', 6, 'GFPPeaks', 1, 'IgnorePolarity', 1, 'MaxMaps', 1000, 'Restarts', 5, 'UseAAHC', 1, 'Normalize', 0), 0, 0);
[ALLEEG EEG] = eeg_store(ALLEEG, EEG, CURRENTSET);
eeglab redraw;
