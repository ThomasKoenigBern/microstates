    % calculates dispersion (W): measure of average distance between members 
% of the same cluster, using 1 - absolute spatial correlation as distance
% function

function W = eeg_Dispersion(IndSamples,ClustLabels, maxClusters)
        %k = total num max clusters
        % i: individual map of each max cluster
        % x_i = p-dimensional vector of obs of the ith object in ust C_k
                % voltage at timepoint with clust label i
        % c_k = centroid of cluster
        % W_q = summation of summation of (x_i - c_k) * (x_i - c_k)'
    % get number of clusters
    clusters = unique(ClustLabels);
    numClusts = length(clusters);
    nTimepoints = size(IndSamples, 1);

    centroids = NaN(numClusts,size(IndSamples,2));
    for i = 1:numClusts
      clustMembers = (ClustLabels == clusters(i));
      if any(clustMembers)
          centroids(i,:) = mean(IndSamples(clustMembers,:),1) ;
      end
    end


      W = nan(numClusts, numClusts);
      pre_mult = nan(nTimepoints, numClusts);
      pre_sum = nan(nTimepoints, numClusts);   
        % indsamples: each channel on a row
        % centroids: each channel in a col
      for t = 1:nTimepoints     % count voltages at timepoints with clust label i
        x = 1;      % should go up to numClusts
        for k = 1:numClusts
            if(ClustLabels(t,1) == k)
                pre_mult(x,:) = IndSamples(t, :)' - centroids(k, :);
                pre_sum(x,:) = pre_mult * pre_mult';
                x = x + 1;
            end            
        end
        W(k,:) = sum(pre_sum);  % dimensions might be wrong?
        % end: will have k by k matrix. 
        % dispersion: one value, representing the sum of the dispersion matrix 
        % also return the matrix
        % can also return sum(diag(W_q)) which is trace
      end

end