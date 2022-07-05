% this version uses distances between centroids for both inter-cluster and
% intra-cluster distances
function Dunn = eeg_Dunn(IndSamples, ClustLabels, IgnorePolarity)

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
        c = corr(A);
        if (IgnorePolarity) 
            corrDist = 1 - abs(c);
        else 
            corrDist = 1 - c; 
        end
    end

    % get number of clusters
    clusters = unique(ClustLabels);
    numClusts = length(clusters);
    if numClusts == 1
        Dunn = nan;
        return;
    end
    
   centroids = NaN(size(IndSamples,1), numClusts);
   intraClustDists = zeros(numClusts,1);
   for i = 1:numClusts
      clustMembers = (ClustLabels == clusters(i));
      if any(clustMembers)
          centroids(:, i) = mean(IndSamples(:, clustMembers), 2);

          %average distance of each observation to the centroids
          intraClustDists(i)= mean(elementCorrDist(IndSamples(:, clustMembers), centroids(:, i)), 2);
      end
   end

   % min inter-cluster distance is minimum distance between centroids
   centroidDists = triu(pairCorrDist(centroids), 1);
   centroidDists = centroidDists(:);
   centroidDists(centroidDists == 0) = [];
   interClustDist = min(centroidDists);
    
   % max intra-cluster distance is twice the maximum average distance
   % between all members of a cluster and its centroid
   intraClustDist = 2*max(intraClustDists);

   Dunn = interClustDist/intraClustDist;
end