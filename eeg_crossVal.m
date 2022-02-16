function crossVal = eeg_crossVal(eegdata, Winner, Maps)
    pre_sigma = nan(1, size(Winner,2));     % num channels x number of timepoints
    for t = 1:size(Winner,2)    % size of winner, # of timepoints
        u = eegdata.data(:,t);      
        u_squared = u.^2;       % magnitude of vector
        if(Winner(1,t) == 0)        % special case where winner MS is 0
            pre_sigma(1,t) = 0;
        else
            a = (u.* eegdata.msinfo.MSMaps(size(Maps,1)).Maps(Winner(1,t)) );          % Winner(t) is the index of template map
            a_squared = (a).^2;
            pre_sigma(1,t) = abs(norm(u_squared) - (norm(a_squared)));
        end
    end
    pre_sigma_sum = sum(pre_sigma(1,:));
%     n_elec = size(eegdata,2);
    sigma_squared = pre_sigma_sum / (size(eegdata.data,2) * (eegdata.nbchan - 1));
    crossVal = sigma_squared * ((eegdata.nbchan - 1)/(eegdata.nbchan - 1 - size(Maps,1)))^2;      % taken from Murray 2008 formula for Cross Validation Criterion
end