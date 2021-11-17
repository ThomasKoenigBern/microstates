%SmoothLabels() Smoothes microstate labels
%
% Usage:
%   >> smoothedLabels = SmoothLabels(V,M,par, srate, IgnorePolarity)
%
% Where: - V is the voltage vector(Ne x Nt)
%        - M is the microstate vector(Nu x Ne)
%        - par.b is the window size
%        - par.lambda is the non-smoothness penalty factor
%          (should be between 0 and 1)
%        - srate is the sampling rate
%        - IgnorePolarity is true if the polarity is to be ignored
%
% Author: Thomas Koenig, University of Bern, Switzerland, 2016
%
% Copyright (C) 2016 Thomas Koenig, University of Bern, Switzerland, 2016
% thomas.koenig@puk.unibe.ch
%
% This program is free software; you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation; either version 2 of the License, or
% (at your option) any later version.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with this program; if not, write to the Free Software
% Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
%
function [smoothedLabels,ExpVar] = SmoothLabels(V,M,par, srate, IgnorePolarity)
    
    if ~isfield(par,'b');   par.b = 0;  end
    [Ns,Nt] = size(V);
    Nu = size(M,1);
    M = NormDim(M,2) / sqrt(Ns);
    deltaT = 1000 / srate;
    WinPts = round(par.b / deltaT);
    Vvar = sum(V.*V,1);
    rmat = repmat((1:Nu)',1,Nt);
        
    %Trivial case with one map 
    if(Nu == 1);    smoothedLabels = ones(1,Nt);    return; end
 
    % Line 2 of Pascual 1995

    fit = M * V;
    if IgnorePolarity == true;  fit = abs(fit); end
    
    [~,smoothedLabels] = max(fit);
        
    % No smooting
    if WinPts == 0;  
        w = zeros(Nu,Nt);
        w(rmat == repmat(smoothedLabels,Nu,1)) = 1;
        ExpVar = SignedSquare(sum((M'*w).*V),IgnorePolarity) ./ Vvar;
        return; 
    end
    
    % Some helpful stuff

    crit = 10e-6;
    S0 = 0;
    
    
    % Line 3 and 4
    w = zeros(Nu,Nt);
    w(rmat == repmat(smoothedLabels,Nu,1)) = 1;
    
    e = sum(Vvar - SignedSquare(sum((M'*w).*V),IgnorePolarity)) / (Nt * (Ns - 1));

    DoLoop = true;

    while DoLoop == true
        % Line 5a
        Nb = conv2(w,ones(1,2*WinPts+1),'same');
        
        % Line 5b
        x = (repmat(Vvar,Nu,1) - SignedSquare(M * V, IgnorePolarity)) / (2* e * (Ns-1)) - par.lambda * Nb;
        [~,dlt] = min(x,[],1);
        
        % Line 6
        smoothedLabels = dlt;

        % Line 7
        w = zeros(Nu,Nt);
        w(rmat == repmat(smoothedLabels,Nu,1)) = 1;
        Su = sum(Vvar - SignedSquare(sum((M'*w).*V),IgnorePolarity)) / (Nt * (Ns - 1));
        ExpVar = SignedSquare(sum((M'*w).*V),IgnorePolarity) ./ Vvar;
        % Line 8
        if abs(Su - S0) <= crit * Su
            DoLoop = false;
        end
    
        S0 = Su;
    end
    smoothedLabels(Vvar == 0) = 0;
    ExpVar(Vvar == 0) = 0;
end

function result = SignedSquare(data,removesign)
    if removesign == true
        result =  data.^2;
    else
        result = data.^2 .* sign(data);
    end
end
