function H = eeg_Hartigan(W, ClusterNumbers, nsamples)
    numClustSolutions = length(ClusterNumbers);

    %% Compute Hartigan index for each cluster solution
    H = zeros(numClustSolutions, 1);
    for c = 1:numClustSolutions
        nc = ClusterNumbers(c);     % number of clusters
        Wratio = (trace(W{c})/trace(W{c+1})) - 1;
        n = nsamples(c);
        H(c) = Wratio*(n-nc-1);
    end

end