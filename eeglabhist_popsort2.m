% EEGLAB history file generated on the 10-Jan-2022
% ------------------------------------------------

EEG.etc.eeglabvers = '2019.1'; % this tracks which version of EEGLAB is being used, you may ignore it
EEG = eeg_checkset( EEG );
EEG = eeg_checkset( EEG );
EEG.etc.eeglabvers = '2021.1'; % this tracks which version of EEGLAB is being used, you may ignore it
EEG = eeg_checkset( EEG );
[EEG,com] = pop_FindMSTemplates(EEG, struct('MinClasses', 3, 'MaxClasses', 6, 'GFPPeaks', 1, 'IgnorePolarity', 1, 'MaxMaps', 1000, 'Restarts', 5, 'UseAAHC', 0, 'Normalize', 1), 0, 0);
EEG = eeg_checkset( EEG );
EEG = eeg_checkset( EEG );
com = pop_QuantMSTemplates(ALLEEG, [1], 0, struct('b',0,'lambda',3.000000e-01,'PeakFit',1,'nClasses',3,'BControl',1,'Rectify',0,'Normalize',0), , 'C:\Program Files\MATLAB\R2021b\eeglab2021.1\plugins\microstates\quantify_results4.csv');
EEG = eeg_checkset( EEG );
