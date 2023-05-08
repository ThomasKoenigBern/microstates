function result = Randomizer_ComputeTanova(d,UpdateExpVarFlag)

% Copyright 2009-2011 Thomas Koenig
% distributed under the terms of the GNU AFFERO General Public License

if nargin < 2
    UpdateExpVarFlag = false;
end

switch d.Normalize
    case 1
        PreNormalizeMode = false;
        bNormalize = false;
    case 2
        PreNormalizeMode = true;
        bNormalize = false;
    case 3
        errordlg('Dissimilarity mode currently not available','Ragu');
        result = NaN;
        return;
end

SelIndFeature = d.IndFeature;
SelIndFeature(isnan(d.IndFeature)) = [];
SelDesign = d.Design;

SelDesign(isnan(SelDesign(:,1)),:) = [];

DoGroup = (numel(unique(SelIndFeature))> 1);
DoF1    = (numel(unique(SelDesign(:,1)))> 1);


if d.ContF1 == 1
    DoF2 = 0;
    NewDesign = SelDesign(:,1)';
    CondIndices = find(~isnan(NewDesign));
    iDesign = NewDesign;
else
    [NewDesign,iDesign,CondIndices,DoF2] = Ragu_SortOutWithinDesign(d.Design',d.TwoFactors);
end
if d.MeanInterval
    TanovaEffectSize = ones(2,4,1,d.Iterations);
else
    TanovaEffectSize = ones(2,4,d.EndFrame-d.StartFrame+1,d.Iterations);
end

if UpdateExpVarFlag == false
    h = waitbar(0,'Computing, please wait...');
end

if (DoF1 && DoF2)
    if abs(corrcoef(NewDesign(:,1),NewDesign(:,2))) > 0.01
        error('Design not orthogonal');
    end
end

InData = zeros(size(d.V,1),numel(iDesign),size(d.V,3),size(d.V,4));

for i = 1:numel(iDesign)
    InData(:,i,:,:) = mean(d.V(:,CondIndices == i,:,:),2);
end

if d.DoGFP    
    InData = sqrt(mean(InData.^2,3));
end
    
InData(isnan(d.IndFeature),:,:,:) = [];

if d.MeanInterval
    InData = mean(InData(:,:,:,d.StartFrame:d.EndFrame),4);
else
    InData = InData(:,:,:,d.StartFrame:d.EndFrame);
end

if ~d.DoGFP && PreNormalizeMode
    InData = NormDimL2(InData,3);
end

if d.MeanInterval
    [tes,ExpVar,EffectMaps] = DoAllEffectSizes(InData,NewDesign',iDesign,SelIndFeature,DoGroup,DoF1,DoF2,bNormalize,d.ContBetween,d.ContF1);
    TanovaEffectSize(:,:,1,1) = tes;
else
    [tes,ExpVar,EffectMaps] = DoAllEffectSizes(InData,NewDesign',iDesign,SelIndFeature,DoGroup,DoF1,DoF2,bNormalize,d.ContBetween,d.ContF1);    
    TanovaEffectSize(:,:,:,1) = tes;
end

NoXing = d.NoXing;
MeanInterval = d.MeanInterval;

tic
if UpdateExpVarFlag == false
    waitbar(1/d.Iterations,h);
    set(h,'Name',sprintf('Remaining time: %01.0f:%02.0f min',floor(toc()*(d.Iterations)/60),rem(toc()*(d.Iterations-1),60)));
    
    for iter = 2:d.Iterations
        TanovaEffectSize(:,:,:,iter) = DoAllEffectSizesRandomized(InData,NewDesign',iDesign,SelIndFeature,DoGroup,DoF1,DoF2,bNormalize,d.ContBetween,d.ContF1,NoXing);        
        if nargin < 2
             waitbar(iter/d.Iterations,h);
             set(h,'Name',sprintf('Remaining time: %01.0f:%02.0f min',floor(toc()*(d.Iterations/iter-1)/60),rem(toc()*(d.Iterations/iter-1),60)));
        else
            ShowProgress(iter/d.Iterations,h);
        end
    end
end

if UpdateExpVarFlag == false
    if MeanInterval
        res.TanovaEffectSize = TanovaEffectSize;
        res.ExpVar           = ExpVar;
    else
        res.TanovaEffectSize = zeros(2,4,size(d.V,4),d.Iterations);
        res.TanovaEffectSize(:,:,d.StartFrame:d.EndFrame,:) = TanovaEffectSize;
        ExpVar1 = zeros(2,4,size(d.V,4));
        ExpVar2 = ExpVar1;
    
        ExpVar1(:,:,d.StartFrame:d.EndFrame,:) = ExpVar{1};
        ExpVar2(:,:,d.StartFrame:d.EndFrame,:) = ExpVar{2};
        res.ExpVar{1} = ExpVar1;
        res.ExpVar{2} = ExpVar2;
    end
    
    Rank = 1:d.Iterations;
    res.PTanova = ones(size(res.TanovaEffectSize)) * d.Iterations;

    if d.MeanInterval
        t1 = 1;
        t2 = 1;
    else
        t1 = d.StartFrame;
        t2 = d.EndFrame;
    end

    for i = 1:2
        for j = 1:4
            for t = t1:t2%size(d.V,4);
                if max(squeeze(res.TanovaEffectSize(i,j,t,:))) == 0
                    res.PTanova(i,j,t,:) = d.Iterations;
                else
                    [~,order] = sort(squeeze(res.TanovaEffectSize(i,j,t,:)),'descend');
                    res.PTanova(i,j,t,order) = Rank;
                end
            end
        end
    end
    res.PTanova = res.PTanova ./ d.Iterations;
else
    if MeanInterval
        res.ExpVar           = ExpVar;
    else
        ExpVar1 = zeros(2,4,size(d.V,4));
        ExpVar2 = ExpVar1;
    
        ExpVar1(:,:,d.StartFrame:d.EndFrame,:) = ExpVar{1};
        ExpVar2(:,:,d.StartFrame:d.EndFrame,:) = ExpVar{2};
        res.ExpVar{1} = ExpVar1;
        res.ExpVar{2} = ExpVar2;
    end
end    

if UpdateExpVarFlag == false
    close(h);
end

if d.DoGFP
    if UpdateExpVarFlag == false
        d.GFPTanovaEffectSize = res.TanovaEffectSize;
        d.GFPPTanova          = res.PTanova;
    end
    d.GFPExpVar           = res.ExpVar;
    d.GFPEffects          = EffectMaps;
else
    if UpdateExpVarFlag == false
        d.TanovaEffectSize = res.TanovaEffectSize;
        d.PTanova          = res.PTanova;
    end
    d.TExpVar          = res.ExpVar;
    d.TEffects         = EffectMaps;
end

result = d;




function res = DoAllEffectSizesRandomized(data,Design,iDesign,Group,DoGroup,DoF1,DoF2,Normalize,ContGroup,ContF1,NoXing)
r_in = zeros(size(data)); 
for j = 1:size(data,1)
    r_in(j,:,:,:) = data(j,PermDesign(Design,NoXing),:,:);
end
rIndFeat = Group(randperm(numel(Group)));

res = DoAllEffectSizes(r_in,Design,iDesign,rIndFeat,DoGroup,DoF1,DoF2,Normalize,ContGroup,ContF1);


function [efs,ExpVar, EffectMaps] = DoAllEffectSizes(data,Design,iDesign,Group,DoGroup,DoF1,DoF2,Normalize,ContGroup,ContF1)

if Normalize
    data = NormDimL2(data,3);
end

if (numel(size(data)) == 3)
    DoAverage = true;
else
    DoAverage = false;
end

if DoAverage
    efs = nan(2,4);
else
    efs = nan(2,4,size(data,4));
end


if nargout > 1
    SSSysT2  = zeros(size(efs));
    SSRand   = SSSysT2;
end

EffectMaps = cell(2,4);

% First, we take out the grand mean across everything
[efstmp,mmBL_All,EffMaps] =   OLES_All(data,ones(1,size(data,2)),0); % Same condition across everything

efs(1,1,:) = efstmp;
noBL_M_All = data - mmBL_All;
EffectMaps{1,1} = EffMaps;

[~,SWiseMeans] = OLESG_All(noBL_M_All,ones(1,size(data,2)),1:numel(Group),Normalize);
SSRand(1,1,:) = squeeze(sum(sum(sum(SWiseMeans .^2,3),2),1));


if nargout > 1
    % Sum of squares across subjects, conditions, and electrodes
    SSRand(1,1,:) = squeeze(sum(sum(sum(noBL_M_All.^2,3),2),1));
end


% Now, we look at the group main effect
if DoGroup
    if ContGroup
        [efstmp,mmBLG_All,EffMaps] = OLESCG_All(noBL_M_All,ones(1,size(data,2)),Group,Normalize);
    else
        [efstmp,mmBLG_All] = OLESG_All(noBL_M_All,ones(1,size(data,2)),Group,Normalize);
        if nargout > 1
            [~,~,EffMaps] = OLESG_All(data,ones(1,size(data,2)),Group,Normalize);
        end
    end
    efs(2,1,:) = efstmp;

    EffectMaps{2,1} = EffMaps;
    noBL_MG_All = noBL_M_All - mmBLG_All;
else
    mmBLG_All   = zeros(size(noBL_M_All));
    noBL_MG_All = noBL_M_All;
end

% This is factor 1:
if DoF1
    if ContF1 == 0
        [efstmp,mmBLF1_All] = OLES_All(noBL_M_All,Design(:,1),Normalize);

        if nargout > 1
            [~,~,EffMaps] = OLES_All(data,Design(:,1),Normalize);
        end
    else
        [efstmp,mmBLF1_All] = OLESC_All(noBL_M_All,Design(:,1),Normalize); 
        if nargout > 1
            [~,~,EffMaps] = OLESC_All(data,Design(:,1),Normalize); 
        end
    end
    efs(1,2,:) = efstmp;
    EffectMaps{1,2} = EffMaps;
else
    mmBLF1_All = zeros(size(noBL_M_All));
end

% Now we go into F1 x group
if (DoF1 && DoGroup)
    if ContGroup
        if ContF1 == 0
            [efstmp,mmBLGF1_All] = OLESCG_All(noBL_MG_All-mmBLF1_All,Design(:,1),Group,Normalize);
            if nargout > 1
                [~,~,EffMaps]     = OLESCG_All(data,Design(:,1),Group,Normalize);
            end
        else
            [efstmp,mmBLGF1_All] = OLESCCG_All(noBL_MG_All-mmBLF1_All,Design(:,1),Group,Normalize);
            if nargout > 1
                [~,~,EffMaps]     = OLESCCG_All(data,Design(:,1),Group,Normalize);

            end
        end
    else
        if ContF1 == 0
            [efstmp,mmBLGF1_All] =  OLESG_All(noBL_MG_All-mmBLF1_All,Design(:,1),Group,Normalize);
            if nargout > 1
                [~,~,EffMaps]     = OLESG_All(data,Design(:,1),Group,Normalize);
            end
        else
            [efstmp,mmBLGF1_All] =  OLESGDC_All(noBL_MG_All-mmBLF1_All,Design(:,1),Group,Normalize);
            if nargout > 2
                [~,~,EffMaps]     = OLESGDC_All(data,Design(:,1),Group,Normalize);
            end
        end
    end

    EffectMaps{2,2} = EffMaps;
    efs(2,2,:) = efstmp;
else
    mmBLGF1_All = zeros(size(noBL_M_All));
end


% Now factor 2
if DoF2
    [efstmp,mmBLF2_All] = OLES_All(noBL_M_All,Design(:,2),Normalize);
    if nargout > 1
        [~,~,EffMaps] = OLES_All(data,Design(:,2),Normalize);
    end
    EffectMaps{1,3} = EffMaps;

    efs(1,3,:) = efstmp;
else
    mmBLF2_All = zeros(size(noBL_M_All));
end

% Factor 2 by group...
if (DoF2 && DoGroup)
    if ContGroup
        [efstmp,mmBLGF2_All] = OLESCG_All(noBL_MG_All-mmBLF2_All,Design(:,2),Group,Normalize);
        if nargout > 2
            [~,~,EffMaps] = OLESCG_All(data,Design(:,2),Group,Normalize);
        end
    else
        [efstmp,mmBLGF2_All] = OLESG_All(noBL_MG_All-mmBLF2_All,Design(:,2),Group,Normalize);
        if nargout > 2
            [~,~,EffMaps] = OLESG_All(data,Design(:,2),Group,Normalize);
        end
    end
   
    EffectMaps{2,3} = EffMaps;
    efs(2,3,:) = efstmp;
else
    mmBLGF2_All = zeros(size(noBL_M_All));
end


% Factor 1 * Factor 2
if (DoF1 && DoF2)
    [efstmp,mmBLF1F2_All        ] = OLES_All(noBL_M_All-mmBLF1_All-mmBLF2_All,iDesign,Normalize);
    if nargout > 1
        [~,~,EffMaps] = OLES_All(data,iDesign,Normalize);
    end
    
    EffectMaps{1,4} = EffMaps;
    efs(1,4,:) = efstmp;
else
    mmBLF1F2_All = zeros(size(noBL_M_All));
end

% Factor 1 * Factor 2 * Group
if (DoF1 && DoF2 && DoGroup)
    if ContGroup
        [efstmp,mmBLGF1F2_All] = OLESCG_All(noBL_MG_All-mmBLF1_All-mmBLF2_All-mmBLGF1_All-mmBLGF2_All-mmBLF1F2_All,iDesign,Group,Normalize);
        if nargout > 2
            [~,~,EffMaps] = OLESCG_All(data,iDesign,Group,Normalize);
        end
    else
        [efstmp,mmBLGF1F2_All] =  OLESG_All(noBL_MG_All-mmBLF1_All-mmBLF2_All-mmBLGF1_All-mmBLGF2_All-mmBLF1F2_All,iDesign,Group,Normalize);
        if nargout > 2
            [~,~,EffMaps] =  OLESG_All(data,iDesign,Group,Normalize);
        end
    end
    
    EffectMaps{2,4} = EffMaps;
    efs(2,4,:) = efstmp;
else
    mmBLGF1F2_All = zeros(size(noBL_M_All));
end


if nargout > 1
    
    SSSysT2(2,1,:) = squeeze(sum(sum(sum(mmBLG_All   .^2,3),2),1));

    SSSysT2(1,2,:) = squeeze(sum(sum(sum(mmBLF1_All  .^2,3),2),1));
    SSSysT2(2,2,:) = squeeze(sum(sum(sum(mmBLGF1_All .^2,3),2),1));
    
    SSSysT2(1,3,:) = squeeze(sum(sum(sum(mmBLF2_All  .^2,3),2),1));
    SSSysT2(2,3,:) = squeeze(sum(sum(sum(mmBLGF2_All .^2,3),2),1));
    SSSysT2(1,4,:) = squeeze(sum(sum(sum(mmBLF1F2_All.^2,3),2),1));
    SSSysT2(2,4,:) = squeeze(sum(sum(sum(mmBLGF1F2_All.^2,3),2),1));

    [~,SWiseMeans]     = OLESG_All(noBL_M_All - mmBLG_All                                                                                                                                ,ones(1,size(data,2)),1:numel(Group),Normalize);

    if DoF1
        if ContF1 == 0
            [~,SWiseMeansF1]   = OLESG_All(    noBL_M_All - mmBLG_All - mmBLF1_All - mmBLGF1_All                                                           - SWiseMeans                              ,Design(:,1)         ,1:numel(Group),Normalize);
        else
            [~,SWiseMeansF1]   = OLESGDC_All(  noBL_M_All - mmBLG_All - mmBLF1_All - mmBLGF1_All                                                           - SWiseMeans                              ,Design(:,1)         ,1:numel(Group),Normalize);
        end
    else
        SWiseMeansF1 = zeros(size(SWiseMeans));
    end
    if DoF2
        [~,SWiseMeansF2]   = OLESG_All(noBL_M_All - mmBLG_All                            - mmBLF2_All - mmBLGF2_All                                - SWiseMeans                              ,Design(:,2)         ,1:numel(Group),Normalize);
    else
        SWiseMeansF2 = zeros(size(SWiseMeans));
    end
    if (DoF1 && DoF2)
        [~,SWiseMeansF1F2] = OLESG_All(noBL_M_All - mmBLG_All - mmBLF1_All - mmBLGF1_All - mmBLF2_All - mmBLGF2_All - mmBLF1F2_All - mmBLGF1F2_All - SWiseMeans - SWiseMeansF1 - SWiseMeansF2,iDesign             ,1:numel(Group),Normalize);
    else
        SWiseMeansF1F2 = zeros(size(SWiseMeans));
    end
    
    SSRand(2,1,:) = squeeze(sum(sum(nansum(SWiseMeans .^2,3),2),1));
    SSRand(1,1,:) = SSRand(2,1,:);
    
    SSRand(2,2,:)  = squeeze(sum(sum(nansum(SWiseMeansF1 .^2,3),2),1));
    SSRand(1,2,:)  = SSRand(2,2,:);

    SSRand(2,3,:) = squeeze(sum(sum(nansum(SWiseMeansF2 .^2,3),2),1));
    SSRand(1,3,:) = SSRand(2,3,:);

    SSRand(2,4,:) = squeeze(sum(sum(nansum(SWiseMeansF1F2 .^2,3),2),1));
    SSRand(1,4,:) = SSRand(2,4,:);

    ExpVar{1} = SSSysT2    ./ (repmat(SSSysT2(1,:,:),2,1,1) + repmat(SSSysT2(2,:,:),2,1,1)+SSRand);
    
    PartialEtaSquaredII  = SSSysT2    ./ (SSSysT2    + SSRand);
    ExpVar{2} = PartialEtaSquaredII;
end            
%----------------------------------------------------

function [es,mmap,cm] = OLESCG_All(in,Design,Group,nFlag) 
%-----------------------------------------------------
% One categorical factor within, and a continuous one between

Group  = normr((Group(:)-mean(Group))');
GroupR = repmat(Group(:),[1 1 size(in,3) size(in,4)]);

dLevel = unique(Design);
ndLevel = numel(dLevel);

cm = zeros(1,ndLevel,size(in,3),size(in,4));

for l = 1:ndLevel
    in_s = in(:,Design == dLevel(l),:,:); 
    m = mean(in_s,2); % subjects x 1 x channels x timepoints
    cm(1,l,:,:) = sum(GroupR .*m,1);
%    sum(m,3)
end

% Normalization not implemented
if nFlag
    disp('Dissimilarity not inplemented for continuous predictors');
end

% Effect size is the RMS across channels (dim=3)and withinlevels (dim = 2)
es = squeeze(mean(sqrt(mean(cm.*cm,3)),2));

if nargout > 1
    cmp = repmat(cm,[numel(Group),1,1,1]) .* repmat(Group(:),[1 ndLevel,size(in,3) size(in,4)]);
    mmap = zeros(size(in));
    for l = 1:ndLevel
        idx = find(Design == dLevel(l));
        mmap(:,idx,:) = repmat(cmp(:,l,:),[1 numel(idx),1]);
    end
end


function [es,mmap,OutMaps] = OLESG_All(in,Design,Group,nFlag)
%----------------------------------------------------
% Computes the difference measure, and the EEG model produced by the design
% for a group x conditions interaction
%----------------------------------------------------
Level = unique(Group);      % Group levels
nLevel = numel(Level);
dLevel = unique(Design);    % Within levels
ndLevel = numel(dLevel);

% Space for the mean maps
LMap = zeros(nLevel,ndLevel,size(in,3),size(in,4));
for l1 = 1:nLevel
    for  l2 = 1:ndLevel
        in_s = in(Group == Level(l1),Design == dLevel(l2),:,:);
        nCObs = size(in_s,1) * size(in_s,2);
        maps = reshape(in_s,[nCObs size(in_s,3) size(in_s,4)]);
        LMap(l1,l2,:,:) = nanmean(maps,1); 
    end
end
% Effect size is the RMS across channels (dim=3)and withlevels (dim = 2)
% and between level
if nFlag == 1
    OutMaps = NormDimL2(LMap,3);
    es = squeeze(mean(mean(sqrt(mean(OutMaps .*OutMaps ,3)),2),1));
else
    OutMaps = LMap;
    es = squeeze(mean(mean(sqrt(mean(LMap .*LMap ,3)),2),1));
end

% This is the model the design produces, if requested
if nargout > 1
    mmap = zeros(size(in));
    for l1 = 1:nLevel
        idx = find(Group == Level(l1));
        for l2 = 1:ndLevel
            idx2 = find(Design == dLevel(l2));
            mmap(idx,idx2,:,:) = repmat(LMap(l1,l2,:,:),[numel(idx),numel(idx2),1,1]);
        end
    end
end


function [es,mmap,OutMaps] = OLES_All(in,Design,nFlag)
%-------------------------------------------------
% One a categorical within factor

nSub = size(in,1);
Level = unique(Design);
nLevel = numel(Level);

% This is the space for the mean maps of each level
LMap = zeros(1,nLevel,size(in,3),size(in,4));

% We go and fill each level with the mean across subjects
for l = 1:nLevel
    in_s = in(:,Design == Level(l),:,:);
    nCObs = size(in_s,1) * size(in_s,2);
    maps = reshape(in_s,[nCObs size(in_s,3) size(in_s,4)]);
    LMap(1,l,:,:) = nanmean(maps,1); 
end

% Effect size is the RMS across channels (dim=3)and levels (dim = 2)
if nFlag == 1
    OutMaps = NormDimL2(LMap,3);
    es = squeeze(mean(sqrt(mean(OutMaps.*OutMaps,3)),2)); 
else
    OutMaps = LMap;
    es = squeeze(mean(sqrt(mean(LMap .*LMap ,3)),2));
end

% We eventually also compute the model produced by the design
if nargout > 1
    mmap = zeros(size(in));
    for l = 1:nLevel
        idx = find(Design == Level(l));
        mmap(:,idx,:,:) = repmat(LMap(1,l,:,:),[nSub,numel(idx),1,1]);
    end
end

function [es,mmap,LMap] = OLESC_All(in,Design,nFlag)
% ---------------------------------------------
% A continous within factor only one group

% We need the average across subjects
in_s = mean(in,1); % 1 x cond x channels x time

% We need the design in the same shape
DesignT(1,:,1,1) = normr((Design(:)-mean(Design))');
DesignR = repmat(DesignT,[1 1 size(in,3) size(in,4)]); 

LMap = nansum(DesignR .* in_s,2); % The covariance maps,1s x 1cond x channels x time
if nFlag
    disp('Dissimilarity not inplemented for continuous predictors');
end

% We just need the RMS across channels, as there is only one dim for the
% conditions, and we have no groups
es = squeeze(sqrt(mean(LMap.*LMap,3)));

% The mean maps need to be inflated to all subjects and weighted by the
% design
if nargout > 1
    mmap = repmat(LMap,[size(in,1) size(in,2) 1 1]) .* DesignR;
end


function [es,mmap,LMap] = OLESCCG_All(in,Design,Group,nFlag)
%------------------------------------------------------
Group = normr(Group(:)'-mean(Group));
Design = normr(Design(:)'-mean(Design));

%This is the combined between / within design
TotDesign = Group(:) * Design(:)';
    
MeanDesign = mean(TotDesign(:));
TotDesign = TotDesign - MeanDesign;
nrmFact = sqrt(sum(sum(TotDesign.^2,2),1));
TotDesign = TotDesign ./ nrmFact;
TotDesignR = repmat(TotDesign,[1,1,size(in,3) size(in,4)]); 

% And this is the covariance map, 1 x 1 x channels x time
LMap = nansum(nansum(in.*TotDesignR,1),2);

% Normalization not implemented
if nFlag
    disp('Dissimilarity not inplemented for continuous predictors');
end

es = squeeze(mean(sqrt(LMap.*LMap),3));

if nargout > 1
    LMapR = repmat(LMap,[size(in,1) size(in,2) 1 1]);
    mmap = LMapR .*(TotDesignR + MeanDesign);
end


function [es,mmap,LMap] = OLESGDC_All(in,Design,Group,nFlag)
%-------------------------------------------------
% Groups are categorical, within are weights

GroupLevel = unique(Group);
nGroupLevel = numel(GroupLevel);

DesignT(1,:,1,1)  = normr((Design(:)-mean(Design))');
DesignR = repmat(DesignT,[1 1 size(in,3) size(in,4)]);

LMap = zeros(nGroupLevel,1,size(in,3),size(in,4));

for l = 1:nGroupLevel
    % Average within group
    in_s = nanmean(in(Group == GroupLevel(l),:,:,:),1);
    % and weight by the within factor
    LMap(l,1,:,:) = nansum(DesignR .* in_s,2);
end

if nFlag
    disp('Dissimilarity not inplemented for continuous predictors');
end

% We need the mean RMS across channels and groups
es = squeeze(mean(mean(sqrt(LMap.*LMap),3),1));

if nargout > 1
    mmap = zeros(size(in));
    for l = 1:nGroupLevel
        idx = find(Group == GroupLevel(l));
        dmap = DesignR .* repmat(LMap(l,1,:,:),[1 size(in,2) 1 1]);
        mmap(idx,:,:,:) = repmat(dmap,[numel(idx),1,1,1]);
    end
end

