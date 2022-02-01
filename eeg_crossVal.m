function crossVal = eeg_crossVal(eeg, IndSamples, TemplateMaps, ClustLabels)
    % check if IndSamples is 3D (segmented data)
    % if so, combine the last 2 dimensions of the matrix to get a
    % channels x samples instead of channels x samples per segment x
    % segments matrix, and combine the dimensions of ClustLabels to get a
    % samples long vector instead of a samples per segment x segments
    % matrix
    if (numel(size(IndSamples)) == 3)
        nSegments = size(IndSamples, 3);

        % reshape IndSamples
        NewIndSamples = IndSamples(:,:,1);
        for i = 2:nSegments
            NewIndSamples = cat(2, NewIndSamples, IndSamples(:,:,i));
        end
        IndSamples = NewIndSamples;

        % reshape ClustLabels
        NewClustLabels = ClustLabels(:,1);
        for i = 2:nSegments
            NewClustLabels = cat(1, NewClustLabels, ClustLabels(:,i));
        end
        ClustLabels = squeeze(NewClustLabels);
    end
    % Check for zero elements in ClustLabels (in case of truncating)
    zeroIndices = find(~ClustLabels);
    if (size(zeroIndices,1) > 0)
        % remove samples with no microstate assignmnets
        IndSamples(:, zeroIndices') = [];
        % remove clust labels of zero
        ClustLabels(zeroIndices') = [];
    end

    pre_sigma = nan(size(eeg,1),size(eeg,2));     % length: number of timepoints
    pre_sigma_sum = nan(n_mod,1);       % length: number of clusters
    for t = 1:size(eeg,1)    % timepoints
        % need to look at map for label corresponding to t. b_model(label,:) 
        % where label is which microstate cluster the timepoint belongs
        % to.
        % find label in assign ms, and take abs values
        for i = 1:n_mod     % add up the templates
            u = eeg.data(t,:);
            a = (u.* eeg.msinfo.MSMaps(ClustLabels(i,:)) );
            pre_sigma(t,:) = ((u.^2) - ((a).^2));
        end
        for j = 1:n_mod
            pre_sigma_sum(j) = sum(pre_sigma(t,:));
        end
    end
    n_elec = size(eeg,2);
    sigma_squared = sum(pre_sigma_sum) / (size(eeg,1) * (n_elec - 1));

    crossVal = sigma_squared * ((n_elec-1)/(n_elec-1-n_mod))^2;      % taken from Murray 2008 formula for Cross Validation Criterion
end