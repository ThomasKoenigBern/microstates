function [step, strLength] = mywaitbar(compl, total, step, nSteps, strLength,progStrArray)

    if nargin < 6
        progStrArray = '/-\|';
    end
    tmp = floor(compl / total * nSteps);
    if step == nSteps
        fprintf(1, [repmat('\b', 1, strLength) '%s']);
        strLength = fprintf(1, '| Done');
        return;
    end
    if tmp > step
        fprintf(1, [repmat('\b', 1, strLength) '%s'], repmat('=', 1, tmp - step));
        step = tmp;
        ete = ceil(toc / step * (nSteps - step));
        strLength = fprintf(1, [repmat(' ', 1, nSteps - step) '%s %3d%%, ETE %02d:%02d'], progStrArray(mod(step - 1, 4) + 1), floor(step * 100 / nSteps), floor(ete / 60), mod(ete, 60));
    end
end

