nClasses = 4;
setIdx = 1:34;
meanIdx = 81;

FitPar.Classes = nClasses;
FitPar.PeakFit = 1;

labels = 'A':'Z';
labels = arrayfun(@(x) sprintf('%s',labels(x)), 1:nClasses, 'UniformOutput', false);

nChannels = ALLEEG(setIdx(1)).nbchan;
newRef = eye(nChannels);
newRef = newRef - 1/nChannels;

%% Mean maps
meanMaps = ALLEEG(meanIdx).msinfo.MSMaps(nClasses).Maps;

% Assign labels and get variances
meanVarDist = cell(1,nClasses);
for i=setIdx
    [MSClass, gfp] = AssignMStates(ALLEEG(i), meanMaps, FitPar, 1);
    for s=1:ALLEEG(i).trials
        peakIdx = find([false (gfp(1,1:end-2,s) < gfp(1,2:end-1,s) & gfp(1,2:end-1,s) > gfp(1,3:end,s)) false]);
        GFPClass = MSClass(peakIdx, s);
        for c=1:nClasses
            clustMembers = newRef*ALLEEG(i).data(:, GFPClass == c, s);
            clustMembers = L2NormDim(clustMembers, 1);
            vars = sum((clustMembers.*meanMaps(c,:)'),1).^2;
            meanVarDist{c} = [meanVarDist{c} vars];
        end
    end
end

%% Published template maps
TemplateName = 'Koenig2002';
[~, templateSortedEEG] = pop_SortMSMaps(ALLEEG, setIdx, 'TemplateSet', TemplateName, 'IgnorePolarity', 1, 'Classes', 4, 'TemplateClasses', 4);

templateSortedIndMaps = zeros(numel(setIdx), nClasses, nChannels);
for i=1:numel(setIdx)
    templateSortedIndMaps(i,:,:) = templateSortedEEG(i).msinfo.MSMaps(nClasses).Maps;
end
templateMeanMaps = zeros(nClasses,nChannels);
for c=1:nClasses
    data = squeeze(templateSortedIndMaps(:,c,:));
    [pc1,~] = eigs(data'*data,1);
    templateMeanMaps(c,:) = L2NormDim(pc1',2);
end

% Assign labels and get variances
templateVarDist = cell(1,nClasses);
for i=1:numel(setIdx)
    [MSClass, gfp] = AssignMStates(templateSortedEEG(i), templateMeanMaps, FitPar, 1);
    for s=1:templateSortedEEG(i).trials
        peakIdx = find([false (gfp(1,1:end-2,s) < gfp(1,2:end-1,s) & gfp(1,2:end-1,s) > gfp(1,3:end,s)) false]);
        GFPClass = MSClass(peakIdx, s);
        for c=1:nClasses
            clustMembers = newRef*templateSortedEEG(i).data(:, GFPClass == c, s);
            clustMembers = L2NormDim(clustMembers, 1);
            vars = sum((clustMembers.*templateMeanMaps(c,:)').^2,1);
            templateVarDist{c} = [templateVarDist{c} vars];
        end
    end
end

%% Manually sorted 
manualSortedIndMaps = zeros(numel(setIdx), nClasses, nChannels);
for i=1:numel(setIdx)
    manualSortedIndMaps(i,:,:) = manualEEG(i).msinfo.MSMaps(nClasses).Maps;
end
manualMeanMaps = zeros(nClasses,nChannels);
for c=1:nClasses
    data = squeeze(manualSortedIndMaps(:,c,:));
    [pc1,~] = eigs(data'*data,1);
    manualMeanMaps(c,:) = L2NormDim(pc1',2);
end

% Assign labels and get variances
manualVarDist = cell(1,nClasses);
for i=1:numel(setIdx)
    [MSClass, gfp] = AssignMStates(manualEEG(i), manualMeanMaps, FitPar, 1);
    for s=1:manualEEG(i).trials
        peakIdx = find([false (gfp(1,1:end-2,s) < gfp(1,2:end-1,s) & gfp(1,2:end-1,s) > gfp(1,3:end,s)) false]);
        GFPClass = MSClass(peakIdx, s);
        for c=1:nClasses
            clustMembers = newRef*manualEEG(i).data(:, GFPClass == c, s);
            clustMembers = L2NormDim(clustMembers, 1);
            vars = sum((clustMembers.*manualMeanMaps(c,:)').^2,1);
            manualVarDist{c} = [manualVarDist{c} vars];
        end
    end
end
