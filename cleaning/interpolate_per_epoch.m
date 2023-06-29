setIdx = 37;
filename = 'C:\Users\delar\Documents\eeglab2021.1\sample_data\toolbox_paper_sample_data\Cleaning Annotations\Bad channels per epoch\s1_EC_int-PO10.csv';
tbl = readtable(filename);

EEG = eeg_retrieve(ALLEEG, setIdx);
for e=1:numel(tbl.Epochs)
    epoch = tbl.Epochs(e);
    chanNames = split(tbl.BadChannels(e), ",");
    chanIdx = find(matches({EEG.chanlocs.labels}, chanNames));
    tmpEEG = pop_select(EEG, 'trial', epoch);
    tmpEEG = pop_interp(EEG, chanIdx);
    EEG.data(:,:,epoch) = tmpEEG.data(:,:,epoch);
end