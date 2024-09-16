function [TemplateNames, DisplayNames, sortOrder] = getTemplateNames()
    global MSTEMPLATE;
    TemplateNames = {MSTEMPLATE.setname};
    minClasses = arrayfun(@(x) MSTEMPLATE(x).msinfo.ClustPar.MinClasses, 1:numel(MSTEMPLATE));
    maxClasses = arrayfun(@(x) MSTEMPLATE(x).msinfo.ClustPar.MaxClasses, 1:numel(MSTEMPLATE));
    [minClasses, sortOrder] = sort(minClasses, 'ascend');
    maxClasses = maxClasses(sortOrder);
    classRangeTxt = string(minClasses);
    diffMaxClasses = maxClasses ~= minClasses;
    classRangeTxt(diffMaxClasses) = string(arrayfun(@(x) sprintf('%s - %s', classRangeTxt(x), string(maxClasses(x))), find(diffMaxClasses), 'UniformOutput', false));
    TemplateNames = TemplateNames(sortOrder);
    subjTxt = arrayfun(@(x) getSubjectTxt(MSTEMPLATE(x).msinfo), sortOrder, 'UniformOutput', false);
    DisplayNames = strcat(classRangeTxt, " maps - ", TemplateNames, subjTxt);
end

function subjTxt = getSubjectTxt(in)
    nSubjects = getNSubjects(in);
    if isempty(nSubjects)
        subjTxt = '';
    else
        subjTxt = sprintf(' - n=%i', nSubjects);
    end
end

function nSubjects = getNSubjects(in)
    nSubjects = [];
    if ~isfield(in, 'MetaData');            return; end
    if ~isfield(in.MetaData, 'nSubjects');  return; end
    nSubjects = in.MetaData.nSubjects;
end