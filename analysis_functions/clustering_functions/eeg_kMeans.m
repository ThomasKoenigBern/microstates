function[b_model,b_ind,b_loading,exp_var] = eeg_kMeans(eeg,n_mod,reruns,max_n,flags,chanloc)
% EEG_MOD Create the EEG model I'm working with
%
% function[b_model,b_ind,b_loading,exp_var] = eeg_mod_r(eeg,n_mod,reruns,max_n)

% input arguments
% eeg = the input data (number of time instances * number of channels)
% n_mod = the number of microstate clusters that you want to extract
% reruns = the number of reiterations (use about 20)
% max_n = maximum number of eeg timepoints used for cluster indentification

% output arguments
% b_model = cluster centers (microstate topographies)
% b_ind = cluster assignment for each moment of time
% b_loading = Amplitude of the assigned cluster at each moment in time
% exp_var = explained variance of the model

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

if (size(n_mod,1) ~= 1)
	error('Second argument must be a scalar')
end

if (size(n_mod,2) ~= 1)
	error('Second argument must be a scalar')
end

[n_frame,n_chan] = size(eeg);

if nargin < 3
    reruns = 1;
end

if nargin < 4
    max_n = n_frame;
end

if isempty(max_n)
    max_n = n_frame;
end

if (max_n > n_frame)
    max_n = n_frame;
end

if ~contains(flags,'p')
    pmode = 0;
else
    pmode = 1;
end

if ~contains(flags,'+')
    plusmode = 0;
else
    plusmode = 1;
end


% Average reference
newRef = eye(n_chan);
newRef = newRef -1/n_chan;
eeg = eeg*newRef;

org_data = eeg;

UseEMD = false;
if contains(flags,'e')
    UseEMD = true;
end

if contains(flags,'n')
    eeg = L2NormDim(eeg,2);
end

best_fit = 0;

if contains(flags,'b')
    h = waitbar(0,sprintf('Computing %i clusters, please wait...',n_mod));
else
    h = [];
    nSteps = 20;
    step = 0;
    fprintf(1, 'k-means clustering(k=%i): |',n_mod);
    strLength = fprintf(1, [repmat(' ', 1, nSteps - step) '|   0%%']);
    tic
end

if max_n < n_mod
    b_model = [];
    return;
end

for run = 1:reruns
    if isempty(h)
        [step, strLength] = mywaitbar(run, reruns, step, nSteps, strLength);
    else
        t = sprintf('Run: %i / %i',run,reruns);
        set(h,'Name',t);
        waitbar(run/reruns,h);
    end
    if nargin > 3
        idx = randperm(n_frame);
        eeg = org_data(idx(1:max_n),:);
    end

    if plusmode == false
        StartingMaps = randi(max_n,n_mod,1);
    else
        StartingMaps = nan(n_mod,1,1);
        StartingMaps(1) = randi(max_n,1);
        for m = 2:n_mod
            model   = eeg(StartingMaps(1:m-1),:);
            corrmat = corr(eeg',model');
            if ~pmode
                %Dist = 1-corrmat.^2;
                Dist = sqrt(2- 2 * abs(corrmat));
                Dist = Dist.^2;
            else
%                Dist = (1 - corrmat);
                Dist = sqrt(2- 2 * corrmat);
                Dist = Dist.^2;
            end
            Dist = min(Dist,[],2);
            Dist = Dist / max(Dist);
            StartingMaps(m) = randsample(max_n,1,true,Dist);
        end
    end

    model = eeg(StartingMaps,:);
    model   = L2NormDim(model,2)*newRef;					% Average Reference, equal variance of model

    o_ind   = zeros(max_n,1);							% Some initialization
%	ind     =  ones(max_n,1);
	count   = 0;
    covmat = eeg*model';							    % Get the unsigned covariance 
    
    if pmode
        if UseEMD == true
            [~,ind] = min(EMMapDifference(double(eeg),double(model),chanloc,chanloc,false),[],2);
        else
            [~,ind] =  max(covmat,[],2);				
        end     % Look for the best fit
    else
        if UseEMD == true
            [~,ind] = min(EMMapDifference(double(eeg),double(model),chanloc,chanloc,true),[],2);
        else
            [~,ind] =  max(abs(covmat),[],2);				% Look for the best fit
        end
    end
        
    
    % TODO TEMP COUNT LIMIT
    conv_limit = 10000;
    while count < conv_limit && any(o_ind - ind)
        count   = count+1;
        if count == conv_limit
            warning("K-Means Didn't converge in 10000 iterations");
        end
        o_ind   = ind;
%        if pmode
%            covm    = eeg * model';						% Get the unsigned covariance matrix
%        else
%            covm    = abs(eeg * model');						% Get the unsigned covariance matrix
%        end
%        [c,ind] =  max(covm,[],2);				            % Look for the best fit

        for i = 1:n_mod
            idx = find (ind == i);
            if pmode
                model(i,:) = mean(eeg(idx,:));
            else
                cvm = eeg(idx,:)' * eeg(idx,:);
                [v,d] = eigs(double(cvm),1);
                model(i,:) = v(:,1)';
            end
        end
		model   = L2NormDim(model,2)*newRef;						% Average Reference, equal variance of model
        covmat = eeg*model';							% Get the unsigned covariance 
        if pmode
            if UseEMD == true
                [~,ind] = min(EMMapDifference(double(eeg),double(model),chanloc,chanloc,false),[],2);
            else
                [~,ind] =  max(covmat,[],2);				
            end     % Look for the best fit
        else
            if UseEMD == true
                [~,ind] = min(EMMapDifference(double(eeg),double(model),chanloc,chanloc,true),[],2);
            else
                [~,ind] =  max(abs(covmat),[],2);				% Look for the best fit
            end
        end
    end % while any

    covmat    = org_data*model';							% Get the unsigned covariance 
    if pmode
        if UseEMD == true
            [~,ind] = min(EMMapDifference(double(org_data),double(model),chanloc,chanloc,false),[],2);
            loading = zeros(size(ind));
            for t = 1:numel(ind)
                loading(t) = covmat(t,ind(t));
            end
        else
            [loading,ind] =  max(covmat,[],2);				% Look for the best fit
        end
    else
        if UseEMD == true
            [~,ind] = min(EMMapDifference(double(org_data),double(model),chanloc,chanloc,true),[],2);
            loading = zeros(size(ind));
            for t = 1:numel(ind)
                loading(t) = abs(covmat(t,ind(t)));
            end
        else
            [loading,ind] =  max(abs(covmat),[],2);				% Look for the best fit
        end
    end
 
    tot_fit = sum(loading);

    
    if (tot_fit > best_fit)
        b_model   = model;
        b_ind     = ind;
        b_loading = loading; %/sqrt(n_chan);
        best_fit  = tot_fit;
    end    
end % for run = 1:reruns

% Individual GEVs
IndGEVnum = zeros(1, n_mod);
for i = 1:n_mod
    clustMembers = (b_ind == i);
    IndGEVnum(i) = sum(b_loading(clustMembers).^2);
end
exp_var = IndGEVnum/sum(vecnorm(org_data').^2);

if isempty(h)
    mywaitbar(reruns, reruns, step, nSteps, strLength);
    fprintf('\n');
else
    close(h);
end