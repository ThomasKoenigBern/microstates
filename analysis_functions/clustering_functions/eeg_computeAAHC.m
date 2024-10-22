% MICROSTATELAB: The EEGLAB toolbox for resting-state microstate analysis
% Version 1.0
%
% Authors:
% Thomas Koenig (thomas.koenig@upd.unibe.ch)
% Delara Aryan  (dearyan@chla.usc.edu)
% 
% Copyright (C) 2023 Thomas Koenig and Delara Aryan
%
% If you use this software, please cite as:
% "MICROSTATELAB: The EEGLAB toolbox for resting-state microstate 
% analysis by Thomas Koenig and Delara Aryan"
% In addition, please reference MICROSTATELAB within the Materials and
% Methods section as follows:
% "Analysis was performed using MICROSTATELAB by Thomas Koenig and Delara
% Aryan."

function [b_model,exp_var] = eeg_computeAAHC(eeg,n_mod,ProgBar, IgnorePolarity, Normalize)

    if nargin < 3;  ProgBar = true; end
    if nargin < 4;  IgnorePolarity = false; end
    if nargin < 5;  Normalize = true; end
    [n_frame,n_chan] = size(eeg);

    h = eye(n_chan)-1/n_chan;
    eeg = eeg*h;									% Average reference of data 

    % Initally, all maps are clusters
    Cluster = L2NormDim(eeg,2);
    
    if Normalize == true
        eeg = L2NormDim(eeg,2);
    end
    
    GEV = sum(eeg.*Cluster,2);
    TotalVar = sum(GEV);
        
    if (ProgBar == true)
        hndl = waitbar(0,sprintf('Fitting %i-%i microstates (AAHC), please wait...',n_mod(1),n_mod(end)));
    else
        nSteps = 20;
        step = 0;
        fprintf(1, 'AAHC clustering(): |');
        strLength = fprintf(1, [repmat(' ', 1, nSteps - step) '|   0%%']);
        tic
    end
    
    if (IgnorePolarity == true);    GEV = abs(GEV); end
    Assignment = 1:n_frame;
    nClusters = size(Cluster,1);
    
    while (nClusters) > min(n_mod)
        % Find the most useless cluster
        [~,ToRemove] = min(GEV);   
        % And these are it's members, to become orphans
        Orphans = Assignment == ToRemove; % These are the orphans
        % So byebye bad cluster 
        Cluster(ToRemove,:) = [];   
        GEV(ToRemove) = [];
        % The assignment has to be adjusted
        Assignment(Assignment > ToRemove) = Assignment(Assignment > ToRemove) - 1;
    
        % Now let's see who's going at adopting the orphans
        Fit = eeg(Orphans,:) * Cluster';  % nOrphans x nClusters
        if (IgnorePolarity == true);    Fit = abs(Fit); end
        [~,NewAssignment] = max(Fit,[],2);  
        Assignment(1,Orphans) = NewAssignment;  % And do the assignment
    
        %So now some of the clusters need an update
        ClusterToUpdate = unique(NewAssignment);
        for f = 1:numel(ClusterToUpdate)  % Some cluster center need an update
            ClusterMembers = Assignment == ClusterToUpdate(f);
            if (IgnorePolarity == true)
                [pc1,~] = eigs(cov(eeg(ClusterMembers,:)),1);
                Cluster(ClusterToUpdate(f),:) = L2NormDim(pc1',2);
            else
                Cluster(ClusterToUpdate(f),:) = L2NormDim(mean(eeg(ClusterMembers,:),1),2);
            end
            % So now we go and see how things fit
            NewFit = Cluster(ClusterToUpdate(f),:)* eeg(ClusterMembers,:)'; % 1 x nFrames
            if (IgnorePolarity == true); NewFit = abs(NewFit);  end
            GEV(ClusterToUpdate(f),1) = sum(NewFit,2);
        end
        nClusters = size(Cluster,1);
    
        prc = 1-(nClusters+min(n_mod))/n_frame;
    
        if (rem(nClusters,10) == 0)
            if ProgBar == true
                waitbar(prc,hndl);
                set(hndl,'Name',sprintf('Remaining time: %01.0f:%02.0f min',floor(toc()*(1/prc)/60),rem(toc()*(1/prc-1),60)));
            else
                [step, strLength] = mywaitbar(n_frame - nClusters, n_frame, step, nSteps, strLength);
            end
        end
        if numel(n_mod) > 1
            idx = find(n_mod == nClusters);
            if numel(idx) > 0
                b_model{idx} = Cluster;
                exp_var{idx} = GEV' / TotalVar;
            end
        end
    end

    if numel(n_mod) == 1
        b_model{1} = Cluster;
        exp_var{1} = GEV' / TotalVar;
    end

    if (ProgBar == true)
        close(hndl);
    else
        mywaitbar(n_frame, n_frame, step, nSteps, strLength);
        fprintf(1,'\n');
    end
end

function [m,i] = nanmin(v)
    idx = find(~isnan(v));
    [m,p] = min(v(idx));
    i = idx(p);
end

