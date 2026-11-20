function geo = usaGeometry(boundaryFile)
% USAGEOMETRY Projected, inset and triangulated state polygons, cached.
%
% Triangulation is the slow step, so results are kept in memory for the
% session and on disk in tempdir, keyed on the boundary file's size and date.
%
%   geo.Points     P x 2 projected vertices (rings stored back to back, CCW)
%   geo.Faces      T x 3 top-surface triangles (indices into Points)
%   geo.Edges      E x 2 consecutive ring vertices (outline and wall edges)
%   geo.PointState / FaceState / EdgeState   owning state index (usaStates order)
%   geo.RingStart, RingLength, RingState     where each ring's points sit, and owner
if nargin < 1 || isempty(boundaryFile)
    boundaryFile = fullfile(fileparts(mfilename('fullpath')), 'data', 'us_states.json');
end
persistent memo
info = dir(boundaryFile);
if isempty(info), error('usaGeometry:MissingFile', 'Cannot find %s', boundaryFile); end
key = sprintf('v2|%s|%d|%.6f', boundaryFile, info.bytes, info.datenum);
if isstruct(memo) && strcmp(memo.key, key), geo = memo.geo; return; end

cacheFile = fullfile(tempdir, sprintf('usa-map-3d-%08x.mat', mod(sum(double(key) .* (1:numel(key))), 2^32)));
if exist(cacheFile, 'file') == 2
    stored = load(cacheFile);
    if isfield(stored, 'key') && strcmp(stored.key, key)
        geo = stored.geo; memo = struct('key', key, 'geo', geo); return;
    end
end

geo = build(boundaryFile);
memo = struct('key', key, 'geo', geo);
try
    save(cacheFile, 'key', 'geo');
catch %#ok<CTCH> a read-only tempdir only costs speed
end
end

function geo = build(boundaryFile)
names = usaStates();
states = loadStateBoundaries(boundaryFile);
[known, stateIndex] = ismember({states.Name}, names);
states = states(known); stateIndex = stateIndex(known);

rings = {}; owner = [];
for i = 1:numel(states)
    switch states(i).Name
        case 'Alaska', origin = {-154, 63};
        case 'Hawaii', origin = {-157, 20};
        otherwise,     origin = {};
    end
    for part = states(i).Parts(:)'
        rings{end + 1} = lambertUSA(part.Lon, part.Lat, origin{:}); %#ok<AGROW>
        owner(end + 1) = stateIndex(i); %#ok<AGROW>
    end
end
mainland = vertcat(rings{~ismember(owner, [2 11])});
if isempty(mainland), error('usa:MissingMainland', 'No mainland states found.'); end
lo = min(mainland); span = max(mainland) - lo;
% Alaska and Hawaii become insets below the southwest; boxes are [x y w h].
insets = {2,  [lo(1),               lo(2) - span(2)*.42, span(1)*.26, span(2)*.34]; ...
          11, [lo(1) + span(1)*.30, lo(2) - span(2)*.32, span(1)*.13, span(2)*.18]};
for k = 1:size(insets, 1)
    ids = find(owner == insets{k, 1});
    if isempty(ids), continue; end
    pts = vertcat(rings{ids});
    low = min(pts); box = insets{k, 2};
    factor = min(box(3:4) ./ (max(pts) - low));
    for r = ids, rings{r} = (rings{r} - low) * factor + box(1:2); end
end

points = cell(numel(rings), 1); faces = points; edges = points;
pointState = points; faceState = points;
ringStart = zeros(numel(rings), 1); ringLength = ringStart;
offset = 0;
for r = 1:numel(rings)
    [xy, f] = triangulateRing(rings{r});   % returns cleaned, CCW-ordered points
    if size(xy, 1) < 3, xy = zeros(0, 2); f = zeros(0, 3); end
    n = size(xy, 1);
    ringStart(r) = offset + 1; ringLength(r) = n;
    points{r} = xy;
    faces{r} = f + offset;
    edges{r} = offset + [(1:n)', mod(1:n, n)' + 1];
    pointState{r} = repmat(owner(r), n, 1);
    faceState{r} = repmat(owner(r), size(f, 1), 1);
    offset = offset + n;
end
geo.Points = vertcat(points{:});
geo.Faces = vertcat(faces{:});
geo.Edges = vertcat(edges{:});
geo.PointState = vertcat(pointState{:});
geo.FaceState = vertcat(faceState{:});
geo.EdgeState = geo.PointState(geo.Edges(:, 1));
geo.RingStart = ringStart;
geo.RingLength = ringLength;
geo.RingState = owner(:);
end
