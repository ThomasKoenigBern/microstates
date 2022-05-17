function CH = eeg_CalinskiHarabasz(IndSamples, ClustLabels, IgnorePolarity)  
    [centroids, Ni, SUMD] = getCandSUMD(IndSamples, ClustLabels,IgnorePolarity);
    clusters = unique(ClustLabels);
    numClusts = length(clusters);
    if numClusts == 1
       CH = nan;
       return;
    end
    CH = getCH(IndSamples,centroids, Ni, SUMD, numClusts,IgnorePolarity);
end 

% Performs element-wise computation of 1 - abs(spatial correlation) or 
    % 1 - (spatial correlation) between matrices A and B
    function corrDist = elementCorrDist(A,B,IgnorePolarity)
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

    function [centroids, counts, sumD] = getCandSUMD(IndSamples, ClustLabels, IgnorePolarity)
      %Get centroids, number of observations and sum of Squared Euclidean
      %distance for each cluster based on cluster index. Index doesn't need
      %to be integers between 1:number of clusters
      p = size(IndSamples, 1);
      clusters = unique(ClustLabels);

      numClusts = length(clusters);
      centroids = NaN(p, numClusts);
      counts = zeros(numClusts,1);
      sumD = zeros(numClusts,1);
      for i = 1:numClusts
          members = (ClustLabels == clusters(i));
          if any(members)
              counts(i) = sum(members);
              centroids(:, i) = sum(IndSamples(:, members), 2) / counts(i);
              sumD(i)= sum(elementCorrDist(IndSamples(:, members), centroids(:, i), IgnorePolarity));          
          end
      end
  end

  function CH = getCH(IndSamples, centroids, Ni, SUMD, NC, IgnorePolarity)
     %Get CalinskiHarabasz value based on cluster centroids, The number of
     %points in each cluster, sum of Squared Euclidean and the number of
     %clusters
      GlobalMean = mean(IndSamples, 2);
      SSW = sum(SUMD,1);
      SSB = elementCorrDist(centroids, GlobalMean, IgnorePolarity);
      SSB = sum(Ni.*SSB');
      CH =(SSB/(NC-1))/(SSW/(length(IndSamples)-NC));
  end