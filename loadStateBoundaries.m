function states = loadStateBoundaries(boundaryFile)
% Read bundled free boundaries or an optional geographic shapefile.
if nargin < 1 || isempty(boundaryFile)
    boundaryFile = fullfile(fileparts(mfilename('fullpath')), 'data', 'us_states.json');
end
[~, ~, extension] = fileparts(boundaryFile);
if strcmpi(extension, '.json')
    states = jsondecode(fileread(boundaryFile));
else
    if exist('OCTAVE_VERSION', 'builtin')
        pkg('load', 'mapping');
        shapes = shaperead(boundaryFile, 'ml', 'UseGeoCoords', true);
    else
        shapes = shaperead(boundaryFile, 'UseGeoCoords', true);
    end
    states = struct('Name', {}, 'Parts', {});
    for i = 1:numel(shapes)
        states(i).Name = shapes(i).Name;
        lon = shapes(i).Lon(:);
        lat = shapes(i).Lat(:);
        breaks = find(~isfinite(lon) | ~isfinite(lat));
        limits = [0; breaks; numel(lon) + 1];
        parts = struct('Lon', {}, 'Lat', {});
        for j = 1:numel(limits)-1
            ids = limits(j)+1:limits(j+1)-1;
            if numel(ids) >= 3
                parts(end+1) = struct('Lon', lon(ids), 'Lat', lat(ids));
            end
        end
        states(i).Parts = parts;
    end
end
% The original palette is alphabetical; never depend on source-file ordering.
[~, order] = sort({states.Name});
states = states(order);
end
