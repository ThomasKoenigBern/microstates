outputPath = 'C:\Users\delar\Documents\eeglab2021.1\sample_data\toolbox_paper_sample_data\Cleaning Annotations';
sets = 37;
threshold = 8;

for i=sets
    epochNums = [];
    badChans = {};
    chanNames = {ALLEEG(i).chanlocs.labels};

    ResidualEstimator = VA_MakeSplineResidualMatrix(ALLEEG(i).chanlocs);
    residuals = zeros(size(ALLEEG(i).data));

    for e=1:ALLEEG(i).trials
        residuals(:,:,e) = ResidualEstimator*ALLEEG(i).data(:,:,e);
    end

    chanRMSE = squeeze(sqrt(mean(residuals.^2, 2)));
    [chans, epochs] = find(chanRMSE >= threshold);
    badEpochs = unique(epochs);
    epochNums = [epochNums; badEpochs];

    for e=1:numel(badEpochs)        
        chanNums = chans(epochs == badEpochs(e));
        chanString = sprintf('%s, ', string(chanNames(chanNums)));
        chanString = chanString(1:end-2);
        badChans = [badChans; chanString];
    end

    tbl = table(epochNums, badChans, 'VariableNames', {'Epochs', 'Bad Channels'});
    writetable(tbl, fullfile(outputPath, [ALLEEG(i).setname '.csv']));
end