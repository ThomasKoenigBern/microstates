function gamma_indices = eeg_gamma (TheEEG, IndSamples, AllClustLabels)
    % first classify all of the clust labels that are A =
    % ClustLabels(IndSamples(A)
    nSegments = size(TheEEG.data,3);    % nSegments is also = to size(AllClustLabels,3)

    numClusters = size(AllClustLabels, 1);
    nTimepoints = size(AllClustLabels, 2);
%     clusters = unique(AllClustLabels(1,:,:));

    % s_plus represents the number of times where two points not clustered
    % together had a larger distance than two points in the same cluster
    
    s_plus = 0;
    s_minus = 0;
    max_dist = 0;
    gamma_indices = nan(numClusters);
    % will only fill in top right section of matrix
    dist_matrices = zeros(numClusters, numClusters);
    for u = 1:numClusters   % for u representing each cluster
        for v = 1:u     % for each cluster not equal
            uMembers = (AllClustLabels == u);
            uClustMembers = IndSamples(:,uMembers);
            uNumSamples = size(uClustMembers, 2);            
            if u == v
                % special case, want to grab max dist
                max_dist = 1;
            else

                vMembers = (AllClustLabels == v);
                vClustMembers = IndSamples(:,vMembers);
                vNumSamples = size(vClustMembers, 2);
                
        %         dist_matrices(u,v) = zeros(IndSamples(u), IndSamples(v));
                this_dist_matrix = zeros(u_nSamples, v_nSamples);
                for i = 1:uNumSamples
                    for j = 1:vNumSamples
        %                 dist_matrices(u,v) = pdist(TheEEG.msinfo.MSMaps(u_clustNum).Maps(AllClustLabels(u,:,1)), TheEEG.msinfo.MSMaps(v_clustNum).Maps(AllClustLabels(v,:,1)));
                        spCorr = corr(TheEEG.msinfo.MSMaps(u_clustNum, i), TheEEG.msinfo.MSMaps(v_clustNum, j));
                        this_dist_matrix(i, j) = 1 - abs(spCorr);
                    end
                end
            end
        end
        gamma = (s_plus-s_minus)/(s_plus+s_minus);
    end


% if not same cluster, capture distance
%           end
% members = (ClustLabels == ClusterNumbers_i);
%           if any(members)
%               clustMembers = IndSamples(members, :)';
%               numSamples = size(clustMembers, 2);
%               
%               for j = 1:numSamples
%                 distance = %?
%               end
%           end
% 
% For k in specified range:
% 	For each cluster a of the k clusters 
% 		maxDist = the max distance between two points in the cluster a
% 		For each point u in this cluster a
% 			For each cluster b of the k-1 other clusters
% 				For each point v in this other cluster b
% 					If (euclidean distance between u and v) > a:
% 						S_plus += 1
% 					Else if (euclidean distance between u and v) > a:
% 						S_minus += 1
% 
%       gamma = (s_plus-s_moins)/(s_plus+s_moins)
% 
%   ---- pasted from R toolbox
%     for j=1:nwithin1
%         %         tau_list(j) = tau;
%         s_plus = s_plus   + (sum(outer(between_dist1,within_dist1(j), ">"), 2));
%         s_minus = s_minus + (sum(outer(between_dist1,within_dist1(j), "<"), 2));
%     end
%     tau  = (nwithin1*nbetween1)-(s_plus+s_minus);
% 
%     tau_indices = (s_plus-s_minus)/(((n1*(n1-1)/2-tau)*(n1*(n1-1)/2))^(1/2));

end