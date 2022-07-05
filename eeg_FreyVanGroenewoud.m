function FVG = eeg_FreyVanGroenewoud(AllIndSamples, AllClustLabels, ClusterNumbers, IgnorePolarity)

    % Performs element-wise computation of 1 - abs(spatial correlation) or 
    % 1 - (spatial correlation) between matrices A and B
    function corrDist = elementCorrDist(A,B)
        % average reference
        A = A - mean(A, 1);
        B = B - mean(B, 1);

        % get correlation
        A = A./sqrt(sum(A.^2, 1));
        B = B./sqrt(sum(B.^2, 1));
        corr = sum(A.*B, 1);           

        % corr dist
        if (IgnorePolarity) 
            corrDist = 1 - abs(corr);
        else 
            corrDist = 1 - corr; 
        end
    end

    % Performs pair-wise computation of 1 - abs(spatial correlation) or 
    % 1 - (spatial correlation) for every pair of columns in matrix A
    function corrDist = pairCorrDist(A)
        Corr = corr(A);
        if (IgnorePolarity) 
            corrDist = 1 - abs(Corr);
        else 
            corrDist = 1 - Corr; 
        end
    end

    numClustSolutions = length(ClusterNumbers);

    % using the individual samples and cluster labels for each solution,
    % compute Frey index for each solution
    FVG = zeros(numClustSolutions, 1);
    for c = 1:numClustSolutions
        IndSamples = AllIndSamples{c};
        ClustLabels = AllClustLabels{c}';
        nc = ClusterNumbers(c);     % number of clusters
        
        % find mean inter-cluster distance and mean intra-cluster distance
        % for the CURRENT cluster solution
        centroids = NaN(size(IndSamples, 1), nc);
        intraClustDists = zeros(nc,1);
        
        clusters = unique(ClustLabels);
        for i = 1:nc
          clustMembers = (ClustLabels == clusters(i));
          if any(clustMembers)
              centroids(:, i) = mean(IndSamples(:, clustMembers), 2) ;

              % twice the average distance of each observation to the centroids
              intraClustDists(i) = 2*mean(elementCorrDist(IndSamples(:, clustMembers),centroids(:, i)), 2);
          end
        end
        
        centroidDists = triu(pairCorrDist(centroids), 1);
        centroidDists = centroidDists(:);
        centroidDists(centroidDists == 0) = [];
        currInterClustDist = mean(centroidDists);
        currIntraClustDist = mean(intraClustDists);

        % find the mean inter-cluster distance and mean intra-cluster
        % distance for the NEXT cluster solution
        IndSamples = AllIndSamples{c+1};
        ClustLabels = AllClustLabels{c+1}';
        if (nc == ClusterNumbers(end))
            nc = ClusterNumbers(end) + 1;
        end

        centroids = NaN(size(IndSamples,1), nc);
        intraClustDists = zeros(nc,1);
        
        clusters = unique(ClustLabels);
        for i = 1:nc
          clustMembers = (ClustLabels == clusters(i));
          if any(clustMembers)
              centroids(:, i) = mean(IndSamples(:, clustMembers), 2);

              % twice the average distance of each observation to the centroids
              intraClustDists(i) = 2*mean(elementCorrDist(IndSamples(:, clustMembers), centroids(:, i)), 2);
          end
        end
        
        centroidDists = triu(pairCorrDist(centroids), 1);
        centroidDists = centroidDists(:);
        centroidDists(centroidDists == 0) = [];
        nextInterClustDist = mean(centroidDists);
        nextIntraClustDist = mean(intraClustDists);

        FVG(c) = (nextInterClustDist - currInterClustDist)/(nextIntraClustDist - currIntraClustDist);
    end

end