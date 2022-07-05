function KL = eeg_krzanowskiLai(AllIndSamples, AllClustLabels, ClusterNumbers, IgnorePolarity)

% old KL code
% diff_q =  (((nc-1)^(2/size(IndSamples,2))) * trace_w(1, i-1))...
%                         - (((nc)^(2/size(IndSamples,2))) * trace_w(1, i));
%                 diff_qplus1 = (((nc)^(2/size(IndSamples,2))) * trace_w(1, i))...
%                             - (((nc+1)^(2/size(IndSamples,2))) * trace_w(1, i+1));
%                 KL(subj, i) = abs(diff_q/diff_qplus1);

    % Performs pair-wise computation of 1 - abs(spatial correlation) or 
    % 1 - (spatial correlation) for every pair of columns in matrix A
    function corrDist = pairCorrDist(A)
        c = corr(A);
        if (IgnorePolarity) 
            corrDist = 1 - abs(c);
        else 
            corrDist = 1 - c; 
        end
    end

    numClustSolutions = length(ClusterNumbers);
    nChannels = size(AllIndSamples{1}, 1);

    % using the individual samples and cluster labels for each solution,
    % first find W (dispersion) for each cluster solution + 1 greater, 1 less
    W = zeros(numClustSolutions+2, 1);
    for i = 1:numClustSolutions+2
        IndSamples = AllIndSamples{i};
        ClustLabels = AllClustLabels{i};
        clusters = unique(ClustLabels);
        numClusts = length(clusters);
        
        % compute W
        W(i) = 0;
        for j = 1:numClusts
            members = (ClustLabels == clusters(j));
            clustMembers = IndSamples(:, members);
            nk = size(clustMembers, 2);
            pairCorrs = pairCorrDist(clustMembers);
            D = sum(sum(triu(pairCorrs, 1)));
            W(i) = W(i) + D/(2*nk);
        end    

    end

    % use the W values to find the diff values for each cluster solution
    % + 1 greater
    diff = NaN(numClustSolutions+1, 1);
    for i = 1:numClustSolutions+1
        prevW = W(i);
        currW = W(i+1);
        if (i > numClustSolutions)
            k = ClusterNumbers(end) + 1;
        else
            k = ClusterNumbers(i);
        end
        diff(i) = prevW*(k-1)^(2/nChannels) - currW*k^(2/nChannels);
    end

    % now use the diff values to find KL for each cluster solution
    KL = zeros(numClustSolutions, 1);
    for i = 1:numClustSolutions
        prevW = W(i);
        currW = W(i+1);
        if ((currW - prevW) > 0)
            KL(i) = 0;
        end
        KL(i) = abs(diff(i)/diff(i+1));
    end

end