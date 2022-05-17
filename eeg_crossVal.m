function crossVal = eeg_crossVal(eegdata, IndSamples, ClustLabels, clustNum)        % i is current map index
% old parameters: (eegdata, Winner, Maps)
%     Maps = ClustLabels';
%     Winner = IndSamples;
    nTimepoints = size(IndSamples, 1);
    nChannels = size(IndSamples, 2);
    pre_sigma = nan(nChannels, nTimepoints);     % num channels x number of timepoints
    for t = 1:nTimepoints    % size of winner, # of timepoints
        u = IndSamples(t,:);    % u: all channels at this timepoint     
        u_squared = u.^2;       % magnitude of vector
        if(ClustLabels(t,1) == 0)   % special case where winner MS is 0
            pre_sigma(1,t) = 0;
        else
            a = (u.* eegdata.msinfo.MSMaps(clustNum).Maps(ClustLabels(t,1)) );          % Winner(t) is the index of template map
            a_squared = (a).^2;
            pre_sigma(1,t) = abs(norm(u_squared) - (norm(a_squared)));
        end
    end
    pre_sigma_sum = sum(pre_sigma(1,:));
%     n_elec = size(eegdata,2);
    sigma_squared = pre_sigma_sum / (nTimepoints * (eegdata.nbchan - 1));
    crossVal = sigma_squared * ((eegdata.nbchan - 1)/(eegdata.nbchan - 1 - clustNum))^2;      % taken from Murray 2008 formula for Cross Validation Criterion
end