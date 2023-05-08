function [NewDesign,iDesign,CondIndices,DoF2] = Ragu_SortOutWithinDesign(Design,TwoLevels)

if (size(Design,1) == 1 || TwoLevels == false) % Make it a dummy two factorial if it isn't
    Design(2,:) = 1;
end

% Find the original labels

OrgLabelsL1 = unique(Design(1,~isnan(Design(1,:))));
OrgLabelsL2 = unique(Design(2,~isnan(Design(2,:))));

if numel(OrgLabelsL2) > 1
    DoF2 = true;
else
    DoF2 = false;
end

% Now we make a design where each conditions goes from 1.. n in steps of 1

SmallDesign = nan(size(Design));

for i = 1:numel(OrgLabelsL1)
    OrgLevel = OrgLabelsL1(i);
    SmallDesign(1,Design(1,:) == OrgLevel) = i;
end
    
for i = 1:numel(OrgLabelsL2)
    OrgLevel = OrgLabelsL2(i);
    SmallDesign(2,Design(2,:) == OrgLevel) = i;
end

% We make a design with all possible combinations
FactL2 = numel(OrgLabelsL1);
iDesign = SmallDesign(1,:) + FactL2 * (SmallDesign(2,:)-1);
% And we check how many unique combinations we have

[c,ia,ic] = unique(iDesign);

% We kick out excluded combinations
ValidCondition = c(~isnan(c));

% And we reconstruct the design we want
NewDesign(2,:) = floor((ValidCondition-1) / FactL2)+1;
NewDesign(1,:) = ValidCondition - FactL2 * (NewDesign(2,:)-1);

% Now we want the sort-order
CondIndices = nan(size(iDesign));

for i = 1:numel(ValidCondition)
    CondIndices(iDesign == ValidCondition(i)) = ValidCondition(i);
end

% and the final design for the interaction design

iDesign = NewDesign(1,:) + FactL2 * (NewDesign(2,:)-1);
