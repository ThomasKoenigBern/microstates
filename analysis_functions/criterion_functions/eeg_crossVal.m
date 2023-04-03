function CV = eeg_crossVal(Maps, IndSamples, ClustLabels, clustNum)        % i is current map index
    nsamples = size(IndSamples, 1);
    pre_sigma = zeros(1, nsamples);

    for t = 1:nsamples
        % all channels at the current timepoint
        u = IndSamples(t,:);

        % template map assigned to current timepoint
        map = Maps(ClustLabels(t), :);

        pre_sigma(t) = u*u' - (map*u')^2;
    end

    pre_sigma_sum = sum(pre_sigma);
    nchannels = size(IndSamples, 2);
    sigma_squared = pre_sigma_sum / (nsamples * (nchannels - 1));
    CV = sigma_squared * ((nchannels - 1)/(nchannels - 1 - clustNum))^2;
end